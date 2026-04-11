import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/managed_ai_service.dart';
import '../core/models/api_provider.dart';

/// Unified engine for SerpApi requests to fetch real data from Google, YouTube, Amazon, etc.
class SerpApiMasterService {
  SerpApiMasterService._internal();
  static final SerpApiMasterService _instance = SerpApiMasterService._internal();
  factory SerpApiMasterService() => _instance;

  final dio.Dio _dio = dio.Dio();
  static const String _baseUrl = 'https://serpapi.com/search.json';

  String? _apiKey;

  Future<void> _ensureApiKey() async {
    // 💡 Always fetch the latest key from Settings because the user might have updated it.
    final settings = Get.find<SettingsController>();
    final settingsKey = settings.getApiKey(ProviderType.serpapi);
    
    if (settingsKey.isNotEmpty) {
      _apiKey = settingsKey;
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      // 🧠 Managed AI Fallback
      try {
        final auth = Get.find<AuthController>();
        final uid = auth.firebaseUid;
        if (uid != null) {
          final managedAi = Get.find<ManagedAiService>();
          final mKey = await managedAi.getManagedKey(uid, provider: ProviderType.serpapi);
          if (mKey != null && mKey.isNotEmpty) {
            _apiKey = mKey;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint("SerpApi fallback failed: $e");
      }
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('لم يتم إعداد مفتاح SerpApi. يرجى إضافته في إعدادات التطبيق أو من قاعدة البيانات.');
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  /// Saves an API key
  Future<void> setApiKey(String key) async {
    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) {
      throw Exception('API key cannot be empty');
    }
    await Get.find<SettingsController>().saveApiKey(ProviderType.serpapi, trimmedKey);
    _apiKey = trimmedKey;
  }

  /// 💳 SerpApi Account Info: Get remaining credits and monthly usage
  Future<Map<String, dynamic>> getAccountInfo({dio.CancelToken? cancelToken}) async {
    if (!await _checkInternetConnection()) {
      throw const SocketException('لا يوجد اتصال بالإنترنت');
    }

    await _ensureApiKey();

    final url = 'https://serpapi.com/account.json?api_key=${_apiKey!}';

    try {
      final response = await _dio.get(url, cancelToken: cancelToken);
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 401 || response.statusCode == 429) {
        // 🔄 Smart Fallback for Account Info
        final uid = Get.find<AuthController>().firebaseUid;
        if (uid != null) {
          final mKey = await Get.find<ManagedAiService>().getManagedKey(uid, provider: ProviderType.serpapi);
          if (mKey != null && mKey.isNotEmpty && mKey != _apiKey) {
            _apiKey = mKey;
            final retryUrl = 'https://serpapi.com/account.json?api_key=$mKey';
            final retryRes = await _dio.get(retryUrl, cancelToken: cancelToken);
            if (retryRes.statusCode == 200) {
              return retryRes.data as Map<String, dynamic>;
            }
          }
        }
        final errorData = response.data;
        throw Exception('فشل جلب الحساب (${response.statusCode}): ${errorData['error'] ?? response.data}');
      }
      
      throw Exception('فشل جلب الحساب: استجابة غير متوقعة من السيرفر');
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) {
        throw Exception('🚫 تم إلغاء جلب بيانات الحساب');
      }
      if (kDebugMode) debugPrint("SERPAPI ACCOUNT ERROR => $e");
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint("SERPAPI ACCOUNT ERROR => $e");
      rethrow;
    }
  }

  /// Core fetch method for any SerpApi engine
  Future<Map<String, dynamic>> fetch(String engine, Map<String, String> parameters, {dio.CancelToken? cancelToken}) async {
    if (!await _checkInternetConnection()) {
      throw const SocketException('لا يوجد اتصال بالإنترنت');
    }

    await _ensureApiKey();

    final queryParams = {
      'engine': engine,
      'api_key': _apiKey!,
      ...parameters,
    };

    try {
      final response = await _dio.get(_baseUrl, queryParameters: queryParams, cancelToken: cancelToken);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else if (response.statusCode == 401 || response.statusCode == 429) {
        // 🔄 Smart Fallback: If 401/Invalid Key or 429/Limit Reached, try to use Managed Key once
        if (kDebugMode) debugPrint("🔄 SerpApi: ${response.statusCode} Detected. Attempting Managed Fallback...");
        
        final uid = Get.find<AuthController>().firebaseUid;
        if (uid != null) {
          final mKey = await Get.find<ManagedAiService>().getManagedKey(uid, provider: ProviderType.serpapi);
          if (mKey != null && mKey.isNotEmpty) {
             if (mKey == _apiKey) {
               if (kDebugMode) debugPrint("🔄 SerpApi Fallback: Managed key is identical to the currently used key. No point in retrying.");
             } else {
                // Retry with new key
                final retryParams = {...queryParams, 'api_key': mKey};
                final retryRes = await _dio.get(_baseUrl, queryParameters: retryParams, cancelToken: cancelToken);
                if (retryRes.statusCode == 200) {
                  _apiKey = mKey; // Update to managed key for future usage
                  if (kDebugMode) debugPrint("✅ SerpApi Fallback SUCCESS with Managed Key.");
                  return retryRes.data as Map<String, dynamic>;
                } else {
                 if (kDebugMode) {
                   final retryError = retryRes.data;
                   debugPrint("❌ SerpApi Fallback FAILED with Managed Key (${retryRes.statusCode}): ${retryError['error'] ?? retryRes.data}");
                 }
                 // If the fallback also failed with 429, we should report it
                 if (retryRes.statusCode == 429) {
                   throw Exception('خطأ من SerpApi (429): المفتاح الاحتياطي للإدارة قد نفد رصيده أيضاً!');
                 }
               }
             }
          } else {
             if (kDebugMode) debugPrint("🔄 SerpApi Fallback: No Managed Key available for fallback.");
          }
        }
        
        final error = response.data;
        throw Exception('خطأ من SerpApi (${response.statusCode}): ${error['error'] ?? response.data}');
      }
      
      throw Exception('خطأ من SerpApi: استجابة غير متوقعة من السيرفر (${response.statusCode})');
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) {
        throw Exception('🚫 تم إلغاء طلب البحث');
      }
      if (kDebugMode) debugPrint("SERPAPI ERROR => $e");
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint("SERPAPI ERROR => $e");
      rethrow;
    }
  }

  /// 🚀 جلب بيانات البروفايل (فيسبوك) بشكل هيكلي (JSON)
  Future<Map<String, dynamic>> getFacebookProfile(String profileId, {dio.CancelToken? cancelToken}) async {
    final params = {
      'engine': 'facebook_profile',
      'profile_id': profileId,
    };
    return await fetch('facebook_profile', params, cancelToken: cancelToken);
  }

  /// 🚀 محرك عام لجلب بيانات أي بروفايل من SerpApi
  Future<Map<String, dynamic>> getSocialProfile(String engine, String profileId, {dio.CancelToken? cancelToken}) async {
    final params = {
      'engine': engine,
      'profile_id': profileId,
    };
    return await fetch(engine, params, cancelToken: cancelToken);
  }

  /// 🔍 محرك البحث العام (قوقل) لاستخدامه في استخراج البيانات من الـ Snippets
  Future<Map<String, dynamic>> googleSearch(String query, {dio.CancelToken? cancelToken}) async {
    final params = {
      'engine': 'google',
      'q': query,
      'num': '1', // نحتاج أول نتيجة فقط غالباً
    };
    return await fetch('google', params, cancelToken: cancelToken);
  }
}
