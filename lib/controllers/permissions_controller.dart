import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/db_service.dart';
import 'auth_controller.dart';

/// Controller that manages reactive permissions for the current logged-in user.
class PermissionsController extends GetxController {
  // Getter for DB dependency
  DBService get _db => Get.find<DBService>();

  // Map of controlName -> {visible: bool, enabled: bool}
  final RxMap<String, Map<String, bool>> _permissions =
      <String, Map<String, bool>>{}.obs;
  final RxBool isLoading = false.obs;

  // 🔥 Firestore real-time subscription
  StreamSubscription<QuerySnapshot>? _permissionsSubscription;

  // List of control names that are allowed by default for all users
  static const List<String> _alwaysAllowed = [
    'ai_chat_screen',
    'chat_image_attach',
    'chat_camera_attach',
    'chat_file_attach',
    'use_managed_keys', // 🛡️ السماح باستخدام مفاتيح الأدمن افتراضياً
    'managed_key_gemini',
    'managed_key_serpapi',
    'managed_key_stability',
    'managed_key_kling',
    'managed_key_github',
  ];

  @override
  void onInit() {
    super.onInit();
    debugPrint('🚀 [PermissionsController] onInit called!');
  }

  @override
  void onClose() {
    stopListing();
    super.onClose();
  }

  /// 🔥 Listening to Firestore permissions in real-time
  void subscribeToUserPermissions(String firebaseUid) {
    if (_permissionsSubscription != null) {
      _permissionsSubscription!.cancel();
    }

    debugPrint(
        "🎧 [PermissionsController] subscribeToUserPermissions called for: $firebaseUid");
    debugPrint(
        "🎧 PermissionsController: Starting Cloud Listener for $firebaseUid");

    _permissionsSubscription = FirebaseFirestore.instance
        .collection('user_permissions')
        .where('user_id', isEqualTo: firebaseUid)
        .snapshots()
        .listen((snapshot) {
      final Map<String, Map<String, bool>> newPerms = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final controlName = data['control_name']?.toString() ?? 'unknown';
        newPerms[controlName] = {
          'visible': data['visible'] == true,
          'enabled': data['enabled'] == true,
        };

        // 💾 Update local DB in background to stay synced
        // Resolving control_id from name for data integrity
        _db.getRecord('ui_controls', where: 'control_name = ?', whereArgs: [controlName]).then((control) {
          if (control != null) {
            _db.insertRecord('user_permissions', {
              'user_id': firebaseUid.hashCode, // Simplified local mapping
              'control_id': control['id'],
              'visible': data['visible'] == true ? 1 : 0,
              'enabled': data['enabled'] == true ? 1 : 0,
            });
          }
        });
      }

      _permissions.assignAll(newPerms);
      debugPrint(
          "🔔 PermissionsController: ${newPerms.length} permissions synced from Cloud");
    }, onError: (e) {
      debugPrint("❌ PermissionsController Cloud Error: $e");
    });
  }

  /// Stop listening to changes
  void stopListing() {
    _permissionsSubscription?.cancel();
    _permissionsSubscription = null;
    _permissions.clear();
    debugPrint("🛑 PermissionsController: Cloud Listener stopped");
  }

  /// Load all permissions for current user from local DB (Startup speed)
  Future<void> loadPermissions(int? userId) async {
    if (userId == null) return;

    isLoading.value = true;
    try {
      // Simplified join to get control names and permission states
      final List<Map<String, dynamic>> permsList = await _db.getRecords(
        'user_permissions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final Map<String, Map<String, bool>> newPerms = {};
      for (var p in permsList) {
        final control = await _db.getRecord('ui_controls', where: 'id = ?', whereArgs: [p['control_id']]);
        if (control != null) {
          final name = control['control_name']?.toString() ?? 'unknown';
          newPerms[name] = {
            'visible': (p['visible'] as int) == 1,
            'enabled': (p['enabled'] as int) == 1,
          };
        }
      }

      _permissions.assignAll(newPerms);
      debugPrint(
          "🔐 PermissionsController: Loaded ${newPerms.length} permissions from SQLite");
    } catch (e) {
      debugPrint("❌ PermissionsController SQLite Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Update a specific permission in the local reactive map
  void updateLocalPermission(String controlName, bool visible, bool enabled) {
    _permissions[controlName] = {
      'visible': visible,
      'enabled': enabled,
    };
    update(); // Notify listeners
  }

  /// Get visibility state for a control
  bool isVisible(String controlName) {
    // Check Admin status (Admins see everything)
    try {
      if (Get.isRegistered<AuthController>()) {
        final auth = Get.find<AuthController>();
        if (auth.isAdmin) return true;
      }
    } catch (_) {}

    // Check if explicitly set in local permissions first
    if (_permissions.containsKey(controlName)) {
      return _permissions[controlName]!['visible']!;
    }

    // If not set, check if it's in the always allowed list
    return _alwaysAllowed.contains(controlName);
  }

  /// Get enabled state for a control
  bool isEnabled(String controlName) {
    // Check Admin status (Admins can use everything)
    try {
      if (Get.isRegistered<AuthController>()) {
        final auth = Get.find<AuthController>();
        if (auth.isAdmin) return true;
      }
    } catch (_) {}

    // Check if explicitly set in local permissions first
    if (_permissions.containsKey(controlName)) {
      return _permissions[controlName]!['enabled']!;
    }

    // If not set, check if it's in the always allowed list
    return _alwaysAllowed.contains(controlName);
  }
}
