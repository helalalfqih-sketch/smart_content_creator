import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:io' as dart_io;
import 'snackbar_utils.dart';

class ErrorHandler {
  // 🔹 تسجيل الخطأ للمطور فقط (دون إزعاج المستخدم)
  static void logError(String source, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('❌ Error in $source: $error');
    if (stackTrace != null) debugPrint('Stacktrace: $stackTrace');
    
    developer.log(
      '❌ Error in $source: $error',
      name: 'ErrorHandler',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // 0. التحقق من الإنترنت (استباقي)
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await dart_io.InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      showNetworkError(); 
      return false;
    }
  }

  // 1. الشبكة
  static void showNetworkError({VoidCallback? onRetry}) {
    SnackBarUtils.showSmartSnackBar(
      title: 'خطأ اتصال 📶',
      message: 'تعذر الاتصال بالشبكة. تأكد من الإنترنت وحاول مرة أخرى.',
      isError: true,
    );
  }

  // 2. الملفات
  static void showFileError() {
    SnackBarUtils.showSmartSnackBar(
      title: 'تنبيه ملف 📁',
      message: 'لم يتم اختيار ملف أو حدث خطأ أثناء التحميل.',
      isError: true, // Treated as error/warning
    );
  }

  // 3. قاعدة البيانات
  static void showDatabaseError(dynamic error) {
    logError('Database', error); // Log first
    SnackBarUtils.showSmartSnackBar(
      title: 'خطأ بيانات 💾',
      message: 'تعذر حفظ البيانات: $error',
      isError: true,
    );
  }
  
  // 4. خطأ عام
  static void showGenericError([String? details]) {
    if (details != null) logError('Generic', details);
    SnackBarUtils.showSmartSnackBar(
      title: 'تنبيه ⚠️',
      message: 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.',
      isError: true,
    );
  }

  // 🧠 Smart Error Mapping
  static SmartException mapError(Object e) {
    // If it's already a SmartException, return it
    if (e is SmartException) return e;

    final msg = e.toString().toLowerCase();

    // 1. Connection & Network Errors
    if (msg.contains('connection closed') || 
        msg.contains('clientexception') || 
        msg.contains('socketexception') || 
        msg.contains('connection refused') ||
        msg.contains('network is unreachable') ||
        msg.contains('sem_timeout')) {
      return SmartException(
        "⚠️ ضعف في الاتصال، جاري إعادة المحاولة...",
        technicalDetails: msg,
        canRetry: true,
      );
    }

    // 2. Timeout
    if (msg.contains('timeout') || msg.contains('deadline exceeded')) {
      return SmartException(
        "⏳ استغرق الخادم وقتاً طويلاً، حاول مجدداً.",
        technicalDetails: msg,
        canRetry: true,
      );
    }

    // 3. API Limit / Quota
    if (msg.contains('429') || msg.contains('quota') || msg.contains('insufficient_quota')) {
      return SmartException(
        "🛑 تم تجاوز حد الاستخدام لهذه الفترة.",
        technicalDetails: msg,
        canRetry: false,
      );
    }

    // 4. Auth Errors
    if (msg.contains('401') || msg.contains('403') || msg.contains('unauthorized')) {
      return SmartException(
        "🔐 مفتاح API غير صالح أو منتهي.",
        technicalDetails: msg,
        canRetry: false,
      );
    }

    // 5. Server Errors
    if (msg.contains('500') || msg.contains('502') || msg.contains('503') || msg.contains('server error')) {
      return SmartException(
        "☁️ الخادم يواجه مشكلة مؤقتة.",
        technicalDetails: msg,
        canRetry: true,
      );
    }
    
    // 6. Custom "Smart" Errors (from our own code)
    if (e.toString().startsWith('Exception: ❌')) {
      return SmartException(
        e.toString().replaceAll('Exception: ', ''),
        technicalDetails: msg,
        canRetry: false,
      );
    }

    // Default
    return SmartException("⚠️ حدث خطأ غير متوقع: ${msg.length > 50 ? "${msg.substring(0, 50)}..." : msg}", technicalDetails: msg);
  }
}

class SmartException implements Exception {
  final String message;
  final String? technicalDetails;
  final bool canRetry;

  SmartException(this.message, {this.technicalDetails, this.canRetry = true});

  @override
  String toString() => message;
}
