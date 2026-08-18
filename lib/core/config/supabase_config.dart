import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ⚡ إعدادات Supabase المركزية للمشروع
class SupabaseConfig {
  /// 🌐 رابط المشروع الخاص بصانع المحتوى الذكي
  static const String url = 'https://blfgpdflupfoxmzynred.supabase.co';

  /// 🔑 المفتاح العام (Publishable Key / Anon Key)
  /// يرجى التأكد من وضع المفتاح الكامل الخاص بمشروع blfgpdflupfoxmzynred
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJsZmdwZGZsdXBmb3htenlucmVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAwMDAwMDAsImV4cCI6MjA1NTU1NTU1NX0.placeholder';

  /// عميل Supabase الرئيسي للوصول المباشر
  static SupabaseClient get client => Supabase.instance.client;

  /// حالة تسجيل الدخول الحالية
  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isAuthenticated => currentUser != null;

  /// 🚀 تهيئة العميل عند إقلاع التطبيق
  static Future<void> initialize({String? customAnonKey}) async {
    try {
      final keyToUse = customAnonKey ?? anonKey;
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: keyToUse,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: kDebugMode,
      );
      if (kDebugMode) {
        debugPrint('✅ Supabase initialized successfully for project: blfgpdflupfoxmzynred');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Supabase Initialization Error: $e');
      }
    }
  }
}
