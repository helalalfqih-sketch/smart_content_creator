import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import '../core/storage/storage_keys.dart';
import '../services/marketing_share_service.dart';
import '../screens/brand_settings_screen.dart'; // To access BrandSettingsController
import '../models/brand_info.dart';
import '../ai/core/agent_models.dart';
import 'package:flutter/material.dart';

class MarketingShareController extends GetxController {
  final AppStorageService _storage = Get.find<AppStorageService>();
  final MarketingShareService _shareService = MarketingShareService();

  final RxBool includeBrand = true.obs;
  final RxBool isSharing = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Load persisted preference
    includeBrand.value = _storage.readBool(StorageKeys.includeBrandInShare, defaultValue: true)!;
  }

  void toggleIncludeBrand(bool value) {
    includeBrand.value = value;
    _storage.writeBool(StorageKeys.includeBrandInShare, value);
  }

  /// 🏥 Get current BrandInfo from the BrandSettingsController
  BrandInfo getCurrentBrand() {
    try {
      final brandController = Get.isRegistered<BrandSettingsController>() 
          ? Get.find<BrandSettingsController>() 
          : Get.put(BrandSettingsController());
      
      final identity = brandController.brandIdentity.value;
      if (identity == null) return BrandInfo.empty();

      return BrandInfo(
        name: identity.storeName,
        industry: identity.industry,
        phone: identity.phone,
        website: identity.website,
      );
    } catch (e) {
      debugPrint("⚠️ Could not fetch brand info: $e");
      return BrandInfo.empty();
    }
  }

  /// 🚀 Execute share process
  Future<void> performShare({
    required BuildContext context,
    required List<ImageItem> items,
    bool? overrideIncludeBrand,
    String? overrideDescription,
  }) async {
    if (items.isEmpty) return;

    final shouldIncludeBrand = overrideIncludeBrand ?? includeBrand.value;
    final brand = shouldIncludeBrand ? getCurrentBrand() : null;

    isSharing.value = true;
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚀 جاري تحضير الوصف والصور للمشاركة..."),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Logic: Use override description if provided, otherwise generate one locally
      final description = overrideDescription ?? _shareService.generateProductDescription(
        items.first, 
        brand: brand,
      );


      await _shareService.shareImages(
        items: items,
        text: description,
      );
    } catch (e) {
      String userFriendlyError = "فشل تحميل الصور للمشاركة. يرجى إعادة المحاولة لاحقاً.";
      final errStr = e.toString().toLowerCase();
      if (errStr.contains("socketexception") || 
          errStr.contains("connection failed") || 
          errStr.contains("unreachable") || 
          errStr.contains("clientexception")) {
        userFriendlyError = "فشل الاتصال بالشبكة. يرجى التحقق من اتصالك بالإنترنت وإعادة المحاولة.";
      } else if (errStr.contains("تحميل أي صورة")) {
        userFriendlyError = "فشل تنزيل صورة المنتج للمشاركة. يرجى التحقق من الرابط وإعادة المحاولة.";
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ $userFriendlyError"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      isSharing.value = false;
    }
  }
}
