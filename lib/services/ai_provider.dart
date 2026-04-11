import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/models/api_provider.dart';
import '../core/utils/smart_exception.dart';
import '../controllers/settings_controller.dart';
import 'gemini_service.dart';
import 'openai_service.dart';
import 'groq_service.dart';
import 'deepseek_service.dart';
import 'anthropic_service.dart';
import 'kling_service.dart';
import 'managed_ai_service.dart';
import 'azure_openai_service.dart';
import 'ai/google_ai_mode_service.dart';
import '../controllers/auth_controller.dart';

abstract class AIProvider {
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint});
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken});
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken});
  Future<bool> testConnection(String apiKey);
  Stream<String> generateTextStream(String prompt,
      {required String apiKey,
      Uint8List? imageBytes,
      Uint8List? videoBytes, // 📹 Video Support
      List<Map<String, String>>? history,
      String? systemPersona});

  /// 🧠 Generate Embeddings for Vector Search
  Future<List<double>> generateEmbeddings(String text,
      {required String apiKey, dio.CancelToken? cancelToken});
}

class AIProviderFactory {
  static final _gemini = GeminiService();
  static final _openai = OpenAIService();
  static final _groq = GroqService();
  static final _deepseek = DeepSeekService();
  static final _anthropic = AnthropicService();
  static final _azure = AzureOpenAIService();
  static final _github = OpenAIService(
    baseUrl: 'https://models.inference.ai.azure.com',
    defaultModel: 'gpt-4o',
  );
  static final _openrouter = OpenAIService(
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'google/gemini-2.0-flash-001',
  );

  /// 🛡️ Circuit Breaker: مزودات الخدمة المحظورة مؤقتاً بسبب المشاكل التقنية (مثلاً 503)
  static final Map<ProviderType, DateTime> _providerBlackouts = {};

  static const _priorityOrder = [
    ProviderType.gemini,      // 🤖 Gemini First
    ProviderType.openrouter,  // 🌐 OpenRouter Second
    ProviderType.github,      // 🛡️ GitHub Third
    ProviderType.serpapi,
    ProviderType.groq,
    ProviderType.openai,
    ProviderType.deepseek,
    ProviderType.anthropic,
  ];

  /// 🛡️ فحص ما إذا كان المزود في وضع "الحظر المؤقت"
  static bool _isBlackedOut(ProviderType type) {
    if (!_providerBlackouts.containsKey(type)) return false;
    final blackoutEnd = _providerBlackouts[type]!;
    if (DateTime.now().isAfter(blackoutEnd)) {
      _providerBlackouts.remove(type);
      return false;
    }
    return true;
  }

  /// 🛡️ حظر المزود مؤقتاً (مثلاً لمدة 5 دقائق)
  static void _triggerBlackout(ProviderType type) {
    if (kDebugMode) debugPrint("🚨 [Circuit Breaker]: Blacklisting $type for 5 minutes due to 503/Critical failure.");
    _providerBlackouts[type] = DateTime.now().add(const Duration(minutes: 5));
  }

  static AIProvider getServiceByType(ProviderType type) {
    switch (type) {
      case ProviderType.gemini:
        return _gemini;
      case ProviderType.openai:
        return _openai;
      case ProviderType.groq:
        return _groq;
      case ProviderType.deepseek:
        return _deepseek;
      case ProviderType.anthropic:
        return _anthropic;
      case ProviderType.kling:
        return Get.find<KlingService>();
      case ProviderType.azure:
        return _azure;
      case ProviderType.stability:
        throw Exception('Stability AI is for image generation only, not chat');
      case ProviderType.removebg:
        throw Exception('Remove.bg is for background removal only, not chat');
      case ProviderType.custom:
        throw Exception('Custom provider not supported');
      case ProviderType.serpapi:
        return Get.find<GoogleAiModeService>();
      case ProviderType.github:
        return _github;
      case ProviderType.openrouter:
        return _openrouter;
    }
  }

  static Future<(AIProvider, String, ProviderType)> getSmartProvider(
      {bool isVideo = false}) async {
    final settingsController = Get.find<SettingsController>();
    final authController = Get.find<AuthController>();
    final managedAi = Get.find<ManagedAiService>();
    final uid = authController.firebaseUid;

    // 🛑 AI Kill Switch (Personal & Managed)
    if (uid != null) {
      if (await managedAi.isUserBlocked(uid)) {
         throw Exception("❌ تواصل مع الإدارة: تم تعطيل وصولك لخدمات الذكاء الاصطناعي.");
      }
    }

    // 1. Check if the active provider for this CATEGORY has a custom key
    final activeProvider = isVideo
        ? settingsController.getActiveVideoProvider()
        : settingsController.getActiveProvider();

    final activeKey = settingsController.getApiKey(activeProvider);
    final isActiveConnected =
        settingsController.getConnectionStatus(activeProvider);

    bool supportsTask =
        isVideo ? activeProvider.isVideoCapable : activeProvider.isTextCapable;

    if (activeKey.isNotEmpty && isActiveConnected && supportsTask) {
      if (kDebugMode) {
        debugPrint(
            '✅ AIProviderFactory: Using User Custom Key ($activeProvider) for ${isVideo ? "Video" : "Text"}.');
      }
      return (getServiceByType(activeProvider), activeKey, activeProvider);
    }

    // 2. Fallback to Managed Key for the Active Provider of this CATEGORY
    if (kDebugMode) {
      debugPrint(
          '🔍 AIProviderFactory: Checking Managed Fallback for $activeProvider (${isVideo ? "Video" : "Text"})...');
    }

    try {
      final authController = Get.find<AuthController>();
      final managedAi = Get.find<ManagedAiService>();
      final firebaseUid = authController.firebaseUid;

      if (firebaseUid != null && supportsTask) {
        final managedKey = await managedAi.getManagedKey(firebaseUid,
            provider: activeProvider);
        if (managedKey != null && managedKey.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
                '✅ AIProviderFactory: Using Managed Key for $activeProvider.');
          }
          return (getServiceByType(activeProvider), managedKey, activeProvider);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ AIProviderFactory: Managed fallback failed: $e');
      }
    }

    // 3. Fallback to any other connected user provider that SUPPORTS the task
    for (final providerType in _priorityOrder) {
      if (providerType == activeProvider) continue;

      bool innerSupports =
          isVideo ? providerType.isVideoCapable : providerType.isTextCapable;
      if (!innerSupports) continue;

      final key = settingsController.getApiKey(providerType);
      final isConnected = settingsController.getConnectionStatus(providerType);

      if (key.isNotEmpty && isConnected) {
        return (getServiceByType(providerType), key, providerType);
      }
    }

    // 3.5. Try Gemini as a universal fallback for text if nothing else works
    if (!isVideo) {
      final geminiKey = settingsController.getApiKey(ProviderType.gemini);
      if (geminiKey.isNotEmpty) {
        return (
          getServiceByType(ProviderType.gemini),
          geminiKey,
          ProviderType.gemini
        );
      }
    }

    // 4. Last Resort: Quota Exceeded or No Keys
    throw SmartUserException(
      '❌ لقد استنفدت أرصدة الاستخدام اليومية المجانية أو لم يتم تكوين مفتاح API لهذا المزود.',
      isQuotaExceeded: true,
    );
  }

  static Future<AiResult> generateWithFallback(
    ProviderType primaryType,
    String primaryKey,
    String prompt,
    List<(ProviderType, String)>? fallbackProviders, {
    List<Map<String, String>>? history,
    String? systemPersona,
    dio.CancelToken? cancelToken,
  }) async {
    final effectivePersona = systemPersona ??
        '''أنت خبير محتوى وتسويق متخصص. يجب أن تكون جميع الردود باللغة العربية حصراً وبشكل قطعي. ابدأ بالرد فوراً دون مقدمات.''';

    // 🗝️ Hexa-Key Rotation for GitHub
    if (primaryType == ProviderType.github) {
      final settingsController = Get.find<SettingsController>();
      final keys = settingsController.githubKeys;

      if (keys.isNotEmpty) {
        for (int i = 0; i < keys.length; i++) {
          try {
            final service = getServiceByType(ProviderType.github);
            return await service.generateText(
              prompt,
              apiKey: keys[i],
              history: history,
              systemPersona: effectivePersona,
              maxTokens: 800,
              cancelToken: cancelToken,
            );
          } catch (e) {
            final errorStr = e.toString();
            if (errorStr.contains('429') && i < keys.length - 1) {
              if (kDebugMode) debugPrint("🔄 Rate Limit! Waiting 2s before GitHub Hexa-Key #${i + 2}...");
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            if (i == keys.length - 1) break;
          }
        }
      }
    }

    // 🛡️ فحص قاطع الدائرة الاستباقي
    if (_isBlackedOut(primaryType)) {
      if (kDebugMode) debugPrint("🛡️ [Circuit Breaker]: Skipping $primaryType due to active blackout. Falling back immediately...");
      throw Exception("503 (Circuit Breaker Active)");
    }

    try {
      final service = getServiceByType(primaryType);
      return await service.generateText(prompt,
          apiKey: primaryKey,
          history: history,
          systemPersona: effectivePersona,
          cancelToken: cancelToken);
    } catch (e) {
      final errorStr = e.toString();
      if (kDebugMode) debugPrint("⚠️ Primary Provider ($primaryType) failed: $e");

      bool isCriticalFailure = errorStr.contains('503') || errorStr.contains('Service Unavailable');
      
      if (isCriticalFailure) {
        _triggerBlackout(primaryType);
      }

      bool shouldRetryFallback = isCriticalFailure ||
                                 errorStr.contains('429') || 
                                 errorStr.contains('401') || 
                                 errorStr.contains('403') || 
                                 errorStr.contains('Invalid API Key') || 
                                 errorStr.contains('API key');


      if (shouldRetryFallback && fallbackProviders != null && fallbackProviders.isNotEmpty) {
        if (errorStr.contains('429')) {
          if (kDebugMode) debugPrint("⏳ [Retry Protection]: Waiting 2s before trying fallback...");
          await Future.delayed(const Duration(seconds: 2));
        }

        for (final (type, key) in fallbackProviders) {
          try {
            if (_isBlackedOut(type)) continue;
            
            if (kDebugMode) debugPrint("📡 [Resilient Fallback]: Trying $type...");
            final service = getServiceByType(type);
            return await service.generateText(prompt,
                apiKey: key,
                history: history,
                systemPersona: effectivePersona,
                cancelToken: cancelToken);
          } catch (err) {
            if (err.toString().contains('503')) _triggerBlackout(type);
            if (kDebugMode) debugPrint("❌ Fallback to $type failed: $err");
            continue;
          }
        }
      }
      rethrow;
    }
  }

  static Future<AiResult> generateWithSmartFallback(
    String prompt, {
    List<Map<String, String>>? history,
    String? systemPersona,
    dio.CancelToken? cancelToken,
  }) async {
    String safePrompt = prompt;
    const int maxPayloadLimit = 10000;
    if (safePrompt.length > maxPayloadLimit) {
      if (kDebugMode) debugPrint("✂️ AIProviderFactory: Truncating large prompt from ${safePrompt.length} to $maxPayloadLimit...");
      safePrompt = "${safePrompt.substring(0, maxPayloadLimit)}\n\n...[Truncated for safety]...";
    }

    final settingsController = Get.find<SettingsController>();
    final activeProvider = settingsController.getActiveProvider();
    final activeKey = settingsController.getApiKey(activeProvider);

    final bool isPrimaryBlackedOut = _isBlackedOut(activeProvider);

    final fallbackList = _priorityOrder
        .where((p) => p != activeProvider && !_isBlackedOut(p))
        .map((type) => (type, settingsController.getApiKey(type)))
        .where((pair) =>
            pair.$2.isNotEmpty &&
            settingsController.getConnectionStatus(pair.$1))
        .toList();

    if (isPrimaryBlackedOut && fallbackList.isNotEmpty) {
      if (kDebugMode) debugPrint("🛡️ [Smart Fallback]: Primary $activeProvider is blacked out. Auto-switching to ${fallbackList.first.$1}");
      return await generateWithFallback(
        fallbackList.first.$1,
        fallbackList.first.$2,
        safePrompt,
        fallbackList.skip(1).toList(),
        history: history,
        systemPersona: systemPersona,
        cancelToken: cancelToken,
      );
    }

    if (activeKey.isEmpty && fallbackList.isEmpty) {
      try {
        final authController = Get.find<AuthController>();
        final managedAi = Get.find<ManagedAiService>();
        if (authController.firebaseUid != null) {
          final mKey = await managedAi.getManagedKey(authController.firebaseUid,
              provider: activeProvider);
          if (mKey != null) {
            final service = getServiceByType(activeProvider);
            if (activeProvider == ProviderType.azure &&
                service is AzureOpenAIService) {
              final endpoint =
                  settingsController.getCustomEndpoint(ProviderType.azure);
              return await service.generateText(safePrompt,
                  apiKey: mKey,
                  customEndpoint: endpoint,
                  systemPersona: systemPersona,
                  cancelToken: cancelToken);
            }
            return await service.generateText(safePrompt,
                apiKey: mKey,
                systemPersona: systemPersona,
                cancelToken: cancelToken);
          }
        }
      } catch (_) {}

      throw Exception(
        '❌ لم يتم تكوين مفاتيح API لأي مزود. الرجاء إضافة مفاتيح في الإعدادات',
      );
    }

    if (activeKey.isEmpty) {
      return generateWithFallback(fallbackList[0].$1, fallbackList[0].$2,
          safePrompt, fallbackList.skip(1).toList(),
          history: history, cancelToken: cancelToken);
    }

    try {
      return await generateWithFallback(
          activeProvider, activeKey, safePrompt, fallbackList,
          history: history, systemPersona: systemPersona, cancelToken: cancelToken);
    } catch (e) {
      if (e is SmartUserException) rethrow;
      throw SmartUserException('❌ حدث خطأ غير متوقع: $e');
    }
  }

  static Future<AiResult> analyzeWithSmartFallback(
    Uint8List bytes,
    String prompt, {
    List<Map<String, String>>? history,
    int? maxTokens,
    dio.CancelToken? cancelToken,
  }) async {
    final settingsController = Get.find<SettingsController>();
    final authController = Get.find<AuthController>();
    final managedAi = Get.find<ManagedAiService>();
    final uid = authController.firebaseUid;

    if (uid != null) {
      if (await managedAi.isUserBlocked(uid)) {
         throw Exception("❌ تواصل مع الإدارة: تم تعطيل وصولك لخدمات الذكاء الاصطناعي.");
      }
    }
    final activeProvider = settingsController.getActiveProvider();
    
    final visionPriority = _priorityOrder.where((p) => p.isVisionCapable).toList();
    if (activeProvider.isVisionCapable) {
      visionPriority.remove(activeProvider);
      if (activeProvider != ProviderType.gemini && _priorityOrder.first == ProviderType.gemini) {
        visionPriority.insert(1, activeProvider);
      } else {
        visionPriority.insert(0, activeProvider);
      }
    }

    Object? lastError;
    bool had402 = false;

    for (final providerType in visionPriority) {
      try {
        if (providerType == ProviderType.github) {
          final keys = settingsController.githubKeys;
          if (keys.isNotEmpty) {
            for (int i = 0; i < keys.length; i++) {
                try {
                  final service = getServiceByType(ProviderType.github);
                  return await service.analyzeImage(bytes, prompt,
                      apiKey: keys[i],
                      history: history,
                      maxTokens: maxTokens,
                      cancelToken: cancelToken);
                } catch (e) {
                  Object? activeError = e;
                  final errorMsg = e.toString();
                  if (errorMsg.contains('402') && history != null && history.isNotEmpty) {
                    try {
                      final service = getServiceByType(ProviderType.github);
                      return await service.analyzeImage(bytes, prompt,
                          apiKey: keys[i],
                          history: null,
                          maxTokens: maxTokens,
                          cancelToken: cancelToken);
                    } catch (retryErr) {
                      activeError = retryErr;
                    }
                  }

                  if (activeError.toString().contains('429') && i < keys.length - 1) continue;
                  lastError = activeError;
                  throw activeError;
                }
            }
          }
        }

        final key = settingsController.getApiKey(providerType);
        final isConnected = settingsController.getConnectionStatus(providerType);
        
        if (key.isEmpty || !isConnected) continue;

        final service = getServiceByType(providerType);
        try {
          return await service.analyzeImage(bytes, prompt,
              apiKey: key,
              history: history,
              maxTokens: maxTokens,
              cancelToken: cancelToken);
        } catch (e) {
          final errorMsg = e.toString();
          if (errorMsg.contains('402') && history != null && history.isNotEmpty) {
            return await service.analyzeImage(bytes, prompt,
                apiKey: key, history: null, cancelToken: cancelToken);
          }
          rethrow;
        }
      } catch (e) {
        lastError = e;
        if (e.toString().contains('402')) had402 = true;
        continue;
      }
    }

    if (had402) {
      throw SmartUserException(
        "❌ رصيد الاستخدام لهذا المزود غير كافٍ. يرجى شحن رصيدك أو استخدام مزود آخر.",
        isQuotaExceeded: true,
      );
    }

    throw lastError ?? Exception("❌ لم ينجح أي مزود في تحليل الصورة.");
  }

  static Future<AiResult> analyzeBatchWithSmartFallback(
    List<Uint8List> images,
    String prompt, {
    List<Map<String, String>>? history,
    int? maxTokens,
    dio.CancelToken? cancelToken,
  }) async {
    final settingsController = Get.find<SettingsController>();
    final authController = Get.find<AuthController>();
    final managedAi = Get.find<ManagedAiService>();
    final uid = authController.firebaseUid;

    if (uid != null) {
      if (await managedAi.isUserBlocked(uid)) {
         throw Exception("❌ تواصل مع الإدارة: تم تعطيل وصولك لخدمات الذكاء الاصطناعي.");
      }
    }

    final activeProvider = settingsController.getActiveProvider();

    final visionPriority = _priorityOrder.where((p) => p.isVisionCapable).toList();
    if (activeProvider.isVisionCapable) {
      visionPriority.remove(activeProvider);
      if (activeProvider != ProviderType.gemini && _priorityOrder.first == ProviderType.gemini) {
        visionPriority.insert(1, activeProvider);
      } else {
        visionPriority.insert(0, activeProvider);
      }
    }

    Object? lastError;
    for (final providerType in visionPriority) {
      try {
        if (providerType == ProviderType.github) {
          final keys = settingsController.githubKeys;
          if (keys.isNotEmpty) {
            for (int i = 0; i < keys.length; i++) {
              try {
                final service = getServiceByType(ProviderType.github);
                return await service.analyzeBatchImages(images, prompt,
                    apiKey: keys[i],
                    history: history,
                    maxTokens: maxTokens ?? 1200,
                    cancelToken: cancelToken);
              } catch (e) {
                Object? activeError = e;
                if (e.toString().contains('402') && history != null && history.isNotEmpty) {
                  try {
                    return await getServiceByType(ProviderType.github)
                        .analyzeBatchImages(images, prompt,
                            apiKey: keys[i],
                            history: null,
                            maxTokens: maxTokens ?? 1200,
                            cancelToken: cancelToken);
                  } catch (retryErr) { activeError = retryErr; }
                }

                if (activeError.toString().contains('429') && i < keys.length - 1) continue;
                lastError = activeError;
                throw activeError; 
              }
            }
          }
        }

        final key = settingsController.getApiKey(providerType);
        final isConnected = settingsController.getConnectionStatus(providerType);
        if (key.isEmpty || !isConnected) continue;

        try {
          final service = getServiceByType(providerType);
          return await service.analyzeBatchImages(images, prompt,
              apiKey: key,
              history: history,
              maxTokens: maxTokens ?? 1200,
              cancelToken: cancelToken);
        } catch (e) {
          if (e.toString().contains('402') && history != null && history.isNotEmpty) {
            final service = getServiceByType(providerType);
            return await service.analyzeBatchImages(images, prompt,
                apiKey: key,
                history: null,
                maxTokens: maxTokens ?? 1200,
                cancelToken: cancelToken);
          }
          rethrow;
        }
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw lastError ?? Exception("❌ فشل تحليل مجموعة الصور.");
  }
}
