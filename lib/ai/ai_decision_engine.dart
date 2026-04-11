import 'dart:io';
import 'package:get/get.dart';
import 'core/agent_models.dart';
import 'models/app_context.dart';
import '../services/ai/intent_classifier_service.dart';

/// 🎯 AI Decision Engine - محرك القرار الذكي
///
/// هذه الطبقة تحلل نية المستخدم وتحدد "المهمة" (AiTask)
/// المسؤولة عن توجيه النظام دون الدخول في تفاصيل بناء النص.
class AiDecisionEngine {
  /// 🔍 كشف نية المستخدم من المحتوى (Hybrid AI)
  static Intent detect(String content,
      {bool hasImage = false, bool hasVideo = false, List<File>? images, AppContext? context}) {
    // 🧠 Use the enhanced IntentClassifierService
    final classifier = Get.put(IntentClassifierService()); // Ensure singleton

    // Construct simplified objects for the classifier
    final msg = IncomingMessage(
      text: content,
      image: hasImage ? File('') : null, // Dummy file
      images: images,
      video: hasVideo ? File('') : null, // Dummy file
    );

    // 🆕 Auto-detect 3D Reconstruction if 3+ images provided
    if (images != null && images.length >= 3) {
      return Intent.reconstruction3D;
    }

    // Pass AppContext to classifier for context-aware decision
    return classifier.classifyIntent(msg, null, null, context: context);
  }

  /// 🧠 كشف الأوامر الضمنية المتعلقة بالمنتج
  /// يتحقق إذا كان الأمر يشير ضمنياً إلى منتج (مثل: "اعمل له فيديو"، "اعمل حملة تسويقية")
  static bool detectImplicitProductCommand(String content) {
    final lowerContent = content.toLowerCase().trim();

    // 🆕 كشف الأوامر المفردة (standalone commands) مثل "عدله" / "غيره"
    final standaloneCommands = [
      'عدله',
      'غيره',
      'طوره',
      'حسنه',
      'كمله',
      'اختصره',
      'وسعه',
      'اعد صياغته',
      'نسقه',
      'زبطه',
      'نظفه',
      'ترجمه',
      'صلحه',
    ];
    if (standaloneCommands
        .any((k) => lowerContent == k || lowerContent.startsWith('$k '))) {
      return true;
    }

    // كلمات تشير إلى أوامر ضمنية
    final implicitKeywords = [
      'له', 'لها', 'عنه', 'عنها', // ضمائر
      'هذا', 'هذه', 'ذلك', 'تلك', // إشارات
      'المنتج', 'المنتج ده', 'المنتج دا', // إشارة مباشرة
      'عدله', 'غيره', 'طوره', 'حسنه', 'كمله', // 🆕 أوامر ضمنية
      'نفس', 'نفسه', 'زيه', 'كذا', 'اللي قلتلك', // 🆕 إشارات سياقية
      'اللي فات', 'السابق', 'الاخير', 'اللي قبل', // 🆕 إشارات زمنية
    ];

    // أوامر تحتاج سياق منتج
    final actionKeywords = [
      'اعمل', 'اصنع', 'صمم', 'اكتب', 'ابحث',
      'فيديو', 'حملة', 'وصف', 'ترند', 'تسويق',
      'عدل', 'غير', 'طور', 'حسن', 'كمل', // 🆕 أفعال التعديل
      'انشر', 'حمل', 'صور', 'ارسل', 'جهز', // 🆕 أفعال إضافية
    ];

    final hasImplicitRef =
        implicitKeywords.any((k) => lowerContent.contains(k));
    final hasAction = actionKeywords.any((k) => lowerContent.contains(k));

    return hasImplicitRef && hasAction;
  }

  /// 🚀 تحويل القرار إلى مهمة (AiTask)
  static AiTask createTask(
    String content, {
    String? productName,
    bool hasImage = false,
    bool hasVideo = false, // 📹 Video Flag
    File? mediaFile, // 📹 Media File
    List<File>? images, // 📸 Multiple images
    String? aiMode,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    AppContext? context, // 🌐 App Context
    Intent? overrideIntent, // 🧠 Override from Orchestrator
  }) {
    final intent = overrideIntent ??
        detect(content,
            hasImage: hasImage, hasVideo: hasVideo, images: images, context: context);

    // 🧠 الجديد: اكتشاف نمط الرد (Reply Mode Detection)
    final replyResult = detectReplyMode(content, replyToContent != null);

    // 🧠 تفعيل الذكاء المحيط (Context Awareness)
    // إذا كان المود غير محدد والنية هي تيك توك، نستخدم بيانات المنتج من السياق
    String? finalProduct = productName;
    if ((finalProduct == null || finalProduct.isEmpty) && context != null) {
      if (detectImplicitProductCommand(content)) {
        finalProduct = context.productName;
      }
    }

    // 🎯 Tool Awareness: ربط النية بالأداة المناسبة
    String? suggestedTool;
    switch (intent) {
      case Intent.trendRequest:
      case Intent.searchTrends:
        suggestedTool = 'search_tiktok';
        break;
      case Intent.youtubeRequest:
        suggestedTool = 'youtube_search';
        break;
      case Intent.googleTrendsRequest:
        suggestedTool = 'google_trends';
        break;
      case Intent.videoGeneration:
        suggestedTool = 'generate_video';
        break;
      case Intent.imageGeneration:
        suggestedTool = 'generate_image';
        break;
      case Intent.instagramSearch:
        suggestedTool = 'instagram_trends';
        break;
      case Intent.alibabaSource:
        suggestedTool = 'alibaba_sourcing';
        break;
      case Intent.analysis:
      case Intent.productDetected:
        suggestedTool = 'analyze_product';
        break;
      case Intent.googleSearch:
        suggestedTool = 'google_search';
        break;
      case Intent.visualExpansion:
        suggestedTool = 'visual_expansion';
        break;
      case Intent.reconstruction3D:
        suggestedTool = 'recalculate_3d'; // 🏺
        break;
      case Intent.amazonRequest:
        suggestedTool = 'amazon_search';
        break;
      case Intent.shoppingRequest:
        suggestedTool = 'google_shopping';
        break;
      default:
        suggestedTool = null;
    }

    return AiTask(
      intent: intent,
      productName: finalProduct,
      userText: content,
      requiresVision: hasImage || (images != null && images.isNotEmpty),
      isVideo: hasVideo, // 📹 Video Flag
      mediaFile: mediaFile, // 📹 Media File
      images: images, // 📸
      aiMode: aiMode,
      suggestedTool: suggestedTool, // 🎯
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToRole: replyToRole,
      replyMode: replyResult.mode,
      styleSummary:
          generateStyleSummary(content, replyResult.mode), // جملة وصفية واحدة
    );
  }

  /// 🧠 محرك كشف نمط الرد (Weighted Heuristics)
  static ReplyModeResult detectReplyMode(String content, bool hasReply) {
    if (!hasReply) {
      return const ReplyModeResult(mode: ReplyMode.discussion, confidence: 1.0);
    }

    final lowerContent = content.toLowerCase();
    double confidence = 0.0;

    // 1. إشارة التحويل (Transform Keywords) - وزن 0.5
    final transformKeywords = [
      'سكريبت',
      'إعلان',
      'بريد',
      'قصة',
      'خطة',
      'جدول',
      'سيناريو',
      'فيديو',
      'نشر',
      'جاهز',
      'تنسيق',
      'بوست',
      'تغريدة'
    ];
    bool isTransform = transformKeywords.any((k) => lowerContent.contains(k));

    // 2. إشارة التوجيه (Directive Verbs) - وزن 0.3
    final directiveVerbs = [
      'اجعل',
      'عدل',
      'غير',
      'اختصر',
      'أضف',
      'وسع',
      'أعد',
      'صلح',
      'ترجم',
      'حول',
      'نسق',
      'زبط',
      'نظف'
    ];
    bool hasDirective = directiveVerbs.any((k) => lowerContent.contains(k));

    // 3. إشارة الطول (Short Content) - وزن 0.2
    bool isShort = content.split(' ').length <= 15;

    // حساب الثقة (Confidence Calculation)
    if (isTransform) confidence += 0.5;
    if (hasDirective) confidence += 0.3;
    if (isShort) confidence += 0.2;

    // تحديد النمط (Mode Determination)
    if (confidence < 0.6) {
      return ReplyModeResult(
          mode: ReplyMode.discussion, confidence: confidence);
    }

    if (isTransform) {
      return ReplyModeResult(mode: ReplyMode.transform, confidence: confidence);
    }

    return ReplyModeResult(
        mode: ReplyMode.modification, confidence: confidence);
  }

  /// 🎨 توليد وصف مختصر جداً للأسلوب
  static String? generateStyleSummary(String content, ReplyMode mode) {
    if (mode == ReplyMode.discussion) return null;

    // منطق مبسط لتوليد جملة واحدة
    if (content.contains('أقصر') || content.contains('اختصر')) {
      return "Concise marketing style, no fluff.";
    }
    if (content.contains('أطول') || content.contains('وسع')) {
      return "Detailed informative style, benefits focused.";
    }
    if (content.contains('إيموجي')) {
      return "Engaging style with expressive emojis.";
    }
    if (content.contains('رسمي')) {
      return "Professional formal tone.";
    }

    return "Professional persuasive marketing tone.";
  }
}
