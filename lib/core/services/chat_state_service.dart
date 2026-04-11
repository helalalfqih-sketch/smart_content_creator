import 'package:get/get.dart';
import 'package:smart_content_creator/core/models/tiktok_video.dart';

/// 🧠 مدير حالة الشات: يحمل كل المتغيرات المؤقتة (RAM)
class ChatStateService extends GetxService {
  // 1. حالة التحميل والبث
  final RxBool isLoading = false.obs;
  final RxBool isStreaming = false.obs;
  final RxBool isOperationActive = false.obs;
  final RxBool isCancelled = false.obs;

  // 2. سياق المحادثة (المنتجات والبحث)
  final RxnString lastAnalyzedProduct = RxnString(); // المنتج الحالي
  final RxString lastSearchQuery = "".obs; // آخر بحث
  final RxString lastBrandName = "".obs;
  final RxString lastBrandNameEn = "".obs; // For consistency
  final RxString lastModel = "".obs; // For consistency

  // 3. خط إنتاج الفيديو (Progress Pipeline)
  final RxDouble pipelineProgress = 0.0.obs;
  final RxString pipelineMessage = "".obs;

  // 4. Trend Analysis State
  final RxList<TikTokVideo> currentTrendVideos = <TikTokVideo>[].obs;
  final RxString trendSearchStatus = ''.obs;
  final RxBool isSearchingTrends = false.obs;
  final RxInt currentTrendOffset = 0.obs;
  final RxString lastTrendQuery = ''.obs;
  final RxString lastTrendMode = 'general'.obs;
  final RxString lastTrendProductName = ''.obs;

  // 5. Active Requests Counter
  final RxInt activeRequests = 0.obs;

  // 6. Visual Context
  final RxnString latestUploadPath = RxnString();

  void resetAll() => resetSession();

  /// إعادة تعيين الحالة (عند الخروج أو بدء محادثة جديدة)
  void resetSession() {
    lastAnalyzedProduct.value = null;
    lastSearchQuery.value = "";
    lastBrandName.value = "";
    lastBrandNameEn.value = "";
    lastModel.value = "";
    pipelineProgress.value = 0.0;
    pipelineMessage.value = "";
    isLoading.value = false;
    isStreaming.value = false;
    isOperationActive.value = false;
    isCancelled.value = false;
    activeRequests.value = 0;

    // Reset trends
    currentTrendVideos.clear();
    trendSearchStatus.value = '';
    isSearchingTrends.value = false;
    currentTrendOffset.value = 0;
    lastTrendQuery.value = '';
    lastTrendMode.value = 'general';
    lastTrendProductName.value = '';
  }

  /// تحديث مرحلة الإنتاج (للفيديو والصور)
  void updatePipeline(String message, double progress) {
    pipelineMessage.value = message;
    pipelineProgress.value = progress;
  }
}
