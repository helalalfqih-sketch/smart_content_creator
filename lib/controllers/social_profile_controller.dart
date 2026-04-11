import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../services/serpapi_services.dart';

class SocialProfileController extends GetxController {
  final SocialProfileService _service = SocialProfileService();
  final SocialInsightScraperService _scraper = SocialInsightScraperService();
  
  final RxMap<String, dynamic> profileData = <String, dynamic>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Future<void> loadProfile(String platform, String profileId) async {
    isLoading.value = true;
    errorMessage.value = '';
    profileData.clear();

    try {
      Map<String, dynamic> data = {};
      
      debugPrint("🔍 LOADING SOCIAL PROFILE => Platform: $platform | ID: $profileId");

      if (platform.toLowerCase() == 'instagram') {
        // 🚀 استخدام خطة الإنقاذ (البحث في قوقل) لإنستقرام لأن SerpApi لا يملك محرك بروفايل مباشر لها
        data = await _scraper.getInstagramInsights(profileId);
      } else if (platform.toLowerCase() == 'facebook') {
        data = await _service.getFacebookProfile(profileId);
      } else {
        data = await _service.getGenericProfile('${platform}_profile', profileId);
      }

      if (data.isNotEmpty && (data.containsKey('name') || data.containsKey('followers'))) {
        profileData.value = data;
      } else {
        debugPrint("⚠️ JSON Profile Engine returned empty or invalid data for $profileId");
        errorMessage.value = 'لم نتمكن من جلب بيانات الحساب حالياً.\n(قد يكون الحساب خاصاً أو غير مدعوم في SerpApi)';
      }
    } catch (e) {
      debugPrint("❌ SocialProfileController Error: $e");
      errorMessage.value = 'حدث خطأ أثناء الاتصال بالخادم.\nتأكد من إعداد SerpApi Key بشكل صحيح.';
    } finally {
      isLoading.value = false;
    }
  }
}
