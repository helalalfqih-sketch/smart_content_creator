import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'ai_decision_engine.dart';
import 'chat_smart_agent.dart';
import '../services/product_memory_service.dart';
import '../services/db_service.dart';
import '../services/ai/intent_classifier_service.dart';
import '../services/unified_ai_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/chat_history_controller.dart';
import '../core/models/chat_message.dart';
import '../core/data/chat_repository.dart';
import 'models/app_context.dart';
import 'core/agent_models.dart';
import '../services/api/jina_service.dart';
import '../services/ai_backend_router.dart';
import 'core/ai_constants.dart';
import '../utils/logger.dart';

/// 🧭 نمط تنفيذ طلب الذكاء الاصطناعي (Deterministic Execution Modes)
enum ExecutionMode {
  directText,
  directMultimodal,
  workflowMultimodal,
  agentMode,
}

/// 🧠 AIOrchestrator: المنسق الاستراتيجي (Strategic Planning Agent).
/// يطبق مفهوم "Reasoning Loop" المتقدم: [Think → Plan → Validate → Execute].
class AIOrchestrator extends GetxService {
  final ChatSmartAgent _agent = Get.find<ChatSmartAgent>();
  final ProductMemoryService _productMemory = Get.find<ProductMemoryService>();
  final AuthController _auth = Get.find<AuthController>();
  final IntentClassifierService _classifier =
      Get.find<IntentClassifierService>();
  final UnifiedAIService _unifiedAi = Get.find<UnifiedAIService>();
  final ChatHistoryController _historyController =
      Get.find<ChatHistoryController>();
  final ChatRepository _repo = Get.find<ChatRepository>();

  @override
  void onInit() {
    AppLogger.info('ENTERING: onInit');
    super.onInit();
    AppLogger.info('EXITING: onInit');
  }

  /// 🎯 سجل القدرات الديناميكي
  final Map<String, bool> _capabilities = {
    'video_gen': true,
    'image_gen': true,
    'trend_search': true,
    'product_analysis': true,
    'ad_writing': true,
    'chat': true,
    'google_lens': true,
    'google_trends': true,
    'youtube_search': true,
    'amazon_search': true,
    'google_news': true,
    'google_shopping': true,
    'google_reverse_image': true,
    'google_short_videos': true,
    'direct_tiktok_link': true,
    'web_search': true,
  };

  /// بناء السياق مع دمج ذاكرة المنتج اللحظية + آخر الرسائل
  Future<AppContext> _buildContext() async {
    AppLogger.info('ENTERING: _buildContext');
    final userId = _auth.firebaseUid ?? 'guest';
    final lastProduct = await _productMemory.getLastProduct(userId);

    // 🔥 جلب اسم المنتج من الذاكرة اللحظية للعميل الذكي (لضمان السرعة قبل الـ DB)
    var currentSessionProduct = _agent.lastAnalyzedProduct.value;

    // 🆕 [SYNC]: If memory is null but DB has a product, sync it back to memory
    if (currentSessionProduct == null && lastProduct != null) {
      currentSessionProduct = lastProduct.productName;
      _agent.lastAnalyzedProduct.value = currentSessionProduct;

      // 🔥 Restore the professional English search query to maintain search quality across restarts
      if (lastProduct.searchQuery.isNotEmpty) {
        _agent.lastSearchQuery.value = lastProduct.searchQuery;
      }

      debugPrint(
          "🔄 [Context Sync]: Restored Product ($currentSessionProduct) and SearchQuery from DB");
    }

    // 🆕 جلب آخر 3 رسائل من الجلسة الحالية للسياق
    List<Map<String, dynamic>> recentMessages = [];
    final sessionId = _historyController.currentSessionId.value;
    if (sessionId != null) {
      final dbService = Get.find<DBService>();
      recentMessages = await dbService.getLastMessages(
        sessionId: sessionId,
        limit: 3,
      );
    }

    final context = AppContext(
      lastProduct: lastProduct,
      explicitProductName: currentSessionProduct, // ✅ حقن المنتج اللحظي
      activeScreen: Get.currentRoute,
      recentMessages: recentMessages, // 🆕 آخر 3 رسائل
    );
    AppLogger.info(
        'EXITING: _buildContext with context: ${context.productName}');
    return context;
  }

  /// 🚀 دورة حياة الـ Agent المتقدمة (Reasoning & Planning Loop)
  Future<void> processUserInput({
    String? text,
    List<File>? images,
    File? video,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    bool forceNewSession = false,
    dio.CancelToken? cancelToken,
  }) async {
    AppLogger.info(
        'ENTERING: processUserInput with text: $text, images: ${images?.length}, video: ${video != null}');
    try {
      final image = (images != null && images.isNotEmpty) ? images.first : null;
      debugPrint(
          "🧠 AIOrchestrator: processUserInput called (text: ${text?.length ?? 0}, images: ${images?.length ?? 0}, hasVideo: ${video != null}, forceNew: $forceNewSession)");

      final userId = _auth.firebaseUid ?? 'guest';

      // 🔥 تصفير الذاكرة اللحظية وحالتها عند إرفاق صورة جديدة لضمان التحليل من الصفر
      if (images != null && images.isNotEmpty) {
        debugPrint(
            "🔄 [Memory Reset]: New image detected! Clearing old memory in orchestrator.");
        await _productMemory.clearProductMemory(userId);
        _agent.lastAnalyzedProduct.value =
            null; // 🧹 تفريغ المتغير اللحظي حتى لا يتسرب السياق القديم
      }

      final context = await _buildContext();

      debugPrint(
          "🧠 AIOrchestrator: User Context Built (${context.activeScreen}, Product: ${context.productName})");

      // 🆕 0. اكتشاف وتحليل الروابط تلقائياً (Jina AI Integration)
      String prompt = text ?? "";
      final isJinaAutoEnabled =
          Get.find<SettingsController>().isJinaEnabled.value;

      if (prompt.isNotEmpty && _containsUrl(prompt) && isJinaAutoEnabled) {
        final rawUrl = _extractUrl(prompt);
        final url = _cleanUrl(rawUrl);

        if (url != null &&
            !url.contains("google.com") &&
            !url.contains("firebaseapp.com")) {
          _agent.pipelineMessage.value =
              "جاري استخراج بيانات المنتج من الرابط... ⛏️";
          _agent.isLoading.value = true;

          final cleanContent =
              await Get.find<JinaService>().fetchCleanContent(url);

          _agent.isLoading.value = false;
          _agent.pipelineMessage.value = "";

          if (cleanContent != null && !cleanContent.startsWith("[ERROR]")) {
            prompt = "$prompt\n\n[بيانات المنتج من الرابط]:\n$cleanContent";
            debugPrint("✅ AIOrchestrator: URL content extracted and injected.");
          } else {
            debugPrint(
                "📡 [Silent Fallback]: Content extraction failed for $url, using raw URL inference.");
            prompt =
                "$prompt\n\n[نظام]: فشل استخراج البيانات برمجياً من الرابط ($url). يرجى تحليل الرابط و 'slug' الخاص به لاستنتاج المنتج والموضوع والرد بناءً على ذلك.";
          }
        }
      }

      // 🆕 1. الضمان الاستباقي لوجود جلسة (Session Creation)
      if (_historyController.currentSessionId.value == null ||
          forceNewSession) {
        debugPrint(
            "🧠 AIOrchestrator: Creating new session (forced: $forceNewSession)...");

        if (forceNewSession) {
          _historyController.currentSessionId.value = null;
        }

        final title = prompt.isNotEmpty
            ? (prompt.length > 30 ? prompt.substring(0, 30) : prompt)
            : (images != null && images.isNotEmpty
                ? (images.length > 1
                    ? 'مجموعة صور 🖼️×${images.length}'
                    : 'تحليل صورة 🖼️')
                : (video != null ? 'تحليل فيديو 🎬' : 'محادثة جديدة'));
        await _historyController.createNewSession(title);
        debugPrint(
            "🧠 AIOrchestrator: New Session ID: ${_historyController.currentSessionId.value}");
      }

      final currentSessionId = _historyController.currentSessionId.value;
      debugPrint("🧠 AIOrchestrator: Using Session: $currentSessionId");

      // 🆕 2. إضافة رسالة المستخدم للسجل والواجهة
      final String uiContent = text?.trim() ?? '';

      final bool alreadyAdded = _agent.history.any((m) =>
          m.role == 'user' &&
          m.content == uiContent &&
          (m.mediaPath == (image?.path ?? video?.path)));

      if (!alreadyAdded) {
        debugPrint("🧠 AIOrchestrator: Adding message to repository...");
        await _repo.addMessage(
          ChatMessage.user(
            content: uiContent,
            image: image,
            images: images,
            mediaPath: image?.path ?? video?.path,
            type: image != null ? 'image' : (video != null ? 'video' : 'text'),
            replyToId: replyToId,
            replyToContent: replyToContent,
            replyToRole: replyToRole,
            productContext: context.explicitProductName,
          ),
          sessionId: currentSessionId,
        );
      }

      _agent.pipelineMessage.value = "🧠 المنسق الذكي يفكر في طلبك...";
      _agent.isLoading.value = true;

      // ⏱️ Start Stopwatch for routing and total execution telemetry
      final routingWatch = Stopwatch()..start();
      final totalWatch = Stopwatch()..start();

      final normalizedText = _normalizeArabic(prompt);
      final mode = _selectExecutionMode(
        prompt: prompt,
        images: images,
        video: video,
        normalizedText: normalizedText,
      );
      routingWatch.stop();

      final routingMs = routingWatch.elapsedMilliseconds;
      debugPrint('[AI_ROUTE] mode=${_modeString(mode)} routing_ms=$routingMs');

      // ──────────────────────────────────────────────────────
      // 🚀 EXECUTION ENGINE: Execute according to selected mode
      // ──────────────────────────────────────────────────────

      // 🅰️ MODE: DIRECT_TEXT (Single LLM Call = 1)
      if (mode == ExecutionMode.directText) {
        // Fast-Path 1: إزالة الخلفية
        if (normalizedText.contains('ازاله الخلفيه') ||
            normalizedText.contains('مسح الخلفيه') ||
            normalizedText.contains('حذف الخلفيه') ||
            normalizedText.contains('بدون خلفيه') ||
            normalizedText.contains('شيل الخلفيه') ||
            normalizedText.contains('امسح الخلفيه') ||
            normalizedText.contains('تفريغ الخلفيه')) {
          _agent.isLoading.value = false;
          _agent.pipelineMessage.value = "";
          debugPrint("🚀 [AI_EXEC] Fast-Path Remove Background");
          await _agent.handleAction('remove_background',
              payload: context.productName, cancelToken: cancelToken);
          totalWatch.stop();
          debugPrint(
              '[AI_CALL] count=1 retries=0 backend=${_getBackend()} total_ms=${totalWatch.elapsedMilliseconds}');
          AppLogger.info(
              'EXITING: processUserInput (Background Removal Fast-Path)');
          return;
        }

        // Fast-Path 2: توليد الصور الصريح
        if (_containsImageGenRequest(normalizedText)) {
          _agent.pipelineMessage.value =
              "جاري تصميم الصورة بالذكاء الاصطناعي... 🎨";
          await _agent.executeTask(
            AiDecisionEngine.createTask(
              prompt,
              context: context,
              overrideIntent: Intent.imageGeneration,
            ),
            skipHistory: true,
            cancelToken: cancelToken,
          );
          _agent.isLoading.value = false;
          _agent.pipelineMessage.value = "";
          totalWatch.stop();
          debugPrint(
              '[AI_CALL] count=1 retries=0 backend=${_getBackend()} total_ms=${totalWatch.elapsedMilliseconds}');
          AppLogger.info('EXITING: processUserInput (Direct Image Gen)');
          return;
        }

        // Fast-Path 3: توليد الفيديو الصريح
        if (_containsVideoGenRequest(normalizedText)) {
          _agent.pipelineMessage.value =
              "جاري إنشاء الفيديو بالذكاء الاصطناعي... 🎬";
          await _agent.executeTask(
            AiDecisionEngine.createTask(
              prompt,
              context: context,
              overrideIntent: Intent.videoGeneration,
            ),
            skipHistory: true,
            cancelToken: cancelToken,
          );
          _agent.isLoading.value = false;
          _agent.pipelineMessage.value = "";
          totalWatch.stop();
          debugPrint(
              '[AI_CALL] count=1 retries=0 backend=${_getBackend()} total_ms=${totalWatch.elapsedMilliseconds}');
          AppLogger.info('EXITING: processUserInput (Direct Video Gen)');
          return;
        }

        // المسار العام للدردشة والنصوص (إعلانات، أوصاف، محادثة، أسئلة): استدعاء AI واحد مباشر
        await _agent.respondNormally(prompt, cancelToken: cancelToken);
        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        totalWatch.stop();
        debugPrint(
            '[AI_CALL] count=1 retries=0 backend=${_getBackend()} total_ms=${totalWatch.elapsedMilliseconds}');
        AppLogger.info('EXITING: processUserInput (Direct Text Path)');
        return;
      }

      // 🅱️ MODE: DIRECT_MULTIMODAL (Single Multimodal Call = 1)
      if (mode == ExecutionMode.directMultimodal) {
        if (prompt.trim().isEmpty) {
          // صورة/صور بدون نص مرفق
          if (images != null && images.length >= 3) {
            _agent.pipelineMessage.value =
                "جاري إجراء تحليل مجمع للمنتج (3D Mode)... 🧊";
            await _agent.executeTask(
              AiDecisionEngine.createTask(
                "تحليل مجمع لهذه الصور",
                images: images,
                context: context,
                overrideIntent: Intent.productDetected,
              ),
              skipHistory: true,
              cancelToken: cancelToken,
            );
          } else if (images != null && images.length == 2) {
            _agent.pipelineMessage.value =
                "جاري استيعاب (المنتج + القالب)... 🍱";
            await _agent.analyzeJointProductAndTemplate(images,
                userPrompt: prompt, cancelToken: cancelToken);
          } else if (images != null && images.isNotEmpty) {
            _agent.pipelineMessage.value = "جاري تحليل المنتج... 🔍";
            await _agent.analyzeProductAndFetchTrends(
              images.first,
              force: true,
              skipHistory: true,
              cancelToken: cancelToken,
            );
          }
        } else {
          // صورة/صور + نص موجه (مثال: صورة + "اكتب وصفاً لهذا المنتج" أو صورتان + "قارن بينهما")
          // استدعاء مباشر لـ multimodal بدون preAnalyze مسبق
          _agent.pipelineMessage.value = "جاري معالجة الصورة والطلب... 👁️";
          await _agent.respondNormally(prompt,
              images: images, cancelToken: cancelToken);
        }

        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        totalWatch.stop();
        debugPrint(
            '[AI_CALL] count=1 retries=0 backend=${_getBackend()} total_ms=${totalWatch.elapsedMilliseconds}');
        AppLogger.info('EXITING: processUserInput (Direct Multimodal Path)');
        return;
      }

      // 🅲 & 🅳 MODES: WORKFLOW_MULTIMODAL & AGENT_MODE (Multi-Step Planning Allowed)
      dynamic preAnalyzedResult;
      if (images != null && images.isNotEmpty) {
        _agent.pipelineMessage.value =
            "جاري استخراج سياق المنتج للعملية... 👁️";
        preAnalyzedResult =
            await preAnalyze(images.first, cancelToken: cancelToken);
      }

      // 1️⃣ PHASE 1: THINK & PLAN عبر LLM
      final analysis = await _classifier.smartClassify(prompt,
          context: context, cancelToken: cancelToken);

      if (preAnalyzedResult != null && preAnalyzedResult.productName != null) {
        analysis['product_name'] ??= preAnalyzedResult.productName;
      }

      if (analysis['source'] == 'local_fallback') {
        _agent.pipelineMessage.value =
            "⚠️ (نمط الاحتياط) جاري استخدام التحليل المحلي...";
      }

      AiPlan plan = _buildPlan(analysis);
      plan = await _reflectAndRefinePlan(plan, context);

      // 2️⃣ PHASE 2: EXECUTE
      if (plan.steps.length > 1) {
        await _executeMultiStepPlan(
          plan,
          context,
          images,
          video,
          analysis['product_name'],
          cancelToken: cancelToken,
        );
      } else {
        final String intentKey = analysis['intent']?.toString() ?? 'chat';
        final String feasibility =
            analysis['feasibility']?.toString() ?? 'full';

        if (_capabilities[intentKey] == true && feasibility == 'full') {
          await _executeSingleStep(
            prompt: prompt,
            intentKey: intentKey,
            images: images,
            video: video,
            context: context,
            analysis: analysis,
            replyToId: replyToId,
            replyToContent: replyToContent,
            replyToRole: replyToRole,
            cancelToken: cancelToken,
          );
        } else {
          await _agent.respondNormally(prompt,
              images: images, cancelToken: cancelToken);
        }
      }

      totalWatch.stop();
      debugPrint(
          '[AI_CALL] count=${plan.steps.isNotEmpty ? plan.steps.length : 1} retries=0 backend=${_getBackend()} total_ms=${totalWatch.elapsedMilliseconds}');
      _agent.isLoading.value = false;
      AppLogger.info('EXITING: processUserInput SUCCESS (Workflow/Agent Path)');

      _agent.isLoading.value = false;
      AppLogger.info('EXITING: processUserInput SUCCESS');
    } catch (e, stackTrace) {
      debugPrint("❌ AIOrchestrator Fatal Error in processUserInput: $e");
      debugPrint(stackTrace.toString());

      _agent.history.add(ChatMessage.assistant(
        content:
            "عذراً، حدث خطأ غير متوقع أثناء معالجة طلبك 😔\n(الرجاء المحاولة مرة أخرى)",
        productContext: _agent.lastAnalyzedProduct.value,
      ).copyWith(
        state: MessageState.error,
      ));
      AppLogger.info('EXITING: processUserInput FATAL ERROR');
    } finally {
      // 🛡️ Global Guard: Always reset loading state regardless of outcome or branch
      _agent.isLoading.value = false;
      _agent.pipelineMessage.value = "";
    }
  }

  AiPlan _buildPlan(Map<String, dynamic> analysis) {
    AppLogger.info('ENTERING: _buildPlan with analysis: ${analysis['intent']}');
    final List<dynamic> stepsJson = analysis['plan'] ?? [];
    final List<AiPlanStep> steps = stepsJson
        .map((s) => AiPlanStep(
              order: s['order'] ?? 0,
              tool: s['tool']?.toString() ?? '',
              description: s['description']?.toString() ?? '',
              parameters: s['params'] ?? {},
            ))
        .toList();

    final plan = AiPlan(
      goal: analysis['user_goal'] ?? 'Execute Request',
      steps: steps,
      confidence: (analysis['confidence'] ?? 0.0).toDouble(),
      reasoning: analysis['reasoning'],
    );
    AppLogger.info('EXITING: _buildPlan with steps: ${plan.steps.length}');
    return plan;
  }

  Future<void> _executeMultiStepPlan(AiPlan plan, AppContext context,
      List<File>? images, File? video, String? extractedProduct,
      {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: _executeMultiStepPlan for goal: ${plan.goal}');
    _agent.pipelineMessage.value = "🚀 جاري تنفيذ خطة العمل: ${plan.goal}";

    for (var step in plan.steps) {
      // 🛑 Cancellation Check: Stop if user pressed cancel/stop button
      if (!_agent.isLoading.value) {
        AppLogger.info('🛑 [CANCELLED]: Stopping multi-step plan execution.');
        break;
      }

      _agent.pipelineMessage.value =
          "جاري معالجة طلبك... (خطوة ${step.order}) 🧠";

      final intent = _mapIntentKey(step.tool);
      if (intent == null) continue;

      final task = AiDecisionEngine.createTask(
        step.description,
        context: context,
        overrideIntent: intent,
        images: images,
        hasImage: images != null && images.isNotEmpty,
        hasVideo: video != null,
        productName: extractedProduct,
      );
      await _agent.executeTask(task,
          skipHistory: true, cancelToken: cancelToken);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    AppLogger.info('EXITING: _executeMultiStepPlan');
  }

  Future<AiPlan> _reflectAndRefinePlan(AiPlan plan, AppContext context) async {
    AppLogger.info('ENTERING: _reflectAndRefinePlan');
    if (plan.steps.isEmpty) return plan;
    bool needsInfo = context.productName == null &&
        plan.steps.any((s) => s.tool == 'video_gen' || s.tool == 'ad_writing');

    if (needsInfo && !plan.steps.any((s) => s.tool == 'product_analysis')) {
      final refinedSteps = [
        const AiPlanStep(
            order: 0,
            tool: 'product_analysis',
            description:
                'تحليل المنتج المكتشف لتوفير سياق أفضل للخطوات التالية'),
        ...plan.steps
      ];
      final refinedPlan = AiPlan(
        goal: plan.goal,
        steps: refinedSteps,
        confidence: plan.confidence,
        reasoning: "تعديل ذاتي: إضافة خطوة تحليل لضمان جودة المخرجات",
      );
      AppLogger.info('EXITING: _reflectAndRefinePlan (Refined)');
      return refinedPlan;
    }
    AppLogger.info('EXITING: _reflectAndRefinePlan (No refinement needed)');
    return plan;
  }

  Future<void> _executeSingleStep({
    required String prompt,
    required String intentKey,
    List<File>? images,
    File? video,
    required AppContext context,
    required Map<String, dynamic> analysis,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    dio.CancelToken? cancelToken,
  }) async {
    AppLogger.info('ENTERING: _executeSingleStep with intent: $intentKey');
    final intent = _mapIntentKey(intentKey);
    final task = AiDecisionEngine.createTask(
      prompt,
      context: context,
      overrideIntent: intent,
      images: images,
      hasImage: images != null && images.isNotEmpty,
      hasVideo: video != null,
      productName: analysis['product_name']?.toString() ?? context.productName,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToRole: replyToRole,
    );
    await _agent.executeTask(task, skipHistory: true, cancelToken: cancelToken);
    AppLogger.info('EXITING: _executeSingleStep');
  }

  Intent? _mapIntentKey(String key) {
    AppLogger.info('ENTERING: _mapIntentKey with key: $key');
    Intent? result;
    switch (key) {
      case 'video_gen':
        result = Intent.videoGeneration;
        break;
      case 'image_gen':
        result = Intent.imageGeneration;
        break;
      case 'trend_search':
        result = Intent.trendRequest;
        break;
      case 'product_analysis':
        result = Intent.productDetected;
        break;
      case 'google_trends':
        result = Intent.googleTrendsRequest;
        break;
      case 'youtube_search':
        result = Intent.youtubeRequest;
        break;
      case 'ad_writing':
        result = Intent.adRequest;
        break;
      case 'chat':
        result = Intent.casualChat;
        break;
      case 'amazon_search':
      case 'alibaba_search':
        result = Intent.amazonRequest;
        break;
      case 'google_shopping':
        result = Intent.shoppingRequest;
        break;
      default:
        result = null;
    }
    AppLogger.info('EXITING: _mapIntentKey result: $result');
    return result;
  }

  Future<void> processSmartAction({
    required String prompt,
    File? image,
    File? video,
    String? aiMode,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    dio.CancelToken? cancelToken,
  }) async {
    AppLogger.info('ENTERING: processSmartAction with prompt: $prompt');
    final context = await _buildContext();
    final task = AiDecisionEngine.createTask(
      prompt,
      hasImage: image != null,
      hasVideo: video != null,
      mediaFile: image ?? video,
      context: context,
      aiMode: aiMode,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToRole: replyToRole,
    );
    await _agent.executeTask(task, skipHistory: true, cancelToken: cancelToken);
    AppLogger.info('EXITING: processSmartAction');
  }

  Future<dynamic> preAnalyze(File image, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: preAnalyze');
    final result =
        await _agent.preAnalyzeImage(image, cancelToken: cancelToken);

    // 🔥 [Sync]: تحديث الحالة اللحظية للعميل فور نجاح التحليل
    if (result != null && result.isProduct && result.productName != null) {
      debugPrint(
          "✅ AIOrchestrator: Pre-analysis success! ProductName: ${result.productName}");
      _agent.saveProductToMemory(result.productName!);
    }

    AppLogger.info('EXITING: preAnalyze');
    return result;
  }

  /// ✍️ توليد وصف تسويقي ذكي تلقائي بناءً على المنتج
  Future<String> generateMarketingDescription({
    required String query,
    bool includeBrand = true,
    dio.CancelToken? cancelToken,
  }) async {
    AppLogger.info('ENTERING: generateMarketingDescription for $query');
    try {
      final prompt = """
اكتب لي وصفاً تسويقياً ذكياً وجذاباً جداً لمنتج: $query.
يجب أن تلتزم بتنسيق الرد بالهيكل التالي بدقة تامة، مع إحاطة كل سطر بعلامة النجمة * لجعله خطاً عريضاً:

*🔴🔥 [اسم المنتج مع عبارة تسويقية جذابة] 🔥🔴*

*هل تبحث عن [سؤال يثير اهتمام الزبون]؟ إليك الحل الأمثل*🤩

*[ضع 4 إلى 5 مميزات للمنتج هنا، بحيث يبدأ كل سطر بعلامة الصح الأخضر ✅ وكل سطر محاط بالنجمة *]*

*💥 [عبارة قوية ومحفزة للشراء]*

*📦 [عبارة تحث على الطلب اليوم]*

*سيتم التوضيح اكثر عن المنتج في الفيديو🎥*

🚨 تحذير هام جداً:
- لا تذكر أي أسعار مطلقاً.
- لا تذكر أي روابط أو أسماء مواقع/متاجر إلكترونية مثل (Amazon، علي بابا، إلخ) مطلقاً. اجعل الوصف عاماً ومناسباً للنشر المباشر.
""";
      final result = await _unifiedAi.generateText(
        prompt,
        systemPersona: "Creative Social Media Marketer",
        cancelToken: cancelToken,
      );

      AppLogger.info('EXITING: generateMarketingDescription');
      return result;
    } catch (e) {
      debugPrint("⚠️ Failed to generate smart description: $e");
      return ""; // Fallback will handle empty string
    }
  }

  /// 🌐 كشف الروابط

  bool _containsUrl(String text) {
    return text.contains("http://") || text.contains("https://");
  }

  /// 📥 استخراج أول رابط من النص
  String? _extractUrl(String text) {
    final RegExp urlRegExp = RegExp(
      r'((https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  /// ✂️ "مقص البيانات" لتنقية الروابط من أدوات التتبع (Deduplication & Privacy)
  String? _cleanUrl(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      // تجريد روابط TikTok والسوشيال ميديا من الباراميترات الزائدة
      if (url.contains('tiktok.com') || url.contains('instagram.com')) {
        return uri.origin + uri.path; // يرجع الرابط الأساسي فقط بدون ?_r=1 الخ
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  // ──────────────────────────────────────────────────────
  // 🧭 Deterministic Local Router Helpers
  // ──────────────────────────────────────────────────────

  /// تنظيف وتوحيد الأحرف العربية للمقارنة الحتمية
  String _normalizeArabic(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي');
  }

  /// تحويل Enum النمط إلى نص للـ Telemetry
  String _modeString(ExecutionMode mode) {
    switch (mode) {
      case ExecutionMode.directText:
        return 'DIRECT_TEXT';
      case ExecutionMode.directMultimodal:
        return 'DIRECT_MULTIMODAL';
      case ExecutionMode.workflowMultimodal:
        return 'WORKFLOW_MULTIMODAL';
      case ExecutionMode.agentMode:
        return 'AGENT_MODE';
    }
  }

  /// جلب اسم المحرك الفعال للـ Telemetry
  String _getBackend() {
    if (Get.isRegistered<AIBackendRouter>()) {
      return Get.find<AIBackendRouter>().currentBackend.value;
    }
    return 'firebase_ai';
  }

  /// كشف حتمي للطلبات متعددة الخطوات (Workflows)
  bool _isMultiStepWorkflowRequest(String text) {
    if (text.isEmpty) return false;

    // 1. تسلسل واضح لعدة أدوات متعاقبة
    const sequenceConnectors = [
      'ثم ابحث',
      'وبعدها ابحث',
      'ثم انشئ',
      'وبعدها انشئ',
      'ثم صمم',
      'وبعدها صمم',
      'ثم اكتب',
      'وبعدها اكتب',
      'ثم اعمل',
      'وبعدها اعمل',
      'ثم حلل',
      'وبعدها حلل',
      'ثم ولد',
      'وبعدها ولد',
      'ثم طلع',
      'وبعدها طلع',
      'ثم سوي',
      'وبعدها سوي',
    ];
    if (sequenceConnectors.any((c) => text.contains(c))) return true;

    // 2. طلب حملة أو خطة شاملة متعددة المنصات
    const campaignKeywords = [
      'حمله تسويقيه شامله',
      'حملة تسويقية شاملة',
      'حمله تسويقيه كامله',
      'حملة تسويقية كاملة',
      'خطه تسويقيه شامله',
      'خطة تسويقية شاملة',
      'لفيسبوك وتيك توك وانستغرام',
      'لفيسبوك وتيك توك وانستقرام',
      'لكل المنصات',
      'لجميع المنصات',
    ];
    if (campaignKeywords.any((k) => text.contains(k))) return true;

    return false;
  }

  /// فحص إذا كان النص يطلب توليد صور بشكل صريح
  bool _containsImageGenRequest(String text) {
    if (text.isEmpty) return false;
    // 1. Direct keyword match (normalized)
    if (AIConstants.imageGenKeywords.any((k) => text.contains(_normalizeArabic(k)))) {
      return true;
    }

    // 2. Flexible Pattern: (creation/action verb) + (image noun)
    final hasImageNoun = text.contains('صوره') ||
        text.contains('صورة') ||
        text.contains('صور') ||
        text.contains('image') ||
        text.contains('photo') ||
        text.contains('picture') ||
        text.contains('pic');

    if (hasImageNoun) {
      const actionVerbs = [
        'انش',
        'اصنع',
        'صنع',
        'اعمل',
        'عمل',
        'ولد',
        'توليد',
        'صمم',
        'تصميم',
        'ارسم',
        'رسم',
        'سوي',
        'سو',
        'كون',
        'تكوين',
        'اريد',
        'ابغي',
        'ابغى',
        'ابي',
        'اعطني',
        'هات',
        'تخيل',
        'create',
        'generate',
        'make',
        'draw',
        'design',
        'render'
      ];
      if (actionVerbs.any((v) => text.contains(v))) return true;
    }

    return false;
  }

  /// فحص إذا كان النص يطلب توليد فيديو بشكل صريح
  bool _containsVideoGenRequest(String text) {
    if (text.isEmpty) return false;
    // 1. Direct keyword match (normalized)
    if (AIConstants.videoGenKeywords.any((k) => text.contains(_normalizeArabic(k)))) {
      return true;
    }

    // 2. Flexible Pattern: (creation/action verb) + (video noun)
    final hasVideoNoun = text.contains('فيديو') ||
        text.contains('فديو') ||
        text.contains('ريلز') ||
        text.contains('مقطع') ||
        text.contains('video') ||
        text.contains('reel') ||
        text.contains('clip');

    if (hasVideoNoun) {
      const actionVerbs = [
        'انش',
        'اصنع',
        'صنع',
        'اعمل',
        'عمل',
        'ولد',
        'توليد',
        'صمم',
        'تصميم',
        'سوي',
        'سو',
        'كون',
        'تكوين',
        'اريد',
        'ابغي',
        'ابغى',
        'ابي',
        'اعطني',
        'هات',
        'تحريك',
        'حرك',
        'create',
        'generate',
        'make',
        'animate'
      ];
      if (actionVerbs.any((v) => text.contains(v))) return true;
    }

    return false;
  }

  /// 🧭 المحدد الحتمي لنمط التنفيذ بدون أي استدعاء خارجي للـ LLM
  ExecutionMode _selectExecutionMode({
    required String prompt,
    required List<File>? images,
    required File? video,
    required String normalizedText,
  }) {
    final hasImages = images != null && images.isNotEmpty;
    final hasVideo = video != null;
    final isMultiStep = _isMultiStepWorkflowRequest(normalizedText);

    // 1. Workflow / Agent Mode (الطلبات المركبة متعددة الخطوات فقط)
    if (isMultiStep) {
      return hasImages
          ? ExecutionMode.workflowMultimodal
          : ExecutionMode.agentMode;
    }

    // 2. Direct Multimodal (صورة واحدة أو عدة صور أو فيديو لطلب محدد)
    if (hasImages || hasVideo) {
      return ExecutionMode.directMultimodal;
    }

    // 3. Direct Text (نص عادي، أسئلة، إعلانات، محادثة)
    return ExecutionMode.directText;
  }
}
