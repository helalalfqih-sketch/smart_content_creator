import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    // هذه العلامة 🚀 ستجعل من السهل عليك البحث عن رسائلك وسط زحام الـ Logs
    debugPrint('🚀 [APP LOG]: $message');
  }
  
  static void error(String message, [Object? error]) {
    debugPrint('❌ [ERROR]: $message | $error');
  }
}
