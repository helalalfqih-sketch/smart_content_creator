import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../models/api_key_model.dart';
import '../models/setting_model.dart';
import '../models/content_model.dart';
import '../models/media_model.dart';
import '../models/log_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_content_creator.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE api_keys(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_name TEXT NOT NULL,
        api_key TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE generated_content(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        input_type TEXT,
        input_path TEXT,
        prompt TEXT,
        result TEXT,
        model TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE media(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        path TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE videos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_path TEXT NOT NULL,
        description TEXT,
        hashtags TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    _database?.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_content_creator.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  String _getCurrentTimestamp() => DateTime.now().toIso8601String();

  // ==================== USERS TABLE ====================

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return db.insert('users', user.toMap());
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final results = await db.query('users');
    return results.map((map) => UserModel.fromMap(map)).toList();
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return UserModel.fromMap(results.first);
    }
    return null;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllUsers() async {
    final db = await database;
    return db.delete('users');
  }

  // ==================== API KEYS TABLE ====================

  Future<int> insertApiKey(ApiKeyModel apiKey) async {
    final db = await database;
    return db.insert('api_keys', apiKey.toMap());
  }

  Future<List<ApiKeyModel>> getAllApiKeys() async {
    final db = await database;
    final results = await db.query('api_keys');
    return results.map((map) => ApiKeyModel.fromMap(map)).toList();
  }

  Future<ApiKeyModel?> getApiKeyById(int id) async {
    final db = await database;
    final results = await db.query(
      'api_keys',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return ApiKeyModel.fromMap(results.first);
    }
    return null;
  }

  Future<ApiKeyModel?> getApiKeyByService(String serviceName) async {
    final db = await database;
    final results = await db.query(
      'api_keys',
      where: 'service_name = ?',
      whereArgs: [serviceName],
    );
    if (results.isNotEmpty) {
      return ApiKeyModel.fromMap(results.first);
    }
    return null;
  }

  Future<List<ApiKeyModel>> getEnabledApiKeys() async {
    final db = await database;
    final results = await db.query(
      'api_keys',
      where: 'enabled = ?',
      whereArgs: [1],
    );
    return results.map((map) => ApiKeyModel.fromMap(map)).toList();
  }

  Future<int> updateApiKey(ApiKeyModel apiKey) async {
    final db = await database;
    return db.update(
      'api_keys',
      apiKey.toMap(),
      where: 'id = ?',
      whereArgs: [apiKey.id],
    );
  }

  Future<int> updateApiKeyByService(String serviceName, String apiKey) async {
    final db = await database;
    return db.update(
      'api_keys',
      {'api_key': apiKey, 'updated_at': _getCurrentTimestamp()},
      where: 'service_name = ?',
      whereArgs: [serviceName],
    );
  }

  Future<int> toggleApiKeyStatus(int id) async {
    final db = await database;
    final apiKey = await getApiKeyById(id);
    if (apiKey == null) return 0;

    return db.update(
      'api_keys',
      {'enabled': apiKey.enabled ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteApiKey(int id) async {
    final db = await database;
    return db.delete(
      'api_keys',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

 //* Future<int> deleteApiKeyByService(String serviceName) async {
  //  final db = await database;
  //  return db.delete(
  //    'api_keys',
  //    where: 'service_name = ?',
  //    whereArgs: [serviceName],
  //  );
 // }

  Future<int> deleteAllApiKeys() async {
    final db = await database;
    return db.delete('api_keys');
  }

  // ==================== SIMPLIFIED API KEYS METHODS ====================

  /// Save or update an API key (simplified interface)
  Future<void> saveApiKey(String service, String key) async {
    try {
      final db = await database;
      final trimmedKey = key.trim();
      
      if (trimmedKey.isEmpty) {
        throw Exception('API key cannot be empty');
      }

      final existing = await db.query(
        'api_keys',
        where: 'service_name = ?',
        whereArgs: [service],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'api_keys',
          {
            'api_key': trimmedKey,
            'enabled': 1,
          },
          where: 'service_name = ?',
          whereArgs: [service],
        );
      } else {
        await db.insert(
          'api_keys',
          {
            'service_name': service,
            'api_key': trimmedKey,
            'enabled': 1,
            'created_at': _getCurrentTimestamp(),
          },
        );
      }
    } catch (e) {
      throw Exception('Failed to save API key for $service: $e');
    }
  }

  /// Get an API key by service name (simplified interface)
  Future<String?> getApiKey(String service) async {
    try {
      final db = await database;
      final results = await db.query(
        'api_keys',
        where: 'service_name = ?',
        whereArgs: [service],
      );

      if (results.isNotEmpty) {
        return results.first['api_key'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to retrieve API key for $service: $e');
    }
  }

  /// Delete an API key by service name (simplified interface)
  Future<void> deleteApiKeyByService(String service) async {
    try {
      final db = await database;
      await db.delete(
        'api_keys',
        where: 'service_name = ?',
        whereArgs: [service],
      );
    } catch (e) {
      throw Exception('Failed to delete API key for $service: $e');
    }
  }

  // ==================== SETTINGS TABLE ====================

  Future<int> insertSetting(SettingModel setting) async {
    final db = await database;
    return db.insert('settings', setting.toMap());
  }

  Future<List<SettingModel>> getAllSettings() async {
    final db = await database;
    final results = await db.query('settings');
    return results.map((map) => SettingModel.fromMap(map)).toList();
  }

  Future<SettingModel?> getSettingById(int id) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return SettingModel.fromMap(results.first);
    }
    return null;
  }

  Future<SettingModel?> getSettingByKey(String key) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isNotEmpty) {
      return SettingModel.fromMap(results.first);
    }
    return null;
  }

  Future<String?> getSettingValue(String key) async {
    final setting = await getSettingByKey(key);
    return setting?.value;
  }

  Future<int> upsertSetting(String key, String value) async {
    final db = await database;
    final existing = await getSettingByKey(key);

    if (existing != null) {
      return db.update(
        'settings',
        {
          'value': value,
          'updated_at': _getCurrentTimestamp(),
        },
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      return db.insert(
        'settings',
        {
          'key': key,
          'value': value,
          'updated_at': _getCurrentTimestamp(),
        },
      );
    }
  }

  Future<int> updateSetting(SettingModel setting) async {
    final db = await database;
    return db.update(
      'settings',
      setting.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [setting.id],
    );
  }

  Future<int> deleteSetting(int id) async {
    final db = await database;
    return db.delete(
      'settings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSettingByKey(String key) async {
    final db = await database;
    return db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<int> deleteAllSettings() async {
    final db = await database;
    return db.delete('settings');
  }

  // ==================== GENERATED CONTENT TABLE ====================

  Future<int> insertContent(ContentModel content) async {
    final db = await database;
    return db.insert('generated_content', content.toMap());
  }

  Future<List<ContentModel>> getAllContent() async {
    final db = await database;
    final results = await db.query('generated_content', orderBy: 'created_at DESC');
    return results.map((map) => ContentModel.fromMap(map)).toList();
  }

  Future<ContentModel?> getContentById(int id) async {
    final db = await database;
    final results = await db.query(
      'generated_content',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return ContentModel.fromMap(results.first);
    }
    return null;
  }

  Future<List<ContentModel>> getContentByInputType(String inputType) async {
    final db = await database;
    final results = await db.query(
      'generated_content',
      where: 'input_type = ?',
      whereArgs: [inputType],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => ContentModel.fromMap(map)).toList();
  }

  Future<List<ContentModel>> getContentByModel(String model) async {
    final db = await database;
    final results = await db.query(
      'generated_content',
      where: 'model = ?',
      whereArgs: [model],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => ContentModel.fromMap(map)).toList();
  }

  Future<int> updateContent(ContentModel content) async {
    final db = await database;
    return db.update(
      'generated_content',
      content.toMap(),
      where: 'id = ?',
      whereArgs: [content.id],
    );
  }

  Future<int> deleteContent(int id) async {
    final db = await database;
    return db.delete(
      'generated_content',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllContent() async {
    final db = await database;
    return db.delete('generated_content');
  }

  Future<int> deleteOldContent(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return db.delete(
      'generated_content',
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // ==================== MEDIA TABLE ====================

  Future<int> insertMedia(MediaModel media) async {
    final db = await database;
    return db.insert('media', media.toMap());
  }

  Future<List<MediaModel>> getAllMedia() async {
    final db = await database;
    final results = await db.query('media', orderBy: 'created_at DESC');
    return results.map((map) => MediaModel.fromMap(map)).toList();
  }

  Future<MediaModel?> getMediaById(int id) async {
    final db = await database;
    final results = await db.query(
      'media',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return MediaModel.fromMap(results.first);
    }
    return null;
  }

  Future<List<MediaModel>> getMediaByType(String type) async {
    final db = await database;
    final results = await db.query(
      'media',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => MediaModel.fromMap(map)).toList();
  }

  Future<int> updateMedia(MediaModel media) async {
    final db = await database;
    return db.update(
      'media',
      media.toMap(),
      where: 'id = ?',
      whereArgs: [media.id],
    );
  }

  Future<int> deleteMedia(int id) async {
    final db = await database;
    return db.delete(
      'media',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllMedia() async {
    final db = await database;
    return db.delete('media');
  }

  Future<int> deleteOldMedia(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return db.delete(
      'media',
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // ==================== ACTIVITY LOGS TABLE ====================

  Future<int> insertLog(LogModel log) async {
    final db = await database;
    return db.insert('activity_logs', log.toMap());
  }

  Future<int> logAction(String action, {String? details}) async {
    return insertLog(
      LogModel(
        action: action,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<LogModel>> getAllLogs() async {
    final db = await database;
    final results = await db.query('activity_logs', orderBy: 'created_at DESC');
    return results.map((map) => LogModel.fromMap(map)).toList();
  }

  Future<LogModel?> getLogById(int id) async {
    final db = await database;
    final results = await db.query(
      'activity_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return LogModel.fromMap(results.first);
    }
    return null;
  }

  Future<List<LogModel>> getLogsByAction(String action) async {
    final db = await database;
    final results = await db.query(
      'activity_logs',
      where: 'action = ?',
      whereArgs: [action],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => LogModel.fromMap(map)).toList();
  }

  Future<List<LogModel>> getLogsFromDate(DateTime startDate) async {
    final db = await database;
    final results = await db.query(
      'activity_logs',
      where: 'created_at >= ?',
      whereArgs: [startDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => LogModel.fromMap(map)).toList();
  }

  Future<List<LogModel>> getLogsBetweenDates(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final results = await db.query(
      'activity_logs',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => LogModel.fromMap(map)).toList();
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return db.delete(
      'activity_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllLogs() async {
    final db = await database;
    return db.delete('activity_logs');
  }

  Future<int> deleteOldLogs(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return db.delete(
      'activity_logs',
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<int> getLogCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM activity_logs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== UTILITY & ANALYTICS METHODS ====================

  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    final userCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    ) ?? 0;

    final apiKeyCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM api_keys'),
    ) ?? 0;

    final contentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM generated_content'),
    ) ?? 0;

    final mediaCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM media'),
    ) ?? 0;

    final logCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM activity_logs'),
    ) ?? 0;

    return {
      'users': userCount,
      'api_keys': apiKeyCount,
      'content': contentCount,
      'media': mediaCount,
      'logs': logCount,
    };
  }

  Future<void> vacuumDatabase() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<int> getDatabaseSize() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_content_creator.db');
    final dbFile = File(path);
    if (await dbFile.exists()) {
      return dbFile.lengthSync();
    }
    return 0;
  }

  Future<void> backupDatabase() async {
    final databasesPath = await getDatabasesPath();
    final sourcePath = join(databasesPath, 'smart_content_creator.db');
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupPath = join(
      appDocDir.path,
      'backups',
      'smart_content_creator_backup_${DateTime.now().millisecondsSinceEpoch}.db',
    );

    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      final backupDir = Directory(dirname(backupPath));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      await sourceFile.copy(backupPath);
    }
  }

  // ==================== VIDEOS TABLE ====================

  Future<int> insertVideo(String videoPath, {String? description, String? hashtags}) async {
    final db = await database;
    return db.insert(
      'videos',
      {
        'video_path': videoPath,
        'description': description,
        'hashtags': hashtags,
        'created_at': _getCurrentTimestamp(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllVideos() async {
    final db = await database;
    return db.query('videos', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getVideoById(int id) async {
    final db = await database;
    final results = await db.query(
      'videos',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateVideo(int id, {String? description, String? hashtags}) async {
    final db = await database;
    return db.update(
      'videos',
      {
        'description': description,
        'hashtags': hashtags,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteVideo(int id) async {
    final db = await database;
    return db.delete(
      'videos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllVideos() async {
    final db = await database;
    return db.delete('videos');
  }
}
