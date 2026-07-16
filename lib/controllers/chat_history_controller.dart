import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import '../core/storage/storage_keys.dart';
import '../services/db_service.dart';
import 'auth_controller.dart';

class ChatHistoryController extends GetxController {
  late DBService _dbService;
  late AppStorageService _storage;

  // Observables
  final sessions = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final canMigrate = false.obs; // 🚀 New: Detect legacy sessions
  final currentSessionId = RxnInt(); // Null = New Chat

  @override
  void onInit() {
    _dbService = Get.find<DBService>();
    _storage = Get.find<AppStorageService>();
    super.onInit();

    // يتم بدء محادثة جديدة دائماً عند التشغيل (مثل Gemini/ChatGPT)

    // 2. مستمع لحفظ الجلسة فور تغييرها
    ever(currentSessionId, (int? id) => _saveLastSession(id));

    // Listen to Auth changes to reload sessions when user changes (login/logout/switch)
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      // 1. Listen to Session Check status
      ever(auth.isCheckingSession, (bool isChecking) {
        if (!isChecking) {
          loadSessions();
        }
      });
      // 2. Listen to UID changes (Crucial for multi-account or anonymous-to-real transitions)
      ever(auth.firebaseUidRx, (_) => loadSessions());
    }
    loadSessions();
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
      final firebaseUid = _currentFirebaseUid;
      
      final results = await _dbService.getSessions(
        userId: userId,
        firebaseUid: firebaseUid,
      );
      sessions.assignAll(results);
      
      // التحقق من وجود محادثات قديمة أو محلية غير مرتبطة بالحساب الحالي
      final legacyResults = await _dbService.getRecords('chat_sessions', 
          where: '(user_id IS NULL OR user_id = ?) AND firebase_uid IS NULL', 
          whereArgs: ['1'], 
          limit: 1);
      canMigrate.value = legacyResults.isNotEmpty && userId != '1' && userId != null;
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
    // إغلاق القائمة الجانبية أو أي نافذة منبثقة فوراً لرؤية المحادثة المفتوحة
    if (Get.isOverlaysOpen) {
      Get.back();
    }
  }

  void startNewChat() {
    currentSessionId.value = null;
    if (Get.isOverlaysOpen) {
      Get.back();
    }
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
      // Delete messages for this session explicitly (SQLite foreign_keys may be disabled)
      await _dbService.deleteRecord('chat_history',
          where: 'session_id = ?', whereArgs: [id]);
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

      // Fetch current user sessions IDs first, so we can delete their messages too.
      final sessionsToDelete = await _dbService.getSessions(
        userId: userId,
        firebaseUid: fbUid,
      );
      final ids = sessionsToDelete
          .map((s) => s['id'])
          .whereType<int>()
          .toList();
      for (final id in ids) {
        await _dbService.deleteRecord('chat_history',
            where: 'session_id = ?', whereArgs: [id]);
      }
      
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
