// lib/ai/core/ai_constants.dart

/// 🎭 System Persona & Rules for AI Content Generation
///
/// يجمع كل الثوابت المشتركة بين مكونات الذكاء الاصطناعي في مكان واحد.
/// هذا يمنع التكرار ويضمن التناسق عبر كل الوكلاء والخدمات.
class AIConstants {
  AIConstants._(); // Private constructor — لا يمكن إنشاء instance

  // =========================================
  // 🎯 System Persona (شخصية النظام)
  // LEGACY_MIGRATION_SOURCE: Matches Firebase Prompt Template 'system_persona_default'
  // =========================================

  static const systemPersona = """
أنت خبير في صناعة المحتوى والتسويق الرقمي. هدفك هو تقديم محتوى "جاهز للنشر" وبجودة احترافية.

قواعد عامة:
1. **ممنوع الدردشة الجانبية**: ابدأ بالمحتوى المطلوب مباشرة.
2. **سياق الردود**: التزم بدقة بنوع الرد المكتشف.
3. **🚫 ممنوع المقدمات والتعريف بالنفس**: لا تذكر اسمك ("صانع المحتوى الذكي")، لا تذكر اسم التطبيق، ولا تضف عبارات مثل "إليك الوصف" أو "يقدم لك". ابدأ بالنص الإعلاني أو المحتوى فوراً.
""";

  // =========================================
  // ✏️ Modification Rules (قواعد التعديل)
  // LEGACY_MIGRATION_SOURCE: Matches Firebase Prompt Template 'modification_rules_default'
  // =========================================

  static const modificationRules = """
MODIFICATION MODE RULES (Highest Priority):
- Output ONLY the final content.
- No introductions. No explanations. No commentary. No meta-text. No apologies.
- Do not reference the original message.
- Do not mention that this is a modification (Do NOT say "Modified content:", "Here is the new version:").
- Preserve meaning unless explicitly instructed otherwise.
""";

  // =========================================
  // 🎨 Image Generation Keywords (كلمات صور)
  // =========================================

  static const imageGenKeywords = [
    'صمم',
    'تصميم',
    'ارسم',
    'رسم',
    'أنشئ صورة',
    'انشئ صورة',
    'أنشا صورة',
    'انشا صورة',
    'انشاء صورة',
    'إنشاء صورة',
    'اصنع صورة',
    'صنع صورة',
    'اعمل صورة',
    'عمل صورة',
    'سوي صورة',
    'سو صورة',
    'صمم لي',
    'ارسم لي',
    'صور لي',
    'انشئ لي',
    'انشا لي',
    'اعمل لي',
    'اصنع لي',
    'سوي لي',
    'سو لي',
    'generate image',
    'create image',
    'design',
    'draw',
    'تخيل صورة',
    'visualize',
    'ولد صورة',
    'توليد صورة',
    'كون صورة',
    'تكوين صورة',
    'make image',
    'اريد صورة',
    'أريد صورة',
    'ابغى صورة',
    'ابي صورة',
    'صورة احترافية',
    'صوره احترافيه',
    'صورة للمنتج',
    'صوره للمنتج',
    'صور للمنتج',
  ];

  // =========================================
  // 🎬 Video Generation Keywords (كلمات فيديو)
  // =========================================

  static const videoGenKeywords = [
    'اصنع فيديو',
    'صنع فيديو',
    'اعمل فيديو',
    'عمل فيديو',
    'ولد فيديو',
    'توليد فيديو',
    'صمم فيديو',
    'تصميم فيديو',
    'كون فيديو',
    'تكوين فيديو',
    'انشئ فيديو',
    'أنشئ فيديو',
    'انشا فيديو',
    'أنشا فيديو',
    'انشاء فيديو',
    'إنشاء فيديو',
    'سوي فيديو',
    'سو فيديو',
    'ابغى فيديو',
    'اريد فيديو',
    'أريد فيديو',
    'ابي فيديو',
    'فيديو للمنتج',
    'فديو للمنتج',
    'مقطع للمنتج',
    'تحريك الصورة',
    'حرك الصورة',
    'animate image',
    'generate video',
    'create video',
    'make video',
  ];

  // =========================================
  // 🛡️ Generic Brand Filters (أسماء عامة)
  // =========================================

  static const genericBrandNames = [
    'n/a',
    'unknown',
    'none',
    'null',
    'undefined',
    'غير معروف',
    'لا يوجد',
    'غير واضح',
    'غير محدد',
    'product',
    'item',
    'منتج',
  ];

  // =========================================
  // 🧹 Arabic Noise Words (كلمات مهملة)
  // =========================================

  static const arabicNoiseWords = [
    'اريد',
    'أريد',
    'ابي',
    'ابغى',
    'روابط',
    'تيك توك',
    'فيديو',
    'بحث',
    'عن',
    'للمنتج',
    'التالي',
    'هذا',
    'المنتج',
    'وصف',
    'هاشتاقات',
    'اعلان',
    'إعلان',
    'تسويق',
    'كتابة',
    'اكتب',
  ];

  /// 🧹 RegExp pattern for noise word removal
  static final arabicNoisePattern = RegExp(arabicNoiseWords.join('|'));

  // =========================================
  // 🎨 Image Style Keywords
  // =========================================

  static const imageStyleKeywords = ['أنمي', 'واقعية', 'سينمائية', 'تراث'];

  // =========================================
  // ⏱️ Timing Constants
  // =========================================

  static const Duration smoothTransitionDelay = Duration(milliseconds: 400);
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration autoActionDelay = Duration(seconds: 1);
  static const Duration trendFetchDelay = Duration(milliseconds: 500);

  // =========================================
  // 📏 Size Limits
  // =========================================

  static const int maxProductNameLength = 50;
  static const int minProductNameLength = 2;
  static const int maxTikTokTitleLength = 120;
  static const int maxQueryLength = 50;
}
