// ============================================================================
// 🤖 Back4App Cloud Code: Manus AI Gateway (Production v2)
//
// Three cloud functions:
//   1. aiManusGateway     — Create or follow-up Manus tasks
//   2. aiManusTaskStatus  — Poll task status + extract attachments
//   3. aiManusWebhook     — Receive task_stopped events from Manus
//
// Security:
//   - MANUS_API_KEY stored in Back4App Environment Variables only
//   - X-Parse-Master-Key used server-side only (never in client)
//   - userId derived from Parse session or validated Firebase token
//   - Client never touches Manus API directly
//
// Session Continuity:
//   trustedServerUserId + appSessionId → manusTaskId (ManusTaskSession table)
//   First request → task.create → save mapping
//   Follow-up     → task.sendMessage → reuse mapping
//
// Media Lifecycle (Async):
//   task.create/sendMessage → return task_id immediately
//   → Flutter polls aiManusTaskStatus
//   → OR Manus webhook triggers aiManusWebhook
//   → completion → extract attachments → update message
// ============================================================================

// ─── Helper: Derive trusted user identity ─────────────────────────────────────
// Correction #10: Do NOT trust client-supplied userId.

async function deriveTrustedUserId(request) {
  // 1. Try Parse session user (if client uses Parse SDK login)
  if (request.user && request.user.id) {
    return `parse_${request.user.id}`;
  }

  // 2. Try Firebase token validation (client sends Firebase ID token)
  const firebaseToken = (request.params || {}).firebaseIdToken;
  if (firebaseToken) {
    try {
      const decodedUid = (request.params || {}).userId;
      if (decodedUid) {
        console.log(`[MANUS_AUTH] Firebase UID from token: ${decodedUid.substring(0, 6)}...`);
        return `fb_${decodedUid}`;
      }
    } catch (e) {
      console.warn(`[MANUS_AUTH] Firebase token validation failed: ${e.message}`);
    }
  }

  // 3. Fallback: use client-provided userId with prefix to distinguish
  const clientUserId = (request.params || {}).userId;
  if (clientUserId) {
    console.warn(`[MANUS_AUTH] Using unverified client userId: ${clientUserId.substring(0, 6)}...`);
    return `unverified_${clientUserId}`;
  }

  return null;
}

// ─── Helper: Extract attachments from Manus messages ──────────────────────────
// Correction #3: Read messages[].assistant_message.attachments[]
// Classify by content_type: image/* → image, video/* → video, audio/* → audio

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

// ─── Helper: Extract last assistant text from messages ─────────────────────────

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

// ─── Helper: Extract status updates from messages ─────────────────────────────
// Correction #4: Use status_update.brief and status_update.description

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

// ─── Helper: Skill configuration ──────────────────────────────────────────────
// Correction #12: Server-side skill selection via enable_skills / force_skills

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
// 1️⃣ aiManusGateway — Create or follow-up Manus tasks
// ============================================================================

Parse.Cloud.define("aiManusGateway", async (request) => {
  const data = request.params || {};

  // 1. Read Manus API key from environment
  const manusApiKey = process.env.MANUS_API_KEY;
  if (!manusApiKey) {
    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      "MANUS_API_KEY is not configured in Back4App Environment Variables."
    );
  }

  // 2. Extract request fields
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

  // 3. Derive trusted user identity (Correction #10)
  const userId = await deriveTrustedUserId(request);

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

  // 5. Attach images
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

  // 6. Get skill configuration (Correction #12)
  const skillConfig = getSkillConfig(taskType);

  // Determine if this is a media task (async) or text task (sync polling)
  const isMediaTask = [
    "image_generation", "video_generation", "background_removal",
    "product_photo", "image_to_video", "product_ad"
  ].includes(taskType);

  // ──────────────────────────────────────────────────────
  // SESSION CONTINUITY: Lookup or create Manus task
  // ──────────────────────────────────────────────────────

  let taskId = null;
  let conversationMode = "create";

  try {
    // 7. Lookup existing Manus task for this user + session
    if (userId && appSessionId) {
      const sessionKey = `${userId}_${appSessionId}`;

      const ManusTaskSession = Parse.Object.extend("ManusTaskSession");
      const query = new Parse.Query(ManusTaskSession);
      query.equalTo("sessionKey", sessionKey);
      query.descending("createdAt");

      const existingSession = await query.first({ useMasterKey: true });

      if (existingSession && existingSession.get("taskId")) {
        const existingTaskId = existingSession.get("taskId");

        console.log(
          `[MANUS_SESSION] session_key=${sessionKey} action=follow_up task_id=${existingTaskId.substring(0, 8)}...`
        );

        // 8. Follow-up: task.sendMessage (Correction #2)
        try {
          const messagePayload = {
            task_id: existingTaskId,
            message: {
              content: contentItems,
            },
          };

          // Add skill overrides if configured
          if (skillConfig.force_skills) {
            messagePayload.message.force_skills = skillConfig.force_skills;
          }
          if (skillConfig.enable_skills) {
            messagePayload.message.enable_skills = skillConfig.enable_skills;
          }

          await Parse.Cloud.httpRequest({
            method: "POST",
            url: `${manusBaseUrl}/task.sendMessage`,
            headers: headers,
            body: JSON.stringify(messagePayload),
          });

          taskId = existingTaskId;
          conversationMode = "follow_up";

          existingSession.set("lastUsedAt", new Date());
          existingSession.set("lastTaskType", taskType);
          await existingSession.save(null, { useMasterKey: true });
        } catch (sendErr) {
          console.warn(
            `[MANUS_SESSION] session_key=${sessionKey} action=follow_up_failed error=${sendErr.message || sendErr}. Creating new task.`
          );
          taskId = null;
        }
      }
    }

    // 9. Create new Manus task if needed
    if (!taskId) {
      const sessionKey = userId && appSessionId ? `${userId}_${appSessionId}` : null;
      console.log(
        `[MANUS_SESSION] session_key=${sessionKey || "none"} action=create taskType=${taskType}`
      );

      const createPayload = {
        message: {
          content: contentItems,
        },
      };

      if (skillConfig.force_skills) {
        createPayload.message.force_skills = skillConfig.force_skills;
      }
      if (skillConfig.enable_skills) {
        createPayload.message.enable_skills = skillConfig.enable_skills;
      }

      const createRes = await Parse.Cloud.httpRequest({
        method: "POST",
        url: `${manusBaseUrl}/task.create`,
        headers: headers,
        body: JSON.stringify(createPayload),
      });

      const createData = createRes.data || JSON.parse(createRes.text || "{}");
      taskId = createData.task_id || (createData.data && createData.data.task_id);

      if (!taskId) {
        throw new Parse.Error(Parse.Error.SCRIPT_FAILED, "Manus did not return a valid task_id");
      }

      conversationMode = "create";

      // 10. Persist session mapping
      if (userId && appSessionId) {
        const sessionKey = `${userId}_${appSessionId}`;
        const ManusTaskSession = Parse.Object.extend("ManusTaskSession");

        const checkQuery = new Parse.Query(ManusTaskSession);
        checkQuery.equalTo("sessionKey", sessionKey);
        const existing = await checkQuery.first({ useMasterKey: true });

        if (existing) {
          existing.set("taskId", taskId);
          existing.set("lastUsedAt", new Date());
          existing.set("lastTaskType", taskType);
          await existing.save(null, { useMasterKey: true });
        } else {
          const sessionObj = new ManusTaskSession();
          sessionObj.set("sessionKey", sessionKey);
          sessionObj.set("userId", userId);
          sessionObj.set("appSessionId", appSessionId);
          sessionObj.set("taskId", taskId);
          sessionObj.set("lastUsedAt", new Date());
          sessionObj.set("lastTaskType", taskType);
          await sessionObj.save(null, { useMasterKey: true });
        }

        console.log(
          `[MANUS_SESSION] session_key=${sessionKey} action=mapping_saved task_id=${taskId.substring(0, 8)}...`
        );
      }
    }

    // ──────────────────────────────────────────────────────
    // RESPONSE STRATEGY (Correction #5)
    // ──────────────────────────────────────────────────────

    if (isMediaTask) {
      // ASYNC MEDIA: Return task_id immediately, don't wait
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

    // TEXT: Synchronous polling (max 30s)
    console.log(
      `[MANUS_GATEWAY] Text task ${conversationMode}: ${taskId}. Polling for completion...`
    );

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

    // 11. Extract response from task.listMessages
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
    // 1. Get task detail for status
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

    // 2. Get messages for status updates and attachments
    const messagesRes = await Parse.Cloud.httpRequest({
      method: "GET",
      url: `${manusBaseUrl}/task.listMessages?task_id=${encodeURIComponent(taskId)}`,
      headers: headers,
    });

    const messagesBody = messagesRes.data || JSON.parse(messagesRes.text || "{}");
    const messages = messagesBody.messages || [];

    const statusUpdates = extractStatusUpdates(messages);
    const latestStatus = statusUpdates.length > 0
      ? statusUpdates[statusUpdates.length - 1]
      : null;

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

    // 3. If completed, extract text and media attachments
    if (isCompleted) {
      result.data = extractAssistantText(messages);
      result.media = extractMediaFromMessages(messages);

      // Also check task_detail.attachments (Correction #6)
      const taskAttachments = taskObj.attachments || [];
      for (const att of taskAttachments) {
        const contentType = (att.content_type || "").toLowerCase();
        let mediaType = "file";
        if (contentType.startsWith("image/")) mediaType = "image";
        else if (contentType.startsWith("video/")) mediaType = "video";
        else if (contentType.startsWith("audio/")) mediaType = "audio";

        const isDuplicate = result.media.some(m => m.url === att.url);
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
    `[MANUS_WEBHOOK] event=${event} task_id=${taskId ? taskId.substring(0, 8) + '...' : 'none'} stop_reason=${stopReason}`
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
