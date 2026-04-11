import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'db_service.dart';
import 'firestore_user_service.dart';
import 'firebase_storage_service.dart';
import '../controllers/auth_controller.dart';

/// 🔄 خدمة المزامنة التلقائية للملف الشخصي
/// تقوم برفع الصور وتحديث البيانات في Firebase في الخلفية
class ProfileSyncService extends GetxService {
  final DBService _db = Get.find<DBService>();
  final FirestoreUserService _firestore = Get.find<FirestoreUserService>();
  final FirebaseStorageService _storage = Get.find<FirebaseStorageService>();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// 🚀 بدء عملية المزامنة
  Future<void> syncProfile() async {
    if (_isSyncing) return;

    final authController = Get.find<AuthController>();
    final user = authController.user;
    final uid = authController.firebaseUid;

    if (user == null || uid == null) return;

    _isSyncing = true;
    if (kDebugMode) debugPrint('🔄 ProfileSync: Starting background sync...');

    try {
      final String? localPhoto = user['photo_url']?.toString();
      final String? localCover = user['cover_url']?.toString();
      final String name = (user['name'] ?? user['username'] ?? '').toString();
      final String bio = (user['bio'] ?? '').toString();

      String? cloudPhoto;
      String? cloudCover;

      // 1️⃣ التحقق من الصور: إذا كانت مسارات محلية، يتم رفعها
      if (localPhoto != null && _isLocalPath(localPhoto)) {
        if (kDebugMode) {
          debugPrint('📤 ProfileSync: Uploading profile photo...');
        }
        cloudPhoto = await _storage.uploadProfileImage(
          uid: uid,
          file: File(localPhoto),
          isProfile: true,
        );
      }

      if (localCover != null && _isLocalPath(localCover)) {
        if (kDebugMode) debugPrint('📤 ProfileSync: Uploading cover photo...');
        cloudCover = await _storage.uploadProfileImage(
          uid: uid,
          file: File(localCover),
          isProfile: false,
        );
      }

      // 2️⃣ تحديث البيانات في Firestore
      final Map<String, dynamic> firestoreData = {
        'name': name,
        'bio': bio,
      };
      if (cloudPhoto != null) firestoreData['photo_url'] = cloudPhoto;
      if (cloudCover != null) firestoreData['cover_url'] = cloudCover;

      final success = await _firestore.updateUserProfile(
        uid: uid,
        data: firestoreData,
      );

      if (success) {
        // 3️⃣ تحديث قاعدة البيانات المحلية بالروابط السحابية الجديدة
        final Map<String, dynamic> localUpdate = {};
        if (cloudPhoto != null) localUpdate['photo_url'] = cloudPhoto;
        if (cloudCover != null) localUpdate['cover_url'] = cloudCover;

        if (localUpdate.isNotEmpty) {
          await _db.updateRecord('users', localUpdate, where: 'id = ?', whereArgs: [user['id']]);
          // ✅ تحديث حالة الـ AuthController ليعكس الروابط السحابية الجديدة
          await authController.refreshUser();
        }
        if (kDebugMode) {
          debugPrint('✅ ProfileSync: Sync completed successfully.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfileSync: Error during sync: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }

  bool _isLocalPath(String path) {
    return !path.startsWith('http') && !path.startsWith('https');
  }
}
