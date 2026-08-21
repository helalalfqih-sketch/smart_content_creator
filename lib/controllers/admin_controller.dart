import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:smart_content_creator/services/db_service.dart';
import 'package:smart_content_creator/services/permissions_sync_service.dart';
import 'package:smart_content_creator/services/firestore_user_service.dart';
import 'package:smart_content_creator/services/subscription_service.dart';
import 'package:smart_content_creator/services/activity_tracking_service.dart';
import 'auth_controller.dart';

class AdminController extends GetxController {
  final DBService _db = Get.find<DBService>();
  static const List<String> _managedAdminKeyControls = [
    'use_managed_keys',
    'managed_key_gemini',
    'managed_key_serpapi',
    'managed_key_stability',
    'managed_key_kling',
    'managed_key_github',
  ];

  // Observable lists
  final RxBool isLoading = false.obs;
  final RxBool hasNewUsers = false.obs;
  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> uiControls = <Map<String, dynamic>>[].obs;

  // 🔍 Search & Filter State
  final RxString searchQuery = ''.obs;
  final RxString filterRole = 'all'.obs; // all / admin / creator / user / premium / blocked / new
  final RxString filterSort = 'newest'.obs; // newest / most_active / name_az

  /// 🔍 القائمة المفلترة - تُحسب تلقائياً من users + فلاتر البحث
  List<Map<String, dynamic>> get filteredUsers {
    var result = users.toList();

    // فلتر النص
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((u) {
        final name = (u['username'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    // فلتر الدور/الحالة
    switch (filterRole.value) {
      case 'admin':
        result = result.where((u) => u['role'] == 'admin').toList();
        break;
      case 'creator':
        result = result.where((u) => u['role'] == 'creator').toList();
        break;
      case 'user':
        result = result.where((u) => u['role'] == 'user').toList();
        break;
      case 'premium':
        result = result.where((u) => u['isPremium'] == true).toList();
        break;
      case 'blocked':
        result = result.where((u) => u['is_ai_blocked'] == true).toList();
        break;
      case 'new':
        result = result.where((u) => u['newUserNotification'] == true).toList();
        break;
    }

    // الترتيب
    switch (filterSort.value) {
      case 'most_active':
        result.sort((a, b) =>
            ((b['ai_total_credits'] as int?) ?? 0)
                .compareTo((a['ai_total_credits'] as int?) ?? 0));
        break;
      case 'name_az':
        result.sort((a, b) =>
            (a['username'] ?? '').toString()
                .compareTo((b['username'] ?? '').toString()));
        break;
      case 'newest':
      default:
        // already sorted by in-memory sort from Firestore
        break;
    }

    return result;
  }

  /// 📊 إحصاءات النظام الشاملة - محسوبة من users في الذاكرة
  Map<String, int> get systemStats {
    int premium = 0, blocked = 0, newUsers = 0, totalCredits = 0;
    for (final u in users) {
      if (u['isPremium'] == true) premium++;
      if (u['is_ai_blocked'] == true) blocked++;
      if (u['newUserNotification'] == true) newUsers++;
      totalCredits += (u['ai_total_credits'] as int?) ?? 0;
    }
    return {
      'total': users.length,
      'premium': premium,
      'blocked': blocked,
      'new': newUsers,
      'totalCredits': totalCredits,
    };
  }

  // 🎧 Audio Feedback
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isFirstLoad = true;
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  // Selected user for editing
  final Rxn<Map<String, dynamic>> selectedUser = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> selectedUserPermissions =
      <Map<String, dynamic>>[].obs;
  final RxString permissionScopeFilter = 'all'.obs;

  // ✅ تتبع المستخدمين الذين تم تعديل صلاحياتهم يدوياً
  final RxSet<String> _modifiedUserIds = <String>{}.obs;
  int get modifiedCount => _modifiedUserIds.length;

  // 🌍 Global SaaS & AI Settings
  final RxMap<String, dynamic> globalSettings = <String, dynamic>{}.obs;
  final RxInt freeDailyLimitEditing = 50.obs;
  final RxMap<String, String> managedKeysEditing = <String, String>{}.obs;

  // 📊 User Activity Tracking
  final RxList<Map<String, dynamic>> selectedUserActivityLogs = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> allRecentActivityLogs = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingActivity = false.obs;

  /// 🔥 SaaS: منح اشتراك لمستخدم
  Future<void> grantUserSubscription({
    required String userId,
    required String planId,
    required int durationDays,
  }) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      _safeSnackbar('حماية النظام 🛡️', 'لا يمكن تعديل اشتراك المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    isLoading.value = true;
    try {
      final subscriptionService = Get.find<SubscriptionService>();
      await subscriptionService.grantSubscription(
        uid: userId,
        planId: planId,
        durationDays: durationDays,
      );
      _safeSnackbar('نجح', 'تم منح الاشتراك للمستخدم بنجاح 💎');
    } catch (e) {
      _safeSnackbar('خطأ', 'فشل منح الاشتراك: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔥 SaaS: سحب الاشتراك
  Future<void> revokeUserSubscription(String userId) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      _safeSnackbar('حماية النظام 🛡️', 'لا يمكن تعديل اشتراك المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    isLoading.value = true;
    try {
      final subscriptionService = Get.find<SubscriptionService>();
      await subscriptionService.revokeSubscription(userId);
      _safeSnackbar('تم', 'تم سحب الاشتراك من المستخدم');
    } catch (e) {
      _safeSnackbar('خطأ', 'فشل سحب الاشتراك: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔥 AI Config: تحديث الإعدادات العالمية
  Future<void> updateGlobalAiSettings([Map<String, dynamic>? settings]) async {
    isLoading.value = true;
    try {
      final finalSettings = settings ?? {
        'free_daily_limit': freeDailyLimitEditing.value,
        'managed_keys': managedKeysEditing,
      };

      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('ai_config')
          .set(finalSettings, SetOptions(merge: true));
      
      globalSettings.addAll(finalSettings);
      _safeSnackbar('نجح', 'تم تحديث الإعدادات العالمية ✅');
    } catch (e) {
      _safeSnackbar('خطأ', 'فشل تحديث الإعدادات: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔍 التحقق من حالة الإعدادات
  Future<void> checkConfigStatus() async {
    // يمكن إضافة منطق للتحقق من صحة المفاتيح هنا
    debugPrint('🔍 Checking global config status...');
  }

  /// 🔑 استيراد المفاتيح الشخصية للمسؤول كمفاتيح عالمية
  Future<void> importPersonalKeys() async {
    _safeSnackbar('قريباً', 'سيتم تفعيل استيراد المفاتيح الشخصية في التحديث القادم');
  }

  // ✅ AI Config Status
  bool get isConfigValid => globalSettings.isNotEmpty;

  /// 🔥 تهيئة الإعدادات العالمية من السحابة
  Future<void> initializeGlobalConfig() async {
    isLoading.value = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('ai_config')
          .get();
      if (snapshot.exists) {
        globalSettings.addAll(snapshot.data()!);
        freeDailyLimitEditing.value = globalSettings['free_daily_limit'] ?? 50;
        managedKeysEditing.assignAll(Map<String, String>.from(globalSettings['managed_keys'] ?? {}));
      }
    } catch (e) {
      debugPrint('⚠️ Failed to initialize AI config: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    subscribeToUsers(force: false); // 🔥 Real-time Firestore sync
    loadUIControls();
    initializeGlobalConfig(); // 🧠 Load AI and limit settings
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    ever(hasNewUsers, (bool hasNew) {
      if (hasNew && !_isFirstLoad) {
        _playNotificationSound();
        // Prevent GetBuilder rebuild during an active build frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNewUserNotification();
        });
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

  void _safeSnackbar(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Color? backgroundColor,
    Color? colorText,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(
        title,
        message,
        snackPosition: snackPosition,
        backgroundColor: backgroundColor,
        colorText: colorText,
      );
    });
  }

  /// 🔥 Subscribe to Firestore users collection for real-time updates
  void subscribeToUsers({bool force = false}) {
    if (_usersSubscription != null && !force) {
      if (kDebugMode) {
        debugPrint('ℹ️ AdminController: Already subscribed to users, skipping.');
      }
      return;
    }

    final authController = Get.find<AuthController>();
    if (!authController.isAdmin) {
      if (kDebugMode) {
        debugPrint('⚠️ AdminController: User is not admin. Skipping Firestore users subscription.');
      }
      _loadUsersFromLocalDB();
      return;
    }

    if (force && _usersSubscription != null) {
      _usersSubscription!.cancel();
      _usersSubscription = null;
    }

    try {
      _usersSubscription = FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .listen(
        (snapshot) {
          users.value = snapshot.docs.map((doc) {
            final data = doc.data();
            final aiUsage = data['ai_usage'] as Map? ?? {};
            final resolvedName = data['name']?.toString() ??
                data['username']?.toString() ??
                data['displayName']?.toString() ??
                (data['email']?.toString().split('@').first ?? 'مستخدم');

            return {
              'id': doc.id, // Firestore UID
              'username': resolvedName,
              'email': data['email']?.toString() ?? '',
              'role': data['role']?.toString() ?? 'user',
              'bio': data['bio']?.toString() ?? '',
              'photo_url': data['photo_url']?.toString() ?? '',
              'cover_url': data['cover_url']?.toString() ?? '',
              'newUserNotification': data['newUserNotification'] ?? false,
              'permissions_count': (data['permissions'] is Map) ? (data['permissions'] as Map).length : 0,
              'permissions': data['permissions'] ?? {},
               'is_ai_blocked': data['is_ai_blocked'] == true,
               'isPremium': data['isPremium'] == true,
               'subscription': data['subscription'] ?? {},
               'createdAt': data['createdAt'],
               'lastLogin': data['lastLogin'],
               'lastSeen': data['lastSeen'],
               'creator_stats': data['creator_stats'] ?? {},
               // 📊 بيانات استهلاك رصيد AI
               'ai_total_credits': (aiUsage['total_credits'] as num?)?.toInt() ?? 0,
               'ai_last_action': aiUsage['last_action']?.toString() ?? '',
               'ai_last_action_at': aiUsage['last_action_at'],
             };
          }).toList()
            // ✅ ترتيب يدوي في الذاكرة: الأحدث أولاً
            // المستخدمون بدون createdAt (قدامى) يظهرون في النهاية
            ..sort((a, b) {
              final aTs = a['createdAt'];
              final bTs = b['createdAt'];
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;  // a goes to end
              if (bTs == null) return -1; // b goes to end
              // Firestore Timestamp comparison
              final aMillis = (aTs is DateTime) ? aTs.millisecondsSinceEpoch
                  : (aTs?.millisecondsSinceEpoch ?? 0);
              final bMillis = (bTs is DateTime) ? bTs.millisecondsSinceEpoch
                  : (bTs?.millisecondsSinceEpoch ?? 0);
              return bMillis.compareTo(aMillis); // descending
            });

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
      subscribeToUsers(force: true); // Force re-subscribe
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
      _safeSnackbar('خطأ', 'فشل تحميل عناصر الواجهة');
    }
  }

  /// Select user for editing permissions
  Future<void> selectUser(Map<String, dynamic> user) async {
    selectedUser.value = user;
    permissionScopeFilter.value = 'all';
    if (user['id'] != null) {
      await loadUserPermissions(user['id'].toString());
      loadUserActivity(user['id'].toString()); // 📊 تحميل سجل النشاط
    }
  }

  /// 📊 تحميل سجل نشاط مستخدم معين من Firestore
  Future<void> loadUserActivity(String userId) async {
    isLoadingActivity.value = true;
    try {
      if (Get.isRegistered<ActivityTrackingService>()) {
        final logs = await Get.find<ActivityTrackingService>().getUserActivityLogs(userId);
        selectedUserActivityLogs.assignAll(logs);
      }
    } catch (e) {
      debugPrint('⚠️ loadUserActivity error: $e');
    } finally {
      isLoadingActivity.value = false;
    }
  }

  /// 📊 تحميل آخر النشاطات لجميع المستخدمين (للأدمن)
  Future<void> loadAllRecentActivity() async {
    isLoadingActivity.value = true;
    try {
      if (Get.isRegistered<ActivityTrackingService>()) {
        final logs = await Get.find<ActivityTrackingService>().getAllRecentLogs(limit: 100);
        allRecentActivityLogs.assignAll(logs);
      }
    } catch (e) {
      debugPrint('⚠️ loadAllRecentActivity error: $e');
    } finally {
      isLoadingActivity.value = false;
    }
  }

  void setPermissionScopeFilter(String scope) {
    permissionScopeFilter.value = scope;
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
      _safeSnackbar('خطأ', 'فشل تحميل صلاحيات المستخدم من السحابة');
    }
  }

  bool _isAlwaysAllowed(String controlName) {
    // List of basic controls that are open by default (same as PermissionsController)
    const alwaysAllowed = [
      'ai_chat_screen',
      'chat_image_attach',
      'chat_camera_attach',
      'chat_file_attach',
      'chat_audio_enhance',
      'video_gen',
      'audio_enhance',
    ];
    return alwaysAllowed.contains(controlName);
  }

  bool _isScreenControl(Map<String, dynamic> control) {
    final category = (control['category'] ?? '').toString().toLowerCase();
    final controlName = (control['control_name'] ?? '').toString().toLowerCase();
    return category == 'screen' || controlName.endsWith('_screen');
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
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      _safeSnackbar('حماية النظام 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    try {
      // Optimistic update so UI colors/switches change immediately.
      final idx = selectedUserPermissions.indexWhere(
        (p) => p['control_name'] == controlName,
      );
      if (idx >= 0) {
        final updated = Map<String, dynamic>.from(selectedUserPermissions[idx]);
        updated['visible'] = visible ? 1 : 0;
        selectedUserPermissions[idx] = updated;
      } else {
        selectedUserPermissions.add({
          'control_name': controlName,
          'visible': visible ? 1 : 0,
          'enabled': _isAlwaysAllowed(controlName) ? 1 : 0,
          'description': controlName,
          'category': 'button',
        });
      }

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

      _safeSnackbar(
        'نجح',
        visible ? 'تم إظهار العنصر للمستخدم' : 'تم إخفاء العنصر عن المستخدم',
      );

      // Refresh from source of truth.
      await loadUserPermissions(userId);

      // No need to update local DB permissions count manually as we're not using it for the list anymore?
      // Actually AdminController list uses data from 'users' collection which might lag behind 'user_permissions' collection
      // But that's acceptable for now.
    } catch (e) {
      debugPrint('Error toggling visibility: $e');
      _safeSnackbar('خطأ', 'فشل تحديث الصلاحية');
    }
  }

  /// Toggle control enabled state for user
  Future<void> toggleControlEnabled({
    required String userId,
    required String controlName,
    required bool enabled,
  }) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      _safeSnackbar('حماية النظام 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    try {
      // Optimistic update so UI colors/switches change immediately.
      final idx = selectedUserPermissions.indexWhere(
        (p) => p['control_name'] == controlName,
      );
      if (idx >= 0) {
        final updated = Map<String, dynamic>.from(selectedUserPermissions[idx]);
        updated['enabled'] = enabled ? 1 : 0;
        selectedUserPermissions[idx] = updated;
      } else {
        selectedUserPermissions.add({
          'control_name': controlName,
          'visible': _isAlwaysAllowed(controlName) ? 1 : 0,
          'enabled': enabled ? 1 : 0,
          'description': controlName,
          'category': 'button',
        });
      }

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

      _safeSnackbar(
        'نجح',
        enabled ? 'تم تفعيل العنصر للمستخدم' : 'تم تعطيل العنصر للمستخدم',
      );

      // Refresh permissions
      await loadUserPermissions(userId);
    } catch (e) {
      debugPrint('Error toggling enabled state: $e');
      _safeSnackbar('خطأ', 'فشل تحديث الصلاحية');
    }
  }

  /// Toggle AI access for a user - 🛑 Kill Switch
  Future<void> toggleUserAiBlock(String userId, bool isBlocked) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      _safeSnackbar('حماية النظام 🛡️', 'لا يمكن قطع اتصال الخدمة عن المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'is_ai_blocked': isBlocked});

      _safeSnackbar(
        isBlocked ? 'تم قطع الاتصال 🛑' : 'تم إعادة الاتصال ✅',
        isBlocked
            ? 'تم تعطيل كافة خدمات AI لهذا المستخدم'
            : 'تم تفعيل خدمات AI للمستخدم بنجاح',
        backgroundColor: isBlocked
            ? Colors.redAccent.withValues(alpha: 0.8)
            : Colors.greenAccent.withValues(alpha: 0.8),
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
      _safeSnackbar('خطأ', 'فشل تغيير حالة الاتصال');
    }
  }

  /// Bulk apply permissions by scope (screens/buttons/all).
  Future<void> applyBulkPermissionByScope({
    required String userId,
    required String scope,
    required bool visible,
    required bool enabled,
  }) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      Get.snackbar('حماية النظام 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    try {
      final normalizedScope = scope.toLowerCase();
      final targetControls = uiControls.where((control) {
        if (normalizedScope == 'all') return true;
        final isScreen = _isScreenControl(control);
        if (normalizedScope == 'screens') return isScreen;
        if (normalizedScope == 'buttons') return !isScreen;
        return false;
      }).toList();

      if (targetControls.isEmpty) {
        Get.snackbar('تنبيه', 'لا توجد عناصر متاحة ضمن هذا النطاق');
        return;
      }

      for (final control in targetControls) {
        final controlName = (control['control_name'] ?? '').toString();
        if (controlName.isEmpty) continue;

        // Optimistic UI update for immediate feedback.
        final idx = selectedUserPermissions.indexWhere(
          (p) => p['control_name'] == controlName,
        );
        if (idx >= 0) {
          final updated = Map<String, dynamic>.from(selectedUserPermissions[idx]);
          updated['visible'] = visible ? 1 : 0;
          updated['enabled'] = enabled ? 1 : 0;
          selectedUserPermissions[idx] = updated;
        } else {
          selectedUserPermissions.add({
            'control_name': controlName,
            'visible': visible ? 1 : 0,
            'enabled': enabled ? 1 : 0,
            'description': control['description'] ?? controlName,
            'category': control['category'] ?? 'button',
          });
        }

        if (_syncService != null) {
          await _syncService!.syncPermissionToCloud(
            userId: userId,
            controlName: controlName,
            visible: visible,
            enabled: enabled,
          );
        }
      }

      _modifiedUserIds.add(userId);
      await loadUserPermissions(userId);

      final actionLabel = visible ? 'منح' : 'إخفاء';
      final scopeLabel = normalizedScope == 'screens'
          ? 'الشاشات'
          : normalizedScope == 'buttons'
              ? 'الأزرار'
              : 'العناصر';
      Get.snackbar('نجح', 'تم $actionLabel جميع $scopeLabel');
    } catch (e) {
      debugPrint('Error applying bulk permissions: $e');
      Get.snackbar('خطأ', 'فشل تطبيق الصلاحيات الجماعية');
    }
  }

  /// Link user account to admin-managed API keys permissions.
  Future<void> linkUserToAdminManagedKeys(String userId) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      Get.snackbar('حماية النظام 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    try {
      for (final controlName in _managedAdminKeyControls) {
        final idx = selectedUserPermissions.indexWhere(
          (p) => p['control_name'] == controlName,
        );
        if (idx >= 0) {
          final updated = Map<String, dynamic>.from(selectedUserPermissions[idx]);
          updated['visible'] = 1;
          updated['enabled'] = 1;
          selectedUserPermissions[idx] = updated;
        } else {
          selectedUserPermissions.add({
            'control_name': controlName,
            'visible': 1,
            'enabled': 1,
            'description': 'Admin Managed Key Access',
            'category': 'System',
          });
        }

        if (_syncService != null) {
          await _syncService!.syncPermissionToCloud(
            userId: userId,
            controlName: controlName,
            visible: true,
            enabled: true,
          );
        }
      }

      _modifiedUserIds.add(userId);
      await loadUserPermissions(userId);
      Get.snackbar('نجح', 'تم ربط المستخدم بمفاتيح الأدمن المُدارة');
    } catch (e) {
      debugPrint('Error linking user to managed admin keys: $e');
      Get.snackbar('خطأ', 'فشل ربط المستخدم بمفاتيح الأدمن');
    }
  }

  /// Unlink user account from admin-managed API keys permissions.
  Future<void> unlinkUserFromAdminManagedKeys(String userId) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      Get.snackbar('حماية النظام 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
    try {
      for (final controlName in _managedAdminKeyControls) {
        final idx = selectedUserPermissions.indexWhere(
          (p) => p['control_name'] == controlName,
        );
        if (idx >= 0) {
          final updated = Map<String, dynamic>.from(selectedUserPermissions[idx]);
          updated['visible'] = 0;
          updated['enabled'] = 0;
          selectedUserPermissions[idx] = updated;
        } else {
          selectedUserPermissions.add({
            'control_name': controlName,
            'visible': 0,
            'enabled': 0,
            'description': 'Admin Managed Key Access',
            'category': 'System',
          });
        }

        if (_syncService != null) {
          await _syncService!.syncPermissionToCloud(
            userId: userId,
            controlName: controlName,
            visible: false,
            enabled: false,
          );
        }
      }

      _modifiedUserIds.add(userId);
      await loadUserPermissions(userId);
      Get.snackbar('نجح', 'تم فصل المستخدم عن مفاتيح الأدمن المُدارة');
    } catch (e) {
      debugPrint('Error unlinking user from managed admin keys: $e');
      Get.snackbar('خطأ', 'فشل فصل المستخدم عن مفاتيح الأدمن');
    }
  }

  /// Change user role - 🔥 Syncs to Firestore
  Future<void> changeUserRole(String userId, String newRole) async {
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      Get.snackbar('حماية النظام 🛡️', 'لا يمكن تعديل دور المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
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
    final user = users.firstWhereOrNull((u) => u['id'] == userId);
    if (user != null && (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com') {
      Get.snackbar('حماية النظام 🛡️', 'لا يمكن حذف المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white);
      return;
    }
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

  /// 🔥 تنظيف المستخدمين الوهميين (الذين ليس لديهم إيميل أو إيميلهم غير صالح أو بدون اسم)
  Future<void> cleanFakeUsers() async {
    isLoading.value = true;
    int deletedCount = 0;
    try {
      final List<String> fakeUserIds = [];
      for (var user in users) {
        final email = (user['email'] ?? '').toString().trim();
        final username = (user['username'] ?? '').toString().trim();
        
        // يعتبر وهمي إذا كان الإيميل فارغاً، أو لا يحتوي على @، أو الاسم فارغاً
        if (email.isEmpty || !email.contains('@') || username.isEmpty) {
          final id = user['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            fakeUserIds.add(id);
          }
        }
      }

      if (fakeUserIds.isEmpty) {
        _safeSnackbar('تنبيه', 'لم يتم العثور على أي مستخدمين وهميين لتنظيفهم 🧹');
        return;
      }

      // حذف المستخدمين من Firestore
      for (var id in fakeUserIds) {
        await FirebaseFirestore.instance.collection('users').doc(id).delete();
        if (_syncService != null) {
          await _syncService!.deleteUserPermissionsFromCloud(id);
        }
        deletedCount++;
      }

      _safeSnackbar('نجح التنظيف 🧹', 'تم حذف $deletedCount مستخدم وهمي بنجاح!');
      selectedUser.value = null;
      selectedUserPermissions.clear();
    } catch (e) {
      debugPrint('Error cleaning fake users: $e');
      _safeSnackbar('خطأ', 'فشل تنظيف المستخدمين الوهميين: $e');
    } finally {
      isLoading.value = false;
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


  // ──────────────────────────────────────────────────────
  // 🎯 AI Backend Switching (Phase 2)
  // ──────────────────────────────────────────────────────

  /// 🔄 تبديل مسار الذكاء الاصطناعي للمستخدم
  Future<void> switchUserAiBackend(String uid, String newBackend) async {
    try {
      final firestoreService = Get.find<FirestoreUserService>();
      final success = await firestoreService.switchUserAiBackend(
        uid: uid,
        newBackend: newBackend,
      );

      if (success) {
        // تحديث القائمة المحلية
        final index = users.indexWhere((u) => u['uid'] == uid);
        if (index != -1) {
          users[index] = {...users[index], 'ai_backend': newBackend};
          users.refresh();
        }
        Get.snackbar(
          '✅ تم التبديل',
          'مسار AI للمستخدم: $newBackend',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar('❌ خطأ', 'فشل تبديل مسار AI');
      }
    } catch (e) {
      Get.snackbar('❌ خطأ', 'فشل تبديل مسار AI: $e');
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
