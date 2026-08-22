import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'firebase_ai_logic_service.dart';
import 'back4app_gateway_service.dart';
import 'manus_ai_service.dart';
import '../core/models/canonical_ai_request.dart';
import '../core/models/manus_media_models.dart';
import '../controllers/chat_history_controller.dart';

/// 🎯 AIBackendRouter - نقطة الدخول الموحدة لجميع طلبات الذكاء الاصطناعي
///
/// يقرأ حقل `ai_backend` من Firestore للمستخدم الحالي ويوجه الطلب إلى:
/// - `"firebase_ai"` → FirebaseAiLogicService (Firebase AI Logic SDK)
/// - `"backend"` → Back4AppGatewayService (Cloud Code Proxy)
/// - `"manus"` → ManusAiService (Manus API v2 Gateway)
class AIBackendRouter extends GetxService {
  /// القيمة الافتراضية لمسار الذكاء الاصطناعي
  static const String defaultBackend = 'firebase_ai';

  /// القيم المسموحة
  static const List<String> validBackends = ['firebase_ai', 'backend', 'manus'];

  /// 🏊‍♂️ أحواض الحصص (Quota Pools)
  /// يمنع استهلاك محاولات فاشلة على نفس الحصة عند نفاذ الرصيد
  static const Map<String, String> quotaPools = {
    'firebase_ai': 'gemini_primary',
    'backend': 'gemini_primary',
    'manus': 'manus',
  };

  /// مسار المستخدم الحالي (يُحدَّث لحظياً من Firestore)
  final RxString currentBackend = defaultBackend.obs;

  /// الاشتراك في تحديثات Firestore لحظياً
  Stream<DocumentSnapshot>? _userDocStream;

  /// 🔒 معرف المستخدم الحالي بأمان
  String? get currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// 🔄 تبديل مسار الذكاء الاصطناعي وتحديثه في Firestore
  Future<bool> switchBackend(String newBackend) async {
    if (!validBackends.contains(newBackend)) return false;
    currentBackend.value = newBackend;

    final uid = currentUserId;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'ai_backend': newBackend,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          debugPrint('✅ AIBackendRouter: Backend switched to $newBackend');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ AIBackendRouter: Error updating backend in Firestore: $e');
        }
      }
    }
    return true;
  }

  String _redactUserId(String? uid) {
    if (uid == null || uid.isEmpty) return 'anonymous';
    if (uid.length <= 6) return '***';
    return '${uid.substring(0, 3)}...${uid.substring(uid.length - 3)}';
  }

  /// 🔄 تهيئة المراقبة اللحظية لمسار المستخدم
  void startListening() {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      _userDocStream =
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

      _userDocStream!.listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          final backend = data?['ai_backend']?.toString() ?? defaultBackend;
          if (validBackends.contains(backend)) {
            currentBackend.value = backend;
            if (kDebugMode) {
              debugPrint(
                  '🎯 AIBackendRouter: User backend updated to: $backend');
            }
          }
        }
      }, onError: (e) {
        if (kDebugMode) {
          debugPrint('⚠️ AIBackendRouter: Error listening to user doc: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ AIBackendRouter.startListening error: $e');
      }
    }
  }

  /// 🧠 الحصول على مسار المستخدم الحالي من Firestore (استعلام مباشر)
  Future<String> resolveBackend() async {
    try {
      final uid = currentUserId;
      if (uid == null) {
        debugPrint(
            '[AI_ROUTER_DIAG] resolveBackend: uid=null resolved=$defaultBackend reason=no_auth_user');
        return defaultBackend;
      }

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        debugPrint(
            '[AI_ROUTER_DIAG] resolveBackend: uid=${_redactUserId(uid)} raw_firestore_value=<doc_not_found> resolved=$defaultBackend reason=user_doc_missing');
        return defaultBackend;
      }

      final rawValue = doc.data()?['ai_backend']?.toString();
      final backend = rawValue ?? defaultBackend;
      final resolved =
          validBackends.contains(backend) ? backend : defaultBackend;
      final reason = rawValue == null
          ? 'field_missing_using_default'
          : (validBackends.contains(backend)
              ? 'firestore_user_pref'
              : 'invalid_value_using_default');

      debugPrint(
          '[AI_ROUTER_DIAG] resolveBackend: uid=${_redactUserId(uid)} raw_firestore_value=$rawValue resolved=$resolved reason=$reason');

      return resolved;
    } catch (e) {
      debugPrint(
          '[AI_ROUTER_DIAG] resolveBackend: error=$e resolved=${currentBackend.value} reason=exception_fallback');
      return currentBackend.value;
    }
  }

  // ──────────────────────────────────────────────────────
  // ⏱️ Rate Limiting, Cooldown & Backoff Queue
  // ──────────────────────────────────────────────────────

  /// تتبع أوقات الانتظار لكل مزود (Cooldown Timers)
  final Map<String, DateTime> _cooldowns = {};

  /// هل المزود حالياً في فترة تهدئة (429 Rate Limit Cooldown)
  bool isBackendCoolingDown(String backend) {
    final expiry = _cooldowns[backend];
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// عدد الثواني المتبقية لانتهاء فترة التهدئة
  int remainingCooldownSeconds(String backend) {
    final expiry = _cooldowns[backend];
    if (expiry == null) return 0;
    final diff = expiry.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// استخراج مدة الانتظار من نص الخطأ (Retry-After parser)
  static Duration parseRetryDuration(String errorMessage) {
    final matchSeconds =
        RegExp(r'retry\s+in\s+([\d\.]+)\s*s', caseSensitive: false)
            .firstMatch(errorMessage);
    if (matchSeconds != null) {
      final sec = double.tryParse(matchSeconds.group(1) ?? '10') ?? 10.0;
      return Duration(milliseconds: ((sec + 0.5) * 1000).toInt());
    }

    final matchSecWord = RegExp(r'([\d\.]+)\s*seconds?', caseSensitive: false)
        .firstMatch(errorMessage);
    if (matchSecWord != null) {
      final sec = double.tryParse(matchSecWord.group(1) ?? '15') ?? 15.0;
      return Duration(milliseconds: ((sec + 0.5) * 1000).toInt());
    }

    return const Duration(seconds: 15);
  }

  /// فحص هل الخطأ ناتج عن تجاوز الحصة أو Rate Limit
  static bool isRateLimitError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();

    // 🛡️ حماية حتمية: عدم اعتبار أخطاء App Check أو Auth أو 401/403 كأخطاء Rate Limit لمنع الـ fallback الخاطئ
    if (lower.contains('app check') ||
        lower.contains('app_check') ||
        lower.contains('appcheck') ||
        lower.contains('attestation') ||
        lower.contains('unauthenticated') ||
        lower.contains('unauthorized') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('permission_denied') ||
        lower.contains('permission denied')) {
      return false;
    }

    return lower.contains('429') ||
        lower.contains('quota exceeded') ||
        lower.contains('rate limit') ||
        lower.contains('too many attempts') ||
        lower.contains('resource_exhausted') ||
        lower.contains('please retry in');
  }

  /// تسجيل فترة انتظار لمزود معين
  void recordCooldown(String backend, Duration duration) {
    _cooldowns[backend] = DateTime.now().add(duration);
    if (kDebugMode) {
      debugPrint(
          '⏱️ [AI_ROUTER] Backend $backend enters cooldown for ${duration.inSeconds}s');
    }
  }

  /// أقصى مدة انتظار تلقائي داخل التطبيق لتجنب تعليق الواجهة (4 ثوانٍ)
  static const int maxAutoWaitSeconds = 4;

  /// تنفيذ الطلب مع حماية ذكية من 429 واستجابة فورية دون تجميد الواجهة
  Future<Map<String, dynamic>> _executeWithRateLimitGuard({
    required String backend,
    required Future<Map<String, dynamic>> Function() requestAction,
    bool autoRetry = true,
  }) async {
    // 1️⃣ إذا كان المزود في فترة انتظار طويلة (> 4 ثوانٍ)، نرجع فوراً لمنع تعليق التطبيق
    if (isBackendCoolingDown(backend)) {
      final remaining = remainingCooldownSeconds(backend);
      if (remaining > maxAutoWaitSeconds) {
        debugPrint(
            '⚡ [AI_ROUTER] Backend $backend in long cooldown ($remaining s). Returning fast response.');
        return {
          'success': false,
          'error':
              'الخادم تحت ضغط مؤقت. يرجى الانتظار $remaining ثانية أو التبديل للمحرك الآخر ⚡',
          'retry_after': remaining,
          'is_throttled': true,
          'meta': {'provider': backend, 'status': 'throttled'},
        };
      } else if (remaining > 0) {
        // انتظار قصير جداً (أقل من 4 ثوانٍ) فقط
        debugPrint('⏱️ [AI_ROUTER] Short wait ($remaining s) for $backend...');
        await Future.delayed(Duration(seconds: remaining));
      }
    }

    // 2️⃣ تنفيذ الطلب
    final result = await requestAction();

    // 3️⃣ فحص النتيجة ومعالجة أي 429
    if (result['success'] != true) {
      final errorMsg = result['error']?.toString() ?? '';
      if (isRateLimitError(errorMsg)) {
        final retryDuration = parseRetryDuration(errorMsg);
        recordCooldown(backend, retryDuration);

        // 4️⃣ إعادة المحاولة فقط إذا كانت المدة قصيرة جداً (<= 4 ثوانٍ)
        if (autoRetry && retryDuration.inSeconds <= maxAutoWaitSeconds) {
          debugPrint(
              '🔄 [AI_ROUTER] Fast auto-retry $backend in ${retryDuration.inSeconds}s...');
          await Future.delayed(retryDuration);
          return await requestAction();
        } else {
          return {
            'success': false,
            'error':
                'الخادم تحت ضغط مؤقت. يرجى الانتظار ${retryDuration.inSeconds} ثانية أو التبديل للمحرك الآخر ⚡',
            'retry_after': retryDuration.inSeconds,
            'is_throttled': true,
            'meta': {'provider': backend, 'status': 'throttled'},
          };
        }
      }
    }

    return result;
  }

  /// 🔀 تفعيل التبديل التلقائي الذكي بين المحركات عند حدوث ضغط (429 Rate Limit)
  static bool enableAutoFailover = true;

  /// 🔍 البحث عن محرك بديل من حوض حصة (Quota Pool) مستقل غير متأثر بالضغط
  String? findFailoverBackend(String failedBackend) {
    final failedPool = quotaPools[failedBackend] ?? failedBackend;
    // 1. محاولة اختيار محرك من حوض حصة مختلف أولاً
    for (final candidate in validBackends) {
      if (candidate == failedBackend) continue;
      final candidatePool = quotaPools[candidate] ?? candidate;
      if (candidatePool != failedPool && !isBackendCoolingDown(candidate)) {
        return candidate;
      }
    }
    // 2. إذا لم يتوفر، اختيار أي محرك متاح ليس في فترة تهدئة
    for (final candidate in validBackends) {
      if (candidate != failedBackend && !isBackendCoolingDown(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// 🛡️ التحقق من أخطاء الأمان أو App Check / Auth لمنع التراجع غير الصحيح
  static bool isAppCheckOrAuthError(String? error) {
    if (error == null) return false;
    final lower = error.toLowerCase();
    return lower.contains('app_check') ||
        lower.contains('appcheck') ||
        lower.contains('attestation') ||
        lower.contains('firebase_app_check') ||
        lower.contains('auth_error') ||
        lower.contains('permission_denied') ||
        lower.contains('unauthenticated') ||
        lower.contains('401') ||
        lower.contains('403');
  }

  Future<Map<String, dynamic>> _executeTextRoute({
    required String backend,
    required String prompt,
    List<Map<String, String>>? history,
    String? image,
    String? mimeType,
    int maxTokens = 2048,
    double temperature = 0.7,
    bool isModificationMode = false,
    String? systemPersona,
    String? templateId,
    Map<String, Object?>? templateInputs,
  }) {
    if (backend == 'firebase_ai') {
      return _routeToFirebaseAi(
        prompt: prompt,
        history: history,
        maxTokens: maxTokens,
        temperature: temperature,
        isModificationMode: isModificationMode,
        systemPersona: systemPersona,
        templateId: templateId,
        templateInputs: templateInputs,
      );
    } else if (backend == 'manus') {
      return _routeToManus(
        prompt: prompt,
        history: history,
        maxTokens: maxTokens,
        temperature: temperature,
        systemPersona: systemPersona,
      );
    } else {
      return _routeToBackend(
        prompt: prompt,
        history: history,
        image: image,
        mimeType: mimeType,
        maxTokens: maxTokens,
        temperature: temperature,
      );
    }
  }

  Future<Map<String, dynamic>> _executeVisionRoute({
    required String backend,
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) {
    if (backend == 'firebase_ai') {
      return _routeVisionToFirebaseAi(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
    } else if (backend == 'manus') {
      return _routeVisionToManus(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
    } else {
      return _routeVisionToBackend(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
    }
  }

  /// 💬 توليد نص (نقطة الدخول الرئيسية مع التبديل التلقائي الذكي)
  Future<Map<String, dynamic>> generateText({
    required String prompt,
    List<Map<String, String>>? history,
    String? image,
    String? mimeType,
    int maxTokens = 2048,
    double temperature = 0.7,
    bool isModificationMode = false,
    String? systemPersona,
    String? templateId,
    Map<String, Object?>? templateInputs,
    bool autoRetry = true,
  }) async {
    final uid = currentUserId;
    final backend = await resolveBackend();
    final redactedId = _redactUserId(uid);

    debugPrint(
        '[AI_ROUTER] operation=text selected=$backend reason=firestore_user_pref userId=$redactedId cooldown_active=${isBackendCoolingDown(backend)}');

    final result = await _executeWithRateLimitGuard(
      backend: backend,
      autoRetry: autoRetry,
      requestAction: () => _executeTextRoute(
        backend: backend,
        prompt: prompt,
        history: history,
        image: image,
        mimeType: mimeType,
        maxTokens: maxTokens,
        temperature: temperature,
        isModificationMode: isModificationMode,
        systemPersona: systemPersona,
        templateId: templateId,
        templateInputs: templateInputs,
      ),
    );

    // 🔀 Smart Auto-Failover: إذا فشل المحرك الأساسي بسبب الحصة (وليس Auth/App Check)، نتحول فوراً لمحرّك من حوض حصة مستقل
    if (enableAutoFailover &&
        result['success'] != true &&
        !isAppCheckOrAuthError(result['error']?.toString()) &&
        (result['is_throttled'] == true ||
            isRateLimitError(result['error']?.toString()))) {
      final fallbackBackend = findFailoverBackend(backend);
      if (fallbackBackend != null && !isBackendCoolingDown(fallbackBackend)) {
        debugPrint(
            '🔀 [AI_ROUTER] Backend $backend throttled. Seamlessly failing over text request to $fallbackBackend (quota_pool=${quotaPools[fallbackBackend]})...');
        return _executeTextRoute(
          backend: fallbackBackend,
          prompt: prompt,
          history: history,
          image: image,
          mimeType: mimeType,
          maxTokens: maxTokens,
          temperature: temperature,
          isModificationMode: isModificationMode,
          systemPersona: systemPersona,
          templateId: templateId,
          templateInputs: templateInputs,
        );
      }
    }

    return result;
  }

  /// 📸 تحليل صورة منتج عبر File
  Future<Map<String, dynamic>> analyzeImage({
    required File image,
    required String prompt,
    String mimeType = 'image/jpeg',
    bool autoRetry = true,
  }) async {
    final bytes = await image.readAsBytes();
    return analyzeProductVision(
      prompt: prompt,
      imageBytes: bytes,
      mimeType: mimeType,
      autoRetry: autoRetry,
    );
  }

  // ──────────────────────────────────────────────────────
  // 🗜️ Image Optimization for Vision
  // ──────────────────────────────────────────────────────

  /// حد الحجم الأدنى للضغط (500 كيلوبايت)
  static const int _compressionThresholdBytes = 500 * 1024;

  /// أقصى أبعاد للصورة المرسلة للنموذج
  static const int _maxVisionDimension = 1024;

  /// جودة الضغط (80% كافية تماماً لتحليل المنتجات)
  static const int _visionCompressionQuality = 80;

  /// 🗜️ ضغط الصورة قبل إرسالها للنموذج لتسريع الاستجابة
  /// الصور الأصغر من 500KB لا تُضغط. الأكبر تُصغّر إلى 1024px بجودة 80%.
  Future<Uint8List> _optimizeImageForVision(Uint8List imageBytes) async {
    final originalKB = imageBytes.lengthInBytes ~/ 1024;

    if (imageBytes.lengthInBytes < _compressionThresholdBytes) {
      debugPrint(
          '[AI_ROUTER] 🗜️ Image already small (${originalKB}KB), skipping compression');
      return imageBytes;
    }

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: _maxVisionDimension,
        minHeight: _maxVisionDimension,
        quality: _visionCompressionQuality,
        format: CompressFormat.jpeg,
      );

      final compressedKB = compressed.lengthInBytes ~/ 1024;
      final savedPercent =
          ((1 - compressed.lengthInBytes / imageBytes.lengthInBytes) * 100)
              .toStringAsFixed(0);
      debugPrint(
          '[AI_ROUTER] 🗜️ Image optimized: ${originalKB}KB → ${compressedKB}KB (-$savedPercent%)');

      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint(
          '[AI_ROUTER] ⚠️ Image compression failed, using original (${originalKB}KB): $e');
      return imageBytes;
    }
  }

  /// 📸 تحليل صورة منتج (نقطة الدخول الرئيسية مع التبديل التلقائي الذكي)
  Future<Map<String, dynamic>> analyzeProductVision({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    bool autoRetry = true,
  }) async {
    // 🗜️ ضغط الصورة لتسريع الرفع والمعالجة
    final optimizedBytes = await _optimizeImageForVision(imageBytes);

    final uid = currentUserId;
    final backend = await resolveBackend();
    final redactedId = _redactUserId(uid);

    debugPrint(
        '[AI_ROUTER] operation=vision selected=$backend reason=firestore_user_pref userId=$redactedId cooldown_active=${isBackendCoolingDown(backend)}');

    final result = await _executeWithRateLimitGuard(
      backend: backend,
      autoRetry: autoRetry,
      requestAction: () => _executeVisionRoute(
        backend: backend,
        prompt: prompt,
        imageBytes: optimizedBytes,
        mimeType: 'image/jpeg',
      ),
    );

    // 🔀 Smart Auto-Failover: إذا فشل المحرك الأساسي بسبب الحصة (وليس Auth/App Check)، نتحول فوراً لمحرّك من حوض حصة مستقل
    if (enableAutoFailover &&
        result['success'] != true &&
        !isAppCheckOrAuthError(result['error']?.toString()) &&
        (result['is_throttled'] == true ||
            isRateLimitError(result['error']?.toString()))) {
      final fallbackBackend = findFailoverBackend(backend);
      if (fallbackBackend != null && !isBackendCoolingDown(fallbackBackend)) {
        debugPrint(
            '🔀 [AI_ROUTER] Backend $backend vision throttled. Seamlessly failing over vision request to $fallbackBackend (quota_pool=${quotaPools[fallbackBackend]})...');
        return _executeVisionRoute(
          backend: fallbackBackend,
          prompt: prompt,
          imageBytes: optimizedBytes,
          mimeType: 'image/jpeg',
        );
      }
    }

    return result;
  }

  // ──────────────────────────────────────────────────────
  // 🟣 Firebase AI Logic Routes
  // ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _routeToFirebaseAi({
    required String prompt,
    List<Map<String, String>>? history,
    int maxTokens = 2048,
    double temperature = 0.7,
    bool isModificationMode = false,
    String? systemPersona,
    String? templateId,
    Map<String, Object?>? templateInputs,
  }) async {
    debugPrint('[FIREBASE_AI] operation=text status=start');
    try {
      if (!Get.isRegistered<FirebaseAiLogicService>()) {
        Get.put(FirebaseAiLogicService());
      }
      final service = Get.find<FirebaseAiLogicService>();
      final result = await service.generateText(
        prompt: prompt,
        history: history,
        maxTokens: maxTokens,
        temperature: temperature,
        isModificationMode: isModificationMode,
        systemPersona: systemPersona,
        templateId: templateId,
        templateInputs: templateInputs,
      );

      if (result['success'] == true) {
        debugPrint('[FIREBASE_AI] operation=text status=success');
      } else {
        debugPrint('[FIREBASE_AI] operation=text status=error');
      }
      return result;
    } catch (e) {
      debugPrint('[FIREBASE_AI] operation=text status=error');
      return {
        'success': false,
        'error': e.toString(),
        'meta': {'provider': 'firebase_ai_logic', 'status': 'error'},
      };
    }
  }

  Future<Map<String, dynamic>> _routeVisionToFirebaseAi({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    debugPrint('[FIREBASE_AI] operation=vision status=start');
    try {
      if (!Get.isRegistered<FirebaseAiLogicService>()) {
        Get.put(FirebaseAiLogicService());
      }
      final service = Get.find<FirebaseAiLogicService>();
      final result = await service.analyzeProductVision(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );

      if (result['success'] == true) {
        debugPrint('[FIREBASE_AI] operation=vision status=success');
      } else {
        debugPrint('[FIREBASE_AI] operation=vision status=error');
      }
      return result;
    } catch (e) {
      debugPrint('[FIREBASE_AI] operation=vision status=error');
      return {
        'success': false,
        'error': e.toString(),
        'meta': {'provider': 'firebase_ai_logic', 'status': 'error'},
      };
    }
  }

  // ──────────────────────────────────────────────────────
  // 🌐 Backend Gateway Routes (Back4App / Vertex)
  // ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _routeToBackend({
    required String prompt,
    List<Map<String, String>>? history,
    String? image,
    String? mimeType,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    debugPrint('[BACKEND_AI] operation=text status=start');
    if (!Get.isRegistered<Back4AppGatewayService>()) {
      debugPrint('[BACKEND_AI] operation=text status=error');
      return {
        'success': false,
        'error': 'Back4AppGatewayService not registered',
        'meta': {'provider': 'backend', 'status': 'error'},
      };
    }
    try {
      final service = Get.find<Back4AppGatewayService>();
      final result = await service.generateTextWithVertex(
        prompt,
        history: history,
        image: image,
        mimeType: mimeType,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      if (result.description.isNotEmpty) {
        debugPrint('[BACKEND_AI] operation=text status=success');
        return {
          'success': true,
          'data': result.description,
          'meta': {
            'provider': result.provider,
            'status': 'active',
          },
        };
      } else {
        debugPrint('[BACKEND_AI] operation=text status=error');
        return {
          'success': false,
          'error': 'Empty response from backend',
          'meta': {'provider': 'backend', 'status': 'error'},
        };
      }
    } catch (e) {
      debugPrint('❌ [BACKEND_AI] Text Error details: $e');
      debugPrint('[BACKEND_AI] operation=text status=error');
      return {
        'success': false,
        'error': e.toString(),
        'meta': {'provider': 'backend', 'status': 'error'},
      };
    }
  }

  Future<Map<String, dynamic>> _routeVisionToBackend({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    debugPrint('[BACKEND_AI] operation=vision status=start');
    if (!Get.isRegistered<Back4AppGatewayService>()) {
      debugPrint('[BACKEND_AI] operation=vision status=error');
      return {
        'success': false,
        'error': 'Back4AppGatewayService not registered',
        'meta': {'provider': 'backend', 'status': 'error'},
      };
    }
    try {
      final service = Get.find<Back4AppGatewayService>();
      final imageBase64 = base64Encode(imageBytes);
      final result = await service.generateTextWithVertex(
        prompt,
        image: imageBase64,
        mimeType: mimeType,
      );

      if (result.description.isNotEmpty) {
        debugPrint('[BACKEND_AI] operation=vision status=success');
        return {
          'success': true,
          'data': result.description,
          'meta': {
            'provider': result.provider,
            'status': 'active',
          },
        };
      } else {
        debugPrint('[BACKEND_AI] operation=vision status=error');
        return {
          'success': false,
          'error': 'Empty response from backend',
          'meta': {'provider': 'backend', 'status': 'error'},
        };
      }
    } catch (e) {
      debugPrint('❌ [BACKEND_AI] Vision Error details: $e');
      debugPrint('[BACKEND_AI] operation=vision status=error');
      return {
        'success': false,
        'error': e.toString(),
        'meta': {'provider': 'backend', 'status': 'error'},
      };
    }
  }

  // ──────────────────────────────────────────────────────
  // 🤖 Manus API v2 Gateway Routes
  // ──────────────────────────────────────────────────────

  /// 🔗 Resolve the current app session ID for Manus task continuity.
  /// Reads from ChatHistoryController so callers don't need to thread it.
  int? get _currentAppSessionId {
    try {
      if (Get.isRegistered<ChatHistoryController>()) {
        return Get.find<ChatHistoryController>().currentSessionId.value;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _routeToManus({
    required String prompt,
    List<Map<String, String>>? history,
    int maxTokens = 2048,
    double temperature = 0.7,
    String? systemPersona,
  }) async {
    if (!Get.isRegistered<ManusAiService>()) {
      Get.put(ManusAiService());
    }
    final service = Get.find<ManusAiService>();
    final request = CanonicalAiRequest(
      prompt: prompt,
      appSessionId: _currentAppSessionId,
      systemPersona: systemPersona,
      history: history,
      maxTokens: maxTokens,
      temperature: temperature,
      taskType: 'text',
    );
    return await service.generateText(request);
  }

  Future<Map<String, dynamic>> _routeVisionToManus({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (!Get.isRegistered<ManusAiService>()) {
      Get.put(ManusAiService());
    }
    final service = Get.find<ManusAiService>();
    final request = CanonicalAiRequest(
      prompt: prompt,
      appSessionId: _currentAppSessionId,
      imageBytes: imageBytes,
      mimeType: mimeType,
      taskType: 'vision',
    );
    return await service.analyzeVision(request);
  }

  // ──────────────────────────────────────────────────────
  // 🎨 MEDIA GENERATION — MANUS ONLY (Correction #11)
  // ──────────────────────────────────────────────────────
  // No silent fallback to Stability/Kling/Higgsfield/Gemini.
  // If ai_backend != 'manus', return explicit error.

  /// 🎨 Submit a media generation task (image/video/product_photo/etc)
  /// Returns ManusGatewayResponse with task_id for async polling.
  /// Correction #5: No synchronous media waits.
  /// Correction #11: MANUS ONLY — no fallback.
  Future<ManusGatewayResponse> submitMediaTask({
    required String prompt,
    required String taskType,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
    String? systemPersona,
  }) async {
    final backend = await resolveBackend();
    final redactedId = _redactUserId(currentUserId);

    debugPrint(
        '[AI_ROUTER] operation=media_$taskType selected=$backend userId=$redactedId');

    // Correction #11: Media generation is MANUS ONLY
    if (backend != 'manus') {
      debugPrint(
          '[AI_ROUTER] ERROR: Media generation requires Manus backend. Current: $backend');
      return ManusGatewayResponse(
        success: false,
        error: 'توليد الوسائط يتطلب تفعيل محرك Manus. '
            'يرجى تفعيل Manus من إعدادات الذكاء الاصطناعي.',
      );
    }

    if (!Get.isRegistered<ManusAiService>()) {
      Get.put(ManusAiService());
    }
    final service = Get.find<ManusAiService>();

    final request = CanonicalAiRequest(
      prompt: prompt,
      appSessionId: _currentAppSessionId,
      systemPersona: systemPersona,
      imageBytes: imageBytes,
      mimeType: mimeType,
      taskType: taskType,
    );

    return await service.submitMediaTask(request, taskType: taskType);
  }

  /// 🔄 Poll task status (delegates to ManusAiService)
  /// Correction #7: Flutter polls Back4App, never Manus directly.
  Future<ManusTaskStatus> pollMediaTaskStatus(String taskId) async {
    if (!Get.isRegistered<ManusAiService>()) {
      Get.put(ManusAiService());
    }
    return await Get.find<ManusAiService>().pollTaskStatus(taskId);
  }

  /// 🔄 Poll until media task completes (with status callbacks)
  /// Correction #4: Real Manus status_update text, NO fake percentages.
  /// Correction #8: Caller maintains ONE placeholder message.
  Future<ManusTaskStatus> pollMediaUntilComplete(
    String taskId, {
    void Function(ManusTaskStatus status)? onStatusUpdate,
  }) async {
    if (!Get.isRegistered<ManusAiService>()) {
      Get.put(ManusAiService());
    }
    return await Get.find<ManusAiService>().pollUntilComplete(
      taskId,
      onStatusUpdate: onStatusUpdate,
    );
  }
}

