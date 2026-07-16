const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// Lazy Redis connection — only created when enqueueJob actually runs.
// This prevents Redis errors from flooding logs during cold starts and deployment.
let _connection = null;
function getRedisConnection() {
  if (_connection) return _connection;
  const IORedis = require('ioredis');
  _connection = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379', {
    maxRetriesPerRequest: null,
    lazyConnect: true,
    enableOfflineQueue: false,
  });
  _connection.on('error', (err) => {
    console.warn('Redis connection warning:', err.message);
  });
  return _connection;
}

const MAX_SIZE_BYTES = parseInt(process.env.MAX_FILE_SIZE_BYTES || String(500 * 1024 * 1024));

exports.enqueueJob = functions.firestore
  .document('jobs/{jobId}')
  .onCreate(async (snap, ctx) => {
    const jobId = ctx.params.jobId;
    const job = snap.data();

    try {
      if (!job || !job.userId || !job.input || !job.input.storagePath) {
        return snap.ref.update({ status: 'invalid', invalidReason: 'missing_fields' });
      }

      if (job.status !== 'created') {
        return snap.ref.update({ status: 'invalid', invalidReason: 'status_must_be_created' });
      }

      // ============================================
      // 🧠 Job Intelligence Router (The Brain)
      // ============================================
      let targetQueueName = 'default-worker';

      if (job.params && job.params.templateId === "cinematic") {
        targetQueueName = 'remotion-worker';
      } else if (sizeBytes > 200 * 1024 * 1024) { // > 200MB
        targetQueueName = 'heavy-ffmpeg-worker';
      } else if (job.params && job.params.aiGenerated === true) {
        targetQueueName = 'ai-video-engine';
      }

      // Initialize the specialized Queue dynamically
      const { Queue } = require('bullmq');
      const specializedQueue = new Queue(targetQueueName, { connection: getRedisConnection() });

      // Add job to the specialized specializedQueue
      const queueJob = await specializedQueue.add(jobId, {
        jobId,
        userId: job.userId,
        input: job.input,
        params: job.params || {},
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      }, {
        attempts: 5,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: 1000,
        removeOnFail: 1000
      });

      // Update status to queued + routing info
      await snap.ref.update({
        status: 'queued',
        queuedAt: admin.firestore.FieldValue.serverTimestamp(),
        queueJobId: queueJob.id,
        routingState: {
          targetQueue: targetQueueName,
          routedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      });
      return null;
    } catch (err) {
      console.error('enqueueJob error', err);
      return snap.ref.update({ status: 'invalid', invalidReason: 'server_error', serverErrorMessage: err.message });
    }
  });

function _normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function _docIdForEmail(email) {
  return crypto.createHash('sha256').update(email).digest('hex');
}

function _generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function _hashOtp(otp, salt) {
  return crypto.createHash('sha256').update(`${salt}:${otp}`).digest('hex');
}

exports.requestPasswordResetOtp = functions.https.onCall(async (data, context) => {
  const email = _normalizeEmail(data && data.email);
  if (!email || !email.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid_email');
  }

  const otp = _generateOtp();
  const salt = crypto.randomBytes(16).toString('hex');
  const otpHash = _hashOtp(otp, salt);

  const docId = _docIdForEmail(email);
  const otpRef = db.collection('password_reset_otps').doc(docId);

  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000);

  await otpRef.set({
    email,
    otpHash,
    salt,
    attemptsLeft: 5,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Trigger Email extension: write to `mail` collection.
  await db.collection('mail').add({
    to: [email],
    message: {
      subject: 'رمز إعادة تعيين كلمة المرور',
      text: `رمز التحقق الخاص بك هو: ${otp}\n\nينتهي خلال 10 دقائق. إذا لم تطلب ذلك فتجاهل هذه الرسالة.`,
    },
  });

  // Always return success without revealing whether the email exists.
  return { ok: true };
});

exports.confirmPasswordResetWithOtp = functions.https.onCall(async (data, context) => {
  const email = _normalizeEmail(data && data.email);
  const otp = String((data && data.otp) || '').trim();
  const newPassword = String((data && data.newPassword) || '').trim();

  if (!email || !email.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid_email');
  }
  if (!otp || otp.length < 4) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid_otp');
  }
  if (!newPassword || newPassword.length < 6) {
    throw new functions.https.HttpsError('invalid-argument', 'weak_password');
  }

  const docId = _docIdForEmail(email);
  const otpRef = db.collection('password_reset_otps').doc(docId);
  const snap = await otpRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'otp_invalid');
  }

  const record = snap.data() || {};
  const expiresAt = record.expiresAt;
  const attemptsLeft = Number(record.attemptsLeft || 0);

  if (!expiresAt || expiresAt.toMillis() < Date.now()) {
    await otpRef.delete().catch(() => null);
    throw new functions.https.HttpsError('permission-denied', 'otp_expired');
  }

  if (attemptsLeft <= 0) {
    await otpRef.delete().catch(() => null);
    throw new functions.https.HttpsError('resource-exhausted', 'otp_locked');
  }

  const computed = _hashOtp(otp, record.salt || '');
  if (computed !== record.otpHash) {
    await otpRef.set({
      attemptsLeft: attemptsLeft - 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    throw new functions.https.HttpsError('permission-denied', 'otp_invalid');
  }

  // OTP correct: update password via Admin SDK.
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: newPassword });

  await otpRef.delete().catch(() => null);
  return { ok: true };
});

// ============================================
// 🌐 Nitro Direct Handler for React App (SSR/SPA)
// Nitro is built with the Cloudflare preset → exports a Fetch API handler.
// We bridge the Firebase/Node req→Response without an internal HTTP port.
// ============================================

let nitroApp = null;
let nitroLoadPromise = null;

function loadNitro() {
  if (nitroApp) return Promise.resolve(nitroApp);
  if (nitroLoadPromise) return nitroLoadPromise;
  nitroLoadPromise = import('./.output/server/index.mjs')
    .then((mod) => {
      // The Cloudflare preset exports a default object with a `fetch` method.
      nitroApp = mod.default;
      nitroLoadPromise = null;
      return nitroApp;
    })
    .catch((err) => {
      console.error('Failed to load Nitro app:', err);
      nitroLoadPromise = null;
      throw err;
    });
  return nitroLoadPromise;
}

exports.server = functions.https.onRequest(async (req, res) => {
  let app;
  try {
    app = await loadNitro();
  } catch (err) {
    res.status(500).send('Failed to load server: ' + err.message);
    return;
  }

  try {
    // Build a full URL from the incoming request.
    const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost';
    const proto = req.headers['x-forwarded-proto'] || 'https';
    const url = `${proto}://${host}${req.url}`;

    // Read body into a Buffer so we can pass it to the Fetch Request.
    const body = await new Promise((resolve, reject) => {
      const chunks = [];
      req.on('data', (chunk) => chunks.push(chunk));
      req.on('end', () => resolve(Buffer.concat(chunks)));
      req.on('error', reject);
    });

    // Build a Web Fetch API Request.
    const fetchRequest = new Request(url, {
      method: req.method,
      headers: req.headers,
      body: ['GET', 'HEAD'].includes(req.method) ? undefined : body,
    });

    // Build a Cloudflare-compatible execution context with waitUntil.
    // Nitro's augmentReq calls ctx.context?.waitUntil.bind(ctx.context),
    // so we must provide a real function or it crashes.
    const execCtx = {
      waitUntil: (promise) => { promise && promise.catch && promise.catch(() => {}); },
      passThroughOnException: () => {},
    };

    // Call Nitro's fetch handler (Cloudflare style: fetch(request, env, context)).
    const fetchResponse = await app.fetch(fetchRequest, {}, execCtx);

    // Write status + headers to Express-compatible res.
    res.status(fetchResponse.status);
    fetchResponse.headers.forEach((value, key) => {
      // skip hop-by-hop headers
      if (!['transfer-encoding', 'connection'].includes(key.toLowerCase())) {
        res.setHeader(key, value);
      }
    });

    // Stream body.
    if (fetchResponse.body) {
      const reader = fetchResponse.body.getReader();
      const pump = async () => {
        const { done, value } = await reader.read();
        if (done) { res.end(); return; }
        res.write(value);
        return pump();
      };
      await pump();
    } else {
      res.end();
    }
  } catch (err) {
    console.error('Nitro handler error:', err);
    res.status(500).send('Server error: ' + err.message);
  }
});

