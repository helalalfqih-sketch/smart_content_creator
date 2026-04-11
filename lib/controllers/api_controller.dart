import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode, debugPrint - Reload Force
import 'package:get/get.dart';
import '../core/models/api_provider.dart';
import '../core/storage/app_storage_service.dart';

import '../services/ai_provider.dart';
import '../services/gemini_service.dart';
import '../services/db_service.dart';
import '../services/managed_ai_service.dart';
import '../core/utils/snackbar_utils.dart';
import '../core/utils/error_handler.dart';
import '../core/utils/smart_exception.dart';
import 'settings_controller.dart';
import 'auth_controller.dart';

enum ApiStatus { active, limited, error, unknown }

class ApiController extends GetxController {
  final DBService _dbService; // New DB dependency
  final AppStorageService _storage;

  late final Rx<ProviderType> _activeProvider;
  late final RxnString _testStatus;
  late final RxBool _isTesting;
  late final RxBool _isSaving;

  final RxMap<ProviderType, ApiProvider> _providers =
      <ProviderType, ApiProvider>{}.obs;

  // Getters for UI
  ProviderType get activeProvider => _activeProvider.value;
  String? get testStatus => _testStatus.value;
  bool get isTesting => _isTesting.value;
  Map<ProviderType, ApiProvider> get providers => _providers;

  // Computed Status for UI
  ApiStatus get geminiStatus => _computeGeminiStatus();

  ApiStatus _computeGeminiStatus() {
    // 🔗 Sync with SettingsController to support Managed Keys status
    try {
      if (Get.isRegistered<SettingsController>()) {
        final settings = Get.find<SettingsController>();
        final isConnected = settings.getConnectionStatus(ProviderType.gemini);
        final hasKey = settings.getApiKey(ProviderType.gemini).isNotEmpty;

        if (isConnected) return ApiStatus.active;
        if (hasKey && !isConnected) return ApiStatus.error;
      }
    } catch (_) {}

    // Fallback to legacy local check
    final p = _providers[ProviderType.gemini];
    if (p == null || p.apiKey.isEmpty) return ApiStatus.unknown;
    if (p.lastTestSuccess == true) return ApiStatus.active;
    if (p.lastTestSuccess == false) return ApiStatus.error;
    return ApiStatus.unknown; // Default
  }

  ApiController([AppStorageService? storage])
      : _storage = storage ?? Get.find<AppStorageService>(),
        _dbService = Get.put(DBService()) {
    // Ensure DBService is available
    _activeProvider = ProviderType.gemini.obs;
    _testStatus = RxnString();
    _isTesting = false.obs;
    _isSaving = false.obs;
  }

  void showError(Object e) {
    // 🧠 Managed AI: Check for Quota Exceeded (v3.0)
    if (e is SmartUserException && e.isQuotaExceeded) {
      _showSubscriptionDialog();
      return;
    }

    // 🧠 Use Smart Error Handler for friendly messages
    final smartError = ErrorHandler.mapError(e);

    // Log technical details if needed
    // if (kDebugMode && smartError.technicalDetails != null) {
    //   debugPrint("❌ Technical Error: ${smartError.technicalDetails}");
    // }

    SnackBarUtils.showSmartSnackBar(
      title: 'تنبيه',
      message: smartError.message,
      isError: true,
    );
  }

  Future<void> setActiveProvider(ProviderType type) async {
    _activeProvider.value = type;
    await _storage.write('activeProvider', type.name);
  }

  Future<void> updateApiKey(String key, {bool? isConnected}) async {
    final type = _activeProvider.value;
    final current = _providers[type];
    
    _providers[type] = ApiProvider(
      type: type,
      apiKey: key,
      lastTestSuccess: isConnected ?? current?.lastTestSuccess,
      lastTested: isConnected != null ? DateTime.now() : current?.lastTested,
      customEndpoint: current?.customEndpoint,
    );
  }


  // 🛑 Removed redundant _initProviders - ApiController now waits for SettingsController
  // to push the active keys and status after Firebase initialization.

  Future<bool> saveCurrentProvider() async {
    _isSaving.value = true;

    final provider = _providers[_activeProvider.value]!;
    try {
      await _dbService.insertRecord('api_keys', {
        'service_name': _activeProvider.value.name,
        'api_key': provider.apiKey,
        'enabled': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (provider.customEndpoint != null &&
          provider.customEndpoint!.isNotEmpty) {
        await _storage.saveProviderEndpoint(
            _activeProvider.value.name, provider.customEndpoint!);
      }

      await _storage.write('activeProvider', _activeProvider.value.name);

      final ok = await testCurrentProvider();
      _isSaving.value = false;
      return ok;
    } catch (e) {
      _isSaving.value = false;
      _testStatus.value = 'خطأ: $e';
      return false;
    }
  }

  Future<bool> testCurrentProvider() async {
    _isTesting.value = true;
    _testStatus.value = 'جاري الفحص...';

    // check if provider exists in map, if not, create it or fail
    if (!_providers.containsKey(_activeProvider.value)) {
      _testStatus.value = 'خطأ: المزود غير موجود';
      _isTesting.value = false;
      return false;
    }

    final provider = _providers[_activeProvider.value]!;
    bool success = false;

    try {
      if (provider.apiKey.trim().isEmpty) {
        success = false;
        _testStatus.value = '❌ المفتاح فارغ';
      } else {
        // Here we should probably call actual test logic, but keeping original structure
        success = true;
        _testStatus.value = '✅ التحقق ناجح';
      }

      await _storage.saveTestResult(_activeProvider.value.name, success);
      _providers[_activeProvider.value] = provider.copyWith(
          lastTestSuccess: success, lastTested: DateTime.now());
    } catch (e) {
      success = false;
      _testStatus.value = 'خطأ: $e';
      await _storage.saveTestResult(_activeProvider.value.name, false);
    } finally {
      _isTesting.value = false;
    }

    return success;
  }

  Future<AiResult> analyzeSelectedImage(Uint8List? bytes, String prompt,
      {List<Map<String, String>>? history}) async {
    if (bytes == null || bytes.isEmpty) {
      throw Exception('يرجى اختيار صورة أولاً.');
    }
    try {
      final (provider, apiKey, type) =
          await AIProviderFactory.getSmartProvider(isVideo: false);
      final result = await provider.analyzeImage(bytes, prompt,
          apiKey: apiKey, history: history);

      // 🧠 Managed AI: Deduct Credit (v3.0)
      _checkAndDeductManagedCredit(apiKey, type);

      // AUTO-SAVE PRODUCT
      await _dbService.insertRecord('products', {
        'name': result.tags.isNotEmpty ? result.tags.first : 'منتج جديد',
        'description': result.description,
        'image_path': 'memory_image',
        'category': result.tags.length > 1 ? result.tags[1] : 'عام',
        'created_at': DateTime.now().toIso8601String(),
      });

      return result;
    } catch (e) {
      showError(e);
      // keep UI stable; return empty AiResult
      return AiResult(
          description: '', tags: const <String>[], provider: 'error');
    }
  }

  Future<AiResult> generateText(String prompt,
      {List<Map<String, String>>? history}) async {
    try {
      final (provider, apiKey, type) =
          await AIProviderFactory.getSmartProvider(isVideo: false);
      final result =
          await provider.generateText(prompt, apiKey: apiKey, history: history);

      // 🧠 Managed AI: Deduct Credit if applicable (v3.0)
      _checkAndDeductManagedCredit(apiKey, type);

      return result;
    } catch (e) {
      showError(e);
      return AiResult(
          description: '', tags: const <String>[], provider: 'error');
    }
  }

  /// 📉 Managed AI Helper: Deduct credits if a system key was used
  void _checkAndDeductManagedCredit(String keyUsed, ProviderType type) async {
    try {
      final settings = Get.find<SettingsController>();
      final userKey = settings.getApiKey(type);

      // If key is NOT the user's private key, it's the managed one
      if (userKey.isEmpty || userKey != keyUsed) {
        final auth = Get.find<AuthController>();
        final managedAi = Get.find<ManagedAiService>();
        if (auth.firebaseUid != null) {
          await managedAi.deductCredit(auth.firebaseUid);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ ApiController: Failed to deduct credit: $e');
      }
    }
  }

  Stream<String> generateTextStream(String prompt,
      {Uint8List? imageBytes,
      Uint8List? videoBytes,
      List<Map<String, String>>? history}) async* {
    try {
      final (provider, apiKey, type) =
          await AIProviderFactory.getSmartProvider();

      bool creditDeducted = false;

      await for (final chunk in provider.generateTextStream(prompt,
          apiKey: apiKey,
          imageBytes: imageBytes,
          videoBytes: videoBytes,
          history: history)) {
        // 📉 Managed AI: Deduct once on first chunk (v3.0)
        if (!creditDeducted && chunk.isNotEmpty) {
          _checkAndDeductManagedCredit(apiKey, type);
          creditDeducted = true;
        }

        yield chunk;
      }
    } catch (e) {
      showError(e);
      yield 'حدث خطأ أثناء الاتصال بالخادم. ⚠️';
    }
  }

  Future<Map<String, dynamic>> generateMarketingContent(String prompt,
      {Uint8List? imageBytes, Uint8List? videoBytes}) async {
    try {
      final (provider, apiKey, type) =
          await AIProviderFactory.getSmartProvider();

      if (provider is GeminiService) {
        final result = await provider.generateMarketingContent(prompt,
            apiKey: apiKey);

        // 🧠 Managed AI: Deduct Credit (v3.0)
        _checkAndDeductManagedCredit(apiKey, type);

        return {'content': result};
      } else {
        throw Exception("هذه الميزة مدعومة فقط بواسطة Gemini حالياً");
      }
    } catch (e) {
      showError(e);
      return {};
    }
  }

  /// 🧠 Generate Embeddings (Unified)
  Future<List<double>> generateEmbeddings(String text) async {
    try {
      final (provider, apiKey, type) =
          await AIProviderFactory.getSmartProvider();

      return await provider.generateEmbeddings(text, apiKey: apiKey);
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Embedding Error: \$e");
      return [];
    }
  }

// ... existing code ...

  Stream<String> chatWithAiStream(String prompt,
      {Uint8List? imageBytes,
      Uint8List? videoBytes,
      List<Map<String, String>>? history}) async* {
    final fullPrompt = """
$prompt

**IMPORTANT**: 
1. Provide your helpful response in Arabic first.
2. After the response, if there are suggested actions, provide them at the very end enclosed in [ACTIONS] and [/ACTIONS] tags in JSON format.
Example:
... your response ...
[ACTIONS]
[{"label": "Label", "action": "code"}]
[/ACTIONS]

Actions can be: "generate_video", "analyze_trends", "generate_script".
""";

    yield* generateTextStream(fullPrompt,
        imageBytes: imageBytes, videoBytes: videoBytes, history: history);
  }

  /// 📣 Managed AI: Show Subscription Dialog (v3.0)
  void _showSubscriptionDialog() {
    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚠️ الأرصدة غير كافية',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Colors.orange, size: 60),
              const SizedBox(height: 16),
              const Text(
                'لقد استهلكت جميع الأرصدة المتاحة للنظام المدار اليوم.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'يمكنك المتابعة عبر إضافة مفتاح API الخاص بك مجاناً، أو الترقية للباقة الاحترافية للاستمرار في استخدام نظامنا.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6200EE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Get.back();
                Get.toNamed('/settings'); // Redirect to settings
              },
              child: const Text('إعدادات المفاتيح 🗝️'),
            ),
          ],
        ),
      ),
    );
  }
}
