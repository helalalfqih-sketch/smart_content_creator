# المسارات وتدفقات المستخدم — Routes & User Flows

---

## 1. جدول المسارات المسجلة (Routes)

| # | المسار | الشاشة | الملف | نوع الحماية | الحالة |
|---|---|---|---|---|---|
| 1 | `/login` | LoginScreen | `screens/auth/login_screen.dart` | عام | STATICALLY_VALID |
| 2 | `/signup` | SignupScreen | `screens/auth/signup_screen.dart` | عام | STATICALLY_VALID |
| 3 | `/password-reset-otp` | PasswordResetOtpScreen | `screens/auth/password_reset_otp_screen.dart` | عام (يأخذ email) | STATICALLY_VALID |
| 4 | `/account-confirmation` | AccountConfirmationScreen | `screens/auth/account_confirmation_screen.dart` | عام | STATICALLY_VALID |
| 5 | `/splash` | SplashScreen | `screens/splash_screen.dart` | عام | STATICALLY_VALID |
| 6 | `/chat` | AiChatScreen | `screens/ai_chat_screen.dart` | محمي (يحتاج تسجيل دخول) | STATICALLY_VALID |
| 7 | `/home` | MainWrapper | `screens/main_wrapper.dart` | محمي | STATICALLY_VALID |
| 8 | `/main` | MainWrapper | `screens/main_wrapper.dart` | محمي (**مكرر مع /home**) | DUPLICATED |
| 9 | `/settings` | GeneralSettingsScreen | `screens/general_settings_screen.dart` | محمي | STATICALLY_VALID |
| 10 | `/api-settings` | SettingsScreen | `screens/settings_screen.dart` | محمي | STATICALLY_VALID |
| 11 | `/creator-profile` | CreatorProfileScreen | `screens/creator_profile_screen.dart` | محمي | STATICALLY_VALID |
| 12 | `/admin` | AdminDashboardScreen | `screens/admin_dashboard_screen.dart` | محمي (admin فقط) | STATICALLY_VALID |
| 13 | `/admin/users` | UsersListScreen | `screens/admin/users_list_screen.dart` | محمي (admin) | STATICALLY_VALID |
| 14 | `/edit-profile` | EditProfileScreen | `screens/auth/edit_profile_screen.dart` | محمي | STATICALLY_VALID |
| 15 | `/privacy` | PrivacyPolicyScreen | `screens/privacy_policy_screen.dart` | عام | STATICALLY_VALID |
| 16 | `/terms` | TermsOfServiceScreen | `screens/terms_of_service_screen.dart` | عام | STATICALLY_VALID |
| 17 | `/subscription` | SubscriptionScreen | `screens/subscription_screen.dart` | محمي | STATICALLY_VALID |
| 18 | `/product-photography` | ProductPhotographyScreen | `screens/product_photography_screen.dart` | محمي | STATICALLY_VALID |
| 19 | `/catalog` | ProductCatalogScreen | `screens/catalog/product_catalog_screen.dart` | محمي | STATICALLY_VALID |

### ملاحظات:
- **لا يوجد Route Guard / Middleware**: المسارات المحمية لا تُفرض الحماية عليها عبر GetX middleware. الحماية تعتمد على SplashScreen الذي يوجه المستخدم بناءً على `AuthController.isLoggedIn`.
- **مسار مكرر:** `/home` و `/main` يؤديان لنفس الشاشة `MainWrapper`.
- **شاشات بدون Route مسجل:** `WhatsappMediaSyncScreen`, `ProductFormScreen` يُفتحان عبر `Get.to()` مباشرة بدون مسار مسمى.

---

## 2. تدفقات المستخدم الرئيسية

### التدفق 1: الإقلاع وتسجيل الدخول

```
App Launch
→ main() [main.dart:44]
  → Firebase.initializeApp()
  → SupabaseConfig.initialize()
  → InitialBinding.dependencies()
  → SplashScreen [splash_screen.dart:9]
    → _initApp() [L52]
      → AuthController.isCheckingSession (polling 100ms × 30 max)
      → if (auth.isLoggedIn) → Get.offAllNamed('/home')
      → else → Get.offAllNamed('/login')
→ LoginScreen
  → email + password input
  → AuthController.login()
    → AuthService.signIn()
      → Supabase Auth (primary)
      → Firebase Auth (secondary sync)
    → FirestoreUserService.getOrCreateUser()
    → Get.offAllNamed('/home')
```

**نقاط الفشل المحتملة:**
- فشل Firebase init → `firebaseInitialized = false` → يكمل بدون Firebase
- فشل Supabase → لا يمكن تسجيل الدخول
- timeout في `_waitForAuthSession` (3 ثوانٍ) → يعتبره غير مسجل

### التدفق 2: كتالوج المنتجات

```
ProductCatalogScreen [product_catalog_screen.dart]
→ CatalogController.onInit()
  → loadProducts()
    → _db.getAllCatalogProducts() [SQLite]
    → Back4AppCatalogRepository.fetchAllProducts() [Back4App]
    → reconcile local ↔ remote
  → loadFeedUrl()
→ UI: Grid/List of products
  → Search, Filter, Sort
  → Add Product → ProductFormScreen
  → Edit Product → ProductFormScreen (with existing product)
  → Delete Product → CatalogController.deleteProduct()
  → Import Excel → CatalogController.importFromExcel()
    → CatalogXlsxImportService.parseExcelFile()
  → Export Excel → CatalogController.exportToExcel()
  → WhatsApp Sync → WhatsappMediaSyncScreen
  → Multi-select → Bulk delete/export
```

### التدفق 3: المحادثة الذكية (AI Chat)

```
AiChatScreen [ai_chat_screen.dart]
→ ChatStateService (messages, state)
→ User sends message
  → ChatBrainService.processMessage()
    → IntentClassifierService.classify()
    → AIBackendRouter.route()
      → Priority: Back4App Gateway → Firebase AI → Direct Gemini
    → Response → ChatStateService.addMessage()
→ Media attachment
  → Image: ImagePicker → upload → Gemini Vision
  → Video: VideoPicker → MediaProcessingService → analysis
  → File: FilePicker → process
```

### التدفق 4: استيراد Excel

```
CatalogController.importFromExcel()
→ FilePicker.platform.pickFiles(type: xlsx)
→ CatalogXlsxImportService.parseExcelFile()
  → Excel.decodeBytes()
  → Map headers → normalize column names
  → For each row:
    → Validate required fields (title, price)
    → Create CatalogProduct model
    → Separate: products with video → catalog, image-only → supplier drafts
  → Return (validProducts, supplierDrafts, invalidCount)
→ CatalogController
  → Save to SQLite
  → Sync to Back4App
  → Show SnackBar with stats
```

### التدفق 5: لوحة تحكم المدير (Admin)

```
AdminDashboardScreen [admin_dashboard_screen.dart]
→ AdminController
  → Load all users from Firestore
  → Load activity logs
  → Load permissions
  → Load global config
→ UI sections:
  → User management (enable/disable/delete)
  → Permission toggles
  → API key management
  → Activity monitoring
  → System health checks
```

### التدفق 6: تصوير المنتجات بالذكاء الاصطناعي

```
ProductPhotographyScreen [product_photography_screen.dart]
→ Image selection (camera/gallery/file)
→ AI Analysis:
  → VisionProductService.analyzeProduct()
  → BackgroundRemovalService.removeBackground()
  → SceneDirectorService.generateScene()
→ Result: Enhanced product photos
→ Save/Share
```

---

## 3. شاشات بدون Route مسجل (Navigator Push فقط)

| الشاشة | كيف تُفتح | الملف |
|---|---|---|
| ProductFormScreen | `Get.to(() => ProductFormScreen(...))` | `screens/catalog/product_form_screen.dart` |
| WhatsappMediaSyncScreen | `Get.to(() => WhatsappMediaSyncScreen())` | `screens/catalog/whatsapp/whatsapp_media_sync_screen.dart` |
| BrandSettingsScreen | `Get.to(() => BrandSettingsScreen())` | `screens/brand_settings_screen.dart` |

---

## 4. مسارات يمكن الوصول إليها مباشرة بدون حماية

> [!WARNING]
> لا يوجد GetX Middleware يمنع الوصول للمسارات المحمية.  
> الحماية تعتمد فقط على SplashScreen redirect.  
> إذا وصل مستخدم غير مسجل إلى `/admin` مباشرة (مثلاً عبر Deep Link)، لن يُمنع بواسطة Route Guard.
