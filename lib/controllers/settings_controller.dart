import 'dart:convert';
import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import 'package:flutter/foundation.dart';
import '../config.dart'; // 🔄 Added Import for Config
import '../services/db_service.dart';
import '../services/secure_storage_service.dart';
import '../core/models/api_provider.dart';
import '../services/ai_provider.dart';
import 'api_controller.dart';
import 'auth_controller.dart';
import '../core/utils/snackbar_utils.dart';
import '../services/azure_openai_service.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/serpapi_master_service.dart';
import '../services/managed_ai_service.dart';
import '../services/tiktok_service.dart';
import '../services/ai_image_generation_service.dart';

class SettingsController extends GetxController {
  // --- Version & Update Config ---
  static const String currentVersion = "1.1.0";
  static const int currentBuild = 3; // Refined Architecture Update
  static const String latestApkUrl =
      "https://helalalfqih-sketch.github.io/-/downloads/app-arm64-v8a-release.apk";

  ApiController get apiController => Get.find<ApiController>();
  late DBService _dbService;
  late SecureStorageService _secureStorage;
  late AppStorageService _storage;

  // Observable maps
  final providerKeys = <ProviderType, String>{}.obs;
  final providerStatus = <ProviderType, bool>{}.obs;
  final providerErrors = <ProviderType, String>{}.obs;
  final providerEndpoints =
      <ProviderType, String>{}.obs; // 🔗 جديد: تخزين الـ Endpoint المخصص
  final providerSecrets = <ProviderType, String>{}
      .obs; // 🔐 جديد: تخزين المفاتيح السرية للمزودين المزدوجين (Kling)

  // Observable state
  final activeProvider =
      ProviderType.gemini.obs; // Legacy (backward compatibility)
  final activeTextProvider = ProviderType.gemini.obs;
  final activeVideoProvider = ProviderType.kling.obs;

  final Rx<ProviderType?> savingProvider = Rx<ProviderType?>(null);

  // UI State for Settings Screen (Which provider is currently selected for editing)
  final selectedProvider = ''.obs;

  // TikTok API Config
  final tiktokClientKey = ''.obs;
  final tiktokClientSecret = ''.obs;
  final tiktokProxyKey = ''.obs;
  final tiktokActorId = ''.obs;
  final tiktokApifyToken = ''.obs;
  final tiktokUsername = ''.obs; // 🆕 اسم المستخدم (مثال: @indexes_1000)
  final tiktokProfileUrl = ''.obs; // 🆕 رابط البروفايل الكامل
  
  // 🗝️ Hexa-Key System for GitHub (GitHub Key 1-6)
  final githubKeys = <String>[].obs;
  
  // YouTube API Config (v4.0)
  final youtubeHandle = ''.obs;     // 🆕 @handle
  final youtubeChannelUrl = ''.obs; // 🆕 Full URL

  // Instagram Account Config (v4.0)
  final instagramUsername = ''.obs; 
  final instagramProfileUrl = ''.obs;

  // 🧠 Managed AI Credits (v3.0)
  final remainingCredits = 0.obs;
  final isTrialActive = false.obs;
  final isManagedActive = false.obs;
  
  // 💳 SerpApi Quota Monitoring
  final serpApiSearchesLeft = 0.obs;
  final serpApiMonthlyLimit = 0.obs;
  final serpApiUsage = 0.obs;
  final isCheckingSerpApi = false.obs;
  
  // ⛏️ Jina AI Reader Config
  final isJinaEnabled = true.obs;

  // 📝 Planning Mode (Quick Toggle)
  final isPlanningMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _dbService = Get.find<DBService>();
    _secureStorage = Get.find<SecureStorageService>();
    _storage = Get.find<AppStorageService>();
    _initializeSettings();
    
    // 🎧 Listen to Auth changes to reload keys (v4.0 Multi-User Isolation)
    // 🎧 Listen to Auth changes to reload keys (v4.0 Multi-User Isolation)
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      ever(auth.firebaseUidRx, (String? newUid) {
        if (newUid != null) {
          _loadAllKeys();
          // 🚀 Seamless Cloud Hydration: Auto-Sync for ALL users on session ready (Silent)
          syncManagedKeysToLocal(silent: true);
        }
      });
    }

    // Initial load
    _loadAllKeys();
  }

  @override
  void onReady() {
    super.onReady();
    _testAllConnections();
  }

  Future<void> _initializeSettings() async {
    await _loadAllKeys();
    await _loadTikTokKeys();
    await _loadActiveProvider();
    await _loadJinaSettings();
    await _loadPlanningSettings();

    // Initialize selectedProvider with current active text provider
    selectedProvider.value = activeTextProvider.value.name;
  }

  Future<void> _loadTikTokKeys() async {
    tiktokClientKey.value = await _secureStorage.getApiKey('tiktok_client_key');
    tiktokClientSecret.value =
        await _secureStorage.getApiKey('tiktok_client_secret');
    final savedProxyKey = await _secureStorage.getApiKey('tiktok_proxy_key');
    tiktokProxyKey.value = savedProxyKey.isNotEmpty ? savedProxyKey : '';

    String savedActorId = _storage.readString('tiktok_actor_id') ?? '';

    // Migration: clockworks is dead, apify/xxx should be apify~xxx, and 'sInglW8hKA9fvy053' is broken
    if (savedActorId == 'clockworks/tiktok-scraper' ||
        savedActorId == 'clockworks~tiktok-scraper' ||
        savedActorId == 'sInglW8hKA9fvy053') {
      savedActorId = 'apify~tiktok-scraper';
    }

    // Ensure ~ is used instead of / for API compatibility
    if (savedActorId.contains('/')) {
      savedActorId = savedActorId.replaceAll('/', '~');
    }

    tiktokActorId.value = savedActorId;
    await _storage.writeString('tiktok_actor_id', savedActorId);

    tiktokApifyToken.value =
        await _secureStorage.getApiKey('tiktok_apify_token');

    // 🆕 تحميل بيانات الحساب الشخصي
    tiktokUsername.value = _storage.readString('tiktok_username') ?? '';
    tiktokProfileUrl.value = _storage.readString('tiktok_profile_url') ?? '';
    
    // 📺 YouTube Account Link
    youtubeHandle.value = _storage.readString('youtube_handle') ?? '';
    youtubeChannelUrl.value = _storage.readString('youtube_channel_url') ?? '';

    // 📸 Instagram Account Link
    instagramUsername.value = _storage.readString('instagram_username') ?? '';
    instagramProfileUrl.value = _storage.readString('instagram_profile_url') ?? '';

    // 🚀 التفعيل التلقائي لحساب المتجر (Indexes Store) بناءً على طلب المستخدم
    if (instagramUsername.value.isEmpty) {
      updateInstagramAccount('indexes.store', 'https://www.instagram.com/indexes.store/');
    }
  }

  Future<void> _loadJinaSettings() async {
    isJinaEnabled.value = _storage.readBool('jina_enabled') ?? true;
  }

  Future<void> toggleJina(bool value) async {
    isJinaEnabled.value = value;
    await _storage.writeBool('jina_enabled', value);
    _showToast(value ? '🚀 تم تفعيل السحب التلقائي' : '⏸️ تم تعطيل السحب التلقائي', isError: false);
  }

  Future<void> _loadPlanningSettings() async {
    isPlanningMode.value = _storage.readBool('planning_mode_enabled') ?? false;
  }

  Future<void> togglePlanningMode(bool value) async {
    isPlanningMode.value = value;
    await _storage.writeBool('planning_mode_enabled', value);
    _showToast(value ? '📝 تم تفعيل وضع التخطيط' : '📝 تم إغلاق وضع التخطيط', isError: false);
  }

  Future<void> saveTikTokKeys(
      {String? key,
      String? secret,
      String? proxyKey,
      String? actorId,
      String? apifyToken}) async {
    final String? uid = Get.find<AuthController>().firebaseUid;
    
    if (key != null) {
      tiktokClientKey.value = key.trim();
      final storageKey = uid != null ? '${uid}_tiktok_client_key' : 'tiktok_client_key';
      await _secureStorage.saveApiKey(storageKey, tiktokClientKey.value);
    }
    if (secret != null) {
      tiktokClientSecret.value = secret.trim();
      final storageKey = uid != null ? '${uid}_tiktok_client_secret' : 'tiktok_client_secret';
      await _secureStorage.saveApiKey(storageKey, tiktokClientSecret.value);
    }
    if (proxyKey != null) {
      tiktokProxyKey.value = proxyKey.trim();
      final storageKey = uid != null ? '${uid}_tiktok_proxy_key' : 'tiktok_proxy_key';
      await _secureStorage.saveApiKey(storageKey, tiktokProxyKey.value);
    }
    if (apifyToken != null) {
      tiktokApifyToken.value = apifyToken.trim();
      final storageKey = uid != null ? '${uid}_tiktok_apify_token' : 'tiktok_apify_token';
      await _secureStorage.saveApiKey(storageKey, tiktokApifyToken.value);
    }

    if (actorId != null) {
      tiktokActorId.value = actorId.trim();
      await _storage.writeString('tiktok_actor_id', tiktokActorId.value);
    }

    // ☁️ Sync TikTok Keys to Cloud
    _syncToFirestore({
      'tiktok_client_key': tiktokClientKey.value,
      'tiktok_client_secret': tiktokClientSecret.value,
      'tiktok_proxy_key': tiktokProxyKey.value,
      'tiktok_apify_token': tiktokApifyToken.value,
    });

    // 🧪 Test connection immediately after saving
    await testTikTokConnection();

    _showToast('✅ تم حفظ إعدادات TikTok', isError: false);
  }

  // Alias for UI compatibility
  Future<void> saveTikTokSettings() async {
    await saveTikTokKeys(
      key: tiktokClientKey.value,
      secret: tiktokClientSecret.value,
      proxyKey: tiktokProxyKey.value,
      actorId: tiktokActorId.value,
      apifyToken: tiktokApifyToken.value,
    );
  }

  void _showToast(String message, {required bool isError}) {
    SnackBarUtils.showSmartSnackBar(
      title: isError ? 'تنبيه' : 'تم بنجاح',
      message: message,
      isError: isError,
    );
  }

  Future<void> _loadAllKeys() async {
    final String? uid = Get.find<AuthController>().firebaseUid;
    
    if (kDebugMode) {
      debugPrint('🔑 SettingsController: Loading keys for UID: ${uid ?? "None (Anonymous)"}');
    }

    for (final type in ProviderType.values) {
      if (type == ProviderType.custom) continue;

      // 1. Try UID-prefixed Secure Storage first (v4.0 Isolation)
      String key = '';
      if (uid != null) {
        key = await _secureStorage.getApiKey('${uid}_${type.name}');
      }
      
      // 2. Fallback & Migration Logic
      if (key.isEmpty) {
        // Check old No-Prefix key
        key = await _secureStorage.getApiKey(type.name);
        
        // Final Fallback: Old DB/Prefs
        if (key.isEmpty) {
          final res = await _dbService.getRecord('api_keys', where: 'service_name = ?', whereArgs: [type.name]);
          key = res?['api_key'] ?? '';
          if (key.isEmpty) {
            key = _storage.readString('api_key_${type.name}') ?? '';
          }
        }
        
        // 🚀 Auto-Migrate to UID-prefixed key if found in any fallback (and user is logged in)
        if (key.isNotEmpty && uid != null) {
          await _secureStorage.saveApiKey('${uid}_${type.name}', key);
          if (kDebugMode) debugPrint('🚀 Settings: Migrated ${type.name} key for user $uid');
        }
      }

      providerKeys[type] = key;

      // 5. Load Secret Key if applicable (e.g., Kling)
      if (type == ProviderType.kling) {
        providerSecrets[type] = await _secureStorage.getSecretKey(type);
      }

      // 6. Load Custom Endpoint
      final endpoint = _storage.getProviderEndpoint(type.name);
      providerEndpoints[type] = endpoint ?? '';

      // 7. 🔗 NEW: Load Last Known Connection Status (Persistence Fix)
      // We load status for BOTH manual and managed keys to ensure UI consistency on startup
      final lastStatus = _storage.readBool(_getStatusKey(type)) ?? 
                        (_storage.readBool('managed_status_${type.name}') ?? false);
      
      providerStatus[type] = lastStatus;

      // 🔄 Sync with ApiController immediately so it knows the key and status
      if (key.isNotEmpty) {
        apiController.updateApiKey(key, isConnected: lastStatus);
      }
    }

    // 8. 🗝️ Load GitHub Hexa-Keys
    githubKeys.clear();
    for (int i = 1; i <= 6; i++) {
      final k = await _secureStorage.getApiKey('github_key_$i');
      if (k.isNotEmpty) {
        githubKeys.add(k);
      }
    }
  }

  Future<void> _loadActiveProvider() async {
    try {
      // 1. Text Provider
      final activeText = _storage.readString('activeTextProvider');
      if (activeText != null && activeText.isNotEmpty) {
        activeTextProvider.value = ProviderType.values.firstWhere(
          (e) => e.name == activeText,
          orElse: () => ProviderType.gemini,
        );
      } else {
        // Fallback to legacy field
        final legacy = _storage.readString('activeProvider');
        if (legacy != null && legacy.isNotEmpty) {
          activeTextProvider.value = ProviderType.values.firstWhere(
            (e) => e.name == legacy,
            orElse: () => ProviderType.gemini,
          );
        }
      }
      
      // 🔄 Sync the loaded active provider with ApiController
      apiController.setActiveProvider(activeTextProvider.value);

      // 2. Video Provider
      final activeVideo = _storage.readString('activeVideoProvider');
      if (activeVideo != null && activeVideo.isNotEmpty) {
        activeVideoProvider.value = ProviderType.values.firstWhere(
          (e) => e.name == activeVideo,
          orElse: () => ProviderType.kling,
        );
      } else {
        activeVideoProvider.value = ProviderType.kling;
      }

      // Sync legacy field for other controllers
      activeProvider.value = activeTextProvider.value;
    } catch (_) {
      activeTextProvider.value = ProviderType.gemini;
      activeVideoProvider.value = ProviderType.kling;
      activeProvider.value = ProviderType.gemini;
    }
  }

  Future<void> _testAllConnections() async {
    for (final type in ProviderType.values) {
      if (type == ProviderType.custom) continue;

      final key = getApiKey(type);

      // Skip testing if already marked as connected (unless it's a manual refresh)
      // This prevents the UI from flickering back to 'Disconnected' during startup check
      if (providerStatus[type] == true) {
        // Still run check in background but don't clear status unless it fails
        _testConnection(type, key, isBackground: true).catchError((_) {});
        continue;
      }

      if (key.isNotEmpty) {
        await _testConnection(type, key);
      } else {
        // 🧠 Managed AI Fallback Check (v4.0)
        try {
          final managedAi = Get.find<ManagedAiService>();
          final auth = Get.find<AuthController>();
          if (auth.firebaseUid != null) {
            final mKey =
                await managedAi.getManagedKey(auth.firebaseUid, provider: type);
            if (mKey != null && mKey.isNotEmpty) {
              // Also load status for managed key (fallback to global connection status)
              final mStatus = _storage.readBool(_getStatusKey(type)) ?? 
                             (_storage.readBool('managed_status_${type.name}') ?? true);
              providerStatus[type] = mStatus;
              
              // Verify in background
              _testConnection(type, mKey).then((_) {
                 _storage.writeBool(_getStatusKey(type), true);
                 _storage.writeBool('managed_status_${type.name}', true);
              }).catchError((_) {
                 _storage.writeBool(_getStatusKey(type), false);
                 _storage.writeBool('managed_status_${type.name}', false);
              });
              continue;
            }
          }
        } catch (_) {}
        providerStatus[type] = false;
      }
    }

    // 🎵 Test TikTok Connection as well
    await testTikTokConnection();
  }

  Future<void> _testConnection(ProviderType type, String key, {bool isBackground = false}) async {
    // 1️⃣ مسح الأخطاء السابقة قبل الفحص (فقط إذا لم يكن في الخلفية للحفاظ على استقرار الواجهة)
    if (!isBackground) providerErrors.remove(type);

    try {
      // 🛠️ منطق المعالجة حسب نوع المزود
      if (type == ProviderType.stability || type == ProviderType.removebg) {
        // حزمة توليد الصور والأدوات
        final imageService = Get.find<AiImageGenerationService>();
        bool isConnected = false;

        if (type == ProviderType.stability) {
          isConnected = await imageService.testStabilityConnection(key);
        } else if (type == ProviderType.removebg) {
          isConnected = await imageService.testRemoveBgConnection(key);
        }

        if (isConnected) {
          providerStatus[type] = true;
          providerErrors.remove(type);
        } else {
          throw Exception("فشل التحقق من المفتاح. تأكد من الكود أو الرصيد.");
        }
      } else if (type == ProviderType.serpapi) {
        // اختبار اتصال مباشر لـ SerpApi (كونه ليس مزود نصوص توليدي بل محرك بحث)
        final uri = Uri.parse('https://serpapi.com/search.json?q=test&api_key=$key');
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 || response.statusCode == 201) {
          providerStatus[type] = true;
          providerErrors.remove(type);
        } else {
          // جلب سبب الخطأ إذا توفر
          String errMsg = 'المفتاح غير صحيح. رمز الخطأ: ${response.statusCode}';
          try {
             final data = jsonDecode(response.body);
             if (data['error'] != null) errMsg = data['error'];
          } catch (_) {}
          throw Exception(errMsg);
        }
      } else {
        // المزودين القياسيين (Gemini, OpenAi, etc)
        final service = AIProviderFactory.getServiceByType(type);

        // 2️⃣ نستخدم generateText بدلاً من testConnection لالتقاط رسالة الخطأ الحقيقية
        if (type == ProviderType.azure && service is AzureOpenAIService) {
          final endpoint = getCustomEndpoint(type);
          await service.generateText('Test Connection',
              apiKey: key, customEndpoint: endpoint);
        } else {
          await service.generateText('Test Connection', apiKey: key);
        }

        // إذا وصلنا هنا، يعني الاتصال نجح
        providerStatus[type] = true;
        providerErrors.remove(type);
      }

      await _dbService.updateRecord('api_keys', {'enabled': 1}, where: 'service_name = ?', whereArgs: [type.name]);
      await _storage.writeBool(_getStatusKey(type), true);
      
      // 🔄 Sync success to ApiController
      apiController.updateApiKey(key, isConnected: true);
    } catch (e) {
      // 3️⃣ التقاط الخطأ وتخزينه
      providerStatus[type] = false;

      // تنظيف نص الخطأ (إزالة كلمة Exception إذا وجدت)
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.replaceFirst('Exception: ', '');
      }
      providerErrors[type] = errorMsg;

      await _dbService.updateRecord('api_keys', {'enabled': 0}, where: 'service_name = ?', whereArgs: [type.name]);
      await _storage.writeBool(_getStatusKey(type), false);
      
      // Sync failure to ApiController
      apiController.updateApiKey(key, isConnected: false);
    }
  }

  String _getStatusKey(ProviderType type) => 'connection_status_${type.name}';

  bool isActive(ProviderType type) {
    return activeTextProvider.value == type ||
        activeVideoProvider.value == type;
  }

  bool isActiveForText(ProviderType type) => activeTextProvider.value == type;
  bool isActiveForVideo(ProviderType type) => activeVideoProvider.value == type;

  ProviderType getActiveProvider() => activeTextProvider.value;
  ProviderType getActiveVideoProvider() => activeVideoProvider.value;

  String getActiveKey() => getApiKey(activeTextProvider.value);

  // 🛠️ التحكم في المزود الافتراضي (Default Provider Control)
  
  Future<void> setActiveTextProvider(ProviderType type) async {
    activeTextProvider.value = type;
    activeProvider.value = type; // Legacy sync
    await _storage.writeString('activeTextProvider', type.name);
    await _storage.writeString('activeProvider', type.name); // Legacy sync
    
    // المزامنة مع ApiController لمعالجة الطلبات الحالية
    Get.find<ApiController>().setActiveProvider(type);
    
    _showToast('تم تعيين ${type.displayName} كمزود افتراضي للنصوص ✅', isError: false);
  }

  Future<void> setActiveVideoProvider(ProviderType type) async {
    activeVideoProvider.value = type;
    await _storage.writeString('activeVideoProvider', type.name);
    _showToast('تم تعيين ${type.displayName} كمزود افتراضي للفيديو ✅', isError: false);
  }

  Future<void> makeDefault(ProviderType type) async {
    if (type.isVideoCapable) {
      await setActiveVideoProvider(type);
    } 
    if (type.isTextCapable) {
      await setActiveTextProvider(type);
    }
  }

  // 🛠️ UI Helper Methods for ProviderSelectionList

  void changeProvider(String providerKey) {
    selectedProvider.value = providerKey;
  }

  bool hasKey(String providerKey) {
    // 1. Check if it's a standard provider
    try {
      final type = ProviderType.values.firstWhere(
        (e) => e.name == providerKey,
      );
      return getApiKey(type).isNotEmpty;
    } catch (_) {
      // 2. Check special providers (TikTok)
      if (providerKey == 'tiktok') {
        return tiktokClientKey.value.isNotEmpty || tiktokUsername.value.isNotEmpty;
      }
      if (providerKey == 'youtube') {
        return youtubeHandle.value.isNotEmpty;
      }
      return false;
    }
  }

  Future<void> saveApiKey(ProviderType type, String key) async {
    if (key.trim().isEmpty) return;

    savingProvider.value = type;
    try {
      final trimmedKey = key.trim();
      final String? uid = Get.find<AuthController>().firebaseUid;

      // 🔐 Consistent Storage: Use UID prefix if available
      final storageKey = uid != null ? '${uid}_${type.name}' : type.name;

      // Save to Secure Storage
      await _secureStorage.saveApiKey(storageKey, trimmedKey);
      providerKeys[type] = trimmedKey;

      // 🔥 Refined Logic: Auto-activate only if no key was set before
      final isNewKey = getApiKey(type).isEmpty;

      if (isNewKey) {
        await setActiveProvider(type,
            isVideo: type.isVideoCapable && !type.isTextCapable);
      }

      await _testConnection(type, trimmedKey);

      // ☁️ Push to Cloud (Bidirectional Sync)
      _syncToFirestore({
        'user_api_keys': {
          type.name: trimmedKey,
        }
      });
    } finally {
      savingProvider.value = null;
    }
  }

  /// 🔄 Migrate keys from anonymous/null state to a newly logged-in UID
  Future<void> migrateKeysToNewUid(String newUid) async {
    if (kDebugMode) debugPrint("🔄 Settings: Migrating local keys to new UID: $newUid");
    
    for (final type in ProviderType.values) {
      if (type == ProviderType.custom) continue;
      
      // 1. Check if we already have a key for the new UID
      final existingKey = await _secureStorage.getApiKey('${newUid}_${type.name}');
      if (existingKey.isNotEmpty) continue; // Already exists, don't overwrite
      
      // 2. Check for "No-Prefix" global key
      final globalKey = await _secureStorage.getApiKey(type.name);
      if (globalKey.isNotEmpty) {
        await _secureStorage.saveApiKey('${newUid}_${type.name}', globalKey);
        if (kDebugMode) debugPrint("✅ Settings: Migrated ${type.name} to $newUid");
      }
    }
    
    // Reload internal state
    await _loadAllKeys();
  }

  Future<void> saveGithubKeys(List<String> keys) async {
    // 🧹 Ignore empty fields as requested
    final filteredKeys =
        keys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();

    githubKeys.assignAll(filteredKeys);

    // Save each slot securely (up to 6)
    for (int i = 1; i <= 6; i++) {
      final keyToSave = i <= filteredKeys.length ? filteredKeys[i - 1] : '';
      await _secureStorage.saveApiKey('github_key_$i', keyToSave);
    }

    // ☁️ Push Hexa-Keys to Cloud
    _syncToFirestore({
      'github_hexa_keys': filteredKeys,
    });

    // Update the main provider key for GitHub with the first one (for immediate use/legacy)
    if (filteredKeys.isNotEmpty) {
      providerKeys[ProviderType.github] = filteredKeys.first;
      await _secureStorage.saveApiKey(ProviderType.github.name, filteredKeys.first);
      await _testConnection(ProviderType.github, filteredKeys.first);
    } else {
      providerKeys[ProviderType.github] = '';
      await _secureStorage.saveApiKey(ProviderType.github.name, '');
      providerStatus[ProviderType.github] = false;
    }

    _showToast('✅ تم حفظ مفاتيح GitHub الستة بنجاح', isError: false);
  }

  // 🔐 Secret Key methods for dual-key providers (e.g., Kling)
  Future<void> saveSecretKey(ProviderType type, String secretKey) async {
    if (secretKey.trim().isEmpty) return;
    final trimmed = secretKey.trim();
    await _secureStorage.saveSecretKey(type, trimmed);
    providerSecrets[type] = trimmed;

    // ☁️ Push Secret to Cloud
    _syncToFirestore({
      'user_secret_keys': {
        type.name: trimmed,
      }
    });
  }

  Future<String> getSecretKey(ProviderType type) async {
    return await _secureStorage.getSecretKey(type);
  }

  Future<void> saveCustomEndpoint(ProviderType type, String endpoint) async {
    if (endpoint.trim().isEmpty) return;
    final trimmed = endpoint.trim();
    await _storage.saveProviderEndpoint(type.name, trimmed);
    providerEndpoints[type] = trimmed;
  }

  Future<bool> setActiveProvider(ProviderType type,
      {bool isVideo = false}) async {
    final isConnected = getConnectionStatus(type);
    if (!isConnected) {
      // Allow setting even if not connected yet if it's the first time/developer mode
      // return false;
    }

    if (isVideo) {
      activeVideoProvider.value = type;
      await _storage.writeString('activeVideoProvider', type.name);
    } else {
      activeTextProvider.value = type;
      await _storage.writeString('activeTextProvider', type.name);
      // Legacy sync
      activeProvider.value = type;
      await _storage.writeString('activeProvider', type.name);
      await apiController.setActiveProvider(type);
    }

    return true;
  }

  Future<void> testProviderConnection(ProviderType type) async {
    savingProvider.value = type;
    try {
      final key = getApiKey(type);
      if (key.isEmpty) {
        // Check managed
        final managedAi = Get.find<ManagedAiService>();
        final auth = Get.find<AuthController>();
        final mKey =
            await managedAi.getManagedKey(auth.firebaseUid, provider: type);
        if (mKey != null && mKey.isNotEmpty) {
          providerStatus[type] = true;
          providerErrors.remove(type);
        } else {
          providerStatus[type] = false;
        }
        return;
      }
      await _testConnection(type, key);
    } finally {
      savingProvider.value = null;
    }
  }

  // 🎵 ميزه خاصة لاختبار تيك توك (Apify)
  Future<void> testTikTokConnection() async {
    try {
      final tiktok = Get.find<TikTokService>();
      final isConnected = await tiktok.testConnection();
      _storage.writeBool('tiktok_connected', isConnected);
      _storage.remove('tiktok_error');
    } catch (e) {
      _storage.writeBool('tiktok_connected', false);
      _storage.writeString('tiktok_error', e.toString());
    }
  }

  // 💳 ميزة فحص رصيد SerpApi
  Future<void> checkSerpApiStatus() async {
    isCheckingSerpApi.value = true;
    try {
      final data = await Get.find<SerpApiMasterService>().getAccountInfo();
      
      serpApiSearchesLeft.value = data['plan_searches_left'] ?? 0;
      serpApiMonthlyLimit.value = data['searches_per_month'] ?? 0;
      serpApiUsage.value = data['this_month_usage'] ?? 0;
      
      _showToast(
        '💳 الرصيد المتبقي: ${serpApiSearchesLeft.value} من ${serpApiMonthlyLimit.value}',
        isError: false
      );
    } catch (e) {
      _showToast('فشل فحص الرصيد: $e', isError: true);
    } finally {
      isCheckingSerpApi.value = false;
    }
  }

  bool get isTikTokConnected => _storage.readBool('tiktok_connected') ?? false;
  String? get tiktokError => _storage.readString('tiktok_error');

  String getApiKey(ProviderType type) => providerKeys[type] ?? '';
  bool getConnectionStatus(ProviderType type) => providerStatus[type] ?? false;

  String getCustomEndpoint(ProviderType type) => providerEndpoints[type] ?? '';

  // 🔗 ميزة الربط الذكي (Smart Token Link) - V2
  Future<void> linkWithGoogle(ProviderType provider) async {
    try {
      final authController = Get.find<AuthController>();

      // 1. Check if user is already signed in (not anonymous)
      bool isAnonymous =
          firebase_auth.FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

      if (isAnonymous) {
        // Trigger Google Sign-In
        await authController.signInWithGoogle();
      }

      // Re-check after sign in attempt
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        throw Exception("يجب تسجيل الدخول بحساب Google لتفعيل الربط التلقائي.");
      }

      // 2. Fetch managed key from Firestore
      final managedAi = Get.find<ManagedAiService>();
      final managedKey =
          await managedAi.getManagedKey(user.uid, provider: provider);

      if (managedKey != null && managedKey.isNotEmpty) {
        // Save the key locally as well for speed/offline fallback
        await saveApiKey(provider, managedKey);

        // Test it immediately
        await testProviderConnection(provider);

        SnackBarUtils.showSmartSnackBar(
          title: 'ربط ناجح ✅',
          message:
              'تم ربط حسابك وجلب مفتاح ${provider.displayName} تلقائياً 🌟',
          isError: false,
        );
      } else {
        throw Exception("لا يوجد مفتاح متاح حالياً لهذا المزود في حسابك.");
      }
    } catch (e) {
      SnackBarUtils.showSmartSnackBar(
        title: 'فشل الربط',
        message: e.toString().contains("Exception: ")
            ? e.toString().split("Exception: ")[1]
            : 'تعذر الربط التلقائي. يرجى إدخال المفتاح يدوياً.',
        isError: true,
      );
    }
  }

  Future<void> shareApp() async {
    // ignore: deprecated_member_use
    await Share.share(
      "🚀 جرب تطبيق 'صانع المحتوى الذكي' (Smart Content Creator)!\n\nأنشئ فيديوهات وإعلانات احترافية بالذكاء الاصطناعي في ثوانٍ. حمل النسخة المحدثة الآن:\n$latestApkUrl\n\nأو قم بزيارة موقعنا للتسجيل: ${Config.baseUrl}",
    );
  }

  /// 🔄 استعادة المفاتيح من فايربيس للقاعدة المحلية (للأدمن فقط)
  /// Restores Managed Keys from Firebase to Local Secure Storage
  Future<void> syncManagedKeysToLocal({bool silent = false}) async {
    final auth = Get.find<AuthController>();
    
    if (kDebugMode) debugPrint("🔄 Settings: Starting Cloud Key Sync for UID: ${auth.firebaseUid}...");
 
    try {
      final managedAi = Get.find<ManagedAiService>();
      final uid = auth.firebaseUid;
      if (uid == null) {
        if (kDebugMode) debugPrint("⚠️ Settings: Sync failed - No Firebase UID");
        return;
      }
 
      int syncedCount = 0;
      List<String> syncedNames = [];
 
      // 1. Fetch User's Personal Keys from their private document
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final Map<String, dynamic> personalKeys = userDoc.data()?['user_api_keys'] as Map<String, dynamic>? ?? {};

      for (final type in ProviderType.values) {
        if (type == ProviderType.custom) continue;
 
        // 🛡️ Skip if local key already exists (To avoid overwriting custom keys)
        // Unless it's a manual UI trigger (not silent)
        if (getApiKey(type).isNotEmpty && silent) continue;
 
        // 🔍 Key Retrieval Strategy: Personal First, then Managed
        String? key;
        String source = "None";

        // Layer 1: Check Personal Keys (from Cloud Sync)
        if (personalKeys.containsKey(type.name)) {
          key = personalKeys[type.name]?.toString();
          source = "Personal";
        }
        
        // Layer 2: Check System Managed Keys (Fallback)
        if (key == null || key.isEmpty) {
          key = await managedAi.getManagedKey(uid, provider: type);
          source = "System";
        }
        
        if (key != null && key.isNotEmpty) {
          // Save to Local Secure Storage (UID-prefixed for isolation)
          await _secureStorage.saveApiKey('${uid}_${type.name}', key);
          providerKeys[type] = key;
          
          if (kDebugMode) debugPrint("✅ Settings: Restored $source key for ${type.name}");

          // Test connection to update status (Background)
          _testConnection(type, key).catchError((_) => false);
          syncedCount++;
          syncedNames.add(type.name);
        }
      }
 
      if (syncedCount > 0) {
        if (kDebugMode) debugPrint("✅ Settings: Successfully synced $syncedCount keys: $syncedNames");
        if (!silent) {
          _showToast('✅ تم استعادة $syncedCount من المفاتيح السحابية', isError: false);
        }
      } else {
        if (kDebugMode) debugPrint("ℹ️ Settings: No keys found in Firestore (Personal or Managed).");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Settings: Key Sync Failed: $e");
    }
  }

  Future<void> checkForUpdate({bool manual = false}) async {
    try {
      // 🔥 Fetch version info from Official Website
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/version.json'),
      );

        if (response.statusCode == 200) {
          final versionData = jsonDecode(response.body);
          final int latestBuild = int.tryParse(versionData['build']?.toString() ?? '0') ?? 0;
          final String latestVersion = versionData['version']?.toString() ?? '1.0.0';
          final String apkUrl = versionData['apk_url']?.toString() ?? '';
          final String releaseNotes =
              versionData['release_notes']?.toString() ?? '';

        if (latestBuild > currentBuild) {
          _showUpdateDialog(
            version: latestVersion,
            build: latestBuild,
            apkUrl: apkUrl,
            releaseNotes: releaseNotes,
          );
        } else if (manual) {
          SnackBarUtils.showSmartSnackBar(
            title: 'أنت على أحدث نسخة',
            message: 'لا يوجد تحديث متوفر حالياً ✅',
            isError: false,
            durationSeconds: 2,
          );
        }
      } else {
        throw Exception(
            'فشل جلب معلومات التحديث (Status: ${response.statusCode}). تأكد من رفع ملف version.json إلى موقعك.');
      }
    } catch (e) {
      if (manual) {
        SnackBarUtils.showSmartSnackBar(
          title: 'خطأ',
          message: 'تعذر التحقق من التحديثات: $e',
          isError: true,
        );
        apiController.setActiveProvider(activeTextProvider.value);
      }
    }
  }

  void _showUpdateDialog({
    required String version,
    required int build,
    required String apkUrl,
    String releaseNotes = '',
  }) {
    final context = Get.context;
    if (context == null) return;

    final bool hasShownWarning = _storage.readBool('ota_warning_shown') ?? false;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_alt, color: Colors.blue),
              SizedBox(width: 10),
              Text('تحديث جديد متوفر 🚀'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'يتوفر إصدار أحدث من التطبيق بميزات إضافية وتحسينات للأداء.'),
              const SizedBox(height: 12),
              Text('رقم الإصدار الجديد: $version (Build $build)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              if (releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(releaseNotes, style: const TextStyle(fontSize: 13)),
              ],
              if (!hasShownWarning) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ التحديث يتم يدويًا. قد يُطلب منك السماح بالتثبيت من هذا المصدر.',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _storage.writeBool('ota_warning_shown', true);
                final uri = Uri.parse(apkUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  // --- TikTok Account Management ---
  Future<void> updateTikTokAccount(String username, String url) async {
    tiktokUsername.value = username;
    tiktokProfileUrl.value = url;
    await _storage.writeString('tiktok_username', username);
    await _storage.writeString('tiktok_profile_url', url);
  }

  // --- YouTube Account Management ---
  Future<void> updateYoutubeAccount(String handle, String url) async {
    youtubeHandle.value = handle;
    youtubeChannelUrl.value = url;
    await _storage.writeString('youtube_handle', handle);
    await _storage.writeString('youtube_channel_url', url);
  }

  // --- Instagram Account Management ---
  Future<void> updateInstagramAccount(String username, String url) async {
    instagramUsername.value = username;
    instagramProfileUrl.value = url;
    await _storage.writeString('instagram_username', username);
    await _storage.writeString('instagram_profile_url', url);
  }

  /// ☁️ المزامنة السحابية الصاعدة (Cloud-Push)
  /// ترفع المفاتيح الجديدة إلى Firestore فور حفظها محلياً
  void _syncToFirestore(Map<String, dynamic> data) async {
    try {
      final String? uid = Get.find<AuthController>().firebaseUid;
      if (uid == null) return;

      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      
      // نستخدم SetOptions(merge: true) لضمان عدم مسح البيانات السابقة
      await userDoc.set(data, SetOptions(merge: true));
      
      if (kDebugMode) debugPrint("☁️ Settings: Successfully pushed $data to Cloud.");
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Settings: Failed to push to Cloud: $e");
    }
  }
}
