import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'ai_provider.dart';
import '../core/models/api_provider.dart';
import '../controllers/settings_controller.dart';

class AzureOpenAIService extends AIProvider {
  final dio.Dio _dio = dio.Dio();

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    
    final settings = Get.find<SettingsController>();
    final endpoint = settings.getCustomEndpoint(ProviderType.azure);
    
    if (apiKey.isEmpty || endpoint.isEmpty) {
      throw Exception('Azure OpenAI (Key/Endpoint) missing.');
    }

    final url = "$endpoint/openai/deployments/gpt-4o/chat/completions?api-version=2023-05-15";

    try {
      final response = await _dio.post(
        url,
        data: {
          "messages": [
            if (systemPersona != null) {"role": "system", "content": systemPersona},
            if (history != null) ...history,
            {"role": "user", "content": prompt}
          ],
          "max_tokens": maxTokens ?? 800,
          "temperature": 0.7,
        },
        options: dio.Options(
          headers: {"api-key": apiKey, "Content-Type": "application/json"},
          validateStatus: (status) => status! < 500,
        ),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'] ?? '';
        return AiResult(description: content, provider: 'azure');
      } else {
        throw Exception("Azure Error: ${response.statusCode}");
      }
    } on dio.DioException catch (e) {
      if (e.type == dio.DioExceptionType.cancel) throw Exception("🚫 Cancelled");
      rethrow;
    }
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt, {String? apiKey, List<Map<String, String>>? history, int? maxTokens, String? systemPersona, dio.CancelToken? cancelToken}) async {
     throw UnimplementedError();
  }

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt, {required String apiKey, List<Map<String, String>>? history, int? maxTokens, String? systemPersona, dio.CancelToken? cancelToken}) async {
     throw UnimplementedError();
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try { await generateText("Test", apiKey: apiKey); return true; } catch (_) { return false; }
  }

  @override
  Stream<String> generateTextStream(String prompt, {required String apiKey, Uint8List? imageBytes, Uint8List? videoBytes, List<Map<String, String>>? history, String? systemPersona}) async* {
     throw UnimplementedError();
  }

  @override
  Future<List<double>> generateEmbeddings(String text, {required String apiKey, dio.CancelToken? cancelToken}) async {
     throw UnimplementedError();
  }
}
