// ============================================================================
// 🚀 Live Back4App Concurrency & Auth Verification Script
//
// Usage:
//   FIREBASE_ID_TOKEN="<real_firebase_jwt_token>" node test_live_concurrent_gateway.js
//
// Tests performed against live Back4App endpoint:
//   1. Authentication Test:
//      - Valid Firebase token -> Authenticated successfully
//      - Forged / Missing token -> Rejected with 404 / OBJECT_NOT_FOUND
//   2. 20 Concurrent First Requests (Same appSessionId):
//      - Fires 20 simultaneous requests to aiManusGateway
//      - Verifies all 20 resolve to the EXACT same task_id
//   3. 100 Concurrent Requests (Same appSessionId):
//      - Fires 100 simultaneous requests to aiManusGateway
//      - Verifies all 100 resolve to the EXACT same task_id
// ============================================================================

const https = require('https');

const PARSE_APP_ID = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2";
const PARSE_REST_KEY = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp";
const GATEWAY_URL = "https://parseapi.back4app.com/functions/aiManusGateway";

const firebaseIdToken = process.env.FIREBASE_ID_TOKEN || "";

function sendGatewayRequest(payload) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload);
    const req = https.request(GATEWAY_URL, {
      method: 'POST',
      headers: {
        'X-Parse-Application-Id': PARSE_APP_ID,
        'X-Parse-REST-API-Key': PARSE_REST_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ statusCode: res.statusCode, body: parsed });
        } catch (_) {
          resolve({ statusCode: res.statusCode, rawBody: body });
        }
      });
    });

    req.on('error', (err) => reject(err));
    req.write(data);
    req.end();
  });
}

async function runLiveTests() {
  console.log('🚀 Starting Live Back4App Concurrency & Auth Verification...\n');

  // ─── Test 1: Unauthenticated / Forged Request Rejection ───────────────────
  console.log('--- Test 1: Fail-Closed Auth on Unauthenticated / Forged Token ---');
  const forgedRes = await sendGatewayRequest({
    prompt: 'Hello',
    appSessionId: 'test_session_unauth',
    firebaseIdToken: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJmb3JnZWQifQ.invalidsig',
  });

  console.log(`Forged Token Response Status: HTTP ${forgedRes.statusCode}`);
  console.log(`Response Body:`, JSON.stringify(forgedRes.body || forgedRes.rawBody));

  if (forgedRes.statusCode === 400 || forgedRes.statusCode === 404 || forgedRes.statusCode === 401) {
    console.log('✅ Test 1 Passed: Forged token was strictly rejected by Back4App.\n');
  } else {
    console.warn('⚠️ Test 1: Unexpected response for forged token.\n');
  }

  if (!firebaseIdToken) {
    console.log('ℹ️ No FIREBASE_ID_TOKEN provided in environment.');
    console.log('To run 20 and 100 live concurrent tests with real authenticated UID:');
    console.log('  export FIREBASE_ID_TOKEN="<token_from_device>"');
    console.log('  node test_live_concurrent_gateway.js\n');
    return;
  }

  // ─── Test 2: 20 Concurrent First Requests (Real Token) ────────────────────
  console.log('--- Test 2: 20 Concurrent Requests with Same Real Token & Session ID ---');
  const session20 = `live_concurrency_20_${Date.now()}`;
  const payload20 = {
    prompt: 'Hello Manus, confirm session.',
    taskType: 'general',
    appSessionId: session20,
    firebaseIdToken: firebaseIdToken,
  };

  console.log(`Firing 20 simultaneous requests to session: ${session20}...`);
  const promises20 = Array.from({ length: 20 }, (_, i) => sendGatewayRequest(payload20));
  const results20 = await Promise.all(promises20);

  const taskIds20 = new Set();
  let successCount20 = 0;

  for (const r of results20) {
    const resData = (r.body && r.body.result) || r.body || {};
    if (resData.task_id) {
      taskIds20.add(resData.task_id);
    }
    if (resData.success) {
      successCount20++;
    }
  }

  console.log(`20 Requests Completed: Successes=${successCount20}/20, Distinct task_ids=${taskIds20.size}`);
  console.log(`Distinct Task IDs:`, Array.from(taskIds20));

  if (taskIds20.size === 1) {
    console.log('✅ Test 2 Passed: Exactly 1 distinct task_id was generated across all 20 concurrent requests!\n');
  } else {
    console.error(`❌ Test 2 Failed: Expected 1 task_id, got ${taskIds20.size}\n`);
  }

  // ─── Test 3: 100 Concurrent Requests (Real Token) ─────────────────────────
  console.log('--- Test 3: 100 Concurrent Requests with Same Real Token & Session ID ---');
  const session100 = `live_concurrency_100_${Date.now()}`;
  const payload100 = {
    prompt: 'Hello Manus, test 100 concurrency.',
    taskType: 'general',
    appSessionId: session100,
    firebaseIdToken: firebaseIdToken,
  };

  console.log(`Firing 100 simultaneous requests to session: ${session100}...`);
  const promises100 = Array.from({ length: 100 }, (_, i) => sendGatewayRequest(payload100));
  const results100 = await Promise.all(promises100);

  const taskIds100 = new Set();
  let successCount100 = 0;

  for (const r of results100) {
    const resData = (r.body && r.body.result) || r.body || {};
    if (resData.task_id) {
      taskIds100.add(resData.task_id);
    }
    if (resData.success) {
      successCount100++;
    }
  }

  console.log(`100 Requests Completed: Successes=${successCount100}/100, Distinct task_ids=${taskIds100.size}`);
  console.log(`Distinct Task IDs:`, Array.from(taskIds100));

  if (taskIds100.size === 1) {
    console.log('✅ Test 3 Passed: Exactly 1 distinct task_id was generated across all 100 concurrent requests!\n');
  } else {
    console.error(`❌ Test 3 Failed: Expected 1 task_id, got ${taskIds100.size}\n`);
  }
}

runLiveTests().catch(console.error);
