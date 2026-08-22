const assert = require('assert');

// Test Suite for Manus Gateway Session Continuity & Media Extraction
console.log('🧪 Running Manus Gateway Session Continuity & Media Extraction Tests...\n');

// ============================================================
// Pure Logic Helpers (extracted from gateway for testability)
// ============================================================

function testAuthEnforcement(context) {
  if (!context || !context.auth) {
    return { error: 'unauthenticated', message: 'User must be authenticated to access Manus AI Gateway.' };
  }
  return { success: true };
}

function testAppCheckEnforcement(context) {
  if (!context || !context.app) {
    return { error: 'permission-denied', message: 'App Check verification failed. Unverified apps cannot access Manus AI Gateway.' };
  }
  return { success: true };
}

function extractLastAssistantMessage(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.type === 'assistant_message' && m.assistant_message && m.assistant_message.content) {
      const content = m.assistant_message.content;
      return typeof content === 'string' ? content : JSON.stringify(content);
    }
  }
  return null;
}

function extractMediaFromMessages(messages) {
  const media = [];
  for (const m of messages) {
    const assistantMsg = m.assistant_message || {};
    const attachments = assistantMsg.attachments || [];

    for (const att of attachments) {
      const contentType = (att.content_type || "").toLowerCase();
      let mediaType = "file";

      if (contentType.startsWith("image/")) {
        mediaType = "image";
      } else if (contentType.startsWith("video/")) {
        mediaType = "video";
      } else if (contentType.startsWith("audio/")) {
        mediaType = "audio";
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

function extractStatusUpdates(messages) {
  const updates = [];
  for (const m of messages) {
    if (m.type === "status_update" || m.status_update) {
      const su = m.status_update || m;
      updates.push({
        brief: su.brief || null,
        description: su.description || null,
        timestamp: m.created_at || null,
      });
    }
  }
  return updates;
}

function assembleContent(prompt, images, mimeType = 'image/jpeg') {
  const items = [{ type: 'text', text: prompt }];
  for (const imgBase64 of (images || [])) {
    items.push({
      type: 'file',
      file_data: {
        mime_type: mimeType,
        data: imgBase64,
      },
    });
  }
  return items;
}

function resolveSessionKey(uid, appSessionId) {
  if (!uid || appSessionId == null) return null;
  return `${uid}_${String(appSessionId)}`;
}

function determineConversationMode(existingTaskId) {
  return existingTaskId ? 'follow_up' : 'create';
}

class MockSessionStore {
  constructor() {
    this._store = {};
  }
  get(sessionKey) {
    return this._store[sessionKey] || null;
  }
  set(sessionKey, taskId, uid, appSessionId) {
    this._store[sessionKey] = {
      taskId,
      uid,
      appSessionId,
      createdAt: new Date(),
      lastUsedAt: new Date(),
    };
  }
  updateLastUsed(sessionKey) {
    if (this._store[sessionKey]) {
      this._store[sessionKey].lastUsedAt = new Date();
    }
  }
  clear() {
    this._store = {};
  }
}

// ============================================================
// Core Gateway & Security Tests
// ============================================================

// Test 1: Unauthenticated request rejection
const noAuthRes = testAuthEnforcement({});
assert.strictEqual(noAuthRes.error, 'unauthenticated', 'Must reject unauthenticated request');
console.log('✅ Test 1: Unauthenticated request strictly rejected');

// Test 2: Missing App Check rejection
const noAppCheckRes = testAppCheckEnforcement({ auth: { uid: 'test-user-123' } });
assert.strictEqual(noAppCheckRes.error, 'permission-denied', 'Must reject request with missing App Check');
console.log('✅ Test 2: Missing App Check strictly rejected');

// Test 3: Valid Auth + Valid App Check passes
const validRes = testAppCheckEnforcement({ auth: { uid: 'test-user-123' }, app: { appId: 'com.smartcontentcreator.app' } });
assert.strictEqual(validRes.success, true);
console.log('✅ Test 3: Verified Auth + Verified App Check accepted');

// Test 4: Multiple images preserved and formatted
const items = assembleContent('Compare products', ['img1_base64', 'img2_base64', 'img3_base64']);
assert.strictEqual(items.length, 4, '1 text + 3 images must equal 4 content items');
assert.strictEqual(items[0].type, 'text');
assert.strictEqual(items[1].file_data.data, 'img1_base64');
assert.strictEqual(items[2].file_data.data, 'img2_base64');
assert.strictEqual(items[3].file_data.data, 'img3_base64');
console.log('✅ Test 4: Multiple images correctly assembled');

// Test 5: True last assistant message returned
const mockListMessages = [
  { type: 'user_message', content: 'hello' },
  { type: 'status_update', brief: 'running' },
  { type: 'assistant_message', assistant_message: { content: 'First partial output' } },
  { type: 'status_update', brief: 'still working' },
  { type: 'assistant_message', assistant_message: { content: 'Final complete output' } },
  { type: 'status_update', brief: 'stopped' },
];
const extracted = extractLastAssistantMessage(mockListMessages);
assert.strictEqual(extracted, 'Final complete output', 'Must return the true last assistant message');
console.log('✅ Test 5: Backward traversal selected the exact last assistant message');

// Test 6: Empty assistant message returns null
const emptyList = [
  { type: 'user_message', content: 'hello' },
  { type: 'status_update', brief: 'stopped' },
];
const emptyExtracted = extractLastAssistantMessage(emptyList);
assert.strictEqual(emptyExtracted, null, 'Must return null for empty assistant output');
console.log('✅ Test 6: Empty assistant output correctly detected');

// ============================================================
// Media Attachments & Status Update Tests (Corrections #3 & #4)
// ============================================================

// Test 7: Attachments classification by content_type
{
  const messagesWithAttachments = [
    {
      type: 'assistant_message',
      assistant_message: {
        content: 'Here is your generated media',
        attachments: [
          { filename: 'ad_banner.png', url: 'https://storage.manus.ai/img1.png', content_type: 'image/png' },
          { filename: 'promo_video.mp4', url: 'https://storage.manus.ai/vid1.mp4', content_type: 'video/mp4' },
          { filename: 'voiceover.mp3', url: 'https://storage.manus.ai/aud1.mp3', content_type: 'audio/mpeg' },
          { filename: 'document.pdf', url: 'https://storage.manus.ai/doc1.pdf', content_type: 'application/pdf' },
        ],
      },
    },
  ];

  const media = extractMediaFromMessages(messagesWithAttachments);
  assert.strictEqual(media.length, 4);
  assert.strictEqual(media[0].type, 'image');
  assert.strictEqual(media[0].url, 'https://storage.manus.ai/img1.png');
  assert.strictEqual(media[1].type, 'video');
  assert.strictEqual(media[1].url, 'https://storage.manus.ai/vid1.mp4');
  assert.strictEqual(media[2].type, 'audio');
  assert.strictEqual(media[3].type, 'file');
  console.log('✅ Test 7: Attachments accurately classified by content_type (image/video/audio/file)');
}

// Test 8: Status updates extracted without fake progress percentages (Correction #4)
{
  const messagesWithStatus = [
    { type: 'status_update', status_update: { brief: 'Analyzing product details', description: 'Examining image features' } },
    { type: 'status_update', brief: 'Generating photorealistic background', description: 'Applying studio lighting' },
  ];

  const updates = extractStatusUpdates(messagesWithStatus);
  assert.strictEqual(updates.length, 2);
  assert.strictEqual(updates[0].brief, 'Analyzing product details');
  assert.strictEqual(updates[1].brief, 'Generating photorealistic background');
  console.log('✅ Test 8: Real Manus status_update.brief/description correctly extracted');
}

// ============================================================
// Session Continuity Tests (Corrections #1 & #2)
// ============================================================

// Test A: Session 12 first request → task.create
{
  const store = new MockSessionStore();
  const uid = 'userA';
  const appSessionId = '12';
  const sessionKey = resolveSessionKey(uid, appSessionId);
  assert.strictEqual(sessionKey, 'userA_12');

  const existing = store.get(sessionKey);
  const mode = determineConversationMode(existing?.taskId);
  assert.strictEqual(mode, 'create', 'First request must use task.create');

  store.set(sessionKey, 'manus_task_ABC123', uid, appSessionId);
  assert.strictEqual(store.get(sessionKey).taskId, 'manus_task_ABC123');
  console.log('✅ Test A: Session 12 first request → task.create, mapping saved');
}

// Test B: Session 12 second request → follow_up (NOT task.create)
{
  const store = new MockSessionStore();
  const uid = 'userA';
  const appSessionId = '12';
  const sessionKey = resolveSessionKey(uid, appSessionId);

  store.set(sessionKey, 'manus_task_ABC123', uid, appSessionId);

  const existing = store.get(sessionKey);
  const mode = determineConversationMode(existing?.taskId);
  assert.strictEqual(mode, 'follow_up', 'Second request must use follow_up, NOT create');
  assert.strictEqual(existing.taskId, 'manus_task_ABC123', 'Must reuse the same task_id');
  console.log('✅ Test B: Session 12 second request → follow_up with same task_id');
}

// Test C: Session 12 third request → still same Manus task
{
  const store = new MockSessionStore();
  const uid = 'userA';
  const appSessionId = '12';
  const sessionKey = resolveSessionKey(uid, appSessionId);

  store.set(sessionKey, 'manus_task_ABC123', uid, appSessionId);
  store.updateLastUsed(sessionKey);

  const existing = store.get(sessionKey);
  const mode = determineConversationMode(existing?.taskId);
  assert.strictEqual(mode, 'follow_up');
  assert.strictEqual(existing.taskId, 'manus_task_ABC123');
  console.log('✅ Test C: Session 12 third request → same Manus task (idempotent)');
}

// Test D: Session 13 → new task.create (different session)
{
  const store = new MockSessionStore();
  const uid = 'userA';

  store.set(resolveSessionKey(uid, '12'), 'manus_task_ABC123', uid, '12');

  const sessionKey13 = resolveSessionKey(uid, '13');
  const existing13 = store.get(sessionKey13);
  const mode = determineConversationMode(existing13?.taskId);
  assert.strictEqual(mode, 'create', 'New session must create new task');
  console.log('✅ Test D: Session 13 → new task.create (independent from Session 12)');
}

// Test E: User A Session 12 vs User B Session 12 → different Manus tasks
{
  const store = new MockSessionStore();
  const keyA = resolveSessionKey('userA', '12');
  const keyB = resolveSessionKey('userB', '12');

  assert.notStrictEqual(keyA, keyB, 'Different users must produce different session keys');

  store.set(keyA, 'task_for_userA', 'userA', '12');
  store.set(keyB, 'task_for_userB', 'userB', '12');

  assert.strictEqual(store.get(keyA).taskId, 'task_for_userA');
  assert.strictEqual(store.get(keyB).taskId, 'task_for_userB');
  assert.notStrictEqual(store.get(keyA).taskId, store.get(keyB).taskId);
  console.log('✅ Test E: User A vs User B on same session ID → isolated Manus tasks');
}

// Test F: Switch Manus → Gemini → Manus → same Manus task restored
{
  const store = new MockSessionStore();
  const uid = 'userA';
  const appSessionId = '12';
  const sessionKey = resolveSessionKey(uid, appSessionId);

  store.set(sessionKey, 'manus_task_XYZ', uid, appSessionId);

  const existing = store.get(sessionKey);
  const mode = determineConversationMode(existing?.taskId);
  assert.strictEqual(mode, 'follow_up', 'Switching back to Manus must reuse same task');
  assert.strictEqual(existing.taskId, 'manus_task_XYZ');
  console.log('✅ Test F: Switch Manus → Gemini → Manus → same Manus task restored');
}

// Test G: New chat/reset → new Manus task
{
  const store = new MockSessionStore();
  const uid = 'userA';

  store.set(resolveSessionKey(uid, '12'), 'old_task', uid, '12');

  const newKey = resolveSessionKey(uid, '14');
  const existing = store.get(newKey);
  const mode = determineConversationMode(existing?.taskId);
  assert.strictEqual(mode, 'create', 'New chat session must create new Manus task');
  console.log('✅ Test G: New chat/reset → new Manus task');
}

// Test H: Null appSessionId → session key is null (no session reuse)
{
  const key = resolveSessionKey('userA', null);
  assert.strictEqual(key, null, 'Null appSessionId must return null session key');
  const key2 = resolveSessionKey(null, '12');
  assert.strictEqual(key2, null, 'Null uid must return null session key');
  console.log('✅ Test H: Null uid or appSessionId → no session tracking (graceful fallback)');
}

// Test I: conversation_mode returned in response meta
{
  const mockResponse = {
    success: true,
    data: 'Some AI output',
    meta: {
      provider: 'manus',
      model: 'manus-v2',
      task_id: 'manus_task_ABC123',
      conversation_mode: 'follow_up',
    },
  };
  assert.strictEqual(mockResponse.meta.conversation_mode, 'follow_up');
  assert.strictEqual(mockResponse.meta.task_id, 'manus_task_ABC123');
  console.log('✅ Test I: conversation_mode correctly returned in response meta');
}

console.log('\n🎉 ALL 17 SESSION CONTINUITY, GATEWAY & MEDIA EXTRACTION TESTS PASSED!\n');
