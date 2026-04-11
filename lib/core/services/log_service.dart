import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 📖 LogService: الموثق المركزي لعمليات التطبيق (The Central Truth)
/// يحل محل print و debugPrint بعناية وسرعة.
class LogService {
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('ℹ️ [INFO]${tag != null ? ' [$tag]' : ''}: $message', name: 'APP');
    }
  }

  static void error(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    if (kDebugMode) {
      developer.log(
        '❌ [ERROR]${tag != null ? ' [$tag]' : ''}: $message',
        error: error,
        stackTrace: stackTrace,
        name: 'APP',
      );
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('⚠️ [WARNING]${tag != null ? ' [$tag]' : ''}: $message', name: 'APP');
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('✅ [SUCCESS]${tag != null ? ' [$tag]' : ''}: $message', name: 'APP');
    }
  }
}
