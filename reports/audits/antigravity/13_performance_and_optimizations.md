# الأداء والتحسينات الممكنة — Performance & Optimizations
## مشروع Smart Content Creator

---

## 1. فرص تحسين الذاكرة والتخزين المؤقت (Memory & Caching)

### 1.1 التخزين المؤقت للصور (Image Caching)
- **الوضع الحالي:** استخدام مزيج من `Image.network` ومكتبة الصور المخصصة `CatalogProductImage`.
- **المخاطر:** عند التمرير في كتالوج يحتوي على آلاف المنتجات، يؤدي تحميل الصور بدون حد أقصى للحجم المخزن مؤقتاً (cacheWidth / cacheHeight) إلى استهلاك كبير لذاكرة الرام (RAM Spikes) على الأجهزة المتوسطة والضعيفة.
- **التوصية:**
  - إلزام ضبط `memCacheWidth: 400` و `memCacheHeight: 400` للصور المصغرة في بطاقات المنتجات.
  - استخدام `CachedNetworkImage` مع `maxBytes` محدد.

### 1.2 دورة حياة مشغلات الفيديو (Video Controller Lifecycle)
- **الوضع الحالي:** يتم تشغيل الفيديوهات في شاشات الكتالوج والدردشة.
- **التحسين:** التأكد من إيقاف مؤقت (Pause) وتفريغ (Dispose) أي `VideoPlayerController` بمجرد خروج بطاقة المنتج من نطاق الشاشة المرئي (Viewport) باستخدام `VisibilityDetector`.

---

## 2. تحسين بناء الواجهات (Widget Build Optimization)

### 2.1 تقليل نطاق الـ Obx Rebuilds
- في شاشات مثل `ProductCatalogScreen`، تغليف الشجرة بـ `Obx` على مستوى عالٍ يؤدي إلى إعادة حساب وبناء كامل الشجرة عند تغيير متغير بسيط مثل حالة الفلتر.
- **الحل:** تقسيم الويدجت واستخدام `Obx` فقط حول النص أو الزر الصغير الذي يتغير (Granular Reactivity).

### 2.2 استخدام `const Constructors`
- تفعيل قواعد الـ Linter (`prefer_const_constructors`) يساعد Flutter في إعادة استخدام نفس كائنات الـ Widget في الذاكرة دون إعادة إنشائها أثناء كل Frame.

---

## 3. تحسين استعلامات قواعد البيانات وشبكة البيانات (Database & Network IO)

### 3.1 استعلامات التصفح المجزأ (Pagination & Batching)
- **قاعدة SQLite المحلية:** عند استرجاع المنتجات، ينبغي استخدام `LIMIT` و `OFFSET` أو Cursor-based pagination بدلاً من جلب كامل الجدول (`SELECT *`) دفعة واحدة في الذاكرة عندما يتجاوز عدد العناصر 1,000 منتج.
- **فهرسة SQLite (Indexing):** إضافة Index على الأعمدة المستخدمة في البحث والفرز (`title`, `category`, `createdAt`, `availability`) لتسريع استجابة التصفح من عشرات الأجزاء من الثانية إلى أجزاء طفيفة جداً.

### 3.2 إعدادات Firestore Offline Cache
- تم تفعيل `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED` في `main.dart:82`.
- **ملاحظة:** ضبط الكاش كـ Unlimited قد يؤدي بمرور الأشهر إلى تضخم حجم بيانات التطبيق على جهاز المستخدم. يفضل تعيين حد آمن مثل 100 ميجابايت (`104857600 bytes`).
