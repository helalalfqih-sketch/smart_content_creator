# نظام إدارة الصلاحيات الديناميكي

## 📋 نظرة عامة

تم تطبيق نظام شامل لإدارة صلاحيات المستخدمين بشكل ديناميكي، يسمح للمدراء بالتحكم الكامل في:
- **الأدوار**: User, Creator, Admin
- **عناصر الواجهة**: إخفاء أو تعطيل أي زر أو شاشة
- **الصلاحيات**: تخصيص الصلاحيات لكل مستخدم على حدة

---

## 🗄️ قاعدة البيانات

### جدول `ui_controls`
يحتوي على جميع عناصر الواجهة القابلة للتحكم:

```sql
CREATE TABLE ui_controls(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  control_name TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  category TEXT DEFAULT 'button',
  created_at TEXT
)
```

### جدول `user_permissions`
يحتوي على صلاحيات كل مستخدم:

```sql
CREATE TABLE user_permissions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  control_id INTEGER NOT NULL,
  visible INTEGER DEFAULT 1,
  enabled INTEGER DEFAULT 1,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(control_id) REFERENCES ui_controls(id) ON DELETE CASCADE,
  UNIQUE(user_id, control_id)
)
```

### العناصر الافتراضية
تم إضافة العناصر التالية افتراضياً:
- `auto_director_button` - زر Auto Director
- `viral_booster_button` - زر Viral Booster
- `ai_chat_screen` - شاشة الدردشة مع AI
- `video_editor_screen` - شاشة محرر الفيديو
- `tiktok_downloader_button` - زر تحميل من TikTok
- `admin_dashboard_screen` - لوحة تحكم المدير
- `settings_screen` - شاشة الإعدادات

---

## 🎮 الاستخدام

### 1️⃣ الوصول إلى لوحة التحكم

```dart
// في main.dart أو routes
Get.to(() => const AdminDashboardScreen());
```

**ملاحظة**: فقط المستخدمون ذوو دور `admin` يمكنهم الوصول.

### 2️⃣ تطبيق الصلاحيات على عنصر واجهة

#### الطريقة الأولى: استخدام Widget Wrapper

```dart
import 'package:smart_content_creator/widgets/permission_controlled_widget.dart';

// إخفاء/إظهار + تفعيل/تعطيل
PermissionControlledWidget(
  controlName: 'auto_director_button',
  child: ElevatedButton(
    onPressed: () => autoDirector(),
    child: Text('Auto Director'),
  ),
)

// إخفاء/إظهار فقط
VisibilityControlled(
  controlName: 'viral_booster_button',
  child: ElevatedButton(
    onPressed: () => viralBooster(),
    child: Text('Viral Booster'),
  ),
)
```

#### الطريقة الثانية: استخدام Extension Methods

```dart
// أسهل وأنظف!
ElevatedButton(
  onPressed: () => autoDirector(),
  child: Text('Auto Director'),
).withPermission('auto_director_button')

// أو للإخفاء فقط
ElevatedButton(
  onPressed: () => viralBooster(),
  child: Text('Viral Booster'),
).withVisibilityControl('viral_booster_button')
```

### 3️⃣ التحكم في الشاشات

```dart
// في navigation
VisibilityControlled(
  controlName: 'video_editor_screen',
  fallback: Center(child: Text('غير مصرح')),
  child: VideoEditorScreen(),
)
```

### 4️⃣ إضافة عنصر واجهة جديد

```dart
final adminController = Get.find<AdminController>();

await adminController.addUIControl(
  controlName: 'new_feature_button',
  description: 'زر الميزة الجديدة',
  category: 'button', // أو 'screen' أو 'feature'
);
```

---

## 🔧 AdminController API

### تحميل البيانات
```dart
await adminController.loadData();
await adminController.loadUsers();
await adminController.loadUIControls();
```

### إدارة الصلاحيات
```dart
// إخفاء/إظهار عنصر
await adminController.toggleControlVisibility(
  userId: 1,
  controlName: 'auto_director_button',
  visible: false,
);

// تفعيل/تعطيل عنصر
await adminController.toggleControlEnabled(
  userId: 1,
  controlName: 'viral_booster_button',
  enabled: false,
);
```

### إدارة الأدوار
```dart
// تغيير دور المستخدم
await adminController.changeUserRole(userId, 'creator');

// الأدوار المتاحة: 'user', 'creator', 'admin'
```

### إدارة المستخدمين
```dart
// حذف مستخدم
await adminController.deleteUser(userId);

// إعادة تعيين جميع الصلاحيات
await adminController.resetUserPermissions(userId);
```

---

## 📊 DBService API

### الحصول على الصلاحيات
```dart
final dbService = Get.find<DBService>();

// التحقق من إمكانية رؤية عنصر
bool canSee = await dbService.canUserSeeControl(userId, 'auto_director_button');

// التحقق من تفعيل عنصر
bool isEnabled = await dbService.isControlEnabledForUser(userId, 'auto_director_button');

// الحصول على صلاحية محددة
Map<String, dynamic>? permission = await dbService.getUserPermission(userId, 'auto_director_button');

// الحصول على جميع صلاحيات المستخدم
List<Map<String, dynamic>> permissions = await dbService.getUserPermissions(userId);
```

### تعيين الصلاحيات
```dart
// تعيين صلاحية
await dbService.setUserPermission(
  userId: 1,
  controlName: 'auto_director_button',
  visible: true,
  enabled: false,
);

// حذف صلاحية
await dbService.deleteUserPermission(userId, 'auto_director_button');

// إعادة تعيين جميع الصلاحيات
await dbService.resetUserPermissions(userId);
```

### إدارة عناصر الواجهة
```dart
// الحصول على جميع العناصر
List<Map<String, dynamic>> controls = await dbService.getAllUIControls();

// الحصول على عنصر محدد
Map<String, dynamic>? control = await dbService.getUIControlByName('auto_director_button');

// إضافة عنصر جديد
await dbService.addUIControl(
  controlName: 'new_button',
  description: 'زر جديد',
  category: 'button',
);
```

---

## 🎨 واجهة Admin Dashboard

### الميزات:
1. **لوحة المستخدمين**:
   - عرض جميع المستخدمين
   - إحصائيات حسب الدور
   - فلترة حسب الدور

2. **محرر الصلاحيات**:
   - تعديل صلاحيات كل مستخدم
   - تبديل الرؤية والتفعيل
   - تجميع حسب الفئة (أزرار، شاشات، ميزات)

3. **إدارة الأدوار**:
   - تغيير دور المستخدم
   - حذف المستخدم
   - إعادة تعيين الصلاحيات

---

## 🔐 الأمان

- **المدراء فقط**: يمكنهم الوصول إلى لوحة التحكم
- **الصلاحيات الافتراضية**: جميع العناصر مرئية ومفعلة افتراضياً
- **Cascade Delete**: حذف المستخدم يحذف جميع صلاحياته تلقائياً

---

## 📝 أمثلة عملية

### مثال 1: إخفاء زر Auto Director عن المستخدمين العاديين

```dart
// في الواجهة
ElevatedButton(
  onPressed: () => autoDirector(),
  child: Text('Auto Director'),
).withVisibilityControl('auto_director_button')

// في لوحة التحكم
adminController.toggleControlVisibility(
  userId: normalUserId,
  controlName: 'auto_director_button',
  visible: false,
);
```

### مثال 2: تعطيل محرر الفيديو للمستخدمين غير المدفوعين

```dart
// في navigation
PermissionControlledWidget(
  controlName: 'video_editor_screen',
  fallback: UpgradePromptScreen(),
  child: VideoEditorScreen(),
)

// في لوحة التحكم
adminController.toggleControlEnabled(
  userId: freeUserId,
  controlName: 'video_editor_screen',
  enabled: false,
);
```

### مثال 3: منح صلاحيات خاصة لمنشئي المحتوى

```dart
// تغيير الدور أولاً
await adminController.changeUserRole(userId, 'creator');

// ثم تفعيل الميزات الخاصة
await adminController.toggleControlVisibility(
  userId: userId,
  controlName: 'advanced_analytics_screen',
  visible: true,
);
```

---

## 🚀 الخطوات التالية

1. **تطبيق الصلاحيات على الواجهات الموجودة**:
   - AI Studio Screen
   - Video Editor Screen
   - Settings Screen

2. **إضافة المزيد من العناصر القابلة للتحكم**:
   - أزرار محددة
   - ميزات متقدمة
   - أقسام في الشاشات

3. **تحسينات مستقبلية**:
   - صلاحيات على مستوى الأدوار (Role-based)
   - صلاحيات مؤقتة (Time-limited)
   - سجل التغييرات (Audit Log)

---

## 📞 الدعم

للمزيد من المساعدة أو الأسئلة، راجع الكود المصدري أو اتصل بفريق التطوير.
