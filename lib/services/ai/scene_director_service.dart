import 'dart:io';
import 'package:get/get.dart';
import '../../services/gemini_service.dart';
import '../../services/ai_provider.dart';

/// 🎬 Scene Director Service
/// يربط بين تحليل Gemini (لفهم المنتج) وتوليد الصور (Imagen/Stability)
/// لضمان بقاء المنتج حقيقياً مع تغيير الخلفية والبيئة المحيطة.
class SceneDirectorService extends GetxService {
  final GeminiService _gemini = Get.find<GeminiService>();

  /// 🧠 العقل: تحليل الصورة واقتراح برومبت إنجليزي دقيق
  Future<String> createProfessionalPrompt(File productImage) async {
    final bytes = await productImage.readAsBytes();

    // 1. نطلب من Gemini تحليل المنتج واقتراح سيناريو إخراجي
    const analysisPrompt = """
    Analyze this product image precisely to create a background generation prompt.
    
    TASK: Write a HIGHLY DETAILED "Image Prompt" in ENGLISH for Stable Diffusion.
    
    CRITICAL RULES:
    1. OUTPUT MUST BE 100% ENGLISH. NO ARABIC.
    2. Describe ONLY the background, lighting, and atmosphere.
    3. Do NOT describe the product itself in detail (it will be preserved via masking).
    4. Style: "8k, photorealistic, commercial photography, cinematic lighting, depth of field".
    5. Format: Raw text only. No "Here is the prompt" or markdown.
    """;

    // نستخدم الـ AIProviderFactory للحصول على المفتاح المناسب
    final config = await AIProviderFactory.getSmartProvider(isVideo: false);
    final apiKey = config.$2; // المفتاح

    // نرسل الطلب لـ Gemini
    final response =
        await _gemini.analyzeImage(bytes, analysisPrompt, apiKey: apiKey);

    // تنظيف النتيجة لاستخراج البرومبت الإنجليزي فقط
    return _extractEnglishPrompt(response.description);
  }

  /// 🧹 تنظيف النص لضمان بقاء البرومبت فقط
  String _extractEnglishPrompt(String response) {
    // 1. استراتيجية "القائمة البيضاء": السماح فقط بالإنجليزية والأرقام والرموز الأساسية
    // أي شيء آخر (عربي، رموز غريبة، إيموجي) سيتم حذفه
    String clean = response.replaceAll(RegExp(r"[^a-zA-Z0-9\s.,!?:;'-]"), ' ');

    // 2. تنظيف المسافات المزدوجة الناتجة عن الحذف
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 3. إذا كان هناك مقدمات مثل "Here is the prompt:", نحذفها
    if (clean.toLowerCase().contains("prompt:")) {
      clean = clean.split(":").last.trim();
    }

    // 4. التأكد من أن النص ليس فارغاً
    if (clean.isEmpty || clean.length < 5) {
      return "luxury commercial background, cinematic lighting, 8k resolution, photorealistic, blurred background";
    }

    return clean;
  }
}
