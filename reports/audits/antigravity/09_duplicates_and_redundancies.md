# تدقيق التكرار والازدواجية — Duplicates & Redundancies
## مشروع Smart Content Creator

---

## 1. التكرار البرمجي المكتشف (Code & Logic Duplications)

### 1.1 الحقن المزدوج للخدمات (Double Dependency Registration)
- **`SecureStorageService`:**
  - تم حقنه في `lib/main.dart` (السطر 52): `Get.put(SecureStorageService(), permanent: true);`
  - تم حقنه مرة ثانية في `lib/core/bindings/initial_binding.dart` (السطر 81): `Get.put(SecureStorageService(), permanent: true);`
- **`AiImageGenerationService`:**
  - تم حقنه في `lib/main.dart` (السطر 121): `Get.put(AiImageGenerationService(), permanent: true);`
  - تم حقنه ثانية كـ `lazyPut` في `lib/core/bindings/initial_binding.dart` (السطر 132).
- **الأثر الهندسي:** يسبب ارتباكاً في دورة حياة الخدمات ويجعل تتبع نقطة الإنشاء الفعلية أصعب، مع احتمال استهلاك طفيف إضافي للذاكرة.

### 1.2 ازدواجية المسارات (Route Redundancy)
- المسار `/home` والمسار `/main` في `lib/main.dart` (الأسطر 198-203) كلاهما يشير إلى نفس الويدجت `const MainWrapper()`.
- **التوصية:** اعتماد مسار موحد `/home` وحذف `/main` أو عمل Redirect صريح.

### 1.3 تكرار حزم الـ Linter في `pubspec.yaml`
- `flutter_lints: ^6.0.0` و `lints: ^6.0.0` مدرجان معاً في قسم `dev_dependencies`. يكفي الاعتماد على `flutter_lints` فقط لمشاريع Flutter.

---

## 2. ازدواجية البيانات وتكرار المنتجات (Data Duplication)

بناءً على نتائج تحليل الكتالوج المسجلة في `09_duplicates.csv`:
- إجمالي المنتجات في ملف التصدير: **1743 منتج**.
- المجموعات المكررة (Duplicate Composite Groups بناءً على الاسم والصورة): **371 مجموعة**.
- النسخ الزائدة المكررة (Extra Duplicate Copies): **1357 نسخة مكررة**.
- **السبب:** عمليات استيراد متكررة لملفات Excel دون تفعيل فحص البصمة الفريدة للمنتج (Deduplication Check) قبل الإدراج في قاعدة البيانات.

---

## 3. تكرار نماذج الذكاء الاصطناعي وخدمات التوجيه
- وجود `GeminiService` و `VertexAiService` و `FirebaseAiLogicService` و `UnifiedAIService` يؤدي إلى تداخل منطق إرسال رسائل الـ Chat وتحليل الوسائط عبر أكثر من قناة.
- **الحل:** تركيز كل العمليات عبر واجهة `AIBackendRouter` الموحدة كـ Facade وحيدة للـ AI.
