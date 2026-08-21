import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

// Controllers
import '../controllers/chat_history_controller.dart';
import '../controllers/auth_controller.dart';

// Core & Repository
import '../core/data/chat_repository.dart';
import '../core/services/chat_state_service.dart';
import '../core/models/chat_message.dart';
import '../core/models/tiktok_video.dart';

// Services
import '../services/db_service.dart';
import '../services/product_memory_service.dart';
import '../services/ai_backend_router.dart';
import '../services/unified_ai_service.dart';
import '../services/ai/vision_product_service.dart';
import '../services/ai/background_removal_service.dart';
import '../services/ai_image_generation_service.dart';
import '../services/video_pipeline_service.dart';
import '../services/serpapi_services.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_user_service.dart';
import '../screens/subscription_screen.dart';

// Mixins & Helpers
import 'chat_task_distributor.dart';
import 'mixins/agent_search_mixin.dart';
import 'mixins/agent_media_mixin.dart';
import 'mixins/agent_core_mixin.dart';
import 'core/ai_helpers_mixin.dart';
import '../core/utils/error_handler.dart';
import '../ai/core/agent_models.dart';
import '../core/services/log_service.dart';
import '../utils/logger.dart';

/// 🤖 ChatSmartAgent: The modular, mixin-based AI agent.
class ChatSmartAgent extends GetxService
    with AIHelpersMixin, AgentSearchMixin, AgentMediaMixin, AgentCoreMixin {
  // 🎯 Core Dependencies
  ChatStateService get _state => Get.find<ChatStateService>();
  ChatRepository get _repo => Get.find<ChatRepository>();
  DBService get _dbService => Get.find<DBService>();
  ChatHistoryController get _historyController =>
      Get.find<ChatHistoryController>();
  AuthController get _authController => Get.find<AuthController>();
  FirestoreUserService get firestoreUser => Get.find<FirestoreUserService>();

  // 🎬 AI & Media Services
  AiImageGenerationService get imageGenService =>
      Get.find<AiImageGenerationService>();
  VideoPipelineService get videoService => Get.find<VideoPipelineService>();
  VisionProductService get visionProductService =>
      Get.find<VisionProductService>();
  BackgroundRemovalService get bgRemovalService =>
      Get.find<BackgroundRemovalService>();
  FirebaseStorageService get storageService =>
      Get.find<FirebaseStorageService>();

  // 🔎 Discovery Services
  GoogleLensService get lensService => Get.find<GoogleLensService>();
  GoogleTrendsService get trendsService => Get.find<GoogleTrendsService>();
  YoutubeSearchService get youtubeService => Get.find<YoutubeSearchService>();
  AmazonProductService get amazonService => Get.find<AmazonProductService>();
  GoogleNewsService get newsService => Get.find<GoogleNewsService>();
  GoogleShoppingService get shoppingService =>
      Get.find<GoogleShoppingService>();
  GoogleReverseImageService get reverseImageService =>
      Get.find<GoogleReverseImageService>();
  GoogleShortVideosService get shortVideosService =>
      Get.find<GoogleShortVideosService>();
  BingCopilotService get bingService => Get.find<BingCopilotService>();
  GoogleImagesService get imagesService => Get.find<GoogleImagesService>();

  // 🧠 Logic Services
  AIBackendRouter get aiRouter => Get.find<AIBackendRouter>();
  UnifiedAIService get unifiedService => Get.find<UnifiedAIService>();
  ChatTaskDistributor get _taskDistributor => Get.find<ChatTaskDistributor>();
  ProductMemoryService get productMemory => Get.find<ProductMemoryService>();

  // 🔓 Reactive State Getters
  RxList<ChatMessage> get history => _repo.history;
  RxBool get isLoading => _state.isLoading;
  RxInt get activeRequests => _state.activeRequests;
  RxnString get lastAnalyzedProduct => _state.lastAnalyzedProduct;
  RxString get lastSearchQuery => _state.lastSearchQuery;

  // 📊 Trend-Specific State
  RxBool get isSearchingTrends => _state.isSearchingTrends;
  RxList<TikTokVideo> get currentTrendVideos => _state.currentTrendVideos;
  RxnString get latestUploadPath => _state.latestUploadPath;

  // 📝 Agent Local State
  final RxBool isWaitingForProductName = false.obs;
  final RxnString lastGeneratedContent = RxnString(null);
  final RxString pipelineMessage = "".obs;
  final RxDouble pipelineProgress = 0.0.obs;
  final RxString activeActionId = "".obs;

  /// 🆔 الحصول على Firebase UID الحالي للمستخدم (للتتبع)
  String? get firebaseUid => _authController.firebaseUid;

  // 🛡️ Request Cancellation
  dio.CancelToken? _cancelToken;

  /// 🛡️ التحقق من حد الاستخدام البصري (15 صورة مجانية)
  Future<bool> checkVisualLimit() async {
    // 🛡️ حماية الأدمن: المسؤولون لديهم وصول غير محدود
    // 🛡️ SaaS Guard: المشترك النشط دائماً لديه وصول
    if (_authController.isAdmin || _authController.isSubscriptionActive) {
      debugPrint("💎 [ChatSmartAgent] Admin or Premium user detected: Granting full access.");
      return true;
    }

    final uid = _authController.firebaseUid;
    if (uid == null) return true; 

    // للمستخدمين المجانيين، نتحقق من الحد (15 صورة)
    final canPerform = await firestoreUser.canPerformVisualAnalysis(uid);
    if (!canPerform) {
      updateStage(0, 0, "🔒 تم الوصول للحد الأقصى");
      isLoading.value = false;
      
      addAndSaveMessage(ChatMessage.assistant(
        content: "🔒 **لقد استهلكت رصيدك المجاني (15 صورة).**\n\nللاستمرار في استخدام ميزات التحليل الذكي وتوليد الفيديو، يرجى الاشتراك في إحدى باقاتنا المميزة. الدردشة النصية ستبقى مجانية دائماً!",
        actions: [
          {'type': 'subscription', 'label': 'عرض باقات الاشتراك 🚀', 'toolId': 'go_to_subscription'}
        ],
      ).copyWith(state: MessageState.completed));

      // تأخير بسيط قبل الانتقال للشاشة
      Future.delayed(const Duration(seconds: 2), () {
        Get.to(() => const SubscriptionScreen());
      });
      
      return false;
    }
    return true;
  }

  /// 📸 زيادة عداد التحليل البصري
  Future<void> incrementVisualCount() async {
    // 🛡️ حماية الأدمن والمشتركين: لا نحسب استهلاكهم
    if (_authController.isSubscriptionActive) return;

    final uid = _authController.firebaseUid;
    if (uid != null) {
      await firestoreUser.incrementVisualAnalysisCount(uid);
    }
  }

  // 🌉 UI Bridge State
  final RxString currentMode = 'casual_chat'.obs;
  final RxString lastTrendQuery = ''.obs;

  /// 💾 Persistent Update: Add to UI and save to SQLite
  Future<int?> addAndSaveMessage(ChatMessage message) async {
    final sessionId = _historyController.currentSessionId.value;
    return await _repo.addMessage(message, sessionId: sessionId);
  }

  Future<void> updateMessage(String messageId, ChatMessage updatedMsg,
      {int? dbId}) async {
    await _repo.updateMessage(messageId, updatedMsg, dbId: dbId);
  }

  @override
  void onInit() {
    AppLogger.info('ENTERING: ChatSmartAgent.onInit');
    super.onInit();
    // Watch for session changes
    ever(_historyController.currentSessionId, (int? sessionId) {
      if (sessionId != null) {
        _loadExistingSession(sessionId);
      } else {
        clearHistory();
      }
    });
    AppLogger.info('EXITING: ChatSmartAgent.onInit');
  }

  /// 🚀 Entry Point: Sending a message
  Future<void> sendUserMessage(String text,
      {File? image,
      List<File>? images,
      bool analyzeImage = true,
      bool skipHistory = false,
      dio.CancelToken? cancelToken}) async {
    // 🛡️ Initialize CancelToken for this request if not provided
    _cancelToken = cancelToken ?? dio.CancelToken();
    AppLogger.info(
        'ENTERING: sendUserMessage with text: $text, hasImage: ${image != null}');
    try {
      // ✂️ Data Scissor: Limit text length for AI safety
      if (text.length > 4000) text = text.substring(0, 4000);

      if (text.isEmpty && image == null) return;

      // Ensure session exists
      if (_historyController.currentSessionId.value == null) {
        await _historyController
            .createNewSession(text.isNotEmpty ? text : "New Chat");
      }

      // Add User Message to UI and DB (Only if not already added by Orchestrator)
      if (!skipHistory) {
        await addAndSaveMessage(ChatMessage.user(content: text, image: image));
      }

      // 🧠 Persistence: Store the latest image path in the global state
      if (image != null) {
        _state.latestUploadPath.value = image.path;
        AppLogger.info(
            "📸 Agent Context Updated: latestUploadPath = ${image.path}");
      }

      // Step 1: Detect Intent (Only if analyzeImage is true)
      if (analyzeImage) {
        final intentResult = await _taskDistributor.getClassifiedIntent(text,
            image: image, cancelToken: _cancelToken);
        await _smartRouter(intentResult, text,
            image: image, cancelToken: _cancelToken);
      } else {
        await respondNormally(text, cancelToken: _cancelToken);
      }
    } finally {
      AppLogger.info('EXITING: sendUserMessage');
    }
  }

  Future<void> _smartRouter(dynamic intent, String text,
      {File? image, dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: _smartRouter with intent: $intent');
    final intentName = (intent is AIIntentResult)
        ? intent.intent
        : (intent?.toString() ?? 'casual_chat');

    if (intentName != 'TEXT' && intentName != 'casual_chat') {
      switch (intentName) {
        case 'google_lens':
          final effectiveImage = image ??
              (latestUploadPath.value != null
                  ? File(latestUploadPath.value!)
                  : null);
          if (effectiveImage != null) {
            await handleGoogleLens(effectiveImage, cancelToken: cancelToken);
          }
          break;
        case 'google_short_videos':
        case 'trend_search':
        case 'similar_videos':
          await handleGoogleShortVideos(text, cancelToken: cancelToken);
          break;
        case 'google_images':
          await handleVisualInspiration(text,
              image: image, cancelToken: cancelToken);
          break;
        case 'VIDEO_GEN':
        case 'generate_video':
          final effectiveImage = image ?? (latestUploadPath.value != null ? File(latestUploadPath.value!) : null);
          if (effectiveImage != null) {
             final msg = await _taskDistributor.handleImageToVideo(effectiveImage, text);
             await addAndSaveMessage(msg);
          } else {
             final msg = await _taskDistributor.handleTextToVideo(text);
             await addAndSaveMessage(msg);
          }
          break;

        case 'generate_ad':
          final effectiveImage = image ??
              (latestUploadPath.value != null
                  ? File(latestUploadPath.value!)
                  : null);
          if (effectiveImage != null) {
            await handleBrandedAdPipeline(effectiveImage,
                cancelToken: cancelToken);
          } else {
            await handleImageGeneration(text, cancelToken: cancelToken);
          }
          break;
        case 'youtube_search':
          await handleYoutubeSearch(text, cancelToken: cancelToken);
          break;
        case 'amazon_search':
        case 'alibaba_search':
          await handleAmazonSearch(text, cancelToken: cancelToken);
          break;
        case 'expert_research':
        case 'product_analysis':
          await handleExpertResearch(text, cancelToken: cancelToken);
          break;
        case 'google_reverse_image':
          final effectiveImage = image ??
              (latestUploadPath.value != null
                  ? File(latestUploadPath.value!)
                  : null);
          if (effectiveImage != null) {
            await handleGoogleReverseImage(effectiveImage,
                cancelToken: cancelToken);
          }
          break;
        case 'google_news':
          await handleGoogleNews(text, cancelToken: cancelToken);
          break;
        case 'remove_background':
          final effectiveImage = image ??
              (latestUploadPath.value != null
                  ? File(latestUploadPath.value!)
                  : null);
          if (effectiveImage != null) {
            await handleBrandedAdPipeline(effectiveImage,
                cancelToken: cancelToken);
          }
          break;
        case 'google_trends':
          await handleGoogleTrends(text, cancelToken: cancelToken);
          break;
        case 'google_shopping':
          await handleGoogleShopping(text, cancelToken: cancelToken);
          break;
        case 'image_generation':
        case 'generate_creative_image':
          await handleImageGeneration(text, cancelToken: cancelToken);
          break;
        default:
          LogService.warning("Unhandled AI Action: $intentName", tag: 'AGENT');
          await respondNormally(text, cancelToken: cancelToken);
      }
      AppLogger.info('EXITING: _smartRouter (Handled Action)');
      return;
    }

    await respondNormally(text, cancelToken: cancelToken);
    AppLogger.info('EXITING: _smartRouter (Normal Response)');
  }

  Future<void> handleImageGeneration(String prompt,
      {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleImageGeneration with prompt: $prompt');
    isLoading.value = true;
    updateStage(1, 1, "🎨 جاري تخيل وإنشاء الصورة... ✨");
    try {
      final latestPath = _state.latestUploadPath.value;
      final canPreserveProduct = latestPath != null &&
          latestPath.trim().isNotEmpty &&
          File(latestPath).existsSync();

      if (kDebugMode) {
        debugPrint(
            '🖼️ [ImageGen] preserve_product=$canPreserveProduct, latestUploadPath=${latestPath ?? "(null)"}');
      }

      // 🧠 التحقق مما إذا كان الطلب يتطلب تفاعلاً بشرياً (Level 5 Pipeline)
      final bool needsHumanInteraction = prompt.toLowerCase().contains(RegExp(
          r'\b(person|people|woman|man|model|sitting|holding|wearing|standing)\b'));

      final result = canPreserveProduct
          ? (needsHumanInteraction
              ? await imageGenService.generateAdvancedHighFidelityScene(
                  productFile: File(latestPath),
                  userPrompt: prompt,
                  cancelToken: cancelToken,
                )
              : await imageGenService.generateProfessionalProductPhoto(
                  originalImageFile: File(latestPath),
                  prompt: prompt,
                  negativePrompt:
                      'nsfw, nude, naked, erotic, lingerie, sexual, explicit, porn, genitalia, nipples, fetish, underage, child, teen, loli, woman, man, person, people, model',
                  cancelToken: cancelToken,
                ))
          : await imageGenService.generateImage(prompt,
              cancelToken: cancelToken);
      if (result.file != null) {
        final response =
            "✨ تمت عملية التوليد بنجاح! إليك ما قمت بإنشائه لـ: **$prompt**";
        await addAndSaveMessage(
          ChatMessage.assistant(
            content: response,
            type: 'generated_image',
            state: MessageState.completed,
          ).copyWith(
            image: result.file,
            mediaPath: result.file!.path,
          ),
        );
      } else {
        final msg = (result.error != null && result.error!.trim().isNotEmpty)
            ? result.error!.trim()
            : 'تعذر توليد الصورة حالياً. جرّب وصفاً أبسط وأكثر حيادية للمنتج.';
        await addAndSaveMessage(
          ChatMessage.assistant(
            content: msg,
            type: 'generated_image',
            state: MessageState.completed,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError('Image Gen', e);
    } finally {
      isLoading.value = false;
      AppLogger.info('EXITING: handleImageGeneration');
    }
  }

  // ========================================
  // 🌉 UI COMPATIBILITY BRIDGES
  // ========================================

  List<SuggestedAction> get availableSmartActions => [
        SuggestedAction(label: "تحليل المنتج 🔍", toolId: "expert_research"),
        SuggestedAction(label: "بحث يوتيوب 🎬", toolId: "youtube_search"),
        SuggestedAction(label: "أخبار جوجل 📰", toolId: "google_news"),
        SuggestedAction(label: "عزل خلفية ✂️", toolId: "remove_background"),
      ];

  Future<void> handleSuggestedAction(SuggestedAction action, File? image,
      {List<File>? images}) async {
    AppLogger.info(
        'ENTERING: handleSuggestedAction with toolId: ${action.toolId}');
    await handleAction(action.toolId,
        payload: action.parameters.isEmpty
            ? (image?.path ?? "")
            : action.parameters);
    AppLogger.info('EXITING: handleSuggestedAction');
  }

  Future<void> generateCreatorImage(String prompt) async {
    AppLogger.info('ENTERING: generateCreatorImage with prompt: $prompt');
    await imageGenService.generateImage(prompt);
    AppLogger.info('EXITING: generateCreatorImage');
  }

  Future<dynamic> extractProductName(File image) async {
    AppLogger.info('ENTERING: extractProductName');
    try {
      final result = await visionProductService.analyzeImage(image);
      AppLogger.info(
          'EXITING: extractProductName result: ${result.productName}');
      return result.productName;
    } catch (e) {
      AppLogger.info('EXITING: extractProductName with error');
      return null;
    }
  }

  Future<void> searchTrendsForProduct(String name) async {
    AppLogger.info('ENTERING: searchTrendsForProduct with name: $name');
    lastTrendQuery.value = name;
    await handleGoogleTrends(name);
    AppLogger.info('EXITING: searchTrendsForProduct');
  }

  void autoDirectorMode() {
    AppLogger.info('ENTERING: autoDirectorMode');
    history.add(ChatMessage.assistant(
        content:
            "وضع المخرج التلقائي نشط الآن! 🎬✨\nسأقوم بتنسيق المشاهد لك."));
    AppLogger.info('EXITING: autoDirectorMode');
  }

  void forceClearHistory() {
    AppLogger.info('ENTERING: forceClearHistory');
    clearHistory();
    AppLogger.info('EXITING: forceClearHistory');
  }

  Future<String> refineSearchQuery(String descriptiveText,
      {dio.CancelToken? cancelToken}) async {
    try {
      final prompt = """
      Refine this descriptive text into a concise search query (3-5 keywords max) in the original language.
      Input: "$descriptiveText"
      Output ONLY the keywords, no explaination.
      """;
      final res = await aiRouter.generateText(
        prompt: prompt,
        systemPersona: "You are a Search Keyword Optimizer.",
      );
      final result = res['data']?.toString() ?? '';
      return result.trim().replaceAll('"', '').split('\n').first;
    } catch (e) {
      return descriptiveText
          .split(' ')
          .take(5)
          .join(' '); // Fallback to first 5 words
    }
  }

  void cancelCurrentOperation() {
    AppLogger.info('ENTERING: cancelCurrentOperation');

    // 🛑 Cancel Ongoing Dio Requests
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel("User cancelled operation");
      debugPrint("🛑 [ChatSmartAgent]: CancelToken triggered cancellation.");
    }

    isLoading.value = false;
    activeRequests.value = 0;
    AppLogger.info('EXITING: cancelCurrentOperation');
  }

  /// 🚀 Vision Bridge: Pre-analyze image (The Fast Path)
  Future<void> completeWithPreAnalysis({
    required String content,
    required File image,
    List<File>? images,
    required dynamic preResult,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    dio.CancelToken? cancelToken,
  }) async {
    AppLogger.info('ENTERING: completeWithPreAnalysis');
    isLoading.value = true;
    try {
      // Add user message to history
      await addAndSaveMessage(ChatMessage.user(
        content: content,
        image: image,
        replyToId: replyToId,
        replyToContent: replyToContent,
        replyToRole: replyToRole,
      ));

      // Use pre-analyzed product name
      final productName = preResult.detectedProduct ?? "المنتج";
      saveProductToMemory(productName);

      // Perform normal chat or logic-based response
      await respondNormally(content, cancelToken: cancelToken);
    } finally {
      isLoading.value = false;
      AppLogger.info('EXITING: completeWithPreAnalysis');
    }
  }

  // ========================================
  // 🛠️ GLUE METHODS (Public for Mixins)
  // ========================================

  void updateStage(int index, int total, String msg) {
    AppLogger.info('AGENT STAGE UPDATE: [$index/$total] $msg');
    pipelineMessage.value = msg;
    pipelineProgress.value = index / total;
  }

  void saveProductToMemory(String name) {
    AppLogger.info('ENTERING: saveProductToMemory with name: $name');
    _state.lastAnalyzedProduct.value = name;
    _state.lastAnalyzedProduct
        .refresh(); // 🔥 Force UI and components to see the update
    AppLogger.info("✅ Global State Updated: lastAnalyzedProduct = $name");
    AppLogger.info('EXITING: saveProductToMemory');
  }

  void clearHistory() {
    AppLogger.info('ENTERING: clearHistory');
    history.clear();
    _repo.clear();
    _state.resetAll();
    AppLogger.info('EXITING: clearHistory');
  }

  Future<void> saveToDb(String query, String result,
      {String messageType = 'text',
      String? metaData,
      String? productContext}) async {
    AppLogger.info('ENTERING: saveToDb');
    final sessionId = _historyController.currentSessionId.value;
    if (sessionId == null) return;

    // 🧠 Use provided context or fall back to global active product
    final context = productContext ?? lastAnalyzedProduct.value;
    final provider = aiRouter.currentBackend.value;

    await _dbService.logChatMessage(
      provider,
      query,
      result,
      sessionId: sessionId,
      messageType: messageType,
      metaData: metaData,
      productContext: context,
    );

    _historyController.refreshSessions();
    AppLogger.info('EXITING: saveToDb');
  }

  Future<void> _loadExistingSession(int sessionId) async {
    AppLogger.info('ENTERING: _loadExistingSession with id: $sessionId');
    isLoading.value = true;
    try {
      // Reset ephemeral context so previous session state doesn't bleed into this one
      _state.resetSession();
      await _repo.loadSession(sessionId);

      // Best-effort: restore last analyzed product and last uploaded media from this session
      try {
        final lastWithContext = history.lastWhere(
          (m) => (m.productContext ?? '').trim().isNotEmpty,
          orElse: () => ChatMessage.assistant(content: ''),
        );
        final ctx = (lastWithContext.productContext ?? '').trim();
        if (ctx.isNotEmpty) {
          _state.lastAnalyzedProduct.value = ctx;
        }

        // 🔥 NEW [SYNC]: Restore professional search query from ProductMemoryService if available
        final userId = Get.find<AuthController>().firebaseUid ?? 'guest';
        final dbProduct = await productMemory.getLastProduct(userId);
        if (dbProduct != null && dbProduct.searchQuery.isNotEmpty) {
          _state.lastSearchQuery.value = dbProduct.searchQuery;
          debugPrint("🔄 [Session Load]: Restored Global Search Query: ${dbProduct.searchQuery}");
        }

        final lastWithMedia = history.lastWhere(
          (m) => (m.mediaPath ?? '').trim().isNotEmpty,
          orElse: () => ChatMessage.assistant(content: ''),
        );
        final media = (lastWithMedia.mediaPath ?? '').trim();
        if (media.isNotEmpty) {
          _state.latestUploadPath.value = media;
        }
      } catch (_) {}

      // 🚀 استئناف أي مهام فيديو معلقة تلقائياً عند تحميل الجلسة
      resumePendingVideoTasks();
    } catch (e) {
      ErrorHandler.logError('Session Loading', e);
    } finally {
      isLoading.value = false;
      AppLogger.info('EXITING: _loadExistingSession');
    }
  }

  /// 🏗️ Orchestration Bridge: Execute structured tasks
  Future<void> executeTask(dynamic task,
      {bool skipHistory = false, dio.CancelToken? cancelToken}) async {
    AppLogger.info(
        'ENTERING: executeTask with intent: ${task is AiTask ? task.intent : 'Unknown'}');

    if (task is AiTask) {
      final String prompt = task.userText ?? "";
      if (task.suggestedTool != null) {
        // 🚀 BYPASS: If a specific tool is planned, go straight to router
        AppLogger.info(
            '🎯 EXECUTION BYPASS: Using planned tool: ${task.suggestedTool}');
        await _smartRouter(task.suggestedTool!, prompt,
            image: task.mediaFile, cancelToken: cancelToken);
        return;
      }

      if (prompt.isNotEmpty) {
        AppLogger.info('💬 EXECUTION: Responding Normally (No tool)');
        await respondNormally(prompt,
            images: task.images, cancelToken: cancelToken);
      }
    } else {
      final prompt = task.prompt ?? "";
      if (prompt.isNotEmpty) {
        await sendUserMessage(prompt, skipHistory: skipHistory);
      }
    }
    AppLogger.info('EXITING: executeTask');
  }

  /// 👁️ Vision Bridge: Pre-analyze image
  Future<dynamic> preAnalyzeImage(File image,
      {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: preAnalyzeImage');
    final result = await visionProductService.analyzeImage(image,
        cancelToken: cancelToken);
    AppLogger.info('EXITING: preAnalyzeImage');
    return result;
  }

  /// 🍱 Vision Bridge: Joint Analysis
  Future<void> analyzeJointProductAndTemplate(List<File> images,
      {String? userPrompt,
      dynamic preAnalyzedResult,
      dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: analyzeJointProductAndTemplate');
    await handleVisionAnalysis(images.first,
        preAnalyzedResult: preAnalyzedResult, cancelToken: cancelToken);
    AppLogger.info('EXITING: analyzeJointProductAndTemplate');
  }

  /// 🔍 Vision Bridge: Classic Analysis
  Future<void> analyzeProductAndFetchTrends(File image,
      {bool force = false,
      bool skipHistory = false,
      dynamic preAnalyzedResult,
      dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: analyzeProductAndFetchTrends');
    await handleVisionAnalysis(image,
        preAnalyzedResult: preAnalyzedResult, cancelToken: cancelToken);
    AppLogger.info('EXITING: analyzeProductAndFetchTrends');
  }

  /// 🌪️ Viral Video: Generate High-Conversion Script
  Future<Map<String, String>> generateViralVideoScript(String product,
      {dio.CancelToken? cancelToken}) async {
    final systemPrompt = """
    You are an AI Viral Video Ad Generator for TikTok.
    Output ONLY a JSON object with these keys: 
    "hook": A viral hook (Max 5 words), 
    "problem": A pain point question, 
    "reveal": A short product benefit, 
    "brand": A brand shoutout.
    Language: Arabic.
    """;

    final prompt = "Generate a viral script for this product: $product";

    try {
      final res = await aiRouter.generateText(
        prompt: prompt,
        systemPersona: systemPrompt,
      );
      final result = res['data']?.toString() ?? '';
      // Clean result if AI includes markdown code blocks
      final cleanJson =
          result.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(cleanJson);

      return {
        "hook": data["hook"] ?? "انتبه! ⚠️",
        "problem": data["problem"] ?? "تعبت من المونتاج؟",
        "reveal": data["reveal"] ?? "اكتشف الحل الذكي",
        "brand": data["brand"] ?? "Indexes Alstora",
      };
    } catch (e) {
      return {
        "hook": "انتبه! ⚠️",
        "problem": "تعبت من المونتاج؟",
        "reveal": "اكتشف الحل الذكي",
        "brand": "Indexes Alstora",
      };
    }
  }
}
