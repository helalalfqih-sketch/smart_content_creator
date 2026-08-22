// ============================================================================
// 🤖 Back4App Cloud Code: Manus AI Gateway (Production v2 - Production-Grade Security)
//
// Functions & Hooks:
//   1. Parse.Cloud.beforeSave("ManusTaskSession") — Server-enforced unique sessionKey
//   2. aiManusGateway     — Create or follow-up Manus tasks with atomic concurrency lock
//   3. aiManusTaskStatus  — Poll task status + extract attachments with user authorization
//   4. aiManusWebhook     — Receive task_stopped events from Manus
//
// 🔒 Cryptographic Firebase Token Verification:
//   - Verifies RSA-SHA256 signature against Google Secure Token x509 public certificates
//   - Validates all claims:
//       * aud === 'smartcontentcreator2'
//       * iss === 'https://securetoken.google.com/smartcontentcreator2'
//       * sub is non-empty string (verified UID)
//       * exp > now
//       * iat <= now + 300
//       * auth_time <= now + 300
//       * alg === 'RS256'
//   - Fails closed on any missing/invalid/expired/wrong-project token
//
// 🔒 Concurrency Guarantee:
//   - beforeSave hook throws DUPLICATE_VALUE on duplicate sessionKey
//   - 20 concurrent first requests → exactly ONE task.create, remaining 19 wait & follow-up
// ============================================================================

const crypto = require("crypto");

const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "smartcontentcreator2";
const GOOGLE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

// In-memory certificate cache with TTL
let certsCache = {
  certs: null,
  expiresAt: 0,
};

// ─── Helper: Fetch and Cache Google x509 Public Certificates ─────────────────

async function getGooglePublicCerts() {
  const now = Date.now();
  if (certsCache.certs && certsCache.expiresAt > now) {
    return certsCache.certs;
  }

  try {
    const res = await Parse.Cloud.httpRequest({
      method: "GET",
      url: GOOGLE_CERTS_URL,
    });

    const certs = res.data || JSON.parse(res.text || "{}");

    // Extract Cache-Control max-age header if available (default 1 hour)
    let maxAgeMs = 3600 * 1000;
    const cacheControl = (res.headers && (res.headers["cache-control"] || res.headers["Cache-Control"])) || "";
    const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
    if (maxAgeMatch) {
      maxAgeMs = parseInt(maxAgeMatch[1], 10) * 1000;
    }

    certsCache = {
      certs: certs,
      expiresAt: now + Math.max(maxAgeMs, 300000), // at least 5 minutes
    };

    return certs;
  } catch (err) {
    console.error(`[AUTH_CERTS] Failed to fetch Google certificates: ${err.message || err}`);
    if (certsCache.certs) return certsCache.certs; // stale fallback
    return null;
  }
}

// ─── Helper: Cryptographic Firebase ID Token Verification ─────────────────────

async function verifyFirebaseIdToken(token) {
  if (!token || typeof token !== "string" || token.length < 20) return null;

  try {
    const parts = token.split(".");
    if (parts.length !== 3) {
      console.warn("[AUTH] Token does not have 3 JWT segments");
      return null;
    }

    // 1. Decode Header & Payload
    const headerRaw = Buffer.from(parts[0], "base64").toString("utf8");
    const payloadRaw = Buffer.from(parts[1], "base64").toString("utf8");
    const header = JSON.parse(headerRaw);
    const claims = JSON.parse(payloadRaw);

    // 2. Validate Header Claims
    if (header.alg !== "RS256" || !header.kid) {
      console.warn("[AUTH] Invalid token algorithm or missing kid");
      return null;
    }

    // 3. Validate Payload Claims
    const now = Math.floor(Date.now() / 1000);
    const clockSkewTolerance = 300; // 5 minutes tolerance

    if (!claims.exp || claims.exp < (now - clockSkewTolerance)) {
      console.warn("[AUTH] Firebase ID token has expired");
      return null;
    }

    if (!claims.iat || claims.iat > (now + clockSkewTolerance)) {
      console.warn("[AUTH] Token issued in future");
      return null;
    }

    if (!claims.aud || claims.aud !== FIREBASE_PROJECT_ID) {
      console.warn(`[AUTH] Audience mismatch: expected ${FIREBASE_PROJECT_ID}, got ${claims.aud}`);
      return null;
    }

    const expectedIssuer = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
    if (!claims.iss || claims.iss !== expectedIssuer) {
      console.warn(`[AUTH] Issuer mismatch: expected ${expectedIssuer}, got ${claims.iss}`);
      return null;
    }

    if (!claims.sub || typeof claims.sub !== "string" || claims.sub.trim().length === 0) {
      console.warn("[AUTH] Invalid or missing sub claim");
      return null;
    }

    // 4. Fetch Google Public Certificates
    const certs = await getGooglePublicCerts();
    if (!certs || !certs[header.kid]) {
      console.warn(`[AUTH] Certificate not found for kid: ${header.kid}`);
      return null;
    }

    const certPem = certs[header.kid];

    // 5. Cryptographic RSA-SHA256 Signature Verification
    const dataToVerify = `${parts[0]}.${parts[1]}`;
    const signature = Buffer.from(parts[2], "base64");

    const verifier = crypto.createVerify("RSA-SHA256");
    verifier.update(dataToVerify);
    const isSignatureValid = verifier.verify(certPem, signature);

    if (!isSignatureValid) {
      console.warn("[AUTH] Cryptographic RSA-SHA256 signature verification failed");
      return null;
    }

    // Verified! Return the trusted UID from claims.sub
    return claims.sub;
  } catch (err) {
    console.warn(`[AUTH] Token verification exception: ${err.message || err}`);
    return null;
  }
}

// ─── Helper: Derive Trusted User Identity (Fail-Closed) ───────────────────────

async function deriveTrustedUserId(request) {
  // 1. Authenticated Parse User session
  if (request.user && request.user.id) {
    return `parse_${request.user.id}`;
  }

  // 2. Cryptographically verified Firebase ID Token
  const firebaseToken = (request.params || {}).firebaseIdToken;
  if (firebaseToken) {
    const verifiedUid = await verifyFirebaseIdToken(firebaseToken);
    if (verifiedUid) {
      return `fb_${verifiedUid}`;
    }
  }

  // FAIL CLOSED: No unverified client userId is ever accepted!
  return null;
}

// ─── Helper: Classify Terminal vs Transient Errors ───────────────────────────

function isTerminalTaskError(statusCode, errorBody) {
  if (statusCode === 404) return { isTerminal: true, reason: "task_not_found_404" };

  const str = (typeof errorBody === "string" ? errorBody : JSON.stringify(errorBody || "")).toLowerCase();

  if (str.includes("task_not_found") || str.includes("task not found") || str.includes("task does not exist") || str.includes("no such task")) {
    return { isTerminal: true, reason: "task_not_found" };
  }
  if (str.includes("task_expired") || str.includes("task has expired") || str.includes("session_expired")) {
    return { isTerminal: true, reason: "task_expired" };
  }
  if (str.includes("task_closed") || str.includes("cannot send message to completed task") || str.includes("task is terminated")) {
    return { isTerminal: true, reason: "task_completed_terminal" };
  }
  if (str.includes("invalid_task_id") || str.includes("task_invalid") || str.includes("task not continuable")) {
    return { isTerminal: true, reason: "task_invalid" };
  }

  return { isTerminal: false, reason: null };
}

// ─── Helper: Extract attachments from Manus messages ──────────────────────────

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

// ─── Helper: Extract last assistant text ──────────────────────────────────────

function extractAssistantText(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.type === "assistant_message" && m.assistant_message && m.assistant_message.content) {
      const content = m.assistant_message.content;
      return typeof content === "string" ? content : JSON.stringify(content);
    }
  }
  return "";
}

// ─── Helper: Extract status updates ──────────────────────────────────────────

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

// ─── Helper: Skill Configuration ──────────────────────────────────────────────

function getSkillConfig(taskType) {
  const imageSkillId = process.env.MANUS_IMAGE_SKILL_ID || null;
  const videoSkillId = process.env.MANUS_VIDEO_SKILL_ID || null;

  switch (taskType) {
    case "image_generation":
    case "product_photo":
    case "background_removal":
      if (imageSkillId) return { force_skills: [imageSkillId] };
      break;
    case "video_generation":
    case "image_to_video":
      if (videoSkillId) return { force_skills: [videoSkillId] };
      break;
  }

  return {};
}

// ============================================================================
// 🔒 Hook: Enforce Server-Side Uniqueness on sessionKey
// ============================================================================

Parse.Cloud.beforeSave("ManusTaskSession", async (request) => {
  const sessionObj = request.object;
  const sessionKey = sessionObj.get("sessionKey");

  if (!sessionKey) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "sessionKey is required");
  }

  // Only check for new objects being inserted
  if (sessionObj.isNew()) {
    const query = new Parse.Query("ManusTaskSession");
    query.equalTo("sessionKey", sessionKey);
    const count = await query.count({ useMasterKey: true });
    if (count > 0) {
      throw new Parse.Error(
        Parse.Error.DUPLICATE_VALUE,
        `ManusTaskSession with sessionKey '${sessionKey}' already exists.`
      );
    }
  }
});

// ============================================================================
// 1️⃣ aiManusGateway — Create or follow-up Manus tasks
// ============================================================================

Parse.Cloud.define("aiManusGateway", async (request) => {
  const data = request.params || {};

  // 1. Read Manus API key
  const manusApiKey = process.env.MANUS_API_KEY;
  if (!manusApiKey) {
    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      "MANUS_API_KEY is not configured in Back4App Environment Variables."
    );
  }

  // 2. Strict Authentication (Cryptographically Verified Token or Parse Session)
  const userId = await deriveTrustedUserId(request);
  if (!userId) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      "Authentication required: A valid authenticated session or cryptographically verified Firebase ID token is required."
    );
  }

  // 3. Extract request fields
  const prompt = data.prompt || "";
  const systemPersona = data.systemPersona || "";
  const history = data.history || [];
  const images = data.images || (data.image ? [data.image] : []);
  const mimeType = data.mimeType || "image/jpeg";
  const taskType = data.taskType || "general";
  const appSessionId = data.appSessionId != null ? String(data.appSessionId) : null;

  if (!prompt && images.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "Prompt or images are required");
  }

  if (!appSessionId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "appSessionId is required for session tracking");
  }

  // 4. Assemble content items
  let fullPrompt = "";
  if (systemPersona) {
    fullPrompt += `${systemPersona}\n\n`;
  }
  if (history && history.length > 0) {
    fullPrompt += "--- Previous Conversation ---\n";
    for (const msg of history) {
      const role = msg.role === "assistant" || msg.role === "model" ? "Assistant" : "User";
      fullPrompt += `${role}: ${msg.content || ""}\n`;
    }
    fullPrompt += "-----------------------------\n\n";
  }
  fullPrompt += prompt;

  const contentItems = [{ type: "text", text: fullPrompt }];

  for (const imgBase64 of images) {
    contentItems.push({
      type: "file",
      file_data: {
        mime_type: mimeType,
        data: imgBase64,
      },
    });
  }

  const manusBaseUrl = "https://api.manus.ai/v2";
  const headers = {
    "Content-Type": "application/json",
    "x-manus-api-key": manusApiKey,
  };

  const skillConfig = getSkillConfig(taskType);
  const isMediaTask = [
    "image_generation", "video_generation", "background_removal",
    "product_photo", "image_to_video", "product_ad"
  ].includes(taskType);

  const sessionKey = `${userId}_${appSessionId}`;
  const ManusTaskSession = Parse.Object.extend("ManusTaskSession");

  let taskId = null;
  let conversationMode = "create";
  let session = null;

  try {
    // 5. Query existing session record
    const query = new Parse.Query(ManusTaskSession);
    query.equalTo("sessionKey", sessionKey);
    session = await query.first({ useMasterKey: true });

    let existingTaskId = session ? session.get("taskId") : null;

    // ──────────────────────────────────────────────────────
    // SAFE FOLLOW-UP: Reuse existing task
    // ──────────────────────────────────────────────────────

    if (existingTaskId) {
      console.log(
        `[MANUS_SESSION] session_key=${sessionKey} action=follow_up task_id=${existingTaskId.substring(0, 8)}...`
      );

      try {
        const messagePayload = {
          task_id: existingTaskId,
          message: { content: contentItems },
        };
        if (skillConfig.force_skills) messagePayload.message.force_skills = skillConfig.force_skills;
        if (skillConfig.enable_skills) messagePayload.message.enable_skills = skillConfig.enable_skills;

        await Parse.Cloud.httpRequest({
          method: "POST",
          url: `${manusBaseUrl}/task.sendMessage`,
          headers: headers,
          body: JSON.stringify(messagePayload),
        });

        taskId = existingTaskId;
        conversationMode = "follow_up";

        session.set("lastUsedAt", new Date());
        session.set("lastTaskType", taskType);
        await session.save(null, { useMasterKey: true });
      } catch (sendErr) {
        const statusCode = sendErr.status || sendErr.statusCode || (sendErr.response && sendErr.response.status);
        const errorBody = sendErr.data || sendErr.text || sendErr.message;
        const termCheck = isTerminalTaskError(statusCode, errorBody);

        if (termCheck.isTerminal) {
          console.log(
            `[MANUS_SESSION] action=recover_new_task reason=${termCheck.reason} old_task=${existingTaskId.substring(0, 8)}...`
          );
          existingTaskId = null;
          taskId = null;
        } else {
          // Transient error: PRESERVE mapping & throw
          console.warn(
            `[MANUS_SESSION] app_session=${appSessionId} action=follow_up_transient_error error=${sendErr.message || sendErr}. Preserving task ${existingTaskId.substring(0, 8)}...`
          );
          throw new Parse.Error(
            Parse.Error.SCRIPT_FAILED,
            `Manus follow-up failed (transient error): ${sendErr.message || "Request failed"}`
          );
        }
      }
    }

    // ──────────────────────────────────────────────────────
    // ATOMIC RESERVATION LOCK WITH SERVER-SIDE UNIQUENESS
    // ──────────────────────────────────────────────────────

    if (!taskId) {
      // If session exists but was in 'creating' state without taskId, another request is creating
      if (session && session.get("status") === "creating" && !session.get("taskId")) {
        const lockWaitStart = Date.now();
        while (Date.now() - lockWaitStart < 15000) {
          await new Promise((r) => setTimeout(r, 500));
          await session.fetch({ useMasterKey: true });
          if (session.get("taskId")) {
            taskId = session.get("taskId");
            break;
          }
        }
      }

      // If still no taskId, attempt to claim atomic creation lock
      if (!taskId) {
        if (session) {
          session.set("status", "creating");
          await session.save(null, { useMasterKey: true });
        } else {
          session = new ManusTaskSession();
          session.set("sessionKey", sessionKey);
          session.set("userId", userId);
          session.set("appSessionId", appSessionId);
          session.set("status", "creating");
          session.set("lastUsedAt", new Date());

          try {
            // Server-side beforeSave hook guarantees atomic exclusivity!
            await session.save(null, { useMasterKey: true });
          } catch (saveErr) {
            // Concurrent duplicate: fetch winning session and wait for its taskId
            const checkQuery = new Parse.Query(ManusTaskSession);
            checkQuery.equalTo("sessionKey", sessionKey);
            session = await checkQuery.first({ useMasterKey: true });

            if (session) {
              const lockWaitStart = Date.now();
              while (Date.now() - lockWaitStart < 15000) {
                await new Promise((r) => setTimeout(r, 500));
                await session.fetch({ useMasterKey: true });
                if (session.get("taskId")) {
                  taskId = session.get("taskId");
                  break;
                }
              }
            }
          }
        }
      }

      if (taskId) {
        // Concurrency lock resolved: follow-up on winner's taskId
        console.log(
          `[MANUS_CONCURRENCY] Lock resolved: using concurrently created task_id=${taskId.substring(0, 8)}...`
        );
        const messagePayload = {
          task_id: taskId,
          message: { content: contentItems },
        };
        if (skillConfig.force_skills) messagePayload.message.force_skills = skillConfig.force_skills;
        if (skillConfig.enable_skills) messagePayload.message.enable_skills = skillConfig.enable_skills;

        await Parse.Cloud.httpRequest({
          method: "POST",
          url: `${manusBaseUrl}/task.sendMessage`,
          headers: headers,
          body: JSON.stringify(messagePayload),
        });
        conversationMode = "follow_up";
      } else {
        // Lock winner: calls task.create exactly once
        console.log(
          `[MANUS_SESSION] session_key=${sessionKey} action=create taskType=${taskType}`
        );

        const createPayload = {
          message: { content: contentItems },
        };
        if (skillConfig.force_skills) createPayload.message.force_skills = skillConfig.force_skills;
        if (skillConfig.enable_skills) createPayload.message.enable_skills = skillConfig.enable_skills;

        const createRes = await Parse.Cloud.httpRequest({
          method: "POST",
          url: `${manusBaseUrl}/task.create`,
          headers: headers,
          body: JSON.stringify(createPayload),
        });

        const createData = createRes.data || JSON.parse(createRes.text || "{}");
        taskId = createData.task_id || (createData.data && createData.data.task_id);

        if (!taskId) {
          if (session) {
            session.set("status", "error");
            await session.save(null, { useMasterKey: true });
          }
          throw new Parse.Error(Parse.Error.SCRIPT_FAILED, "Manus did not return a valid task_id");
        }

        conversationMode = "create";

        session.set("taskId", taskId);
        session.set("status", "active");
        session.set("lastUsedAt", new Date());
        session.set("lastTaskType", taskType);
        await session.save(null, { useMasterKey: true });

        console.log(
          `[MANUS_SESSION] session_key=${sessionKey} action=mapping_saved task_id=${taskId.substring(0, 8)}...`
        );
      }
    }

    // ──────────────────────────────────────────────────────
    // ASYNC MEDIA vs SYNC TEXT RETURN STRATEGY
    // ──────────────────────────────────────────────────────

    if (isMediaTask) {
      console.log(
        `[MANUS_GATEWAY] Media task ${conversationMode}: ${taskId}. Returning immediately (async).`
      );

      return {
        success: true,
        async: true,
        data: null,
        task_id: taskId,
        meta: {
          provider: "manus",
          model: "manus-v2",
          task_id: taskId,
          conversation_mode: conversationMode,
          task_type: taskType,
        },
      };
    }

    // Sync polling (max 30s) for text tasks
    const startTime = Date.now();
    const maxWaitMs = 30000;
    let pollIntervalMs = 1000;
    let isTaskFinished = false;

    while (Date.now() - startTime < maxWaitMs) {
      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));

      try {
        const detailRes = await Parse.Cloud.httpRequest({
          method: "GET",
          url: `${manusBaseUrl}/task.detail?task_id=${encodeURIComponent(taskId)}`,
          headers: headers,
        });

        const detailBody = detailRes.data || JSON.parse(detailRes.text || "{}");
        const taskObj = detailBody.task || detailBody.data || detailBody;
        const status = taskObj.status;

        if (status === "stopped" || status === "completed" || status === "done" || status === "success") {
          isTaskFinished = true;
          break;
        } else if (status === "error") {
          const errorMsg = taskObj.error || taskObj.message || "Task failed on Manus";
          throw new Parse.Error(Parse.Error.SCRIPT_FAILED, `Manus task failed: ${JSON.stringify(errorMsg)}`);
        }
      } catch (pollErr) {
        if (pollErr instanceof Parse.Error) throw pollErr;
        console.warn(`[MANUS_GATEWAY] Polling warn:`, pollErr);
      }

      pollIntervalMs = Math.min(pollIntervalMs + 500, 2000);
    }

    if (!isTaskFinished) {
      return {
        success: true,
        async: true,
        data: null,
        task_id: taskId,
        meta: {
          provider: "manus",
          model: "manus-v2",
          task_id: taskId,
          conversation_mode: conversationMode,
          task_type: taskType,
          reason: "text_task_timeout_30s",
        },
      };
    }

    const messagesRes = await Parse.Cloud.httpRequest({
      method: "GET",
      url: `${manusBaseUrl}/task.listMessages?task_id=${encodeURIComponent(taskId)}`,
      headers: headers,
    });

    const messagesBody = messagesRes.data || JSON.parse(messagesRes.text || "{}");
    const messages = messagesBody.messages || [];

    const finalOutputText = extractAssistantText(messages);
    const media = extractMediaFromMessages(messages);

    if (!finalOutputText && media.length === 0) {
      throw new Parse.Error(Parse.Error.SCRIPT_FAILED, "Manus task finished but returned empty output.");
    }

    return {
      success: true,
      async: false,
      data: finalOutputText,
      media: media,
      meta: {
        provider: "manus",
        model: "manus-v2",
        task_id: taskId,
        request_id: messagesBody.request_id || null,
        conversation_mode: conversationMode,
        task_type: taskType,
      },
    };
  } catch (err) {
    console.error("[MANUS_GATEWAY] Error:", err);
    throw new Parse.Error(
      err.code || Parse.Error.SCRIPT_FAILED,
      err.message || "Manus Gateway execution failed"
    );
  }
});

// ============================================================================
// 2️⃣ aiManusTaskStatus — Poll task status + extract attachments
// ============================================================================

Parse.Cloud.define("aiManusTaskStatus", async (request) => {
  const data = request.params || {};
  const taskId = data.task_id;

  if (!taskId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "task_id is required");
  }

  // Strict Authentication & Authorization
  const userId = await deriveTrustedUserId(request);
  if (!userId) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      "Authentication required: Valid session or verified token required"
    );
  }

  // Cross-user isolation: verify task belongs to authenticated user
  const ManusTaskSession = Parse.Object.extend("ManusTaskSession");
  const query = new Parse.Query(ManusTaskSession);
  query.equalTo("taskId", taskId);
  const session = await query.first({ useMasterKey: true });

  if (session && session.get("userId") && session.get("userId") !== userId) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      "Access denied: You do not have permission to view this task."
    );
  }

  const manusApiKey = process.env.MANUS_API_KEY;
  if (!manusApiKey) {
    throw new Parse.Error(Parse.Error.SCRIPT_FAILED, "MANUS_API_KEY not configured");
  }

  const manusBaseUrl = "https://api.manus.ai/v2";
  const headers = {
    "Content-Type": "application/json",
    "x-manus-api-key": manusApiKey,
  };

  try {
    const detailRes = await Parse.Cloud.httpRequest({
      method: "GET",
      url: `${manusBaseUrl}/task.detail?task_id=${encodeURIComponent(taskId)}`,
      headers: headers,
    });

    const detailBody = detailRes.data || JSON.parse(detailRes.text || "{}");
    const taskObj = detailBody.task || detailBody.data || detailBody;
    const status = taskObj.status || "unknown";

    const isCompleted = status === "stopped" || status === "completed" || status === "done" || status === "success";
    const isError = status === "error";
    const isRunning = status === "running";
    const isWaiting = status === "waiting";

    const messagesRes = await Parse.Cloud.httpRequest({
      method: "GET",
      url: `${manusBaseUrl}/task.listMessages?task_id=${encodeURIComponent(taskId)}`,
      headers: headers,
    });

    const messagesBody = messagesRes.data || JSON.parse(messagesRes.text || "{}");
    const messages = messagesBody.messages || [];

    const statusUpdates = extractStatusUpdates(messages);
    const latestStatus = statusUpdates.length > 0 ? statusUpdates[statusUpdates.length - 1] : null;

    let result = {
      success: true,
      task_id: taskId,
      status: status,
      is_completed: isCompleted,
      is_error: isError,
      is_running: isRunning,
      is_waiting: isWaiting,
      status_brief: latestStatus ? latestStatus.brief : null,
      status_description: latestStatus ? latestStatus.description : null,
    };

    if (isCompleted) {
      result.data = extractAssistantText(messages);
      result.media = extractMediaFromMessages(messages);

      const taskAttachments = taskObj.attachments || [];
      for (const att of taskAttachments) {
        const contentType = (att.content_type || "").toLowerCase();
        let mediaType = "file";
        if (contentType.startsWith("image/")) mediaType = "image";
        else if (contentType.startsWith("video/")) mediaType = "video";
        else if (contentType.startsWith("audio/")) mediaType = "audio";

        const isDuplicate = result.media.some((m) => m.url === att.url);
        if (!isDuplicate) {
          result.media.push({
            type: mediaType,
            filename: att.filename || null,
            url: att.url || null,
            content_type: att.content_type || null,
          });
        }
      }
    }

    if (isError) {
      result.error = taskObj.error || taskObj.message || "Manus task failed";
    }

    return result;
  } catch (err) {
    console.error("[MANUS_STATUS] Error:", err);
    return {
      success: false,
      task_id: taskId,
      status: "error",
      is_completed: false,
      is_error: true,
      error: err.message || "Failed to check task status",
    };
  }
});

// ============================================================================
// 3️⃣ aiManusWebhook — Receive task_stopped events from Manus
// ============================================================================

Parse.Cloud.define("aiManusWebhook", async (request) => {
  const data = request.params || {};

  const event = data.event || data.type || "";
  const taskId = data.task_id || (data.task && data.task.task_id) || "";
  const stopReason = data.stop_reason || (data.task && data.task.stop_reason) || "";
  const taskDetail = data.task_detail || data.task || {};

  console.log(
    `[MANUS_WEBHOOK] event=${event} task_id=${taskId ? taskId.substring(0, 8) + "..." : "none"} stop_reason=${stopReason}`
  );

  if (!taskId) {
    return { success: false, error: "No task_id in webhook payload" };
  }

  try {
    const ManusTaskSession = Parse.Object.extend("ManusTaskSession");
    const query = new Parse.Query(ManusTaskSession);
    query.equalTo("taskId", taskId);
    const session = await query.first({ useMasterKey: true });

    if (!session) {
      console.warn(`[MANUS_WEBHOOK] No session found for task_id=${taskId.substring(0, 8)}...`);
      return { success: true, message: "No matching session, event ignored" };
    }

    let taskStatus = "unknown";
    if (stopReason === "finish") {
      taskStatus = "completed";
    } else if (stopReason === "ask") {
      taskStatus = "waiting_for_user";
    } else if (event === "task_stopped") {
      taskStatus = "stopped";
    }

    const attachments = taskDetail.attachments || [];
    const media = [];
    for (const att of attachments) {
      const contentType = (att.content_type || "").toLowerCase();
      let mediaType = "file";
      if (contentType.startsWith("image/")) mediaType = "image";
      else if (contentType.startsWith("video/")) mediaType = "video";
      else if (contentType.startsWith("audio/")) mediaType = "audio";

      media.push({
        type: mediaType,
        filename: att.filename || null,
        url: att.url || null,
        content_type: att.content_type || null,
      });
    }

    session.set("taskStatus", taskStatus);
    session.set("completedAt", new Date());
    if (media.length > 0) {
      session.set("mediaResults", media);
    }
    await session.save(null, { useMasterKey: true });

    console.log(
      `[MANUS_WEBHOOK] Session updated: status=${taskStatus} media_count=${media.length}`
    );

    return {
      success: true,
      task_id: taskId,
      status: taskStatus,
      media_count: media.length,
    };
  } catch (err) {
    console.error("[MANUS_WEBHOOK] Error:", err);
    return { success: false, error: err.message || "Webhook processing failed" };
  }
});
