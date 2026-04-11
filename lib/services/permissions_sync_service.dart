import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/db_service.dart';
import '../controllers/permissions_controller.dart';

/// خدمة مزامنة الصلاحيات مع Firebase Firestore
/// تدعم المزامنة الثنائية الاتجاه بين قاعدة البيانات المحلية والسحابة
class PermissionsSyncService extends GetxService {
  // Use a getter or lazy initialization to avoid accessing instance before Firebase.initializeApp() completes
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      throw Exception(
          "Firebase not initialized. Ensure Firebase.initializeApp() is called first.");
    }
  }

  // Getters for dependencies to avoid "Not found" errors during startup
  DBService get _db => Get.find<DBService>();
  // AuthController removed as it was unused in this scope (except inside methods where it's retrieved freshly)
  PermissionsController get _permController =>
      Get.find<PermissionsController>();

  final RxBool isSyncing = false.obs;
  final RxString lastSyncTime = ''.obs;

  // Collections names
  static const String _uiControlsCollection = 'ui_controls';
  static const String _userPermissionsCollection = 'user_permissions';

  // Map to keep track of active listeners per user
  final Map<String, StreamSubscription> _listeners = {};

  /// مزامنة جميع الصلاحيات للمستخدم الحالي من السحابة (مرة واحدة)
  Future<void> syncUserPermissionsFromCloud(
      String firebaseUid, int localId) async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    try {
      if (kDebugMode) {
        debugPrint(
            '🔄 بدء مزامنة الصلاحيات من السحابة للمستخدم: $firebaseUid (Local: $localId)');
      }

      // 1. جلب الصلاحيات من Firestore باستخدام UID الحقيقي
      final permissionsSnapshot = await _firestore
          .collection(_userPermissionsCollection)
          .where('user_id', isEqualTo: firebaseUid)
          .get();

      if (kDebugMode) {
        debugPrint(
            '📥 تم جلب ${permissionsSnapshot.docs.length} صلاحية من السحابة');
      }

      // 2. تطبيق الصلاحيات على قاعدة البيانات المحلية والـ Controller
      final permsMap = <String, Map<String, bool>>{};

      for (var doc in permissionsSnapshot.docs) {
        final data = doc.data();
        final controlName = data['control_name'] as String;
        final visible = data['visible'] as bool? ?? true;
        final enabled = data['enabled'] as bool? ?? true;

        // تحديث قاعدة البيانات المحلية
        final control = await _db.getRecord('ui_controls', where: 'control_name = ?', whereArgs: [controlName]);
        if (control != null) {
          await _db.insertRecord('user_permissions', {
            'user_id': localId,
            'control_id': control['id'],
            'visible': visible ? 1 : 0,
            'enabled': enabled ? 1 : 0,
          });
        }

        permsMap[controlName] = {'visible': visible, 'enabled': enabled};
      }

      // تحديث الحالة التفاعلية مرة واحدة بدلاً من التكرار
      if (permsMap.isNotEmpty) {
        _permController.loadPermissions(
            localId); // إعادة التحميل من DB لضمان التزامن الكامل
      }

      lastSyncTime.value = DateTime.now().toIso8601String();
      if (kDebugMode) debugPrint('✅ اكتملت المزامنة بنجاح');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في مزامنة الصلاحيات: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// مزامنة جميع الصلاحيات المحلية إلى السحابة (للمدراء)
  Future<void> syncAllPermissionsToCloud() async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    try {
      if (kDebugMode) debugPrint('🔄 بدء مزامنة جميع الصلاحيات إلى السحابة');

      final users = await _db.getRecords('users');

      int syncedCount = 0;
      for (var user in users) {
        final localId = user['id'] as int;
        final firebaseUid = user['firebase_uid'] as String?;

        if (firebaseUid == null || firebaseUid.isEmpty) continue;

        // جلب الصلاحيات مع أسماء العناصر
        final permissionsRaw = await _db.getRecords('user_permissions', where: 'user_id = ?', whereArgs: [localId]);
        final List<Map<String, dynamic>> permissions = [];
        
        for (var p in permissionsRaw) {
          final control = await _db.getRecord('ui_controls', where: 'id = ?', whereArgs: [p['control_id']]);
          if (control != null) {
            permissions.add({
              ...p,
              'control_name': control['control_name'],
            });
          }
        }

        for (var permission in permissions) {
          await syncPermissionToCloud(
            userId: firebaseUid,
            controlName: permission['control_name'] as String,
            visible: (permission['visible'] as int) == 1,
            enabled: (permission['enabled'] as int) == 1,
          );
          syncedCount++;
        }
      }

      lastSyncTime.value = DateTime.now().toIso8601String();
      Get.snackbar('نجح', 'تم مزامنة $syncedCount صلاحية');
    } catch (e) {
      debugPrint('❌ خطأ في المزامنة: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  /// مزامنة عناصر الواجهة إلى السحابة
  Future<void> syncUIControlsToCloud() async {
    try {
      if (kDebugMode) debugPrint('🔄 مزامنة عناصر الواجهة إلى السحابة');

      final controls = await _db.getRecords('ui_controls');

      for (var control in controls) {
        final controlName = control['control_name'];
        final controlData = {
          'control_name': controlName,
          'description': control['description'],
          'category': control['category'],
          'updated_at': FieldValue.serverTimestamp(),
        };

        final existingQuery = await _firestore
            .collection(_uiControlsCollection)
            .where('control_name', isEqualTo: controlName)
            .limit(1)
            .get();

        if (existingQuery.docs.isNotEmpty) {
          await existingQuery.docs.first.reference.update(controlData);
        } else {
          controlData['created_at'] = FieldValue.serverTimestamp();
          await _firestore.collection(_uiControlsCollection).add(controlData);
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في مزامنة عناصر الواجهة: $e');
    }
  }

  /// 🛡️ Sync specific permission to Cloud (Admin Dashboard Action)
  Future<void> syncPermissionToCloud({
    required String userId, // firebase_uid
    required String controlName,
    bool visible = true,
    bool enabled = true,
  }) async {
    isSyncing.value = true;
    try {
      // Helper to generate a consistent document ID for a user's specific permission
      // This ensures that each user-control permission has a unique, predictable document.
      String getPermissionDocId(String userId, String controlName) {
        return '${userId}_${controlName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_').toLowerCase()}';
      }

      final docId = getPermissionDocId(userId, controlName);

      await _firestore.collection('user_permissions').doc(docId).set({
        'user_id': userId,
        'control_name': controlName,
        'visible': visible,
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Cloud Sync Success: $controlName for $userId');
      }

      // Update local count in "users" metadata if needed (optional)
      _updateUserPermissionCount(userId);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Cloud Sync Failed: $e');
      rethrow; // Re-throw to propagate the error if needed
    } finally {
      isSyncing.value = false;
    }
  }

  /// Update permissions count in user document for admin visibility
  Future<void> _updateUserPermissionCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_permissions')
          .where('user_id', isEqualTo: userId)
          .get();

      await _firestore.collection('users').doc(userId).update({
        'permissions_count': snapshot.docs.length,
      });
    } catch (_) {}
  }

  /// الاستماع للتغييرات في الوقت الفعلي (Real-time sync)
  Stream<QuerySnapshot> watchUserPermissions(String userId) {
    return _firestore
        .collection(_userPermissionsCollection)
        .where('user_id', isEqualTo: userId)
        .snapshots();
  }

  /// 🎧 Setup Realtime Sync
  /// ⚠️ DEPRECATED: Now handled by PermissionsController directly for faster UI updates
  @Deprecated('Use PermissionsController.subscribeToUserPermissions instead')
  void setupRealtimeSync(String firebaseUid, int localId) {
    if (Get.isRegistered<PermissionsController>()) {
      Get.find<PermissionsController>().subscribeToUserPermissions(firebaseUid);
    }
  }

  /// حذف جميع صلاحيات مستخدم من السحابة
  Future<void> deleteUserPermissionsFromCloud(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_userPermissionsCollection)
          .where('user_id', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ تم حذف صلاحيات المستخدم من السحابة');
    } catch (e) {
      debugPrint('❌ خطأ في حذف الصلاحيات: $e');
    }
  }

  /// التحقق من حالة الاتصال بالسحابة
  Future<bool> checkCloudConnection() async {
    try {
      await _firestore
          .collection('_health_check')
          .doc('test')
          .set({'timestamp': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('❌ لا يوجد اتصال بالسحابة: $e');
      return false;
    }
  }

  /// مزامنة كاملة (Local → Cloud و Cloud → Local)
  Future<void> fullSync(String userId) async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    try {
      final localId = int.tryParse(userId);
      if (localId == null) {
        debugPrint('⚠️ fullSync: Invalid local userId: $userId');
        return;
      }

      final user = await _db.getRecord('users', where: 'id = ?', whereArgs: [localId]);
      final firebaseUid = user?['firebase_uid'] as String?;

      if (firebaseUid == null || firebaseUid.isEmpty) {
        debugPrint(
            '⚠️ Cannot sync permissions: No Firebase UID for user $localId');
        return;
      }

      // 1. التحقق من الاتصال
      final isConnected = await checkCloudConnection();
      if (!isConnected) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // 2. مزامنة من السحابة إلى المحلي
      await syncUserPermissionsFromCloud(firebaseUid, localId);

      // 3. مزامنة من المحلي إلى السحابة (للتحديثات الجديدة)
      final permissionsRaw = await _db.getRecords('user_permissions', where: 'user_id = ?', whereArgs: [localId]);
      final List<Map<String, dynamic>> localPermissions = [];
      
      for (var p in permissionsRaw) {
        final control = await _db.getRecord('ui_controls', where: 'id = ?', whereArgs: [p['control_id']]);
        if (control != null) {
          localPermissions.add({
            ...p,
            'control_name': control['control_name'],
          });
        }
      }
      for (var permission in localPermissions) {
        await syncPermissionToCloud(
          userId: firebaseUid, // Use Firebase UID
          controlName: permission['control_name'] as String,
          visible: (permission['visible'] as int) == 1,
          enabled: (permission['enabled'] as int) == 1,
        );
      }

      lastSyncTime.value = DateTime.now().toIso8601String();
      debugPrint('✅ اكتملت المزامنة الكاملة');
    } catch (e) {
      debugPrint('❌ خطأ في المزامنة الكاملة: $e');
      rethrow;
    } finally {
      isSyncing.value = false;
    }
  }

  /// 🔥 Update user permissions in Firestore users collection
  /// This syncs the permissions map directly to the user document
  Future<void> updateUserPermissionsInFirestore(
      String firebaseUid, Map<String, dynamic> permissions) async {
    try {
      await _firestore.collection('users').doc(firebaseUid).update({
        'permissions': permissions,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('✅ Updated permissions in Firestore users collection');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to update permissions in Firestore: $e');
      }
    }
  }

  @override
  void onClose() {
    for (var sub in _listeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    super.onClose();
  }
}
