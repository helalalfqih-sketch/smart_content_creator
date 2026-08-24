# الاعتماديات والمنصات — Dependencies & Platforms

---

## 1. تحليل pubspec.yaml

**إصدار التطبيق:** 1.3.1+7  
**SDK:** Dart >=3.3.0 <4.0.0 | Flutter >=3.22.0

### 1.1 الاعتماديات الرئيسية (62 حزمة)

| الفئة | الحزم | العدد |
|---|---|---|
| **Firebase** | firebase_core, firebase_auth, cloud_firestore, cloud_functions, firebase_storage, firebase_app_check, firebase_ai | **7** |
| **Supabase** | supabase_flutter | **1** |
| **State Management** | get, get_storage | **2** |
| **AI/ML** | google_generative_ai | **1** |
| **Database** | sqflite, path, path_provider | **3** |
| **Media** | video_player, video_player_win, chewie, audioplayers, image_picker, flutter_image_compress, video_thumbnail, image | **8** |
| **Networking** | http, dio, http_parser | **3** |
| **UI** | flutter_screenutil, responsive_framework, flutter_staggered_grid_view, fl_chart, shimmer, animate_do, google_fonts, lucide_icons, flutter_markdown, flutter_linkify | **10** |
| **Security** | flutter_secure_storage, crypto | **2** |
| **Platform** | file_picker, file_selector, open_filex, permission_handler, gal, receive_sharing_intent, connectivity_plus, app_links, share_plus, in_app_purchase | **10** |
| **Video Pipeline** | process_run, archive, youtube_explode_dart | **3** |
| **Social** | webview_flutter, webview_flutter_android | **2** |
| **Data** | excel, xml, mime, url_launcher, logger, vector_math | **6** |
| **Shorebird** | (مذكور في shorebird.yaml لكن ليس dependency مباشرة) | **0** |

### 1.2 dev_dependencies

| الحزمة | الإصدار |
|---|---|
| flutter_test | SDK |
| flutter_lints | ^6.0.0 |
| lints | ^6.0.0 |
| flutter_launcher_icons | ^0.13.1 |

**ملاحظة:** `flutter_lints` و `lints` كلاهما مثبت — هذا تكرار؛ عادةً يكفي أحدهما.

---

## 2. مشاكل الاعتماديات المحتملة

### 2.1 حزم قد تكون غير مستخدمة (NEEDS_VERIFICATION)

| الحزمة | السبب |
|---|---|
| `in_app_purchase` | لم يُعثر على استخدام واضح في الشاشات (subscription_screen قد يستخدمه) |
| `archive` | مذكور كـ "future proofing" في التعليق |
| `vector_math` | قد يكون dependency ضمنية |
| `get_storage` | SharedPreferences + SecureStorage يغطيان الاحتياج |

### 2.2 حقن مكرر لخدمات

تم توثيقه في تقرير Architecture.

---

## 3. المنصات المدعومة

### 3.1 Android
- **مجلد:** `android/`
- **Gradle:** يحتاج فحص `build.gradle` لـ minSdk, targetSdk, compileSdk
- **الحالة:** STATICALLY_VALID (لم يتم بناء APK)

### 3.2 iOS
- **مجلد:** `ios/`
- **الحالة:** STATICALLY_VALID

### 3.3 Web
- **مجلد:** `web/`
- **Firebase Options مضمنة في main.dart** للويب
- **الحالة:** STATICALLY_VALID

### 3.4 Windows
- **مجلد:** `windows/`
- **video_player_win مثبت** لدعم تشغيل الفيديو
- **رقعة FFmpeg في main.dart:56-58**
- **الحالة:** STATICALLY_VALID

### 3.5 macOS & Linux
- **مجلدات:** `macos/`, `linux/`
- **الحالة:** UNVERIFIED — لم يتم فحصهما بعمق

---

## 4. Shorebird OTA Updates

- **ملف الإعداد:** `shorebird.yaml`
- **app_id:** `50f79796-407c-4909-a7c2-8ed8d05d25b3`
- **auto_update:** مفعل (افتراضي)
- **الحالة:** STATICALLY_VALID — الإعداد موجود لكن لم يتم التحقق من عمل التحديثات

---

## 5. Firebase Configuration

- **firebase.json:** يحتوي إعدادات Firestore, Hosting, Storage, Functions
- **Hosting site:** `smartcontentcreator2`
- **Hosting public:** `web_landing` (صفحة هبوط)
- **Functions runtime:** `nodejs22`
- **Functions codebases:** `default` (functions/) + `functions` (backend/) ← **codebase ثاني يشير لمجلد `backend/` غير موجود!**

> [!WARNING]
> `firebase.json` يعرّف codebase ثاني بمصدر `"backend"` لكن **لا يوجد مجلد `backend/` في المشروع**.  
> الحالة: CONFIRMED_BROKEN — هذا سيسبب خطأ عند `firebase deploy --only functions`

---

## 6. Assets والخطوط

### الخطوط المسجلة:
- **IBMPlexSansArabic** — 7 أوزان (Regular, Bold, Light, Medium, SemiBold, ExtraLight, Thin)
- **NotoSansArabic** — 2 أوزان (Regular, Bold)

### الأصول المسجلة:
- `assets/fonts/`
- `assets/images/background.jpg`
- `assets/images/styles/logoapp.jpeg`
- `assets/images/styles/`
- `lib/services/data/mock_tiktok_trends.json`
- `shorebird.yaml`

---

## 7. .gitignore

### ملفات محمية بشكل صحيح:
- `.env`, `.env.*`, `functions/.env` ✅
- `*.apk`, `*.xlsx`, `*.log` ✅
- `build/`, `.dart_tool/`, `node_modules` ✅
- `scratch/`, `tmp/` ✅

### ملفات يجب إضافتها لـ .gitignore:
- `app_check_debug.txt` — موجود وغير متعقب ✅ (لكن يجب إضافته صراحة)
- `build_error.txt` — موجود وغير متعقب ✅
- `reports/` — تقارير التدقيق لا يجب تتبعها في الإنتاج
- `.vscode/` — مُعلق في .gitignore (يجب تفعيل الاستبعاد)
