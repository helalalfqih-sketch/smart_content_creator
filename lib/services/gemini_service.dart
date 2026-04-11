import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import '../core/models/api_provider.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/utils/log_service.dart';
import 'ai_provider.dart';
import '../core/api/enterprise_api_client.dart';

class GeminiService implements AIProvider {
  static const List<String> _modelCandidates = [
    // OpenRouter Specific (Preferred)
    "google/gemini-pro-1.5",
    "google/gemini-flash-1.5",
    "google/gemini-2.0-flash-001",
    "google/gemini-2.0-pro-exp-02-05:free",
    "google/gemini-2.0-flash-exp:free",
    
    // Google Native
    "gemini-1.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-2.0-flash-exp",
    "gemini-1.5-pro",
    "gemini-1.5-pro-latest",
    "gemini-2.0-pro-exp-02-05",
    "gemini-pro",
  ];

  String? _cachedWorkingModel;
  String _cachedVersion = "v1beta"; 
  final EnterpriseApiClient _apiClient = EnterpriseApiClient();

  static const String _systemInstructionText =
      '''أنت خبير محتوى وتسويق متخصص.
مهمتك:
- مساعدة المستخدم في كتابة المحتوى، التسويق، وتحليل الصور/الفيديو.
- يجب أن تكون جميع الردود باللغة العربية حصراً وبشكل قطعي.
- ابدأ بالرد المطلوب فوراً دون مقدمات أو ترحيب.
- تجنب تماماً ذكر اسمك أو اسم التطبيق أو "بصفتي مساعد ذكي".
''';

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    
    final fullPrompt = "${systemPersona ?? _systemInstructionText}\n\n$prompt";

    // ✅ Dynamic Model Rotation Helper
    return _rotateUntilSuccess(
      apiKey: apiKey,
      cancelToken: cancelToken,
      builder: (model) => {
        "contents": [
          if (history != null) ..._mapHistoryToContents(history),
          {
            "role": "user",
            "parts": [
              {"text": fullPrompt}
            ]
          }
        ],
        "generationConfig": {
           "temperature": 0.7,
           if (maxTokens != null) "maxOutputTokens": maxTokens,
        }
      },
    );
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    
    final fullPrompt = "${systemPersona ?? _systemInstructionText}\n\n$prompt";

    return _rotateUntilSuccess(
      apiKey: apiKey ?? '',
      cancelToken: cancelToken,
      builder: (model) => {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Encode(bytes)
                }
              },
              {"text": fullPrompt}
            ]
          }
        ]
      },
    );
  }

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    
    final fullPrompt = "${systemPersona ?? _systemInstructionText}\n\n$prompt";

    return _rotateUntilSuccess(
      apiKey: apiKey,
      cancelToken: cancelToken,
      builder: (model) {
        final List<Map<String, dynamic>> parts = images.map((img) => {
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": base64Encode(img)
          }
        }).toList();
        parts.add({"text": fullPrompt});
        return {
          "contents": [{"role": "user", "parts": parts}]
        };
      },
    );
  }

  /// 🛡️ Smart Rotation: Tries multiple model identifiers and API versions (v1, v1beta)
  Future<AiResult> _rotateUntilSuccess({
    required String apiKey,
    required Map<String, dynamic> Function(String model) builder,
    dio.CancelToken? cancelToken,
  }) async {
    final cleanKey = apiKey.trim();
    final settings = Get.find<SettingsController>();
    String? customBaseUrl = settings.getCustomEndpoint(ProviderType.gemini);

    // 🕵️ Auto-detect OpenRouter or GitHub keys used in Gemini provider
    if (cleanKey.startsWith("sk-or-v1-") && (customBaseUrl.isEmpty || !customBaseUrl.contains("openrouter.ai"))) {
      LogService.debug("💡 [Gemini-Hybrid]: Detected OpenRouter key. Auto-routing to OpenRouter endpoint...", tag: 'Gemini');
      customBaseUrl = "https://openrouter.ai/api/v1";
    } else if ((cleanKey.startsWith("ghp-") || cleanKey.startsWith("ghp_") || cleanKey.startsWith("github_")) && 
               (customBaseUrl.isEmpty || !customBaseUrl.contains("inference.ai.azure.com"))) {
      LogService.debug("💡 [Gemini-Hybrid]: Detected GitHub Models key. Auto-routing to GitHub endpoint...", tag: 'Gemini');
      customBaseUrl = "https://models.inference.ai.azure.com";
    }

    // 1. Try Cached model first for speed
    if (_cachedWorkingModel != null) {
      try {
        final body = builder(_cachedWorkingModel!);
        final text = await _executeRequest(body, cleanKey, _cachedWorkingModel!, version: _cachedVersion, cancelToken: cancelToken, customBaseUrl: customBaseUrl);
        return AiResult(description: text, provider: 'Gemini ($_cachedWorkingModel)');
      } catch (_) {
         _cachedWorkingModel = null;
      }
    }

    // 2. Try the "Model Discovery" API first
    LogService.debug("🔍 [Gemini-Discovery]: Starting discovery for Key: ${cleanKey.length > 5 ? cleanKey.substring(0, 5) : cleanKey}...", tag: 'Gemini');
    final discoveredModels = await _discoverAvailableModels(cleanKey, customBaseUrl: customBaseUrl);
    
    if (discoveredModels.isEmpty) {
      LogService.debug("⚠️ [Gemini-Discovery]: No models found via API. Using static fallback list.", tag: 'Gemini');
    }

    final List<String> versions = ["v1beta", "v1"];
    final List<String> candidates = discoveredModels.isNotEmpty ? discoveredModels : _modelCandidates;

    Object? lastError;

    for (final version in versions) {
      for (final model in candidates) {
        try {
          LogService.debug("📡 [Gemini-Rotation]: Requesting ($version) '$model'...", tag: 'Gemini');
          final body = builder(model);
          
          // Debug payload snippet
          final parts = body['contents']?[0]?['parts'] as List?;
          final firstPart = parts != null && parts.isNotEmpty ? parts[0] : null;
          final promptSnippet = firstPart?['text']?.toString() ?? "";
          LogService.debug("📝 [Gemini-Payload]: Prompt snippet: ${promptSnippet.length > 30 ? promptSnippet.substring(0, 30) : promptSnippet}...", tag: 'Gemini');

          final text = await _executeRequest(body, cleanKey, model, version: version, cancelToken: cancelToken, customBaseUrl: customBaseUrl);
          
          _cachedWorkingModel = model;
          _cachedVersion = version;
          LogService.debug("✅ [Gemini-Rotation]: SUCCESS with ($version) '$model'!", tag: 'Gemini');
          
          return AiResult(
            description: text,
            provider: 'Gemini ($model)',
          );
        } catch (e) {
          lastError = e;
          final errorStr = e.toString().toLowerCase();
          
          bool isRetryable = errorStr.contains('404') || 
                            errorStr.contains('not_found') || 
                            errorStr.contains('not found') ||
                            errorStr.contains('المدخلات غير مدعومة') ||
                            errorStr.contains('429') ||
                            errorStr.contains('resource_exhausted') ||
                            errorStr.contains('quota') ||
                            errorStr.contains('سريعة جداً') || // Localized Rate Limit
                            errorStr.contains('رصيدك');      // Localized Quota

          // 🛡️ Stronger Check: If it's our EnterpriseApiException, check the type
          if (e is EnterpriseApiException) {
            if (e.type == ApiErrorType.rateLimit || e.type == ApiErrorType.quota) {
              isRetryable = true;
            }
          }

          if (isRetryable) {
            LogService.debug("⚠️ [Gemini-Rotation]: ($version) '$model' failed with retryable error ($errorStr). Trying next...", tag: 'Gemini');
            continue;
          }

          // If API Key is invalid, stop rotation immediately
          if (errorStr.contains('api key not valid') || errorStr.contains('api_key_invalid') || errorStr.contains('invalid_argument')) {
             LogService.debug("❌ [Gemini-Rotation]: Fatal Error - API Key is invalid. Stopping rotation.", tag: 'Gemini');
             throw Exception("مفتاح الـ API غير صالح. يرجى التأكد من المفتاح أو الرابط المستخدم.");
          }

          // Special Handling: If we get 1201 (Prompt empty), it's likely a proxy expecting a different format
          if (errorStr.contains('1201') || errorStr.contains('prompt cannot be empty')) {
             LogService.debug("💡 [Gemini-Bridge]: Detected 1201 Proxy Error. Retrying with Legacy Format...", tag: 'Gemini');
             try {
                final userText = builder(model)['contents']?.last?['parts']?[0]?['text'] ?? "";
                final legacyBody = {
                  "prompt": { "text": "$_systemInstructionText\n\n$userText" }
                };
                final text = await _executeRequest(legacyBody, cleanKey, model, version: version, cancelToken: cancelToken, customBaseUrl: customBaseUrl);
                return AiResult(description: text, provider: 'Gemini ($model - Legacy Mode)');
             } catch (legacyErr) {
                LogService.debug("❌ [Gemini-Bridge]: Legacy Fallback also failed: $legacyErr", tag: 'Gemini');
             }
          }

          rethrow;
        }
      }
    }

    throw lastError ?? Exception("Gemini rotation failed.");
  }

  /// 🕵️ Discover available models
  Future<List<String>> _discoverAvailableModels(String apiKey, {String? customBaseUrl}) async {
    final cleanKey = apiKey.trim();
    final isOpenRouter = (customBaseUrl != null && customBaseUrl.contains("openrouter.ai")) || cleanKey.startsWith("sk-or-v1-");
    
    String url;
    Map<String, String> headers = {};
    
    if (isOpenRouter) {
      url = "https://openrouter.ai/api/v1/models";
      headers["Authorization"] = "Bearer $cleanKey";
    } else {
      final baseUrl = (customBaseUrl != null && customBaseUrl.isNotEmpty) ? customBaseUrl : "https://generativelanguage.googleapis.com";
      url = "$baseUrl/v1beta/models?key=$cleanKey";
    }
    
    try {
      LogService.debug("🌐 [Gemini-Discovery]: Calling Discovery URL: $url", tag: 'Gemini');
      
      final response = await _apiClient.request(
        url: url,
        method: "GET",
        headers: headers,
        providerName: "gemini",
      );
      
      if (response.statusCode == 200) {
        if (isOpenRouter) {
          final List models = response.data['data'] ?? [];
          final List<String> names = models
              .map((m) => m['id'] as String)
              .where((id) => id.contains('google/gemini'))
              .toList();
          LogService.debug("✅ [Gemini-Discovery-OR]: Found ${names.length} Gemini models on OpenRouter", tag: 'Gemini');
          return names;
        } else {
          final List models = response.data['models'] ?? [];
          final List<String> names = models
              .map((m) => (m['name'] as String).replaceFirst('models/', ''))
              .where((name) => name.contains('gemini'))
              .toList();
          LogService.debug("✅ [Gemini-Discovery-Google]: Found ${names.length} native models", tag: 'Gemini');
          return names;
        }
      }
    } catch (e) {
      LogService.debug("⚠️ [Gemini-Discovery]: Failed to list models: $e", tag: 'Gemini');
    }
    return [];
  }

  Future<String> _executeRequest(Map<String, dynamic> body, String apiKey, String model, {String version = "v1beta", dio.CancelToken? cancelToken, String? customBaseUrl}) async {
    final cleanKey = apiKey.trim();
    
    final isBridge = (customBaseUrl != null && (customBaseUrl.contains("openrouter.ai") || customBaseUrl.contains("inference.ai.azure.com"))) || 
                     cleanKey.startsWith("sk-or-v1-") || cleanKey.startsWith("ghp-") || cleanKey.startsWith("ghp_") || cleanKey.startsWith("github_");
    
    String baseUrl = (customBaseUrl != null && customBaseUrl.isNotEmpty) ? customBaseUrl : "https://generativelanguage.googleapis.com";
    
    // Remove trailing slashes
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    
    String url;
    Map<String, dynamic> finalBody = body;
    Map<String, String> headers = {"Content-Type": "application/json"};

    if (isBridge) {
      // 🚀 Bridge Mode (OpenRouter / GitHub): Convert Gemini format to OpenAI format
      url = baseUrl.contains("/v1") ? "$baseUrl/chat/completions" : "$baseUrl/v1/chat/completions";
      headers["Authorization"] = "Bearer $cleanKey";
      headers["HTTP-Referer"] = "https://smartcontentcreator-d49f2.web.app";
      headers["X-Title"] = "Smart Content Creator";

      final String promptText = _extractTextFromGeminiBody(body);
      
      // Select model with mapping for OpenRouter
      String targetModel = model;
      if (baseUrl.contains("inference.ai.azure.com") && !model.contains("gpt-4o")) {
        targetModel = "gpt-4o";
      } else if (baseUrl.contains("openrouter.ai")) {
        // Map common names to OpenRouter canonical slugs
        final Map<String, String> orMapping = {
          "gemini-1.5-pro": "google/gemini-pro-1.5",
          "gemini-1.5-pro-latest": "google/gemini-pro-1.5",
          "gemini-1.5-flash": "google/gemini-flash-1.5",
          "gemini-1.5-flash-latest": "google/gemini-flash-1.5",
          "gemini-2.0-flash-exp": "google/gemini-2.0-flash-exp:free",
          "gemini-2.0-pro-exp-02-05": "google/gemini-2.0-pro-exp-02-05:free",
          "gemini-pro": "google/gemini-pro",
        };
        
        if (orMapping.containsKey(model)) {
          targetModel = orMapping[model]!;
        } else if (!model.contains("/")) {
          targetModel = "google/$model";
        }
      }

      finalBody = {
        "model": targetModel,
        "messages": [
          {"role": "user", "content": promptText}
        ],
        "temperature": 0.7,
      };
    } else {
      // 💎 Google Native Format
      // Prevent double /v1/ duplication
      final versionPath = baseUrl.contains("/$version") ? "" : "/$version";
      url = "$baseUrl$versionPath/models/$model:generateContent?key=$cleanKey";
      // Ensure no double slashes like ...//v1beta
      url = url.replaceAll("://", "___").replaceAll("//", "/").replaceAll("___", "://");
    }
    
    LogService.debug("🌐 [Gemini-API]: Calling: ${url.replaceFirst(cleanKey, 'HIDDEN_KEY')}", tag: 'Gemini');

    final response = await _apiClient.request(
      url: url,
      method: "POST",
      data: finalBody,
      headers: headers,
      providerName: "gemini",
      cancelToken: cancelToken,
    );
    
    if (response.statusCode == 200) {
      final data = response.data;
      if (isBridge) {
         return data["choices"]?[0]?["message"]?["content"] ?? data.toString();
      }
      
      // Handle both official and proxy responses
      if (data["candidates"] != null) {
        return data["candidates"][0]["content"]["parts"][0]["text"];
      } else if (data["text"] != null) {
        return data["text"];
      }
      return data.toString();
    }
    throw Exception("Gemini Error: ${response.statusCode}");
  }

  String _extractTextFromGeminiBody(Map<String, dynamic> body) {
    try {
      final contents = body['contents'] as List?;
      if (contents == null || contents.isEmpty) return "";
      final lastContent = contents.last;
      final parts = lastContent['parts'] as List?;
      if (parts == null || parts.isEmpty) return "";
      return parts[0]['text'] ?? "";
    } catch (_) {
      return "";
    }
  }

  List<Map<String, dynamic>> _mapHistoryToContents(List<Map<String, String>> history) {
    return history.map((m) => {
      "role": m['role'] == 'user' ? 'user' : 'model',
      "parts": [{"text": m['content']}]
    }).toList();
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try {
      final res = await generateText("hi", apiKey: apiKey);
      return res.description.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<String> generateTextStream(String prompt, {required String apiKey, Uint8List? imageBytes, Uint8List? videoBytes, List<Map<String, String>>? history, String? systemPersona}) async* {
    final res = await generateText(prompt, apiKey: apiKey, history: history, systemPersona: systemPersona);
    yield res.description;
  }

  @override
  Future<List<double>> generateEmbeddings(String text, {required String apiKey, dio.CancelToken? cancelToken}) async {
    return [];
  }

  // --- MISSING METHODS RESTORED ---

  Future<String> generateScript(String topic, {String tone = 'مرح وجذاب', required String apiKey, dio.CancelToken? cancelToken}) async {
    final prompt = "اكتب سيناريو فيديو عن: $topic. النبرة: $tone";
    final res = await generateText(prompt, apiKey: apiKey, cancelToken: cancelToken);
    return res.description;
  }

  Future<String> generateMarketingPlan(String product, {String targetAudience = 'الجمهور العام', required String apiKey, dio.CancelToken? cancelToken}) async {
    final prompt = "ضع خطة تسويقية لـ: $product. الجمهور: $targetAudience";
    final res = await generateText(prompt, apiKey: apiKey, cancelToken: cancelToken);
    return res.description;
  }

  Future<String> generateMarketingContent(String prompt, {required String apiKey, dio.CancelToken? cancelToken}) async {
    final res = await generateText(prompt, apiKey: apiKey, cancelToken: cancelToken);
    return res.description;
  }

  Future<String> suggestViralHooks(String topic, {required String apiKey, dio.CancelToken? cancelToken}) async {
    final res = await generateText("أعطني 10 جمل افتتاحية جذابة عن $topic", apiKey: apiKey, cancelToken: cancelToken);
    return res.description;
  }

  Future<String> generateMarketingAd(String productInfo, {Uint8List? imageBytes, required String apiKey, dio.CancelToken? cancelToken}) async {
    final prompt = "اكتب إعلان تسويقي جذاب لهذا المنتج: $productInfo";
    if (imageBytes != null) {
      final res = await analyzeImage(imageBytes, prompt, apiKey: apiKey, cancelToken: cancelToken);
      return res.description;
    }
    final res = await generateText(prompt, apiKey: apiKey, cancelToken: cancelToken);
    return res.description;
  }
}
