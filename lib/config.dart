// lib/config.dart
class Config {
  // 🧠 اسم نموذج تحليل الصور (Image Classification or Captioning)
  static const String huggingFaceImageModel = "google/vit-base-patch32";

  // ✍️ اسم نموذج توليد النصوص التسويقية
  static const String huggingFaceTextModel = "google/flan-t5-small";

  // 🔑 API Keys (Optional: Hardcode here for testing if you don't want to use Settings UI)
  static const String geminiApiKey = ""; // ⚠️ ضع مفتاح API هنا للاختبار السريع

  // 🌐 الموقع الرسمي وسيرفر التحديثات
  // Note: Update this to your custom domain once DNS is configured
  static const String baseUrl = "https://smartcontentcreator2.web.app";
}
