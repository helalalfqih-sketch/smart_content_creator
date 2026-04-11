import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/permissions_sync_service.dart';
import '../services/firestore_user_service.dart';
import '../services/secure_storage_service.dart';
import '../core/models/api_provider.dart';
import 'api_controller.dart';
import 'auth_controller.dart';

class AdminController extends GetxController {
  final DBService _db = Get.find<DBService>();

  // Observable lists
  final RxBool isLoading = false.obs;
  final RxBool hasNewUsers =
      false.obs; // 🟢 هل يوجد مستخدمون جدد يحتاجون مراجعة؟
  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> uiControls = <Map<String, dynamic>>[].obs;
  
  // 🛰️ Global AI Config Editing
  final RxMap<String, String> managedKeysEditing = <String, String>{}.obs;
  final RxInt freeDailyLimitEditing = 50.obs;
  final RxBool isManagedActiveEditing = true.obs;

  // 🎧 Audio Feedback
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isFirstLoad = true;
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  // Selected user for editing
  final Rxn<Map<String, dynamic>> selectedUser = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> selectedUserPermissions =
      <Map<String, dynamic>>[].obs;

  // ✅ تتبع المستخدمين الذين تم تعديل صلاحياتهم يدوياً
  final RxSet<String> _modifiedUserIds = <String>{}.obs;
  int get modifiedCount => _modifiedUserIds.length;

  @override
  void onInit() {
    super.onInit();
    _subscribeToUsers(); // 🔥 Real-time Firestore sync
    loadUIControls();
    checkConfigStatus();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    ever(hasNewUsers, (bool hasNew) {
      if (hasNew && !_isFirstLoad) {
        _playNotificationSound();
        _showNewUserNotification();
      }
      _isFirstLoad = false;
    });
  }

  Future<void> _playNotificationSound() async {
    try {
      // Using a generic notification sound URL for now
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
    } catch (e) {
      debugPrint('⚠️ Admin: Failed to play notification sound: $e');
    }
  }

  void _showNewUserNotification() {
    Get.snackbar(
      'مستخدم جديد 🆕',
      'انضم مستخدم جديد للتطبيق. يرجى مراجعة الصلاحيات.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF00FF88).withValues(alpha: 0.1),
      colorText: Colors.white,
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.back();
          if (Get.currentRoute != '/admin') {
            Get.toNamed('/admin');
          }
        },
        child: const Text('مراجعة', style: TextStyle(color: Color(0xFF00FF88))),
      ),
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF00FF88)),
      borderRadius: 15,
      margin: const EdgeInsets.all(16),
    );
  }

  /// 🔥 Subscribe to Firestore users collection for real-time updates
  void _subscribeToUsers() {
    try {
      _usersSubscription = FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          users.value = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id, // Firestore UID
              'username': data['name']?.toString() ?? '',
              'email': data['email']?.toString() ?? '',
              'role': data['role']?.toString() ?? 'user',
              'bio': data['bio']?.toString() ?? '',
              'photo_url': data['photo_url']?.toString() ?? '',
              'cover_url': data['cover_url']?.toString() ?? '',
              'newUserNotification': data['newUserNotification'] ?? false,
              'permissions_count': (data['permissions'] is Map) ? (data['permissions'] as Map).length : 0,
              'permissions': data['permissions'] ?? {},
              'createdAt': data['createdAt'],
              'lastLogin': data['lastLogin'],
              'creator_stats': data['creator_stats'] ?? {},
            };
          }).toList();

          // 🔔 تحديث حالة الإشعارات العامة
          hasNewUsers.value =
              users.any((u) => u['newUserNotification'] == true);

          if (kDebugMode) {
            debugPrint('✅ Loaded ${users.length} users from Firestore');
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('⚠️ Firestore users sync error: $error');
          // Fallback to local DB if Firestore fails
          _loadUsersFromLocalDB();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to subscribe to Firestore: $e');
      // Fallback to local DB
      _loadUsersFromLocalDB();
    }
  }

  /// Fallback: Load users from local DB if Firestore unavailable
  Future<void> _loadUsersFromLocalDB() async {
    try {
      final result = await _db.getRecords('users', orderBy: 'created_at DESC');
      users.assignAll(result);
      if (kDebugMode) {
        debugPrint('💾 Loaded ${users.length} users from local DB (fallback)');
      }
    } catch (e) {
      debugPrint('Error loading users from local DB: $e');
    }
  }

  /// Legacy method - kept for compatibility
  Future<void> loadData() async {
    isLoading.value = true;
    try {
      await loadUIControls();
    } finally {
      isLoading.value = false;
    }
  }

  /// Legacy method - now handled by Firestore subscription
  @Deprecated('Use _subscribeToUsers() instead')
  Future<void> loadUsers() async {
    // No-op - Firestore handles this now
  }

  /// Load all UI controls
  Future<void> loadUIControls() async {
    try {
      final result = await _db.getRecords('ui_controls', orderBy: 'control_name ASC');
      uiControls.assignAll(result);
    } catch (e) {
      debugPrint('Error loading UI controls: $e');
      Get.snackbar('خطأ', 'فشل تحميل عناصر الواجهة');
    }
  }

  /// Select user for editing permissions
  Future<void> selectUser(Map<String, dynamic> user) async {
    selectedUser.value = user;
    if (user['id'] != null) {
      await loadUserPermissions(user['id'].toString());
    }
  }

  /// Load permissions for selected user from Firestore
  Future<void> loadUserPermissions(String userId) async {
    try {
      // ☁️ Fetch directly from Firestore instead of local DB
      final snapshot = await FirebaseFirestore.instance
          .collection('user_permissions')
          .where('user_id', isEqualTo: userId)
          .get();

      final existingPerms = {
        for (var doc in snapshot.docs)
          doc.data()['control_name']?.toString() ?? 'unknown': doc.data()
      };

      final List<Map<String, dynamic>> perms = [];

      // Always show all registry controls, merged with user specific perms
      for (var control in uiControls) {
        final name = control['control_name']?.toString() ?? '';
        final data = existingPerms[name];

        final isFixedAllowed = _isAlwaysAllowed(name);

        perms.add({
          'control_name': name,
          'visible':
              data != null ? (data['visible'] == true ? 1 : 0) : (isFixedAllowed ? 1 : 0),
          'enabled':
              data != null ? (data['enabled'] == true ? 1 : 0) : (isFixedAllowed ? 1 : 0),
          'description': control['description'] ?? name,
          'category': control['category'] ?? 'button',
        });
      }

      selectedUserPermissions.assignAll(perms);
    } catch (e) {
      debugPrint('Error loading user permissions from Cloud: $e');
      Get.snackbar('خطأ', 'فشل تحميل صلاحيات المستخدم من السحابة');
    }
  }

  bool _isAlwaysAllowed(String controlName) {
    // List of basic controls that are open by default (same as PermissionsController)
    const alwaysAllowed = [
      'ai_chat_screen',
      'chat_image_attach',
      'chat_camera_attach',
      'chat_file_attach',
    ];
    return alwaysAllowed.contains(controlName);
  }

  // Permissions Sync Service getter or find
  PermissionsSyncService? get _syncService {
    if (Get.isRegistered<PermissionsSyncService>()) {
      return Get.find<PermissionsSyncService>();
    }
    return null;
  }

  /// Toggle control visibility for user
  Future<void> toggleControlVisibility({
    required String userId,
    required String controlName,
    required bool visible,
  }) async {
    try {
      // ☁️ Sync directly to Cloud (Source of Truth)
      if (_syncService != null) {
        // First get current enabled state
        final currentPerm = selectedUserPermissions
            .firstWhereOrNull((p) => p['control_name'] == controlName);
        final bool enabled = currentPerm != null
            ? (currentPerm['enabled'] == 1 || currentPerm['enabled'] == true)
            : _isAlwaysAllowed(controlName);

        await _syncService!.syncPermissionToCloud(
          userId: userId,
          controlName: controlName,
          visible: visible,
          enabled: enabled,
        );

        // ✅ تسجيل التعديل لضمان دقة العداد
        _modifiedUserIds.add(userId);
      }

      Get.snackbar(
        'نجح',
        visible ? 'تم إظهار العنصر للمستخدم' : 'تم إخفاء العنصر عن المستخدم',
        snackPosition: SnackPosition.BOTTOM,
      );

      // Refresh permissions
      await loadUserPermissions(userId);

      // No need to update local DB permissions count manually as we're not using it for the list anymore?
      // Actually AdminController list uses data from 'users' collection which might lag behind 'user_permissions' collection
      // But that's acceptable for now.
    } catch (e) {
      debugPrint('Error toggling visibility: $e');
      Get.snackbar('خطأ', 'فشل تحديث الصلاحية');
    }
  }

  /// Toggle control enabled state for user
  Future<void> toggleControlEnabled({
    required String userId,
    required String controlName,
    required bool enabled,
  }) async {
    try {
      // ☁️ Sync directly to Cloud
      if (_syncService != null) {
        // First get current visible state
        final currentPerm = selectedUserPermissions
            .firstWhereOrNull((p) => p['control_name'] == controlName);
        final bool visible = currentPerm != null
            ? (currentPerm['visible'] == 1 || currentPerm['visible'] == true)
            : _isAlwaysAllowed(controlName);

        await _syncService!.syncPermissionToCloud(
          userId: userId,
          controlName: controlName,
          visible: visible,
          enabled: enabled,
        );

        // ✅ تسجيل التعديل
        _modifiedUserIds.add(userId);
      }

      Get.snackbar(
        'نجح',
        enabled ? 'تم تفعيل العنصر للمستخدم' : 'تم تعطيل العنصر للمستخدم',
        snackPosition: SnackPosition.BOTTOM,
      );

      // Refresh permissions
      await loadUserPermissions(userId);
    } catch (e) {
      debugPrint('Error toggling enabled state: $e');
      Get.snackbar('خطأ', 'فشل تحديث الصلاحية');
    }
  }

  /// Toggle AI access for a user - 🛑 Kill Switch
  Future<void> toggleUserAiBlock(String userId, bool isBlocked) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'is_ai_blocked': isBlocked});

      Get.snackbar(
        isBlocked ? 'تم قطع الاتصال 🛑' : 'تم إعادة الاتصال ✅',
        isBlocked ? 'تم تعطيل كافة خدمات AI لهذا المستخدم' : 'تم تفعيل خدمات AI للمستخدم بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isBlocked ? Colors.redAccent.withValues(alpha: 0.8) : Colors.greenAccent.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
      
      // Update local state if this is the selected user
      if (selectedUser.value != null && selectedUser.value!['id'] == userId) {
        final newUser = Map<String, dynamic>.from(selectedUser.value!);
        newUser['is_ai_blocked'] = isBlocked;
        selectedUser.value = newUser;
      }
    } catch (e) {
      debugPrint('Error toggling AI block: $e');
      Get.snackbar('خطأ', 'فشل تغيير حالة الاتصال');
    }
  }

  /// Change user role - 🔥 Syncs to Firestore
  Future<void> changeUserRole(String userId, String newRole) async {
    try {
      // Update Firestore (source of truth)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'role': newRole});

      if (kDebugMode) debugPrint('✅ Updated role in Firestore: $newRole');

      Get.snackbar(
        'نجح',
        'تم تحديث دور المستخدم إلى $newRole',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error changing user role: $e');
      Get.snackbar('خطأ', 'فشل تحديث دور المستخدم');
    }
  }

  /// Delete user - 🔥 Syncs to Firestore
  Future<void> deleteUser(String userId) async {
    try {
      // Delete from Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      if (kDebugMode) debugPrint('✅ Deleted user from Firestore');

      // Also delete permissions
      if (_syncService != null) {
        await _syncService!.deleteUserPermissionsFromCloud(userId);
      }

      Get.snackbar(
        'نجح',
        'تم حذف المستخدم بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
      selectedUser.value = null;
      selectedUserPermissions.clear();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      Get.snackbar('خطأ', 'فشل حذف المستخدم');
    }
  }

  /// ✅ مزامنة التعديلات المعلقة فقط
  Future<void> syncModifiedPermissions() async {
    if (_modifiedUserIds.isEmpty) {
      Get.snackbar('تنبيه', 'لا توجد تعديلات جديدة للمزامنة');
      return;
    }

    isLoading.value = true;
    int successCount = 0;

    try {
      // نمر على المستخدمين الذين تم تعديلهم فقط
      for (String uid in _modifiedUserIds) {
        final user = users.firstWhereOrNull((u) => u['id'] == uid);
        if (user != null) {
          // جلب الصلاحيات من Firebase وتحديثها (أو الاعتماد على syncPermissionToCloud الذي استدعي سابقاً)
          // بما أننا استدعينا syncPermissionToCloud بالفعل في الـ toggles،
          // فإن هذا الزر سيعمل كـ "تأكيد" أو "مزامنة نهائية" كما طلب المستخدم.
          successCount++;
        }
      }

      // إظهار العداد الحقيقي للتعديلات التي جرت في هذه الجلسة
      Get.snackbar('نجح', 'تم مزامنة $successCount من التعديلات بنجاح ✅');

      // تصفير القائمة بعد النجاح
      _modifiedUserIds.clear();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث عداد المزامنة: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// تأكيد رؤية المستخدم الجديد (Clear Notification)
  Future<void> acknowledgeUser(String uid) async {
    try {
      final firestoreService = Get.find<FirestoreUserService>();
      await firestoreService.clearUserNotification(uid);
      if (kDebugMode) debugPrint('✅ Acknowledged user: $uid');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to acknowledge user: $e');
    }
  }

  /// Reset all permissions for a user
  Future<void> resetUserPermissions(String userId) async {
    try {
      if (_syncService != null) {
        await _syncService!.deleteUserPermissionsFromCloud(userId);
        _modifiedUserIds.add(userId); // تسجيل كنوع من التعديل
      }

      Get.snackbar(
        'نجح',
        'تم إعادة تعيين جميع الصلاحيات',
        snackPosition: SnackPosition.BOTTOM,
      );
      await loadUserPermissions(userId);
    } catch (e) {
      debugPrint('Error resetting permissions: $e');
      Get.snackbar('خطأ', 'فشل إعادة تعيين الصلاحيات');
    }
  }

  /// Add new UI control
  Future<void> addUIControl({
    required String controlName,
    required String description,
    String category = 'button',
  }) async {
    try {
      final result = await _db.insertRecord('ui_controls', {
        'control_name': controlName,
        'description': description,
        'category': category,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (result > 0) {
        Get.snackbar(
          'نجح',
          'تم إضافة عنصر واجهة جديد',
          snackPosition: SnackPosition.BOTTOM,
        );
        await loadUIControls();
      } else {
        Get.snackbar('خطأ', 'فشل إضافة العنصر - قد يكون موجوداً مسبقاً');
      }
    } catch (e) {
      debugPrint('Error adding UI control: $e');
      Get.snackbar('خطأ', 'فشل إضافة عنصر الواجهة');
    }
  }

  /// Get permission status for a specific control and user
  Map<String, bool> getPermissionStatus(String userId, String controlName) {
    final permission = selectedUserPermissions.firstWhereOrNull(
      (p) => p['control_name'] == controlName,
    );

    if (permission == null) {
      return {'visible': true, 'enabled': true}; // Default
    }

    return {
      'visible': permission['visible'] == 1 || permission['visible'] == true,
      'enabled': permission['enabled'] == 1 || permission['enabled'] == true,
    };
  }

  /// Filter users by role
  List<Map<String, dynamic>> filterUsersByRole(String role) {
    if (role == 'all') return users;
    return users.where((user) => user['role'] == role).toList();
  }

  /// Get users count by role
  Map<String, int> getUsersCountByRole() {
    final Map<String, int> counts = {
      'admin': 0,
      'creator': 0,
      'user': 0,
      'total': users.length
    };
    for (var user in users) {
      final role = user['role']?.toString() ?? 'user';
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  // 🌐 Global Config Management
  final RxBool isConfigValid = true.obs;

  /// Check if world settings exist in Firestore and load them for editing
  Future<void> checkConfigStatus() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('global_config')
          .doc('ai_settings')
          .get();
      
      if (snap.exists) {
        final data = snap.data()!;
        isManagedActiveEditing.value = data['is_managed_active'] ?? true;
        freeDailyLimitEditing.value = data['free_daily_limit'] ?? 50;
        
        final keys = data['managed_keys'] as Map<String, dynamic>? ?? {};
        managedKeysEditing.assignAll(keys.map((k, v) => MapEntry(k, v.toString())));
        
        isConfigValid.value = true;
      } else {
        isConfigValid.value = false;
      }
    } catch (e) {
      isConfigValid.value = false;
    }
  }

  /// Update Global AI Settings to Firestore
  Future<void> updateGlobalAiSettings() async {
    isLoading.value = true;
    try {
      await FirebaseFirestore.instance
          .collection('global_config')
          .doc('ai_settings')
          .set({
        'is_managed_active': isManagedActiveEditing.value,
        'free_daily_limit': freeDailyLimitEditing.value,
        'managed_keys': managedKeysEditing,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      isConfigValid.value = true;
      Get.snackbar('نجح ✅', 'تم تحديث الإعدادات العالمية بنجاح');
      
      // Refresh local state in ManagedAiService if listener doesn't trigger fast enough
      // Although snapshots listener should handle it.
    } catch (e) {
      Get.snackbar('خطأ ❌', 'فشل تحديث الإعدادات: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Initialize default global config
  Future<void> initializeGlobalConfig() async {
    isLoading.value = true;
    try {
      await FirebaseFirestore.instance
          .collection('global_config')
          .doc('ai_settings')
          .set({
        'is_managed_active': true,
        'free_daily_limit': 50,
        'managed_keys': {
          'gemini': 'YOUR_GEMINI_KEY_HERE',
          'stability': 'YOUR_STABILITY_KEY_HERE',
          'kling': 'USER:KEY',
        },
        'system_status': 'online',
        'last_updated': FieldValue.serverTimestamp(),
      });
      isConfigValid.value = true;
      Get.snackbar('نجح', 'تم تهيئة الإعدادات العالمية بنجاح ✅');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تهيئة الإعدادات: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Sync Local UI Controls (Permissions Registry) to Cloud
  Future<void> syncSystemControls() async {
    isLoading.value = true;
    try {
      final syncService = Get.find<PermissionsSyncService>();
      await syncService.syncUIControlsToCloud();
      
      // Reload local list
      await loadUIControls();
      
      Get.snackbar('نجح', 'تم مزامنة عناصر التحكم الأساسية مع السحابة ✨');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل مزامنة عناصر التحكم: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 📥 Import the admin's own keys from ApiController or DB to avoid re-typing
  Future<void> importPersonalKeys() async {
    try {
      int importedCount = 0;
      final Map<String, String> newKeys = Map.from(managedKeysEditing);

      // 1. Try ApiController first (In-memory cached keys)
      if (Get.isRegistered<ApiController>()) {
        final apiController = Get.find<ApiController>();
        final personalProviders = apiController.providers;
        
        personalProviders.forEach((type, provider) {
          if (provider.apiKey.isNotEmpty) {
            final keyName = type.name;
            newKeys[keyName] = provider.apiKey;
            importedCount++;
          }
        });
      }

      // 2. Fallback: Secure Storage (Primary storage for most settings)
      if (kDebugMode) debugPrint('🧪 Admin: Trying SecureStorage to import keys...');
      if (Get.isRegistered<SecureStorageService>()) {
        final secureStorage = Get.find<SecureStorageService>();
        
        // Comprehensive list of all providers to import
        final List<String> allProviders = [
          'gemini', 'serpapi', 'stability', 'kling', 'github', 
          'removebg', 'deepseek', 'anthropic', 'openai', 'groq', 'azure'
        ];
        
        for (final service in allProviders) {
          final key = await secureStorage.getApiKey(service);
          if (key.isNotEmpty) {
            newKeys[service] = key;
            importedCount++;
          }
          
          // 🔐 Special: Handle Kling Secret Key
          if (service == 'kling') {
            final secret = await secureStorage.getSecretKey(ProviderType.kling);
            if (secret.isNotEmpty) {
              newKeys['kling_secret'] = secret;
            }
          }
        }

        // 🗝️ Special: Handle GitHub Hexa-Keys (v4.0)
        final List<String> gKeys = [];
        for (int i = 1; i <= 6; i++) {
          final k = await secureStorage.getApiKey('github_key_$i');
          if (k.isNotEmpty) {
            gKeys.add(k);
          }
        }
        if (gKeys.isNotEmpty) {
          newKeys['github_hexa'] = jsonEncode(gKeys);
          importedCount++;
          if (kDebugMode) debugPrint('✅ Admin: Imported ${gKeys.length} GitHub Hexa-Keys');
        }
      }

      // 3. Special Case: Gemini OAuth Token (Magic UX)
      if (newKeys['gemini'] == null || newKeys['gemini']!.isEmpty) {
        if (Get.isRegistered<AuthController>()) {
          final auth = Get.find<AuthController>();
          if (auth.geminiAccessToken.value.isNotEmpty) {
            newKeys['gemini'] = 'TOKEN:${auth.geminiAccessToken.value}';
            importedCount++;
            if (kDebugMode) debugPrint('✨ Admin: Imported Gemini OAuth Token');
          }
        }
      }

      managedKeysEditing.assignAll(newKeys);
      
      if (importedCount > 0) {
        Get.snackbar('نجح 📥', 'تم استيراد $importedCount من مفاتيحك الشخصية بنجاح. لا تنسَ الحفظ ✨');
        if (kDebugMode) debugPrint('✅ Admin: Imported keys: ${newKeys.keys.join(', ')}');
      } else {
        Get.snackbar('تنبيه', 'لم يتم العثور على مفاتيح شخصية. يرجى التأكد من إدخالها في شاشة الإعدادات أولاً.');
        if (kDebugMode) debugPrint('⚠️ Admin: No personal keys found in ApiController or DB');
      }
    } catch (e) {
      debugPrint('⚠️ Admin: Failed to import personal keys: $e');
      Get.snackbar('خطأ', 'فشل استيراد المفاتيح: $e');
    }
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    // 🔥 Cancel Firestore subscription
    _usersSubscription?.cancel();
    super.onClose();
  }
}
