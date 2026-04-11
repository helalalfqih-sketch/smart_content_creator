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
  }) async {
    try {
      final ref = _firestore.collection(_usersCollection).doc(uid);
      final snap = await ref.get();

      if (!snap.exists) {
        // إنشاء مستخدم جديد بـ role: "user" تلقائيًا مع إشعار للمدير
        final userData = {
          'email': email,
          'role': 'user', // 🔒 دائمًا user - Admin يُعيّن يدويًا فقط
          'isPremium': false, // 🟢 حقل الاشتراك الافتراضي

          // 🧠 Managed AI Architecture (v3.0)
          'credits': 50, // الرصيد الافتراضي للتجربة
          'is_trial_active': true,
          'is_ai_blocked': false, // 🛑 Kill switch for AI access
          'last_credit_reset': FieldValue.serverTimestamp(),

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
}
