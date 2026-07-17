import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
// استيراد كافة الخدمات والمتحكمات المطلوبة
import '../../services/db_service.dart';
import '../../services/unified_ai_service.dart';
import '../../services/ai_image_generation_service.dart';
import '../../services/gemini_service.dart';
import '../../services/kling_service.dart';
import '../../services/higgsfield_service.dart';
import '../../services/google_veo_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_user_service.dart';
import '../../services/permissions_sync_service.dart';
import '../../services/subscription_service.dart';
import '../../services/activity_log_service.dart';
import '../../services/activity_tracking_service.dart';
import '../../services/gatekeeper_service.dart';
import '../../services/referral_service.dart';
import '../../services/ai/google_ai_mode_service.dart';
import '../../services/ai/gemini_audio_service.dart';
import '../../services/ai/gemini_vision_service.dart';
import '../../services/product_memory_service.dart';
import '../../services/ai/vision_product_service.dart';
import '../../services/ai/background_removal_service.dart'; // ✂️ خدمة العزل
import '../../services/ai/scene_director_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/profile_sync_service.dart';
import '../../services/instagram_service.dart';
import '../../services/tiktok_account_service.dart';
import '../../services/media_merge_service.dart';
import '../../services/ai/model_capability_service.dart';
import '../../services/ai/intent_classifier_service.dart';
import '../../services/serpapi_services.dart';
import '../../services/serpapi_master_service.dart';
import '../../services/tiktok_service.dart';
import '../../services/video_pipeline_service.dart';
import '../../services/media/youtube_stream_service.dart';
import '../../services/ai/gemini_director_service.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/api/jina_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/remotion_service.dart';
import '../../services/ai/openrouter_video_service.dart';
import '../../services/telegram_service.dart'; // ✈️ Telegram Integration
import '../../services/global_config_service.dart'; // 🌍 Global Config
import '../../services/back4app_gateway_service.dart'; // ☁️ Back4App AI Gateway
import '../../services/vertex_ai_service.dart';
import '../../services/product_matching_service.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/chat_history_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/permissions_controller.dart';
import '../../controllers/trend_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../controllers/home_dashboard_controller.dart';
import '../../core/services/chat_state_service.dart';
import '../../core/services/chat_brain_service.dart';
import '../../core/data/chat_repository.dart';
import '../../core/services/share_receiver_service.dart';
import '../../ai/chat_task_distributor.dart';

import '../../ai/chat_smart_agent.dart';
import '../../ai/ai_orchestrator.dart';
import '../../services/ai_provider.dart';
import '../../controllers/catalog_controller.dart'; // 🛒 كتالوج Meta

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1️⃣ الخدمات الأساسية فقط (Startup-Critical)
    // نبقي أقل قدر ممكن في الإقلاع لتقليل dropped frames.
    Get.put(SecureStorageService(), permanent: true); // ⚠️ نُقل من SettingsController لدعم التسلسل
    Get.put(DBService(), permanent: true);
    
    // ⚠️ ترتيب الحلقات الحساسة
    Get.put(AuthService(), permanent: true);
    Get.put(FirestoreUserService(), permanent: true); // AuthController يحتاجه

    // 🌍 تسجيل GlobalConfigService فقط إذا Firebase جاهز
    final firebaseOk = Get.find<bool>(tag: 'firebaseInitialized');
    if (firebaseOk) {
      Get.put(GlobalConfigService(), permanent: true); // 🌍 مفاتيح الأدمن
    }
    Get.put(PermissionsSyncService(), permanent: true); // AuthController يحتاجه
    Get.put(PermissionsController(), permanent: true); // AuthController يحتاجه
    Get.put(AuthController(), permanent: true); // Splash/Auth تعتمد عليه مباشرة

    // 2️⃣ Controllers (Deferred)
    Get.put(SettingsController(), permanent: true);
    Get.lazyPut(() => ChatHistoryController(), fenix: true);
    Get.lazyPut(() => HomeController(), fenix: true);
    Get.lazyPut(() => NavigationController(), fenix: true);
    Get.lazyPut(() => ThemeController(), fenix: true);
    Get.lazyPut(() => HomeDashboardController(), fenix: true);
    Get.put(CatalogController(), permanent: true); // 🛒 كتالوج Meta

    // 🧠 Chat Core Services (New Architecture)
    Get.lazyPut(() => ChatStateService(), fenix: true);
    Get.lazyPut(() => ChatRepository(), fenix: true);
    Get.lazyPut(() => ChatBrainService(), fenix: true);
    Get.lazyPut(() => UnifiedAIService(), fenix: true);
    Get.lazyPut(() => ChatTaskDistributor(), fenix: true);

    // 2️⃣ خدمات البنية التحتية الإضافية
    Get.lazyPut(() => FirebaseStorageService(), fenix: true);
    Get.lazyPut(() => ProfileSyncService(), fenix: true);
    Get.lazyPut(() => InstagramService(), fenix: true);
    Get.lazyPut(() => TikTokAccountService(), fenix: true);
    Get.lazyPut(() => TrendController(), fenix: true);
    Get.lazyPut(() => AdminController(), fenix: true);

    // 3️⃣ خدمات الذكاء الاصطناعي التخصصية
    Get.lazyPut(() => GeminiService(), fenix: true);
    Get.lazyPut(() => Back4AppGatewayService(), fenix: true); // ☁️ Back4App AI Gateway (18 keys)
    Get.lazyPut(() => VertexAiService(), fenix: true); // ☁️ Vertex AI Service (via Back4App)
    Get.lazyPut(() => KlingService(), fenix: true);
    Get.lazyPut(() => HiggsfieldService(), fenix: true);
    Get.lazyPut(() => OpenRouterVideoService(), fenix: true);
    Get.lazyPut(() => GoogleVeoService(), fenix: true);
    Get.lazyPut(() => AiImageGenerationService(), fenix: true);
    Get.lazyPut(() => GeminiAudioService(), fenix: true);
    Get.lazyPut(() => GeminiVisionService(), fenix: true);
    Get.lazyPut(() => VisionProductService(), fenix: true);
    Get.lazyPut(() => ProductMemoryService(), fenix: true);
    Get.lazyPut(() => ProductMatchingService(), fenix: true);
    Get.lazyPut(() => BackgroundRemovalService(), fenix: true); // ✂️ Inject Background Service
    Get.lazyPut(() => SceneDirectorService(), fenix: true);
    Get.lazyPut(() => MediaMergeService(), fenix: true);
    Get.lazyPut(() => ModelCapabilityService(), fenix: true);
    
    // 🎬 Video & Media Services (Improved Lazy Loading)
    Get.lazyPut(() => VideoPipelineService(), fenix: true);
    Get.lazyPut(() => GeminiDirectorService(), fenix: true);
    Get.lazyPut(() => FfmpegService(), fenix: true);
    Get.lazyPut(() => RemotionService(), fenix: true);
    Get.lazyPut(() => YoutubeStreamService(), fenix: true);
    
    // 🧬 SerpApi Engine Registration
    Get.lazyPut(() => SerpApiMasterService(), fenix: true);
    Get.lazyPut(() => GoogleLensService(), fenix: true);
    Get.lazyPut(() => GoogleTrendsService(), fenix: true);
    Get.lazyPut(() => YoutubeSearchService(), fenix: true);
    Get.lazyPut(() => AmazonProductService(), fenix: true);
    Get.lazyPut(() => GoogleNewsService(), fenix: true);
    Get.lazyPut(() => GoogleShoppingService(), fenix: true);
    Get.lazyPut(() => GoogleReverseImageService(), fenix: true);
    Get.lazyPut(() => GoogleShortVideosService(), fenix: true);
    Get.lazyPut(() => BingCopilotService(), fenix: true);
    Get.lazyPut(() => GoogleImagesService(), fenix: true);
    Get.lazyPut(() => BingImagesService(), fenix: true);
    Get.lazyPut(() => GoogleSearchService(), fenix: true);
    Get.lazyPut(() => VisualExpansionService(), fenix: true);
    Get.lazyPut(() => GoogleAiModeService(), fenix: true); // 🧠 Added AI Mode

    // 📱 Social & Pipeline Services
    Get.lazyPut(() => TikTokService(), fenix: true);
    Get.lazyPut(() => TelegramService(), fenix: true); // ✈️ Register Telegram Service

    // 4️⃣ المحركات الذكية والعملاء (Agents)
    Get.lazyPut(
      () => IntentClassifierService(Get.find<UnifiedAIService>()),
      fenix: true,
    );
    Get.lazyPut(() => ChatSmartAgent(), fenix: true);
    Get.lazyPut<AIProvider>(() => Get.find<GeminiService>(), fenix: true);
    Get.lazyPut(() => AIOrchestrator(), fenix: true);
    Get.lazyPut(() => ShareReceiverService(), fenix: true);

    // 5️⃣ خدمات ميزات إضافية
    Get.lazyPut(() => SubscriptionService(), fenix: true);
    Get.lazyPut(() => ActivityLogService(), fenix: true);
    Get.lazyPut(() => ActivityTrackingService(), fenix: true); // 📊 User Activity Tracking
    Get.lazyPut(() => GatekeeperService(), fenix: true);
    Get.lazyPut(() => ReferralService(), fenix: true);
    Get.lazyPut(() => JinaService(), fenix: true);

    if (kDebugMode) {
      print("✅ تم حقن كافة خدمات صانع المحتوى الذكي بنجاح");
    }
  }
}
