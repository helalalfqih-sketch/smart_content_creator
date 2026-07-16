import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 💎 نظام إدارة الاشتراكات (SaaS Engine)
/// يدير الخطط، الصلاحيات، والمزامنة مع Firestore
class SubscriptionService extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _subCollection = 'subscriptions';
  static const String _usersCollection = 'users';

  // 🛍️ IAP UI State (Placeholders for SubscriptionScreen)
  final RxBool isLoading = false.obs;
  final RxBool isAvailable = false.obs; // Set to false to trigger WhatsApp fallback by default
  final RxList<dynamic> products = <dynamic>[].obs;

  /// 🛒 شراء اشتراك (In-App Purchase Placeholder)
  Future<void> buySubscription() async {
    isLoading.value = true;
    try {
      // Logic for Apple/Google Pay would go here
      debugPrint('🛒 Buy subscription triggered...');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔄 استعادة المشتريات
  Future<void> restorePurchases() async {
    isLoading.value = true;
    try {
      debugPrint('🔄 Restore purchases triggered...');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      isLoading.value = false;
    }
  }

  /// 🎯 منح اشتراك لمستخدم (من قبل الأدمن أو بعد الدفع)
  Future<bool> grantSubscription({
    required String uid,
    required String planId,
    required int durationDays,
    String source = "admin",
  }) async {
    try {
      final now = DateTime.now();
      final end = now.add(Duration(days: durationDays));

      // 1. تحديث سجل الاشتراكات التفصيلي
      await _db.collection(_subCollection).doc(uid).set({
        'planId': planId,
        'startDate': now.millisecondsSinceEpoch,
        'endDate': end.millisecondsSinceEpoch,
        'status': 'active',
        'source': source,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. تحديث بيانات المستخدم الأساسية للوصول السريع
      await _db.collection(_usersCollection).doc(uid).update({
        'isPremium': true,
        'subscription': {
          'planId': planId,
          'endDate': end.millisecondsSinceEpoch,
          'status': 'active',
        }
      });

      debugPrint('✅ [Subscription] Granted $planId to $uid for $durationDays days.');
      return true;
    } catch (e) {
      debugPrint('❌ [Subscription] Error granting subscription: $e');
      return false;
    }
  }

  /// 🔁 التحقق من انتهاء صلاحية الاشتراك
  Future<void> checkAndRefreshSubscription(String uid) async {
    try {
      final doc = await _db.collection(_subCollection).doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final int endDate = data['endDate'] ?? 0;
      final String status = data['status'] ?? 'expired';

      if (DateTime.now().millisecondsSinceEpoch > endDate && status == 'active') {
        // 🚨 انتهى الاشتراك!
        await _db.collection(_subCollection).doc(uid).update({
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _db.collection(_usersCollection).doc(uid).update({
          'isPremium': false,
          'subscription.status': 'expired',
        });
        
        debugPrint('🚨 [Subscription] User $uid subscription has EXPIRED.');
      }
    } catch (e) {
      debugPrint('❌ [Subscription] Error checking expiry: $e');
    }
  }

  /// 🛑 إلغاء الاشتراك يدوياً
  Future<bool> revokeSubscription(String uid) async {
    try {
      await _db.collection(_subCollection).doc(uid).update({
        'status': 'revoked',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _db.collection(_usersCollection).doc(uid).update({
        'isPremium': false,
        'subscription.status': 'revoked',
      });

      return true;
    } catch (e) {
      debugPrint('❌ [Subscription] Error revoking subscription: $e');
      return false;
    }
  }
}
