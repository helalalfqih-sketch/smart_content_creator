import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../../controllers/settings_controller.dart';
import '../../core/models/api_provider.dart';
import '../../core/utils/key_routing_helper.dart';
import '../google_veo_service.dart';
import '../kling_service.dart';

/// 🧠 Model Capability Service
/// المسؤول عن فحص صلاحيات الموديلات المتاحة للمستخدم فعلياً عبر الـ API
class ModelCapabilityService extends GetxService {
  final Map<String, bool> _capabilities = {};

  bool isModelAvailable(String modelId) => _capabilities[modelId] ?? false;

  /// 🔍 فحص استباقي لكافة المحركات
  Future<void> checkAllCapabilities() async {
    final settings = Get.find<SettingsController>();
    if (kDebugMode) {
      debugPrint(
          "🔍 ModelCapabilityService: Checking AI model availability...");
    }

    // 1. Veo Capabilities (Flow & Whisk)
    try {
      final veo = Get.find<GoogleVeoService>();
      final apiKey = settings.getApiKey(ProviderType.gemini);

      if (apiKey.isNotEmpty) {
        _capabilities['veo-3.1-fast'] = await veo.testConnection(apiKey);
        _capabilities['veo-3.1'] = _capabilities['veo-3.1-fast'] ?? false;
      }
    } catch (_) {
      _capabilities['veo-3.1-fast'] = false;
    }

    // 2. Imagen Capabilities (Nano Banana Pro)
    _capabilities['imagen-3.0'] =
        true; // نعتبرها مستقرة طالما مفتاح Gemini موجود

    // 3. Video Alternative (Kling AI)
    try {
      final kling = Get.find<KlingService>();
      _capabilities['kling-v1'] =
          await kling.testConnection(""); // فحص المفتاح المخزن
    } catch (_) {
      _capabilities['kling-v1'] = false;
    }

    // 4. Smart Routing Capabilities (GitHub/OpenRouter)
    final gKey = settings.getApiKey(ProviderType.github);
    final gemKey = settings.getApiKey(ProviderType.gemini);
    
    if (KeyRoutingHelper.isSmartKey(gKey) || KeyRoutingHelper.isSmartKey(gemKey)) {
      final smartKey = KeyRoutingHelper.isSmartKey(gKey) ? gKey : gemKey;
      final smartModels = KeyRoutingHelper.getModelsForKey(smartKey);
      for (var model in smartModels) {
        _capabilities[model] = true;
      }
      if (kDebugMode) debugPrint("🚀 [Routing]: Smart models activated via prefix.");
    }

    if (kDebugMode) {
      debugPrint("✅ Model Capabilities Report:");
      _capabilities.forEach((key, value) =>
          debugPrint("   - $key: ${value ? 'AVAILABLE' : 'NOT FOUND'}"));
    }
  }

  /// 🚦 Smart Fallback Router
  /// يختار أفضل موديل متاح بناءً على القدرات الحقيقية
  String getBestVideoModel() {
    if (isModelAvailable('veo-3.1-fast')) return 'veo';
    if (isModelAvailable('kling-v1')) return 'kling';
    return 'gemini-flash'; // Fallback النهائي
  }
}
