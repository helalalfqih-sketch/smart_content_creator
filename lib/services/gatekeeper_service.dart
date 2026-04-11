import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/permissions_controller.dart';

/// 🛡️ ميزات النظام المحمية
enum FeatureGate {
  advancedAnalysis, // تحليل الفيديوهات الطويلة أو المعقدة
  unlimitedVideoGen, // توليد فيديو بلا حدود
  videoMotion, // تحريك الصور
  trendsAnalysis, // تحليل الترندات المتقدم
  smartReplier, // الرد الذكي (مجاني حالياً)
}

class GatekeeperService extends GetxService {
  AuthController get _auth => Get.find<AuthController>();

  /// التحقق من إمكانية الوصول لميزة معينة
  bool canAccess(FeatureGate feature) {
    final user = _auth.user;
    final bool isPremium = _auth.isPremium;
    final String role = user?['role'] ?? 'user';

    // 1. Admin always has access
    if (role == 'admin') return true;

    // 2. Feature-specific logic
    switch (feature) {
      case FeatureGate.advancedAnalysis:
      case FeatureGate.unlimitedVideoGen:
      case FeatureGate.videoMotion:
      case FeatureGate.trendsAnalysis:
        return isPremium; // تتطلب اشتراك Premium

      case FeatureGate.smartReplier:
        return true; // متاح للجميع (Freemium)
    }
  }

  /// 🔓 التحقق من صلاحية مخصصة (String based) من المدير
  bool checkPermission(String controlName) {
    try {
      if (Get.isRegistered<PermissionsController>()) {
        final perms = Get.find<PermissionsController>();
        return perms.isVisible(controlName);
      }
    } catch (e) {
      debugPrint("⚠️ Gatekeeper: Error checking permission $controlName: $e");
    }
    return false;
  }

  /// رسالة الترقية (نصية)
  String getUpgradeMessage(FeatureGate feature) {
    switch (feature) {
      case FeatureGate.advancedAnalysis:
        return "⚠️ هذه الميزة تتطلب اشتراك Pro للتحليل المتقدم.";
      case FeatureGate.unlimitedVideoGen:
        return "⚠️ لقد استهلكت رصيدك المجاني. رقي حسابك لتوليد بلا حدود! 🚀";
      case FeatureGate.videoMotion:
        return "⚠️ ميزة تحريك الصور حصرية لمشتركي Pro. 💎";
      case FeatureGate.trendsAnalysis:
        return "⚠️ تحليل الترندات العميق متاح فقط للمشتركين. 📈";
      default:
        return "⚠️ هذه الميزة تتطلب ترقية حسابك.";
    }
  }
}
