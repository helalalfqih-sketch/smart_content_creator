import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/brand_identity_model.dart';

/// خدمة إدارة المستخدمين في Firestore
/// المصدر الموثوق الوحيد للأدوار (Roles)
class FirestoreUserService extends GetxService {
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      throw Exception(
          "Firebase not initialized. Ensure Firebase.initializeApp() is called first.");
    }
  }

  static const String _usersCollection = 'users';

  /// الحصول على بيانات المستخدم من Firestore أو إنشاء حساب جديد
  ///
  /// - إذا كان المستخدم موجود: يُرجع بياناته
  /// - إذا كان جديد: يُنشئ وثيقة بـ role: "user" تلقائيًا
  ///
  /// ⚠️ لا يمكن لأي كود تعيين role: "admin" - يجب تعيينه يدويًا من Firebase Console
  Future<Map<String, dynamic>> getOrCreateUser({
    required String uid,
    required String email,
    String? name,
  }) async {
    try {
      final ref = _firestore.collection(_usersCollection).doc(uid);
      final snap = await ref.get();

      if (!snap.exists) {
        // إنشاء مستخدم جديد بـ role: "user" تلقائيًا مع إشعار للمدير
        final userData = {
          'email': email,
          'name': name ?? 'مبدع SMART',
          'role': 'user', // 🔒 دائمًا user - Admin يُعيّن يدويًا فقط
          'isPremium': false, // 🟢 حقل الاشتراك الافتراضي
          'visualAnalysisCount': 0, // 📸 عداد تحليل الصور (مجاني لأول 15 صورة)

          // 🧠 Managed AI Architecture (v3.0)
          'credits': 50, // الرصيد الافتراضي للتجربة
          'is_trial_active': true,
          'is_ai_blocked': false, // 🛑 Kill switch for AI access
          'last_credit_reset': FieldValue.serverTimestamp(),
          'ai_backend': 'firebase_ai', // 🎯 مسار الذكاء الاصطناعي الافتراضي

          'newUserNotification': true, // 🟢 إشعار للمدير بوجود مستخدم جديد
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await ref.set(userData);

        if (kDebugMode) {
          debugPrint(
              '✅ تم إنشاء مستخدم جديد في Firestore: $email (role: user)');
        }

        return {
          'email': email,
          'role': 'user',
          'isPremium': false,
          'newUserNotification': true,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        };
      }

      // المستخدم موجود - إرجاع بياناته
      final data = snap.data()!;
      if (kDebugMode) {
        debugPrint(
            '🔍 FirestoreUserService: Fetched user data for $uid - Role: ${data['role']}');
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في getOrCreateUser: $e');
      }
      rethrow;
    }
  }

  /// التحقق من صلاحيات الأدمن
  ///
  /// يقرأ مباشرة من Firestore (مصدر الحقيقة الوحيد)
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (!doc.exists) {
        return false;
      }

      final role = doc.data()?['role'] as String?;
      return role == 'admin';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في isAdmin: $e');
      }
      return false;
    }
  }

  /// الحصول على دور المستخدم فقط
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (!doc.exists) {
        return 'user'; // افتراضي
      }

      return doc.data()?['role'] as String? ?? 'user';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في getUserRole: $e');
      }
      return 'user';
    }
  }

  /// تحديث بيانات المستخدم (بدون تعديل role)
  ///
  /// ⚠️ role محمي بواسطة Firestore Security Rules
  Future<bool> updateUserProfile({
    required String uid,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (data == null || data.isEmpty) return true;

      // إزالة role إذا كان موجود (لا يمكن تعديله من الكود)
      data.remove('role');

      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_usersCollection).doc(uid).update(data);

      if (kDebugMode) {
        debugPrint('✅ تم تحديث بيانات المستخدم');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في updateUserProfile: $e');
      }
      return false;
    }
  }

  /// 📸 زيادة عداد التحليل البصري
  Future<void> incrementVisualAnalysisCount(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'visualAnalysisCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في زيادة عداد التحليل: $e');
    }
  }

  /// 📸 التحقق مما إذا كان مسموحاً للمستخدم إجراء تحليل بصري
  /// - المشترك (isPremium): مسموح دائماً
  /// - المستخدم الجديد: مسموح حتى 15 صورة
  Future<bool> canPerformVisualAnalysis(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final bool isPremium = data['isPremium'] as bool? ?? false;
      final String role = data['role'] as String? ?? 'user';
      final int count = data['visualAnalysisCount'] as int? ?? 0;

      // إذا كان مشرفاً أو مشتركاً، فله الصلاحية المطلقة
      if (role == 'admin' || isPremium) return true;

      // إذا لم يكن كذلك، لديه حد 15 صورة
      return count < 15;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في التحقق من صلاحية التحليل: $e');
      return false;
    }
  }

  /// الاستماع للتغييرات في الوقت الفعلي على بيانات المستخدم
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots();
  }

  /// إزالة إشعار المستخدم الجديد (يستخدمه المدير)
  Future<void> clearUserNotification(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'newUserNotification': false,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في clearUserNotification: $e');
    }
  }

  /// 📊 جلب إحصائيات المبدع من السحابة
  Future<Map<String, dynamic>?> getCreatorStats(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null || !data.containsKey('creator_stats')) return null;
      
      return data['creator_stats'] as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ فشل جلب الإحصائيات من السحابة: $e');
      return null;
    }
  }

  /// 📊 مزامنة إحصائيات المبدع مع Firestore لكي يراها المدير
  Future<void> updateCreatorStats({
    required String uid,
    required Map<String, dynamic> stats,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'creator_stats': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) debugPrint('✅ تم مزامنة إحصائيات المبدع مع السحابة');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ فشل مزامنة الإحصائيات: $e');
    }
  }

  /// التحقق من اتصال Firestore
  Future<bool> checkConnection() async {
    try {
      await _firestore
          .collection('_health_check')
          .doc('test')
          .set({'timestamp': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ لا يوجد اتصال بـ Firestore: $e');
      }
      return false;
    }
  }

  /// 💾 حفظ الهوية البصرية للمبدع
  Future<void> saveBrandIdentity({
    required String uid,
    required BrandIdentity brand,
  }) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({'brand_identity': brand.toMap()});
      if (kDebugMode) debugPrint('✅ تم حفظ الهوية البصرية للمستخدم: $uid');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ فشل حفظ الهوية البصرية: $e');
      rethrow;
    }
  }

  /// 📖 استرجاع الهوية البصرية
  Future<BrandIdentity?> getBrandIdentity(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || !data.containsKey('brand_identity')) return null;

      return BrandIdentity.fromMap(data['brand_identity'] as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ فشل استرجاع الهوية البصرية: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // 🎯 AI Backend Management (Phase 2)
  // ──────────────────────────────────────────────────────

  /// الحصول على مسار الذكاء الاصطناعي للمستخدم
  Future<String> getUserAiBackend(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return 'firebase_ai';
      return doc.data()?['ai_backend']?.toString() ?? 'firebase_ai';
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في getUserAiBackend: $e');
      return 'firebase_ai';
    }
  }

  /// 🔄 تبديل مسار الذكاء الاصطناعي للمستخدم (Admin فقط)
  Future<bool> switchUserAiBackend({
    required String uid,
    required String newBackend,
  }) async {
    try {
      final allowed = ['firebase_ai', 'backend', 'manus'];
      if (!allowed.contains(newBackend)) {
        if (kDebugMode) {
          debugPrint('❌ قيمة ai_backend غير مسموحة: $newBackend');
        }
        return false;
      }

      await _firestore.collection(_usersCollection).doc(uid).update({
        'ai_backend': newBackend,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ تم تبديل ai_backend للمستخدم $uid → $newBackend');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في switchUserAiBackend: $e');
      }
      return false;
    }
  }
}
