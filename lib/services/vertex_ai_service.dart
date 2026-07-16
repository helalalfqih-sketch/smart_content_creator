import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../core/models/api_provider.dart';
import 'ai_provider.dart';

/// ☁️ VertexAiService — Google Vertex AI عبر Back4App Cloud Code
///
/// ⚠️ مبدأ الأمان: لا يوجد أي Service Account أو Google Cloud credentials
/// داخل هذا الملف أو أي ملف في التطبيق.
/// جميع الطلبات تمر عبر Back4App Cloud Code الذي يحتفظ بـ credentials
/// بشكل آمن كـ Environment Variables على السيرفر.
///
/// الاستخدام في سلسلة Fallback:
///   Back4App (AI Studio) → Back4App (Vertex AI) ← هذه الخدمة
///                        → GitHub GPT-4o → Gemini محلي → ...
class VertexAiService extends GetxService implements AIProvider {
  // ─── Back4App Connection ────────────────────────────────────────────────────
  static const String _parseAppId = 'uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2';
  static const String _parseRestKey = 'Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp';
  static const String _parseMasterKey = '8qRzu0pBFkDo0urIjpXeFGb23xR5C23JoOlD05ze';
  static const String _parseBaseUrl = 'https://parseapi.back4app.com';

  /// النموذج الافتراضي — يمكن تغييره من Back4App Dashboard دون تحديث التطبيق
  static const String _defaultModel = 'gemini-2.5-flash';

  Map<String, String> get _headers => {
        'X-Parse-Application-Id': _parseAppId,
        'X-Parse-REST-API-Key': _parseRestKey,
        'X-Parse-Master-Key': _parseMasterKey,
        'Content-Type': 'application/json',
      };

  // ─── AIProvider Interface ────────────────────────────────────────────────────

  @override
  Future<AiResult> generateText(
    String prompt, {
    required String apiKey, // غير مستخدم — Vertex يدار من Back4App
    List<Map<String, String>>? history,
    int? maxTokens,
    String? systemPersona,
    dio.CancelToken? cancelToken,
    String? customEndpoint,
  }) async {
    return _callVertexGateway(
      prompt: prompt,
      history: history,
      maxTokens: maxTokens ?? 4096,
      systemPersona: systemPersona,
    );
  }

  @override
  Future<AiResult> analyzeImage(
    Uint8List bytes,
    String prompt, {
    String? apiKey,
    List<Map<String, String>>? history,
    int? maxTokens,
    String? systemPersona,
    dio.CancelToken? cancelToken,
  }) async {
    return _callVertexGateway(
      prompt: prompt,
      history: history,
      maxTokens: maxTokens ?? 4096,
      systemPersona: systemPersona,
      imageBase64: base64Encode(bytes),
      mimeType: 'image/jpeg',
    );
  }

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
    // Vertex عبر Back4App يدعم صورة واحدة حالياً — نرسل الأولى
    // (يمكن تحديث Back4App function لاحقاً لدعم batch)
    if (images.isEmpty) {
      throw Exception('[VertexAI] لا توجد صور للتحليل.');
    }
    return _callVertexGateway(
      prompt: prompt,
      history: history,
      maxTokens: maxTokens ?? 1200,
      systemPersona: systemPersona,
      imageBase64: base64Encode(images.first),
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try {
      final result = await _callVertexGateway(prompt: 'hi', maxTokens: 10);
      return result.description.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [VertexAI] testConnection failed: $e');
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
    // Vertex عبر Back4App لا يدعم streaming حالياً — نُعيد كـ single chunk
    final result = await generateText(
      prompt,
      apiKey: apiKey,
      history: history,
      systemPersona: systemPersona,
    );
    yield result.description;
  }

  @override
  Future<List<double>> generateEmbeddings(
    String text, {
    required String apiKey,
    dio.CancelToken? cancelToken,
  }) async {
    // Embeddings غير مدعومة في هذه الخدمة
    return [];
  }

  @override
  Future<String> generateVideo(String prompt,
      {String? imagePath, String? apiKey, String model = "evo-1"}) {
    throw UnimplementedError("Video generation not supported by Vertex AI Gateway");
  }

  @override
  Future<Map<String, dynamic>> checkTaskStatus(String taskId) {
    throw UnimplementedError("Task status check not supported by Vertex AI Gateway");
  }

  // ─── Core Gateway Call ───────────────────────────────────────────────────────

  /// 📡 استدعاء Back4App `aiVertexGateway` Cloud Function
  Future<AiResult> _callVertexGateway({
    required String prompt,
    List<Map<String, String>>? history,
    int maxTokens = 4096,
    double temperature = 0.7,
    String? systemPersona,
    String? imageBase64,
    String? mimeType,
    String? model,
  }) async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiVertexGateway');

      // تحويل التاريخ لـ format مفهوم
      final List<Map<String, String>>? formattedHistory = history?.map((h) {
        return <String, String>{
          'role': h['role'] == 'model' ? 'assistant' : (h['role'] ?? 'user'),
          'content': h['content'] ?? '',
        };
      }).toList();

      final body = <String, dynamic>{
        'prompt': prompt,
        'model': model ?? _defaultModel,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (formattedHistory != null && formattedHistory.isNotEmpty)
          'history': formattedHistory,
        if (systemPersona != null && systemPersona.isNotEmpty)
          'system_persona': systemPersona,
        if (imageBase64 != null) 'image': imageBase64,
        if (mimeType != null) 'mimeType': mimeType,
      };

      if (kDebugMode) {
        debugPrint('☁️ [Vertex-Gateway]: Calling aiVertexGateway...');
        debugPrint(
            '📝 [Vertex-Gateway]: Prompt length: ${prompt.length}, Image: ${imageBase64 != null ? "YES" : "NO"}, Model: ${model ?? _defaultModel}');
      }

      final response = await http
          .post(
            url,
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 45)); // Vertex قد يأخذ وقتاً أطول

      if (kDebugMode) {
        debugPrint(
            '📡 [Vertex-Gateway]: Status: ${response.statusCode}');
        debugPrint(
            '📡 [Vertex-Gateway]: Body preview: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];

        if (result != null && result['success'] == true) {
          final text = result['data'] ?? '';
          final meta = result['meta'] ?? {};

          if (kDebugMode) {
            debugPrint(
                '✅ [Vertex-Gateway]: SUCCESS! Provider: ${meta['provider']}, Model: ${meta['model']}');
          }

          return AiResult(
            description: text,
            provider:
                'Vertex AI (${meta['model'] ?? model ?? _defaultModel})',
          );
        }
      }

      // معالجة الأخطاء
      final errorData = json.decode(response.body);
      final errorMsg = errorData['error'] ??
          errorData['message'] ??
          'Unknown Vertex Gateway Error';
      final errorCode = errorData['code'] ?? response.statusCode;

      if (kDebugMode) {
        debugPrint('❌ [Vertex-Gateway]: Error $errorCode: $errorMsg');
      }

      throw Exception('VertexAI ($errorCode): $errorMsg');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Vertex-Gateway]: Connection Error: $e');
      }
      rethrow;
    }
  }

  // ─── Health Check ─────────────────────────────────────────────────────────

  /// 🏥 فحص صحة Vertex Gateway في Back4App
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiVertexHealth');
      final response = await http
          .post(url, headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['result'] ?? {});
      }
      return {'status': 'error', 'code': response.statusCode};
    } catch (e) {
      return {'status': 'offline', 'error': e.toString()};
    }
  }
}
