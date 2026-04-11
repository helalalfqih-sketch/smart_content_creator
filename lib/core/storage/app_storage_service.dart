import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/secure_storage_service.dart';
import 'storage_keys.dart';

class AppStorageService extends GetxService {
  late GetStorage _storage;
  final SecureStorageService _secureStorage = Get.find<SecureStorageService>();

  /// ⚡ Initialize and perform migration
  Future<AppStorageService> init() async {
    await GetStorage.init();
    _storage = GetStorage();
    
    // 🚚 Perform one-time migration from SharedPreferences to GetStorage
    await _migrateFromSharedPreferences();
    
    return this;
  }

  /// 🚚 Migration Engine: SharedPreferences -> GetStorage
  Future<void> _migrateFromSharedPreferences() async {
    final hasMigrated = _storage.read<bool>('storage_migrated') ?? false;
    if (hasMigrated) return;

    if (kDebugMode) debugPrint("🚚 AppStorage: Starting migration from SharedPreferences...");
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        final value = prefs.get(key);
        if (value != null) {
          await _storage.write(key, value);
          if (kDebugMode) debugPrint("✅ AppStorage Migrated: $key");
        }
      }
      
      await _storage.write('storage_migrated', true);
      if (kDebugMode) debugPrint("🏁 AppStorage: Migration completed successfully.");
    } catch (e) {
      if (kDebugMode) debugPrint("❌ AppStorage Migration Error: $e");
    }
  }

  // ==========================================
  // 🟢 General Storage (GetStorage)
  // ==========================================

  T? read<T>(String key, {T? defaultValue}) {
    return _storage.read<T>(key) ?? defaultValue;
  }

  String? readString(String key, {String? defaultValue}) {
    final val = _storage.read(key);
    if (val == null) return defaultValue;
    return val.toString();
  }
  bool? readBool(String key, {bool? defaultValue}) => read<bool>(key, defaultValue: defaultValue);
  int? readInt(String key, {int? defaultValue}) => read<int>(key, defaultValue: defaultValue);

  Future<void> write(String key, dynamic value) async {
    await _storage.write(key, value);
  }

  Future<void> writeString(String key, String value) => write(key, value);
  Future<void> writeBool(String key, bool value) => write(key, value);
  Future<void> writeInt(String key, int value) => write(key, value);

  Future<void> remove(String key) async {
    await _storage.remove(key);
  }

  // ==========================================
  // 🔐 Secure Storage (Facade)
  // ==========================================

  Future<void> writeSecure(String key, String value) async {
    await _secureStorage.saveApiKey(key, value);
  }

  Future<String> readSecure(String key) async {
    return await _secureStorage.getApiKey(key);
  }

  Future<void> deleteSecure(String key) async {
    await _secureStorage.deleteApiKey(key);
  }

  // ==========================================
  // 🏗️ Convenience Methods (Commonly Used)
  // ==========================================

  // ==========================================
  // 🏢 Provider Specific Storage
  // ==========================================

  String? getProviderApiKey(String providerName) => readString(StorageKeys.apiKeyKey(providerName));
  Future<void> saveProviderApiKey(String providerName, String apiKey) => writeString(StorageKeys.apiKeyKey(providerName), apiKey);

  String? getProviderEndpoint(String providerName) => readString(StorageKeys.endpointKey(providerName));
  Future<void> saveProviderEndpoint(String providerName, String endpoint) => writeString(StorageKeys.endpointKey(providerName), endpoint);

  Future<void> saveTestResult(String providerName, bool success) async {
    final now = DateTime.now().toIso8601String();
    await writeString(StorageKeys.testTimeKey(providerName), now);
    await writeBool(StorageKeys.testSuccessKey(providerName), success);
  }

  bool? getLastTestSuccess(String providerName) => readBool(StorageKeys.testSuccessKey(providerName));
  
  DateTime? getLastTestTime(String providerName) {
    final timeStr = readString(StorageKeys.testTimeKey(providerName));
    return timeStr != null ? DateTime.tryParse(timeStr) : null;
  }
}
