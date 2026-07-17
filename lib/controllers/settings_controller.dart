import 'dart:convert';
import 'dart:async';
import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import '../core/storage/storage_keys.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../services/db_service.dart';
import '../services/secure_storage_service.dart';
import '../core/models/api_provider.dart';
import '../services/ai_provider.dart';
import 'package:smart_content_creator/controllers/api_controller.dart';
import 'package:smart_content_creator/controllers/auth_controller.dart';
import 'package:smart_content_creator/controllers/permissions_controller.dart';
import '../core/utils/snackbar_utils.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/serpapi_master_service.dart';
import '../services/tiktok_service.dart';
import '../services/ai_image_generation_service.dart';
import '../services/back4app_gateway_service.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class SettingsController extends GetxController {
  static const String currentVersion = "1.2.0";
  static const int currentBuild = 4;
  static const String latestApkUrl = "https://www.mediafire.com/file/erl25nent8bfsxl/app-arm64-v8a-release.apk/file";

  ApiController get apiController => Get.find<ApiController>();
  late DBService _dbService;
  late SecureStorageService _secureStorage;
  late AppStorageService _storage;
  
  static const String firestoreApiKeyField = 'user_api_keys';

  final providerKeys = <ProviderType, String>{}.obs;
  final providerStatus = <ProviderType, bool>{}.obs;
  final providerErrors = <ProviderType, String>{}.obs;
  final providerEndpoints = <ProviderType, String>{}.obs;
  final providerSecrets = <ProviderType, String>{}.obs;

  final activeProvider = ProviderType.gemini.obs;
  final activeTextProvider = ProviderType.gemini.obs;
  final activeVideoProvider = ProviderType.kling.obs;
  final Rx<ProviderType?> savingProvider = Rx<ProviderType?>(null);
  final selectedProvider = ''.obs;

  // 📥 متغيرات تحميل التحديث الخلفي
  final isDownloadingUpdate = false.obs;
  final downloadProgress = 0.0.obs;
  final downloadTaskMsg = ''.obs;

  final tiktokClientKey = ''.obs;
  final tiktokClientSecret = ''.obs;
  final tiktokProxyKey = ''.obs;
  final tiktokActorId = ''.obs;
  final tiktokApifyToken = ''.obs;
  final tiktokUsername = ''.obs;
  final tiktokProfileUrl = ''.obs;
  final tiktokError = ''.obs;
  
  final githubKeys = <String>[].obs;
  final youtubeHandle = ''.obs;
  final youtubeChannelUrl = ''.obs;
  final instagramUsername = ''.obs; 
  final instagramProfileUrl = ''.obs;

  // ── Facebook Integration ──
  final fbUserToken = ''.obs;
  final fbPageId = ''.obs;
  final fbPageName = ''.obs;
  final fbPageToken = ''.obs;
  final fbPagesList = <Map<String, dynamic>>[].obs;
  final isFetchingFbPages = false.obs;

  final isTrialActive = false.obs;
  final isManagedActive = false.obs;
  final remainingCredits = 0.obs;
  
  final serpApiSearchesLeft = 0.obs;
  final serpApiMonthlyLimit = 0.obs;
  final serpApiUsage = 0.obs;
  final isCheckingSerpApi = false.obs;
  
  final isJinaEnabled = true.obs;
  final isPlanningMode = false.obs;

  // ☁️ AI Cloud Gateway Control Center & Diagnostics
  final isLoadingHealth = false.obs;
  final isLoadingKeys = false.obs;
  final isLoadingErrors = false.obs;

  final serverHealth = <String, dynamic>{}.obs;
  final serverKeys = <Map<String, dynamic>>[].obs;
  final gatewayErrors = <Map<String, dynamic>>[].obs;
  final dailyUsageCount = 0.obs;
  final gatewayLatency = 0.obs;

  // 🧪 Live Gateway Test
  final isRunningLiveTest = false.obs;
  final liveTestResult = Rx<Map<String, dynamic>?>(null);

  // 📸 Last used vision/text providers
  final lastImageProvider = 'لا توجد صورة محللة بعد'.obs;
  final lastTextProvider = 'لا توجد طلبات بعد'.obs;

  final _syncGate = _SyncGate();
  bool _isLoadingKeys = false;
  String? _lastKeysHash;

  @override
  void onInit() {
    super.onInit();
    _dbService = Get.find<DBService>();
    _secureStorage = Get.find<SecureStorageService>();
    _storage = Get.find<AppStorageService>();
    
    lastImageProvider.value = _storage.readString('lastImageProvider') ?? 'لا توجد صورة محللة بعد';
    lastTextProvider.value = _storage.readString('lastTextProvider') ?? 'لا توجد طلبات بعد';
    
    _initializeSettings();
    
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      ever(auth.firebaseUidRx, (String? newUid) {
        if (newUid != null) {
          _loadAllKeys();
        }
      });

      // 🔄 Bind credits and trial status from Firestore profile
      ever(auth.rxUser, (Map<String, dynamic>? userData) {
        if (userData != null) {
          remainingCredits.value = (userData['credits'] as num?)?.toInt() ?? 0;
          isTrialActive.value = userData['is_trial_active'] == true;
        }
      });

      if (auth.user != null) {
        remainingCredits.value = (auth.user!['credits'] as num?)?.toInt() ?? 0;
        isTrialActive.value = auth.user!['is_trial_active'] == true;
      }
    }

    _loadAllKeys();
    _autoSyncManagedKeys();
  }

  Future<void> _autoSyncManagedKeys() async {
    await Future.delayed(const Duration(seconds: 2));
    await syncManagedKeysToLocal();
  }

  @override
  void onReady() {
    super.onReady();
    _testAllConnections();
    // 🚀 التحقق التلقائي من وجود تحديث عند تشغيل التطبيق
    checkForUpdate(manual: false);
  }

  Future<void> _initializeSettings() async {
    await _loadAllKeys();
    await _loadTikTokKeys();
    await _loadFacebookSettings();
    await _loadActiveProvider();
    await _loadJinaSettings();
    await _loadPlanningSettings();

    if (isManagedActive.value) {
      syncManagedKeysToLocal();
    }
    selectedProvider.value = activeTextProvider.value.name;
  }

  Future<void> _loadTikTokKeys() async {
    tiktokClientKey.value = await _secureStorage.getApiKey('tiktok_client_key');
    tiktokClientSecret.value = await _secureStorage.getApiKey('tiktok_client_secret');
    tiktokProxyKey.value = await _secureStorage.getApiKey('tiktok_proxy_key');
    tiktokActorId.value = _storage.readString('tiktok_actor_id') ?? 'apify~tiktok-scraper';
    tiktokApifyToken.value = await _secureStorage.getApiKey('tiktok_apify_token');
    tiktokUsername.value = _storage.readString('tiktok_username') ?? '';
    tiktokProfileUrl.value = _storage.readString('tiktok_profile_url') ?? '';
    youtubeHandle.value = _storage.readString('youtube_handle') ?? '';
    youtubeChannelUrl.value = _storage.readString('youtube_channel_url') ?? '';
    instagramUsername.value = _storage.readString('instagram_username') ?? '';
    instagramProfileUrl.value = _storage.readString('instagram_profile_url') ?? '';

    if (instagramUsername.value.isEmpty) {
      updateInstagramAccount('indexes.store', 'https://www.instagram.com/indexes.store/');
    }
  }

  Future<void> _loadJinaSettings() async => isJinaEnabled.value = _storage.readBool('jina_enabled') ?? true;
  Future<void> toggleJina(bool value) async {
    isJinaEnabled.value = value;
    await _storage.writeBool('jina_enabled', value);
    _showToast(value ? '🚀 تم تفعيل السحب التلقائي' : '⏸️ تم تعطيل السحب التلقائي', isError: false);
  }

  Future<void> _loadPlanningSettings() async => isPlanningMode.value = _storage.readBool('planning_mode_enabled') ?? false;
  Future<void> togglePlanningMode(bool value) async {
    isPlanningMode.value = value;
    await _storage.writeBool('planning_mode_enabled', value);
    _showToast(value ? '📝 تم تفعيل وضع التخطيط' : '📝 تم إغلاق وضع التخطيط', isError: false);
  }

  Future<void> saveTikTokKeys({String? key, String? secret, String? proxyKey, String? actorId, String? apifyToken}) async {
    final String? uid = Get.find<AuthController>().firebaseUid;
    if (key != null) {
      tiktokClientKey.value = key.trim();
      await _secureStorage.saveApiKey(uid != null ? '${uid}_tiktok_client_key' : 'tiktok_client_key', key.trim());
    }
    if (secret != null) {
      tiktokClientSecret.value = secret.trim();
      await _secureStorage.saveApiKey(uid != null ? '${uid}_tiktok_client_secret' : 'tiktok_client_secret', secret.trim());
    }
    if (proxyKey != null) {
      tiktokProxyKey.value = proxyKey.trim();
      await _secureStorage.saveApiKey(uid != null ? '${uid}_tiktok_proxy_key' : 'tiktok_proxy_key', proxyKey.trim());
    }
    if (apifyToken != null) {
      tiktokApifyToken.value = apifyToken.trim();
      await _secureStorage.saveApiKey(uid != null ? '${uid}_tiktok_apify_token' : 'tiktok_apify_token', apifyToken.trim());
    }
    if (actorId != null) {
      tiktokActorId.value = actorId.trim();
      await _storage.writeString('tiktok_actor_id', actorId.trim());
    }
    _syncToFirestore({
      'tiktok_client_key': tiktokClientKey.value,
      'tiktok_client_secret': tiktokClientSecret.value,
      'tiktok_proxy_key': tiktokProxyKey.value,
      'tiktok_apify_token': tiktokApifyToken.value,
    });
    await testTikTokConnection();
    _showToast('✅ تم حفظ إعدادات TikTok', isError: false);
  }

  Future<void> saveTikTokSettings() async => saveTikTokKeys(key: tiktokClientKey.value, secret: tiktokClientSecret.value, proxyKey: tiktokProxyKey.value, actorId: tiktokActorId.value, apifyToken: tiktokApifyToken.value);

  void _showToast(String message, {required bool isError}) {
    SnackBarUtils.showSmartSnackBar(title: isError ? 'تنبيه' : 'تم بنجاح', message: message, isError: isError);
  }

  Future<void> _loadAllKeys() async {
    if (_isLoadingKeys) return;
    _isLoadingKeys = true;
    try {
      String? uid = Get.find<AuthController>().firebaseUid ?? _storage.readString(StorageKeys.firebaseUid);
      if (Get.isRegistered<PermissionsController>()) {
        isManagedActive.value = Get.find<PermissionsController>().isVisible('use_managed_keys');
      }

      for (final type in ProviderType.values) {
        if (type == ProviderType.custom) {
          continue;
        }
        String key = uid != null ? await _secureStorage.getApiKey('${uid}_${type.name}') : '';
        if (key.isEmpty) key = await _secureStorage.getApiKey(type.name);
        if (key.isEmpty) {
          final res = await _dbService.getRecord('api_keys', where: 'service_name = ?', whereArgs: [type.name]);
          key = res?['api_key'] ?? _storage.readString('api_key_${type.name}') ?? '';
        }
        if (key.isEmpty) key = await _secureStorage.getApiKey('global_${type.name}');

        providerKeys[type] = key;
        if (type.requiresSecretKey) providerSecrets[type] = await _secureStorage.getSecretKey(type);
        providerEndpoints[type] = _storage.getProviderEndpoint(type.name) ?? '';
        final bool isKeyPresent = key.isNotEmpty;
        final lastStatus = _storage.readBool(_getStatusKey(type)) ?? isKeyPresent;
        providerStatus[type] = isKeyPresent ? lastStatus : false;
        if (isKeyPresent) apiController.updateApiKey(key, isConnected: lastStatus);
      }
      githubKeys.clear();
      for (int i = 1; i <= 6; i++) {
        final k = await _secureStorage.getApiKey('github_key_$i');
        if (k.isNotEmpty) githubKeys.add(k);
      }
    } finally {
      _isLoadingKeys = false;
    }
  }

  Future<void> _loadActiveProvider() async {
    try {
      final activeText = _storage.readString('activeTextProvider') ?? _storage.readString('activeProvider');
      if (activeText != null) {
        activeTextProvider.value = ProviderType.values.firstWhere((e) => e.name == activeText, orElse: () => ProviderType.gemini);
      }
      apiController.setActiveProvider(activeTextProvider.value);
      final activeVideo = _storage.readString('activeVideoProvider');
      activeVideoProvider.value = ProviderType.values.firstWhere((e) => e.name == activeVideo, orElse: () => ProviderType.kling);
      activeProvider.value = activeTextProvider.value;
    } catch (_) {}
  }

  Future<void> _testAllConnections() async {
    for (final type in ProviderType.values) {
      if (type == ProviderType.custom) {
        continue;
      }
      final key = getApiKey(type);
      if (key.isNotEmpty) {
        if (providerStatus[type] != true) {
           providerStatus[type] = true;
           apiController.updateApiKey(key, isConnected: true);
        }
        _testConnection(type, key, isBackground: true).catchError((_) {});
      }
    }
    await testTikTokConnection();
  }

  Future<void> _testConnection(ProviderType type, String key, {bool isBackground = false}) async {
    if (!isBackground) providerErrors.remove(type);
    try {
      if (type == ProviderType.stability || type == ProviderType.removebg) {
        final imageService = Get.find<AiImageGenerationService>();
        bool isConnected = type == ProviderType.stability ? await imageService.testStabilityConnection(key) : await imageService.testRemoveBgConnection(key);
        if (!isConnected) throw Exception("فشل التحقق");
      } else if (type == ProviderType.serpapi || type == ProviderType.telegram) {
        final uri = type == ProviderType.serpapi ? Uri.parse('https://serpapi.com/search.json?q=test&api_key=$key') : Uri.parse('https://api.telegram.org/bot$key/getMe');
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200 && response.statusCode != 201) throw Exception("فشل الاتصال");
      } else {
        final service = AIProviderFactory.getServiceByType(type);
        await service.generateText('Test Connection', apiKey: key);
      }
      providerStatus[type] = true;
      providerErrors.remove(type);
      await _storage.writeBool(_getStatusKey(type), true);
      apiController.updateApiKey(key, isConnected: true);
    } catch (e) {
      if (isBackground) return;
      providerStatus[type] = false;
      providerErrors[type] = e.toString();
      await _storage.writeBool(_getStatusKey(type), false);
      apiController.updateApiKey(key, isConnected: false);
    }
  }

  String _getStatusKey(ProviderType type) => 'connection_status_${type.name}';
  bool isActive(ProviderType type) => activeTextProvider.value == type || activeVideoProvider.value == type;
  bool isActiveForText(ProviderType type) => activeTextProvider.value == type;
  bool isActiveForVideo(ProviderType type) => activeVideoProvider.value == type;
  ProviderType getActiveProvider() => activeTextProvider.value;
  ProviderType getActiveVideoProvider() => activeVideoProvider.value;
  String getApiKey(ProviderType type) => providerKeys[type] ?? '';
  String getActiveKey() => getApiKey(activeTextProvider.value);
  bool getConnectionStatus(ProviderType type) => providerStatus[type] ?? false;
  String getCustomEndpoint(ProviderType type) => providerEndpoints[type] ?? '';

  Future<bool> setActiveProvider(ProviderType type, {bool isVideo = false}) async {
    if (isVideo) {
      return await setActiveVideoProvider(type).then((_) => true);
    } else {
      return await setActiveTextProvider(type).then((_) => true);
    }
  }

  Future<void> setActiveTextProvider(ProviderType type) async {
    activeTextProvider.value = type;
    activeProvider.value = type;
    await _storage.writeString('activeTextProvider', type.name);
    Get.find<ApiController>().setActiveProvider(type);
    _showToast('تم تعيين ${type.displayName} افتراضياً للنصوص ✅', isError: false);
  }

  Future<void> setActiveVideoProvider(ProviderType type) async {
    activeVideoProvider.value = type;
    await _storage.writeString('activeVideoProvider', type.name);
    _showToast('تم تعيين ${type.displayName} افتراضياً للفيديو ✅', isError: false);
  }

  Future<void> makeDefault(ProviderType type) async {
    if (type.isVideoCapable) await setActiveVideoProvider(type);
    if (type.isTextCapable) await setActiveTextProvider(type);
  }

  void changeProvider(String providerKey) => selectedProvider.value = providerKey;

  bool hasKey(String providerKey) {
    final type = ProviderType.values.firstWhereOrNull((e) => e.name == providerKey);
    if (type != null) return getApiKey(type).isNotEmpty;
    if (providerKey == 'tiktok') return tiktokClientKey.value.isNotEmpty;
    if (providerKey == 'youtube') return youtubeHandle.value.isNotEmpty;
    if (providerKey == 'facebook') return fbPageId.value.isNotEmpty;
    return false;
  }

  Future<void> saveApiKey(ProviderType type, String key) async {
    if (key.trim().isEmpty) return;
    savingProvider.value = type;
    try {
      final String? uid = Get.find<AuthController>().firebaseUid;
      await _secureStorage.saveApiKey(uid != null ? '${uid}_${type.name}' : type.name, key.trim());
      providerKeys[type] = key.trim();
      await _testConnection(type, key.trim());
      _syncToFirestore({firestoreApiKeyField: {type.name: key.trim()}});
    } finally {
      savingProvider.value = null;
    }
  }

  Future<void> migrateKeysToNewUid(String newUid) async {
    for (final type in ProviderType.values) {
      if (type == ProviderType.custom) continue;
      final globalKey = await _secureStorage.getApiKey(type.name);
      if (globalKey.isNotEmpty) await _secureStorage.saveApiKey('${newUid}_${type.name}', globalKey);
    }
    await _loadAllKeys();
  }

  Future<void> saveGithubKeys(List<String> keys) async {
    final filtered = keys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    githubKeys.assignAll(filtered);
    for (int i = 1; i <= 6; i++) {
      await _secureStorage.saveApiKey('github_key_$i', i <= filtered.length ? filtered[i - 1] : '');
    }
    _syncToFirestore({'github_hexa_keys': filtered});
    _showToast('✅ تم حفظ مفاتيح GitHub', isError: false);
  }

  Future<void> saveSecretKey(ProviderType type, String secretKey) async {
    if (secretKey.trim().isEmpty) return;
    await _secureStorage.saveSecretKey(type, secretKey.trim());
    providerSecrets[type] = secretKey.trim();
    _syncToFirestore({'user_secret_keys': {type.name: secretKey.trim()}});
  }

  Future<String> getSecretKey(ProviderType type) async => await _secureStorage.getSecretKey(type);

  Future<void> saveCustomEndpoint(ProviderType type, String endpoint) async {
    await _storage.saveProviderEndpoint(type.name, endpoint.trim());
    providerEndpoints[type] = endpoint.trim();
  }

  Future<void> testProviderConnection(ProviderType type) async {
    savingProvider.value = type;
    try { await _testConnection(type, getApiKey(type)); }
    finally { savingProvider.value = null; }
  }

  Future<void> testTikTokConnection() async {
    try {
      final tiktok = Get.find<TikTokService>();
      final isConnected = await tiktok.testConnection();
      _storage.writeBool('tiktok_connected', isConnected);
    } catch (e) {
      _storage.writeBool('tiktok_connected', false);
    }
  }

  Future<void> checkSerpApiStatus() async {
    isCheckingSerpApi.value = true;
    try {
      final data = await Get.find<SerpApiMasterService>().getAccountInfo();
      serpApiSearchesLeft.value = data['plan_searches_left'] ?? 0;
      _showToast('💳 الرصيد: ${serpApiSearchesLeft.value}', isError: false);
    } catch (e) { _showToast('فشل فحص الرصيد', isError: true); }
    finally { isCheckingSerpApi.value = false; }
  }

  bool get isTikTokConnected => _storage.readBool('tiktok_connected') ?? false;

  Future<void> shareApp() async {
    await SharePlus.instance.share(ShareParams(text: "🚀 جرب تطبيق صانع المحتوى الذكي!\n$latestApkUrl"));
  }

  Future<void> checkForUpdate({bool manual = false}) async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/version.json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if ((data['build'] ?? 0) > currentBuild) {
          _showUpdateDialog(version: data['version'], build: data['build'], apkUrl: data['apk_url']);
        } else if (manual) { _showToast('أنت على أحدث نسخة ✅', isError: false); }
      }
    } catch (_) {}
  }

  void _showUpdateDialog({required String version, required int build, required String apkUrl}) {
    final context = Get.context;
    if (context == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111122),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🚀 تحديث جديد متوفر',
          style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'الإصدار الجديد $version متوفر الآن للتحميل. يحتوي هذا الإصدار على تحسينات في الأداء وإصلاحات هامة.',
          style: const TextStyle(color: Colors.white70, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.white38, fontFamily: 'IBMPlexSansArabic')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              downloadAndInstallUpdate(apkUrl, version);
            },
            child: const Text('تحديث الآن ⚡', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 📥 تحميل التحديث في الخلفية وتثبيته تلقائياً
  Future<void> downloadAndInstallUpdate(String apkUrl, String version) async {
    if (isDownloadingUpdate.value) return;
    isDownloadingUpdate.value = true;
    downloadProgress.value = 0.0;
    downloadTaskMsg.value = 'جاري بدء تحميل التحديث...';

    // إظهار نافذة تقدم التحميل
    Get.dialog(
      Obx(() => PopScope(
        canPop: false, // منع الإغلاق التلقائي أثناء التحميل
        child: AlertDialog(
          backgroundColor: const Color(0xFF111122),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '⏳ جاري تحميل التحديث',
            style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: downloadProgress.value,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
              ),
              const SizedBox(height: 16),
              Text(
                '${(downloadProgress.value * 100).toStringAsFixed(0)}% مكتمل',
                style: const TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                downloadTaskMsg.value,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontFamily: 'IBMPlexSansArabic', fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )),
      barrierDismissible: false,
    );

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/smart_content_creator_v$version.apk';

      await dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
            downloadTaskMsg.value = 'جاري تنزيل ملف APK (${(received / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB)';
          }
        },
      );

      // إغلاق نافذة التقدم
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      downloadTaskMsg.value = 'تم التحميل بنجاح. جاري تشغيل التثبيت...';
      isDownloadingUpdate.value = false;

      // تشغيل مثبت النظام تلقائياً
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        Get.snackbar(
          '❌ تعذر تثبيت التحديث تلقائياً',
          'الرجاء تثبيت التحديث يدوياً من المجلد: $savePath',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      isDownloadingUpdate.value = false;
      Get.snackbar(
        '❌ فشل تنزيل التحديث',
        'حدث خطأ غير متوقع: $e',
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    }
  }


  Future<void> updateTikTokAccount(String username, String url) async {
    tiktokUsername.value = username;
    tiktokProfileUrl.value = url;
    await _storage.writeString('tiktok_username', username);
    await _storage.writeString('tiktok_profile_url', url);
  }

  Future<void> updateYoutubeAccount(String handle, String url) async {
    youtubeHandle.value = handle;
    youtubeChannelUrl.value = url;
    await _storage.writeString('youtube_handle', handle);
    await _storage.writeString('youtube_channel_url', url);
  }

  Future<void> updateInstagramAccount(String username, String url) async {
    instagramUsername.value = username;
    instagramProfileUrl.value = url;
    await _storage.writeString('instagram_username', username);
    await _storage.writeString('instagram_profile_url', url);
  }

  // ── Facebook Integration Methods ──
  Future<void> _loadFacebookSettings() async {
    fbUserToken.value = await _secureStorage.getApiKey('facebook_user_token');
    fbPageId.value = _storage.readString('facebook_page_id') ?? '';
    fbPageName.value = _storage.readString('facebook_page_name') ?? '';
    fbPageToken.value = await _secureStorage.getApiKey('facebook_page_token');
    if (fbUserToken.value.isNotEmpty && fbPageId.value.isEmpty) {
      await fetchFacebookPages();
    }
  }

  Future<void> saveFacebookUserToken(String token) async {
    fbUserToken.value = token.trim();
    await _secureStorage.saveApiKey('facebook_user_token', token.trim());
    await fetchFacebookPages();
  }

  Future<void> saveSelectedFacebookPage(String id, String name, String pageToken) async {
    fbPageId.value = id;
    fbPageName.value = name;
    fbPageToken.value = pageToken;
    await _storage.writeString('facebook_page_id', id);
    await _storage.writeString('facebook_page_name', name);
    await _secureStorage.saveApiKey('facebook_page_token', pageToken);
    _showToast('✅ تم ربط صفحة فيسبوك: $name', isError: false);
  }

  Future<void> fetchFacebookPages() async {
    final token = fbUserToken.value.trim();
    if (token.isEmpty) return;

    isFetchingFbPages.value = true;
    try {
      final response = await http.get(Uri.parse('https://graph.facebook.com/v20.0/me/accounts?access_token=$token'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          final List<dynamic> pages = data['data'];
          fbPagesList.value = pages.map<Map<String, dynamic>>((p) => {
            'id': p['id']?.toString() ?? '',
            'name': p['name']?.toString() ?? '',
            'access_token': p['access_token']?.toString() ?? '',
            'category': p['category']?.toString() ?? '',
          }).toList();
          _showToast('✅ تم جلب ${fbPagesList.length} صفحة من فيسبوك', isError: false);
        } else {
          fbPagesList.clear();
        }
      } else {
        _showToast('❌ فشل جلب الصفحات من فيسبوك', isError: true);
      }
    } catch (e) {
      _showToast('❌ خطأ أثناء الاتصال بفيسبوك: $e', isError: true);
    } finally {
      isFetchingFbPages.value = false;
    }
  }

  Future<void> disconnectFacebook() async {
    fbUserToken.value = '';
    fbPageId.value = '';
    fbPageName.value = '';
    fbPageToken.value = '';
    fbPagesList.clear();
    await _secureStorage.saveApiKey('facebook_user_token', '');
    await _secureStorage.saveApiKey('facebook_page_token', '');
    await _storage.writeString('facebook_page_id', '');
    await _storage.writeString('facebook_page_name', '');
    _showToast('⏸️ تم إلغاء ربط فيسبوك', isError: false);
  }

  Future<void> syncManagedKeysToLocal() async {
    await _syncGate.run(() async {
      try {
        final String? uid = Get.find<AuthController>().firebaseUid;
        final String prefix = uid ?? 'global';
        DocumentSnapshot? doc;
        if (uid != null) doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc == null || !doc.exists) doc = await FirebaseFirestore.instance.collection('admin_settings').doc('global_keys').get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final Map<String, dynamic> keys = data.containsKey(firestoreApiKeyField) ? Map<String, dynamic>.from(data[firestoreApiKeyField]) : data;

          // 🧩 Data Hash Guard: Deduplicate key sync
          final currentHash = keys.toString().hashCode.toString();
          if (currentHash == _lastKeysHash) {
            if (kDebugMode) debugPrint("🔄 Settings: Cloud keys haven't changed (Hash: $currentHash). Skipping local write.");
            return;
          }
          _lastKeysHash = currentHash;
          
          if (kDebugMode) debugPrint("🔄 Settings: Syncing new keys from Cloud (Hash: $currentHash)");

          for (var entry in keys.entries) {
            final name = entry.key.replaceAll('managed_key_', '').replaceAll('api_key_', '');
            final value = entry.value.toString();
            final type = ProviderType.values.firstWhereOrNull((e) => e.name == name);
            if (type != null && value.isNotEmpty) {
              await _secureStorage.saveApiKey('${prefix}_$name', value);
              await _secureStorage.saveApiKey(name, value);
              providerKeys[type] = value;
              providerStatus[type] = true;
              apiController.updateApiKey(value, isConnected: true);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ SettingsController: Failed to sync managed keys: $e");
        }
      }
    });
  }

  /// ☁️ جلب حالة الاتصال والصحة للبوابة السحابية
  Future<void> fetchGatewayHealth() async {
    isLoadingHealth.value = true;
    final sw = Stopwatch()..start();
    try {
      final gateway = Get.find<Back4AppGatewayService>();
      final res = await gateway.checkHealth();
      serverHealth.value = res;
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching gateway health: $e");
    } finally {
      sw.stop();
      gatewayLatency.value = sw.elapsedMilliseconds;
      isLoadingHealth.value = false;
    }
  }

  /// 🔑 جلب تفاصيل المفاتيح والتبديل التلقائي سحابياً
  Future<void> fetchGatewayKeysStatus() async {
    isLoadingKeys.value = true;
    try {
      final gateway = Get.find<Back4AppGatewayService>();
      final keys = await gateway.checkAllKeys();
      serverKeys.assignAll(keys);

      final usage = await gateway.getDailyUsage();
      dailyUsageCount.value = usage['requestCount'] ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching gateway keys: $e");
    } finally {
      isLoadingKeys.value = false;
    }
  }

  /// ❌ جلب سجل الأخطاء الأخيرة للبوابة
  Future<void> fetchGatewayErrors() async {
    isLoadingErrors.value = true;
    try {
      final gateway = Get.find<Back4AppGatewayService>();
      final errs = await gateway.getRecentErrors();
      gatewayErrors.assignAll(errs);
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching gateway errors: $e");
    } finally {
      isLoadingErrors.value = false;
    }
  }

  /// 🔄 تحديث جميع تشخيصات البوابة بالتوازي
  Future<void> refreshAllDiagnostics() async {
    await Future.wait([
      fetchGatewayHealth(),
      fetchGatewayKeysStatus(),
      fetchGatewayErrors(),
    ]);
  }

  /// 🧪 اختبار تفصيلي للمزودات — يُرسل طلبات متوازية لكافة الخطوط
  Future<void> runLiveTest() async {
    if (isRunningLiveTest.value) return;
    isRunningLiveTest.value = true;
    liveTestResult.value = null;
    try {
      final gateway = Get.find<Back4AppGatewayService>();
      final result = await gateway.liveTestDetailedProviders();
      liveTestResult.value = result;
    } catch (e) {
      liveTestResult.value = {
        'vertex': {
          'success': false,
          'provider': 'Vertex AI (بوابة أساسية)',
          'model': 'gemini-2.5-flash',
          'keyName': 'Google Vertex Service Account',
          'latencyMs': 0,
          'response': 'خطأ في اختبار البوابة: $e',
        },
        'cloudPool': {
          'success': false,
          'provider': 'Gemini Key Pool (بوابة احتياطية)',
          'model': 'gemini-2.0-flash',
          'keyName': '—',
          'latencyMs': 0,
          'response': 'خطأ في اختبار البوابة: $e',
        },
        'localKey': {
          'success': false,
          'provider': 'Google AI Studio (مفتاح محلي)',
          'model': 'gemini-2.5-flash',
          'keyName': '—',
          'latencyMs': 0,
          'response': 'خطأ في اختبار المفتاح: $e',
        }
      };
    } finally {
      isRunningLiveTest.value = false;
    }
  }

  void _syncToFirestore(Map<String, dynamic> data) async {
    try {
      final uid = Get.find<AuthController>().firebaseUid;
      if (uid != null) await FirebaseFirestore.instance.collection('users').doc(uid).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  void updateLastImageProvider(String provider) {
    lastImageProvider.value = provider;
    _storage.writeString('lastImageProvider', provider);
  }

  void updateLastTextProvider(String provider) {
    lastTextProvider.value = provider;
    _storage.writeString('lastTextProvider', provider);
  }
}

class _SyncGate {
  bool _running = false;
  DateTime? _lastRun;
  Future<void> run(Future<void> Function() task) async {
    if (_running) return;
    final now = DateTime.now();
    if (_lastRun != null && now.difference(_lastRun!) < const Duration(seconds: 15)) return;
    _running = true;
    try {
      _lastRun = now;
      await task();
    } finally {
      _running = false;
    }
  }
}
