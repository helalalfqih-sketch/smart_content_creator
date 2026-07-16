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
import 'core/agent_router.dart';
import 'core/agent_feature_flags.dart';
import 'core/agent_models.dart';
import 'memory/agent_memory.dart';
import '../services/ai_provider.dart';
import '../services/api/jina_service.dart';
import '../utils/logger.dart';

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

  late final AgentRouter _agentRouter;

  @override
  void onInit() {
    AppLogger.info('ENTERING: onInit');
    super.onInit();
    // Initialize Agent System (V2)
    _agentRouter = AgentRouter(
      aiProvider: Get.find<AIProvider>(),
      memory: AgentMemory(),
    );
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

      // 🔥 [Race Condition Fix]: إذا كان هناك صور، يجب تحليلها أولاً قبل بناء السياق
      // لضمان استخراج اسم المنتج وحفظه في الذاكرة.
      dynamic preAnalyzedResult;
      if (images != null && images.isNotEmpty) {
        debugPrint(
            "🧠 AIOrchestrator: Image detected, forcing pre-analysis before context build...");
        _agent.isLoading.value = true;
        _agent.pipelineMessage.value = "جاري التعرّف على تفاصيل   👁️";
        preAnalyzedResult =
            await preAnalyze(images.first, cancelToken: cancelToken);
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

        // تجنب استخراج الروابط الداخلية أو غير المرغوب فيها
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
            // ✅ النجاح: دمج البيانات المستخرجة
            prompt = "$prompt\n\n[بيانات المنتج من الرابط]:\n$cleanContent";
            debugPrint("✅ AIOrchestrator: URL content extracted and injected.");
          } else {
            // 🛡️ [Silent Fallback]: فشل الاستخراج، الاعتماد على تخمين Gemini للرابط
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
          // إذا كان الإجبار مفعلاً، نقوم بتفريغ المعرف الحالي لضمان إنشاء جلسة جديدة كلياً
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
        await Future.delayed(
            const Duration(milliseconds: 100)); // Slightly longer delay
        debugPrint(
            "🧠 AIOrchestrator: New Session ID: ${_historyController.currentSessionId.value}");
      }

      final currentSessionId = _historyController.currentSessionId.value;
      debugPrint("🧠 AIOrchestrator: Using Session: $currentSessionId");

      // 🆕 2. إضافة رسالة المستخدم للسجل والواجهة (إخفاء بيانات السحب من الواجهة)
      final String uiContent = (text == null || text.trim().isEmpty)
          ? (image != null ? 'صورة' : (video != null ? 'فيديو' : 'نص'))
          : text;

      final bool alreadyAdded = _agent.history.any((m) =>
          m.role == 'user' &&
          m.content == uiContent &&
          (m.mediaPath == (image?.path ?? video?.path)));

      if (!alreadyAdded) {
        debugPrint("🧠 AIOrchestrator: Adding message to repository...");
        await _repo.addMessage(
          ChatMessage.user(
            content: uiContent, // 👈 عرض النص الأصلي فقط للمستخدم
            image: image,
            images: images, // 📸 Pass the full list to history
            mediaPath: image?.path ?? video?.path,
            type: image != null ? 'image' : (video != null ? 'video' : 'text'),
            replyToId: replyToId,
            replyToContent: replyToContent,
            replyToRole: replyToRole,
            productContext: context.explicitProductName,
          ),
          sessionId: currentSessionId,
        );
      } else {
        debugPrint(
            "🧠 AIOrchestrator: Message already in history, skipping duplicate.");
      }

      _agent.pipelineMessage.value = "🧠 المنسق الذكي يفكر في طلبك...";
      _agent.isLoading.value = true;

      // PHASE 0: Agent System Interceptor (V2 Flow)
      if (AgentFeatureFlags.mockModeEnabled ||
          AgentFeatureFlags.architectureValidationEnabled) {
        final agentRequest = AgentRequest(
          userMessage: prompt,
          userId: userId,
          activePlatform: 'alibaba',
        );

        final result = await _agentRouter.route(agentRequest);

        // Check if the agent actually handled the request
        if (result.data != "AGENT_NOT_HANDLED" &&
            result.data != "AGENT_SYSTEM_DISABLED") {
          // 1️⃣ VALIDATION MODE (LOG ONLY): Ensure it never blocks or returns
          if (AgentFeatureFlags.architectureValidationEnabled) {
            debugPrint(
                "🔬 [ARCHITECTURE_VALIDATION] Captured Agent Result: ${result.type}");
            debugPrint("🔬 Reasoning: ${result.reasoning}");
            // No return here! Legacy pipeline will continue if mockMode is off.
          }

          // 2️⃣ MOCK MODE (EXECUTION PATH): Actually shows UI and halts pipeline
          if (AgentFeatureFlags.mockModeEnabled) {
            debugPrint("🚀 [MOCK_MODE] Executing Agent UI Flow");

            await _repo.addMessage(
              ChatMessage.assistant(
                content: result.reasoning ?? "جاري عرض النتائج...",
                agentResult: result,
                state: MessageState.completed,
                productContext: context.productName,
              ),
              sessionId: _historyController.currentSessionId.value,
            );

            _agent.isLoading.value = false;
            _agent.pipelineMessage.value = "";
            AppLogger.info('EXITING: processUserInput (Via Agent Router)');
            return; // STOP execution of legacy pipeline in Mock Mode
          }
        }
      }

      // 🆕 2. اكتشاف المنتج تلقائياً (دعم الـ Batch والزر الذهبي)
      if (images != null && images.isNotEmpty) {
        if (images.length >= 3 && prompt.trim().isEmpty) {
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
              cancelToken: cancelToken);
          _agent.isLoading.value = false;
          _agent.pipelineMessage.value = "";
          AppLogger.info('EXITING: processUserInput (Batch Analysis)');
          return;
        } else if (images.length == 2) {
          // 🍱 [Full Meal Recovery]: Joint Vision for Product + Template
          // نفعله دائماً عند وجود صورتين لضمان عدم التشتت بين المنتج والقالب
          _agent.pipelineMessage.value =
              "جاري استيعاب (المنتج + القالب) في وجبة واحدة... 🍱";
          await _agent.analyzeJointProductAndTemplate(images,
              userPrompt: prompt,
              preAnalyzedResult: preAnalyzedResult,
              cancelToken: cancelToken);

          // إذا كان هناك نص مع الصورتين، سنكمل للـ Classifier لاحقاً إذا لزم الأمر،
          // ولكن غالباً الـ analyzeJoint سيتكفل بالبداية الصحيحة.
          if (prompt.trim().isEmpty) {
            _agent.isLoading.value = false;
            _agent.pipelineMessage.value = "";
            AppLogger.info('EXITING: processUserInput (Joint Vision)');
            return;
          }
        } else if (prompt.trim().isEmpty) {
          // صورة واحدة فقط وبدون نص -> تحليل كلاسيكي
          _agent.pipelineMessage.value = "جاري تحليل المنتج... 🔍";
          await _agent.analyzeProductAndFetchTrends(
            images.first,
            force: true,
            preAnalyzedResult: preAnalyzedResult,
            skipHistory: true,
            cancelToken: cancelToken,
          );
          _agent.isLoading.value = false;
          _agent.pipelineMessage.value = "";
          AppLogger.info('EXITING: processUserInput (Classic Analysis)');
          return;
        }
      }

      // ⚡ Fast Path: تحيات بسيطة — تجنب smartClassify بالكامل
      if (_isSimpleGreeting(prompt)) {
        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        await _agent.sendUserMessage(prompt,
            skipHistory: true, cancelToken: cancelToken);
        AppLogger.info('EXITING: processUserInput (Simple Greeting)');
        return;
      }

      // ⚡ Fast Path: إزالة الخلفية المباشر (Direct Background Removal)
      // 🪚 Normalize Arabic text to catch typos (ة -> ه, إ/أ -> ا)
      final normalizedText = prompt
          .toLowerCase()
          .replaceAll('ة', 'ه')
          .replaceAll('أ', 'ا')
          .replaceAll('إ', 'ا')
          .replaceAll('آ', 'ا');

      if (normalizedText.contains('ازاله الخلفيه') ||
          normalizedText.contains('مسح الخلفيه') ||
          normalizedText.contains('حذف الخلفيه') ||
          normalizedText.contains('بدون خلفيه') ||
          normalizedText.contains('شيل الخلفيه') ||
          normalizedText.contains('امسح الخلفيه') ||
          normalizedText.contains('تفريغ الخلفيه')) {
        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        debugPrint("🚀 [Intent Detected]: Fast-Path Remove Background");
        await _agent.handleAction('remove_background',
            payload: context.productName, cancelToken: cancelToken);
        AppLogger.info(
            'EXITING: processUserInput (Background Removal Fast-Path)');
        return;
      }

      // ⚡ Fast Path: محادثة قصيرة جداً (Optimization) — تجنب المخطط للدردشة البسيطة
      // ⚡ Fast Path: محادثة قصيرة جداً أو سياقية (Optimization) — تجنب المخطط للدردشة البسيطة
      final wordCount = prompt.trim().split(RegExp(r'\s+')).length;
      final isContextual = _isContextualReply(normalizedText);

      if ((wordCount < 5 || isContextual) &&
          !_isTechnicalRequest(normalizedText) &&
          images == null &&
          video == null) {
        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        debugPrint(
            "🚀 [Optimization]: Contextual/Short Fast-Path (WordCount: $wordCount, Contextual: $isContextual)");
        await _agent.respondNormally(prompt, cancelToken: cancelToken);
        AppLogger.info('EXITING: processUserInput (Contextual Optimization)');
        return;
      }

      // 1️⃣ PHASE 1: THINK & PLAN
      final analysis = await _classifier.smartClassify(prompt,
          context: context, cancelToken: cancelToken);

      if (analysis['source'] == 'local_fallback') {
        _agent.pipelineMessage.value =
            "⚠️ (نمط الاحتياط) جاري استخدام التحليل المحلي...";
      }

      final String intentKey = analysis['intent']?.toString() ?? 'chat';
      final bool isNaturalChat = intentKey == 'TEXT' ||
          intentKey == 'chat' ||
          intentKey == 'casual_chat';

      // 🔓 [解放 (liberation)]: If it's natural chat, bypass strict planning/clarification checks.
      // We only enforce strict planning for technical tools (Video/Search/Analysis).
      if (isNaturalChat && images == null && video == null) {
        await _agent.respondNormally(prompt, cancelToken: cancelToken);
        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        AppLogger.info('EXITING: processUserInput (Natural Conversation Path)');
        return;
      }

      // 🔓 [解放 (liberation)]: Absolute Fix - Zero Blocking.
      // We process everything. If there's a plan, we execute it.
      // If no steps or low confidence, we fall back to normal chat.

      AiPlan plan = _buildPlan(analysis);
      plan = await _reflectAndRefinePlan(plan, context);

      final double confidence = (analysis['confidence'] ?? 0.0).toDouble();

      // IF No Plan OR Low Confidence OR Natural Chat -> Just Respond Normally
      if (plan.steps.isEmpty ||
          (confidence < 0.6 && !isNaturalChat) ||
          isNaturalChat) {
        debugPrint(
            "💬 [Orchestrator]: Falling back to Normal Chat (No plan or low confidence)");
        await _agent.respondNormally(prompt, cancelToken: cancelToken);
        _agent.isLoading.value = false;
        _agent.pipelineMessage.value = "";
        AppLogger.info('EXITING: processUserInput (Direct Chat Path)');
        return;
      }

      // 3️⃣ PHASE 3: EXECUTE
      if (plan.steps.length > 1) {
        await _executeMultiStepPlan(
            plan, context, images, video, analysis['product_name'],
            cancelToken: cancelToken);
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
          // Alternative negotiation as a fallback
          await _negotiateAlternatives(
            intentKey: intentKey,
            userGoal: analysis['user_goal'],
            feasibility: feasibility,
            reasoning: analysis['reasoning'],
            userMessage: prompt,
            context: context,
            cancelToken: cancelToken,
          );
        }
      }

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

  Future<void> _negotiateAlternatives({
    required String intentKey,
    String? userGoal,
    required String feasibility,
    String? reasoning,
    required String userMessage,
    required AppContext context,
    dio.CancelToken? cancelToken,
  }) async {
    AppLogger.info('ENTERING: _negotiateAlternatives for intent: $intentKey');
    final negotiationPrompt = """
    User Request: "$userMessage"
    Goal: ${userGoal ?? 'Unknown'}
    Intent: $intentKey
    Feasibility: $feasibility
    Reasoning: ${reasoning ?? 'Limited capability'}
    Identify alternatives in Arabic for the Smart Content Creator app.
    """;
    final response = await _unifiedAi.generateText(negotiationPrompt,
        systemPersona: "You are a helpful AI Strategist.",
        cancelToken: cancelToken);
    _agent.history.add(ChatMessage.assistant(
      content: response,
      productContext: _agent.lastAnalyzedProduct.value,
    ).copyWith(
      state: MessageState.completed,
    ));
    AppLogger.info('EXITING: _negotiateAlternatives');
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

  /// ⚡ كشف سريع للتحيات البسيطة لتجنب smartClassify
  bool _isSimpleGreeting(String text) {
    final lower = text.trim().toLowerCase();
    const greetings = [
      'مرحبا',
      'هلا',
      'سلام',
      'هاي',
      'صباح الخير',
      'مساء الخير',
      'صباح الورد',
      'مساء الورد',
      'hello',
      'hi',
      'hey',
      'salam',
      'اهلا',
      'أهلا',
      'أهلاً',
      'مراحب',
      'السلام عليكم',
    ];
    final result = greetings.contains(lower) ||
        (lower.length <= 6 && greetings.any((g) => lower.contains(g)));
    AppLogger.info('EXITING: _isSimpleGreeting result: $result');
    return result;
  }

  /// 🛡️ فحص إذا كان الطلب يتطلب أدوات تقنية (Searching for Keywords)
  bool _isTechnicalRequest(String text) {
    final technicalKeywords = [
      'اعلان',
      'إعلان',
      'بحث',
      'تريند',
      'وصف',
      'فيديو',
      'صورة',
      'صوره',
      'صمم',
      'ارسم',
      'حلل',
      'تخيل',
      'لوجو',
      'شعار',
      'انمي',
      'كرتون',
      'بكم',
      'سعر',
      'السعر'
    ];
    return technicalKeywords.any((k) => text.toLowerCase().contains(k));
  }

  /// 🧠 كشف الردود السياقية القصيرة (نعم، أكمل، لا، إلخ)
  bool _isContextualReply(String text) {
    final lower = text.trim().toLowerCase();
    final contextualKeywords = [
      'نعم',
      'أجل',
      'ايوه',
      'أيوة',
      'تم',
      'تمام',
      'ماشي',
      'موافق',
      'اوكي',
      'ok',
      'لا',
      'كلا',
      'بلاش',
      'أكمل',
      'كمل',
      'استمر',
      'واصل',
      'بعدين',
      'غيره',
      'شي ثاني',
      'أخر',
      'آخر',
      'فهمت',
      'وضحت',
      'شكرا',
      'يسلمو',
    ];
    return contextualKeywords.contains(lower) ||
        (lower.length <= 10 && contextualKeywords.any((k) => lower == k));
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
}
