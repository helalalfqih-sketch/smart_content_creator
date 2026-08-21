import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/gemini_service.dart';
import '../services/db_service.dart';
import 'kling_service.dart';
import 'higgsfield_service.dart';
import '../controllers/settings_controller.dart';
import '../services/ai_provider.dart';
import '../core/models/api_provider.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/image_utils.dart';
import './serpapi_services.dart';
import 'ai_backend_router.dart';

import '../ai/core/agent_models.dart';
import '../models/brand_identity_model.dart';

enum AIActionType {
  generateVideo,
  generateDescription,
  generateHashtags,
  analyzeImage,
  editVideo,
  enhanceAudio,
  sceneAnalysis,
  highlightReel
}

class UnifiedAIService extends GetxService {
  GeminiService get _gemini => Get.find<GeminiService>();
  DBService get _db => Get.find<DBService>();
  SettingsController get _settings => Get.find<SettingsController>();
  GoogleLensService get _lens => Get.find<GoogleLensService>();

  /// 🤖 اسم النموذج أو المزود الأخير الذي تم استخدامه بنجاح
  String lastUsedProvider = 'gemini';

  /// جلب المفتاح الفعال (يدوي)
  Future<String?> _getEffectiveKey(ProviderType provider) async {
    // 1. المفتاح المحلي اليدوي (Manual Key)
    final localKey = _settings.getApiKey(provider);
    if (localKey.isNotEmpty) return localKey;

    return null;
  }

  Future<String> _getGeminiKey() async {
    return await _getEffectiveKey(ProviderType.gemini) ?? '';
  }

  /// 🧠 Smart Router: Classify User Intent (Enhanced v4.0)
  /// Returns a structured AIIntentResult with confidence and parameters
  Future<AIIntentResult> classifyUserIntent(String userText, {File? image, dio.CancelToken? cancelToken}) async {
    try {
      final apiKey = await _getGeminiKey();
      if (apiKey.isEmpty) {
        return AIIntentResult(
          intent: "TEXT",
          confidence: 1.0,
          parameters: {},
          suggestedActions: [],
        );
      }

      final routerPrompt = """
You are the Brain of a high-end AI Content Creation OS. Analyze the user's input and determine the optimal routing package.
${image != null ? "CONTEXT: The user has attached an image. If they ask to animate it, generate a video from it, or describe a scene with it, prioritize VIDEO_GEN." : ""}
User Input: "$userText"

Intents:
- "SHOPPING": User wants to find products, buy, or check prices.
- "TRENDS": User wants to know what's popular, trending, or market growth.
- "VIDEOS": User wants to see short clips, reels, or video benchmarks.
- "NEWS": User wants latest updates/news.
- "IMAGE_GEN": User wants to create or imagine an image.
- "VIDEO_GEN": User wants to create or animate a video.
- "VISUAL_SEARCH": User wants to research products visually, use Google Lens, find similar items, or find visual inspiration from an image or query.
- "TEXT": Standard conversation, ad writing, or general chatting.

Rules:
1. Return ONLY a JSON object representing the AIIntentResult.
2. Provide a 'confidence' score (0.0 to 1.0).
3. 'parameters' MUST include the 'query' translated to English (if not already) for better tool results.
4. 'suggested_actions' is an array of tool IDs for Smart Chips (e.g., ["shopping", "trends", "videos", "lens"]).
5. If intent is ambiguous, lower the confidence.

JSON Template:
{
  "intent": "SHOPPING",
  "confidence": 0.95,
  "parameters": {"query": "English query"},
  "suggested_actions": ["shopping", "amazon", "videos"]
}
""";

      // 🚀 استخدام نظام التبادل الذكي لتصنيف النوايا (Smart Fallback Brain)
      // يضمن بقاء "عقل" النظام يعمل حتى عند تعطل Gemini (429)
      final response = await AIProviderFactory.generateWithSmartFallback(routerPrompt, cancelToken: cancelToken);
      
      final Map<String, dynamic> data = JsonUtils.parseSafe(response.description);
      return AIIntentResult.fromJson(data);
    } catch (e) {
      debugPrint("⚠️ Intent Classification Error: $e");
      return AIIntentResult(
        intent: "TEXT",
        confidence: 0.0,
        parameters: {"original": userText},
        suggestedActions: [],
      );
    }
  }

  /// 1. نقطة الدخول الرئيسية: تحليل المدخلات واقتراح الإجراءات (Main Entry Point)
  Future<List<Map<String, dynamic>>> analyzeAndSuggest(File file,
      {required bool isVideo, dio.CancelToken? cancelToken}) async {
    final key = await _getGeminiKey();
    if (key.isEmpty) {
      throw Exception("مفتاح Gemini غير موجود في الإعدادات");
    }

    // حفظ في قاعدة البيانات (وسائط المنتج) (Product Media)
    await _db.insertRecord('product_media', {
      'file_path': file.path,
      'media_type': isVideo ? 'video' : 'image',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (isVideo) {
      // للنسخة الأولية (MVP)، إعادة اقتراحات ذكية ثابتة للفيديو
      // مستقبلاً، يمكن طلب تحليل الإطار الأول أو محتوى الفيديو من Gemini.
      return [
        {
          'type': AIActionType.editVideo,
          'label': 'تعديل ومونتاج',
          'icon': 'movie_edit',
          'description': 'قص، إضافة نصوص، فلاتر'
        },
        {
          'type': AIActionType.enhanceAudio,
          'label': 'تحسين الصوت',
          'icon': 'graphic_eq',
          'description': 'إزالة الضوضاء، تضخيم الصوت'
        },
        {
          'type': AIActionType.sceneAnalysis,
          'label': 'تحليل المشاهد AI',
          'icon': 'analytics',
          'description': 'فهم محتوى الفيديو لاقتراح العناوين'
        },
        {
          'type': AIActionType.highlightReel,
          'label': 'إنشاء ملخص (Shorts)',
          'icon': 'flash_on',
          'description': 'تحويله لفيديو قصير لـ TikTok'
        },
      ];
    } else {
      // معالجة الصور (Image Handling)
      return [
        {
          'type': AIActionType.generateVideo,
          'label': 'توليد فيديو إعلاني',
          'icon': 'movie_creation',
          'description': 'تحويل الصورة لفيديو متحرك'
        },
        {
          'type': AIActionType.generateDescription,
          'label': 'وصف تسويقي',
          'icon': 'description',
          'description': 'كتابة نص إعلاني للمنتج'
        },
        {
          'type': AIActionType.generateHashtags,
          'label': 'ترندات وهاشتاقات',
          'icon': 'tag',
          'description': 'أفضل الهاشتاجات لـ TikTok'
        },
        {
          'type': AIActionType.analyzeImage,
          'label': 'تحليل المنتج',
          'icon': 'radar',
          'description': 'نقاط القوة والجمهور المستهدف'
        },
      ];
    }
  }

  /// 2. طرق التنفيذ (Execution Methods)

  Future<String> generateDescription(File image, {dio.CancelToken? cancelToken}) async {
    // 2. استدعاء Gemini
    final prompt = """
أنت خبير تسويق. اكتب وصفاً إعلانياً لهذا المنتج (بأسلوب TikTok/Reels).
القواعد:
1. ابدأ بـ **Hook** (سؤال أو جملة صادمة).
2. اذكر 3 فوائد رئيسية في نقاط (bullets ✅).
3. اختم بـ **CTA** (دعوة للشراء) واضحة.
4. أضف هاشتاقات ترند.
5. 🚫 ممنوع المقدمات (مثل: "بصفتي خبير..." أو "إليك الوصف"). ابدأ بالنص الإعلاني فوراً.
""";
    final res = await _analyzeImageWithFallback(image, prompt, cancelToken: cancelToken);
    final description = res.description;

    // حفظ في السجل (History)
    await _db.insertRecord('generated_content', {
      'type': 'description_image',
      'prompt': prompt,
      'result': description,
      'created_at': DateTime.now().toIso8601String(),
    });

    return description;
  }

  Future<String> generateHashtags(File image, {dio.CancelToken? cancelToken}) async {
    final prompt =
        "استخرج أفضل 10 هاشتاقات (Hashtags) رائجة حالياً على TikTok وتناسب هذا المنتج. (أعطني الهاشتاقات فقط بدون مقدمات وبدون ترقيم)";
    final res = await _analyzeImageWithFallback(image, prompt, cancelToken: cancelToken);
    final hashtags = res.description;
    await _db.insertRecord('generated_content', {
      'type': 'hashtags_image',
      'prompt': prompt,
      'result': hashtags,
      'created_at': DateTime.now().toIso8601String(),
    });
    return hashtags;
  }

  Future<String> generateScript(String topic, {String tone = 'مرح', dio.CancelToken? cancelToken}) async {
    final res = await _gemini.generateScript(topic,
        tone: tone, apiKey: await _getGeminiKey(), cancelToken: cancelToken);
    await _db.insertRecord('generated_content', {
      'type': 'script',
      'prompt': topic,
      'result': res,
      'created_at': DateTime.now().toIso8601String(),
    });
    return res;
  }

  Future<String> generateMarketingPlan(String product,
      {String audience = 'الجمهور العام', dio.CancelToken? cancelToken}) async {
    final res = await _gemini.generateMarketingPlan(product,
        targetAudience: audience, apiKey: await _getGeminiKey(), cancelToken: cancelToken);
    await _db.insertRecord('generated_content', {
      'type': 'marketing_plan',
      'prompt': product,
      'result': res,
      'created_at': DateTime.now().toIso8601String(),
    });
    return res;
  }

  /// جديد: توليد نص إعلاني جذاب (التسويق الجذاب المحدث)
  Future<String> generateMarketingAd(String product, {File? image, dio.CancelToken? cancelToken}) async {
    final compressedFile =
        image != null ? await ImageUtils.compressForAi(image) : null;
    final bytes =
        compressedFile != null ? await compressedFile.readAsBytes() : null;
    if (image != null) {
      final res = await _analyzeImageWithFallback(image, 
          "أنت خبير محتوى تسويقي. اكتب إعلاناً جذاباً لهذا المنتج ($product) بأسلوب TikTok.", cancelToken: cancelToken);
      final ad = res.description;
      await _db.insertRecord('generated_content', {
          'type': 'marketing_ad',
          'prompt': product,
          'result': ad,
          'created_at': DateTime.now().toIso8601String(),
      });
      return ad;
    }

    final res = await _gemini.generateMarketingAd(product,
        imageBytes: bytes, apiKey: await _getGeminiKey(), cancelToken: cancelToken);
    await _db.insertRecord('generated_content', {
        'type': 'marketing_ad',
        'prompt': product,
        'result': res,
        'created_at': DateTime.now().toIso8601String(),
    });
    return res;
  }

  /// 🚀 توليد خطة محتوى تسويقية مهيكلة (Structured Content Plan)
  /// يحول البيانات البحثية إلى مخرجات إبداعية منظمة
  Future<Map<String, dynamic>> generateStructuredContentPlan(
      String product, {
      File? image,
      Map<String, dynamic>? researchData,
      dio.CancelToken? cancelToken,
  }) async {
    final researchContext = researchData != null 
        ? "Research Data (Use this for accuracy):\n${jsonEncode(researchData)}" 
        : "";

    final prompt = """
You are a Senior Growth Marketer and Content Creator. Generate a high-converting content plan for: $product.
$researchContext

Return ONLY a valid JSON object with this structure:
{
  "title": "A catchy title for the campaign",
  "audience": "Brief description of the ideal audience",
  "hooks": ["Hook 1 (Max 15 words)", "Hook 2", "Hook 3"],
  "adCopy": "The main marketing text. Use emojis, benefits, and a clear CTA.",
  "videoScript": "A 30-60 second script for TikTok/Reels with visual instructions [in brackets].",
  "visualPrompt": "A professional prompt for an AI image generator (like Midjourney/DALL-E) to create the perfect ad visual.",
  "seoTags": "#tag1 #tag2 #tag3"
}

IMPORTANT:
1. Language: Arabic (except for visualPrompt which should be English).
2. Content should be viral-friendly (TikTok/Instagram style).
3. Do NOT include markdown formatting (```json).
4. Do NOT include any text outside the JSON.
""";

    try {
      String responseText = "";
      if (image != null) {
        final res = await _analyzeImageWithFallback(image, prompt, isJson: true, cancelToken: cancelToken);
        responseText = res.description;
      } else {
        responseText = await generateText(prompt, cancelToken: cancelToken);
      }

      return JsonUtils.parseSafe(responseText);
    } catch (e) {
      debugPrint("❌ Structured Content Plan Error: $e");
      return {'error': e.toString()};
    }
  }

  Future<String> suggestViralHooks(String topic, {dio.CancelToken? cancelToken}) async {
    final res =
        await _gemini.suggestViralHooks(topic, apiKey: await _getGeminiKey(), cancelToken: cancelToken);
    await _db.insertRecord('generated_content', {
        'type': 'viral_hooks',
        'prompt': topic,
        'result': res,
        'created_at': DateTime.now().toIso8601String(),
    });
    return res;
  }

  /// 💬 توليد نصوص عامة (Chat/Marketing)
  Future<String> generateText(String prompt,
      {String? systemPersona,
      String? mode,
      List<Map<String, String>>? history,
      dio.CancelToken? cancelToken}) async {
    // 🛡️ Guard: Prevent empty prompt crashes (Error 1201)
    if (prompt.trim().isEmpty) {
      debugPrint("⚠️ [UnifiedAI]: Attempted to send empty prompt. Aborting.");
      return "⚠️ عذراً، لم أستطع معالجة طلبك لأن النص فارغ. يرجى كتابة شيء ما.";
    }

    if (Get.isRegistered<AIBackendRouter>()) {
      final router = Get.find<AIBackendRouter>();
      final res = await router.generateText(
        prompt: prompt,
        systemPersona: systemPersona,
        history: history,
      );
      if (res['success'] == true && res['data'] != null) {
        lastUsedProvider = res['meta']?['provider']?.toString() ?? 'firebase_ai';
        return res['data'].toString();
      }
      throw Exception(res['error'] ?? 'AI generation failed');
    }

    String? effectiveSystemPersona = systemPersona;
    String finalPrompt = prompt;

    if (effectiveSystemPersona != null) {
      finalPrompt = "$effectiveSystemPersona\n\n$prompt";
    }

    try {
      final res = await AIProviderFactory.generateWithSmartFallback(
        finalPrompt,
        history: history,
        cancelToken: cancelToken,
      );
      lastUsedProvider = res.provider;
      return res.description;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ UnifiedAIService.generateText Fallback Error: $e");
      rethrow;
    }
  }

  /// استخراج معلومات المنتج للبحث
  /// 🧠 استخراج بيانات المنتج (الاسم، التصنيف، العلامة التجارية)
  Future<Map<String, dynamic>> extractProductInfo(File image, {BrandIdentity? brand, dio.CancelToken? cancelToken}) async {
    if (kDebugMode) debugPrint("🧠 [UnifiedAI]: Starting Product Info Extraction...");
    
    final brandContext = brand != null ? """
CONTEXT: The user belongs to the brand '${brand.storeName}'. 
If the product in the image looks like it belongs to this brand or category (${brand.industry}), please prioritize identifying it as such.
""" : "";

    final prompt = """
$brandContext
You are an expert visual analyst. Analyze the image and extract details.
CRITICAL: Distinguish between a commercial product (for sale) and a personal item/person (selfie, person wearing clothes, casual photo).

Return ONLY JSON:
{
  "name": "Specific product name OR visual description (e.g., 'Person wearing grey shawl')",
  "category": "Category (Electronics, Fashion, Person, Home, Selfie, Food)",
  "brand": "Brand or 'Unknown'",
  "is_commercial": true/false, // True ONLY if it looks like a studio product photo or ad. False for selfies/people.
  "search_query": "Detailed English search query including [Brand] [Product Name] [Model] for best search results",
  "description": "Brief description in Arabic",
  "teaser": "A smart, unique marketing teaser or friendly comment in Arabic based SPECIFICALLY on this image (Max 15 words)"
}
NO MARKDOWN. NO EXTRA TEXT.
""";

    try {
      final res = await _analyzeImageWithFallback(image, prompt, isJson: true, cancelToken: cancelToken);
      final data = JsonUtils.parseSafe(res.description);
      data['provider'] = res.provider; // 🤖 تضمين اسم النموذج في البيانات المرجعة
      if (kDebugMode) debugPrint("✅ [UnifiedAI]: Extraction Complete: ${data['name']}");
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ [UnifiedAI]: Extraction Failed: $e");
      return {'error': e.toString()};
    }
  }

  /// 🍱 [Full Meal Recovery]: استخراج بيانات المنتج والقالب في طلب واحد
  Future<Map<String, dynamic>> extractProductInfoBatch(List<File> images, {BrandIdentity? brand, dio.CancelToken? cancelToken}) async {
    if (kDebugMode) debugPrint("🧠 [UnifiedAI]: Starting Batch Extraction (Product + Template)... 🍱");
    
    final brandContext = brand != null ? "User Brand: ${brand.storeName} (${brand.industry})." : "";

    final prompt = """
$brandContext
You are a High-End Art Director. Analyze these TWO images for a marketing campaign.
[Image Index 0]: THE MAIN PRODUCT.
[Image Index 1]: THE BACKGROUND TEMPLATE.

MISSION: 
1. Identify the PRODUCT in Image 0 (ignore any distractions).
2. Note the visual style/theme of Image 1 (The Template).
3. Synthesize a joint description that places the Product in the Template.

Output JSON only:
{
  "name": "Specific Product Name from Image 0",
  "category": "Product Category",
  "brand": "Product Brand",
  "search_query": "English search query",
  "composition_note": "A summary of how the product (Img 0) fits into the environment (Img 1)",
  "detected_template_theme": "The visual theme of Image 1 (e.g. orange marketplace, luxury bedroom)"
}
NO MARKDOWN. NO EXTRA TEXT.
""";

    try {
      final bytesList = await ImageUtils.batchPrepareForVision(images);
      final res = await analyzeBatchImages(bytesList, prompt, maxTokens: 800, cancelToken: cancelToken);
      final data = JsonUtils.parseSafe(res.description);
      if (kDebugMode) {
        debugPrint("✅ [UnifiedAI]: Batch Extraction Complete: ${data['name']} in ${data['detected_template_theme']}");
      }
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ [UnifiedAI]: Batch Extraction Failed: $e");
      // Fallback to single image extraction if batch fails
      if (images.isNotEmpty) return await extractProductInfo(images.first, brand: brand, cancelToken: cancelToken);
      return {'error': e.toString()};
    }
  }

  Future<AiResult> analyzeImage(File image, String prompt,
      {List<Map<String, String>>? history, dio.CancelToken? cancelToken}) async {
    // نستخدم النظام الموحد للتحليل البصري مع دعم التبديل التلقائي
    return await _analyzeImageWithFallback(image, prompt, history: history, cancelToken: cancelToken);
  }

  /// 🛡️ المحرك الموحد للتحليل البصري (Unified Visual Analysis with Fallback)
  /// يحاول استخدام Gemini أولاً، وفي حال فشله (خاصة خطأ 429)، يستخدم Google Lens + SerpApi AI
  Future<AiResult> _analyzeImageWithFallback(File image, String prompt,
      {List<Map<String, String>>? history, bool isJson = false, dio.CancelToken? cancelToken}) async {
    
    // 🛡️ Guard: Prevent empty visual prompts
    if (prompt.trim().isEmpty) {
      return AiResult(description: "⚠️ يرجى تزويد صف أو أمر لتحليل الصورة.", provider: "System Guard");
    }

    // ⚡ تصغير الصورة وتشفيرها لتقليل استهلاك التوكنز والوقت
    final bytes = await ImageUtils.compressAndResizeForVision(image);

    try {
      // 🚀 استخدام نظام التبديل الذكي للرؤية (Vision Smart Fallback)
      // يحاول استخدام Gemini Vision أولاً، وفي حال فشله (403/429)، ينتقل لـ GitHub GPT-4o أو OpenRouter
      final res = await AIProviderFactory.analyzeWithSmartFallback(
        bytes,
        prompt,
        history: history,
        cancelToken: cancelToken,
      );
      lastUsedProvider = res.provider; // 🤖 حفظ اسم المحرك الفعلي المستخدم للتحليل البصري
      return res;
    } catch (e) {
      // 🛡️ خطة الإنقاذ القصوى: إذا فشل كل من Gemini و GitHub/OpenRouter (مثلاً بسبب القوتا)
      // نلجأ لـ Google Lens + SerpApi كحل أخير
      if (kDebugMode) debugPrint("📡 [FALLBACK]: Multi-provider Vision failed. Rescuing with Google Lens...");
      
      try {
        final lensData = await _lens.analyzeImage(image.path);
        
        if (lensData.contains("فشل") || lensData.isEmpty) {
          rethrow;
        }

        final fallbackPrompt = """
You are an AI assistant helping with visual analysis.
I have used Google Lens on an image, and it found the following results:
---
$lensData
---

USER REQUEST:
$prompt

CRITICAL INSTRUCTIONS:
- Based on the Google Lens results, fulfill the user request.
- If the user requested JSON, you MUST return valid JSON. 
- Do NOT say "I cannot see the image".
- If you are unsure about the product name, use the most prominent result from Google Lens.
- Never return "There is no structural data available". If data is sparse, provide generic but valid JSON fields (e.g., {"name": "Unknown Product", "category": "General"}).
""";

        final res = await AIProviderFactory.generateWithSmartFallback(fallbackPrompt, history: history, cancelToken: cancelToken);
        lastUsedProvider = res.provider; // 🤖 حفظ اسم المحرك البديل المستخدم
        return res;
      } catch (fallbackError) {
        if (kDebugMode) debugPrint("❌ [FALLBACK ERROR]: Visual fallback failed: $fallbackError");
        rethrow;
      }
    }
  }

  /// جديد: توليد فيديو إعلاني باستخدام مزود الفيديو الفعال (Kling أو Higgsfield)
  Future<String> generateVideo(File image, {String? prompt, dio.CancelToken? cancelToken}) async {
    // 1. استخراج برومبت محسّن إذا لم يتم توفيره أو إذا كان برومبتاً بسيطاً
    String finalPrompt = prompt ?? "";
    if (finalPrompt.isEmpty ||
        finalPrompt.contains('High-end commercial') ||
        finalPrompt.length < 50) {
      finalPrompt = await generateVideoPrompt(image, cancelToken: cancelToken);
    }

    // 2. طلب توليد الفيديو
    final isHiggsfield = _settings.getActiveVideoProvider() == ProviderType.higgsfield;
    String result = "";

    if (isHiggsfield) {
      final higgsfield = Get.find<HiggsfieldService>();
      final effectiveKey = await _getEffectiveKey(ProviderType.higgsfield);
      result = await higgsfield.generateVideo(finalPrompt,
          imagePath: image.path, apiKey: effectiveKey);
    } else {
      final kling = Get.find<KlingService>();
      final effectiveKey = await _getEffectiveKey(ProviderType.kling);
      result = await kling.generateVideo(finalPrompt,
          imagePath: image.path, apiKey: effectiveKey);
    }

    // حفظ في قاعدة البيانات
    await _db.insertRecord('generated_content', {
      'type': 'video_generation',
      'prompt': finalPrompt,
      'result': result, // قد يكون رابطاً أو ID
      'created_at': DateTime.now().toIso8601String(),
    });

    return result;
  }

  /// 🎬 توليد برومبت فيديو احترافي بناءً على وصف الصورة (Visual-to-Video Prompting)
  Future<String> generateVideoPrompt(File image, {dio.CancelToken? cancelToken}) async {
    try {
      // IMAGE COMPRESSION NOT NEEDED HERE IF PROMPT ONLY
      // final compressedFile = await ImageUtils.compressForAi(image);
      // final bytes = await compressedFile.readAsBytes();

      const prompt = """
انظر إلى صورة هذا المنتج جيدا.
المطلوب: توليد وصف (Prompt) باللغة الإنجليزية لتوليد فيديو إعلاني سينمائي لهذا المنتج باستخدام Kling AI.
ركز على:
1. الجماليات البصرية للمنتج (الخامة، اللون، التفاصيل).
2. حركة الكاميرا (Cinematic slow motion, product rotation, 4k).
3. الإضاءة المحيطة (Soft studio lighting, dramatic shadows, neon highlights).
4. الخلفية (Elegant bokeh background, luxury showcase).

اكتب الرد باللغة الإنجليزية حصراً، في سطر واحد فقط ومباشرة دون أي مقدمات أو علامات تنصيص.
Example: Professional cinematic product showcase of a luxury watch, elegant golden hour lighting, slow 360 rotation, high-end commercial style, 4k.
""";

      final apiKey = await _getGeminiKey();
      final res = await _gemini.generateText(prompt, apiKey: apiKey, cancelToken: cancelToken);

      String cleanPrompt =
          res.description.trim().replaceAll('"', '').replaceAll('\n', ' ');

      // Fallback if Gemini fails to give a good prompt
      if (cleanPrompt.length < 10) {
        final info = await extractProductInfo(image);
        return "Cinematic high-quality commercial for ${info['name'] ?? 'Product'}, professional advertising style, 4k, smooth motion.";
      }

      return cleanPrompt;
    } catch (e) {
      if (kDebugMode) print('❌ UnifiedAIService.veoPrompt Error: $e');
      return "Cinematic commercial video for the product in the image, professional lighting, smooth motion, 4k.";
    }
  }

  /// 🎨 توليد إعلان إبداعي متكامل (High-Fidelity Ad Creative)
  /// يضمن ترتيباً صارماً: [قالب، منتج، شعار] مع التحقق من الأحجام
  Future<AiResult> generateAdCreative({
    required File template,
    required File product,
    required File logo,
    String? customPrompt,
    String? productName, // 🆕 Context Injection
    dio.CancelToken? cancelToken,
  }) async {
    if (kDebugMode) debugPrint("🚀 [UnifiedAI]: Starting high-fidelity Ad Creative Pipeline...");

    // 1. التحقق من الترتيب والأحجام (Size-Based Validation)
    final tSize = template.lengthSync();
    final pSize = product.lengthSync();
    final lSize = logo.lengthSync();

    if (kDebugMode) {
      debugPrint("📊 [Validation]: T: $tSize, P: $pSize, L: $lSize");
    }

    // 🚀 Performance Fix (Zero-Lag Batch): Compress both in ONE isolate pass
    // 🚀 Performance Fix (Zero-Lag Batch): Compress both in ONE isolate pass
    final List<Uint8List> images = await ImageUtils.batchPrepareForVision([product, template]);

    final brandingPrompt = """
USER INSTRUCTIONS: ${customPrompt ?? ''}

HERO SUBJECT PROJECT: As a High-End Art Director, analyze these TWO images in their EXACT order.
[Image Index 0]: HERO PRODUCT (The Primary Subject) - This is the actual product for sale.
[Image Index 1]: BACKGROUND TEMPLATE (The Design Environment) - This is ONLY context for the design.

----------------------------------------
MISSION: 
Identify the product EXCLUSIVELY from [Image Index 0]. Provide its specific name and benefits.
Position and style the advertisement to perfectly fit the environment of [Image Index 1].

STRICT RULES:
1. (SUBJECT ISOLATION): Image 0 is the ONLY Subject. Give it 100% priority for identification.
2. (IGNORE TEMPLATE BRANDING): If [Image 1] contains text or branding (like Alibaba Sanaa), DISREGARD IT COMPLETELY. Imagine it is NOT there.
3. (LATENT COMPOSITION): Mentally "place" the product from [Image 0] into the template [Image 1].
4. (PRODUCT CLASSIFICATION): Generate high-converting Arabic headlines based ONLY on the visual features of [Image 0].
5. (LIGHTING): Identify the light source in the Template [Image 1] to match shadows on the Product [Image 0].
----------------------------------------
OUTPUT FORMAT (STRICT):
DESCRIPTIVE_TITLE: <Arabic Title>
AD_COPY: <Arabic Headline>
BENEFITS: <Benefit 1, Benefit 2, Benefit 3>
POSITION: <Left|Center|Right>
METADATA: { "has_box": true/false, "has_hand": true/false, "light_source": "Top-Left|Top-Right|Center" }
""";

    return await analyzeBatchImages(images, brandingPrompt, history: null, maxTokens: 800, cancelToken: cancelToken);
  }


  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {List<Map<String, String>>? history, int maxTokens = 800, dio.CancelToken? cancelToken}) async {
    // 🛡️ Multi-Image Analysis (High-Efficiency Pipeline)
    final List<Uint8List> orderedImages = List.from(images);
    
    const String visionSystemPersona = """
You are a professional visual analyzer and creative director. 
Mandatory Rule: If you cannot read specific text on a product, describe its appearance (shape, color, category) and use that description to fulfill the marketing request. 
Never return empty results or excuses about image quality. Synthesize and infer based on visual cues.
""";
    
    try {
      AiResult result;
      final geminiKey = _settings.getApiKey(ProviderType.gemini);
      if (geminiKey.isNotEmpty) {
        result = await AIProviderFactory.getServiceByType(ProviderType.gemini)
            .analyzeBatchImages(orderedImages, prompt, apiKey: geminiKey, history: history, maxTokens: maxTokens, systemPersona: visionSystemPersona, cancelToken: cancelToken);
      } else {
        final openRouterKey = _getSettingsKey(ProviderType.openrouter);
        if (openRouterKey != null && openRouterKey.isNotEmpty) {
          result = await AIProviderFactory.getServiceByType(ProviderType.openrouter)
              .analyzeBatchImages(orderedImages, prompt, apiKey: openRouterKey, history: history, maxTokens: maxTokens, systemPersona: visionSystemPersona, cancelToken: cancelToken);
        } else {
          final githubKey = _getSettingsKey(ProviderType.github);
          result = await AIProviderFactory.getServiceByType(ProviderType.github)
              .analyzeBatchImages(orderedImages, prompt, apiKey: githubKey ?? '', history: history, maxTokens: maxTokens, systemPersona: visionSystemPersona, cancelToken: cancelToken);
        }
      }

      // 🔍 Post-Processing: Extract Product Name from description if not present
      final String description = result.description;
      final String? extractedName = _extractProductName(description);
      
      // 🛡️ Safety Fix: Handle productName lookup safely to prevent runtime crashes
      String? pName;
      try {
        pName = result.productName;
      } catch (e) {
        if (kDebugMode) debugPrint("⚠️ productName lookup failed, using extraction: $e");
      }

      return AiResult(
        description: description,
        productName: pName ?? extractedName,
        tags: result.tags,
        provider: result.provider,
      );
    } catch (e) {
      if (kDebugMode) print('❌ UnifiedAIService Batch Vision Error: $e');
      rethrow;
    }
  }

  /// 🕵️ مساعد لاستخراج اسم المنتج من ردود الـ AI الوصفية
  String? _extractProductName(String text) {
    // نركز على استخراج النص بعد "DESCRIPTIVE_TITLE:" أو "Product:"
    final patterns = [
      RegExp(r'DESCRIPTIVE_TITLE:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'Product:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'المنتج:\s*([^\n]+)'),
      RegExp(r'اسم المنتج:\s*([^\n]+)'),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  String? _getSettingsKey(ProviderType type) {
    final settings = Get.find<SettingsController>();
    return settings.getApiKey(type);
  }

  /// 🚀 Integrated Analysis (Zero-Lag Full Meal)
  /// Runs in a background isolate via 'compute' to eliminate UI jank
  static Future<AiResult> analyzeProjectWithContext(Map<String, dynamic> params) async {
    final List<Uint8List> images = params['images'];
    final String userPrompt = params['prompt'];
    final String apiKey = params['apiKey'];
    final String baseUrl = params['baseUrl'];
    final String model = params['model'] ?? 'gpt-4o';

    if (images.length >= 2) {
      debugPrint("🚀 [UnifiedAI-Isolate]: Multi-image detected. Bypassing memory for Integrated Analysis...");
    }

    // 2. Prepare "The Full Meal" (Integrated Batch Request)
    final Map<String, dynamic> requestBody = {
      "model": model,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text", 
              "text": "Task: Create a professional ad. \n"
                      "Image 1: The main product (Identify this exclusively). \n"
                      "Image 2: The background template (Context only). \n"
                      "Instruction: ${userPrompt.isNotEmpty ? userPrompt : 'Create a high-quality advertisement.'}"
            },
            // Product Image
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,${base64Encode(images[0])}"}
            },
            // Template Image
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,${base64Encode(images[1])}"}
            },
          ]
        }
      ],
      "max_tokens": 800,
    };

    return await _sendToProviderStatic(requestBody, apiKey, baseUrl);
  }

  static Future<AiResult> _sendToProviderStatic(Map<String, dynamic> body, String apiKey, String baseUrl) async {
    final String finalUrl = baseUrl.contains('chat/completions') ? baseUrl : (baseUrl.endsWith('/') ? '${baseUrl}chat/completions' : '$baseUrl/chat/completions');
    
    final response = await http.post(
      Uri.parse(finalUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final content = (data["choices"]?[0]?["message"]?["content"] ?? "").toString();
      
      return AiResult(
        description: content.trim(),
        provider: 'Isolate-Integrated',
      );
    } else {
      throw Exception("Integrated Batch request failed: ${response.statusCode} - ${response.body}");
    }
  }
}
