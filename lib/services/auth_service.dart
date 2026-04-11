import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

// NOTE: google_sign_in is commented out because it causes compilation errors on Windows
// To enable Google Sign-In on Android/iOS:
// 1. Uncomment the import below
// 2. Uncomment the GoogleSignIn initialization and methods
// 3. Make sure you're building for Android/iOS (not Windows)
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends GetxService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Enable Google Sign-In with minimal scopes for initial login
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // 🔑 Gemini-Specific Sign-In Instance (Magic UX)
  // We keep this separate to avoid polluting the main login scopes
  final GoogleSignIn _geminiSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/generative-language'],
  );

  // 🛡️ Concurrency Guard (Lock) for silent sign-in
  Future<String?>? _ongoingTokenRefresh;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  /// الحصول على توكن جديد صامت (لـ Gemini)
  Future<String?> getFreshToken() async {
    // 🛡️ Logic: If a refresh is already in progress, wait for it
    if (_ongoingTokenRefresh != null) {
      if (kDebugMode) debugPrint("⏳ Concurrent token refresh detected. Waiting...");
      return _ongoingTokenRefresh;
    }

    _ongoingTokenRefresh = _performSilentSignIn();

    try {
      final token = await _ongoingTokenRefresh;
      return token;
    } finally {
      _ongoingTokenRefresh = null; // ✅ Reset lock
    }
  }

  /// Internal helper to perform the actual silent sign-in
  Future<String?> _performSilentSignIn() async {
    try {
      final GoogleSignInAccount? googleUser =
          await _geminiSignIn.signInSilently();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        return googleAuth.accessToken;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint("🔒 Silent Sign-In Error: $e");
      return null;
    }
  }

  /// طلب صلاحية Gemini بشكل منفصل (Magic UX)
  Future<String?> requestGeminiScopes() async {
    try {
      // ✅ Use shared instance to avoid concurrency issues
      final GoogleSignInAccount? googleUser = await _geminiSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      return googleAuth.accessToken;
    } catch (e) {
      if (kDebugMode) debugPrint("🔒 Gemini Scopes Request Error: $e");
      return null;
    }
  }

  /// الحصول على بيانات اعتماد Google (للمزامنة والربط)
  Future<(AuthCredential?, String?)> getGoogleCredential() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return (null, null);
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return (credential, googleAuth.accessToken);
    } catch (e) {
      if (kDebugMode) debugPrint("Google Auth Error: $e");
      return (null, null);
    }
  }

  /// تسجيل الدخول عبر Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final (credential, _) = await getGoogleCredential();
      if (credential == null) return null;
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      if (kDebugMode) debugPrint("❌ AuthService: Google Sign-In Error: $e");
      rethrow;
    }
  }

  /// 📧 تسجيل الدخول بالبريد وكلمة المرور
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      if (kDebugMode) debugPrint("🔐 AuthService: محاولة تسجيل الدخول لـ $email");
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("❌ AuthService: Sign-In Error: $e");
      rethrow;
    }
  }

  /// Send OTP (Email Link)
  Future<void> sendOtp(String email) async {
    try {
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url:
              'https://smartcontentcreator.page.link/login', // يجب تحديث هذا الرابط في Firebase Console
          handleCodeInApp: true,
          iOSBundleId: 'com.smartcc.ai',
          androidPackageName: 'com.smartcc.ai',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Send OTP Error (User Anonymized)");
      rethrow;
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) debugPrint("Send Password Reset Error (User Anonymized)");
      rethrow;
    }
  }

  /// 📧 إرسال بريد تفعيل الحساب
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (kDebugMode) debugPrint("📧 AuthService: تم إرسال بريد التفعيل إلى ${user.email}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ AuthService: Error sending verification email: $e");
      rethrow;
    }
  }

  /// Confirm Password Reset with oobCode
  Future<void> confirmPasswordReset(String oobCode, String newPassword) async {
    try {
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
    } catch (e) {
      if (kDebugMode) debugPrint("Confirm Password Reset Error: $e");
      rethrow;
    }
  }

  /// Verify OTP (Sign in with Email Link)
  Future<UserCredential?> verifyOtp(String email, String emailLink) async {
    try {
      if (_auth.isSignInWithEmailLink(emailLink)) {
        return await _auth.signInWithEmailLink(
          email: email,
          emailLink: emailLink,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Verify OTP Error: $e");
      rethrow;
    }
    return null;
  }

  /// تسجيل الدخول المجهول (Device-Based Identity)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      if (kDebugMode) debugPrint("Anonymous Sign-In Error: $e");
      return null;
    }
  }

  /// 🟢 إنشاء حساب جديد أو ترقية الحساب المجهول (Registration/Upgrade)
  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      User? currentUser = _auth.currentUser;

      // 🔍 السيناريو الأول: ترقية حساب مجهول (Anonymous Upgrade)
      // لضمان بقاء نفس الـ UID وبيانات Firestore والـ SQLite
      if (currentUser != null && currentUser.isAnonymous) {
        if (kDebugMode) debugPrint("🔄 AuthService: محاولة ترقية الحساب المجهول...");
        
        AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        
        try {
          return await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (linkError) {
          if (kDebugMode) debugPrint("⚠️ AuthService: فشل الربط: ${linkError.code}");
          
          // إذا كان البريد مستخدماً بالفعل، نمرر الخطأ ليتم معالجته كـ "تسجيل دخول" أو تنبيه
          if (linkError.code == 'email-already-in-use' || 
              linkError.code == 'credential-already-in-use') {
             rethrow; 
          }
          // في الحالات الأخرى، سنحاول إنشاء حساب جديد كخطة بديلة
        }
      }

      // 🆕 السيناريو الثاني: إنشاء حساب جديد تماماً
      if (kDebugMode) debugPrint("🆕 AuthService: محاولة إنشاء حساب جديد...");
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("❌ AuthService: Firebase Registration Error: $e");
      rethrow;
    }
  }

  /// ربط الحساب المجهول بحساب دائم (Account Linking)
  /// لضمان بقاء نفس الـ UID عند التسجيل بـ Google أو البريد
  Future<UserCredential?> linkWithCredential(AuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // التحقق مما إذا كان المستخدم مجهولاً أو يحتاج للربط
        if (user.isAnonymous) {
          return await user.linkWithCredential(credential);
        }

        // إذا كان المستخدم مسجلاً بالفعل، نتحقق من المزودين المرتبطين
        final isAlreadyLinked = user.providerData
            .any((info) => info.providerId == credential.providerId);

        if (isAlreadyLinked) {
          if (kDebugMode) {
            debugPrint("ℹ️ User already linked to ${credential.providerId}");
          }
          return await _auth.signInWithCredential(credential);
        }

        // محاولة ربط الحساب الحالي
        return await user.linkWithCredential(credential);
      }

      // إذا لم يوجد مستخدم مجهول، نقوم بتسجيل دخول عادي
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      if (kDebugMode) debugPrint("Account Linking Logic: $e");

      // معالجة الحالات الخاصة لـ Firebase
      if (e is FirebaseAuthException) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked') {
          if (kDebugMode) {
            debugPrint(
                "🔄 Account Linking Error (${e.code}): Switching to direct Sign-In");
          }
          return await _auth.signInWithCredential(credential);
        }
      }
      rethrow;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint("Sign Out Error: $e");
    }
  }
}
