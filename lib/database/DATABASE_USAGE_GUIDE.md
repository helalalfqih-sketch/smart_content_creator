# 📚 SQLite Database Usage Guide

## Overview
The `DatabaseHelper` class is a singleton instance that manages all database operations for the smart_content_creator app.

## Initialization

```dart
import 'package:smart_content_creator/database/database_helper.dart';

// Get database instance (automatically initializes on first use)
final db = DatabaseHelper.instance;
```

---

## 📍 USERS TABLE

### Insert User
```dart
import 'package:smart_content_creator/models/user_model.dart';

final user = UserModel(
  name: 'Ahmed',
  email: 'ahmed@example.com',
  createdAt: DateTime.now(),
);
int userId = await DatabaseHelper.instance.insertUser(user);
```

### Get All Users
```dart
List<UserModel> users = await DatabaseHelper.instance.getAllUsers();
for (var user in users) {
  print('${user.name} - ${user.email}');
}
```

### Get User by ID
```dart
UserModel? user = await DatabaseHelper.instance.getUserById(1);
if (user != null) {
  print('Found: ${user.name}');
}
```

### Update User
```dart
final updatedUser = user.copyWith(name: 'Ahmed Updated');
await DatabaseHelper.instance.updateUser(updatedUser);
```

### Delete User
```dart
await DatabaseHelper.instance.deleteUser(1);
```

### Delete All Users
```dart
await DatabaseHelper.instance.deleteAllUsers();
```

---

## 🔑 API KEYS TABLE

### Insert API Key
```dart
import 'package:smart_content_creator/models/api_key_model.dart';

final apiKey = ApiKeyModel(
  serviceName: 'Gemini',
  apiKey: 'your-api-key-here',
  enabled: true,
  createdAt: DateTime.now(),
);
int keyId = await DatabaseHelper.instance.insertApiKey(apiKey);
```

### Get All API Keys
```dart
List<ApiKeyModel> keys = await DatabaseHelper.instance.getAllApiKeys();
```

### Get API Key by Service Name
```dart
ApiKeyModel? key = await DatabaseHelper.instance.getApiKeyByService('Gemini');
if (key != null) {
  print('API Key: ${key.apiKey}');
}
```

### Get Only Enabled API Keys
```dart
List<ApiKeyModel> enabledKeys = await DatabaseHelper.instance.getEnabledApiKeys();
```

### Toggle API Key Status
```dart
await DatabaseHelper.instance.toggleApiKeyStatus(keyId);
```

### Update API Key by Service
```dart
await DatabaseHelper.instance.updateApiKeyByService('OpenAI', 'new-api-key');
```

### Delete API Key
```dart
await DatabaseHelper.instance.deleteApiKey(keyId);
// Or by service name:
await DatabaseHelper.instance.deleteApiKeyByService('Gemini');
```

---

## ⚙️ SETTINGS TABLE

### Insert Setting
```dart
import 'package:smart_content_creator/models/setting_model.dart';

final setting = SettingModel(
  key: 'theme_mode',
  value: 'dark',
  updatedAt: DateTime.now(),
);
await DatabaseHelper.instance.insertSetting(setting);
```

### Get Setting by Key
```dart
SettingModel? setting = await DatabaseHelper.instance.getSettingByKey('theme_mode');
String? themeMode = setting?.value;
```

### Get Setting Value Directly
```dart
String? themeMode = await DatabaseHelper.instance.getSettingValue('theme_mode');
```

### Upsert Setting (Insert or Update)
```dart
// This will update if exists, insert if not
await DatabaseHelper.instance.upsertSetting('language', 'ar');
```

### Get All Settings
```dart
List<SettingModel> allSettings = await DatabaseHelper.instance.getAllSettings();
```

### Delete Setting
```dart
await DatabaseHelper.instance.deleteSettingByKey('theme_mode');
```

---

## 📄 GENERATED CONTENT TABLE

### Insert Generated Content
```dart
import 'package:smart_content_creator/models/content_model.dart';

final content = ContentModel(
  inputType: 'image',
  inputPath: '/path/to/image.jpg',
  prompt: 'Analyze this product image',
  result: 'The image contains...',
  model: 'gemini-1.5-flash',
  createdAt: DateTime.now(),
);
int contentId = await DatabaseHelper.instance.insertContent(content);
```

### Get All Content (Latest First)
```dart
List<ContentModel> allContent = await DatabaseHelper.instance.getAllContent();
```

### Get Content by ID
```dart
ContentModel? content = await DatabaseHelper.instance.getContentById(1);
```

### Get Content by Input Type
```dart
List<ContentModel> imageContent = 
  await DatabaseHelper.instance.getContentByInputType('image');
```

### Get Content by Model
```dart
List<ContentModel> geminiContent = 
  await DatabaseHelper.instance.getContentByModel('gemini-1.5-flash');
```

### Update Content
```dart
final updated = content.copyWith(result: 'Updated result');
await DatabaseHelper.instance.updateContent(updated);
```

### Delete Content
```dart
await DatabaseHelper.instance.deleteContent(contentId);
```

### Delete Old Content (Older than X days)
```dart
await DatabaseHelper.instance.deleteOldContent(30); // Delete content older than 30 days
```

---

## 🎬 MEDIA TABLE

### Insert Media
```dart
import 'package:smart_content_creator/models/media_model.dart';

final media = MediaModel(
  type: 'image',
  path: '/path/to/media.jpg',
  createdAt: DateTime.now(),
);
int mediaId = await DatabaseHelper.instance.insertMedia(media);
```

### Get All Media (Latest First)
```dart
List<MediaModel> allMedia = await DatabaseHelper.instance.getAllMedia();
```

### Get Media by Type
```dart
List<MediaModel> images = await DatabaseHelper.instance.getMediaByType('image');
List<MediaModel> videos = await DatabaseHelper.instance.getMediaByType('video');
```

### Delete Old Media
```dart
await DatabaseHelper.instance.deleteOldMedia(7); // Delete media older than 7 days
```

---

## 📊 ACTIVITY LOGS TABLE

### Log an Action
```dart
// Simple action log
await DatabaseHelper.instance.logAction('generate_text');

// Action with details
await DatabaseHelper.instance.logAction(
  'generate_text',
  details: 'Generated 150 words for product description',
);
```

### Insert Log Directly
```dart
import 'package:smart_content_creator/models/log_model.dart';

final log = LogModel(
  action: 'save_video',
  details: 'Saved video to /storage/videos/output.mp4',
  createdAt: DateTime.now(),
);
await DatabaseHelper.instance.insertLog(log);
```

### Get All Logs (Latest First)
```dart
List<LogModel> allLogs = await DatabaseHelper.instance.getAllLogs();
```

### Get Logs by Action
```dart
List<LogModel> generateLogs = 
  await DatabaseHelper.instance.getLogsByAction('generate_text');
```

### Get Logs from Specific Date
```dart
DateTime date = DateTime(2024, 11, 24);
List<LogModel> logsFromDate = 
  await DatabaseHelper.instance.getLogsFromDate(date);
```

### Get Logs Between Dates
```dart
DateTime startDate = DateTime(2024, 11, 1);
DateTime endDate = DateTime(2024, 11, 30);
List<LogModel> monthlyLogs = 
  await DatabaseHelper.instance.getLogsBetweenDates(startDate, endDate);
```

### Get Log Count
```dart
int totalLogs = await DatabaseHelper.instance.getLogCount();
print('Total logs: $totalLogs');
```

### Delete Old Logs
```dart
await DatabaseHelper.instance.deleteOldLogs(60); // Delete logs older than 60 days
```

---

## 🔧 UTILITY METHODS

### Get Database Statistics
```dart
Map<String, int> stats = await DatabaseHelper.instance.getStatistics();
print('Users: ${stats['users']}');
print('API Keys: ${stats['api_keys']}');
print('Generated Content: ${stats['content']}');
print('Media: ${stats['media']}');
print('Activity Logs: ${stats['logs']}');
```

### Backup Database
```dart
await DatabaseHelper.instance.backupDatabase();
// Creates backup in app documents: /backups/smart_content_creator_backup_[timestamp].db
```

### Get Database Size
```dart
int sizeInBytes = await DatabaseHelper.instance.getDatabaseSize();
int sizeInMB = sizeInBytes ~/ (1024 * 1024);
print('Database size: ${sizeInMB} MB');
```

### Vacuum Database (Optimize Space)
```dart
await DatabaseHelper.instance.vacuumDatabase();
```

### Delete All Data
```dart
// Delete specific tables
await DatabaseHelper.instance.deleteAllUsers();
await DatabaseHelper.instance.deleteAllApiKeys();
await DatabaseHelper.instance.deleteAllSettings();
await DatabaseHelper.instance.deleteAllContent();
await DatabaseHelper.instance.deleteAllMedia();
await DatabaseHelper.instance.deleteAllLogs();
```

### Close Database Connection
```dart
await DatabaseHelper.instance.close();
```

### Delete Entire Database
```dart
await DatabaseHelper.instance.deleteDatabase();
```

---

## 💡 Common Patterns

### Complete Content Generation Workflow
```dart
// 1. Log action start
await DatabaseHelper.instance.logAction('generate_text', details: 'Started generation');

try {
  // 2. Get API key
  ApiKeyModel? apiKey = await DatabaseHelper.instance.getApiKeyByService('Gemini');
  if (apiKey == null) throw Exception('No API key found');

  // 3. Generate content (using your API service)
  // String result = await apiService.generate(prompt);

  // 4. Save generated content
  final content = ContentModel(
    inputType: 'text',
    prompt: 'Your prompt',
    result: 'Generated result',
    model: 'gemini-1.5-flash',
    createdAt: DateTime.now(),
  );
  await DatabaseHelper.instance.insertContent(content);

  // 5. Log success
  await DatabaseHelper.instance.logAction('generate_text', 
    details: 'Generation completed successfully');

} catch (e) {
  // 6. Log error
  await DatabaseHelper.instance.logAction('error', details: 'Generation failed: $e');
}
```

### Settings Management
```dart
// Save user preferences
await DatabaseHelper.instance.upsertSetting('theme', 'dark');
await DatabaseHelper.instance.upsertSetting('language', 'ar');
await DatabaseHelper.instance.upsertSetting('auto_backup', 'true');

// Retrieve settings
String? theme = await DatabaseHelper.instance.getSettingValue('theme');
String? language = await DatabaseHelper.instance.getSettingValue('language');
```

### Performance Monitoring
```dart
// Get statistics for dashboard
final stats = await DatabaseHelper.instance.getStatistics();
final dbSize = await DatabaseHelper.instance.getDatabaseSize();
final recentLogs = await DatabaseHelper.instance.getLogsFromDate(
  DateTime.now().subtract(Duration(days: 7))
);

print('Recent activity (7 days): ${recentLogs.length} actions');
print('Database size: ${dbSize ~/ (1024 * 1024)} MB');
```

---

## ⚠️ Important Notes

1. **Singleton Pattern**: DatabaseHelper is a singleton, so use `DatabaseHelper.instance` throughout your app
2. **Async Operations**: All database operations are asynchronous - use `await`
3. **Null Safety**: All models support null-safe Dart 3
4. **Timestamps**: All timestamps are stored as ISO8601 strings
5. **Boolean Storage**: Booleans are stored as 0 (false) and 1 (true) in SQLite
6. **Cross-Platform**: Works on Android, iOS, Windows, and has fallback support

---

## 🚀 Best Practices

1. **Always log important actions** for debugging and analytics
2. **Regularly backup your database** before major operations
3. **Cleanup old logs** periodically to save space
4. **Use upsertSetting()** for settings to avoid duplicate key errors
5. **Check for null** when retrieving single records
6. **Use batch operations** when possible for better performance
7. **Close database** when the app closes (in main.dart)

---

## 📋 Available Actions for Logging

```
- generate_text
- generate_hashtags
- extract_labels
- save_video
- upload_media
- select_provider
- test_connection
- save_api_key
- open_screen
- error
- app_start
- app_close
```

Feel free to add your own custom actions!
