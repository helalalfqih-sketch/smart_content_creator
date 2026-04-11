import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import '../core/storage/storage_keys.dart';
import '../services/db_service.dart';
import 'auth_controller.dart';

class ChatHistoryController extends GetxController {
  final DBService _dbService = Get.find<DBService>();
  final AppStorageService _storage = Get.find<AppStorageService>();

  // Observables
  final sessions = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final canMigrate = false.obs; // 🚀 New: Detect legacy sessions
  final currentSessionId = RxnInt(); // Null = New Chat

  @override
  void onInit() {
    super.onInit();

    // 1. استعادة معرف الجلسة الأخير
    _loadLastSession();

    // 2. مستمع لحفظ الجلسة فور تغييرها
    ever(currentSessionId, (int? id) => _saveLastSession(id));

    // Listen to Auth changes to reload sessions when user changes (login/logout/switch)
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      // Only reload when checking is FINISHED (false)
      ever(auth.isCheckingSession, (bool isChecking) {
        if (!isChecking) {
          loadSessions();
        }
      });
    }
    loadSessions();
  }

  void _loadLastSession() {
    final lastId = _storage.read<int>(StorageKeys.lastChatSessionId);
    if (lastId != null && currentSessionId.value == null) {
      currentSessionId.value = lastId;
      if (kDebugMode) debugPrint("💾 History Controller: Restored last session ID: $lastId");
    }
  }

  Future<void> _saveLastSession(int? id) async {
    try {
      if (id != null) {
        await _storage.write(StorageKeys.lastChatSessionId, id);
      } else {
        await _storage.remove(StorageKeys.lastChatSessionId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving last session ID: $e");
    }
  }

  String? get _currentUserId {
    if (!Get.isRegistered<AuthController>()) return null;
    final auth = Get.find<AuthController>();
    final user = auth.user;
    return user?['id']?.toString() ?? auth.firebaseUid;
  }

  String? get _currentFirebaseUid {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().firebaseUid;
  }

  /// Load all sessions from DB
  Future<void> loadSessions() async {
    try {
      isLoading.value = true;
      final userId = _currentUserId;
      final results = await _dbService.getSessions(userId: userId);
      sessions.assignAll(results);
      
      if (results.isEmpty) {
        final total = await _dbService.getRecords('chat_sessions', limit: 1);
        canMigrate.value = total.isNotEmpty;
      } else {
        canMigrate.value = false;
      }
    } catch (e) {
      debugPrint("❌ History Controller: Error loading sessions: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshSessions() => loadSessions();

  /// Create a new session with the first message prompt as title
  Future<int> createNewSession(String title, {bool shouldSelect = true}) async {
    try {
      final cleanTitle = title.length > 30 ? '${title.substring(0, 30)}...' : title;
      final userId = _currentUserId;
      final firebaseUid = _currentFirebaseUid;
      final id = await _dbService.insertRecord('chat_sessions', {
        'title': cleanTitle,
        'user_id': userId,
        'firebase_uid': firebaseUid,
        'created_at': DateTime.now().toIso8601String(),
        'last_message_at': DateTime.now().toIso8601String(),
      });
      
      await loadSessions(); // Refresh list
      if (shouldSelect) {
        currentSessionId.value = id;
      }
      return id;
    } catch (e) {
      debugPrint("Error creating session: $e");
      return -1;
    }
  }

  void selectSession(int id) {
    currentSessionId.value = id;
    Get.back(); // Close drawer
  }

  void startNewChat() {
    currentSessionId.value = null;
    Get.back(); // Close drawer
  }

  void resetConversation() {
    currentSessionId.value = null;
    loadSessions(); 
  }

  Future<void> renameSession(int id, String newTitle) async {
    try {
      await _dbService.updateRecord('chat_sessions', {'title': newTitle}, where: 'id = ?', whereArgs: [id]);
      await loadSessions();
    } catch (e) {
      debugPrint("Error renaming session: $e");
    }
  }

  Future<void> deleteSession(int id) async {
    try {
      await _dbService.deleteRecord('chat_sessions', where: 'id = ?', whereArgs: [id]);
      if (currentSessionId.value == id) {
        currentSessionId.value = null;
      }
      await loadSessions();
    } catch (e) {
      debugPrint("Error deleting session: $e");
    }
  }

  Future<void> deleteAllSessions() async {
    try {
      final userId = _currentUserId;
      final fbUid = _currentFirebaseUid;
      
      // Delete sessions matching the local ID, Firebase UID, OR legacy sessions with no ID
      final List<String> conditions = ['user_id IS NULL'];
      final List<dynamic> args = [];
      
      if (userId != null) {
        conditions.add('user_id = ?');
        args.add(userId);
      }
      if (fbUid != null) {
        conditions.add('firebase_uid = ?');
        args.add(fbUid);
      }
      
      await _dbService.deleteRecord(
        'chat_sessions', 
        where: conditions.join(' OR '), 
        whereArgs: args
      );
      
      currentSessionId.value = null;
      await loadSessions();
    } catch (e) {
      debugPrint("Error deleting all sessions: $e");
    }
  }

  Future<void> migrateLegacySessions() async {
    final userId = _currentUserId;
    if (userId == null) return;
    isLoading.value = true;
    try {
      await _dbService.updateRecord('chat_sessions', {'user_id': userId}, where: 'user_id IS NULL OR user_id = ?', whereArgs: ['1']);
      await loadSessions();
    } finally {
      isLoading.value = false;
    }
  }
}
