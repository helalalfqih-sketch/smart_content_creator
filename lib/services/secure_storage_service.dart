import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../core/models/api_provider.dart'; // For ProviderType

class SecureStorageService extends GetxService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveApiKey(String provider, String key) async {
    await _storage.write(key: 'api_key_$provider', value: key);
  }

  Future<String> getApiKey(String provider) async {
    return await _storage.read(key: 'api_key_$provider') ?? '';
  }

  Future<void> deleteApiKey(String provider) async {
    await _storage.delete(key: 'api_key_$provider');
  }

  // Secret Key methods for dual-key providers (e.g., Kling)
  Future<void> saveSecretKey(ProviderType type, String key) async {
    await _storage.write(key: 'secret_key_${type.name}', value: key);
  }

  Future<String> getSecretKey(ProviderType type) async {
    return await _storage.read(key: 'secret_key_${type.name}') ?? '';
  }

  // Gemini OAuth Token Methods
  Future<void> saveGeminiToken(String token) async {
    await _storage.write(key: 'gemini_oauth_token', value: token);
  }

  Future<String> getGeminiToken() async {
    return await _storage.read(key: 'gemini_oauth_token') ?? '';
  }

  Future<void> deleteGeminiToken() async {
    await _storage.delete(key: 'gemini_oauth_token');
  }

  // Instagram OAuth Token Methods
  Future<void> saveInstagramToken(String token) async {
    await _storage.write(key: 'instagram_access_token', value: token);
  }

  Future<String> getInstagramToken() async {
    return await _storage.read(key: 'instagram_access_token') ?? '';
  }

  Future<void> deleteInstagramToken() async {
    await _storage.delete(key: 'instagram_access_token');
  }

  // Instagram OAuth State (CSRF protection)
  Future<void> saveInstagramState(String state) async {
    await _storage.write(key: 'instagram_oauth_state', value: state);
  }

  Future<String> getInstagramState() async {
    return await _storage.read(key: 'instagram_oauth_state') ?? '';
  }

  // TikTok OAuth Token Methods
  Future<void> saveTikTokToken(String token) async {
    await _storage.write(key: 'tiktok_access_token', value: token);
  }

  Future<String> getTikTokToken() async {
    return await _storage.read(key: 'tiktok_access_token') ?? '';
  }

  Future<void> deleteTikTokToken() async {
    await _storage.delete(key: 'tiktok_access_token');
  }

  // TikTok Refresh Token
  Future<void> saveTikTokRefreshToken(String token) async {
    await _storage.write(key: 'tiktok_refresh_token', value: token);
  }

  Future<String> getTikTokRefreshToken() async {
    return await _storage.read(key: 'tiktok_refresh_token') ?? '';
  }

  Future<void> deleteTikTokRefreshToken() async {
    await _storage.delete(key: 'tiktok_refresh_token');
  }

  // TikTok OAuth State (CSRF protection)
  Future<void> saveTikTokState(String state) async {
    await _storage.write(key: 'tiktok_oauth_state', value: state);
  }

  Future<String> getTikTokState() async {
    return await _storage.read(key: 'tiktok_oauth_state') ?? '';
  }

  // TikTok PKCE Code Verifier
  Future<void> saveTikTokCodeVerifier(String verifier) async {
    await _storage.write(key: 'tiktok_code_verifier', value: verifier);
  }

  Future<String> getTikTokCodeVerifier() async {
    return await _storage.read(key: 'tiktok_code_verifier') ?? '';
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // -----------------------------------------------------------------------
  // 🏪 Store Signature Methods (توقيع المتجر)
  // -----------------------------------------------------------------------

  Future<void> saveStoreSignature({
    required String storeName,
    required String phone,
    required String address,
    required String delivery,
  }) async {
    await _storage.write(key: 'store_name', value: storeName);
    await _storage.write(key: 'store_phone', value: phone);
    await _storage.write(key: 'store_address', value: address);
    await _storage.write(key: 'store_delivery', value: delivery);
  }

  Future<Map<String, String>> getStoreSignature() async {
    return {
      'storeName': await _storage.read(key: 'store_name') ?? '',
      'phone':     await _storage.read(key: 'store_phone') ?? '',
      'address':   await _storage.read(key: 'store_address') ?? '',
      'delivery':  await _storage.read(key: 'store_delivery') ?? '',
    };
  }

  Future<bool> hasStoreSignature() async {
    final name = await _storage.read(key: 'store_name');
    return name != null && name.isNotEmpty;
  }
}
