import 'package:logger/logger.dart';

// نظام تسجيل مركزي وموحد
class LogService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// ℹ️ تسجيل المعلومات العامة
  static void info(String message, {String? tag}) {
    _logger.i("${tag != null ? '[$tag] ' : ''}$message");
  }

  /// ⚠️ تسجيل التحذيرات
  static void warning(String message, {String? tag}) {
    _logger.w("${tag != null ? '[$tag] ' : ''}$message");
  }

  /// ❌ تسجيل الأخطاء
  static void error(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    _logger.e("${tag != null ? '[$tag] ' : ''}$message", error: error, stackTrace: stackTrace);
  }

  /// ✅ تسجيل العمليات الناجحة
  static void success(String message, {String? tag}) {
    _logger.i("✅ ${tag != null ? '[$tag] ' : ''}$message");
  }

  /// 🧩 تسجيل العمليات (Debug)
  static void debug(String message, {String? tag}) {
    _logger.d("${tag != null ? '[$tag] ' : ''}$message");
  }
}
