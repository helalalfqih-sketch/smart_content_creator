import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../services/global_config_service.dart';

/// Unified engine for SerpApi requests to fetch real data from Google, YouTube, Amazon, etc.
class SerpApiMasterService {
  SerpApiMasterService._internal();
  static final SerpApiMasterService _instance = SerpApiMasterService._internal();
  factory SerpApiMasterService() => _instance;

  final dio.Dio _dio = dio.Dio();
  static const String _baseUrl = 'https://serpapi.com/search.json';

  String? _apiKey;

  Future<void> _ensureApiKey() async {
    // 1. Check for personal key in Settings
    final settings = Get.find<SettingsController>();
    final settingsKey = settings.getApiKey(ProviderType.serpapi);
    
    if (settingsKey.isNotEmpty) {
      _apiKey = settingsKey;
      return;
    }

    // 2. 🌍 Use Admin Key if personal key is missing
    final globalConfig = Get.find<GlobalConfigService>();
    final adminKey = await globalConfig.getAdminApiKey('serpapi');

    if (adminKey != null && adminKey.isNotEmpty) {
      if (kDebugMode) debugPrint('🔑 [SerpApi] Using Admin Fallback Key');
      _apiKey = adminKey;
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('لم يتم إعداد مفتاح SerpApi. يرجى إضافته في إعدادات التطبيق أو التواصل مع الإدارة.');
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
  /// Supports both GET (standard) and POST (for file uploads)
  Future<Map<String, dynamic>> fetch(String engine, Map<String, dynamic> parameters, {dio.CancelToken? cancelToken}) async {
    if (!await _checkInternetConnection()) {
      throw const SocketException('لا يوجد اتصال بالإنترنت');
    }

    await _ensureApiKey();

    final queryParams = {
      'engine': engine,
      'api_key': _apiKey!,
    };

    try {
      dio.Response response;
      
      // 🚀 Check if any parameter is a File path or binary data for upload
      if (parameters.containsKey('file') && parameters['file'] is String && File(parameters['file']).existsSync()) {
        final filePath = parameters['file'] as String;
        final formData = dio.FormData.fromMap({
          ...queryParams,
          ...parameters,
          'file': await dio.MultipartFile.fromFile(filePath),
        });

        response = await _dio.post(_baseUrl, data: formData, cancelToken: cancelToken);
      } else {
        // Standard GET request
        response = await _dio.get(_baseUrl, queryParameters: {...queryParams, ...parameters}, cancelToken: cancelToken);
      }

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
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
