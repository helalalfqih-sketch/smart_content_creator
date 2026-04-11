import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import '../core/models/api_provider.dart';
import 'ai_provider.dart';

class AnthropicService implements AIProvider {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-3-5-sonnet-20241022';
  final dio.Dio _dio = dio.Dio();

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    if (apiKey.isEmpty) {
      throw Exception("❌ مفتاح Anthropic غير موجود");
    }

    try {
      final response = await _dio.post(
        _baseUrl,
        options: dio.Options(
          headers: {
            'x-api-key': apiKey,
            'Content-Type': 'application/json',
            'anthropic-version': '2023-06-01',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        cancelToken: cancelToken,
        data: {
          "model": _model,
          "max_tokens": maxTokens ?? 1024,
          if (systemPersona != null && systemPersona.isNotEmpty)
            "system": systemPersona,
          "messages": [
            if (history != null)
              ...history.map((m) {
                final role = m['role'] == 'assistant' || m['role'] == 'model' ? 'assistant' : 'user';
                return {"role": role, "content": m['content']};
              }),
            {"role": "user", "content": prompt}
          ]
        },
      );

      final data = response.data;
      final content = data["content"] as List?;
      if (content != null && content.isNotEmpty) {
        final text = content[0]["text"] ?? "";
        return AiResult(
          description: text,
          tags: const <String>[],
          provider: 'Anthropic',
        );
      }
      throw Exception("❌ رد فارغ من Anthropic");
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) {
        throw Exception('🚫 تم إلغاء الطلب');
      }
      throw Exception("❌ خطأ من Anthropic: ${e.message}");
    } catch (e) {
      throw Exception("❌ خطأ في الاتصال: $e");
    }
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    return analyzeBatchImages([bytes], prompt, apiKey: apiKey ?? '', history: history, maxTokens: maxTokens, systemPersona: systemPersona, cancelToken: cancelToken);
  }

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    try {
      final List<Map<String, dynamic>> content = [];
      for (final img in images) {
        content.add({
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": base64Encode(img),
          },
        });
      }
      content.add({"type": "text", "text": prompt});

      final response = await _dio.post(
        _baseUrl,
        options: dio.Options(
          headers: {
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
          },
        ),
        cancelToken: cancelToken,
        data: {
          "model": _model,
          "max_tokens": maxTokens ?? 2048,
          if (systemPersona != null && systemPersona.isNotEmpty)
            "system": systemPersona,
          "messages": [
            {"role": "user", "content": content}
          ],
        },
      );

      final data = response.data;
      return AiResult(
        description: data['content'][0]['text'],
        provider: 'Anthropic Vision',
      );
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) {
        throw Exception('🚫 تم إلغاء الطلب');
      }
      throw Exception("Anthropic Error: ${e.message}");
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    if (apiKey.isEmpty) return false;
    try {
      final result = await generateText("Hello", apiKey: apiKey);
      return result.description.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<String> generateTextStream(String prompt,
      {required String apiKey,
      Uint8List? imageBytes,
      Uint8List? videoBytes,
      List<Map<String, String>>? history,
      String? systemPersona}) async* {
    final result = await generateText(prompt, apiKey: apiKey, history: history, systemPersona: systemPersona);
    yield result.description;
  }

  @override
  Future<List<double>> generateEmbeddings(String text,
      {required String apiKey, dio.CancelToken? cancelToken}) async {
    return [];
  }
}
