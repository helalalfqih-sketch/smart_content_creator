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

    return claims.sub;
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
      return `fb_${verifiedUid}`;
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
