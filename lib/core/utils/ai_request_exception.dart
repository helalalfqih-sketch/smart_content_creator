import 'dart:io';
import 'package:dio/dio.dart' as dio;

/// Safe, structured failures. Never retain request headers, images or response bodies.
class AiRequestException implements Exception {
  final String code;
  final String message;
  final bool canRetry;

  const AiRequestException(this.code, this.message, {this.canRetry = false});

  static const invalidResponse = AiRequestException(
    'invalid_response',
    'وصل رد غير مكتمل أو غير صالح من الخدمة. أعد المحاولة لاحقاً.',
    canRetry: true,
  );

  factory AiRequestException.http(int? status) {
    final message = switch (status) {
      401 || 403 => 'تحقق من مفتاح الخدمة وصلاحياته في الإعدادات.',
      402 => 'رصيد الخدمة غير كافٍ لإتمام الطلب.',
      404 => 'النموذج أو المزود المختار غير متاح حالياً.',
      413 => 'الصورة كبيرة جداً. اختر صورة أصغر.',
      429 => 'تم تجاوز حد الطلبات. انتظر قليلاً ثم أعد المحاولة.',
      400 || 422 => 'رفض المزود الطلب. تحقق من دعم النموذج لصيغة الصورة.',
      _ => 'تعذر إتمام الطلب لدى المزود. أعد المحاولة لاحقاً.',
    };
    return AiRequestException(
      status == null ? 'provider_error' : 'http_$status',
      message,
      canRetry: status == 429 || (status != null && status >= 500),
    );
  }

  factory AiRequestException.transport(dio.DioException error) {
    final cause = error.error;
    if (error.type == dio.DioExceptionType.badCertificate ||
        cause is TlsException) {
      return const AiRequestException(
        'tls_error',
        'تعذر إنشاء اتصال آمن بالخدمة. تحقق من تاريخ الهاتف وجرّب شبكة أخرى.',
      );
    }
    switch (error.type) {
      case dio.DioExceptionType.connectionTimeout:
        return const AiRequestException(
          'connect_timeout',
          'انتهت مهلة الاتصال بالخدمة. تحقق من الشبكة وأعد المحاولة.',
          canRetry: true,
        );
      case dio.DioExceptionType.sendTimeout:
        return const AiRequestException(
          'upload_timeout',
          'انتهت مهلة رفع الصورة. جرّب صورة أصغر أو شبكة أخرى.',
          canRetry: true,
        );
      case dio.DioExceptionType.receiveTimeout:
        return const AiRequestException(
          'response_timeout',
          'لم تصل نتيجة التحليل ضمن المهلة. راجع السجل قبل إعادة الطلب.',
          canRetry: true,
        );
      default:
        break;
    }
    if (error.response?.statusCode != null &&
        error.response!.statusCode! >= 400) {
      return AiRequestException.http(error.response!.statusCode);
    }
    if (cause is FormatException) return invalidResponse;
    if (cause is SocketException) {
      if (cause.message.toLowerCase().contains('failed host lookup')) {
        return const AiRequestException(
          'dns_error',
          'تعذر الوصول إلى عنوان الخدمة. جرّب شبكة أخرى ثم أعد إرسال الصورة.',
          canRetry: true,
        );
      }
      return const AiRequestException(
        'connection_error',
        'تعذر الاتصال بالخدمة أثناء طلب التحليل. جرّب شبكة أخرى ثم أعد إرسال الصورة.',
        canRetry: true,
      );
    }
    if (cause is HttpException) {
      return const AiRequestException(
        'connection_interrupted',
        'انقطع الاتصال قبل اكتمال الرد. راجع السجل قبل إعادة الطلب.',
        canRetry: true,
      );
    }
    if (error.type == dio.DioExceptionType.connectionError) {
      return const AiRequestException(
        'connection_error',
        'تعذر الاتصال بالخدمة أثناء طلب التحليل. جرّب شبكة أخرى ثم أعد إرسال الصورة.',
        canRetry: true,
      );
    }
    return const AiRequestException(
      'request_error',
      'تعذر إكمال طلب التحليل داخل التطبيق. لم تُستلم نتيجة صالحة.',
    );
  }

  @override
  String toString() => '$message (رمز: $code)';
}
