# الأمان والخصوصية — Security & Privacy Audit

---

## 1. أسرار مكشوفة في الكود المصدري

### 🔴 CRITICAL: Firebase Options في main.dart

| البند | الموقع | الحالة |
|---|---|---|
| `apiKey` | `main.dart:67` | SECURITY_RISK — مكشوف في الكود |
| `appId` | `main.dart:68` | SECURITY_RISK — مكشوف في الكود |
| `messagingSenderId` | `main.dart:69` | SECURITY_RISK |
| `projectId` | `main.dart:70` | SECURITY_RISK |
| `storageBucket` | `main.dart:71` | SECURITY_RISK |
| `authDomain` | `main.dart:72` | SECURITY_RISK |

**التأثير:** أي شخص لديه وصول للمستودع يمكنه استخدام هذه المفاتيح للوصول لخدمات Firebase.  
**الدليل:** `main.dart` سطر 66-73  
**الحل:** نقل إلى `--dart-define` في البناء أو `flutter_dotenv` مع `.env` في `.gitignore`

### 🔴 CRITICAL: ملف .env في functions/

الملف `functions/.env` (245 bytes) موجود ويحتوي أسرار Back4App.  
**الحالة:** مدرج في `.gitignore` (`functions/.env`) ✅ — لكنه **موجود على القرص** ويمكن مشاركته بالخطأ.

### 🟡 MEDIUM: config.dart

`lib/config.dart:10` يحتوي `geminiApiKey = ""` (فارغ حالياً) — لكن الوجود يشير لاحتمال وضع مفتاح حقيقي لاحقاً.

### 🟡 MEDIUM: HuggingFace Model Names

`lib/config.dart:4-7` يحتوي أسماء نماذج HuggingFace — ليست أسراراً لكنها تكشف البنية.

---

## 2. Firebase App Check

| الفحص | النتيجة | الحالة |
|---|---|---|
| موقع التفعيل | `main.dart:88-101` | موجود |
| Provider للأندرويد | `AndroidProvider.debug` | ⚠️ SECURITY_RISK |
| Provider لـ iOS | `AppleProvider.debug` | ⚠️ SECURITY_RISK |
| Provider للويب | غير موجود | SECURITY_RISK |
| Production Provider (PlayIntegrity) | غير مفعل | SECURITY_RISK |

**التأثير:** App Check في وضع Debug يعني أن أي جهاز يمكنه استدعاء Firebase APIs بدون attestation حقيقي.  
**الحل:** تبديل إلى `AndroidProvider.playIntegrity` و `AppleProvider.appAttestWithDeviceCheckFallback` في الإنتاج.

---

## 3. قواعد Firestore

| المسار | القراءة | الكتابة | المشكلة |
|---|---|---|---|
| `users/{userId}` | مصادق | المالك أو Admin | ✅ مناسب |
| `users/{userId}/**` | مصادق | المالك أو Admin | ✅ مناسب |
| `subscriptions/{userId}` | المالك أو Admin | Admin فقط | ✅ مناسب |
| `app_settings/{id}` | مصادق | Admin فقط | ✅ مناسب |
| **`global_config/{id}`** | **`if true` (بدون مصادقة)** | Admin فقط | ⚠️ HIGH — بيانات الإعداد مكشوفة للعامة |
| `ui_controls/{id}` | مصادق | Admin فقط | ✅ مناسب |
| `user_permissions/{id}` | مصادق | Admin فقط | ✅ مناسب |
| `user_activity_logs/{id}` | المالك أو Admin | إنشاء: المالك، تعديل/حذف: Admin | ✅ مناسب |
| **`catalog_products/{id}`** | **`if true` (بدون مصادقة)** | إنشاء: مصادق، تعديل/حذف: المالك أو Admin | ⚠️ HIGH — كل المنتجات مكشوفة |

**التعليق على `catalog_products`:** القراءة العامة مقصودة لأن الكتالوج يُنشر لـ Meta/Facebook. لكن يجب التأكد أن البيانات لا تحتوي معلومات حساسة.

**التعليق على `global_config`:** `allow read: if true` يعني أن أي شخص يمكنه قراءة إعدادات النظام بدون تسجيل دخول. **يجب مراجعة المحتوى** — إذا كان يحتوي مفاتيح API أو إعدادات حساسة فهذا خطر حرج.

---

## 4. قواعد Storage

| المسار | القراءة | الكتابة | المشكلة |
|---|---|---|---|
| `public/app-latest.apk` | عام | ممنوع | ✅ مناسب |
| `chat_media/{chatId}/**` | مصادق | مصادق | ⚠️ أي مستخدم يقرأ وسائط أي محادثة |
| `users/{userId}/catalog_media/**` | عام | المالك فقط | ✅ مقصود (Meta catalog) |
| `catalogs/{userId}/**` | عام | المالك أو global | ✅ مقصود (CSV feed) |
| **`/{allPaths=**}`** | **مصادق** | **مصادق** | 🔴 CRITICAL — أي مستخدم مسجل يمكنه الكتابة في أي مسار |

**أخطر مشكلة:** القاعدة الافتراضية `/{allPaths=**}` تسمح لأي مستخدم مسجل بالقراءة والكتابة في أي مسار لم تُحدد له قاعدة خاصة. هذا يعني:
- يمكن لمستخدم رفع ملف في مسار مستخدم آخر
- يمكن الكتابة فوق ملفات النظام
- **الحل:** تقييد القاعدة الافتراضية أو حذفها

---

## 5. مخاطر إضافية مكتشفة

### 5.1 CSV/Excel Formula Injection
**الملف:** `catalog_xlsx_import_service.dart`  
**الخطر:** عند استيراد ملفات Excel من مصادر خارجية، الخلايا التي تبدأ بـ `=`, `+`, `-`, `@` يمكن أن تنفذ صيغاً خبيثة.  
**الحالة:** NEEDS_RUNTIME_TEST — يجب فحص هل يتم تعقيم المدخلات.

### 5.2 WebView
**الحزمة:** `webview_flutter` في `pubspec.yaml:83`  
**الخطر:** إذا تم تحميل URLs من مدخلات المستخدم بدون تحقق، يمكن استغلالها لـ phishing أو XSS.  
**الحالة:** NEEDS_RUNTIME_TEST

### 5.3 عدم وجود Route Guard
**الخطر:** المسارات المحمية (`/admin`, `/settings`, `/catalog`) يمكن الوصول إليها عبر Deep Links بدون تحقق من المصادقة.  
**الحالة:** SECURITY_RISK  
**الحل:** إضافة GetX Middleware يتحقق من `AuthController.isLoggedIn` قبل كل مسار محمي.

### 5.4 أذونات Android
**الملف:** `android/app/src/main/AndroidManifest.xml`  
**الحالة:** لم يتم فحص الأذونات المطلوبة بالتفصيل (NEEDS_RUNTIME_TEST)  
**يجب التحقق من:** INTERNET, CAMERA, STORAGE, RECORD_AUDIO, وأي أذونات زائدة

### 5.5 Logging بيانات حساسة
**الملف:** `main.dart:112-114`  
**الكود:** `debugPrint("🚨 Flutter Error: ${details.exceptionAsString()}")` — قد يطبع stack traces تحتوي مسارات ملفات أو بيانات حساسة.  
**الحالة:** LOW — فقط في debug mode

---

## 6. ملخص الأمان

| الفئة | الحالة | العدد |
|---|---|---|
| أسرار مكشوفة في الكود | 🔴 CRITICAL | 6+ |
| App Check ضعيف | 🟠 HIGH | 1 |
| قواعد Firestore مفتوحة | 🟠 HIGH | 2 |
| قواعد Storage خطيرة | 🔴 CRITICAL | 1 |
| غياب Route Guards | 🟠 HIGH | 1 |
| مخاطر محتملة تحتاج فحص | 🟡 MEDIUM | 3 |
