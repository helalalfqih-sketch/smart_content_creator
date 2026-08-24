# تحليل الشاشات وعناصر الواجهة — Screens & UI Deep Dive
## مشروع Smart Content Creator

---

## 1. فهرس الشاشات الرئيسية (Screens Catalog)

يحتوي التطبيق على أكثر من 20 شاشة موزعة عبر مختلف الميزات:

| # | الشاشة (Screen) | المسار (File) | الحجم والأسطر | الغرض وطبيعة الواجهة | الحالة |
|---|---|---|---|---|---|
| 1 | `SplashScreen` | `lib/screens/splash_screen.dart` | 245 سطر (7 KB) | شاشة الإقلاع والتحقق من الجلسة والخلفية المجريّة التفاعلية | STATICALLY_VALID |
| 2 | `LoginScreen` | `lib/screens/auth/login_screen.dart` | 315 سطر (11 KB) | تسجيل الدخول بالبريد الإلكتروني أو Google | STATICALLY_VALID |
| 3 | `SignupScreen` | `lib/screens/auth/signup_screen.dart` | 230 سطر (7.7 KB) | إنشاء حساب جديد وربطه بالخدمات السحابية | STATICALLY_VALID |
| 4 | `PasswordResetOtpScreen` | `lib/screens/auth/password_reset_otp_screen.dart` | 210 سطر (7.6 KB) | استرجاع كلمة المرور عبر الرمز | STATICALLY_VALID |
| 5 | `AccountConfirmationScreen` | `lib/screens/auth/account_confirmation_screen.dart` | 170 سطر (5.6 KB) | تأكيد الحساب وتفعيله | STATICALLY_VALID |
| 6 | `EditProfileScreen` | `lib/screens/auth/edit_profile_screen.dart` | 420 سطر (17 KB) | تعديل الملف الشخصي والبيانات والصور | STATICALLY_VALID |
| 7 | `MainWrapper` | `lib/screens/main_wrapper.dart` | 380 سطر (14 KB) | شريط التنقل السفلي الديناميكي والتبديل بين التبويبات | STATICALLY_VALID |
| 8 | `AiChatScreen` | `lib/screens/ai_chat_screen.dart` | ~2000 سطر (84 KB) | واجهة الدردشة الذكية متعددة الوسائط (نصوص، صور، صوت، فيديو) | STATICALLY_VALID |
| 9 | `ProductCatalogScreen` | `lib/screens/catalog/product_catalog_screen.dart` | 3264 سطر (151 KB) | كتالوج المنتجات لـ Meta (شبكة المنتجات، البحث، الفلاتر، العمليات الجماعية) | PERFORMANCE_RISK |
| 10 | `ProductFormScreen` | `lib/screens/catalog/product_form_screen.dart` | ~2200 سطر (98 KB) | نموذج إضافة وتعديل المنتج وحقول Meta ورفع الوسائط | PERFORMANCE_RISK |
| 11 | `WhatsappMediaSyncScreen` | `lib/screens/catalog/whatsapp/whatsapp_media_sync_screen.dart` | 650 سطر (29 KB) | شاشة مزامنة وسائط واتساب مع الكتالوج | STATICALLY_VALID |
| 12 | `AdminDashboardScreen` | `lib/screens/admin_dashboard_screen.dart` | ~3500 سطر (137 KB) | لوحة تحكم الإدارة الشاملة (المستخدمين، الصلاحيات، المفاتيح، السجلات) | PERFORMANCE_RISK |
| 13 | `UsersListScreen` | `lib/screens/admin/users_list_screen.dart` | 850 سطر (32 KB) | قائمة المستخدمين المفصلة وإدارتهم للأدمن | STATICALLY_VALID |
| 14 | `SettingsScreen` | `lib/screens/settings_screen.dart` | ~2500 سطر (109 KB) | إعدادات مفاتيح API ومقدمي الذكاء الاصطناعي | PERFORMANCE_RISK |
| 15 | `GeneralSettingsScreen` | `lib/screens/general_settings_screen.dart` | 420 سطر (16 KB) | الإعدادات العامة (المظهر، اللغة، الإشعارات) | STATICALLY_VALID |
| 16 | `ProductPhotographyScreen` | `lib/screens/product_photography_screen.dart` | ~750 سطر (28 KB) | استوديو تصوير المنتجات وعزل الخلفية بالذكاء الاصطناعي | STATICALLY_VALID |
| 17 | `CreatorProfileScreen` | `lib/screens/creator_profile_screen.dart` | 390 سطر (15 KB) | ملف المبدع وإحصائياته | STATICALLY_VALID |
| 18 | `SubscriptionScreen` | `lib/screens/subscription_screen.dart` | 480 سطر (19 KB) | باقات الاشتراك ونظام الترقية | STATICALLY_VALID |
| 19 | `PrivacyPolicyScreen` | `lib/screens/privacy_policy_screen.dart` | 180 سطر (6 KB) | سياسة الخصوصية | STATICALLY_VALID |
| 20 | `TermsOfServiceScreen` | `lib/screens/terms_of_service_screen.dart` | 190 سطر (6.5 KB) | شروط الخدمة والاستخدام | STATICALLY_VALID |

---

## 2. تحليل المكونات والويدجت (Custom Widgets Breakdown)

### 2.1 مكونات الكتالوج (Catalog Widgets)
- **`ProductCard` (`lib/screens/catalog/widgets/product_card.dart` - 20 KB):**
  - بطاقة عرض المنتج الفردي داخل الشبكة مع شارات التوفر، وسعر التخفيض، ونوع الوسائط.
  - تدعم التحديد الطويل (Long Press) للتحديد المتعدد وإجراءات سريعة (مشاركة، تعديل، حذف).
  - استخدام `CachedNetworkImage` أو بديل التخزين السحابي لتقليل استهلاك الذاكرة.
- **`CatalogProductImage` (`lib/screens/catalog/widgets/catalog_product_image.dart` - 5 KB):**
  - عنصر مخصص للتعامل الذكي مع روابط الصور الخارجية، ودعم fallback في حالة فشل التحميل.

### 2.2 ويدجت الخلفيات والمؤثرات البصرية
- **`GalacticBackgroundUnified` (`lib/core/theme/animations/galactic_background_unified.dart`):**
  - رسم فضائي مخصص عبر `CustomPainter` ومحركات حركة `AnimationController` لتقديم واجهة بصرية فاخرة.
  - تستخدم في الـ SplashScreen وشاشات المصادقة.

---

## 3. تدقيق الأداء ودورات حياة الويدجت (Lifecycle & State Management)

### 3.1 إدارة الذاكرة وتفريغ الـ Controllers (Disposal)
- **شاشات الفيديو ومشغلات الوسائط:**
  - في شاشات الكتالوج والدردشة، يتم تهيئة `VideoPlayerController` و `ChewieController`.
  - **ملاحظة فحص:** يجب التأكد من استدعاء `controller.dispose()` داخل `dispose()` أو `onClose()` لتجنب تسريب الذاكرة (Memory Leaks) خاصة عند تكرار التمرير في الشبكة.
- **متحكمات الحركة `AnimationController`:**
  - في `SplashScreen` تم توثيق تفريغ `_mainController.dispose()` و `_bgController.dispose()` بشكل صحيح (الأسطر 86-90).

### 3.2 إعادة البناء غير الضرورية (Rebuild Triggers)
- في `ProductCatalogScreen` و `AdminDashboardScreen`، توجد مقتطفات `Obx` كبيرة تغلف شاشات كاملة أو قوائم بطول مئات العناصر، مما قد يؤدي إلى إعادة رسم (Repaint) لعناصر غير متغيرة عند تحديث حالة جزئية مثل عداد التحديد.
- **التوصية:** تضييق نطاق الـ `Obx` ليكون على مستوى الـ Widget الفعلي المتأثر فقط (Granular Obx).
