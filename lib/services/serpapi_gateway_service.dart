import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../core/utils/ai_request_exception.dart';

/// The provider key stays on the VPS; requests use this user's Firebase session.
class SerpApiGatewayService extends GetxService {
  static const baseUrl = 'https://waha.indexesstore.com/serpapi/mobile';
  final Dio _http;
  final Future<String?> Function() _tokenReader;
  final connected = false.obs;
  final checking = false.obs;
  final statusMessage = 'اربط حساب التطبيق بخدمة البحث.'.obs;
  final hourlyLimit = 0.obs;
  final dailyLimit = 0.obs;
  StreamSubscription<User?>? _authSubscription;

  SerpApiGatewayService({Dio? client, Future<String?> Function()? tokenReader})
      : _http = client ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))),
        _tokenReader = tokenReader ?? _firebaseToken;

  static Future<String?> _firebaseToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  @override
  void onInit() {
    super.onInit();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      connected.value = false;
      statusMessage.value = 'تحقق من ربط حسابك الحالي بالخدمة.';
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  Future<Map<String, dynamic>> _request(String path,
      {Map<String, dynamic>? data, CancelToken? cancelToken}) async {
    String? token;
    try { token = await _tokenReader(); } catch (_) { /* fixed safe error below */ }
    if (token == null || token.isEmpty) {
      connected.value = false;
      throw const AiRequestException('sign_in_required', 'سجّل الدخول إلى حساب التطبيق أولاً.');
    }
    try {
      final response = await _http.request<String>('$baseUrl/$path',
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          headers: {'Authorization': 'Bearer $token'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 75),
        ),
      );
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.data ?? '');
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) { /* preserve HTTP errors before decoding */ }
      if (response.statusCode != 200) {
        if (response.statusCode == 401 || response.statusCode == 403) connected.value = false;
        throw _safeError(body?['error']?.toString(), response.statusCode);
      }
      if (body == null) throw AiRequestException.invalidResponse;
      return body;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const AiRequestException('cancelled', 'أُلغي طلب البحث.');
      }
      if (error.type == DioExceptionType.receiveTimeout) {
        throw const AiRequestException('provider_timeout', 'تأخر رد البحث. لم تُعد المحاولة تلقائيًا.');
      }
      throw const AiRequestException('connection_error', 'تعذر الاتصال بخدمة البحث. تحقق من الشبكة وحاول لاحقًا.');
    }
  }

  static AiRequestException _safeError(String? code, int? status) {
    if (status == 401) return const AiRequestException('sign_in_required', 'انتهت جلسة الدخول. سجّل الدخول مجددًا.');
    if (status == 403) return const AiRequestException('account_not_authorized', 'هذا الحساب غير مخوّل للخدمة. استخدم حساب المدير ببريد موثّق أو اطلب تفعيل حسابك.');
    if (status == 404) return const AiRequestException('gateway_not_ready', 'ربط SerpApi لم يُفعّل على الخادم بعد.');
    if (status == 429) return const AiRequestException('serpapi_quota', 'بلغت حد البحث المتاح. انتظر تجدد الحد أو راجع رصيد SerpApi.');
    if (code == 'provider_credentials') return const AiRequestException('provider_credentials', 'الخادم يحتاج إلى مراجعة مفتاح SerpApi.');
    if (code == 'provider_timeout') return const AiRequestException('provider_timeout', 'تأخر رد Google AI Mode. لم تُعد المحاولة تلقائيًا.');
    if (code == 'provider_empty_answer' || code == 'provider_search_failed') return const AiRequestException('provider_empty_answer', 'لم يرجع Google AI Mode إجابة لهذا البحث. جرّب صياغة أخرى.');
    if (status == 400) return const AiRequestException('invalid_search', 'صيغة البحث غير صالحة أو النص طويل جدًا.');
    return const AiRequestException('serpapi_unavailable', 'تعذر الاتصال بخدمة البحث حاليًا.');
  }

  Future<bool> connect() async {
    if (checking.value) return false;
    checking.value = true;
    try {
      final body = await _request('status');
      if (body['status'] != 'authorized' || body['engine'] != 'google_ai_mode') throw AiRequestException.invalidResponse;
      connected.value = true;
      final limits = body['limits'];
      if (limits is Map) {
        hourlyLimit.value = (limits['hourly'] as num?)?.toInt() ?? 0;
        dailyLimit.value = (limits['daily'] as num?)?.toInt() ?? 0;
      }
      statusMessage.value = 'تم ربط الحساب بالخادم. أصبح البحث متاحًا من المحادثة.';
      return true;
    } on AiRequestException catch (error) {
      connected.value = false;
      statusMessage.value = error.message;
      return false;
    } catch (_) {
      connected.value = false;
      statusMessage.value = 'تعذر التحقق من الربط حاليًا.';
      return false;
    } finally { checking.value = false; }
  }

  Future<Map<String, dynamic>> search(String query,
      {String hl = 'ar', String? gl, String? subsequentRequestToken, CancelToken? cancelToken}) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 4000) throw const AiRequestException('invalid_search', 'اكتب بحثًا من 1 إلى 4000 حرف.');
    return _request('ai-mode', data: {
      'q': text, 'hl': hl,
      if (gl != null) 'gl': gl,
      if (subsequentRequestToken != null) 'subsequent_request_token': subsequentRequestToken,
    }, cancelToken: cancelToken);
  }
}
