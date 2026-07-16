const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * 🛡️ Helper: التحقق من هوية المستخدم بشكل آمن عبر Firebase Auth
 */
async function verifyUser(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error("Missing or invalid Authorization header");
  }
  const idToken = authHeader.split('Bearer ')[1];
  const decodedToken = await admin.auth().verifyIdToken(idToken);
  return decodedToken.uid;
}

/**
 * 🔑 Helper: نظام الـ Failover للمفاتيح
 * يحاول تنفيذ الطلب عبر قائمة مفاتيح مرتبة
 */
async function callAiWithFailover(prompt, keys) {
  const keyList = [
    keys.gemini_primary,
    keys.gemini_secondary,
    process.env.GEMINI_BACKUP // مفتاح الطوارئ الأخير
  ].filter(k => !!k);

  let lastError;

  for (const key of keyList) {
    try {
      console.log(`📡 Attempting request with key suffix: ...${key.slice(-4)}`);
      // هنا سنضع كود استدعاء Gemini الفعلي لاحقاً
      // return await performGeminiCall(prompt, key);
      
      // محاكاة نجاح مؤقتة للمرحلة الحالية
      return { success: true, text: `AI Response for: ${prompt}`, usedKey: `...${key.slice(-4)}` };
    } catch (error) {
      console.warn(`⚠️ Key failed, trying next... Error: ${error.message}`);
      lastError = error;
      continue; // انتقال للمفتاح التالي
    }
  }

  throw new Error(`All keys failed. Last error: ${lastError.message}`);
}

/**
 * 🚀 Main SaaS Endpoint
 */
exports.smartAI = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');

  if (req.method === 'OPTIONS') return res.status(204).send('');

  try {
    // 1️⃣ Auth Guard (Secure)
    const uid = await verifyUser(req);

    // 2️⃣ SaaS Guard (Firestore)
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return res.status(403).json({ error: "User record missing" });
    
    const userData = userDoc.data();
    // التحقق من الصلاحيات (مثلاً: رصيد الصور أو مدة الاشتراك)
    if (!userData.isPremium && (userData.visualAnalysisCount >= 15)) {
      return res.status(402).json({ error: "Limit reached. Please upgrade to premium." });
    }

    // 3️⃣ Get Global Keys
    const aiConfig = await admin.firestore().collection("app_settings").doc("ai_config").get();
    const keys = aiConfig.exists ? aiConfig.data().managed_keys : {};

    // 4️⃣ Execute AI with Failover logic
    const { prompt } = req.body;
    const aiResult = await callAiWithFailover(prompt, keys);

    // 5️⃣ Logging usage (SaaS Analytics)
    await admin.firestore().collection("usage_logs").add({
      uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      promptLength: prompt.length,
      success: true
    });

    return res.json(aiResult);

  } catch (error) {
    console.error("❌ SaaS API Error:", error);
    return res.status(error.message.includes("Auth") ? 401 : 500).json({
      success: false,
      error: error.message
    });
  }
});
