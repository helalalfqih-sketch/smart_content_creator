// lib/ai/core/ai_helpers_mixin.dart

import 'ai_constants.dart';
import '../../utils/logger.dart';

/// 🧠 Shared helper methods for AI agents
///
/// يوفر أدوات معالجة النصوص، تحليل المنتجات، وتنسيق المخرجات
/// لضمان سلوك موحد عبر جميع مكونات الوكيل الذكي.
mixin AIHelpersMixin {
  /// 📝 Extract product name from user text
  String? extractProductNameFromText(String text) {
    AppLogger.info('ENTERING: extractProductNameFromText with text: $text');
    if (text.isEmpty) {
      AppLogger.info('EXITING: extractProductNameFromText result: null');
      return null;
    }

    // 1. محاولة التقسيم بالسطر الجديد (غالباً ما يكون الاسم في السطر الأخير)
    if (text.contains('\n')) {
      final candidate = text.split('\n').last.trim();
      if (_isValidProductName(candidate)) return candidate;
    }

    // 2. محاولة التقسيم بالنقطتين الرأسيتين
    if (text.contains(':')) {
      final candidate = text.split(':').last.trim();
      if (_isValidProductName(candidate)) return candidate;
    }

    // 3. تنظيف النصوص من الكلمات الشائعة (Noise Words)
    final cleanText =
        text.replaceAll(AIConstants.arabicNoisePattern, '').trim();

    if (cleanText.isEmpty) return null;
    if (_isValidProductName(cleanText)) {
      AppLogger.info('EXITING: extractProductNameFromText result: $cleanText');
      return cleanText;
    }

    AppLogger.info('EXITING: extractProductNameFromText result: $text');
    return text;
  }

  bool _isValidProductName(String text) =>
      text.length >= AIConstants.minProductNameLength &&
      text.length <= AIConstants.maxProductNameLength;

  /// 🛡️ Filter generic placeholders (تحقق من الأسماء الوهمية)
  bool isGenericBrand(String? s) {
    AppLogger.info('ENTERING: isGenericBrand with s: $s');
    if (s == null || s.trim().isEmpty) {
      AppLogger.info('EXITING: isGenericBrand result: true');
      return true;
    }
    final lower = s.toLowerCase();
    final result = AIConstants.genericBrandNames.any((p) => lower.contains(p));
    AppLogger.info('EXITING: isGenericBrand result: $result');
    return result;
  }

  /// 🧹 Clean TikTok title (تنظيف عناوين تيك توك من الهاشتاقات الزائدة)
  String cleanTikTokTitle(String title) {
    if (title.isEmpty) return "";

    // إزالة الهاشتاقات
    String clean = title.replaceAll(RegExp(r'#\S+'), '').trim();

    // إذا أصبح النص فارغاً، نأخذ أول 10 كلمات
    if (clean.isEmpty) {
      final words = title.split(' ');
      clean = words.take(10).join(' ');
      if (words.length > 10) clean += "...";
    }

    // قص النص الطويل
    if (clean.length > AIConstants.maxTikTokTitleLength) {
      clean = "${clean.substring(0, AIConstants.maxTikTokTitleLength - 3)}...";
    }

    AppLogger.info('EXITING: cleanTikTokTitle result: $clean');
    return clean;
  }

  /// 📊 Format views (تنسيق أرقام المشاهدات: 2.5K, 1.2M)
  String formatViews(int views) {
    AppLogger.info('ENTERING: formatViews with views: $views');
    String result;
    if (views >= 1000000) {
      result = "${(views / 1000000).toStringAsFixed(1)}M";
    } else if (views >= 1000) {
      result = "${(views / 1000).toStringAsFixed(1)}K";
    } else {
      result = views.toString();
    }
    AppLogger.info('EXITING: formatViews result: $result');
    return result;
  }

  /// 🎬 Check if image generation request (التحقق من نية توليد صور)
  bool isImageGenerationRequest(String prompt) {
    if (prompt.isEmpty) return false;
    final lower = prompt.toLowerCase().trim()
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي');

    // 🛡️ فحص النفي (Negation Check) - إذا كانت الجملة تحتوي على كلمات نفي، نتوقف فوراً
    final negationKeywords = [
      'لا', 'لم', 'ما', 'ليس', 'بدون', 'إيقاف', 'توقف', 'بلاش',
      'not', 'no', 'stop', 'don\'t', 'without', 'never', 'quit'
    ];
    if (negationKeywords.any((k) => lower.contains(k))) {
      return false;
    }

    // تحقق من الستايلات (واقعية، أنمي...)
    final hasStyle =
        AIConstants.imageStyleKeywords.any((s) => lower.contains(s));

    // تحقق من الكلمات المفتاحية
    final hasKeyword = AIConstants.imageGenKeywords
        .any((k) => lower.contains(k.toLowerCase().replaceAll('ة', 'ه').replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ى', 'ي')));

    // تحقق من النمط المرن (فعل إنشاء + اسم صورة)
    final hasImageNoun = lower.contains('صوره') || lower.contains('صورة') || lower.contains('صور') || lower.contains('image');
    final hasActionVerb = ['انش', 'اصنع', 'صنع', 'اعمل', 'عمل', 'ولد', 'توليد', 'صمم', 'تصميم', 'ارسم', 'سوي', 'سو', 'اريد', 'ابغي', 'ابغى', 'ابي', 'اعطني', 'تخيل', 'create', 'generate', 'draw', 'design', 'make'].any((v) => lower.contains(v));

    final result = hasKeyword || hasStyle || (hasImageNoun && hasActionVerb);
    AppLogger.info('EXITING: isImageGenerationRequest result: $result');
    return result;
  }
}
