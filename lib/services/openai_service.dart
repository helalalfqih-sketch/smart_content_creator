import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'ai_provider.dart';
import '../core/models/api_provider.dart';
import '../core/utils/vision_image.dart';

/// OpenAI-compatible text and vision requests, including OpenRouter.
class OpenAIService extends AIProvider {
  final dio.Dio _dio;
  final String? baseUrl;
  final String defaultModel;
  final List<String> providerOnly;
  final bool allowProviderFallbacks;

  OpenAIService({
    this.baseUrl,
    this.defaultModel = 'gpt-4o',
    this.providerOnly = const [],
    this.allowProviderFallbacks = true,
    dio.Dio? client,
  }) : _dio =
           client ??
           dio.Dio(
             dio.BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 120),
             ),
           );

  Future<AiResult> _complete(
    Object content, {
    required String apiKey,
    List<Map<String, String>>? history,
    int? maxTokens,
    String? systemPersona,
    dio.CancelToken? cancelToken,
    String? customEndpoint,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('❌ 401: أضف مفتاح الخدمة من الإعدادات أولاً.');
    }
    final endpoint = (customEndpoint ?? baseUrl ?? 'https://api.openai.com/v1')
        .replaceFirst(RegExp(r'/+$'), '');
    final url = '$endpoint/chat/completions';
    final isOpenRouter = Uri.parse(url).host == 'openrouter.ai';
    try {
      final response = await _dio.post(
        url,
        data: {
          'model': defaultModel,
          'messages': [
            if (systemPersona != null)
              {'role': 'system', 'content': systemPersona},
            if (history != null) ...history,
            {'role': 'user', 'content': content},
          ],
          'max_tokens': maxTokens ?? 1024,
          'temperature': 0.7,
          if (providerOnly.isNotEmpty)
            'provider': {
              'only': providerOnly,
              'allow_fallbacks': allowProviderFallbacks,
            },
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Content-Type': 'application/json',
            if (isOpenRouter) ...{
              'HTTP-Referer': 'https://smartcontentcreator.com',
              'X-Title': 'Smart Content Creator',
            },
          },
        ),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map || data['error'] != null) {
        final error = data is Map ? data['error'] : null;
        throw _requestError(
          error is Map
              ? int.tryParse('${error['code']}') ?? response.statusCode
              : response.statusCode,
        );
      }
      final choices = data['choices'];
      final message =
          choices is List && choices.isNotEmpty && choices.first is Map
          ? choices.first['message']
          : null;
      final answer = message is Map ? message['content'] : null;
      if (answer is! String || answer.trim().isEmpty) {
        throw Exception('❌ لم يُرجع النموذج إجابة صالحة. أعد المحاولة.');
      }
      return AiResult(
        description: answer,
        provider: isOpenRouter
            ? ProviderType.openrouter.name
            : ProviderType.openai.name,
      );
    } on dio.DioException catch (e) {
      if (dio.CancelToken.isCancel(e)) rethrow;
      if (e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.receiveTimeout ||
          e.type == dio.DioExceptionType.sendTimeout) {
        throw Exception(
          '❌ timeout: استغرق التحليل وقتاً طويلاً. أعد المحاولة.',
        );
      }
      // Never include headers, image bytes, or provider response bodies in logs/UI.
      throw _requestError(e.response?.statusCode);
    }
  }

  Exception _requestError(int? status) {
    final message = switch (status) {
      401 || 403 => 'تحقق من مفتاح الخدمة وصلاحياته في الإعدادات.',
      402 => 'رصيد الخدمة غير كافٍ لإتمام الطلب.',
      404 => 'النموذج أو مزود الصور المختار غير متاح حالياً.',
      413 => 'الصورة كبيرة جداً. اختر صورة أصغر.',
      429 => 'تم تجاوز حد الطلبات. انتظر قليلاً ثم أعد المحاولة.',
      400 || 422 => 'رفض المزود الطلب. تحقق من دعم النموذج لصيغة الصورة.',
      null => 'تعذر الاتصال بالخدمة. تحقق من الإنترنت وأعد المحاولة.',
      _ => 'تعذر إتمام الطلب لدى المزود. أعد المحاولة لاحقاً.',
    };
    return Exception('❌ ${status ?? 'connection_error'}: $message');
  }

  @override
  Future<AiResult> generateText(
    String prompt, {
    required String apiKey,
    List<Map<String, String>>? history,
    int? maxTokens,
    String? systemPersona,
    dio.CancelToken? cancelToken,
    String? customEndpoint,
  }) => _complete(
    prompt,
    apiKey: apiKey,
    history: history,
    maxTokens: maxTokens,
    systemPersona: systemPersona,
    cancelToken: cancelToken,
    customEndpoint: customEndpoint,
  );

  @override
  Future<AiResult> analyzeImage(
    Uint8List bytes,
    String prompt, {
    String? apiKey,
    List<Map<String, String>>? history,
    int? maxTokens,
    String? systemPersona,
    dio.CancelToken? cancelToken,
  }) => analyzeBatchImages(
    [bytes],
    prompt,
    apiKey: apiKey ?? '',
    history: history,
    maxTokens: maxTokens,
    systemPersona: systemPersona,
    cancelToken: cancelToken,
  );

  @override
  Future<AiResult> analyzeBatchImages(
    List<Uint8List> images,
    String prompt, {
    required String apiKey,
    List<Map<String, String>>? history,
    int? maxTokens,
    String? systemPersona,
    dio.CancelToken? cancelToken,
  }) async {
    if (images.isEmpty) throw Exception('❌ أرفق صورة للتحليل.');
    final parts = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];
    for (final bytes in images) {
      final mime = visionImageMimeType(bytes);
      if (mime == null) {
        throw Exception(
          '❌ صيغة الصورة غير صالحة. استخدم JPG أو PNG أو WebP أو GIF.',
        );
      }
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('❌ الصورة كبيرة جداً. استخدم صورة أصغر من 5 ميغابايت.');
      }
      parts.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'},
      });
    }
    return _complete(
      parts,
      apiKey: apiKey,
      history: history,
      maxTokens: maxTokens ?? 2048,
      systemPersona: systemPersona,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try {
      if ((baseUrl ?? '').contains('openrouter.ai')) {
        final response = await _dio.get(
          '$baseUrl/key',
          options: dio.Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Accept': 'application/json',
            },
          ),
        );
        return response.statusCode == 200;
      }
      await generateText('Test', apiKey: apiKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> generateTextStream(
    String prompt, {
    required String apiKey,
    Uint8List? imageBytes,
    Uint8List? videoBytes,
    List<Map<String, String>>? history,
    String? systemPersona,
  }) async* {
    throw UnimplementedError();
  }

  @override
  Future<List<double>> generateEmbeddings(
    String text, {
    required String apiKey,
    dio.CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }
}
