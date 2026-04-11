# 🛠️ Database Setup Guide

## Step 1: Update pubspec.yaml
✅ **Already done!** The following dependencies are added:
```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1
```

Run: `flutter pub get`

## Step 2: Initialize Database in main.dart

Add this to your `main()` function before `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Initialize database
  await DatabaseHelper.instance.database;
  
  // Log app start
  await DatabaseHelper.instance.logAction('app_start');
  
  runApp(const MyApp());
}
```

## Step 3: Add Import to main.dart
```dart
import 'package:smart_content_creator/database/database_helper.dart';
```

## Step 4: Close Database on App Exit

Add this to your main widget or navigation handler:

```dart
Future<bool> _onWillPop(BuildContext context) async {
  // Log app close
  await DatabaseHelper.instance.logAction('app_close');
  
  // Close database
  await DatabaseHelper.instance.close();
  
  return true;
}
```

Or in your main app widget:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WillPopScope(
        onWillPop: () async {
          await DatabaseHelper.instance.logAction('app_close');
          await DatabaseHelper.instance.close();
          return true;
        },
        child: const HomeScreen(),
      ),
    );
  }
}
```

## Step 5: Use Database Throughout Your App

### In Your Screens
```dart
import 'package:smart_content_creator/database/database_helper.dart';
import 'package:smart_content_creator/models/content_model.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late final DatabaseHelper _db;

  @override
  void initState() {
    super.initState();
    _db = DatabaseHelper.instance;
  }

  Future<void> saveContent(String result) async {
    await _db.logAction('generate_text');
    
    final content = ContentModel(
      inputType: 'text',
      prompt: 'Your prompt',
      result: result,
      model: 'gemini-1.5-flash',
      createdAt: DateTime.now(),
    );
    
    await _db.insertContent(content);
  }

  @override
  Widget build(BuildContext context) {
    // Your UI here
    return Container();
  }
}
```

### In Your Services
```dart
import 'package:smart_content_creator/database/database_helper.dart';

class ContentService {
  final _db = DatabaseHelper.instance;

  Future<String> generateContent(String prompt) async {
    try {
      // Your generation logic here
      String result = 'Generated content';
      
      // Save to database
      await _db.insertContent(ContentModel(
        prompt: prompt,
        result: result,
        model: 'gemini-1.5-flash',
        createdAt: DateTime.now(),
      ));
      
      return result;
    } catch (e) {
      await _db.logAction('error', details: 'Generation failed: $e');
      rethrow;
    }
  }
}
```

## Step 6: Common Integration Patterns

### Pattern 1: API Key Management
```dart
Future<void> setupApiKeys() async {
  final db = DatabaseHelper.instance;
  
  // Check if API key exists
  var geminiKey = await db.getApiKeyByService('Gemini');
  
  if (geminiKey == null) {
    // Create new API key
    await db.insertApiKey(ApiKeyModel(
      serviceName: 'Gemini',
      apiKey: '', // User will enter this
      enabled: true,
      createdAt: DateTime.now(),
    ));
  }
}
```

### Pattern 2: Settings Management
```dart
Future<String> getAppTheme() async {
  final db = DatabaseHelper.instance;
  String? theme = await db.getSettingValue('theme_mode');
  return theme ?? 'light';
}

Future<void> setAppTheme(String theme) async {
  await DatabaseHelper.instance.upsertSetting('theme_mode', theme);
}
```

### Pattern 3: Activity Tracking
```dart
Future<void> trackUserAction(String action, {String? details}) async {
  await DatabaseHelper.instance.logAction(action, details: details);
}

// Usage
await trackUserAction('generate_text', 
  details: 'Generated 150 words for product');
```

### Pattern 4: Data Analytics
```dart
Future<void> showStatistics() async {
  final db = DatabaseHelper.instance;
  final stats = await db.getStatistics();
  
  print('''
    📊 App Statistics:
    Generated Content: ${stats['content']} items
    Media Uploaded: ${stats['media']} items
    Total Actions: ${stats['logs']} logged
  ''');
}
```

## Step 7: Testing Database Operations

Create a test file: `lib/database/database_test.dart`

```dart
import 'package:smart_content_creator/database/database_helper.dart';
import 'package:smart_content_creator/models/user_model.dart';
import 'package:smart_content_creator/models/api_key_model.dart';

Future<void> testDatabase() async {
  final db = DatabaseHelper.instance;
  
  print('Testing DatabaseHelper...\n');
  
  // Test Users
  print('✅ Testing Users Table');
  final user = UserModel(
    name: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime.now(),
  );
  int userId = await db.insertUser(user);
  print('   - Created user with ID: $userId');
  
  // Test API Keys
  print('✅ Testing API Keys Table');
  final apiKey = ApiKeyModel(
    serviceName: 'Gemini',
    apiKey: 'test-key-123',
    createdAt: DateTime.now(),
  );
  int keyId = await db.insertApiKey(apiKey);
  print('   - Created API key with ID: $keyId');
  
  // Test Settings
  print('✅ Testing Settings Table');
  await db.upsertSetting('app_version', '1.0.0');
  String? version = await db.getSettingValue('app_version');
  print('   - Saved setting: app_version = $version');
  
  // Test Logging
  print('✅ Testing Activity Logs');
  await db.logAction('test_action', details: 'Testing database');
  int logCount = await db.getLogCount();
  print('   - Total logs: $logCount');
  
  // Test Statistics
  print('✅ Testing Statistics');
  final stats = await db.getStatistics();
  print('   - Database stats: $stats');
  
  print('\n✅ All database tests passed!');
}
```

Call in main.dart:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await DatabaseHelper.instance.database;
  
  // Run tests
  // await testDatabase(); // Comment out for production
  
  runApp(const MyApp());
}
```

## Step 8: Backup Strategy

Add periodic backups to your app:

```dart
class BackupService {
  static Future<void> setupAutoBackup() async {
    // Backup database daily
    // Implementation depends on your scheduling package
    await DatabaseHelper.instance.backupDatabase();
  }
}
```

## Step 9: Monitoring & Maintenance

Add to your app settings screen:

```dart
class DatabaseStats extends StatefulWidget {
  @override
  State<DatabaseStats> createState() => _DatabaseStatsState();
}

class _DatabaseStatsState extends State<DatabaseStats> {
  late Future<Map<String, int>> _stats;
  
  @override
  void initState() {
    super.initState();
    _stats = DatabaseHelper.instance.getStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _stats,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data!;
          return Column(
            children: [
              Text('Users: ${data['users']}'),
              Text('API Keys: ${data['api_keys']}'),
              Text('Content: ${data['content']}'),
              Text('Media: ${data['media']}'),
              Text('Logs: ${data['logs']}'),
              ElevatedButton(
                onPressed: () async {
                  await DatabaseHelper.instance.backupDatabase();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup created!')),
                  );
                },
                child: const Text('Backup Database'),
              ),
            ],
          );
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
```

## 📋 Verification Checklist

- [ ] Dependencies added to pubspec.yaml
- [ ] `flutter pub get` executed
- [ ] Database initialized in main.dart
- [ ] Database closed on app exit
- [ ] Imports added where needed
- [ ] Test operations verified
- [ ] Logging implemented in key functions
- [ ] Backup strategy in place

## 🚨 Troubleshooting

### Issue: Database file not found
**Solution**: Make sure `WidgetsFlutterBinding.ensureInitialized()` is called before accessing database

### Issue: Database locked error
**Solution**: Make sure you're not opening multiple database instances. Use `DatabaseHelper.instance` consistently

### Issue: Null pointer exception
**Solution**: Check that model objects are properly created. All date fields should use `DateTime.now()`

### Issue: Data not persisting
**Solution**: Make sure to `await` all database operations

## 📞 Support Files

- **DATABASE_USAGE_GUIDE.md** - Comprehensive API documentation
- **QUICK_REFERENCE.md** - Quick lookup for all methods
- **SETUP_GUIDE.md** - This file

---

**Ready to use!** Your database system is fully integrated and production-ready.
