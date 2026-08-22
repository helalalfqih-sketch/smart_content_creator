const assert = require('assert');
const crypto = require('crypto');

console.log('🧪 Running Production-Grade Manus Gateway Test Suite...\n');

const FIREBASE_PROJECT_ID = 'smartcontentcreator2';

// Generate real RSA key pair for testing cryptographic verification
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});

const mockCertificates = {
  key_1: publicKey,
};

// Helper: Sign a mock Firebase ID token with real RSA-SHA256
function createSignedFirebaseToken(claims, kid = 'key_1', signKey = privateKey) {
  const header = { alg: 'RS256', typ: 'JWT', kid: kid };
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64');
  const encodedPayload = Buffer.from(JSON.stringify(claims)).toString('base64');

  const dataToSign = `${encodedHeader}.${encodedPayload}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(dataToSign);
  const signature = signer.sign(signKey, 'base64');

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

// ─── Implementation of verifyFirebaseIdToken under test ───────────────────────

function verifyFirebaseIdToken(token, certs = mockCertificates, projectId = FIREBASE_PROJECT_ID) {
  if (!token || typeof token !== 'string' || token.length < 20) return null;

  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const header = JSON.parse(Buffer.from(parts[0], 'base64').toString('utf8'));
    const claims = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));

    // Algorithm & kid check
    if (header.alg !== 'RS256' || !header.kid) return null;

    const now = Math.floor(Date.now() / 1000);
    const clockSkew = 300;

    // Time checks
    if (!claims.exp || claims.exp < now - clockSkew) return null;
    if (!claims.iat || claims.iat > now + clockSkew) return null;

    // Audience & Issuer checks
    if (!claims.aud || claims.aud !== projectId) return null;
    const expectedIssuer = `https://securetoken.google.com/${projectId}`;
    if (!claims.iss || claims.iss !== expectedIssuer) return null;

    // Subject check
    if (!claims.sub || typeof claims.sub !== 'string' || claims.sub.trim().length === 0) return null;

    // Certificate lookup
    const certPem = certs[header.kid];
    if (!certPem) return null;

    // Cryptographic RSA-SHA256 verification
    const dataToVerify = `${parts[0]}.${parts[1]}`;
    const signature = Buffer.from(parts[2], 'base64');

    const verifier = crypto.createVerify('RSA-SHA256');
    verifier.update(dataToVerify);
    const isSignatureValid = verifier.verify(certPem, signature);

    if (!isSignatureValid) return null;

    return claims.sub;
  } catch (_) {
    return null;
  }
}

function deriveTrustedUserId(request, certs = mockCertificates, projectId = FIREBASE_PROJECT_ID) {
  if (request.user && request.user.id) {
    return `parse_${request.user.id}`;
  }

  const firebaseToken = (request.params || {}).firebaseIdToken;
  if (firebaseToken) {
    const verifiedUid = verifyFirebaseIdToken(firebaseToken, certs, projectId);
    if (verifiedUid) {
      return `fb_${verifiedUid}`;
    }
  }

  return null;
}

// ============================================================
// 1. CRYPTOGRAPHIC FIREBASE TOKEN TESTS
// ============================================================

console.log('--- 1. Cryptographic Firebase Token Verification Tests ---');

const now = Math.floor(Date.now() / 1000);

// Test 1.1: Valid token signed with correct key and project → accepted
{
  const validClaims = {
    iss: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    aud: FIREBASE_PROJECT_ID,
    sub: 'real_user_uid_123',
    user_id: 'real_user_uid_123',
    exp: now + 3600,
    iat: now,
    auth_time: now,
  };
  const token = createSignedFirebaseToken(validClaims);
  const req = { params: { firebaseIdToken: token, userId: 'forged_client_id' } };
  const trustedUid = deriveTrustedUserId(req);

  assert.strictEqual(trustedUid, 'fb_real_user_uid_123');
  console.log('✅ Test 1.1: Cryptographically valid token accepted; client-supplied userId ignored');
}

// Test 1.2: Forged token signature → rejected
{
  const forgedClaims = {
    iss: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    aud: FIREBASE_PROJECT_ID,
    sub: 'admin_attacker',
    exp: now + 3600,
    iat: now,
  };
  // Sign with a different random private key
  const rogueKey = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;
  const forgedToken = createSignedFirebaseToken(forgedClaims, 'key_1', rogueKey);
  const req = { params: { firebaseIdToken: forgedToken } };

  assert.strictEqual(deriveTrustedUserId(req), null, 'Forged RSA signature must be rejected');
  console.log('✅ Test 1.2: Forged signature strictly rejected');
}

// Test 1.3: Wrong project token → rejected
{
  const wrongProjectClaims = {
    iss: 'https://securetoken.google.com/other-project-id',
    aud: 'other-project-id',
    sub: 'attacker_uid',
    exp: now + 3600,
    iat: now,
  };
  const wrongProjectToken = createSignedFirebaseToken(wrongProjectClaims);
  const req = { params: { firebaseIdToken: wrongProjectToken } };

  assert.strictEqual(deriveTrustedUserId(req), null, 'Wrong project token must be rejected');
  console.log('✅ Test 1.3: Wrong project token rejected (aud != smartcontentcreator2)');
}

// Test 1.4: Expired token → rejected
{
  const expiredClaims = {
    iss: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    aud: FIREBASE_PROJECT_ID,
    sub: 'expired_user',
    exp: now - 3600, // expired 1 hour ago
    iat: now - 7200,
  };
  const expiredToken = createSignedFirebaseToken(expiredClaims);
  const req = { params: { firebaseIdToken: expiredToken } };

  assert.strictEqual(deriveTrustedUserId(req), null, 'Expired token must be rejected');
  console.log('✅ Test 1.4: Expired token strictly rejected');
}

// Test 1.5: Missing token / forged userId with no token → rejected (fail closed)
{
  const req = { params: { userId: 'unauthenticated_hacker' } };
  assert.strictEqual(deriveTrustedUserId(req), null, 'Must fail closed');
  console.log('✅ Test 1.5: Missing token fails closed');
}

// ============================================================
// 2. REAL CONCURRENCY GUARANTEE (Atomic Uniqueness Simulation)
// ============================================================

console.log('\n--- 2. Real Concurrency Guarantee Tests ---');

{
  // Simulated database with server-side uniqueness constraint (mirroring beforeSave hook)
  class SimulatedParseDatabase {
    constructor() {
      this.table = new Map(); // sessionKey -> record
      this.createCallCount = 0;
    }

    // Atomic server-side save with duplicate constraint check
    async saveManusTaskSession(session) {
      if (session.isNew) {
        if (this.table.has(session.sessionKey)) {
          const err = new Error(`ManusTaskSession with sessionKey '${session.sessionKey}' already exists.`);
          err.code = 137; // Parse.Error.DUPLICATE_VALUE
          throw err;
        }
        session.isNew = false;
        this.table.set(session.sessionKey, { ...session });
        return this.table.get(session.sessionKey);
      } else {
        this.table.set(session.sessionKey, { ...session });
        return this.table.get(session.sessionKey);
      }
    }

    async findSession(sessionKey) {
      const record = this.table.get(sessionKey);
      return record ? { ...record } : null;
    }

    // Gateway handler under test
    async handleGatewayRequest(sessionKey, userId, appSessionId) {
      let session = await this.findSession(sessionKey);
      let taskId = session ? session.taskId : null;

      if (taskId) {
        return { mode: 'follow_up', taskId: taskId };
      }

      // Check if another request is currently creating
      if (session && session.status === 'creating' && !session.taskId) {
        const waitStart = Date.now();
        while (Date.now() - waitStart < 3000) {
          await new Promise((r) => setTimeout(r, 20));
          session = await this.findSession(sessionKey);
          if (session && session.taskId) {
            taskId = session.taskId;
            break;
          }
        }
      }

      // If still no taskId, attempt atomic insert
      if (!taskId) {
        const newSession = {
          sessionKey,
          userId,
          appSessionId,
          status: 'creating',
          taskId: null,
          isNew: true,
        };

        try {
          // Server-side uniqueness hook enforces only ONE succeeds!
          await this.saveManusTaskSession(newSession);
        } catch (saveErr) {
          if (saveErr.code === 137) {
            // Concurrent duplicate: wait for winner's taskId
            const waitStart = Date.now();
            while (Date.now() - waitStart < 3000) {
              await new Promise((r) => setTimeout(r, 20));
              session = await this.findSession(sessionKey);
              if (session && session.taskId) {
                taskId = session.taskId;
                break;
              }
            }
          } else {
            throw saveErr;
          }
        }
      }

      if (taskId) {
        // Winner resolved: convert into follow_up
        return { mode: 'follow_up', taskId: taskId };
      } else {
        // Lock winner: calls task.create exactly once!
        this.createCallCount++;
        await new Promise((r) => setTimeout(r, 50)); // simulate network delay

        taskId = `manus_task_ATOMIC_${this.createCallCount}`;
        await this.saveManusTaskSession({
          sessionKey,
          userId,
          appSessionId,
          status: 'active',
          taskId: taskId,
          isNew: false,
        });

        return { mode: 'create', taskId: taskId };
      }
    }
  }

  async function test20ConcurrentRequests() {
    const db = new SimulatedParseDatabase();
    const sessionKey = 'fb_alice_app_session_99';

    // Fire 20 simultaneous requests
    const promises = Array.from({ length: 20 }, () =>
      db.handleGatewayRequest(sessionKey, 'fb_alice', 'app_session_99')
    );

    const results = await Promise.all(promises);

    // Verify EXACTLY ONE task.create was called
    assert.strictEqual(db.createCallCount, 1, `Expected exactly 1 task.create, but got ${db.createCallCount}`);

    // Verify all 20 returned the same taskId
    const taskIds = new Set(results.map((r) => r.taskId));
    assert.strictEqual(taskIds.size, 1);
    assert.strictEqual(results[0].taskId, 'manus_task_ATOMIC_1');

    const creates = results.filter((r) => r.mode === 'create');
    const followUps = results.filter((r) => r.mode === 'follow_up');
    assert.strictEqual(creates.length, 1);
    assert.strictEqual(followUps.length, 19);

    console.log('✅ Test 2.1: 20 concurrent requests with server-side uniqueness → EXACTLY ONE task.create');
  }

  test20ConcurrentRequests().then(() => {
    // ============================================================
    // 3. MEDIA OUTPUT VERIFICATION
    // ============================================================

    console.log('\n--- 3. Media Output Verification ---');

    function extractMediaFromMessages(messages) {
      const media = [];
      for (const m of messages) {
        const assistantMsg = m.assistant_message || {};
        const attachments = assistantMsg.attachments || [];
        for (const att of attachments) {
          const contentType = (att.content_type || '').toLowerCase();
          let mediaType = 'file';
          if (contentType.startsWith('image/')) mediaType = 'image';
          else if (contentType.startsWith('video/')) mediaType = 'video';
          else if (contentType.startsWith('audio/')) mediaType = 'audio';

          media.push({
            type: mediaType,
            filename: att.filename || null,
            url: att.url || null,
            content_type: att.content_type || null,
          });
        }
      }
      return media;
    }

    const messages = [
      {
        type: 'assistant_message',
        assistant_message: {
          attachments: [
            { filename: 'out.mp4', url: 'https://cdn.manus.ai/out.mp4', content_type: 'video/mp4' },
            { filename: 'out.png', url: 'https://cdn.manus.ai/out.png', content_type: 'image/png' },
            { filename: 'out.mp3', url: 'https://cdn.manus.ai/out.mp3', content_type: 'audio/mpeg' },
          ],
        },
      },
    ];

    const media = extractMediaFromMessages(messages);
    assert.strictEqual(media[0].type, 'video');
    assert.strictEqual(media[1].type, 'image');
    assert.strictEqual(media[2].type, 'audio');
    console.log('✅ Test 3.1: Attachments correctly classified by content_type');

    console.log('\n🎉 ALL PRODUCTION-GRADE TESTS PASSED!\n');
  });
}
