import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 🧠 DBService: المحرك المركزي لقاعدة البيانات (The Refactored Magic Engine)
/// يستخدم نظام Generic CRUD لاختصار 2200 سطر إلى هيكل ذكي وسهل الصيانة.
class DBService extends GetxService {
  static Database? _database;
  static const int _dbVersion = 31;
  bool _schemaChecked = false;

  // ---------------------------------------------------------------------------
  // 1. التهيئة (Initialization)
  // ---------------------------------------------------------------------------
  
  Future<DBService> init() async {
    await db;
    return this;
  }

  Future<Database> get db async {
    if (_database != null) {
      if (!_schemaChecked) await _ensureColumnsExist(_database!);
      return _database!;
    }
    _database = await _init();
    if (_database != null) await _ensureColumnsExist(_database!);
    return _database!;
  }

  Future<Database> _init() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'smart_content_creator.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. المخطط الهندسي (The Master Schema - 22+ Tables) 🏗️
  // ---------------------------------------------------------------------------

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. الهوية والمستخدمين
    batch.execute('''CREATE TABLE users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      username TEXT,
      bio TEXT,
      password_hash TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      photo_url TEXT,
      cover_url TEXT,
      firebase_uid TEXT,
      created_at TEXT
    )''');

    // 2. الجلسات (Sessions)
    batch.execute('''CREATE TABLE chat_sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      created_at TEXT NOT NULL,
      last_message_at TEXT NOT NULL,
      last_message_text TEXT,
      user_id TEXT,
      firebase_uid TEXT,
      is_synced INTEGER DEFAULT 0
    )''');

    // 3. الرسائل وسجل الدردشة (AI Context)
    batch.execute('''CREATE TABLE chat_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER,
      conversation_id TEXT,
      provider TEXT NOT NULL,
      user_message TEXT,
      ai_response TEXT,
      message_type TEXT DEFAULT 'text',
      media_path TEXT,
      video_url TEXT,
      product_context TEXT,
      meta_data TEXT, 
      state TEXT DEFAULT 'completed',
      created_at TEXT NOT NULL,
      user_id TEXT,
      firebase_uid TEXT,
      is_synced INTEGER DEFAULT 0,
      embedding TEXT,
      FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
    )''');

    // 4. المنتجات والذاكرة (Product AI)
    batch.execute('''CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      description TEXT,
      image_path TEXT,
      video_url TEXT,
      price REAL DEFAULT 0.0,
      category TEXT,
      is_favorite INTEGER DEFAULT 0,
      embedding TEXT,
      created_at TEXT
    )''');

    batch.execute('''CREATE TABLE product_memory(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL UNIQUE,
      product_name TEXT NOT NULL,
      product_name_en TEXT,
      brand_name TEXT,
      brand_name_en TEXT,
      category TEXT,
      model TEXT,
      search_query TEXT NOT NULL,
      image_path TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');

    // 5. الإعدادات، المفاتيح، والـ Cache
    batch.execute('''CREATE TABLE api_keys(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      service_name TEXT NOT NULL UNIQUE,
      api_key TEXT NOT NULL,
      enabled INTEGER DEFAULT 1,
      created_at TEXT
    )''');

    batch.execute('''CREATE TABLE response_cache(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      input_hash TEXT NOT NULL UNIQUE,
      response_data TEXT NOT NULL,
      type TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');

    // 6. الصلاحيات والتحكم (UI Permissions)
    batch.execute('''CREATE TABLE ui_controls(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      control_name TEXT UNIQUE NOT NULL,
      description TEXT NOT NULL,
      category TEXT DEFAULT 'button',
      created_at TEXT
    )''');

    batch.execute('''CREATE TABLE user_permissions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      control_id INTEGER NOT NULL,
      visible INTEGER DEFAULT 1,
      enabled INTEGER DEFAULT 1,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(control_id) REFERENCES ui_controls(id) ON DELETE CASCADE,
      UNIQUE(user_id, control_id)
    )''');

    // 7. التقارير، الترندات، والوسائط (Media & Trends)
    batch.execute('''CREATE TABLE viral_booster_reports(id INTEGER PRIMARY KEY AUTOINCREMENT, video_url TEXT, viral_score INTEGER, rating TEXT, best_time_today TEXT, hashtags TEXT, created_at TEXT)''');
    batch.execute('''CREATE TABLE trend_items(id INTEGER PRIMARY KEY AUTOINCREMENT, query TEXT, result TEXT, provider TEXT, created_at TEXT)''');
    batch.execute('''CREATE TABLE downloaded_videos(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, video_url TEXT, saved_path TEXT, downloaded_at TEXT)''');
    batch.execute('''CREATE TABLE generated_content(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, prompt TEXT, result TEXT, model TEXT, created_at TEXT)''');
    batch.execute('''CREATE TABLE product_media(id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT, media_type TEXT, session_id INTEGER, created_at TEXT)''');
    batch.execute('''CREATE TABLE activity_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT NOT NULL, details TEXT, created_at TEXT NOT NULL)''');
    batch.execute('''CREATE TABLE referrals(id INTEGER PRIMARY KEY AUTOINCREMENT, referrer_id TEXT, timestamp TEXT)''');
    batch.execute('''CREATE TABLE conversations(id INTEGER PRIMARY KEY AUTOINCREMENT, firebase_uid TEXT, created_at TEXT)''');

    // 8. كتالوج المنتجات (Meta Commerce Manager)
    batch.execute('''CREATE TABLE catalog_products(
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      availability TEXT DEFAULT 'in stock',
      condition TEXT DEFAULT 'new',
      price REAL DEFAULT 0.0,
      currency TEXT DEFAULT 'YER',
      link TEXT,
      image_link TEXT,
      additional_image_links TEXT,
      video_url TEXT,
      brand TEXT,
      google_product_category TEXT,
      fb_product_category TEXT,
      quantity INTEGER DEFAULT 1,
      sale_price REAL,
      sale_price_effective_date TEXT,
      item_group_id TEXT,
      gender TEXT,
      color TEXT,
      size TEXT,
      age_group TEXT,
      material TEXT,
      pattern TEXT,
      shipping TEXT,
      shipping_weight TEXT,
      gtin TEXT,
      product_tags TEXT,
      style TEXT,
      created_at TEXT,
      updated_at TEXT,
      is_synced INTEGER DEFAULT 0
    )''');

    await batch.commit();
    await _insertDefaultControls(db);
    if (kDebugMode) print('✅ DBService: Tables Created Successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 🛡️ Migration logic from existing DBService if needed
    if (oldVersion < 26) {
       await _insertDefaultControls(db);
    }
    if (oldVersion < 27) {
       // إضافة عمود الحالة لتتبع الرسائل الجاري معالجتها
       await db.execute("ALTER TABLE chat_history ADD COLUMN state TEXT DEFAULT 'completed'");
    }
    if (oldVersion < 28) {
       // إضافة عمود لرابط الفيديو لتجنب تعارض الأسماء
       await db.execute("ALTER TABLE chat_history ADD COLUMN video_url TEXT");
    }
    if (oldVersion < 29) {
      // توسعة سجل عناصر التحكم الافتراضي للشاشات والأزرار
      await _insertDefaultControls(db);
    }
    if (oldVersion < 30) {
      // إضافة جدول كتالوج المنتجات للمزامنة مع Meta Commerce Manager
      await db.execute('''CREATE TABLE IF NOT EXISTS catalog_products(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        availability TEXT DEFAULT 'in stock',
        condition TEXT DEFAULT 'new',
        price REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'YER',
        link TEXT,
        image_link TEXT,
        additional_image_links TEXT,
        video_url TEXT,
        brand TEXT,
        google_product_category TEXT,
        fb_product_category TEXT,
        quantity INTEGER DEFAULT 1,
        sale_price REAL,
        sale_price_effective_date TEXT,
        item_group_id TEXT,
        gender TEXT,
        color TEXT,
        size TEXT,
        age_group TEXT,
        material TEXT,
        pattern TEXT,
        shipping TEXT,
        shipping_weight TEXT,
        gtin TEXT,
        product_tags TEXT,
        style TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0
      )''');
    }
    if (oldVersion < 31) {
      // إضافة صلاحية كتالوج المنتجات
      await _insertDefaultControls(db);
    }
  }

  // 🛡️ Failsafe Table Checker
  Future<void> _ensureColumnsExist(Database db) async {
    try {
      // 🛡️ Ensure missing tables are created
      final tableCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='conversations'");
      if (tableCheck.isEmpty) {
        await db.execute('''CREATE TABLE conversations(id INTEGER PRIMARY KEY AUTOINCREMENT, firebase_uid TEXT, created_at TEXT)''');
      }

      final columnsToAdd = {
        'chat_sessions': ['firebase_uid TEXT', 'is_synced INTEGER DEFAULT 0'],
        'chat_history': ['firebase_uid TEXT', 'message_type TEXT', 'media_path TEXT', 'embedding TEXT', 'product_context TEXT'],
        'products': ['embedding TEXT', 'video_url TEXT'],
        'users': ['firebase_uid TEXT', 'photo_url TEXT', 'cover_url TEXT'],
      };
      for (var table in columnsToAdd.keys) {
        final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
        final existing = tableInfo.map((row) => row['name'] as String).toSet();
        for (var colDef in columnsToAdd[table]!) {
          final colName = colDef.split(' ').first;
          if (!existing.contains(colName)) {
            await db.execute('ALTER TABLE $table ADD COLUMN $colDef');
          }
        }
      }
      _schemaChecked = true;
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 3. النظام العام للعمليات (The Magic Generic CRUD) 🪄
  // ---------------------------------------------------------------------------

  Future<int> insertRecord(String table, Map<String, dynamic> data) async {
    try {
      final d = await db;
      return await d.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      if (kDebugMode) print('❌ DB Insert Error [$table]: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getRecords(String table, {String? where, List<dynamic>? whereArgs, String? orderBy, int? limit}) async {
    try {
      final d = await db;
      return await d.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
    } catch (e) {
      if (kDebugMode) print('❌ DB Query Error [$table]: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRecord(String table, {required String where, required List<dynamic> whereArgs}) async {
    final results = await getRecords(table, where: where, whereArgs: whereArgs, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateRecord(String table, Map<String, dynamic> data, {required String where, required List<dynamic> whereArgs}) async {
    try {
      final d = await db;
      return await d.update(table, data, where: where, whereArgs: whereArgs);
    } catch (e) {
      if (kDebugMode) print('❌ DB Update Error [$table]: $e');
      return 0;
    }
  }

  Future<int> deleteRecord(String table, {required String where, required List<dynamic> whereArgs}) async {
    try {
      final d = await db;
      return await d.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      if (kDebugMode) print('❌ DB Delete Error [$table]: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. الدوال المعقدة (Legacy Complex Logic - Preserved) 🧠
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSessions({int limit = 50, String? userId, String? firebaseUid}) async {
    final d = await db;
    
    List<String> conditions = [];
    List<dynamic> args = [];
    
    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }
    if (firebaseUid != null) {
      conditions.add('firebase_uid = ?');
      args.add(firebaseUid);
    }
    
    // نقوم بجلب المحادثات الخاصة بالمستخدم + المحادثات المحلية (Anonymous) التي لم تُربط بحساب بعد
    // نقوم بجلب المحادثات الخاصة بالمستخدم + المحادثات المحلية (التي تحمل الرقم 1 أو فارغة)
    String where = conditions.isNotEmpty 
        ? '(${conditions.join(' OR ')} OR (user_id IS NULL OR user_id = "1" OR firebase_uid IS NULL))' 
        : '(user_id IS NULL OR user_id = "1" OR firebase_uid IS NULL)';
    
    final sql = '''
      SELECT s.*, 
      (SELECT h.media_path FROM chat_history h WHERE h.session_id = s.id AND h.message_type = 'image' ORDER BY h.created_at DESC LIMIT 1) as image_path
      FROM chat_sessions s WHERE $where ORDER BY last_message_at DESC LIMIT $limit
    ''';
    
    return await d.rawQuery(sql, args);
  }

  Future<int> logChatMessage(String provider, String userMessage, String aiResponse, {int? sessionId, String messageType = 'text', String? mediaPath, String? videoUrl, String? state, String? userId, String? firebaseUid, String? embedding, String? metaData, String? productContext}) async {
    final now = DateTime.now().toIso8601String();
    if (sessionId != null) {
      await updateRecord('chat_sessions', {
        'last_message_at': now,
        'last_message_text': aiResponse.length > 50 ? '${aiResponse.substring(0, 50)}...' : aiResponse,
      }, where: 'id = ?', whereArgs: [sessionId]);
    }
    return await insertRecord('chat_history', {
      'session_id': sessionId,
      'provider': provider,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'message_type': messageType,
      'media_path': mediaPath,
      'video_url': videoUrl,
      'state': state ?? 'completed',
      'product_context': productContext,
      'meta_data': metaData,
      'created_at': now,
      'user_id': userId,
      'firebase_uid': firebaseUid,
      'embedding': embedding,
    });
  }

  Future<List<Map<String, dynamic>>> getUnifiedHistory() async {
    final chats = await getRecords('chat_history', orderBy: 'created_at DESC', limit: 20);
    final viral = await getRecords('viral_booster_reports', orderBy: 'created_at DESC', limit: 20);
    final downloads = await getRecords('downloaded_videos', orderBy: 'downloaded_at DESC', limit: 20);
    
    final List<Map<String, dynamic>> combined = [];
    combined.addAll(chats.map((e) => {...e, 'history_type': 'chat'}));
    combined.addAll(viral.map((e) => {...e, 'history_type': 'viralReport'}));
    combined.addAll(downloads.map((e) => {...e, 'history_type': 'download'}));

    combined.sort((a, b) => (b['created_at'] ?? b['downloaded_at'] ?? '').compareTo(a['created_at'] ?? a['downloaded_at'] ?? ''));
    return combined;
  }

  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> clearTable(String table) async {
    final d = await db;
    await d.delete(table);
  }

  Future<void> nukeDatabase() async {
    String path = join(await getDatabasesPath(), 'smart_content_creator.db');
    await deleteDatabase(path);
    _database = null;
  }

  // ---------------------------------------------------------------------------
  // 🔨 أدوات المساعدة (Helpers)
  // ---------------------------------------------------------------------------

  Future<void> _insertDefaultControls(Database db) async {
    final controls = [
      {'control_name': 'admin_dashboard_screen', 'description': 'لوحة تحكم المدير', 'category': 'Admin'},
      {'control_name': 'ai_chat_screen', 'description': 'شاشة المساعد الذكي', 'category': 'Home'},
      {'control_name': 'video_gen', 'description': 'توليد فيديو بالذكاء الاصطناعي', 'category': 'Studio'},
      {'control_name': 'settings_screen', 'description': 'شاشة الإعدادات', 'category': 'screen'},
      {'control_name': 'api_settings_screen', 'description': 'إعدادات مفاتيح API', 'category': 'screen'},
      {'control_name': 'creator_profile_screen', 'description': 'شاشة الملف الإبداعي', 'category': 'screen'},
      {'control_name': 'ai_studio_screen', 'description': 'استوديو الذكاء الاصطناعي', 'category': 'screen'},
      {'control_name': 'upload_screen', 'description': 'شاشة رفع المحتوى', 'category': 'screen'},
      {'control_name': 'trend_screen', 'description': 'شاشة الترندات', 'category': 'screen'},
      {'control_name': 'home_screen', 'description': 'الشاشة الرئيسية', 'category': 'screen'},
      {'control_name': 'catalog_screen', 'description': 'شاشة كتالوج المنتجات لـ Meta', 'category': 'screen'},
      {'control_name': 'chat_image_attach', 'description': 'زر إرفاق صورة بالدردشة', 'category': 'button'},
      {'control_name': 'chat_camera_attach', 'description': 'زر الكاميرا بالدردشة', 'category': 'button'},
      {'control_name': 'chat_file_attach', 'description': 'زر إرفاق ملف بالدردشة', 'category': 'button'},
      {'control_name': 'chat_audio_enhance', 'description': 'زر تحسين الصوت بالدردشة', 'category': 'button'},
      {'control_name': 'use_managed_keys', 'description': 'السماح باستخدام مفاتيح الأدمن', 'category': 'System'},
      {'control_name': 'managed_key_gemini', 'description': 'وصول مفتاح Gemini المُدار', 'category': 'System'},
      {'control_name': 'managed_key_serpapi', 'description': 'وصول مفتاح SerpApi المُدار', 'category': 'System'},
      {'control_name': 'managed_key_stability', 'description': 'وصول مفتاح Stability المُدار', 'category': 'System'},
      {'control_name': 'managed_key_kling', 'description': 'وصول مفتاح Kling المُدار', 'category': 'System'},
      {'control_name': 'managed_key_github', 'description': 'وصول مفتاح GitHub المُدار', 'category': 'System'},
    ];
    for (var control in controls) {
      await db.insert('ui_controls', {...control, 'created_at': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<Map<String, int>> getStatistics() async {
    final stats = <String, int>{};
    final tables = ['users', 'chat_sessions', 'chat_history', 'products', 'videos'];
    for (final table in tables) {
      try {
        final d = await db;
        final result = await d.rawQuery('SELECT COUNT(*) as count FROM $table');
        stats[table] = Sqflite.firstIntValue(result) ?? 0;
      } catch (_) { stats[table] = 0; }
    }
    return stats;
  }

  // ========================================
  // 🧠 CONTEXT MEMORY SYSTEM
  // ========================================

  Future<List<Map<String, dynamic>>> getLastMessages({
    required int sessionId,
    int limit = 3,
  }) async {
    try {
      final d = await db;
      final result = await d.query(
        'chat_history',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return result.reversed.toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ DB getLastMessages Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLastDetectedProduct({String? userId}) async {
    try {
      final results = await getRecords(
        'product_memory',
        where: userId != null ? 'user_id = ?' : null,
        whereArgs: userId != null ? [userId] : null,
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      return results.isEmpty ? null : results.first;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ DB getLastDetectedProduct Error: $e');
      return null;
    }
  }
}
