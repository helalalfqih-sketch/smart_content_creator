import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
// استيراد كافة الخدمات والمتحكمات المطلوبة
import '../../services/db_service.dart';
import '../../services/unified_ai_service.dart';
import '../../services/ai_image_generation_service.dart';
import '../../services/gemini_service.dart';
import '../../services/kling_service.dart';
import '../../services/google_veo_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_user_service.dart';
import '../../services/managed_ai_service.dart';
import '../../services/permissions_sync_service.dart';
import '../../services/subscription_service.dart';
import '../../services/activity_log_service.dart';
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

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1️⃣ المتحكمات والخدمات الأساسية (البنية التحتية)
    // يجب أن تعمل أولاً لأن الجميع يعتمد عليها
    Get.put(SecureStorageService(), permanent: true); // ⚠️ نُقل من SettingsController لدعم التسلسل
    Get.put(DBService(), permanent: true);
    
    // ⚠️ ترتيب الحلقات الحساسة
    Get.put(AuthService(), permanent: true);
    Get.put(FirestoreUserService(), permanent: true); // AuthController يحتاجه
    Get.put(PermissionsSyncService(), permanent: true); // AuthController يحتاجه
    Get.put(PermissionsController(), permanent: true); // AuthController يحتاجه
    Get.put(AuthController(), permanent: true); // الآن آمن، كل متطلباته موجودة
    Get.put(SettingsController(), permanent: true); // سيعمل بأمان لأن AuthController موجود
    
    Get.put(ChatHistoryController(), permanent: true);
    Get.put(HomeController(), permanent: true);
    Get.put(NavigationController(), permanent: true);
    Get.put(ThemeController(), permanent: true);
    Get.put(HomeDashboardController(), permanent: true);

    // 🧠 Chat Core Services (New Architecture)
    Get.put(ChatStateService(), permanent: true);
    Get.put(ChatRepository(), permanent: true);
    Get.put(ChatBrainService(), permanent: true);
    Get.put(UnifiedAIService(), permanent: true);
    Get.put(ChatTaskDistributor(), permanent: true);

    // 2️⃣ خدمات البنية التحتية الإضافية
    Get.put(ManagedAiService(), permanent: true);
    Get.put(FirebaseStorageService(), permanent: true);
    Get.put(ProfileSyncService(), permanent: true);
    Get.put(InstagramService(), permanent: true);
    Get.put(TikTokAccountService(), permanent: true);
    Get.put(TrendController(), permanent: true);
    Get.lazyPut(() => AdminController(), fenix: true);

    // 3️⃣ خدمات الذكاء الاصطناعي التخصصية
    Get.lazyPut(() => GeminiService());
    Get.lazyPut(() => KlingService());
    Get.lazyPut(() => GoogleVeoService());
    Get.lazyPut(() => AiImageGenerationService());
    Get.lazyPut(() => GeminiAudioService(), fenix: true);
    Get.put(GeminiVisionService(), permanent: true);
    Get.put(VisionProductService(), permanent: true);
    Get.put(ProductMemoryService(), permanent: true);
    Get.put(BackgroundRemovalService(), permanent: true); // ✂️ Inject Background Service
    Get.put(SceneDirectorService(), permanent: true);
    Get.lazyPut(() => MediaMergeService(), fenix: true);
    Get.put(ModelCapabilityService(), permanent: true);
    
    // 🎬 Video & Media Services (Improved Lazy Loading)
    Get.lazyPut(() => VideoPipelineService(), fenix: true);
    Get.lazyPut(() => GeminiDirectorService(), fenix: true);
    Get.lazyPut(() => FfmpegService(), fenix: true);
    Get.put(YoutubeStreamService(), permanent: true);
    
    // 🧬 SerpApi Engine Registration
    Get.put(SerpApiMasterService(), permanent: true);
    Get.put(GoogleLensService(), permanent: true);
    Get.put(GoogleTrendsService(), permanent: true);
    Get.put(YoutubeSearchService(), permanent: true);
    Get.put(AmazonProductService(), permanent: true); 
    Get.put(GoogleNewsService(), permanent: true);
    Get.put(GoogleShoppingService(), permanent: true);
    Get.put(GoogleReverseImageService(), permanent: true);
    Get.put(GoogleShortVideosService(), permanent: true);
    Get.put(BingCopilotService(), permanent: true);
    Get.put(GoogleImagesService(), permanent: true);
    Get.put(BingImagesService(), permanent: true);
    Get.put(GoogleSearchService(), permanent: true);
    Get.put(VisualExpansionService(), permanent: true);
    Get.put(GoogleAiModeService(), permanent: true); // 🧠 Added AI Mode

    // 📱 Social & Pipeline Services
    Get.put(TikTokService(), permanent: true);

    // 4️⃣ المحركات الذكية والعملاء (Agents)
    Get.put(IntentClassifierService(Get.find<UnifiedAIService>()), permanent: true);
    Get.put(ChatSmartAgent(), permanent: true);
    Get.lazyPut<AIProvider>(() => Get.find<GeminiService>());
    Get.put(AIOrchestrator(), permanent: true);
    Get.put(ShareReceiverService(), permanent: true);

    // 5️⃣ خدمات ميزات إضافية
    Get.put(SubscriptionService(), permanent: true);
    Get.put(ActivityLogService(), permanent: true);
    Get.put(GatekeeperService(), permanent: true);
    Get.lazyPut(() => ReferralService(), fenix: true);
    Get.put(JinaService(), permanent: true);

    if (kDebugMode) {
      print("✅ تم حقن كافة خدمات صانع المحتوى الذكي بنجاح");
    }
  }
}
