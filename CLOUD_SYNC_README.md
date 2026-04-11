# ☁️ المزامنة السحابية والمصادقة المتقدمة (OTP)

## 📋 نظرة عامة
تم ترقية نظام المصادقة والصلاحيات ليشمل:
1. **مزامنة الصلاحيات السحابية**: حفظ واسترجاع صلاحيات المستخدمين من Firebase Firestore.
2. **المصادقة بدون كلمة مرور (OTP)**: تسجيل الدخول عبر رابط يُرسل للبريد الإلكتروني.
3. **المزامنة في الوقت الفعلي**: أي تغيير في صلاحيات المستخدم من قبل المدير ينعكس فوراً على جهاز المستخدم.

---

## 🛠️ المكونات الجديدة

### 1. `PermissionsSyncService`
خدمة مسؤولة عن مزامنة البيانات بين قاعدة البيانات المحلية (`sqflite`) والسحابية (`Firestore`).

- **syncUserPermissionsFromCloud(userId)**: تحميل الصلاحيات عند تسجيل الدخول.
- **syncPermissionToCloud(...)**: رفع تحديثات الصلاحيات للسحابة.
- **setupRealtimeSync(userId)**: الاستماع للتغييرات الفورية وتطبيقها.

### 2. تحديثات `AuthService`
- **sendOtp(email)**: إرسال رابط تسجيل الدخول (OTP Link) عبر Firebase Auth.
- **verifyOtp(email, link)**: التحقق من الرابط وإتمام تسجيل الدخول.

### 3. تحديثات `AuthController`
- دمج عملية المزامنة `_syncPermissionsAfterLogin` تلقائياً بعد أي عملية تسجيل دخول ناجحة.
- إضافة دوال `sendOtp` و `verifyOtpAndLogin` لربط الواجهة بالخدمات.

---

## 🚀 كيفية الاستخدام: تسجيل الدخول عبر OTP

### 1. إرسال الرابط
```dart
final authController = Get.find<AuthController>();
await authController.sendOtp('user@example.com');
```

### 2. استقبال الرابط والتحقق (Deep Linking)
عندما يضغط المستخدم على الرابط في بريده، سيفتح التطبيق. يجب التقاط الرابط وتمريره:

```dart
// مثال في صفحة البدء أو الـ Router
void handleDeepLink(String link) {
  if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
    // استخراج البريد (قد يحتاج لتخزينه مؤقتاً عند الإرسال)
    String savedEmail = Get.find<PreferencesService>().savedEmail; 
    
    Get.find<AuthController>().verifyOtpAndLogin(savedEmail, link);
  }
}
```

---

## 🔄 كيفية عمل المزامنة

1. **المدير** يقوم بتغيير صلاحية (مثلاً إخفاء زر) في لوحة التحكم.
2. `AdminController` يقوم بتحديث قاعدة البيانات المحلية **و** يستدعي `PermissionsSyncService` لرفع التغيير للسحابة.
3. التغيير يُحفظ في مجموعة `user_permissions` في Firestore.
4. **المستخدم** (المتصل بالإنترنت) يتلقى التحديث فوراً عبر `setupRealtimeSync`.
5. يتم تحديث قاعدة البيانات المحلية للمستخدم، وتتفاعل الواجهة تلقائياً (تخفي الزر).

---

## ⚙️ التكوين المطلوب في Firebase Console

لتفعيل هذه الميزات، تأكد من:
1. تفعيل **Email/Password** و **Email Link (Passwordless sign-in)** في تبويب Authentication.
2. إضافة Cloud Firestore وإنشاء قاعدة بيانات.
3. تكوين الـ Dynamic Links (أو App Links) لتوجيه المستخدم للتطبيق عند الضغط على الرابط.

---

## ✅ الخلاصة
أصبح التطبيق الآن يدعم:
- تسجيل دخول آمن بدون كلمات مرور (Passwordless).
- تجربة مستخدم موحدة عبر أجهزة متعددة (بفضل المزامنة السحابية).
- تحكم إداري فوري وفعّال في ميزات التطبيق عن بعد.
