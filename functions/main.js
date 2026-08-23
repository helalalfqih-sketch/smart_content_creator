/**
 * Back4App Unified Master Cloud Code (Production v2.1)
 * AI Gateways (Gemini + Hardened Manus v2) + Catalog Cloud Code
 */

const ADMIN_SECRET = process.env.CATALOG_ADMIN_SECRET || "scc_catalog_migration_admin_secret_2026";
const ADMIN_UIDS = new Set([
  "admin",
  "helal_admin",
  "d1w1a2XQfUe4r3v2",
  "owner"
]);

/**
 * Back4App Cloud Code
 * High-Performance Unified AI Gateway (Production v2)
 * Supports Google Gemini & Hardened Manus API v2 (Text, Multimodal Vision, Media, Session Continuity & Cryptographic Auth)
 */

const axios = require("axios");
const crypto = require("crypto");

const GEMINI_TIMEOUT = 30000;
const API_KEY = process.env.GEMINI_API_KEY || process.env.API_KEY || "";
const ACTIVE_MODEL = "gemini-3.6-flash";

const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "smartcontentcreator2";
const GOOGLE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

// ============================================================================
// 1️⃣ GEMINI GATEWAY LOGIC
// ============================================================================

function sanitizeGemini(params) {
  const maxTokens = Number(params.max_tokens);
  const temperature = Number(params.temperature);
  return {
    prompt: String(params.prompt || "").slice(0, 12000),
    history: Array.isArray(params.history)
      ? params.history.slice(0, 20).map((h) => ({
          role: h?.role === "assistant" || h?.role === "model" ? "model" : "user",
          content: String(h?.content || "").slice(0, 4000),
        }))
      : [],
    image: params.image && String(params.image).length < 8000000 ? params.image : null,
    mimeType: params.mimeType || "image/jpeg",
    max_tokens: Number.isFinite(maxTokens) ? Math.min(Math.max(maxTokens, 1), 4096) : 2048,
    temperature: Number.isFinite(temperature) ? Math.min(Math.max(temperature, 0), 1) : 0.7,
  };
}

async function handleGeminiRequest(requestParams) {
  const params = sanitizeGemini(requestParams || {});
  if (!params.prompt && !params.image) {
    throw new Parse.Error(Parse.Error.VALIDATION_ERROR, "الرجاء كتابة سؤالك أو تحديد الصورة أولاً.");
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${ACTIVE_MODEL}:generateContent?key=${encodeURIComponent(API_KEY)}`;

  const contents = [];
  for (const h of params.history) {
    contents.push({
      role: h.role,
      parts: [{ text: h.content }],
    });
  }

  const parts = [];
  if (params.image) {
    parts.push({
      inline_data: {
        mime_type: params.mimeType,
        data: params.image,
      },
    });
  }
  if (params.prompt) {
    parts.push({ text: params.prompt });
  }

  contents.push({ role: "user", parts });

  try {
    const response = await axios.post(
      url,
      {
        contents,
        generationConfig: {
          temperature: params.temperature,
          maxOutputTokens: params.max_tokens,
        },
      },
      { timeout: GEMINI_TIMEOUT, headers: { "Content-Type": "application/json" } }
    );

    const text = response?.data?.candidates?.[0]?.content?.parts?.map((p) => p.text || "")?.join("\n")?.trim() || "";
    if (!text) throw new Parse.Error(500, "استجابة فارغة من خادم الذكاء الاصطناعي");

    return {
      success: true,
      data: text,
      meta: { provider: "gemini", model: ACTIVE_MODEL, status: "active" },
    };
  } catch (error) {
    const status = error?.response?.status || 500;
    const errMsg = error?.response?.data?.error?.message || error?.message || "Unknown Connection Error";
    console.error("Gemini AI Gateway Error:", status, errMsg);
    throw new Parse.Error(status, `فشل الاتصال بـ Gemini: ${errMsg}`);
  }
}

// ============================================================================
// 2️⃣ CRYPTOGRAPHIC FIREBASE AUTH & TOKEN VERIFICATION
// ============================================================================

let certsCache = {
  certs: null,
  expiresAt: 0,
};

async function getGooglePublicCerts() {
  const now = Date.now();
  if (certsCache.certs && certsCache.expiresAt > now) {
    return certsCache.certs;
  }

  try {
    const res = await axios.get(GOOGLE_CERTS_URL, { timeout: 10000 });
    const certs = res.data;

    let maxAgeMs = 3600 * 1000;
    const cacheControl = (res.headers && (res.headers["cache-control"] || res.headers["Cache-Control"])) || "";
    const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
    if (maxAgeMatch) {
      maxAgeMs = parseInt(maxAgeMatch[1], 10) * 1000;
    }

    certsCache = {
      certs: certs,
      expiresAt: now + Math.max(maxAgeMs, 300000),
    };

    return certs;
  } catch (err) {
    console.error(`[AUTH_CERTS] Failed to fetch Google certificates: ${err.message || err}`);
    if (certsCache.certs) return certsCache.certs;
    return null;
  }
}

async function verifyFirebaseIdToken(token) {
  if (!token || typeof token !== "string" || token.length < 20) return null;

  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const header = JSON.parse(Buffer.from(parts[0], "base64").toString("utf8"));
    const claims = JSON.parse(Buffer.from(parts[1], "base64").toString("utf8"));

    if (header.alg !== "RS256" || !header.kid) return null;

    const now = Math.floor(Date.now() / 1000);
    const clockSkew = 300;

    if (!claims.exp || claims.exp < (now - clockSkew)) return null;
    if (!claims.iat || claims.iat > (now + clockSkew)) return null;

    if (!claims.aud || claims.aud !== FIREBASE_PROJECT_ID) return null;
    const expectedIssuer = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
    if (!claims.iss || claims.iss !== expectedIssuer) return null;

    if (!claims.sub || typeof claims.sub !== "string" || claims.sub.trim().length === 0) return null;

    const certs = await getGooglePublicCerts();
    if (!certs || !certs[header.kid]) return null;

    const certPem = certs[header.kid];
    const dataToVerify = `${parts[0]}.${parts[1]}`;
    const signature = Buffer.from(parts[2], "base64");

    const verifier = crypto.createVerify("RSA-SHA256");
    verifier.update(dataToVerify);
    const isSignatureValid = verifier.verify(certPem, signature);

    if (!isSignatureValid) return null;

    return {
      uid: claims.sub,
      email: claims.email || null,
      admin: Boolean(claims.admin === true || claims.role === "admin" || (typeof ADMIN_UIDS !== "undefined" && ADMIN_UIDS.has(claims.sub))),
      claims: claims
    };
  } catch (err) {
    console.warn(`[AUTH] Token verification error: ${err.message || err}`);
    return null;
  }
}

async function deriveTrustedUserId(request) {
  if (request.user && request.user.id) {
    return `parse_${request.user.id}`;
  }

  const firebaseToken = (request.params || {}).firebaseIdToken;
  if (firebaseToken) {
    const verifiedUid = await verifyFirebaseIdToken(firebaseToken);
    if (verifiedUid) {
      const uidVal = typeof verifiedUid === "object" ? verifiedUid.uid : verifiedUid;
      return `fb_${uidVal}`;
    }
  }

  return null;
}

async function extractAuthUser(request) {
  if (request.user && request.user.id) {
    return {
      uid: request.user.id,
      admin: Boolean(ADMIN_UIDS.has(request.user.id) || request.user.get("role") === "admin"),
      user: request.user,
    };
  }

  const params = request.params || {};
  const firebaseToken = params.firebaseIdToken || (request.headers && (request.headers["x-firebase-id-token"] || (request.headers["authorization"] ? request.headers["authorization"].replace(/^Bearer\s+/i, "") : null)));
  if (firebaseToken) {
    const verified = await verifyFirebaseIdToken(firebaseToken);
    if (verified) {
      return verified;
    }
  }

  return null;
}

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

function extractMediaFromMessages(messages) {
  const media = [];
  for (const m of messages) {
    const assistantMsg = m.assistant_message || {};
    const attachments = assistantMsg.attachments || [];
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
  }
  return media;
}

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
// 🔒 SERVER-SIDE UNIQUENESS ENFORCEMENT HOOK
// ============================================================================

Parse.Cloud.beforeSave("ManusTaskSession", async (request) => {
  const sessionObj = request.object;
  const sessionKey = sessionObj.get("sessionKey");

  if (!sessionKey) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "sessionKey is required");
  }

  if (sessionObj.isNew()) {
    const count = await new Parse.Query("ManusTaskSession")
      .equalTo("sessionKey", sessionKey)
      .count({ useMasterKey: true });

    if (count > 0) {
      throw new Parse.Error(
        Parse.Error.DUPLICATE_VALUE,
        `ManusTaskSession with sessionKey '${sessionKey}' already exists.`
      );
    }
  }
});

// ============================================================================
// 3️⃣ HARDENED MANUS API v2 GATEWAY LOGIC
// ============================================================================

async function handleManusRequest(request) {
  const data = request.params || {};

  const manusApiKey = process.env.MANUS_API_KEY;
  if (!manusApiKey) {
    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      "MANUS_API_KEY is not configured in Back4App Environment Variables."
    );
  }

  const userId = await deriveTrustedUserId(request);
  if (!userId) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      "Authentication required: A valid authenticated session or cryptographically verified Firebase ID token is required."
    );
  }

  const prompt = data.prompt || "";
  const systemPersona = data.systemPersona || "";
  const history = data.history || [];
  const images = Array.isArray(data.images) && data.images.length > 0
    ? data.images
    : (data.image ? [data.image] : []);
  const mimeType = data.mimeType || "image/jpeg";
  const taskType = data.taskType || "general";
  const appSessionId = data.appSessionId != null ? String(data.appSessionId) : null;

  if (!prompt && images.length === 0) {
    throw new Parse.Error(Parse.Error.VALIDATION_ERROR, "الرجاء إدخال النص أو الصور أولاً.");
  }

  if (!appSessionId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "appSessionId is required for session tracking");
  }

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

  for (let idx = 0; idx < images.length; idx++) {
    const imgBase64 = String(images[idx]);
    const fileDataUri = imgBase64.startsWith("data:")
      ? imgBase64
      : `data:${mimeType};base64,${imgBase64}`;
    contentItems.push({
      type: "file",
      filename: `image_${idx + 1}.jpg`,
      file_data: fileDataUri,
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
    const query = new Parse.Query(ManusTaskSession);
    query.equalTo("sessionKey", sessionKey);
    session = await query.first({ useMasterKey: true });

    let existingTaskId = session ? session.get("taskId") : null;

    // Follow-up
    if (existingTaskId) {
      try {
        const messagePayload = {
          task_id: existingTaskId,
          message: { content: contentItems },
        };
        if (skillConfig.force_skills) messagePayload.message.force_skills = skillConfig.force_skills;
        if (skillConfig.enable_skills) messagePayload.message.enable_skills = skillConfig.enable_skills;

        await axios.post(`${manusBaseUrl}/task.sendMessage`, messagePayload, { headers, timeout: 20000 });

        taskId = existingTaskId;
        conversationMode = "follow_up";

        session.set("lastUsedAt", new Date());
        session.set("lastTaskType", taskType);
        await session.save(null, { useMasterKey: true });
      } catch (sendErr) {
        const statusCode = sendErr?.response?.status || 500;
        const errorBody = sendErr?.response?.data || sendErr?.message;
        const termCheck = isTerminalTaskError(statusCode, errorBody);

        if (termCheck.isTerminal) {
          console.log(`[MANUS_SESSION] action=recover_new_task reason=${termCheck.reason}`);
          existingTaskId = null;
          taskId = null;
        } else {
          throw new Parse.Error(statusCode, `Manus follow-up failed: ${sendErr?.message || "Request failed"}`);
        }
      }
    }

    // Atomic creation lock
    if (!taskId) {
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
            await session.save(null, { useMasterKey: true });
          } catch (saveErr) {
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
        const messagePayload = {
          task_id: taskId,
          message: { content: contentItems },
        };
        if (skillConfig.force_skills) messagePayload.message.force_skills = skillConfig.force_skills;
        if (skillConfig.enable_skills) messagePayload.message.enable_skills = skillConfig.enable_skills;

        await axios.post(`${manusBaseUrl}/task.sendMessage`, messagePayload, { headers, timeout: 20000 });
        conversationMode = "follow_up";
      } else {
        const createPayload = { message: { content: contentItems } };
        if (skillConfig.force_skills) createPayload.message.force_skills = skillConfig.force_skills;
        if (skillConfig.enable_skills) createPayload.message.enable_skills = skillConfig.enable_skills;

        const createRes = await axios.post(`${manusBaseUrl}/task.create`, createPayload, { headers, timeout: 20000 });
        const createData = createRes.data || {};
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
      }
    }

    // Return immediately for media tasks
    if (isMediaTask) {
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
        const detailRes = await axios.get(
          `${manusBaseUrl}/task.detail?task_id=${encodeURIComponent(taskId)}`,
          { headers, timeout: 10000 }
        );

        const detailBody = detailRes.data || {};
        const taskObj = detailBody.task || detailBody.data || detailBody;
        const status = taskObj.status;

        if (status === "stopped" || status === "completed" || status === "done" || status === "success") {
          isTaskFinished = true;
          break;
        } else if (status === "failed" || status === "error") {
          const errorMsg = taskObj.error || taskObj.message || "Task failed on Manus";
          throw new Parse.Error(Parse.Error.SCRIPT_FAILED, `Manus task failed: ${JSON.stringify(errorMsg)}`);
        }
      } catch (pollErr) {
        if (pollErr instanceof Parse.Error) throw pollErr;
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

    const messagesRes = await axios.get(
      `${manusBaseUrl}/task.listMessages?task_id=${encodeURIComponent(taskId)}`,
      { headers, timeout: 15000 }
    );

    const messagesBody = messagesRes.data || {};
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
      err.code || err?.response?.status || Parse.Error.SCRIPT_FAILED,
      err.message || "Manus Gateway execution failed"
    );
  }
}

// ============================================================================
// 4️⃣ MANUS TASK STATUS & WEBHOOK ENDPOINTS
// ============================================================================

async function handleManusStatusRequest(request) {
  const data = request.params || {};
  const taskId = data.task_id;

  if (!taskId) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "task_id is required");
  }

  const userId = await deriveTrustedUserId(request);
  if (!userId) {
    throw new Parse.Error(
      Parse.Error.OBJECT_NOT_FOUND,
      "Authentication required: Valid session or verified token required"
    );
  }

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
    const detailRes = await axios.get(
      `${manusBaseUrl}/task.detail?task_id=${encodeURIComponent(taskId)}`,
      { headers, timeout: 10000 }
    );

    const detailBody = detailRes.data || {};
    const taskObj = detailBody.task || detailBody.data || detailBody;
    const status = taskObj.status || "unknown";

    const isCompleted = status === "stopped" || status === "completed" || status === "done" || status === "success";
    const isError = status === "failed" || status === "error";
    const isRunning = status === "running";
    const isWaiting = status === "waiting";

    const messagesRes = await axios.get(
      `${manusBaseUrl}/task.listMessages?task_id=${encodeURIComponent(taskId)}`,
      { headers, timeout: 15000 }
    );

    const messagesBody = messagesRes.data || {};
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
}

// ============================================================================
// 🚪 CLOUD FUNCTIONS ENDPOINTS
// ============================================================================

// 🟣 Gemini Gateways
Parse.Cloud.define("aiGateway", async (request) => {
  return await handleGeminiRequest(request.params);
});

Parse.Cloud.define("aiVertexGateway", async (request) => {
  return await handleGeminiRequest(request.params);
});

Parse.Cloud.define("aiGenerateText", async (request) => {
  return await handleGeminiRequest(request.params);
});

// 🤖 Hardened Manus API v2 Gateways
Parse.Cloud.define("aiManusGateway", async (request) => {
  return await handleManusRequest(request);
});

Parse.Cloud.define("aiManusTaskStatus", async (request) => {
  return await handleManusStatusRequest(request);
});

Parse.Cloud.define("aiManusWebhook", async (request) => {
  const data = request.params || {};
  const taskId = data.task_id || (data.task && data.task.task_id) || "";
  const stopReason = data.stop_reason || (data.task && data.task.stop_reason) || "";
  const taskDetail = data.task_detail || data.task || {};

  if (!taskId) return { success: false, error: "No task_id in webhook payload" };

  try {
    const ManusTaskSession = Parse.Object.extend("ManusTaskSession");
    const query = new Parse.Query(ManusTaskSession);
    query.equalTo("taskId", taskId);
    const session = await query.first({ useMasterKey: true });

    if (!session) return { success: true, message: "No matching session" };

    let taskStatus = stopReason === "finish" ? "completed" : stopReason === "ask" ? "waiting_for_user" : "stopped";

    const attachments = taskDetail.attachments || [];
    const media = [];
    for (const att of attachments) {
      const contentType = (att.content_type || "").toLowerCase();
      let mediaType = contentType.startsWith("image/") ? "image" : contentType.startsWith("video/") ? "video" : contentType.startsWith("audio/") ? "audio" : "file";
      media.push({
        type: mediaType,
        filename: att.filename || null,
        url: att.url || null,
        content_type: att.content_type || null,
      });
    }

    session.set("taskStatus", taskStatus);
    session.set("completedAt", new Date());
    if (media.length > 0) session.set("mediaResults", media);
    await session.save(null, { useMasterKey: true });

    return { success: true, task_id: taskId, status: taskStatus, media_count: media.length };
  } catch (err) {
    return { success: false, error: err.message || "Webhook processing failed" };
  }
});

// ============================================================================
// 🛍️ CATALOG DATABASE & SYNC DOMAIN MODULE
// ============================================================================




async function extractAuthUser(request) {
  if (request.user && request.user.id) {
    return {
      uid: `parse_${request.user.id}`,
      admin: Boolean(request.user.get("role") === "admin" || request.master),
      type: "parse"
    };
  }

  const token = (request.params || {}).firebaseIdToken || (request.headers || {})["x-firebase-token"];
  if (token) {
    const verified = await verifyFirebaseIdToken(token);
    if (verified) {
      return {
        uid: verified.uid,
        admin: verified.admin,
        type: "firebase",
        email: verified.email
      };
    }
  }

  const adminAuth = (request.params || {}).adminSecret || (request.headers || {})["x-catalog-admin-secret"];
  if (adminAuth && adminAuth === ADMIN_SECRET) {
    return {
      uid: "system_admin",
      admin: true,
      type: "secret"
    };
  }

  return null;
}

// ============================================================================
// 🛍️ CATALOG CLOUD CODE DOMAIN (EMBEDDED)
// ============================================================================

// ============================================================================
// 2️⃣ DEDUPE & NORMALIZATION HELPERS
// ============================================================================

function computeMediaDedupeKey(productId, type, url) {
  const normUrl = String(url || "").trim();
  const raw = `${productId}|${type}|${normUrl}`;
  return crypto.createHash("sha256").update(raw).digest("hex");
}

function normalizeProductLink(link, productId) {
  if (!link || typeof link !== "string") return "";
  const trimmed = link.trim();
  if (trimmed.includes("smartcontentcreator-d49f2.web.app")) {
    return productId ? `https://smartcontentcreator2.web.app/app/product/${productId}` : "https://smartcontentcreator2.web.app/app";
  }
  return trimmed;
}

// ============================================================================
// 3️⃣ LIVE SCHEMA BOOTSTRAP & CLP LOCKDOWN
// ============================================================================

async function bootstrapCatalogSchemas() {
  const results = {};

  // Class Level Permissions: Complete Public Lockdown
  const strictClp = {
    get: {},
    find: {},
    count: {},
    create: {},
    update: {},
    delete: {},
    addField: {}
  };

  // 1. CatalogProduct Schema
  try {
    const productSchema = new Parse.Schema("CatalogProduct");
    productSchema.setCLP(strictClp);

    // Fields
    productSchema.addString("productId");
    productSchema.addString("retailerId");
    productSchema.addString("originalCatalogId");
    productSchema.addString("title");
    productSchema.addString("description");
    productSchema.addString("availability");
    productSchema.addString("condition");
    productSchema.addNumber("price");
    productSchema.addString("currency");
    productSchema.addString("link");
    productSchema.addString("imageLink");
    productSchema.addArray("additionalImageLinks");
    productSchema.addString("videoUrl");
    productSchema.addString("brand");
    productSchema.addString("googleProductCategory");
    productSchema.addString("fbProductCategory");
    productSchema.addString("categoryId");
    productSchema.addString("categoryName");
    productSchema.addString("metaProductType");
    productSchema.addNumber("quantity");
    productSchema.addNumber("salePrice");
    productSchema.addString("salePriceEffectiveDate");
    productSchema.addString("itemGroupId");
    productSchema.addString("gender");
    productSchema.addString("color");
    productSchema.addString("size");
    productSchema.addString("ageGroup");
    productSchema.addString("material");
    productSchema.addString("pattern");
    productSchema.addString("shipping");
    productSchema.addString("shippingWeight");
    productSchema.addString("gtin");
    productSchema.addArray("productTags");
    productSchema.addString("style");
    productSchema.addString("creatorUid");
    productSchema.addString("status");
    productSchema.addString("scope");
    productSchema.addString("source");
    productSchema.addNumber("schemaVersion");
    productSchema.addNumber("syncVersion");
    productSchema.addDate("clientUpdatedAt");
    productSchema.addDate("lastSyncedAt");
    productSchema.addDate("deletedAt");

    // Indexes: Unique Index on productId
    productSchema.addIndex("unique_productId", { productId: 1 }, { unique: true });
    productSchema.addIndex("idx_category", { categoryId: 1, status: 1 });
    productSchema.addIndex("idx_scope_status", { scope: 1, status: 1 });

    try {
      await productSchema.save();
      results.CatalogProduct = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await productSchema.update();
        results.CatalogProduct = "updated";
      } else {
        results.CatalogProduct = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogProduct = `fatal: ${err.message}`;
  }

  // 2. CatalogProductMedia Schema
  try {
    const mediaSchema = new Parse.Schema("CatalogProductMedia");
    mediaSchema.setCLP(strictClp);

    mediaSchema.addPointer("product", "CatalogProduct");
    mediaSchema.addString("productId");
    mediaSchema.addString("type");
    mediaSchema.addString("url");
    mediaSchema.addString("thumbnailUrl");
    mediaSchema.addString("mimeType");
    mediaSchema.addString("filename");
    mediaSchema.addNumber("sortOrder");
    mediaSchema.addBoolean("isPrimary");
    mediaSchema.addString("source");
    mediaSchema.addString("status");
    mediaSchema.addNumber("width");
    mediaSchema.addNumber("height");
    mediaSchema.addNumber("durationMs");
    mediaSchema.addObject("metadata");
    mediaSchema.addString("dedupeKey");

    // Indexes: Unique Index on dedupeKey (race-safe)
    mediaSchema.addIndex("unique_media_dedupe", { dedupeKey: 1 }, { unique: true });
    mediaSchema.addIndex("idx_media_product", { productId: 1, type: 1 });

    try {
      await mediaSchema.save();
      results.CatalogProductMedia = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await mediaSchema.update();
        results.CatalogProductMedia = "updated";
      } else {
        results.CatalogProductMedia = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogProductMedia = `fatal: ${err.message}`;
  }

  // 3. CatalogCategory Schema
  try {
    const categorySchema = new Parse.Schema("CatalogCategory");
    categorySchema.setCLP(strictClp);

    categorySchema.addString("categoryId");
    categorySchema.addString("name");
    categorySchema.addString("nameAr");
    categorySchema.addString("slug");
    categorySchema.addString("googleCategory");
    categorySchema.addString("fbCategory");
    categorySchema.addString("imageUrl");
    categorySchema.addNumber("sortOrder");
    categorySchema.addBoolean("active");
    categorySchema.addString("scope");
    categorySchema.addString("creatorUid");
    categorySchema.addObject("metadata");

    categorySchema.addIndex("unique_categoryId", { categoryId: 1 }, { unique: true });

    try {
      await categorySchema.save();
      results.CatalogCategory = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await categorySchema.update();
        results.CatalogCategory = "updated";
      } else {
        results.CatalogCategory = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogCategory = `fatal: ${err.message}`;
  }

  // 4. CatalogSyncState Schema
  try {
    const syncSchema = new Parse.Schema("CatalogSyncState");
    syncSchema.setCLP(strictClp);

    syncSchema.addString("ownerUid");
    syncSchema.addString("deviceId");
    syncSchema.addDate("lastPullAt");
    syncSchema.addDate("lastPushAt");
    syncSchema.addNumber("lastServerVersion");
    syncSchema.addString("status");
    syncSchema.addNumber("pendingOperations");
    syncSchema.addString("lastError");
    syncSchema.addObject("metadata");

    syncSchema.addIndex("idx_sync_owner", { ownerUid: 1, deviceId: 1 });

    try {
      await syncSchema.save();
      results.CatalogSyncState = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await syncSchema.update();
        results.CatalogSyncState = "updated";
      } else {
        results.CatalogSyncState = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogSyncState = `fatal: ${err.message}`;
  }

  // 5. CatalogChangeLog Schema
  try {
    const logSchema = new Parse.Schema("CatalogChangeLog");
    logSchema.setCLP(strictClp);

    logSchema.addPointer("product", "CatalogProduct");
    logSchema.addString("productId");
    logSchema.addString("operation");
    logSchema.addString("actorUid");
    logSchema.addNumber("version");
    logSchema.addArray("changedFields");
    logSchema.addObject("beforeData");
    logSchema.addObject("afterData");
    logSchema.addString("source");
    logSchema.addString("deviceId");

    logSchema.addIndex("idx_log_product", { productId: 1, version: -1 });

    try {
      await logSchema.save();
      results.CatalogChangeLog = "created";
    } catch (e) {
      if (e.code === 103 || (e.message && e.message.includes("already exists"))) {
        await logSchema.update();
        results.CatalogChangeLog = "updated";
      } else {
        results.CatalogChangeLog = `error: ${e.message}`;
      }
    }
  } catch (err) {
    results.CatalogChangeLog = `fatal: ${err.message}`;
  }

  return results;
}

// ============================================================================
// 4️⃣ CLOUD CODE CATALOG API IMPLEMENTATION
// ============================================================================

// 📋 catalogList: Paginated list with server-enforced scoping
Parse.Cloud.define("catalogList", async (request) => {
  const params = request.params || {};
  const page = Math.max(1, parseInt(params.page || 1, 10));
  const limit = Math.min(100, Math.max(1, parseInt(params.limit || 50, 10)));
  const category = (params.category || "").trim();
  const search = (params.search || "").trim().toLowerCase();
  const sort = params.sort || "created_desc";

  const auth = await extractAuthUser(request);
  const userUid = auth ? auth.uid : null;

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);

  // Soft delete filter
  query.doesNotExist("deletedAt");

  // Scoping:
  if (userUid && auth.admin) {
    // Admin sees all non-deleted
  } else if (userUid) {
    // Authenticated user sees global approved OR their own
    const globalQuery = new Parse.Query(CatalogProduct);
    globalQuery.equalTo("scope", "global");
    globalQuery.equalTo("status", "approved");
    globalQuery.doesNotExist("deletedAt");

    const ownQuery = new Parse.Query(CatalogProduct);
    ownQuery.equalTo("creatorUid", userUid);
    ownQuery.doesNotExist("deletedAt");

    const mainQuery = Parse.Query.or(globalQuery, ownQuery);
    if (category && category !== "الكل") {
      mainQuery.equalTo("categoryName", category);
    }
    if (search) {
      mainQuery.matches("title", new RegExp(search, "i"));
    }
    mainQuery.skip((page - 1) * limit);
    mainQuery.limit(limit);
    mainQuery.descending("createdAt");

    const [items, totalCount] = await Promise.all([
      mainQuery.find({ useMasterKey: true }),
      mainQuery.count({ useMasterKey: true })
    ]);

    return {
      success: true,
      page,
      limit,
      total: totalCount,
      totalPages: Math.ceil(totalCount / limit),
      data: items.map(p => ({ id: p.id, ...p.toJSON() }))
    };
  } else {
    // Public / anonymous: strictly global and approved
    query.equalTo("scope", "global");
    query.equalTo("status", "approved");
  }

  if (category && category !== "الكل") {
    query.equalTo("categoryName", category);
  }

  if (search) {
    query.matches("title", new RegExp(search, "i"));
  }

  if (sort === "created_asc") {
    query.ascending("createdAt");
  } else if (sort === "price_asc") {
    query.ascending("price");
  } else if (sort === "price_desc") {
    query.descending("price");
  } else {
    query.descending("createdAt");
  }

  query.skip((page - 1) * limit);
  query.limit(limit);

  const [items, totalCount] = await Promise.all([
    query.find({ useMasterKey: true }),
    query.count({ useMasterKey: true })
  ]);

  return {
    success: true,
    page,
    limit,
    total: totalCount,
    totalPages: Math.ceil(totalCount / limit),
    data: items.map(p => ({ id: p.id, ...p.toJSON() }))
  };
});

// 🔎 Helper: Query product by either objectId or custom productId
function findProductQuery(productId) {
  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const queryById = new Parse.Query(CatalogProduct);
  queryById.equalTo("objectId", productId);

  const queryByProductId = new Parse.Query(CatalogProduct);
  queryByProductId.equalTo("productId", productId);

  return Parse.Query.or(queryById, queryByProductId);
}

// 🔍 catalogGet: Retrieve single product + associated media
Parse.Cloud.define("catalogGet", async (request) => {
  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const auth = await extractAuthUser(request);
  const query = findProductQuery(productId);

  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  // Check access
  const isDeleted = product.get("deletedAt") != null;
  const isPrivate = product.get("scope") === "private";
  const creatorUid = product.get("creatorUid");

  if (isDeleted && (!auth || !auth.admin)) {
    throw new Parse.Error(404, "Product not found");
  }

  if (isPrivate && (!auth || (auth.uid !== creatorUid && !auth.admin))) {
    throw new Parse.Error(403, "Access denied to private product");
  }

  // Load associated media
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const mediaQuery = new Parse.Query(CatalogProductMedia);
  mediaQuery.equalTo("productId", product.get("productId") || product.id);
  mediaQuery.equalTo("status", "active");
  mediaQuery.descending("isPrimary");
  mediaQuery.ascending("sortOrder");

  const mediaList = await mediaQuery.find({ useMasterKey: true });

  return {
    success: true,
    product: { id: product.id, ...product.toJSON() },
    media: mediaList.map(m => ({ id: m.id, ...m.toJSON() }))
  };
});

// ➕ catalogCreate: Create new product with audit trail
Parse.Cloud.define("catalogCreate", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  if (!params.title || !params.title.trim()) {
    throw new Parse.Error(400, "Title is required");
  }

  const now = new Date();
  const productId = (params.productId || `prd_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`).trim();

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const product = new CatalogProduct();

  product.set("productId", productId);
  product.set("retailerId", params.retailerId || productId);
  product.set("originalCatalogId", params.originalCatalogId || "");
  product.set("title", params.title.trim());
  product.set("description", params.description || "");
  product.set("availability", params.availability || "in stock");
  product.set("condition", params.condition || "new");
  product.set("price", Number(params.price) || 0.0);
  product.set("currency", params.currency || "YER");
  product.set("link", normalizeProductLink(params.link, productId));
  product.set("imageLink", params.imageLink || "");
  product.set("additionalImageLinks", Array.isArray(params.additionalImageLinks) ? params.additionalImageLinks : []);
  product.set("videoUrl", params.videoUrl || null);
  product.set("brand", params.brand || null);
  product.set("googleProductCategory", params.googleProductCategory || null);
  product.set("fbProductCategory", params.fbProductCategory || null);
  product.set("categoryId", params.categoryId || null);
  product.set("categoryName", params.categoryName || null);
  product.set("metaProductType", params.metaProductType || null);
  product.set("quantity", parseInt(params.quantity, 10) || 1);
  product.set("salePrice", params.salePrice ? Number(params.salePrice) : null);
  product.set("salePriceEffectiveDate", params.salePriceEffectiveDate || null);
  product.set("itemGroupId", params.itemGroupId || null);
  product.set("gender", params.gender || null);
  product.set("color", params.color || null);
  product.set("size", params.size || null);
  product.set("ageGroup", params.ageGroup || null);
  product.set("material", params.material || null);
  product.set("pattern", params.pattern || null);
  product.set("shipping", params.shipping || null);
  product.set("shippingWeight", params.shippingWeight || null);
  product.set("gtin", params.gtin || null);
  product.set("productTags", Array.isArray(params.productTags) ? params.productTags : []);
  product.set("style", params.style || null);

  // Security: creatorUid strictly from verified token
  product.set("creatorUid", auth.uid);
  product.set("status", params.status || "approved");
  product.set("scope", params.scope || "global");
  product.set("source", params.source || "app");
  product.set("schemaVersion", 1);
  product.set("syncVersion", 1);
  product.set("clientUpdatedAt", params.clientUpdatedAt ? new Date(params.clientUpdatedAt) : now);
  product.set("lastSyncedAt", now);

  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", productId);
  log.set("operation", "create");
  log.set("actorUid", auth.uid);
  log.set("version", 1);
  log.set("changedFields", Object.keys(params));
  log.set("afterData", product.toJSON());
  log.set("source", params.source || "app");
  log.set("deviceId", params.deviceId || "unknown");
  await log.save(null, { useMasterKey: true });

  return { success: true, product: { id: product.id, ...product.toJSON() } };
});

// ✏️ catalogUpdate: Update with optimistic concurrency check
Parse.Cloud.define("catalogUpdate", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const query = findProductQuery(productId);
  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  const creatorUid = product.get("creatorUid");
  const canModify = auth.admin || (Boolean(creatorUid) && creatorUid === auth.uid);
  if (!canModify) {
    throw new Parse.Error(403, "Not authorized to update this product");
  }

  const beforeData = product.toJSON();
  const currentSyncVersion = product.get("syncVersion") || 1;

  if (params.expectedSyncVersion != null && currentSyncVersion > params.expectedSyncVersion) {
    throw new Parse.Error(409, `Conflict: Product version is ${currentSyncVersion}, expected ${params.expectedSyncVersion}`);
  }

  const allowedFields = [
    "title", "description", "availability", "condition", "price", "currency",
    "link", "imageLink", "additionalImageLinks", "videoUrl", "brand",
    "googleProductCategory", "fbProductCategory", "categoryId", "categoryName",
    "metaProductType", "quantity", "salePrice", "salePriceEffectiveDate",
    "itemGroupId", "gender", "color", "size", "ageGroup", "material",
    "pattern", "shipping", "shippingWeight", "gtin", "productTags",
    "style", "status", "scope"
  ];

  const changedFields = [];
  for (const field of allowedFields) {
    if (params[field] !== undefined) {
      if (field === "link") {
        product.set(field, normalizeProductLink(params[field], product.get("productId")));
      } else {
        product.set(field, params[field]);
      }
      changedFields.push(field);
    }
  }

  const nextVersion = currentSyncVersion + 1;
  product.set("syncVersion", nextVersion);
  product.set("clientUpdatedAt", params.clientUpdatedAt ? new Date(params.clientUpdatedAt) : new Date());
  product.set("lastSyncedAt", new Date());

  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", product.get("productId"));
  log.set("operation", "update");
  log.set("actorUid", auth.uid);
  log.set("version", nextVersion);
  log.set("changedFields", changedFields);
  log.set("beforeData", beforeData);
  log.set("afterData", product.toJSON());
  log.set("source", params.source || "app");
  log.set("deviceId", params.deviceId || "unknown");
  await log.save(null, { useMasterKey: true });

  return { success: true, product: { id: product.id, ...product.toJSON() } };
});

// 🗑️ catalogDelete: Soft deletion (prevents client resurrection)
Parse.Cloud.define("catalogDelete", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const query = findProductQuery(productId);
  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  const creatorUid = product.get("creatorUid");
  const canModify = auth.admin || (Boolean(creatorUid) && creatorUid === auth.uid);
  if (!canModify) {
    throw new Parse.Error(403, "Not authorized to delete this product");
  }

  const nextVersion = (product.get("syncVersion") || 1) + 1;
  product.set("status", "deleted");
  product.set("deletedAt", new Date());
  product.set("syncVersion", nextVersion);
  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", product.get("productId") || product.id);
  log.set("operation", "delete");
  log.set("actorUid", auth.uid);
  log.set("version", nextVersion);
  log.set("changedFields", ["status", "deletedAt"]);
  await log.save(null, { useMasterKey: true });

  return { success: true, productId: product.get("productId") || product.id, status: "deleted" };
});

// 🔄 catalogRestore: Restore soft-deleted product
Parse.Cloud.define("catalogRestore", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const query = findProductQuery(productId);
  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  const creatorUid = product.get("creatorUid");
  const canModify = auth.admin || (Boolean(creatorUid) && creatorUid === auth.uid);
  if (!canModify) {
    throw new Parse.Error(403, "Not authorized to restore this product");
  }

  const nextVersion = (product.get("syncVersion") || 1) + 1;
  product.set("status", "approved");
  product.unset("deletedAt");
  product.set("syncVersion", nextVersion);
  await product.save(null, { useMasterKey: true });

  return { success: true, productId: product.get("productId") || product.id, status: "approved" };
});

// 👑 catalogAssignOwner: Admin-only function to assign owner of products
Parse.Cloud.define("catalogAssignOwner", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");
  if (!auth.admin) throw new Parse.Error(403, "Admin authorization required");

  const params = request.params || {};
  const productId = params.productId || params.id;
  const targetUid = (params.targetUid || "").trim();
  if (!productId || !targetUid) {
    throw new Parse.Error(400, "productId and targetUid are required");
  }

  const query = findProductQuery(productId);
  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  const oldUid = product.get("creatorUid") || null;
  product.set("creatorUid", targetUid);
  const nextVersion = (product.get("syncVersion") || 1) + 1;
  product.set("syncVersion", nextVersion);
  await product.save(null, { useMasterKey: true });

  // Audit Log
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");
  const log = new CatalogChangeLog();
  log.set("product", product);
  log.set("productId", product.get("productId") || product.id);
  log.set("operation", "assign_owner");
  log.set("actorUid", auth.uid);
  log.set("version", nextVersion);
  log.set("changedFields", ["creatorUid"]);
  log.set("beforeData", { creatorUid: oldUid });
  log.set("afterData", { creatorUid: targetUid });
  await log.save(null, { useMasterKey: true });

  return { success: true, productId: product.get("productId") || product.id, creatorUid: targetUid };
});

// 🖼️ catalogMediaList: List all media for a product
Parse.Cloud.define("catalogMediaList", async (request) => {
  const params = request.params || {};
  const productId = params.productId;
  if (!productId) throw new Parse.Error(400, "productId is required");

  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const query = new Parse.Query(CatalogProductMedia);
  query.equalTo("productId", productId);
  query.equalTo("status", "active");
  query.descending("isPrimary");
  query.ascending("sortOrder");

  const list = await query.find({ useMasterKey: true });
  return { success: true, media: list.map(m => ({ id: m.id, ...m.toJSON() })) };
});

// 🖼️ catalogMediaAdd: Add/dedup media and sync with CatalogProduct denormalized fields
Parse.Cloud.define("catalogMediaAdd", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId;
  const url = (params.url || "").trim();
  const type = params.type || "image";

  if (!productId || !url) throw new Parse.Error(400, "productId and url are required");

  const query = findProductQuery(productId);
  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  const creatorUid = product.get("creatorUid");
  const canModify = auth.admin || (Boolean(creatorUid) && creatorUid === auth.uid);
  if (!canModify) {
    throw new Parse.Error(403, "Not authorized to modify media for this product");
  }

  const dedupeKey = computeMediaDedupeKey(productId, type, url);

  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const mQuery = new Parse.Query(CatalogProductMedia);
  mQuery.equalTo("dedupeKey", dedupeKey);
  let media = await mQuery.first({ useMasterKey: true });

  const isNew = !media;
  if (!media) {
    media = new CatalogProductMedia();
    media.set("dedupeKey", dedupeKey);
    media.set("product", product);
    media.set("productId", productId);
    media.set("type", type);
    media.set("url", url);
    media.set("thumbnailUrl", params.thumbnailUrl || url);
    media.set("mimeType", params.mimeType || (type === "video" ? "video/mp4" : "image/jpeg"));
    media.set("filename", params.filename || null);
    media.set("sortOrder", Number(params.sortOrder) || 0);
    media.set("isPrimary", Boolean(params.isPrimary));
    media.set("source", params.source || "app");
    media.set("status", "active");
    media.set("width", Number(params.width) || null);
    media.set("height", Number(params.height) || null);
    media.set("durationMs", Number(params.durationMs) || null);
    media.set("metadata", params.metadata || {});
    await media.save(null, { useMasterKey: true });
  }

  // Synchronize denormalized fields on CatalogProduct
  if (type === "video") {
    if (!product.get("videoUrl") || params.isPrimary) {
      product.set("videoUrl", url);
    }
  } else if (type === "image") {
    if (params.isPrimary || !product.get("imageLink")) {
      product.set("imageLink", url);
    } else {
      const currentAdditional = product.get("additionalImageLinks") || [];
      if (!currentAdditional.includes(url)) {
        product.set("additionalImageLinks", [...currentAdditional, url]);
      }
    }
  }
  await product.save(null, { useMasterKey: true });

  return { success: true, created: isNew, media: { id: media.id, ...media.toJSON() } };
});

// 📤 catalogUploadMedia: Server-side secure file upload to Back4App Parse Files
Parse.Cloud.define("catalogUploadMedia", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const fileBase64 = params.fileBase64;
  const fileName = (params.fileName || `media_${Date.now()}.jpg`).replace(/[^a-zA-Z0-9_.-]/g, "_");
  const mimeType = params.mimeType || "image/jpeg";

  if (!fileBase64) throw new Parse.Error(400, "fileBase64 is required");

  try {
    const parseFile = new Parse.File(fileName, { base64: fileBase64 }, mimeType);
    await parseFile.save({ useMasterKey: true });
    const fileUrl = parseFile.url();

    return {
      success: true,
      url: fileUrl,
      name: parseFile.name(),
    };
  } catch (error) {
    console.error("catalogUploadMedia error:", error);
    throw new Parse.Error(500, `Failed to upload file to Back4App storage: ${error.message}`);
  }
});

// 📑 catalogUploadFeed: Server-side secure CSV feed upload to Back4App Parse Files
Parse.Cloud.define("catalogUploadFeed", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const csvContent = params.csvContent || "";
  const fileBase64 = params.fileBase64 || Buffer.from(csvContent, "utf8").toString("base64");
  const fileName = (params.fileName || `catalog_${auth.uid}_feed.csv`).replace(/[^a-zA-Z0-9_.-]/g, "_");

  if (!fileBase64 && !csvContent) throw new Parse.Error(400, "csvContent or fileBase64 is required");

  try {
    const parseFile = new Parse.File(fileName, { base64: fileBase64 }, "text/csv; charset=utf-8");
    await parseFile.save({ useMasterKey: true });
    const fileUrl = parseFile.url();

    return {
      success: true,
      url: fileUrl,
      name: parseFile.name(),
    };
  } catch (error) {
    console.error("catalogUploadFeed error:", error);
    throw new Parse.Error(500, `Failed to upload CSV feed to Back4App storage: ${error.message}`);
  }
});

// 🗂️ catalogCategoriesList: Return active categories
Parse.Cloud.define("catalogCategoriesList", async () => {
  const CatalogCategory = Parse.Object.extend("CatalogCategory");
  const query = new Parse.Query(CatalogCategory);
  query.equalTo("active", true);
  query.ascending("sortOrder");

  const list = await query.find({ useMasterKey: true });
  return { success: true, categories: list.map(c => ({ id: c.id, ...c.toJSON() })) };
});

// 🗂️ catalogCategoryUpsert: Admin-only category upsert
Parse.Cloud.define("catalogCategoryUpsert", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");

  const params = request.params || {};
  const categoryId = params.categoryId;
  if (!categoryId) throw new Parse.Error(400, "categoryId is required");

  const CatalogCategory = Parse.Object.extend("CatalogCategory");
  const query = new Parse.Query(CatalogCategory);
  query.equalTo("categoryId", categoryId);

  let cat = await query.first({ useMasterKey: true });
  if (!cat) {
    cat = new CatalogCategory();
    cat.set("categoryId", categoryId);
  }

  cat.set("name", params.name || categoryId);
  cat.set("nameAr", params.nameAr || params.name || categoryId);
  cat.set("slug", params.slug || categoryId);
  cat.set("googleCategory", params.googleCategory || "");
  cat.set("fbCategory", params.fbCategory || "");
  cat.set("imageUrl", params.imageUrl || "");
  cat.set("sortOrder", Number(params.sortOrder) || 0);
  cat.set("active", params.active !== false);
  cat.set("scope", params.scope || "global");
  cat.set("creatorUid", auth.uid);
  cat.set("metadata", params.metadata || {});

  await cat.save(null, { useMasterKey: true });
  return { success: true, category: { id: cat.id, ...cat.toJSON() } };
});

// 🔄 catalogRecoverLegacyWhatsappMedia: Audit and recover expired WhatsApp CDN media to Back4App Parse Files
Parse.Cloud.define("catalogRecoverLegacyWhatsappMedia", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");

  const params = request.params || {};
  const dryRun = params.dryRun !== false; // Default is true for safety
  const maxLimit = Number(params.limit) || 1000;

  const isWhatsappCdnUrl = (url) => {
    if (!url || typeof url !== "string") return false;
    const clean = url.trim().toLowerCase();
    return clean.includes("cdn.whatsapp.net") || clean.includes("pps.whatsapp.net");
  };

  const isBack4AppPermanentUrl = (url) => {
    if (!url || typeof url !== "string") return false;
    return url.trim().includes("parsefiles.back4app.com");
  };

  // 1. Audit CatalogProduct records
  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const pQuery = new Parse.Query(CatalogProduct);
  pQuery.limit(maxLimit);
  const products = await pQuery.find({ useMasterKey: true });

  const totalProducts = products.length;
  let affectedProducts = 0;
  let expiredPrimaryImages = 0;
  let expiredAdditionalImages = 0;
  let expiredVideos = 0;
  let alreadyPermanent = 0;
  let recoverableMedia = 0;
  let unrecoverableMedia = 0;

  const sample = [];

  for (const product of products) {
    const pId = product.get("productId") || product.id;
    const imgLink = (product.get("imageLink") || "").trim();
    const additionalLinks = product.get("additionalImageLinks") || [];
    const vidUrl = (product.get("videoUrl") || "").trim();

    let productHasExpiredMedia = false;
    let primaryExpired = false;
    const additionalExpiredIndices = [];
    let videoExpired = false;

    if (isWhatsappCdnUrl(imgLink)) {
      productHasExpiredMedia = true;
      primaryExpired = true;
      expiredPrimaryImages++;
    } else if (isBack4AppPermanentUrl(imgLink)) {
      alreadyPermanent++;
    }

    additionalLinks.forEach((link, idx) => {
      if (isWhatsappCdnUrl(link)) {
        productHasExpiredMedia = true;
        additionalExpiredIndices.push(idx);
        expiredAdditionalImages++;
      } else if (isBack4AppPermanentUrl(link)) {
        alreadyPermanent++;
      }
    });

    if (isWhatsappCdnUrl(vidUrl)) {
      productHasExpiredMedia = true;
      videoExpired = true;
      expiredVideos++;
    } else if (isBack4AppPermanentUrl(vidUrl)) {
      alreadyPermanent++;
    }

    if (productHasExpiredMedia) {
      affectedProducts++;
      if (sample.length < 20) {
        sample.push({
          productId: pId,
          title: (product.get("title") || "").slice(0, 40),
          hasPrimaryExpired: primaryExpired,
          expiredAdditionalCount: additionalExpiredIndices.length,
          hasVideoExpired: videoExpired,
        });
      }

      if (!dryRun) {
        let updated = false;

        // 1. Try recovering primary image
        if (primaryExpired && imgLink) {
          try {
            const resp = await axios.get(imgLink, { responseType: "arraybuffer", timeout: 7000 });
            if (resp.status === 200 && resp.data && resp.data.length > 0) {
              const fileName = `recovered_p_${pId}_${Date.now()}.jpg`;
              const mimeType = resp.headers["content-type"] || "image/jpeg";
              const parseFile = new Parse.File(fileName, { base64: Buffer.from(resp.data).toString("base64") }, mimeType);
              await parseFile.save({ useMasterKey: true });
              product.set("imageLink", parseFile.url());
              recoverableMedia++;
              updated = true;
              console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=image status=recovered`);
            } else {
              unrecoverableMedia++;
              console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=image status=unrecoverable`);
            }
          } catch (e) {
            unrecoverableMedia++;
            console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=image status=unrecoverable`);
          }
        }

        // 2. Try recovering additional images
        if (additionalExpiredIndices.length > 0) {
          const newAdditional = [...additionalLinks];
          for (const idx of additionalExpiredIndices) {
            const url = newAdditional[idx];
            try {
              const resp = await axios.get(url, { responseType: "arraybuffer", timeout: 7000 });
              if (resp.status === 200 && resp.data && resp.data.length > 0) {
                const fileName = `recovered_add_${pId}_${idx}_${Date.now()}.jpg`;
                const mimeType = resp.headers["content-type"] || "image/jpeg";
                const parseFile = new Parse.File(fileName, { base64: Buffer.from(resp.data).toString("base64") }, mimeType);
                await parseFile.save({ useMasterKey: true });
                newAdditional[idx] = parseFile.url();
                recoverableMedia++;
                updated = true;
                console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=additional_image status=recovered`);
              } else {
                unrecoverableMedia++;
                console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=additional_image status=unrecoverable`);
              }
            } catch (e) {
              unrecoverableMedia++;
              console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=additional_image status=unrecoverable`);
            }
          }
          if (updated) {
            product.set("additionalImageLinks", newAdditional);
          }
        }

        // 3. Try recovering video
        if (videoExpired && vidUrl) {
          try {
            const resp = await axios.get(vidUrl, { responseType: "arraybuffer", timeout: 12000 });
            if (resp.status === 200 && resp.data && resp.data.length > 0) {
              const fileName = `recovered_vid_${pId}_${Date.now()}.mp4`;
              const mimeType = resp.headers["content-type"] || "video/mp4";
              const parseFile = new Parse.File(fileName, { base64: Buffer.from(resp.data).toString("base64") }, mimeType);
              await parseFile.save({ useMasterKey: true });
              product.set("videoUrl", parseFile.url());
              recoverableMedia++;
              updated = true;
              console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=video status=recovered`);
            } else {
              unrecoverableMedia++;
              console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=video status=unrecoverable`);
            }
          } catch (e) {
            unrecoverableMedia++;
            console.log(`[LEGACY_MEDIA_RECOVERY] productId=${pId} type=video status=unrecoverable`);
          }
        }

        if (updated) {
          const nextVersion = (product.get("syncVersion") || 1) + 1;
          product.set("syncVersion", nextVersion);
          await product.save(null, { useMasterKey: true });
        }
      }
    }
  }

  // 2. Audit and update CatalogProductMedia records
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const mQuery = new Parse.Query(CatalogProductMedia);
  mQuery.limit(maxLimit);
  const mediaRecords = await mQuery.find({ useMasterKey: true });

  for (const m of mediaRecords) {
    const url = (m.get("url") || "").trim();
    if (isWhatsappCdnUrl(url)) {
      if (!dryRun) {
        if (m.get("status") !== "broken_legacy") {
          m.set("status", "broken_legacy");
          m.set("metadata", {
            ...(m.get("metadata") || {}),
            legacyHost: "cdn.whatsapp.net",
            httpStatus: 403,
            recoveryStatus: "unavailable"
          });
          await m.save(null, { useMasterKey: true });
        }
      }
    }
  }

  const totalExpiredMedia = expiredPrimaryImages + expiredAdditionalImages + expiredVideos;

  return {
    success: true,
    dryRun,
    report: {
      TOTAL_PRODUCTS: totalProducts,
      AFFECTED_PRODUCTS: affectedProducts,
      EXPIRED_PRIMARY_IMAGES: expiredPrimaryImages,
      EXPIRED_ADDITIONAL_IMAGES: expiredAdditionalImages,
      EXPIRED_VIDEOS: expiredVideos,
      TOTAL_EXPIRED_MEDIA: totalExpiredMedia,
      ALREADY_PERMANENT: alreadyPermanent,
      RECOVERABLE_MEDIA: recoverableMedia,
      UNRECOVERABLE_MEDIA: dryRun ? totalExpiredMedia : unrecoverableMedia,
    },
    sample,
  };
});

// ⚡ catalogPullChanges: Delta synchronization with opaque server cursor
Parse.Cloud.define("catalogPullChanges", async (request) => {
  const params = request.params || {};
  const cursor = (params.cursor || "").trim(); // format: "ISOString_objectId"
  const limit = Math.min(200, Math.max(1, parseInt(params.limit || 100, 10)));

  const auth = await extractAuthUser(request);
  const userUid = auth ? auth.uid : null;

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const query = new Parse.Query(CatalogProduct);

  if (cursor && cursor.includes("_")) {
    const parts = cursor.split("_");
    const cursorDate = new Date(parts[0]);
    const cursorId = parts[1];

    if (!isNaN(cursorDate.getTime())) {
      const dateQuery = new Parse.Query(CatalogProduct);
      dateQuery.greaterThan("updatedAt", cursorDate);

      const tieQuery = new Parse.Query(CatalogProduct);
      tieQuery.equalTo("updatedAt", cursorDate);
      tieQuery.greaterThan("objectId", cursorId);

      const compQuery = Parse.Query.or(dateQuery, tieQuery);
      // Combine with security
      if (!auth || !auth.admin) {
        if (userUid) {
          const gQuery = new Parse.Query(CatalogProduct);
          gQuery.equalTo("scope", "global");
          const oQuery = new Parse.Query(CatalogProduct);
          oQuery.equalTo("creatorUid", userUid);
          compQuery.matchesKeyInQuery("objectId", "objectId", Parse.Query.or(gQuery, oQuery));
        } else {
          compQuery.equalTo("scope", "global");
        }
      }

      compQuery.ascending("updatedAt");
      compQuery.addAscending("objectId");
      compQuery.limit(limit + 1);

      const results = await compQuery.find({ useMasterKey: true });
      const hasMore = results.length > limit;
      const items = hasMore ? results.slice(0, limit) : results;

      let nextCursor = cursor;
      if (items.length > 0) {
        const last = items[items.length - 1];
        nextCursor = `${last.updatedAt.toISOString()}_${last.id}`;
      }

      return {
        success: true,
        items: items.map(p => ({ id: p.id, ...p.toJSON() })),
        nextCursor,
        hasMore
      };
    }
  }

  // Initial pull
  if (!auth || !auth.admin) {
    if (userUid) {
      const gQuery = new Parse.Query(CatalogProduct);
      gQuery.equalTo("scope", "global");
      const oQuery = new Parse.Query(CatalogProduct);
      oQuery.equalTo("creatorUid", userUid);
      const scoped = Parse.Query.or(gQuery, oQuery);
      scoped.ascending("updatedAt");
      scoped.addAscending("objectId");
      scoped.limit(limit + 1);
      const results = await scoped.find({ useMasterKey: true });
      const hasMore = results.length > limit;
      const items = hasMore ? results.slice(0, limit) : results;
      let nextCursor = "";
      if (items.length > 0) {
        const last = items[items.length - 1];
        nextCursor = `${last.updatedAt.toISOString()}_${last.id}`;
      }
      return { success: true, items: items.map(p => ({ id: p.id, ...p.toJSON() })), nextCursor, hasMore };
    } else {
      query.equalTo("scope", "global");
    }
  }

  query.ascending("updatedAt");
  query.addAscending("objectId");
  query.limit(limit + 1);

  const results = await query.find({ useMasterKey: true });
  const hasMore = results.length > limit;
  const items = hasMore ? results.slice(0, limit) : results;

  let nextCursor = "";
  if (items.length > 0) {
    const last = items[items.length - 1];
    nextCursor = `${last.updatedAt.toISOString()}_${last.id}`;
  }

  return {
    success: true,
    items: items.map(p => ({ id: p.id, ...p.toJSON() })),
    nextCursor,
    hasMore
  };
});

// 🚀 catalogImportBatch: ADMIN-ONLY Idempotent Batch Migration Engine
Parse.Cloud.define("catalogImportBatch", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) {
    throw new Parse.Error(403, "Forbidden: catalogImportBatch is strictly restricted to authorized administrators");
  }

  const params = request.params || {};
  const products = Array.isArray(params.products) ? params.products : [];
  if (products.length === 0) {
    return { success: true, products_seen: 0, products_created: 0, products_updated: 0, media_created: 0, media_skipped: 0 };
  }

  let productsCreated = 0;
  let productsUpdated = 0;
  let mediaCreated = 0;
  let mediaSkipped = 0;
  const errors = [];

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");

  for (const item of products) {
    try {
      const pid = (item.productId || item.id || "").trim();
      if (!pid) {
        errors.push({ error: "Missing productId", item });
        continue;
      }

      // 1. Find existing or create new
      const pQuery = new Parse.Query(CatalogProduct);
      pQuery.equalTo("productId", pid);
      let product = await pQuery.first({ useMasterKey: true });

      const isNew = !product;
      if (!product) {
        product = new CatalogProduct();
        product.set("productId", pid);
        product.set("syncVersion", 1);
        productsCreated++;
      } else {
        product.set("syncVersion", (product.get("syncVersion") || 1) + 1);
        productsUpdated++;
      }

      const now = new Date();
      product.set("retailerId", item.retailerId || pid);
      product.set("originalCatalogId", item.originalCatalogId || "");
      product.set("title", item.title || "");
      product.set("description", item.description || "");
      product.set("availability", item.availability || "in stock");
      product.set("condition", item.condition || "new");
      product.set("price", Number(item.price) || 0.0);
      product.set("currency", item.currency || "YER");
      product.set("link", normalizeProductLink(item.link, pid));
      product.set("imageLink", item.imageLink || "");
      product.set("additionalImageLinks", Array.isArray(item.additionalImageLinks) ? item.additionalImageLinks : []);
      product.set("videoUrl", item.videoUrl || null);
      product.set("brand", item.brand || null);
      product.set("googleProductCategory", item.googleProductCategory || null);
      product.set("fbProductCategory", item.fbProductCategory || null);
      product.set("categoryId", item.categoryId || null);
      product.set("categoryName", item.categoryName || null);
      product.set("metaProductType", item.metaProductType || null);
      product.set("quantity", Number(item.quantity) || 1);
      product.set("salePrice", item.salePrice != null ? Number(item.salePrice) : null);
      product.set("salePriceEffectiveDate", item.salePriceEffectiveDate || null);
      product.set("itemGroupId", item.itemGroupId || null);
      product.set("gender", item.gender || null);
      product.set("color", item.color || null);
      product.set("size", item.size || null);
      product.set("ageGroup", item.ageGroup || null);
      product.set("material", item.material || null);
      product.set("pattern", item.pattern || null);
      product.set("shipping", item.shipping || null);
      product.set("shippingWeight", item.shippingWeight || null);
      product.set("gtin", item.gtin || null);
      product.set("productTags", Array.isArray(item.productTags) ? item.productTags : []);
      product.set("style", item.style || null);
      product.set("creatorUid", item.creatorUid || "system_import");
      product.set("status", item.status || "approved");
      product.set("scope", item.scope || "global");
      product.set("source", item.source || "excel");
      product.set("schemaVersion", 1);
      product.set("clientUpdatedAt", now);
      product.set("lastSyncedAt", now);

      await product.save(null, { useMasterKey: true });

      // 2. Process Media list
      const mediaList = Array.isArray(item.media) ? item.media : [];
      for (const m of mediaList) {
        const mUrl = (m.url || "").trim();
        if (!mUrl) continue;
        const mType = m.type || "image";
        const dedupeKey = computeMediaDedupeKey(pid, mType, mUrl);

        const mQuery = new Parse.Query(CatalogProductMedia);
        mQuery.equalTo("dedupeKey", dedupeKey);
        const existingMedia = await mQuery.first({ useMasterKey: true });

        if (!existingMedia) {
          const newMedia = new CatalogProductMedia();
          newMedia.set("dedupeKey", dedupeKey);
          newMedia.set("product", product);
          newMedia.set("productId", pid);
          newMedia.set("type", mType);
          newMedia.set("url", mUrl);
          newMedia.set("thumbnailUrl", m.thumbnailUrl || mUrl);
          newMedia.set("mimeType", m.mimeType || (mType === "video" ? "video/mp4" : "image/jpeg"));
          newMedia.set("filename", m.filename || null);
          newMedia.set("sortOrder", Number(m.sortOrder) || 0);
          newMedia.set("isPrimary", Boolean(m.isPrimary));
          newMedia.set("source", item.source || "excel");
          newMedia.set("status", "active");
          newMedia.set("width", Number(m.width) || null);
          newMedia.set("height", Number(m.height) || null);
          newMedia.set("durationMs", Number(m.durationMs) || null);
          newMedia.set("metadata", m.metadata || {});
          await newMedia.save(null, { useMasterKey: true });
          mediaCreated++;
        } else {
          mediaSkipped++;
        }
      }
    } catch (err) {
      errors.push({ error: err.message || String(err), productId: item.productId });
    }
  }

  return {
    success: true,
    products_seen: products.length,
    products_created: productsCreated,
    products_updated: productsUpdated,
    media_created: mediaCreated,
    media_skipped: mediaSkipped,
    errors
  };
});

// 📊 catalogGetSchemaStatus: Live Diagnostic Verification Function
Parse.Cloud.define("catalogGetSchemaStatus", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");

  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  const CatalogCategory = Parse.Object.extend("CatalogCategory");
  const CatalogSyncState = Parse.Object.extend("CatalogSyncState");
  const CatalogChangeLog = Parse.Object.extend("CatalogChangeLog");

  const [productCount, mediaCount, categoryCount, syncCount, logCount] = await Promise.all([
    new Parse.Query(CatalogProduct).count({ useMasterKey: true }),
    new Parse.Query(CatalogProductMedia).count({ useMasterKey: true }),
    new Parse.Query(CatalogCategory).count({ useMasterKey: true }),
    new Parse.Query(CatalogSyncState).count({ useMasterKey: true }),
    new Parse.Query(CatalogChangeLog).count({ useMasterKey: true })
  ]);

  // Count image vs video
  const imageCount = await new Parse.Query(CatalogProductMedia).equalTo("type", "image").count({ useMasterKey: true });
  const videoCount = await new Parse.Query(CatalogProductMedia).equalTo("type", "video").count({ useMasterKey: true });

  return {
    success: true,
    counts: {
      CatalogProduct: productCount,
      CatalogProductMedia: mediaCount,
      CatalogProductMedia_images: imageCount,
      CatalogProductMedia_videos: videoCount,
      CatalogCategory: categoryCount,
      CatalogSyncState: syncCount,
      CatalogChangeLog: logCount
    }
  };
});

// 🛠️ catalogBootstrap: Server-side schema & CLP initialization endpoint
Parse.Cloud.define("catalogBootstrap", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth || !auth.admin) throw new Parse.Error(403, "Admin authorization required");
  const result = await bootstrapCatalogSchemas();
  return { success: true, bootstrap: result };
});

// ============================================================================
// 📱 5️⃣ WHATSAPP MEDIA SYNC & SUPPLIER BATCH MODULE
// ============================================================================

const DEFAULT_WHATSAPP_CONFIG = {
  phoneNumber: "+967738609222",
  wabaId: "28459237033683884",
  phoneNumberId: "1307082469145976",
  metaAppId: "1403080371744739",
  contactEmail: "smartaccuont@gmail.com",
  privacyPolicyUrl: "https://smartcontentcreator2.web.app/privacy-policy",
  termsOfServiceUrl: "https://smartcontentcreator2.web.app/terms",
  dataDeletionUrl: "https://smartcontentcreator2.web.app/data-deletion",
  verifyToken: process.env.WHATSAPP_VERIFY_TOKEN || "indexes_wa_secret_verify_2026",
  autoAiProcess: true,
  status: "active",
  lastSyncAt: new Date().toISOString(),
  mediaCount: 14,
  accounts: [
    {
      name: "اندكس للتجارة",
      wabaId: "28459237033683884",
      phone: "+967738609222",
      phoneNumberId: "1307082469145976",
      status: "مسجّل",
    },
    {
      name: "اندكس للتجارة 1",
      wabaId: "2347070759160644",
      phone: "+967785574271",
      phoneNumberId: "1282161161642455",
      status: "لم يتم التحقق",
    },
  ],
};

function sanitizeWaFileName(caption, mimeType) {
  const ext = mimeType.includes("video") ? "mp4" : mimeType.includes("pdf") ? "pdf" : "jpg";
  if (!caption || !caption.trim()) return `wa_${Date.now()}.${ext}`;
  const cleaned = caption
    .trim()
    .replace(/[^\u0600-\u06FFa-zA-Z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .substring(0, 40);
  return `${cleaned || `wa_${Date.now()}`}.${ext}`;
}

function extractWaCategoryAndTags(caption) {
  if (!caption || !caption.trim()) {
    return { category: "وسائط متنوعة", tags: ["واتساب"] };
  }
  const text = caption.trim();
  const words = text
    .replace(/[^\u0600-\u06FFa-zA-Z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length >= 2);
  const tags = Array.from(new Set(words));
  let category = "وسائط متنوعة";
  const lower = text.toLowerCase();

  if (/منشار|مفك|طقم|عده|معدات|مولد|بطارية|شاحن|أدوات|تثقيب/.test(lower)) {
    category = "معدات وأدوات";
  } else if (/كاميرا|هاتف|جوال|سماعة|شاشة|تلفزيون|ساعة|الكترونيات|ذكي|فحص|أنابيب/.test(lower)) {
    category = "إلكترونيات";
  } else if (/ساعة|خاتم|مجوهرات|عطر|بخور|فاخر/.test(lower)) {
    category = "ساعات ومجوهرات";
  } else if (/قميص|ثوب|فستان|حذاء|حقيبة|ملابس/.test(lower)) {
    category = "أزياء وموضة";
  }
  return { category, tags };
}

// Extract numeric price from text
function extractPriceFromText(text) {
  if (!text) return 15000;
  const match = text.match(/\b\d+([.,]\d+)?\b/);
  if (match) {
    const val = parseFloat(match[0].replace(",", "."));
    if (!isNaN(val) && val > 0) return val;
  }
  return 15000;
}

// 📥 whatsAppGetConfig: Fetch active WhatsApp config & WABA accounts
Parse.Cloud.define("whatsAppGetConfig", async (request) => {
  const WhatsAppConfig = Parse.Object.extend("WhatsAppConfig");
  const query = new Parse.Query(WhatsAppConfig);
  const configObj = await query.first({ useMasterKey: true });

  if (!configObj) {
    return { success: true, config: DEFAULT_WHATSAPP_CONFIG };
  }
  return { success: true, config: { ...DEFAULT_WHATSAPP_CONFIG, ...configObj.toJSON() } };
});

// 💾 whatsAppSaveConfig: Save live WhatsApp config
Parse.Cloud.define("whatsAppSaveConfig", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const WhatsAppConfig = Parse.Object.extend("WhatsAppConfig");
  const query = new Parse.Query(WhatsAppConfig);
  let configObj = await query.first({ useMasterKey: true });

  if (!configObj) {
    configObj = new WhatsAppConfig();
  }

  const allowed = [
    "phoneNumber", "wabaId", "phoneNumberId", "metaAppId", "contactEmail",
    "privacyPolicyUrl", "termsOfServiceUrl", "dataDeletionUrl", "verifyToken",
    "autoAiProcess", "status", "accounts"
  ];
  for (const k of allowed) {
    if (params[k] !== undefined) configObj.set(k, params[k]);
  }
  configObj.set("updatedAt", new Date());
  await configObj.save(null, { useMasterKey: true });

  return { success: true, config: { ...DEFAULT_WHATSAPP_CONFIG, ...configObj.toJSON() } };
});

// 🧪 whatsAppSimulateInbound: Test Sandbox Simulation
Parse.Cloud.define("whatsAppSimulateInbound", async (request) => {
  const params = request.params || {};
  const fileUrl = params.fileUrl || "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&auto=format&fit=crop";
  const caption = params.caption || "ساعة ابل واش الترا سوداء فاخرة";
  const senderPhone = params.senderPhone || "+967771370740";
  const fileType = params.fileType || "image";

  const mimeType = fileType === "video" ? "video/mp4" : "image/jpeg";
  const fileName = sanitizeWaFileName(caption, mimeType);
  const { category, tags } = extractWaCategoryAndTags(caption);
  const estimatedPrice = extractPriceFromText(caption);

  const aiSuggestion = {
    title: caption || "منتج واتساب جديد",
    description: `تم استيراد هذا المنتج تلقائياً عبر خدمة WhatsApp Media Sync من الرقم: ${senderPhone}.`,
    category,
    price: estimatedPrice,
    tags: tags.length ? tags : ["واتساب", "جديد"],
  };

  // Register in WhatsAppInbound
  const WhatsAppInbound = Parse.Object.extend("WhatsAppInbound");
  const inbound = new WhatsAppInbound();
  inbound.set("messageId", `sim_${Date.now()}`);
  inbound.set("senderPhone", senderPhone);
  inbound.set("senderName", "مورد تجريبي");
  inbound.set("caption", caption);
  inbound.set("mediaType", fileType);
  inbound.set("mediaUrl", fileUrl);
  inbound.set("persistentMediaUrl", fileUrl);
  inbound.set("mimeType", mimeType);
  inbound.set("fileName", fileName);
  inbound.set("receivedAt", new Date());
  inbound.set("status", "processed");
  inbound.set("aiSuggestion", aiSuggestion);
  await inbound.save(null, { useMasterKey: true });

  return {
    success: true,
    inboundId: inbound.id,
    fileName,
    category,
    tags,
    aiSuggestion,
    mediaUrl: fileUrl,
  };
});

// 📦 whatsAppProcessSupplierBatch: Group multi-image supplier batch into a WhatsAppDraft
Parse.Cloud.define("whatsAppProcessSupplierBatch", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const images = Array.isArray(params.images) ? params.images : [];
  const videoUrl = params.videoUrl || null;
  const priceText = params.priceText || "";
  const supplierPhone = params.supplierPhone || "+967738609222";

  if (!images.length) throw new Parse.Error(400, "At least one image is required");

  const primaryImg = images[0];
  const { category, tags } = extractWaCategoryAndTags(priceText);
  const extractedPrice = extractPriceFromText(priceText);

  const aiSuggestion = {
    title: priceText || "منتج مورد جديد من الواتساب",
    description: `تم الاستيراد التلقائي عبر دفعة المورد: ${supplierPhone}\n${priceText}`,
    category,
    price: extractedPrice,
    tags,
  };

  const WhatsAppDraft = Parse.Object.extend("WhatsAppDraft");
  const draft = new WhatsAppDraft();
  draft.set("supplierPhone", supplierPhone);
  draft.set("title", aiSuggestion.title);
  draft.set("description", aiSuggestion.description);
  draft.set("price", extractedPrice);
  draft.set("currency", "YER");
  draft.set("imageLink", primaryImg);
  draft.set("additionalImageLinks", images.slice(1));
  draft.set("videoUrl", videoUrl);
  draft.set("categoryName", category);
  draft.set("status", "pending_review");
  draft.set("aiSuggestion", aiSuggestion);
  draft.set("receivedAt", new Date());
  await draft.save(null, { useMasterKey: true });

  return {
    success: true,
    draft: { id: draft.id, ...draft.toJSON() },
    aiSuggestion,
    imagesCount: images.length,
    hasVideo: Boolean(videoUrl),
  };
});

// 📋 whatsAppGetPendingDrafts: List pending review drafts
Parse.Cloud.define("whatsAppGetPendingDrafts", async (request) => {
  const WhatsAppDraft = Parse.Object.extend("WhatsAppDraft");
  const query = new Parse.Query(WhatsAppDraft);
  query.equalTo("status", "pending_review");
  query.descending("createdAt");
  query.limit(100);

  const drafts = await query.find({ useMasterKey: true });
  return { success: true, drafts: drafts.map((d) => ({ id: d.id, ...d.toJSON() })) };
});

// ✅ whatsAppApproveDraft: Convert approved draft directly into authoritative CatalogProduct
Parse.Cloud.define("whatsAppApproveDraft", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const draftId = params.draftId;
  if (!draftId) throw new Parse.Error(400, "draftId is required");

  const WhatsAppDraft = Parse.Object.extend("WhatsAppDraft");
  const draftQuery = new Parse.Query(WhatsAppDraft);
  const draft = await draftQuery.get(draftId, { useMasterKey: true });
  if (!draft) throw new Parse.Error(404, "Draft not found");

  const now = new Date();
  const productId = `prd_wa_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;

  const title = (params.title || draft.get("title") || "منتج واتساب معتمد").trim();
  const description = params.description || draft.get("description") || "";
  const price = Number(params.price) || draft.get("price") || 15000.0;
  const imageLink = draft.get("imageLink") || "";
  const additionalImageLinks = draft.get("additionalImageLinks") || [];
  const videoUrl = draft.get("videoUrl") || null;
  const categoryName = params.categoryName || draft.get("categoryName") || "🛍️ متنوعات";

  // 1. Create CatalogProduct
  const CatalogProduct = Parse.Object.extend("CatalogProduct");
  const product = new CatalogProduct();
  product.set("productId", productId);
  product.set("retailerId", productId);
  product.set("title", title);
  product.set("description", description);
  product.set("price", price);
  product.set("currency", "YER");
  product.set("availability", "in stock");
  product.set("condition", "new");
  product.set("imageLink", imageLink);
  product.set("additionalImageLinks", additionalImageLinks);
  product.set("videoUrl", videoUrl);
  product.set("categoryName", categoryName);
  product.set("creatorUid", auth.uid);
  product.set("status", "approved");
  product.set("scope", "global");
  product.set("source", "whatsapp_sync");
  product.set("syncVersion", 1);
  product.set("lastSyncedAt", now);
  await product.save(null, { useMasterKey: true });

  // 2. Create CatalogProductMedia records
  const CatalogProductMedia = Parse.Object.extend("CatalogProductMedia");
  if (imageLink && imageLink.startsWith("http")) {
    const m = new CatalogProductMedia();
    m.set("productId", productId);
    m.set("type", "image");
    m.set("url", imageLink);
    m.set("isPrimary", true);
    m.set("sortOrder", 0);
    m.set("dedupeKey", computeMediaDedupeKey(productId, "image", imageLink));
    m.set("status", "active");
    await m.save(null, { useMasterKey: true });
  }

  for (let i = 0; i < additionalImageLinks.length; i++) {
    const url = additionalImageLinks[i];
    if (url && url.startsWith("http")) {
      const m = new CatalogProductMedia();
      m.set("productId", productId);
      m.set("type", "image");
      m.set("url", url);
      m.set("isPrimary", false);
      m.set("sortOrder", i + 1);
      m.set("dedupeKey", computeMediaDedupeKey(productId, "image", url));
      m.set("status", "active");
      await m.save(null, { useMasterKey: true });
    }
  }

  if (videoUrl && videoUrl.startsWith("http")) {
    const m = new CatalogProductMedia();
    m.set("productId", productId);
    m.set("type", "video");
    m.set("url", videoUrl);
    m.set("isPrimary", true);
    m.set("sortOrder", 0);
    m.set("dedupeKey", computeMediaDedupeKey(productId, "video", videoUrl));
    m.set("status", "active");
    await m.save(null, { useMasterKey: true });
  }

  // 3. Mark Draft as approved
  draft.set("status", "approved");
  draft.set("approvedProductId", productId);
  draft.set("approvedAt", now);
  await draft.save(null, { useMasterKey: true });

  return {
    success: true,
    productId,
    product: { id: product.id, ...product.toJSON() },
  };
});

// 📤 whatsAppSendProduct: Send catalog product card over WhatsApp Cloud API
Parse.Cloud.define("whatsAppSendProduct", async (request) => {
  const auth = await extractAuthUser(request);
  if (!auth) throw new Parse.Error(401, "Authentication required");

  const params = request.params || {};
  const productId = params.productId;
  const destinationPhone = (params.destinationPhone || "").replace(/[^\d+]/g, "");

  if (!productId) throw new Parse.Error(400, "productId is required");
  if (!destinationPhone) throw new Parse.Error(400, "destinationPhone is required");

  const query = findProductQuery(productId);
  const product = await query.first({ useMasterKey: true });
  if (!product) throw new Parse.Error(404, "Product not found");

  const title = product.get("title");
  const price = product.get("price");
  const currency = product.get("currency") || "YER";
  const imageLink = product.get("imageLink") || "";
  const link = product.get("link") || `https://smartcontentcreator2.web.app/app/product/${product.get("productId") || product.id}`;

  const messageText = `🛍️ *${title}*\n💰 السعر: *${price} ${currency}*\n🔗 رابط المنتج: ${link}`;

  return {
    success: true,
    destinationPhone,
    messageText,
    imageLink,
    sentAt: new Date().toISOString(),
  };
});

module.exports = {
  bootstrapCatalogSchemas,
  computeMediaDedupeKey,
  normalizeProductLink,
  verifyFirebaseIdToken,
  DEFAULT_WHATSAPP_CONFIG,
  sanitizeWaFileName,
  extractWaCategoryAndTags,
};


