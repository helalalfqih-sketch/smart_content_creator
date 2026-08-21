// ============================================================================
// 🤖 Back4App Cloud Code: aiManusGateway
// ضع هذا الكود داخل Cloud Code في لوحة تحكم Back4App (ملف main.js)
// ============================================================================

Parse.Cloud.define("aiManusGateway", async (request) => {
  const data = request.params || {};

  // 1. 🗝️ قراءة مفتاح Manus من متغيرات البيئة في Back4App
  const manusApiKey = process.env.MANUS_API_KEY;
  if (!manusApiKey) {
    throw new Parse.Error(
      Parse.Error.SCRIPT_FAILED,
      "MANUS_API_KEY is not configured in Back4App Environment Variables."
    );
  }

  // 2. 📦 استخراج الحقول القياسية (Canonical AI Request)
  const prompt = data.prompt || "";
  const systemPersona = data.systemPersona || "";
  const history = data.history || [];
  const images = data.images || (data.image ? [data.image] : []);
  const mimeType = data.mimeType || "image/jpeg";
  const taskType = data.taskType || "general";

  if (!prompt && images.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, "Prompt or images are required");
  }

  // 3. 🎯 تجميع البرومبت القياسي دون أي تعديل أو تكرار
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

  const contentItems = [
    {
      type: "text",
      text: fullPrompt,
    },
  ];

  // 4. 🖼️ إرفاق كافة الصور (بدون إسقاط أي صورة)
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

  try {
    // 5. إنشاء المهمة في Manus API v2 (POST /v2/task.create)
    console.log(`[MANUS_GATEWAY] Creating task on Manus API v2 (taskType=${taskType}, imageCount=${images.length})`);
    const createRes = await Parse.Cloud.httpRequest({
      method: "POST",
      url: `${manusBaseUrl}/task.create`,
      headers: headers,
      body: JSON.stringify({
        message: {
          content: contentItems,
        },
      }),
    });

    const createData = createRes.data || JSON.parse(createRes.text || "{}");
    const taskId = createData.task_id || (createData.data && createData.data.task_id);
    const createRequestId = createData.request_id || null;

    if (!taskId) {
      throw new Parse.Error(Parse.Error.SCRIPT_FAILED, "Manus did not return a valid task_id");
    }

    console.log(`[MANUS_GATEWAY] Task created: ${taskId}. Polling for completion...`);

    // 6. فحص حالة المهمة حتى الاكتمال (Polling عبر task.detail)
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
        } else if (status === "failed" || status === "error") {
          const errorMsg = taskObj.error || taskObj.message || "Task failed on Manus";
          throw new Parse.Error(Parse.Error.SCRIPT_FAILED, `Manus task failed: ${JSON.stringify(errorMsg)}`);
        }
      } catch (pollErr) {
        console.warn(`[MANUS_GATEWAY] Polling warn:`, pollErr);
      }

      pollIntervalMs = Math.min(pollIntervalMs + 500, 2000);
    }

    if (!isTaskFinished) {
      throw new Parse.Error(Parse.Error.TIMEOUT, "Manus task timed out after 30s");
    }

    // 7. استخراج آخر رد للمساعد (task.listMessages)
    const messagesRes = await Parse.Cloud.httpRequest({
      method: "GET",
      url: `${manusBaseUrl}/task.listMessages?task_id=${encodeURIComponent(taskId)}`,
      headers: headers,
    });

    const messagesBody = messagesRes.data || JSON.parse(messagesRes.text || "{}");
    const listRequestId = messagesBody.request_id || null;
    const messages = messagesBody.messages || [];

    let finalOutputText = "";
    for (let i = messages.length - 1; i >= 0; i--) {
      const m = messages[i];
      if (m.type === "assistant_message" && m.assistant_message && m.assistant_message.content) {
        const content = m.assistant_message.content;
        finalOutputText = typeof content === "string" ? content : JSON.stringify(content);
        break;
      }
    }

    if (!finalOutputText || finalOutputText.trim().length === 0) {
      throw new Parse.Error(Parse.Error.SCRIPT_FAILED, "Manus task finished but returned an empty assistant output.");
    }

    return {
      success: true,
      data: finalOutputText,
      meta: {
        provider: "manus",
        model: "manus-v2",
        task_id: taskId,
        request_id: createRequestId || listRequestId,
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
