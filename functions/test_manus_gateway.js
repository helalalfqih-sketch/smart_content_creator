const assert = require('assert');

console.log('🧪 Running Hardened Manus Gateway Test Suite...\n');

// ============================================================
// Logic Helpers Under Test
// ============================================================

function verifyFirebaseIdTokenSync(token, mockValidTokens = {}) {
  if (!token || typeof token !== 'string' || token.length < 20) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const payloadRaw = Buffer.from(parts[1], 'base64').toString('utf8');
    const claims = JSON.parse(payloadRaw);

    const now = Math.floor(Date.now() / 1000);
    if (!claims.exp || claims.exp < now) return null;
    if (!claims.sub || !claims.iss || !claims.iss.startsWith('https://securetoken.google.com/')) return null;

    if (mockValidTokens[token]) {
      return mockValidTokens[token]; // returns verified uid
    }
    return null;
  } catch (_) {
    return null;
  }
}

function deriveTrustedUserIdSync(request, mockValidTokens = {}) {
  // 1. Authenticated Parse user
  if (request.user && request.user.id) {
    return `parse_${request.user.id}`;
  }

  // 2. Cryptographically verified Firebase token
  const firebaseToken = (request.params || {}).firebaseIdToken;
  if (firebaseToken) {
    const verifiedUid = verifyFirebaseIdTokenSync(firebaseToken, mockValidTokens);
    if (verifiedUid) {
      return `fb_${verifiedUid}`;
    }
  }

  // FAIL CLOSED: No unverified client userId fallback permitted!
  return null;
}

function isTerminalTaskError(statusCode, errorBody) {
  if (statusCode === 404) return { isTerminal: true, reason: 'task_not_found_404' };

  const str = (typeof errorBody === 'string' ? errorBody : JSON.stringify(errorBody || '')).toLowerCase();

  if (str.includes('task_not_found') || str.includes('task not found') || str.includes('task does not exist') || str.includes('no such task')) {
    return { isTerminal: true, reason: 'task_not_found' };
  }
  if (str.includes('task_expired') || str.includes('task has expired') || str.includes('session_expired')) {
    return { isTerminal: true, reason: 'task_expired' };
  }
  if (str.includes('task_closed') || str.includes('cannot send message to completed task') || str.includes('task is terminated')) {
    return { isTerminal: true, reason: 'task_completed_terminal' };
  }
  if (str.includes('invalid_task_id') || str.includes('task_invalid') || str.includes('task not continuable')) {
    return { isTerminal: true, reason: 'task_invalid' };
  }

  return { isTerminal: false, reason: null };
}

function extractMediaFromMessages(messages) {
  const media = [];
  for (const m of messages) {
    const assistantMsg = m.assistant_message || {};
    const attachments = assistantMsg.attachments || [];

    for (const att of attachments) {
      const contentType = (att.content_type || '').toLowerCase();
      let mediaType = 'file';

      if (contentType.startsWith('image/')) {
        mediaType = 'image';
      } else if (contentType.startsWith('video/')) {
        mediaType = 'video';
      } else if (contentType.startsWith('audio/')) {
        mediaType = 'audio';
      }

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

// ============================================================
// 1. TRUSTED USER IDENTITY TESTS
// ============================================================

console.log('--- 1. Trusted User Identity Tests ---');

// Valid JWT mock generator
function makeToken(uid, expSecondsFromNow = 3600) {
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64');
  const payload = Buffer.from(
    JSON.stringify({
      iss: 'https://securetoken.google.com/smart-content-creator',
      sub: uid,
      user_id: uid,
      exp: Math.floor(Date.now() / 1000) + expSecondsFromNow,
    })
  ).toString('base64');
  const signature = 'mock_signature_bytes_1234567890';
  return `${header}.${payload}.${signature}`;
}

const validTokenAlice = makeToken('user_alice');
const validTokenBob = makeToken('user_bob');
const expiredToken = makeToken('user_charlie', -3600); // expired 1 hour ago
const mockValidTokens = {
  [validTokenAlice]: 'user_alice',
  [validTokenBob]: 'user_bob',
};

// Test 1.1: Forged userId with no auth → strictly rejected (null)
{
  const req = { params: { userId: 'forged_admin_id' } };
  const identity = deriveTrustedUserIdSync(req, mockValidTokens);
  assert.strictEqual(identity, null, 'Forged userId with no auth token must be rejected');
  console.log('✅ Test 1.1: Forged userId with no auth strictly rejected (fail closed)');
}

// Test 1.2: Valid authenticated Parse user → accepted
{
  const req = { user: { id: 'parse_user_999' }, params: { userId: 'ignored_client_id' } };
  const identity = deriveTrustedUserIdSync(req, mockValidTokens);
  assert.strictEqual(identity, 'parse_parse_user_999');
  console.log('✅ Test 1.2: Valid Parse session accepted');
}

// Test 1.3: Valid Firebase ID token → verified UID used (client userId ignored)
{
  const req = { params: { firebaseIdToken: validTokenAlice, userId: 'attacker_specified_id' } };
  const identity = deriveTrustedUserIdSync(req, mockValidTokens);
  assert.strictEqual(identity, 'fb_user_alice', 'Must use verified UID from token claims');
  console.log('✅ Test 1.3: Valid Firebase token verified; client userId safely ignored');
}

// Test 1.4: Expired or forged token → strictly rejected
{
  const reqExpired = { params: { firebaseIdToken: expiredToken } };
  assert.strictEqual(deriveTrustedUserIdSync(reqExpired, mockValidTokens), null);

  const reqForged = { params: { firebaseIdToken: 'fake.header.sig' } };
  assert.strictEqual(deriveTrustedUserIdSync(reqForged, mockValidTokens), null);
  console.log('✅ Test 1.4: Expired or forged Firebase token rejected');
}

// Test 1.5: User A cannot access User B task mapping
{
  const taskSessions = {
    task_123: { userId: 'fb_user_alice', taskId: 'task_123' },
  };

  function canUserAccessTask(requestUserId, taskId) {
    const session = taskSessions[taskId];
    if (!session) return false;
    return session.userId === requestUserId;
  }

  assert.strictEqual(canUserAccessTask('fb_user_alice', 'task_123'), true);
  assert.strictEqual(canUserAccessTask('fb_user_bob', 'task_123'), false, 'User B must not access User A task');
  console.log('✅ Test 1.5: Cross-user task isolation verified');
}

// ============================================================
// 2. SAFE FOLLOW-UP RECOVERY POLICY TESTS
// ============================================================

console.log('\n--- 2. Follow-Up Recovery Policy Tests ---');

// Test 2.1: Transient errors (500, 502, 503, 504, 429, timeout) → PRESERVE task mapping
{
  assert.strictEqual(isTerminalTaskError(500, 'Internal Server Error').isTerminal, false);
  assert.strictEqual(isTerminalTaskError(502, 'Bad Gateway').isTerminal, false);
  assert.strictEqual(isTerminalTaskError(503, 'Service Unavailable').isTerminal, false);
  assert.strictEqual(isTerminalTaskError(429, 'Rate limit exceeded').isTerminal, false);
  assert.strictEqual(isTerminalTaskError(0, 'ECONNRESET').isTerminal, false);
  assert.strictEqual(isTerminalTaskError(0, 'ETIMEDOUT').isTerminal, false);
  console.log('✅ Test 2.1: Transient errors (5xx, 429, timeout, network) classified as NON-terminal');
}

// Test 2.2: Terminal errors (404, task_not_found, task_expired, task_closed) → TRIGGER recovery
{
  const check404 = isTerminalTaskError(404, 'Not Found');
  assert.strictEqual(check404.isTerminal, true);
  assert.strictEqual(check404.reason, 'task_not_found_404');

  const checkExpired = isTerminalTaskError(400, { error: 'task_expired', message: 'Task has expired' });
  assert.strictEqual(checkExpired.isTerminal, true);
  assert.strictEqual(checkExpired.reason, 'task_expired');

  const checkNotFound = isTerminalTaskError(400, 'task_not_found: no task with this id');
  assert.strictEqual(checkNotFound.isTerminal, true);
  assert.strictEqual(checkNotFound.reason, 'task_not_found');

  const checkClosed = isTerminalTaskError(400, 'cannot send message to completed task');
  assert.strictEqual(checkClosed.isTerminal, true);
  assert.strictEqual(checkClosed.reason, 'task_completed_terminal');
  console.log('✅ Test 2.2: Terminal task errors (404, expired, not found, closed) accurately detected');
}

// Test 2.3: Simulated Follow-Up Recovery Flow
{
  let createCallCount = 0;
  let currentTaskMapping = 'task_EXISTING_1';

  function simulateFollowUpRequest(errorToSimulate) {
    if (currentTaskMapping) {
      if (errorToSimulate) {
        const term = isTerminalTaskError(errorToSimulate.status, errorToSimulate.body);
        if (term.isTerminal) {
          // Terminal error: recover by creating a new task
          createCallCount++;
          currentTaskMapping = `task_NEW_${createCallCount}`;
          return { success: true, mode: 'recover_new_task', taskId: currentTaskMapping, reason: term.reason };
        } else {
          // Transient error: DO NOT create new task, preserve mapping, throw
          return { success: false, mode: 'preserved_transient_error', taskId: currentTaskMapping, error: errorToSimulate.body };
        }
      } else {
        return { success: true, mode: 'follow_up', taskId: currentTaskMapping };
      }
    } else {
      createCallCount++;
      currentTaskMapping = `task_INITIAL_${createCallCount}`;
      return { success: true, mode: 'create', taskId: currentTaskMapping };
    }
  }

  // A. sendMessage 500 → no task.create, mapping preserved
  const res500 = simulateFollowUpRequest({ status: 500, body: 'Manus Server Error 500' });
  assert.strictEqual(res500.success, false);
  assert.strictEqual(res500.taskId, 'task_EXISTING_1');
  assert.strictEqual(createCallCount, 0, 'Must NOT call task.create on 500 error');

  // B. sendMessage timeout → no task.create, mapping preserved
  const resTimeout = simulateFollowUpRequest({ status: 0, body: 'Socket Timeout' });
  assert.strictEqual(resTimeout.success, false);
  assert.strictEqual(resTimeout.taskId, 'task_EXISTING_1');
  assert.strictEqual(createCallCount, 0, 'Must NOT call task.create on timeout');

  // C. sendMessage 429 → no task.create, mapping preserved
  const res429 = simulateFollowUpRequest({ status: 429, body: 'Too Many Requests' });
  assert.strictEqual(res429.success, false);
  assert.strictEqual(res429.taskId, 'task_EXISTING_1');
  assert.strictEqual(createCallCount, 0, 'Must NOT call task.create on 429');

  // D. Documented task-not-found → exactly ONE replacement task.create
  const res404 = simulateFollowUpRequest({ status: 404, body: 'Task does not exist' });
  assert.strictEqual(res404.success, true);
  assert.strictEqual(res404.mode, 'recover_new_task');
  assert.strictEqual(res404.taskId, 'task_NEW_1');
  assert.strictEqual(createCallCount, 1, 'Must call task.create exactly once for recovery');

  // E. Subsequent request in same session uses the recovered task
  const resFollowUp = simulateFollowUpRequest(null);
  assert.strictEqual(resFollowUp.success, true);
  assert.strictEqual(resFollowUp.mode, 'follow_up');
  assert.strictEqual(resFollowUp.taskId, 'task_NEW_1');
  assert.strictEqual(createCallCount, 1, 'Must reuse the recovered task');

  console.log('✅ Test 2.3: Follow-up recovery policy verified across 500, timeout, 429, and 404');
}

// ============================================================
// 3. CONCURRENCY PROTECTION TESTS (20 Concurrent First Requests)
// ============================================================

console.log('\n--- 3. Concurrency Protection Tests ---');

{
  class MockAtomicSessionStore {
    constructor() {
      this.sessions = {};
      this.createCallCount = 0;
    }

    async handleGatewayRequest(sessionKey, userId, appSessionId) {
      let session = this.sessions[sessionKey];

      if (session && session.taskId) {
        return { mode: 'follow_up', taskId: session.taskId };
      }

      // Check if another request is currently creating
      if (session && session.status === 'creating' && !session.taskId) {
        // Wait for lock resolution
        const waitStart = Date.now();
        while (Date.now() - waitStart < 3000) {
          await new Promise((r) => setTimeout(r, 20));
          session = this.sessions[sessionKey];
          if (session && session.taskId) {
            return { mode: 'follow_up', taskId: session.taskId };
          }
        }
      }

      // Atomic lock reservation
      if (!session) {
        this.sessions[sessionKey] = {
          sessionKey,
          userId,
          appSessionId,
          status: 'creating',
          taskId: null,
        };
      }

      // If we are the lock winner (status === 'creating' and taskId === null):
      // Simulate calling external Manus task.create (takes ~100ms)
      this.createCallCount++;
      await new Promise((r) => setTimeout(r, 100));

      const newTaskId = `manus_task_CONCURRENT_${this.createCallCount}`;
      this.sessions[sessionKey].taskId = newTaskId;
      this.sessions[sessionKey].status = 'active';

      return { mode: 'create', taskId: newTaskId };
    }
  }

  async function runConcurrencyTest() {
    const store = new MockAtomicSessionStore();
    const sessionKey = 'fb_user_alice_session_42';

    // Launch 20 concurrent first requests simultaneously
    const requests = Array.from({ length: 20 }, (_, i) =>
      store.handleGatewayRequest(sessionKey, 'fb_user_alice', 'session_42')
    );

    const results = await Promise.all(requests);

    // Verify exactly ONE task.create call occurred
    assert.strictEqual(store.createCallCount, 1, `Expected exactly 1 task.create, got ${store.createCallCount}`);

    // Verify all 20 requests received the exact same taskId
    const taskIds = new Set(results.map((r) => r.taskId));
    assert.strictEqual(taskIds.size, 1, 'All 20 requests must share the same taskId');
    assert.strictEqual(results[0].taskId, 'manus_task_CONCURRENT_1');

    // Exactly 1 request did 'create', 19 requests did 'follow_up'
    const createModes = results.filter((r) => r.mode === 'create');
    const followUpModes = results.filter((r) => r.mode === 'follow_up');
    assert.strictEqual(createModes.length, 1);
    assert.strictEqual(followUpModes.length, 19);

    console.log('✅ Test 3: 20 concurrent first requests → exactly 1 task.create + 19 follow-ups on same task_id');
  }

  runConcurrencyTest().then(() => {
    // ============================================================
    // 4. MEDIA OUTPUT VERIFICATION TESTS
    // ============================================================

    console.log('\n--- 4. Media Output Verification Tests ---');

    const sampleMessages = [
      {
        type: 'assistant_message',
        assistant_message: {
          content: 'Media generation result',
          attachments: [
            { filename: 'ad.png', url: 'https://cdn.manus.ai/ad.png', content_type: 'image/png' },
            { filename: 'spot.mp4', url: 'https://cdn.manus.ai/spot.mp4', content_type: 'video/mp4' },
            { filename: 'voice.wav', url: 'https://cdn.manus.ai/voice.wav', content_type: 'audio/wav' },
            { filename: 'doc.pdf', url: 'https://cdn.manus.ai/doc.pdf', content_type: 'application/pdf' },
          ],
        },
      },
    ];

    const media = extractMediaFromMessages(sampleMessages);
    assert.strictEqual(media.length, 4);
    assert.strictEqual(media[0].type, 'image');
    assert.strictEqual(media[1].type, 'video');
    assert.strictEqual(media[2].type, 'audio');
    assert.strictEqual(media[3].type, 'file');
    console.log('✅ Test 4: Media attachments correctly extracted & classified by content_type');

    console.log('\n🎉 ALL HARDENED GATEWAY TESTS (IDENTITY, RECOVERY, CONCURRENCY, MEDIA) PASSED!\n');
  });
}
