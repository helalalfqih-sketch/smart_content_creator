const admin = require('firebase-admin');
const { Worker, QueueScheduler } = require('bullmq');
const IORedis = require('ioredis');
const path = require('path');
const { spawn } = require('child_process');
const tmp = require('tmp-promise');

admin.initializeApp();
const db = admin.firestore();

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const BUCKET_NAME = process.env.BUCKET_NAME || 'default-bucket';
const MAX_RENDER_MS = parseInt(process.env.MAX_RENDER_MS || String(5 * 60 * 1000));
const connection = new IORedis(REDIS_URL);

const queueName = 'render';

function runFfmpeg(inputPath, outputPath, ffmpegArgs = [], jobId) {
  return new Promise((resolve, reject) => {
    const args = ['-y', '-i', inputPath, ...ffmpegArgs, outputPath];
    const proc = spawn('ffmpeg', args);

    let stderr = '';
    proc.stderr.on('data', (d) => { 
      stderr += d.toString(); 
      // Basic progress parsing could be added here
    });

    const killTimer = setTimeout(() => {
      proc.kill('SIGKILL');
      reject(new Error('ffmpeg timeout'));
    }, MAX_RENDER_MS);

    proc.on('close', (code) => {
      clearTimeout(killTimer);
      if (code === 0) {
        resolve(stderr); 
      } else {
        reject(new Error('ffmpeg failed code=' + code));
      }
    });
  });
}

const worker = new Worker(queueName, async (job) => {
  const data = job.data;
  const jobId = data.jobId;
  const jobRef = db.collection('jobs').doc(jobId);

  try {
    await db.runTransaction(async (t) => {
      const doc = await t.get(jobRef);
      if (!doc.exists) throw new Error('jobNotFound');
      if (doc.data().status !== 'queued') throw new Error('invalid_status');
      t.update(jobRef, { status: 'processing', startedAt: admin.firestore.FieldValue.serverTimestamp() });
    });
  } catch (e) {
    throw e;
  }

  const bucket = admin.storage().bucket(BUCKET_NAME);
  const inputPath = data.input.storagePath;
  const tmpDir = await tmp.dir({ unsafeCleanup: true });
  const inputLocal = path.join(tmpDir.path, 'input');
  const outputLocal = path.join(tmpDir.path, 'output.mp4');

  try {
    // Note: Local execution mock (for real environment, ensure you have credentials)
    // await bucket.file(inputPath).download({ destination: inputLocal });
    
    // FFmpeg Processing Mock (will fail locally without real input unless configured)
    // const ffmpegArgs = ['-c:v', 'libx264', '-preset', 'fast'];
    // await runFfmpeg(inputLocal, outputLocal, ffmpegArgs, jobId);

    // MOCK Output
    const outStoragePath = `outputs/${data.userId}/${jobId}/output.mp4`;
    
    // await bucket.upload(outputLocal, { destination: outStoragePath });

    await jobRef.update({
      status: 'done',
      result: { storagePath: outStoragePath },
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await tmpDir.cleanup();
    return { result: outStoragePath };
  } catch (err) {
    await jobRef.update({
      status: 'failed',
      errorMessage: err.message,
      finishedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    try { await tmpDir.cleanup(); } catch (_) {}
    throw err;
  }
}, { connection, concurrency: 1 });

console.log("Worker started, listening for render jobs...");
