import 'dart:async';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import '../utils/log_service.dart';

/// 🏷️ تصنيفات الأخطاء الاحترافية
enum ApiErrorType {
  auth, // 401: مشكلة في المفتاح
  quota, // 402: انتهاء الرصيد
  rateLimit, // 429: تجاوز سرعة الطلبات
  server, // 5xx: مشكلة من المصدر
  network, // مشاكل اتصال
  invalid, // 400: مدخلات خاطئة
  unknown
}

/// 🚀 Enterprise API Manager
/// يدير المحاولات، تصنيف الأخطاء، والتحكم في التدفق
class EnterpriseApiClient {
  final dio.Dio _dio = dio.Dio();

  // طابور الطلبات النشطة لمنع التصادم
  final Map<String, DateTime> _lastRequestTimes = {};

  // إعدادات افتراضية
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);

  // 🧪 نظام محاكاة الأعطال للاختبار (Fault Injection)
  static ApiErrorType? debugForceError;

  EnterpriseApiClient() {
    _dio.interceptors.add(dio.LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      logPrint: (obj) => LogService.debug('📡 [API_LOG]: $obj', tag: 'Network'),
    ));
  }

  /// 🛠️ الدالة الرئيسية لإرسال الطلبات مع نظام حماية كامل
  Future<dio.Response> request({
    required String url,
    required String method,
    required String providerName,
    Map<String, dynamic>? headers,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dio.ResponseType? responseType,
    int retryCount = 0,
    dio.CancelToken? cancelToken,
  }) async {
    return await requestInner(
      url: url,
      method: method,
      providerName: providerName,
      headers: headers,
      data: data,
      queryParameters: queryParameters,
      responseType: responseType,
      retryCount: retryCount,
      cancelToken: cancelToken,
    );
  }

  /// 🛠️ الدالة الرئيسية لإرسال الطلبات مع نظام حماية كامل
  Future<dio.Response> requestInner({
    required String url,
    required String method,
    required String providerName,
    Map<String, dynamic>? headers,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dio.ResponseType? responseType,
    int retryCount = 0,
    dio.CancelToken? cancelToken,
  }) async {
    // 🧪 اختبار الـ Fallback: محاكاة فشل متعمد
    if (debugForceError != null) {
      final forcedError = debugForceError!;
      throw EnterpriseApiException(
        type: forcedError,
        message: "🧪 [SIMULATED ERROR]: المحاكي مفعل لنوع $forcedError",
      );
    }

    try {
      // 1️⃣ استراتيجية الـ Rate Limiting الاستباقي
      await _preRequestDelay(providerName);

      final response = await _dio.request(
        url,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: dio.Options(
          method: method,
          headers: headers,
          responseType: responseType ?? dio.ResponseType.json,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 20),
        ),
      );

      _lastRequestTimes[providerName] = DateTime.now();
      return response;
    } on dio.DioException catch (e) {
      // 🛡️ Handle cancellation explicitly
      if (e.type == dio.DioExceptionType.cancel) {
        throw EnterpriseApiException(
          type: ApiErrorType.network,
          message: "🚫 تم إلغاء الطلب من قبل المستخدم",
          originalError: e,
        );
      }

      final errorType = _classifyError(e);

      // 2️⃣ استراتيجية إعادة المحاولة الذكية (Retry Strategy)
      if (_shouldRetry(errorType, retryCount)) {
        final delay = initialRetryDelay * (retryCount + 1);
        debugPrint(
            '🔄 [RETRY]: $providerName failed ($errorType). Retrying in ${delay.inSeconds}s...');

        await Future.delayed(delay);
        return requestInner(
          url: url,
          method: method,
          providerName: providerName,
          headers: headers,
          data: data,
          queryParameters: queryParameters,
          retryCount: retryCount + 1,
          cancelToken: cancelToken,
        );
      }

      // 3️⃣ رمي خطأ مصنف بدلاً من خطأ Dio خام
      throw EnterpriseApiException(
        type: errorType,
        message: _getFriendlyErrorMessage(errorType, e),
        originalError: e,
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// 🛡️ تأخير الطلبات لتجنب الـ Rate Limit
  Future<void> _preRequestDelay(String provider) async {
    if (_lastRequestTimes.containsKey(provider)) {
      final lastReq = _lastRequestTimes[provider]!;
      final diff = DateTime.now().difference(lastReq);

      // نضمن وجود 1 ثانية على الأقل بين الطلبات لنفس المزود
      if (diff.inMilliseconds < 1000) {
        await Future.delayed(
            Duration(milliseconds: 1000 - diff.inMilliseconds));
      }
    }
  }

  /// 🕵️ تصنيف الأخطاء
  ApiErrorType _classifyError(dio.DioException e) {
    if (e.type == dio.DioExceptionType.connectionTimeout ||
        e.type == dio.DioExceptionType.receiveTimeout) {
      return ApiErrorType.network;
    }

    final status = e.response?.statusCode;
    switch (status) {
      case 401:
        return ApiErrorType.auth;
      case 402:
        return ApiErrorType.quota;
      case 429:
        return ApiErrorType.rateLimit;
      case 400:
      case 403:
      case 404:
        return ApiErrorType.invalid;
      case 500:
      case 502:
      case 503:
        return ApiErrorType.server;
      default:
        return ApiErrorType.unknown;
    }
  }

  /// 🔄 هل يجب إعادة المحاولة؟
  bool _shouldRetry(ApiErrorType type, int currentRetry) {
    if (currentRetry >= maxRetries) {
      return false;
    }

    // ⚡ Optimization: Never retry for rate limit as we have an instant fallback system
    // This removes the 2s delay between failing the primary and trying the secondary.
    if (type == ApiErrorType.rateLimit) {
      return false;
    }

    // نعيد المحاولة فقط في حالة مشاكل السيرفر أو الشبكة
    return type == ApiErrorType.server || type == ApiErrorType.network;
  }

  /// 💬 رسائل خطأ ودودة للمستخدم
  String _getFriendlyErrorMessage(ApiErrorType type, dio.DioException e) {
    switch (type) {
      case ApiErrorType.auth:
        return "مفتاح الـ API غير صالح أو منتهي الصلاحية.";
      case ApiErrorType.quota:
        return "لقد استهلكت كامل رصيدك في هذه الخدمة.";
      case ApiErrorType.rateLimit:
        return "طلبات سريعة جداً! النظام يقوم بالتهدئة الآن.";
      case ApiErrorType.server:
        return "عذراً، سيرفر الخدمة يواجه ضغطاً حالياً.";
      case ApiErrorType.network:
        return "تحقق من اتصالك بالإنترنت.";
      case ApiErrorType.invalid:
        return "المدخلات غير مدعومة من قبل الذكاء الاصطناعي.";
      default:
        return e.message ?? "حدث خطأ غير متوقع.";
    }
  }
}

/// 📦 كائن الخطأ المصنف
class EnterpriseApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final dynamic originalError;
  final int? statusCode;

  EnterpriseApiException({
    required this.type,
    required this.message,
    this.originalError,
    this.statusCode,
  });

  @override
  String toString() => message;
}
