import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'ai_provider.dart';
import '../core/models/api_provider.dart';

/// 🧠 Groq Service: Ultra-fast inference for real-time AI responses
class GroqService extends AIProvider {
  final dio.Dio _dio = dio.Dio();
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    
    try {
      final response = await _dio.post(
        customEndpoint ?? _baseUrl,
        data: {
          "model": "llama-3.3-70b-versatile",
          "messages": [
            if (systemPersona != null) {"role": "system", "content": systemPersona},
            if (history != null) ...history,
            {"role": "user", "content": prompt}
          ],
          "max_tokens": maxTokens ?? 2048,
          "temperature": 0.7,
        },
        options: dio.Options(
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json",
          },
        ),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] ?? '';
        return AiResult(
          description: content, 
          provider: ProviderType.groq.name
        );
      } else {
        throw Exception("Groq API Error (${response.statusCode}): ${response.data}");
      }
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) {
        throw Exception("🚫 تم إلغاء طلب Groq.");
      }
      throw Exception("Groq Connection Error: $e");
    }
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try {
      await generateText("Test", apiKey: apiKey);
      return true;
    } catch (_) {
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
    throw UnimplementedError();
  }

  @override
  Future<List<double>> generateEmbeddings(String text,
      {required String apiKey, dio.CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }
}
