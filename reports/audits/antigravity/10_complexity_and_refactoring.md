# تحليل التعقيد وخطة إعادة الهيكلة — Complexity & Refactoring Roadmap
## مشروع Smart Content Creator

---

## 1. قائمة الملفات ذات الحجم والتعقيد المرتفع (God Files)

تم تحديد عدة ملفات تتجاوز المعايير الهندسية النظيفة (أكثر من 500 سطر / 30 KB) وتجمع مسؤوليات متعددة:

| # | الملف (File) | الحجم | الأسطر التقريبية | المسؤوليات المتداخلة (Mixed Concerns) | أولوية إعادة الهيكلة |
|---|---|---|---|---|---|
| 1 | `lib/screens/catalog/product_catalog_screen.dart` | 151 KB | 3,264 سطر | بناء الواجهة، حساب الإحصائيات، فلاتر البحث، التحكم بالتحديد، شريط التقدم، معالجة الروابط | 🔴 قصوى (P0) |
| 2 | `lib/screens/admin_dashboard_screen.dart` | 137 KB | ~3,500 سطر | جداول المستخدمين، بطاقات الصلاحيات، مراقبة النشاط، إدارة الـ API keys، واجهات الرسوم البيانية | 🔴 قصوى (P0) |
| 3 | `lib/screens/settings_screen.dart` | 109 KB | ~2,500 سطر | حفظ الـ Tokens، خيارات الذكاء الاصطناعي، اختبار الاتصال، إعدادات الخوادم، واجهات التبديل | 🟠 عالية (P1) |
| 4 | `lib/screens/catalog/product_form_screen.dart` | 98 KB | ~2,200 سطر | معالجة نماذج الإدخال، رفع الوسائط، التحقق من الحقول، معالجة الصور، حفظ البيانات | 🟠 عالية (P1) |
| 5 | `lib/screens/ai_chat_screen.dart` | 84 KB | ~2,000 سطر | فقاعات الدردشة، مسجل الصوت، تشغيل الفيديو، قائمة النماذج، إدارة المرفقات | 🟠 عالية (P1) |
| 6 | `lib/controllers/catalog_controller.dart` | 82 KB | 2,060 سطر | التخزين المحلي SQLite، سحابة Back4App، استيراد/تصدير Excel، التحديد المتعدد، توليد Feeds | 🔴 قصوى (P0) |
| 7 | `lib/controllers/auth_controller.dart` | 51 KB | ~1,400 سطر | منطق الدخول، التسجيل، التحقق من الـ OTP، إدارة صلاحيات المستخدمين، التحقق من الجلسات | 🟡 متوسطة (P2) |
| 8 | `lib/controllers/admin_controller.dart` | 45 KB | ~1,200 سطر | استعلامات Firestore، عمليات الأدمن، إحصائيات النظام، تحديث الإعدادات العالمية | 🟡 متوسطة (P2) |

---

## 2. خارطة إعادة الهيكلة والتفكيك (Decomposition Strategy)

### 2.1 تفكيك `ProductCatalogScreen` (151 KB -> مكونات مستقلة)
```
lib/screens/catalog/
├── product_catalog_screen.dart (فقط Scaffold و CustomScrollView - أقل من 150 سطر)
├── sections/
│   ├── catalog_app_bar_section.dart (شريط البحث والتحديد السريع)
│   ├── catalog_stats_banner_section.dart (إحصائيات المنتجات والوسائط)
│   ├── catalog_filters_bar_section.dart (فلاتر التصنيفات والحالة)
│   └── catalog_feed_url_section.dart (بطاقة رابط Meta Catalog)
└── widgets/
    ├── product_grid_view.dart (شبكة عرض المنتجات)
    └── bulk_actions_floating_bar.dart (شريط العمليات الجماعية السفلي)
```

### 2.2 تفكيك `CatalogController` (82 KB -> متحكمات مجزأة)
```
lib/controllers/catalog/
├── catalog_controller.dart (المتحكم المنسق الرئيسي)
├── catalog_selection_controller.dart (إدارة التحديد المتعدد والحالة التفاعلية)
├── catalog_import_export_controller.dart (استيراد وتصدير ملفات Excel)
└── catalog_sync_controller.dart (المزامنة بين SQLite و Back4App Parse)
```

### 2.3 تفكيك `AdminDashboardScreen` (137 KB)
- فصل تبويبات الأدمن إلى ويدجت منفصلة:
  - `AdminUsersTab`
  - `AdminPermissionsTab`
  - `AdminApiKeysTab`
  - `AdminActivityLogsTab`
