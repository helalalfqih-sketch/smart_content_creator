import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import '../../ai/core/agent_models.dart';
import '../../ai/models/app_context.dart';
import '../unified_ai_service.dart';
import 'naive_bayes_classifier.dart';
import 'data/naive_bayes_data.dart';

enum Sentiment { neutral, excited, angry, urgent, inquisitive }

class IntentClassifierService {
  final NaiveBayesClassifier _bayes = NaiveBayesClassifier();
  final UnifiedAIService? _aiService;
  bool _isTrained = false;

  IntentClassifierService([this._aiService]) {
    _trainClassifier();
  }

  void _trainClassifier() {
    if (!_isTrained) {
      _bayes.train(initialTrainingData);
      _isTrained = true;
    }
  }

  /// 🧠 المحلل الذكي: يستخدم Gemini لفهم النية العميقة وتحويلها لـ JSON
  Future<Map<String, dynamic>> smartClassify(String text,
      {AppContext? context, dio.CancelToken? cancelToken}) async {
    if (_aiService == null) return {'intent': 'casualChat', 'confidence': 0.5};

    try {
      final prompt = """
      You are the 🧠 Strategic Brain of an AI Content Creation platform.
      Analyze this user request: "$text"
      
      Context Info:
      - Active Screen: ${context?.activeScreen ?? 'Unknown'}
      - Current Product: ${context?.productName ?? 'None'}
      
      Available Tools & Capabilities:
      - video_gen: Generates professional AI videos from a product photo.
      - image_gen: Creates/edits product images, logos, and professional backgrounds.
      - trend_search: Searches TikTok for viral content ideas.
      - product_analysis: Analyzes product info from text or images.
      - ad_writing: Writes marketing scripts and captions.
      - google_lens: Visual search and product identification from images.
      - google_trends: Real-time market demand and trending search analysis.
      - youtube_search: Searching YouTube for reviews, tutorials, and competitors.
      - amazon_search: Sourcing products, checking prices and competitors on Amazon.
      - google_news: Latest industry news and PR mentions for brands.
      - google_shopping: Price comparison and deal finding.
      - google_reverse_image: Finding original sources and rights for an image.
      - google_short_videos: Viral analysis of YouTube Shorts.
      - google_search: General web search for local businesses, knowledge graph info, and broad questions.
      - visual_expansion: Deep research starting from an image (Lens + Search bridge) to get reviews, questions, and content ideas.
      - chat: General helpful conversation.
      
      Your goal is to classify the intent and analyze feasibility.
      
      ⚠️ IMPORTANT RULES:
      1. [LANGUAGE]: You MUST generate all 'description', 'user_goal', 'goal', 'task_prompt', and 'suggested_question' fields in ARABIC ONLY. Internal reasoning and prompts MUST be in Arabic to maintain conversation consistency.
      2. [AMAZON]: For 'amazon_search' tool, you MUST use the parameter key "k" instead of "q" for the search query. Example: {"tool": "amazon_search", "params": {"k": "drone"}}.
      
      CRITICAL DIFFERENTIATION:
      - If user says "Analyze this image", "What is this?", "Tell me about this photo" -> intent: product_analysis
      - If user says "Create an image", "Imagine a logo", "Draw something" -> intent: image_gen
      - If user says "Animate this", "Make a video", "Convert to reel" -> intent: video_gen
      - If user JUST sends an image without text -> intent: product_analysis
      
      Output Technical Keys:
      - video_gen, image_gen, trend_search, product_analysis, ad_writing, chat
      - google_lens, google_trends, youtube_search, amazon_search, google_news, google_shopping, google_reverse_image, google_short_videos, google_search, visual_expansion

      Return ONLY a JSON object:
      {
        "intent": "key",
        "confidence": 0.95,
        "product_name": "extracted product or null",
        "user_goal": "summarize user ultimate goal",
        "required_tools": ["tiktok_search", "google_lens", etc],
        "feasibility": "full | partial | none",
        "reasoning": "brief explanation",
        "plan": [
           {"order": 1, "tool": "tool_name", "description": "what to do", "params": {}}
        ],
        "requires_clarification": true/false,
        "suggested_question": "if confidence is low, what to ask user?",
        "style": "cinematic/playful/professional/null",
        "requires_vision": true/false
      }
      """;

      final raw = await _aiService.generateText(prompt,
          systemPersona: "You are an Intent and Planning API.", cancelToken: cancelToken);
          
      // 🛡️ Robust Extraction: Use regex to find the first JSON-like block {}
      final jsonMatch = RegExp(r'\{[\s\S]*\}', multiLine: true).firstMatch(raw);
      if (jsonMatch == null) {
        throw FormatException("No JSON object found in response: $raw");
      }
      
      final clean = _cleanJson(raw);
      
      try {
        final Map<String, dynamic> data = jsonDecode(clean);

        // Auto-logic: if confidence is really low, force clarification
        if ((data['confidence'] ?? 0.0) < 0.5) {
          data['requires_clarification'] = true;
        }

        return data;
      } catch (e) {
        debugPrint("❌ JSON Parsing Error in smartClassify: $e");
        debugPrint("📦 Raw Response: $raw");
        debugPrint("🧹 Cleaned String: $clean");
        rethrow;
      }
    } catch (e) {
      // 🛡️ Fallback Logic: If Gemini fails (Rate Limit 429), use Local Hybrid logic
      debugPrint(
          "⚠️ Smart Classification Failed: $e. Falling back to Local Mode.");
      return _localFallback(text, context);
    }
  }

  /// 🧹 مُنظف الـ JSON: يزيل أي نص زائد أو رموز هروب غير مرتبة (Escapes)
  String _cleanJson(String raw) {
    if (raw.isEmpty) return "{}";
    
    // 1. استخراج الكتلة التي تبدأ بـ { وتنتهي بـ }
    final jsonMatch = RegExp(r'\{[\s\S]*\}', multiLine: true).firstMatch(raw);
    String clean = jsonMatch?.group(0) ?? raw;

    // 2. إزالة علامات Markdown
    clean = clean
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // 3. 🛡️ Absolute Fix: إزالة رموز الهروب التي يخطئ الـ LLM في وضعها داخل الـ JSON
    // مثل \_ أو \, أو \" (إذا كانت زائدة)
    clean = clean.replaceAll(r'\_', '_');
    clean = clean.replaceAll(r'\,', ',');
    
    return clean;
  }

  /// 🏠 Local Fallback: Classification using Naive Bayes and Rules
  Map<String, dynamic> _localFallback(String text, AppContext? context) {
    final msg = IncomingMessage(text: text);
    final intent = classifyIntent(msg, null, null, context: context);

    // Convert Enum to String key
    String key = 'chat';
    if (intent == Intent.videoGeneration) {
      key = 'video_gen';
    } else if (intent == Intent.imageGeneration) {
      key = 'image_gen';
    } else if (intent == Intent.trendRequest) {
      key = 'trend_search';
    } else if (intent == Intent.productDetected) {
      key = 'product_analysis';
    } else if (intent == Intent.adRequest) {
      key = 'ad_writing';
    } else if (intent == Intent.visualSearch) {
      key = 'visual_search';
    }

    return {
      'intent': key,
      'confidence': 0.7, // Fixed confidence for local
      'product_name':
          context?.productName, // ✅ Preserve existing context product
      'user_goal': 'Local Fallback Execution',
      'required_tools': [key],
      'feasibility': 'full',
      'plan': [
        {'order': 1, 'tool': key, 'description': text}
      ],
      'requires_clarification': false,
      'source': 'local_fallback'
    };
  }

  /// 🌍 الكشف الصريح عن نية البحث العام (Google Search)
  bool _containsGoogleSearchRequest(String text) {
    final keywords = [
      'ابحث عن', 'فين مكان', 'اين يقع', 'موقع', 'رقم تليفون', 'مواعيد عمل',
      'search google', 'find location', 'address for', 'phone number of',
      'هو مين', 'ما هو', 'من يكون', 'tell me about', 'who is', 'what is'
    ];
    return keywords.any((k) => text.toLowerCase().contains(k));
  }

  /// 📸➡️🌐 الكشف عن نية التوسع البصري (Visual Expansion)
  bool _containsVisualExpansionRequest(String text, bool hasMedia) {
    if (!hasMedia) return false;
    final keywords = [
      'حلل بعمق', 'خطة محتوى', 'معلومات اكتر', 'توسع', 'أبحاث', 'ريفيوهات',
      'deep research', 'content plan', 'more info', 'expand', 'reviews for this'
    ];
    return keywords.any((k) => text.toLowerCase().contains(k));
  }

  /// Classifies the user intent based on priority (Legacy Hybrid Support)
  Intent classifyIntent(IncomingMessage msg, MediaAnalysisResult? media,
      ProductVisionResult? product,
      {AppContext? context}) {
    if (msg.url != null && _isTikTokUrl(msg.url!)) {
      return Intent.urlAnalysis;
    }

    final text = msg.text ?? '';
    final lower = text.toLowerCase();

    // 🌐 Context-Aware Bridge & URL Content detection
    if (lower.contains("[بيانات المنتج من الرابط]:") || lower.contains("jina.ai")) {
      return Intent.productDetected;
    }

    final hasContextProduct = context?.hasProduct ?? false;
    final isImplicit = _isExplicitProductMention(lower) ||
        lower.contains('له') ||
        lower.contains('عنها') ||
        lower.contains('هذا') ||
        lower.contains('this');

    if (hasContextProduct && isImplicit) {
      if (_containsVideoRequest(lower)) return Intent.videoGeneration;
      if (_containsTrendRequest(lower)) return Intent.trendRequest;
    }

    if (text.isNotEmpty) {
      final probs = _bayes.predict(text);
      if (probs.isNotEmpty) {
        final sorted = probs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (sorted.first.value > 0.6) {
          if (sorted.first.key == 'trend') return Intent.trendRequest;
          if (sorted.first.key == 'analysis') return Intent.productDetected;
        }
      }

      if (_containsAdRequest(lower)) return Intent.adRequest;
      if (_containsTrendRequest(lower)) return Intent.trendRequest;
      if (_containsCodeRequest(lower)) return Intent.codeRequest;
      if (_containsImageRequest(lower)) return Intent.imageGeneration;
      if (_containsVideoRequest(lower)) return Intent.videoGeneration;
      if (_containsInstagramRequest(lower)) return Intent.instagramSearch;
      if (_containsAlibabaRequest(lower)) return Intent.alibabaSource;
      if (_containsVisualSearchRequest(lower)) return Intent.visualSearch;
      if (_containsGoogleSearchRequest(lower)) return Intent.googleSearch;
      if (_containsVisualExpansionRequest(lower, msg.hasMedia)) return Intent.visualExpansion;
    }

    if (msg.hasMedia && product != null && product.isProduct) {
      return Intent.productDetected;
    }
    if (msg.hasMedia &&
        media != null &&
        media.contentType == ContentType.product) {
      return Intent.productDetected;
    }
    if (text.isEmpty) return Intent.unknown;
    if (_isPotentialProduct(text)) {
      return Intent.productDetected;
    }

    return Intent.casualChat;
  }

  bool _isTikTokUrl(Uri url) {
    return url.host.toLowerCase().contains('tiktok.com');
  }

  bool _containsTrendRequest(String text) {
    if (_containsAdRequest(text)) return false;
    final keywords = [
      'ترند',
      'رائج',
      'trending',
      'trends',
      'فيديوهات رائدة',
      'تيك توك',
      'tiktok'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsAdRequest(String text) {
    final keywords = [
      'وصف',
      'تسويق',
      'ad copy',
      'marketing',
      'caption',
      'اعلان',
      'إعلان',
      'هاشتاقات',
      'hashtags',
      'هاشتاج',
      'هاشتاق',
      'سيناريو',
      'scenario'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsCodeRequest(String text) {
    final keywords = [
      'كود',
      'code',
      'برمجة',
      'script',
      'programming',
      'اكتب لي ',
      'write me '
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsImageRequest(String text) {
    final keywords = [
      'صمم لي صورة',
      'صمم صورة',
      'توليد صورة',
      'منتج في صورة',
      'خلفية للمنتج',
      'ارسم',
      'تخيل',
      'imagine',
      'draw',
      'generate image',
      'create image',
      'logo',
      'لوجو',
      'شعار'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsVideoRequest(String text) {
    final keywords = [
      'اصنع فيديو',
      'اعمل فيديو',
      'حول لفيديو',
      'تحريك',
      'طريقة تحريك',
      'animate',
      'generate video',
      'make video',
      'kling',
      'reel',
      'ريل'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsInstagramRequest(String text) {
    final keywords = [
      'انستقرام',
      'انستجرام',
      'انستا',
      'instagram',
      ' ig ',
      'reels',
      'ريلز'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsAlibabaRequest(String text) {
    final keywords = [
      'علي بابا',
      'عليبابة',
      'مورد',
      'alibaba',
      'supplier',
      'sourcing',
      'buy from china'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _containsVisualSearchRequest(String text) {
    final keywords = [
      'عدسة',
      'لينس',
      'lens',
      'مشابه',
      'إلهام بصري',
      'visual inspiration',
      'search image',
      'find image',
      'discover style'
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isPotentialProduct(String text) {
    if (text.trim().isEmpty) return false;
    final words = text.trim().split(' ');
    if (words.length > 7) return false;
    final productIndicators = [
      'عطر',
      'جهاز',
      'ساعة',
      'حقيبة',
      'منتج',
      'أداة',
      'كريم',
      'هاتف',
      'سماعة',
      'لابتوب',
      'نظارة',
      'حذاء',
      'ملابس',
      'كتاب',
      'عدسة',
      'مكمل',
      'بروتين',
      'ماكينة',
      'شاحن',
      'بطارية',
      'طنجرة',
      'مقلاة',
      'غلاية',
      'خلاط',
      'فرن',
      'ميكروويف',
      'ثلاجة',
      'غسالة',
      'مكواة',
      'سشوار',
      'مصفف',
      'ماسك',
      'كريم',
      'سيروم',
      'شامبو',
      'بلسم',
      'عطر',
      'بخور',
      'فستان',
      'قميص',
      'بنطلون',
      'تيشيرت',
      'جاكيت',
      'عباية',
      'سجادة',
      'مفرش',
      'لحاف',
      'مخدة',
      'كرسي',
      'طاولة',
      'كنبة',
      'سرير',
      'دولاب',
      'خزانة',
      'رف',
      'مكتب',
      'ساعة',
      'خاتم',
      'اسوارة',
      'سلسال',
      'عقد',
      'حقيبة',
      'شنطة',
      'محفظة',
      'لعبة',
      'دراجة',
      'سكوتر',
      'كاميرا',
      'ترايبود',
      'مايك',
      'اضاءة',
      'كيبل',
      'توصيلة',
      'باوربانك',
      'كفر',
      'استشوار',
      'فير',
      'مكياج',
      'روج',
      'مسكرة'
    ];
    final lower = text.toLowerCase();
    if (productIndicators.any((k) => lower.contains(k))) return true;
    final englishProductTerms = [
      'iphone',
      'samsung',
      'nike',
      'adidas',
      'sony',
      'laptop',
      'macbook',
      'headphone',
      'watch',
      'camera',
      'drone',
      'led',
      'mask',
      'charger'
    ];
    if (englishProductTerms.any((k) => lower.contains(k))) return true;
    final commandWords = [
      'فيديو',
      'صورة',
      'بحث',
      'ريفيو',
      'video',
      'image',
      'search',
      'review',
      'tiktok'
    ];
    if (commandWords.any((k) => lower.contains(k)) &&
        !productIndicators.any((p) => lower.contains(p))) {
      if (_isExplicitProductMention(text)) return true;
      return false;
    }
    return false;
  }

  bool _isExplicitProductMention(String text) {
    final lower = text.toLowerCase();
    final explicitMarkers = [
      'للمنتج التالي',
      'المنتج التالي',
      'عن المنتج',
      'اسم المنتج',
      'هذا المنتج',
      'product:',
      'product name',
      'following product',
      'for the product',
      'about this product'
    ];
    return explicitMarkers.any((m) => lower.contains(m));
  }

  Sentiment analyzeSentiment(String text) {
    final lower = text.toLowerCase();
    if (['سيء', 'بطيء', 'غبي', 'خطأ', 'bad', 'slow', 'stupid', 'error', 'wrong']
        .any((k) => lower.contains(k))) {
      return Sentiment.angry;
    }
    if ([
      'رائع',
      'ممتاز',
      'شكرا',
      'مبدع',
      'wow',
      'amazing',
      'love',
      'cool',
      'thanks',
      '😍',
      '🔥'
    ].any((k) => lower.contains(k))) {
      return Sentiment.excited;
    }
    if (['بسرعة', 'عاجل', 'ضروری', 'fast', 'urgent', 'asap', 'now']
        .any((k) => lower.contains(k))) {
      return Sentiment.urgent;
    }
    if (['كيف', 'ماذا', 'لماذا', 'هل', 'how', 'what', 'why', '?']
        .any((k) => lower.contains(k))) {
      return Sentiment.inquisitive;
    }
    return Sentiment.neutral;
  }
}
