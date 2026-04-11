import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/models/api_provider.dart';
import '../ai_provider.dart';
import 'data/google_ai_mode_models.dart';

class GoogleAiModeService implements AIProvider {
  static const String _baseUrl = 'https://serpapi.com/search';

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    try {
      // 🛡️ Note: Google AI Mode (SerpApi) doesn't natively support system personas
      // Use prompt enrichment if we wanted to enforce Arabic here, but sticking to no-op for now.
      final result = await searchAiOverviews(prompt, apiKey: apiKey);
      final text = result.reconstructedMarkdown ?? 'No response received.';
      
      return AiResult(
        description: text,
        provider: 'Google AI Mode (SerpApi)',
      );
    } catch (e) {
      if (kDebugMode) print('❌ GoogleAiModeService.generateText Error: $e');
      rethrow;
    }
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    throw UnimplementedError(
        'Google AI Mode does not support multi-modal image analysis yet.');
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try {
      final result = await searchAiOverviews('test', apiKey: apiKey);
      return result.reconstructedMarkdown != null;
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
    final result = await generateText(prompt,
        apiKey: apiKey, history: history, systemPersona: systemPersona);
    yield result.description;
  }

  @override
  Future<List<double>> generateEmbeddings(String text,
      {required String apiKey, dio.CancelToken? cancelToken}) async {
    throw UnimplementedError('Google AI Mode does not support embeddings.');
  }

  Future<GoogleAiModeResult> searchAiOverviews(
    String query, {
    required String apiKey,
    String? subsequentRequestToken,
    String? gl = 'us',
    String? hl = 'en',
    String? location,
  }) async {
    // ✂️ "مقص البيانات" لضمان عدم تجاوز طول الرابط (URI Too Long - 414)
    String safeQuery = query;
    const int maxUriLimit = 2500;
    if (safeQuery.length > maxUriLimit) {
      if (kDebugMode) debugPrint("✂️ GoogleAiMode: Truncating query for URI safety...");
      safeQuery = safeQuery.substring(0, maxUriLimit);
    }

    final queryParams = {
      'engine': 'google_ai_mode',
      'q': safeQuery,
      'api_key': apiKey,
      'gl': gl,
      'hl': hl,
    };

    if (subsequentRequestToken != null) {
      queryParams['subsequent_request_token'] = subsequentRequestToken;
    }

    if (location != null) {
      queryParams['location'] = location;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    try {
      if (kDebugMode) print('🌐 Requesting Google AI Mode: $uri');
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception('SerpApi Error: ${data['error']}');
        }
        return GoogleAiModeResult.fromJson(data);
      } else {
        throw Exception('Failed to load AI Mode results: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ GoogleAiModeService Error: $e');
      rethrow;
    }
  }

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    // 🛡️ Google Lens with SerpApi currently doesn't have a native batch mode
    // We'll analyze the first image as a primary representative
    if (images.isEmpty) throw Exception("No images provided");
    return analyzeImage(images.first, prompt,
        apiKey: apiKey, history: history, systemPersona: systemPersona);
  }
}
