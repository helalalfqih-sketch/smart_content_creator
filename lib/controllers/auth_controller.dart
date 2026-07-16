import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import '../core/storage/storage_keys.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_user_service.dart';
import '../services/permissions_sync_service.dart';
import '../core/utils/error_handler.dart';
import 'chat_history_controller.dart';
import 'permissions_controller.dart';
import '../services/secure_storage_service.dart';
import '../services/instagram_service.dart';
import '../services/tiktok_account_service.dart';
import '../core/utils/auth_validation.dart';
import 'settings_controller.dart';
import '../services/subscription_service.dart';

class AuthController extends GetxController {
  final DBService _db = Get.find<DBService>();
  final _appLinks = AppLinks();

  final AuthService _authService = Get.find<AuthService>();
  final AppStorageService _storage = Get.find<AppStorageService>();
  
  final Rxn<Map<String, dynamic>> _currentUser = Rxn<Map<String, dynamic>>();
  Rxn<Map<String, dynamic>> get rxUser => _currentUser;
  final RxBool isLoading = false.obs;
  final RxBool isCheckingSession = true.obs;
  
  final RxnString firebaseUidRx = RxnString(); // 🆕 Reactive UID for listeners
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  bool _isProcessingProfile = false;
  String? _lastProfileHash;

  // 🔑 Gemini OAuth Token (Magic UX)
  final RxString geminiAccessToken = "".obs;
  final RxnString authErrorRx = RxnString();
  final RxnString _pendingOobCode = RxnString(); // 🔑 رمز معلق لاستعادة كلمة المرور
  final RxnString _pendingLinkMode = RxnString(); // 🔑 نوع الرابط المعلق
  
  RxnString get authError => authErrorRx;
  RxnString get currentError => authErrorRx;

  void clearError() {
    authErrorRx.value = null;
  }

  Map<String, dynamic>? get user => _currentUser.value;
  bool get isLoggedIn => _currentUser.value != null;

  /// التحقق من صلاحيات الأدمن (Firestore أو Local DB)
  bool get isAdmin {
    if (_currentUser.value == null) return false;
    final user = _currentUser.value!;
    return user['firestore_role'] == 'admin' || user['role'] == 'admin';
  }

  /// التحقق من اشتراك الـ Premium
  bool get isPremium {
    if (_currentUser.value == null) return false;
    final user = _currentUser.value!;
    final result = user['isPremium'] == true || user['isPremium'] == 1;
    return result;
  }

  /// 💎 SaaS: التحقق مما إذا كان الاشتراك نشطاً فعلياً (غير منتهٍ)
  bool get isSubscriptionActive {
    if (_currentUser.value == null) return false;
    if (isAdmin) return true; // الأدمن دائماً نشط

    final user = _currentUser.value!;
    final sub = user['subscription'];
    
    if (sub == null) return isPremium; // Fallback to old field

    final status = sub['status']?.toString() ?? 'inactive';
    final int endDate = sub['endDate'] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    return status == 'active' && now < endDate;
  }

  /// الحصول على حالة الاشتراك كنص
  String get subscriptionStatus {
    if (_currentUser.value == null) return 'free';
    if (isAdmin) return 'admin';
    
    final user = _currentUser.value!;
    final sub = user['subscription'];
    if (sub == null) return isPremium ? 'premium' : 'free';

    return sub['status']?.toString() ?? 'free';
  }

  /// الحصول على معرف Firebase UID الحالي (Unified ID)
  String? get firebaseUid =>
      firebase_auth.FirebaseAuth.instance.currentUser?.uid;

  /// الحصول على البريد الإلكتروني للمستخدم الحالي
  String? get userEmail => _currentUser.value?['email'];

  @override
  void onInit() {
    super.onInit();
    // 🛡️ صيانة الهوية الشخصية الذكية (Silent Registration)
    ensureUserRegistered();
    // 🔑 Magic UX: Load saved Gemini token
    _loadSavedGeminiToken();

    // 🎧 الاستماع لحالة الفحص لتنفيذ الإجراءات المؤجلة
    ever(isCheckingSession, (bool checking) {
      if (!checking) {
        _checkPendingActions();
      }
    });
  }

  Future<void> _loadSavedGeminiToken() async {
    final token = await Get.find<SecureStorageService>().getGeminiToken();
    if (token.isNotEmpty) {
      geminiAccessToken.value = token;
    }
  }

  @override
  void onClose() {
    _userSubscription?.cancel();
    _stopPermissionsListener();
    super.onClose();
  }

  @override
  void onReady() {
    super.onReady();
    // Check if the app was opened via an email link (OTP)
    _handleIncomingLinks();
  }

  /// Check for incoming links (OTP + Instagram/TikTok OAuth Callback)
  Future<void> _handleIncomingLinks() async {
    try {
      // 1. Handle link when app is already running in background
      _appLinks.uriLinkStream.listen((uri) {
        if (_isInstagramCallback(uri)) {
          _handleInstagramCallback(uri);
        } else if (_isTikTokCallback(uri)) {
          _handleTikTokCallback(uri);
        } else {
          _processAuthLink(uri.toString());
        }
      });

      // 2. Handle link when app is started from cold
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (_isInstagramCallback(initialUri)) {
          _handleInstagramCallback(initialUri);
        } else if (_isTikTokCallback(initialUri)) {
          _handleTikTokCallback(initialUri);
        } else {
          _processAuthLink(initialUri.toString());
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Link Handling Error: $e");
    }
  }

  /// 📸 التحقق مما إذا كان الرابط هو callback لانستقرام
  bool _isInstagramCallback(Uri uri) {
    return uri.toString().contains('instagram-callback');
  }

  /// 📸 معالجة رابط رجوع انستقرام
  Future<void> _handleInstagramCallback(Uri uri) async {
    try {
      if (Get.isRegistered<InstagramService>()) {
        final instagramService = Get.find<InstagramService>();
        await instagramService.handleAuthCallback(uri);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Instagram Callback Error: $e");
    }
  }

  /// 🎵 التحقق مما إذا كان الرابط هو callback لتيك توك
  bool _isTikTokCallback(Uri uri) {
    return uri.toString().contains('tiktok-callback');
  }

  /// 🎵 معالجة رابط رجوع تيك توك
  Future<void> _handleTikTokCallback(Uri uri) async {
    try {
      if (Get.isRegistered<TikTokAccountService>()) {
        final tiktokService = Get.find<TikTokAccountService>();
        await tiktokService.handleAuthCallback(uri);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("TikTok Callback Error: $e");
    }
  }

  Future<void> _processAuthLink(String link) async {
    if (link.contains('oobCode')) {
      if (kDebugMode) debugPrint("🔗 Potential Auth Link detected: $link");

      final Uri uri = Uri.parse(link.replaceFirst('//', '/'));
      
      // محاولة استخراج المعلمات من الرابط الأصلي أو الرابط المضمن (Nested Link)
      String? oobCode = uri.queryParameters['oobCode'];
      String? mode = uri.queryParameters['mode'];
      
      if (oobCode == null && link.contains('link=')) {
        final nestedLink = uri.queryParameters['link'];
        if (nestedLink != null) {
          final nestedUri = Uri.parse(nestedLink);
          oobCode = nestedUri.queryParameters['oobCode'];
          mode = nestedUri.queryParameters['mode'];
        }
      }

      // 1. Handle Password Reset
      if (mode == 'resetPassword' && oobCode != null) {
        // 🛡️ إذا كان التطبيق لا يزال في مرحلة الفحص، نؤجل الإجراء
        if (isCheckingSession.value) {
          debugPrint("⏳ Delaying Password Reset dialog until session check completes...");
          _pendingOobCode.value = oobCode;
          _pendingLinkMode.value = mode;
        } else {
          _showNewPasswordDialog(oobCode);
        }
        return;
      }

      // 2. Handle OTP Login
      final email = _storage.read<String>(StorageKeys.otpEmail);

      if (email != null) {
        // Show loading dialog
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );

        final success = await verifyOtpAndLogin(email, link);

        if (Get.isDialogOpen ?? false) Get.back(); // Close loading dialog

        if (success) {
          Get.snackbar('تم بنجاح', 'تم تسجيل الدخول بنجاح! 🎉');
          await _storage.remove(StorageKeys.otpEmail);
        }
      } else {
        if (kDebugMode) {
          debugPrint("⚠️ Link detected but no cached email found.");
        }
      }
    }
  }

  void _checkPendingActions() {
    if (_pendingOobCode.value != null && _pendingLinkMode.value == 'resetPassword') {
      final code = _pendingOobCode.value!;
      _pendingOobCode.value = null;
      _pendingLinkMode.value = null;
      
      if (kDebugMode) debugPrint("🚀 Executing pending Password Reset action...");
      
      // تأخير بسيط إضافي لضمان انتهاء الانتقال بين الشاشات واستقرار السياق
      Future.delayed(const Duration(milliseconds: 1500), () {
        _showNewPasswordDialog(code);
      });
    }
  }

  void _showNewPasswordDialog(String oobCode) {
    if (Get.context == null) {
      debugPrint("⚠️ Cannot show New Password dialog: context is null.");
      // Retry once after a short delay if context was null
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (Get.context != null) _showNewPasswordDialog(oobCode);
      });
      return;
    }

    final newPasswordController = TextEditingController();
    
    // 🛡️ صيانة الأمان: التأكد من استقرار الواجهة قبل عرض الحوار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.context == null) return;
      
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('كلمة مرور جديدة',
                  style: GoogleFonts.cairo(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'أدخل كلمة المرور الجديدة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (newPasswordController.text.length < 6) {
                    Get.snackbar(
                        'تنبيه', 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                    return;
                  }
                  final success = await resetPassword(
                      oobCode, newPasswordController.text.trim());
                  if (success) {
                    Get.back();
                    Get.offAllNamed('/login');
                  }
                },
                child: const Text('تحديث كلمة المرور'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<bool> resetPassword(String oobCode, String newPassword) async {
    if (!await ErrorHandler.hasInternetConnection()) return false;
    isLoading.value = true;
    try {
      await _authService.confirmPasswordReset(oobCode, newPassword);
      Get.snackbar(
          'تم النجاح', 'تم تغيير كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول.');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إعادة تعيين كلمة المرور: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 🛡️ ضمان وجود هوية للمستخدم (Silent Registration)
  /// يقوم بإنشاء Anonymous UID إذا لم يكن المستخدم مسجلاً
  Future<void> ensureUserRegistered() async {
    isCheckingSession.value = true;
    try {
      var firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        if (kDebugMode) {
          debugPrint("🆕 No Firebase user found. Signing in anonymously...");
        }
        final credential = await _authService.signInAnonymously();
        firebaseUser = credential?.user;
      } else {
        if (kDebugMode) {
          debugPrint("✅ existing Firebase user: ${firebaseUser.uid}");
        }
      }

      if (firebaseUser != null) {
        final localId = firebaseUser.uid.hashCode;
        // 🚀 استعادة الهوية المحلية على الفور لضمان بقاء دور (مدير)
        final localUser = await _db.getRecord('users', where: 'id = ?', whereArgs: [localId]);

        // 1. تحديث الهوية الأساسية فوراً (بدون انتظار السحابة)
        _currentUser.value = _sanitizeUserData({
          'id': localId,
          'firestore_uid': firebaseUser.uid,
          'email': firebaseUser.email ?? "anonymous",
          'isPremium': localUser?['isPremium'] == 1 || localUser?['isPremium'] == true,
          'role': localUser?['role'] ?? 'user',
          'firestore_role': localUser?['role'] ?? 'user',
          'name': localUser?['name'] ?? localUser?['username'] ?? firebaseUser.displayName ?? 'مبدع SMART',
          'username': localUser?['username'],
          'photo_url': localUser?['photo_url'] ?? firebaseUser.photoURL ?? '',
        });
        firebaseUidRx.value = firebaseUser.uid;

        // 🚀 Fast Unlock: انطلق بمجرد معرفة الهوية
        isCheckingSession.value = false;

        // 2. مزامنة البيانات في الخلفية
        _syncRoleFromFirestore(
            firebaseUser.uid, 
            firebaseUser.email ?? "anonymous",
            name: firebaseUser.displayName,
            photoUrl: firebaseUser.photoURL,
        );
        for (var table in ['conversations', 'chat_sessions', 'chat_history', 'users']) {
          try {
            await _db.updateRecord(table, {'firebase_uid': firebaseUser.uid}, where: 'firebase_uid IS NULL', whereArgs: []);
          } catch (_) {
            // Ignore if table doesn't exist yet
          }
        }
        _syncPermissionsAfterLogin(localId.toString(),
            firebaseUid: firebaseUser.uid);
        _setupUserProfileListener(firebaseUser.uid);

        // 🧠 Managed AI: Check and Reset Credits (Background)
        unawaited(_checkCreditsInBackground(firebaseUser.uid));
      }
    } catch (e) {
      if (kDebugMode) debugPrint("EnsureUserRegistered Error: $e");
    } finally {
      // 🛡️ Failsafe: Ensure flag is lowered in all paths
      if (isCheckingSession.value) isCheckingSession.value = false;
    }
  }

  /// 🧠 مساعد لتحديث الرصيد في الخلفية دون تعطيل البداية
  Future<void> _checkCreditsInBackground(String uid) async {
    // ManagedAiService is currently disabled or integrated into UnifiedAIService
  }

  // _checkSavedSession removed (unused)

  /// تسجيل الدخول عبر البريد وكلمة المرور
  Future<bool> login(String email, String password) async {
    if (!await ErrorHandler.hasInternetConnection()) return false;
    isLoading.value = true;
    try {
      // 1. تسجيل الدخول عبر Firebase (أو الربط إذا كان مجهولاً)
      final credential = firebase_auth.EmailAuthProvider.credential(
          email: email, password: password);     
      // نستخدم linkWithCredential لضمان انتقال البيانات من الحساب المجهول إن وجد
      final userCred = await _authService.linkWithCredential(credential);
      if (userCred != null && userCred.user != null) {
        final user = userCred.user!;   
        // 🛡️ التحقق الإلزامي: هل البريد مفعل؟
        if (!user.emailVerified) {
          Get.snackbar(
            'تفعيل البريد مطلوب', 
            'يرجى فتح بريدك الإلكتروني والضغط على رابط التفعيل للموافقة على دخولك.',
            backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
            colorText: Colors.white,
            mainButton: TextButton(
              onPressed: () => resendVerificationEmail(),
              child: const Text('إعادة إرسال', style: TextStyle(color: Colors.cyanAccent)),
            ),
            duration: const Duration(seconds: 8),
          );
          // في مرحلة التطوير قد تسمح بالدخول، ولكن للأمان سنرفض الدخول
          return false; 
        }

        // 2. المزامنة والتحويل
        await _handleLoginSuccess(
          user.uid.hashCode.toString(),
          firebaseUid: user.uid,
          email: email,
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Login Error Details: $e");
      
      String message = "فشل تسجيل الدخول";
      
      // معالجة الأخطاء الشائعة لتسجيل الدخول
      if (e.toString().contains('user-not-found')) {
        message = "هذا البريد الإلكتروني غير مسجل.";
      } else if (e.toString().contains('wrong-password') || 
                 e.toString().contains('invalid-credential')) {
        message = "كلمة المرور غير صحيحة أو البيانات غير مطابقة.";
      } else if (e.toString().contains('user-disabled')) {
        message = "تم إيقاف هذا الحساب من قبل الإدارة.";
      } else if (e.toString().contains('too-many-requests')) {
        message = "تم حظر الدخول مؤقتاً بسبب محاولات كثيرة خاطئة. جرب لاحقاً.";
      } else if (e.toString().contains('invalid-email')) {
        message = "صيغة البريد الإلكتروني غير صحيحة.";
      }

      Get.snackbar(
        'خطأ في الدخول', 
        message,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.lock_person_rounded, color: Colors.orangeAccent),
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> loginWithValidation(String email, String password) async {
    clearError();
    final error = AuthValidation.validateEmail(email) ?? 
                  AuthValidation.validatePassword(password);
    if (error != null) {
      authError.value = error;
      return false;
    }
    return await login(email, password);
  }

  /// 🟢 إنشاء حساب جديد أو ترقية الحساب المجهول (Registration/Upgrade)
  Future<bool> signUp(String email, String password) async {
    if (!await ErrorHandler.hasInternetConnection()) return false;
    isLoading.value = true;
    try {
      // 1. استدعاء خدمة التسجيل (التي تتعامل مع الترقية تلقائياً)
      final userCred = await _authService.registerWithEmail(email, password);

      if (userCred != null && userCred.user != null) {
        
        // 📧 إرسال بريد التحقق فور التسجيل
        await _authService.sendEmailVerification();
        
        // تسجيل الخروج فوراً لفرض التفعيل قبل أول دخول (أمان عالي)
        await _authService.signOut();
        
        Get.snackbar(
          'خطوة أخيرة هامة', 
          'تم إنشاء الحساب بنجاح. يرجى تفعيل بريدك الإلكتروني عبر الرابط المرسل إليك لتتمكن من الدخول.',
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
          colorText: Colors.white,
          duration: const Duration(seconds: 10),
          snackPosition: SnackPosition.TOP,
          icon: const Icon(Icons.mark_email_unread_rounded, color: Colors.cyanAccent),
        );
        
        // لا نقوم باستدعاء _handleLoginSuccess هنا لكي لا يدخل المستخدم
        // بل نوجهه لشاشة تسجيل الدخول
        Get.offAllNamed('/login');
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("SignUp Error Details: $e");
      
      String message = "فشل إنشاء الهوية الرقمية";
      
      // معالجة الأكواد البرمجية لـ Firebase بشكل احترافي
      if (e.toString().contains('email-already-in-use') || 
          e.toString().contains('credential-already-in-use')) {
        message = "هذا البريد الإلكتروني مسجل مسبقاً. جرب تسجيل الدخول بدلاً من ذلك.";
      } else if (e.toString().contains('weak-password')) {
        message = "كلمة المرور ضعيفة جداً. استخدم 6 أحرف على الأقل.";
      } else if (e.toString().contains('invalid-email')) {
        message = "صيغة البريد الإلكتروني غير صحيحة.";
      } else if (e.toString().contains('network-request-failed')) {
        message = "فشل الاتصال بالخادم، تأكد من جودة الإنترنت.";
      }
      
      Get.snackbar(
        'تنبيه المصادقة', 
        message, 
        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  /// 📧 إعادة إرسال بريد التفعيل
  Future<void> resendVerificationEmail() async {
    try {
      await _authService.sendEmailVerification();
      Get.snackbar(
        'تم الإرسال', 
        'تم إرسال رابط تفعيل جديد إلى بريدك الإلكتروني.',
        backgroundColor: Colors.green.withValues(alpha: 0.2),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر إرسال البريد حالياً، حاول لاحقاً.');
    }
  }

  /// Central Logic: Sync Firestore Role -> Sync Permissions -> Reset Chat -> Redirect
  Future<void> _handleLoginSuccess(String userId,
      {String? firebaseUid, String? email}) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    
    // 1. Sync role and profile from Firestore (if Firebase user)
    if (firebaseUid != null && email != null) {
      await _syncRoleFromFirestore(
        firebaseUid, 
        email, 
        name: firebaseUser?.displayName,
        photoUrl: firebaseUser?.photoURL,
      );
      firebaseUidRx.value = firebaseUid; // Update reactive UID

      // 🗝️ Migrate local keys to the new UID
      if (Get.isRegistered<SettingsController>()) {
        await Get.find<SettingsController>().migrateKeysToNewUid(firebaseUid);
      }
    }

    // 2. Sync Permissions
    await _syncPermissionsAfterLogin(userId, firebaseUid: firebaseUid);

    // 3. Reset Conversation (Fresh Start)
    // 4. Reset Conversation (Fresh Start)
    if (Get.isRegistered<ChatHistoryController>()) {
      Get.find<ChatHistoryController>().resetConversation();
    }

    // 4. Redirect to Home (Main Dynamic Wrapper)
    // We use offAllNamed to clear stack and show bottom bar
    Get.offAllNamed('/home');

    // 5. إظهار رسالة النجاح
    Get.snackbar(
      'مرحباً بك',
      'تم تسجيل الدخول بنجاح! 🎉',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.withValues(alpha: 0.1),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(15),
      borderRadius: 15,
      icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
    );
  }

  /// Sync role from Firestore (source of truth)
  Future<void> _syncRoleFromFirestore(String firebaseUid, String email, {String? name, String? photoUrl}) async {
    try {
      if (Get.isRegistered<FirestoreUserService>()) {
        final firestoreService = Get.find<FirestoreUserService>();
        if (kDebugMode) debugPrint('🔄 Syncing role from Firestore...');

        // 1. Update Profile first if we have new data from Google/Provider
        if (name != null || photoUrl != null) {
          await firestoreService.updateUserProfile(
            uid: firebaseUid,
            data: {
              if (name != null) 'name': name,
              if (photoUrl != null) 'photo_url': photoUrl,
              'email': email,
            },
          );
        }

        // 2. SaaS: Check expiry before fetching
        await _subService.checkAndRefreshSubscription(firebaseUid);

        // 3. Get or create user in Firestore
        final cloudUser = await firestoreService.getOrCreateUser(
          uid: firebaseUid,
          email: email,
          name: name,
        );

        // Update local user object with Firestore role
        _currentUser.value = _sanitizeUserData({
          ..._currentUser.value ?? {},
          'firestore_role': cloudUser['role'],
          'role': cloudUser['role'], // Persistent Sync
          'isPremium': cloudUser['isPremium'] ?? false,
          'subscriptionStatus': cloudUser['subscriptionStatus'],
          'subscriptionExpiry': cloudUser['subscriptionExpiry'],
          'firestore_uid': firebaseUid,
        });

        // 💾 Persist to Local DB
        try {
          final localId = _currentUser.value?['id'];
          if (localId != null && localId is int) {
            await _db.updateRecord('users', {'role': cloudUser['role']}, where: 'id = ?', whereArgs: [localId]);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to persist role to SQLite: $e');
        }

        if (kDebugMode) {
          debugPrint(
              '✅ Role synced from Firestore: ${cloudUser['role']} for UID: $firebaseUid');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Firestore role sync failed: $e');
      // Default to user role if sync fails
      _currentUser.value = _sanitizeUserData({
        ..._currentUser.value ?? {},
        'firestore_role': 'user',
      });
    }
  }

  /// إعداد مستمع لبيانات المستخدم من Firestore لتحديث الـ Rx فوراً
  void _setupUserProfileListener(String uid) {
    if (_userSubscription != null) return;

    try {
      if (Get.isRegistered<FirestoreUserService>()) {
        final firestoreService = Get.find<FirestoreUserService>();
        _userSubscription = firestoreService.watchUser(uid).listen((snapshot) {
          if (_isProcessingProfile) return;
          
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            
            // 🧩 Data Hash Guard: Deduplicate profile updates
            final currentHash = data.toString().hashCode.toString();
            if (currentHash == _lastProfileHash) return;
            _lastProfileHash = currentHash;

            if (kDebugMode) debugPrint("🔄 Real-time Profile update received (Hash: $currentHash)");

            _isProcessingProfile = true;
            try {
              _currentUser.value = _sanitizeUserData({
                ..._currentUser.value ?? {},
                ...data,
                'firestore_role': data['role'],
                'isPremium': data['isPremium'] ?? false,
              });
            } finally {
              _isProcessingProfile = false;
            }
          }
        }, onError: (e) {
          if (kDebugMode) {
            debugPrint("⚠️ AuthController: User Profile Listener Error: $e");
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("⚠️ Error setting up user profile listener: $e");
      }
    }
  }

  /// 🛡️ التطهير الذكي للبيانات: يحول الحقول التي يفترض أن تكون نصوصاً ولكنها قد تأتي كـ Map
  Map<String, dynamic> _sanitizeUserData(Map<String, dynamic> rawData) {
    final sanitized = Map<String, dynamic>.from(rawData);
    
    // القائمة السوداء للهياكل المعقدة في الحقول النصية المتوقعة
    final stringFields = ['name', 'username', 'email', 'photo_url', 'cover_url', 'role', 'firestore_role', 'bio'];
    
    for (final field in stringFields) {
      if (sanitized[field] != null && sanitized[field] is! String) {
        if (kDebugMode) {
          debugPrint("⚠️ AuthController: Sanitizing field '$field' from ${sanitized[field].runtimeType} to String");
        }
        sanitized[field] = sanitized[field].toString();
      }
    }
    
    return sanitized;
  }

  /// Start permissions listener for the current user
  void _initPermissionsListener(String firebaseUid, int localId) {
    if (kDebugMode) {
      debugPrint(
          '🔑 [AuthController] _initPermissionsListener called for: $firebaseUid (Local: $localId)');
    }
    if (Get.isRegistered<PermissionsController>()) {
      final permCtrl = Get.find<PermissionsController>();
      // 1. Load from local DB for instant startup
      permCtrl.loadPermissions(localId);
      // 2. Start cloud listener for real-time updates
      permCtrl.subscribeToUserPermissions(firebaseUid);
    } else {
      if (kDebugMode) {
        debugPrint(
            '❌ [AuthController] PermissionsController NOT REGISTERED in _initPermissionsListener!');
      }
    }
  }

  /// Stop permissions listener
  void _stopPermissionsListener() {
    if (Get.isRegistered<PermissionsController>()) {
      Get.find<PermissionsController>().stopListing();
    }
  }

  /// Sync permissions after login
  Future<void> _syncPermissionsAfterLogin(String localUserId,
      {String? firebaseUid}) async {
    try {
      final String targetFirebaseUid =
          firebaseUid ?? _currentUser.value?['firestore_uid'] ?? '';

      if (targetFirebaseUid.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ Skipping permission sync: No Firebase UID available');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('🔄 Starting permissions sync for user: $targetFirebaseUid');
      }

      // 🔥 Start Real-time Listening (Modern Approach)
      final int targetLocalId =
          int.tryParse(localUserId) ?? _currentUser.value?['id'] ?? 0;

      _initPermissionsListener(targetFirebaseUid, targetLocalId);

      // 2. Sync Permissions from Cloud
      if (Get.isRegistered<PermissionsSyncService>()) {
        final syncService = Get.find<PermissionsSyncService>();
        await syncService.syncUserPermissionsFromCloud(
            targetFirebaseUid, targetLocalId);
      }

      // 3. 🛠️ Managed Key Sync (Firebase -> Local)
      if (Get.isRegistered<SettingsController>()) {
        final permCtrl = Get.find<PermissionsController>();
        if (isAdmin || permCtrl.isVisible('use_managed_keys')) {
          unawaited(Get.find<SettingsController>().syncManagedKeysToLocal());
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Permission Sync Error: $e');
    }
  }


  // --- SOCIAL LOGIN ---

  Future<void> signInWithGoogle() async {
    if (!await ErrorHandler.hasInternetConnection()) return;

    isLoading.value = true;
    try {
      // 1. الحصول على الـ Credential (بدون صلاحيات Gemini)
      final (credential, _) = await _authService.getGoogleCredential();
      if (credential == null) return;

      // 2. الربط أو تسجيل الدخول
      final userCred = await _authService.linkWithCredential(credential);

      if (userCred != null && userCred.user != null) {
        final firebaseUser = userCred.user!;
        
        // ملاحظة: حسابات Google غالباً ما تكون مفعلة تلقائياً
        // ولكن للاتساق يمكننا ترك التحقق أو تجاوزه لحسابات Google
        
        await _handleLoginSuccess(
          firebaseUser.uid.hashCode.toString(),
          firebaseUid: firebaseUser.uid,
          email: firebaseUser.email ?? 'google_user',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Google Login Error: $e");
      
      String message = "فشل تسجيل الدخول عبر Google";
      if (e.toString().contains('network-request-failed')) {
        message = "خطأ في الشبكة، تحقق من اتصالك بالإنترنت.";
      } else if (e.toString().contains('popup-closed-by-user') || 
                 e.toString().contains('canceled')) {
        message = "تم إلغاء عملية تسجيل الدخول.";
      }

      Get.snackbar(
        'خطأ Google', 
        message,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
        colorText: Colors.white,
        icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.redAccent, size: 30),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// ربط Gemini بحساب Google بشكل منفصل (Magic UX)
  Future<void> linkGeminiWithGoogle() async {
    if (!await ErrorHandler.hasInternetConnection()) return;

    isLoading.value = true;
    try {
      final token = await _authService.requestGeminiScopes();

      if (token != null && token.isNotEmpty) {
        geminiAccessToken.value = token;
        await Get.find<SecureStorageService>().saveGeminiToken(token);

        Get.snackbar("نجاح", "تم تفعيل Gemini بنجاح عبر حسابك!",
            backgroundColor: Colors.green.withValues(alpha: 0.2));
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Gemini Linkage Error: $e");
      Get.snackbar('خطأ', 'فشل ربط Gemini: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // _handleSocialLogin removed (unused)

  Future<void> logout() async {
    try {
      isLoading.value = true;
      // 🔥 Stop permissions listener
      _stopPermissionsListener();

      _currentUser.value = null;
      await _storage.remove(StorageKeys.loggedUserId);

      // Sign out from social providers too
      await _authService.signOut();

      _userSubscription?.cancel();
      Get.offAllNamed('/login');
    } catch (e) {
      if (kDebugMode) debugPrint('Logout Error: $e');
      Get.snackbar('خطأ', 'فشل تسجيل الخروج: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // --- NEW USER MANAGEMENT METHODS ---

  Future<void> refreshUser() async {
    if (user == null) return;
    final id = user!['id'] as int;
    final updatedUser = await _db.getRecord('users', where: 'id = ?', whereArgs: [id]);
    if (updatedUser != null) {
      _currentUser.value = _sanitizeUserData(updatedUser);
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? photoUrl,
    String? coverUrl,
  }) async {
    if (user == null) return false;
    final id = user!['id'] as int;
    final data = <String, dynamic>{};
    
    // 🛡️ mapping 'name' to DB column 'username'
    if (name != null) data['username'] = name;
    if (bio != null) data['bio'] = bio;
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (coverUrl != null) data['cover_url'] = coverUrl;

    if (data.isEmpty) return true;

    final result = await _db.updateRecord('users', data, where: 'id = ?', whereArgs: [id]);
    if (result > 0) {
      // 🔄 Refresh and ensure BOTH keys are present for UI compatibility
      final updatedUser = await _db.getRecord('users', where: 'id = ?', whereArgs: [id]);
      if (updatedUser != null) {
        final sanitized = _sanitizeUserData(updatedUser);
        // 🏗️ Dual-Key Stability: ensure 'name' exists in memory even if DB is 'username'
        sanitized['name'] = updatedUser['username'] ?? updatedUser['name'];
        _currentUser.value = sanitized;
        return true;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    if (!isAdmin) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'username': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'user',
          'photo_url': data['photo_url'] ?? '',
          'newUserNotification': data['newUserNotification'] ?? false,
          'createdAt': data['createdAt'],
          'bio': data['bio'] ?? '',
          'isPremium': data['isPremium'] ?? false,
          'lastSeen': data['lastSeen'],
          'subscriptionStatus': data['subscriptionStatus'] ?? 'free',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ fetchAllUsers error: $e');
      return await _db.getRecords('users', orderBy: 'created_at DESC'); // Fallback to local
    }
  }

  final SubscriptionService _subService = SubscriptionService();

  Future<bool> grantUserSubscription({
    required dynamic userId,
    required String planId,
    required int durationDays,
  }) async {
    if (!isAdmin) return false;
    try {
      if (userId is String) {
        return await _subService.grantSubscription(
          uid: userId,
          planId: planId,
          durationDays: durationDays,
          source: "admin",
        );
      }
      return false;
    } catch (e) {
      debugPrint('❌ grantUserSubscription error: $e');
      return false;
    }
  }

  Future<bool> revokeUserSubscription(dynamic userId) async {
    if (!isAdmin) return false;
    try {
      if (userId is String) {
        return await _subService.revokeSubscription(userId);
      }
      return false;
    } catch (e) {
      debugPrint('❌ revokeUserSubscription error: $e');
      return false;
    }
  }

  Future<bool> promoteToAdmin(dynamic userId) async {
    if (!isAdmin) return false;
    try {
      if (userId is String) {
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'role': 'admin'});
        return true;
      } else if (userId is int) {
        final result = await _db.updateRecord('users', {'role': 'admin'}, where: 'id = ?', whereArgs: [userId]);
        return result > 0;
      }
      return false;
    } catch (e) {
      debugPrint('❌ promoteToAdmin error: $e');
      return false;
    }
  }

  Future<bool> removeUser(dynamic userId) async {
    if (!isAdmin) return false;
    try {
      if (userId is String) {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        return true;
      } else if (userId is int) {
        final result = await _db.deleteRecord('users', where: 'id = ?', whereArgs: [userId]);
        return result > 0;
      }
      return false;
    } catch (e) {
      debugPrint('❌ removeUser error: $e');
      return false;
    }
  }

  // --- OTP Verification Methods ---

  Future<void> sendOtp(String email) async {
    if (!await ErrorHandler.hasInternetConnection()) return;
    

    isLoading.value = true;
    try {
      // PERSIST EMAIL: Firebase needs the email used to send the link to verify it on the same device
      await _storage.write(StorageKeys.otpEmail, email.trim());

      await _authService.sendOtp(email);
      Get.snackbar('نجح',
          'تم إرسال رابط التحقق إلى بريدك الإلكتروني. يرجى الضغط عليه من صندوق الوارد.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 8));
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال الرابط: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!await ErrorHandler.hasInternetConnection()) return;
    

    isLoading.value = true;
    try {
      await _authService.sendPasswordResetEmail(email);
      Get.snackbar(
          'نجح', 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.primaryColor,
          colorText: Get.theme.colorScheme.onPrimary);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال الرابط: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyOtpAndLogin(String email, String emailLink) async {
    isLoading.value = true;
    try {
      final credential = await _authService.verifyOtp(email, emailLink);

      if (credential != null && credential.user != null) {
        final firebaseUser = credential.user!;
        final userEmail = firebaseUser.email!;

        // 1. Check if user exists locally
        final localUser = await _db.getRecord('users', where: 'email = ?', whereArgs: [userEmail]);

        if (localUser != null) {
          _currentUser.value = _sanitizeUserData(localUser);
          // Save Session
          await _storage.write(StorageKeys.loggedUserId, localUser['id'] as int);

          // 🔥 Central Handler with Firebase UID
          await _handleLoginSuccess(
            localUser['id'].toString(),
            firebaseUid: firebaseUser.uid,
            email: userEmail,
          );
        } else {
          // 2. If not, create new user (auto-signup)
          // SignUp calls Login internally, which calls _handleLoginSuccess
          final password = "otp_auth_${firebaseUser.uid}";
          await signUp(userEmail, password);

          // 🔥 After signup, sync Firestore role
          final newUser = await _db.getRecord('users', where: 'email = ?', whereArgs: [userEmail]);
          if (newUser != null) {
            await _handleLoginSuccess(
              newUser['id'].toString(),
              firebaseUid: firebaseUser.uid,
              email: userEmail,
            );
          }
        }

        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("OTP Verification Error: $e");
      Get.snackbar('خطأ', 'فشل التحقق: $e');
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  /// 🔄 Refresh Gemini Token (Magic UX)
  Future<String> getFreshToken() async {
    try {
      final token = await _authService.getFreshToken();
      if (token != null && token.isNotEmpty) {
        geminiAccessToken.value = token;
        await Get.find<SecureStorageService>().saveGeminiToken(token);
        return token;
      } else {
        // Token is null or empty (Revoked/Expired)
        geminiAccessToken.value = "";
        await Get.find<SecureStorageService>().deleteGeminiToken();
        return "";
      }
    } catch (e) {
      if (kDebugMode) debugPrint("🔒 Gemini Token Refresh Failed: $e");
      // If it's a network error, we don't clear the token, just let it fail
      if (e.toString().contains('SocketException') ||
          e.toString().contains('network_error')) {
        rethrow;
      }
      geminiAccessToken.value = "";
      return "";
    }
  }

  Future<bool> signUpWithValidation(String email, String password, String confirmPassword, [String? name]) async {
    clearError();
    final error = AuthValidation.validateEmail(email) ?? 
                  AuthValidation.validatePassword(password) ??
                  AuthValidation.validateConfirmPassword(password, confirmPassword);
    if (error != null) {
      authErrorRx.value = error;
      return false;
    }
    return await signUp(email, password);
  }

  // --- Password Reset Methods (V4.0 Link-Based) ---

  Future<bool> requestPasswordResetOtp(String email) async {
    if (!await ErrorHandler.hasInternetConnection()) return false;
    isLoading.value = true;
    try {
      await _authService.requestPasswordResetOtp(email);
      
      Get.snackbar(
        'تم إرسال الرابط',
        'يرجى مراجعة بريدك الإلكتروني والضغط على الرابط لإعادة تعيين كلمة المرور.',
        backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال البريد: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Compatibility Stubs for Legacy Screens
  Future<bool> confirmPasswordResetWithOtp({required String email, required String otp, required String newPassword}) async {
    Get.snackbar('نظام جديد', 'يرجى استخدام الرابط المرسل لبريدك الإلكتروني لتغيير كلمة المرور مباشرة.');
    return false;
  }

  Future<bool> requestRegistrationOtp(String email) async {
    await _authService.sendEmailVerification();
    return true;
  }

  Future<bool> confirmRegistrationOtp({required String otp, required String email, String? password}) async {
    Get.snackbar('تنبيه', 'يرجى الضغط على رابط التفعيل المرسل لبريدك الإلكتروني بدلاً من الرمز.');
    return false;
  }
}
