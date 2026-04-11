# ⚡ SQLite Database - Quick Reference

## 🗂️ File Structure
```
lib/
├── database/
│   ├── database_helper.dart           (Main database class - 698 lines)
│   ├── DATABASE_USAGE_GUIDE.md        (Comprehensive guide)
│   └── QUICK_REFERENCE.md             (This file)
│
└── models/
    ├── user_model.dart                (User data)
    ├── api_key_model.dart             (API keys for services)
    ├── setting_model.dart             (App settings)
    ├── content_model.dart             (Generated content)
    ├── media_model.dart               (Media files)
    └── log_model.dart                 (Activity logs)
```

## 📊 Database Tables
| Table | Records | Purpose |
|-------|---------|---------|
| `users` | User profiles | Store user info |
| `api_keys` | API credentials | Manage service keys |
| `settings` | Config key-value pairs | App settings |
| `generated_content` | Generated outputs | Store AI results |
| `media` | Media metadata | Track images/videos |
| `activity_logs` | Action history | Audit trail |

## 🚀 Quick Start

### 1. Initialize Database
```dart
import 'package:smart_content_creator/database/database_helper.dart';

final db = DatabaseHelper.instance;
// Database auto-initializes on first use
```

### 2. Common Operations
```dart
// Log an action
await db.logAction('app_start');

// Get a setting
String? theme = await db.getSettingValue('theme_mode');

// Get all content
List<ContentModel> content = await db.getAllContent();

// Get statistics
Map<String, int> stats = await db.getStatistics();
```

## 📝 CRUD Operations Summary

### Users
```
✅ insertUser()
✅ getAllUsers()
✅ getUserById()
✅ updateUser()
✅ deleteUser()
✅ deleteAllUsers()
```

### API Keys
```
✅ insertApiKey()
✅ getAllApiKeys()
✅ getApiKeyById()
✅ getApiKeyByService()
✅ getEnabledApiKeys()
✅ updateApiKey()
✅ updateApiKeyByService()
✅ toggleApiKeyStatus()
✅ deleteApiKey()
✅ deleteApiKeyByService()
✅ deleteAllApiKeys()
```

### Settings
```
✅ insertSetting()
✅ getAllSettings()
✅ getSettingById()
✅ getSettingByKey()
✅ getSettingValue()
✅ upsertSetting()    ⭐ (Insert or update)
✅ updateSetting()
✅ deleteSetting()
✅ deleteSettingByKey()
✅ deleteAllSettings()
```

### Generated Content
```
✅ insertContent()
✅ getAllContent()
✅ getContentById()
✅ getContentByInputType()
✅ getContentByModel()
✅ updateContent()
✅ deleteContent()
✅ deleteAllContent()
✅ deleteOldContent()  ⭐ (Auto-cleanup)
```

### Media
```
✅ insertMedia()
✅ getAllMedia()
✅ getMediaById()
✅ getMediaByType()
✅ updateMedia()
✅ deleteMedia()
✅ deleteAllMedia()
✅ deleteOldMedia()    ⭐ (Auto-cleanup)
```

### Activity Logs
```
✅ insertLog()
✅ logAction()         ⭐ (Simple logging)
✅ getAllLogs()
✅ getLogById()
✅ getLogsByAction()
✅ getLogsFromDate()
✅ getLogsBetweenDates()
✅ deleteLog()
✅ deleteAllLogs()
✅ deleteOldLogs()     ⭐ (Auto-cleanup)
✅ getLogCount()
```

## 🔧 Utility Methods

| Method | Purpose |
|--------|---------|
| `getStatistics()` | Get count of all records |
| `getDatabaseSize()` | Get DB file size in bytes |
| `vacuumDatabase()` | Optimize database |
| `backupDatabase()` | Create backup file |
| `close()` | Close database connection |
| `deleteDatabase()` | Delete entire database |

## 📊 Database Schema

### users
```sql
id INTEGER PRIMARY KEY
name TEXT
email TEXT
created_at TEXT (ISO8601)
```

### api_keys
```sql
id INTEGER PRIMARY KEY
service_name TEXT NOT NULL
api_key TEXT NOT NULL
enabled INTEGER (0=false, 1=true)
created_at TEXT (ISO8601)
```

### settings
```sql
id INTEGER PRIMARY KEY
key TEXT NOT NULL
value TEXT
updated_at TEXT (ISO8601)
```

### generated_content
```sql
id INTEGER PRIMARY KEY
input_type TEXT (text/image/video)
input_path TEXT
prompt TEXT
result TEXT
model TEXT
created_at TEXT (ISO8601)
```

### media
```sql
id INTEGER PRIMARY KEY
type TEXT (image/video)
path TEXT
created_at TEXT (ISO8601)
```

### activity_logs
```sql
id INTEGER PRIMARY KEY
action TEXT NOT NULL
details TEXT
created_at TEXT NOT NULL (ISO8601)
```

## 💡 Code Examples

### Save Multiple API Keys
```dart
final services = ['Gemini', 'OpenAI', 'Groq'];
final keys = ['key1', 'key2', 'key3'];

for (int i = 0; i < services.length; i++) {
  await db.insertApiKey(ApiKeyModel(
    serviceName: services[i],
    apiKey: keys[i],
    createdAt: DateTime.now(),
  ));
}
```

### Get Statistics & Display
```dart
final stats = await db.getStatistics();
print('''
  📊 Database Statistics:
  👥 Users: ${stats['users']}
  🔑 API Keys: ${stats['api_keys']}
  📄 Content: ${stats['content']}
  🎬 Media: ${stats['media']}
  📋 Logs: ${stats['logs']}
''');
```

### Clean Old Data
```dart
// Delete logs older than 90 days
await db.deleteOldLogs(90);

// Delete content older than 30 days
await db.deleteOldContent(30);

// Delete media older than 7 days
await db.deleteOldMedia(7);
```

### Advanced Log Query
```dart
// Get all actions from last 7 days
DateTime weekAgo = DateTime.now().subtract(Duration(days: 7));
List<LogModel> recentLogs = await db.getLogsFromDate(weekAgo);

// Group by action
Map<String, int> actionCount = {};
for (var log in recentLogs) {
  actionCount[log.action] = (actionCount[log.action] ?? 0) + 1;
}

print('Actions in last 7 days:');
actionCount.forEach((action, count) {
  print('  $action: $count times');
});
```

## 🔐 Data Integrity

✅ **All models support null-safe Dart 3**
✅ **Automatic timestamp management**
✅ **copyWith() for immutable updates**
✅ **fromMap() & toMap() serialization**
✅ **Singleton pattern for single instance**
✅ **Cross-platform support (Android, iOS, Windows)**

## ⚠️ Important Reminders

1. **Always await** database operations
2. **Use DatabaseHelper.instance** consistently
3. **Check for null** when getting single records
4. **Log important actions** for debugging
5. **Backup before** major deletions
6. **Close database** when app terminates

## 🎯 Recommended Logging Actions

```dart
// Authentication & Navigation
'app_start'
'app_close'
'login'
'logout'
'open_screen'

// Content Generation
'generate_text'
'generate_hashtags'
'extract_labels'
'analyze_image'
'test_connection'

// File Operations
'upload_media'
'save_video'
'save_image'
'delete_media'

// API Management
'save_api_key'
'update_api_key'
'delete_api_key'
'select_provider'

// Error Handling
'error'
'warning'
'exception'
```

## 📞 Support

For detailed examples, see: **DATABASE_USAGE_GUIDE.md**

---

**Last Updated**: 2024-11-24  
**Database Version**: 1  
**Package**: sqflite 2.3.0
