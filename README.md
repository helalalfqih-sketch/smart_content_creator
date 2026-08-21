# 📱 صانع المحتوى الذكي (Smart Content Creator)
## 📋 الدليل الهندسي الشامل والتقرير المعماري لبناء وتشغيل النظام (System Architecture & Replication Blueprint)

---

## 📑 الفهرس (Table of Contents)
1. [نظرة عامة على النظام (Executive Overview)](#1-نظرة-عامة-على-النظام)
2. [المعمارية والتقنيات المستخدمة (Technology Stack & Architecture)](#2-المعمارية-والتقنيات-المستخدمة)
3. [هيكلية المشروع وشجرة الملفات (Project Structure)](#3-هيكلية-المشروع-وشجرة-الملفات)
4. [مخطط قواعد البيانات ونماذج البيانات (Database Schema & Models)](#4-مخطط-قواعد-البيانات-ونماذج-البيانات)
5. [بنية خوادم الذكاء الاصطناعي والبوابة السحابية (AI Gateway & Cloud Infrastructure)](#5-بنية-خوادم-الذكاء-الاصطناعي-والبوابة-السحابية)
6. [الأنظمة والموديولات الوظيفية (Core Functional Modules)](#6-الأنظمة-والموديولات-الوظيفية)
7. [الأمان، الصلاحيات ونظام الاشتراكات (Security, IAM & SaaS Economy)](#7-الأمان-والصلاحيات-ونظام-الاشتراكات)
8. [دليل التثبيت والتشغيل للمطورين (Developer Setup & Deployment Guide)](#8-دليل-التثبيت-والتشغيل-للمطورين)

---

## 1. نظرة عامة على النظام
منصة متكاملة وتطبيق جوال/ويب احترافي مبني بتقنية **Flutter** لإدارة كتالوجات المتاجر الإلكترونية وصناعة المحتوى التسويقي آلياً بالذكاء الاصطناعي (**Google Gemini & Vertex AI**).

### الأهداف الرئيسية:
- **تحليل المنتجات بالرؤية الحاسوبية (Computer Vision):** التقاط أو رفع صورة المنتج واستخراج الاسم والوصف والمزايا والوسوم التسويقية تلقائياً.
- **إدارة واستيراد الكتالوجات الضخمة:** دعم استيراد كتالوجات **Meta Catalog (Facebook/Instagram)** وملفات **Excel/CSV** بآلاف المنتجات دفعة واحدة إلى سحابة Firestore.
- **صانع خطط النشر والمحتوى:** توليد منشورات تسويقية مجدولة للمنصات (Instagram, TikTok, Facebook, Twitter, WhatsApp).
- **لوحة تحكم إدارية شاملة (Admin Control Center):** إدارة المستخدمين، مصفوفة الصلاحيات، التحكم في أسعار ورصيد الـ AI، ومراقبة العمليات لحظياً.

---

## 2. المعمارية والتقنيات المستخدمة

### 🖥️ الواجهة الأمامية (Frontend & Mobile Client):
- **الإطار البرمجي:** `Flutter` (Dart 3.x).
- **إدارة الحالة وحقن الاعتماديات:** `GetX` (`GetxController`, `GetxService`, `GetBuilder`, `Obx`).
- **التصميم والخطوط:** تصميم عصري داكن (Dark Neumorphism / Glassmorphism) مع خطوط `Google Fonts (Cairo & Inter)`.
- **معالجة الوسائط والفيديو:** `media_kit`, `video_editor`, `video_thumbnail`.
- **التخزين المحلي:** `sqflite` (SQLite Offline Caching), `shared_preferences`.

### ☁️ الخدمات السحابية وقواعد البيانات (Backend & Cloud Services):
- **المصادقة (Authentication):** `Firebase Authentication` (البريد وكلمة المرور، تسجيل دخول Google، المصادقة المجهولة).
- **قاعدة البيانات الأساسية:** `Google Cloud Firestore` (NoSQL Realtime Database).
- **التخزين السحابي للصور والملفات:** `Firebase Storage`.
- **البوابة السحابية للذكاء الاصطناعي (AI Gateway Proxy):** خوادم `Back4App (Parse Server Node.js Cloud Code)` للوساطة وتأمين المفاتيح.
- **تحديثات الكود عبر الهواء (Code Push):** `Shorebird Code Push`.
- **محركات الذكاء الاصطناعي:** `Google Gemini 3.6 Flash / 2.5 Flash`, `Google Vertex AI Enterprise`.

---

## 3. هيكلية المشروع وشجرة الملفات

```
lib/
├── main.dart                          # نقطة الانطلاق وتهيئة Firebase و GetX
├── core/                              # النواة الأساسية، الثيمات والروابط
│   ├── bindings/                      # InitialBinding لتهيئة الخدمات الأساسية
│   ├── constants/                     # الثوابت، الألوان والأحجام
│   ├── models/                        # نماذج البيانات المشتركة
│   └── theme/                         # ثيم التطبيق الداكن والتأثيرات البصرية
├── controllers/                       # متحكمات GetX لإدارة المنطق والحالة
│   ├── auth_controller.dart           # تسجيل الدخول، إنشاء الحساب، وصلاحيات الأدمن
│   ├── catalog_controller.dart        # إدارة الكتالوج، استيراد إكسل Meta، والفلترة
│   ├── admin_controller.dart          # لوحة التحكم، المستخدمين، والصلاحيات
│   ├── chat_controller.dart           # مساعد المحادثة التسويقية الذكي
│   ├── content_creator_controller.dart# توليد النصوص والخطط التسويقية
│   └── settings_controller.dart       # إعدادات المستخدم وتخصيص الواجهة
├── models/                            # كلاسات ونماذج قواعد البيانات
│   ├── catalog_product_model.dart     # نموذج المنتج المتكامل ودعم Excel Meta
│   ├── user_model.dart                # نموذج المستخدم، الرصيد وخطة الاشتراك
│   ├── post_plan_model.dart           # نموذج خطة النشر والجدولة
│   └── ui_control_model.dart          # نموذج التحكم الديناميكي في عناصر الواجهة
├── screens/                           # شاشات وواجهات المستخدم
│   ├── auth/                          # شاشات تسجيل الدخول وإنشاء الحساب
│   ├── catalog/                       # شاشات الكتالوج وتفاصيل وإضافة المنتجات
│   ├── admin_dashboard_screen.dart    # لوحة تحكم المسؤول الفائقة (Desktop & Mobile)
│   ├── chat_screen.dart               # شاشة الشات الذكي مع الذكاء الاصطناعي
│   └── content_creator_screen.dart    # استوديو صناعة المحتوى
└── services/                          # الخدمات والطبقات الخارجية
    ├── ai_provider.dart               # موزع طلبات الذكاء الاصطناعي (AI Factory)
    ├── back4app_gateway_service.dart  # الربط المباشر مع بوابة Back4App Cloud Code
    ├── vertex_ai_service.dart         # موصل Vertex AI Enterprise
    ├── db_service.dart                # قاعدة البيانات المحلية SQLite
    └── subscription_service.dart      # إدارة خطط وباقات الاشتراك SaaS
```

---

## 4. مخطط قواعد البيانات ونماذج البيانات

### 🗄️ مجموعات Firestore (Firestore Collections):

#### 1. مجموعة المستخدمين `users/{userId}`:
```json
{
  "id": "STRING (UID)",
  "email": "user@example.com",
  "username": "Helal",
  "role": "admin | creator | user",
  "firestore_role": "admin | user",
  "isPremium": true,
  "credits": 100,
  "is_ai_blocked": false,
  "status": "active",
  "subscriptionPlan": "free | pro | enterprise",
  "subscriptionExpiresAt": "TIMESTAMP",
  "createdAt": "TIMESTAMP",
  "lastActiveAt": "TIMESTAMP"
}
```

#### 2. مجموعة كتالوج المنتجات `catalog_products/{productId}`:
```json
{
  "id": "STRING (UUID)",
  "title": "ساعة يد رجالية فاخرة",
  "description": "وصف تسويقي احترافي للمنتج...",
  "price": 150.0,
  "currency": "USD",
  "category": "ساعات وإكسسوارات",
  "image": "URL (Firebase Storage / Web)",
  "additionalImageLinks": ["URL1", "URL2"],
  "sku": "WATCH-001",
  "availability": "in stock",
  "condition": "new",
  "brand": "BrandName",
  "status": "approved | pending | archived",
  "aiAnalysis": {
    "tags": ["ساعة", "فخامة", "رجالي"],
    "targetAudience": "رجال الأعمال، الشباب",
    "sellingPoints": ["مقاومة للماء", "زجاج ياقوتي"]
  },
  "userId": "STRING (UID)",
  "createdAt": "TIMESTAMP"
}
```

#### 3. مجموعة إعدادات النظام `app_settings/ai_config`:
```json
{
  "free_daily_limit": 50,
  "managed_keys": {
    "gemini": "ACTIVE",
    "vertex": "ACTIVE"
  },
  "isMaintenanceMode": false,
  "minAppVersion": "1.3.0"
}
```

---

## 5. بنية خوادم الذكاء الاصطناعي والبوابة السحابية

### 🛡️ تدفق الطلبات والأمان (Secure Proxy Architecture):
```
[Flutter App Client]
       │
       │ (1. Authorization: Parse App ID + REST API Key)
       ▼
[Back4App Node.js Gateway: aiGateway / aiVertexGateway]
       │
       │ (2. Server-side Secret Key: Google Gemini 3.6 Flash / Vertex Auth)
       ▼
[Google AI Cloud Engine]
       │
       │ (3. Response: Rich Marketing Text / Product Vision Analysis)
       ▼
[Back4App Gateway Response] ──(HTTP 200)──► [Flutter App Client]
```

### مزايا البوابة السحابية في `main.js`:
1. **انعدام تسريب المفاتيح (Zero-Leakage):** لا يوجد أي مفتاح API داخل كود تطبيق العميل أو ملف الـ APK.
2. **التوجيه الذكي للنماذج (Auto Model Routing):** توجيه الطلبات إلى أحدث النماذج النشطة (`gemini-3.6-flash`).
3. **دعم الصور والرؤية (Vision Support):** معالجة الصور المرسلة بترميز Base64 وفحصها بالذكاء الاصطناعي.
4. **تسجيل الأخطاء التلقائي (Telemetry & Logging):** تسجيل أي انقطاع أو خطأ لحظياً في كلاس `AiErrorLogs`.

---

## 6. الأنظمة والموديولات الوظيفية

### 📦 1. نظام استيراد كتالوج Meta و Excel الذكي (`CatalogController`):
- يقرأ ملفات `.xlsx` و `.csv` الخاصة بكتالوجات Meta Catalog الرسمية.
- يدعم استخراج الأعمدة القياسية: (`id`, `title`, `description`, `link`, `image_link`, `price`, `availability`, `additional_image_link`).
- يحتوي على محرك **Batch Processing** يقوم بإدراج آلاف المنتجات إلى Firestore بحزم دفعية (Chunks of 500) لتفادي قيود الشبكة.

### 🎨 2. نظام تحليل الصور التسويقي (AI Vision Product Studio):
- يحلل صورة المنتج من الكاميرا أو المعرض مباشرة.
- يستخرج تلقائياً: (اسم المنتج، الفئة المناسبة، اقتراح السعر، 3 نقاط بيع فريدة، وصف تسويقي احترافي، ووسوم الهاشتاغ).

### 👑 3. لوحة تحكم المسؤول (Admin Super Dashboard):
- متوافقة للعمل كـ **Web / Desktop / Mobile**.
- شريط بحث وفلترة فورية للمستخدمين حسب الدور (`Admin`, `Creator`, `User`) أو الحالة (`Premium`, `Blocked`, `New`).
- تنبيه صوتي وتفاعلي لحظي عند انضمام مستخدم جديد للنظام.
- مصفوفة صلاحيات تفاعلية لتعديل صلاحيات كل مستخدم بنقرة زر واحدة.

---

## 7. الأمان والصلاحيات ونظام الاشتراكات

### مستويات المستخدمين (Role-Based Access Control):
| الدور (Role) | الصلاحيات | رصيد الذكاء الاصطناعي |
| :--- | :--- | :--- |
| **Admin (المسؤول)** | تحكم كامل، لوحة الإدارة، تعديل الكتالوج العالمي، إدارة المستخدمين | غير محدود (99999) |
| **Creator (صانع المحتوى)** | إضافة وتعديل المنتجات، تصدير خطط النشر، تحليل المنتجات | خطة Pro (1000/يوم) |
| **User (المستخدم العادي)** | تصفح المنتجات، طلبات التحليل الأساسية | خطة Free (20-50/يوم) |

---

## 8. دليل التثبيت والتشغيل للمطورين

### ⚙️ المتطلبات الأساسية (Prerequisites):
- `Flutter SDK` (إصدار 3.24+ أو أحدث).
- `Dart SDK` (إصدار 3.5+).
- `Node.js` (إصدار 18+).
- حساب `Firebase` ومشروع مهيأ.
- حساب `Back4App`.

### 🚀 خطوات التشغيل خطوة بخطوة:

#### 1. استنساخ المشروع وتثبيت الحزم:
```bash
git clone https://github.com/helalalfqih-sketch/smart_content_creator.git
cd smart_content_creator
flutter pub get
```

#### 2. إعداد ملفات Firebase:
- ضع ملف `google-services.json` داخل مجلد `android/app/`.
- قم بنشر قواعد الأمان الخاصة بقواعد البيانات:
```bash
firebase deploy --only firestore:rules,firestore:indexes
```

#### 3. إعداد ونشر خادم Back4App:
- أنشئ تطبيقاً في [Back4App](https://dashboard.back4app.com).
- انسخ محتوى ملف `main.js` الخاص بالبوابة السحابية إلى **Cloud Code Functions** واضغط **Deploy**.
- حدّث `_parseAppId` و `_parseRestApiKey` في ملف `lib/services/back4app_gateway_service.dart`.

#### 4. بناء وتشغيل التطبيق:
```bash
# تشغيل التطبيق في وضع التطوير
flutter run

# بناء ملف APK للإنتاج
flutter build apk --release --split-per-abi

# بناء نسخة الويب
flutter build web --release
```

---
**تم إعداد هذا التقرير ليكون المرجع الشامل (Master Blueprint) لإعادة بناء وتشغيل المنصة بنسبة مطابقة 100%.**
