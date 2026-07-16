import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import 'ai_provider.dart';

/// 🎬 Google Veo Video Generation Service
/// Supports: Veo 3.1 and Veo 3.1 Fast
class GoogleVeoService extends GetxService implements AIProvider {
  SettingsController get _settings => Get.find<SettingsController>();

  String get _apiKey => _settings
      .getApiKey(ProviderType.gemini); // Veo uses Gemini/Google API Key

  // Google AI Studio Video Gen Endpoint (Conceptual based on latest API)
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta";

  @override
  Future<bool> testConnection(String apiKey) async {
    // We can test by calling a simple model list or trying a fast prediction
    try {
      final url = Uri.parse("$_baseUrl/models/veo-3.1-fast?key=$apiKey");
      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    return AiResult(
        description: "Veo is a video model.", provider: "Google Veo");
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    return AiResult(
        description: "Veo doesn't analyze images directly in this mode.",
        provider: "Google Veo");
  }

  /// 🎥 الأساس: توليد الفيديو باستخدام Veo
  @override
  Future<String> generateVideo(String prompt,
      {String? imagePath, String? apiKey, String model = "veo-3.1-fast"}) async {
    final effectiveApiKey = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _apiKey;
    if (effectiveApiKey.isEmpty) throw Exception("مفتاح Google API مطلوب لتشغيل Veo.");

    final modelName = model;
    final url = Uri.parse("$_baseUrl/models/$modelName:predict?key=$effectiveApiKey");

    // تحويل الصورة لـ Base64 إذا وجدت (Image-to-Video)
    String? base64Image;
    if (imagePath != null) {
      final bytes = await File(imagePath).readAsBytes();
      base64Image = base64Encode(bytes);
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "instances": [
            {
              "prompt": prompt,
              if (base64Image != null)
                "image": {"bytesBase64Encoded": base64Image}
            }
          ],
          "parameters": {
            "sampleCount": 1,
            "aspectRatio": "16:9",
            "resolution": modelName.contains("fast") ? "720p" : "1080p",
            "fps": 24,
            "durationSeconds": 5
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // التنسيق المتوقع من Google AI
        final predictions = data['predictions'] as List?;
        if (predictions != null && predictions.isNotEmpty) {
          // Veo usually returns a cloud storage URI or a status to poll
          return predictions[0]['videoUri'] ??
              predictions[0]['url'] ??
              "Task Started";
        }
        return "تم إرسال الطلب لـ Veo بنجاح.";
      } else {
        throw Exception("خطأ من جوجل (Veo): ${response.body}");
      }
    } catch (e) {
      throw Exception("فشل الاتصال بـ Google Veo: $e");
    }
  }

  @override
  Future<Map<String, dynamic>> checkTaskStatus(String taskId) async {
    return {"status": "processing", "job_id": taskId};
  }

  @override
  Stream<String> generateTextStream(String prompt,
      {required String apiKey,
      Uint8List? imageBytes,
      Uint8List? videoBytes,
      List<Map<String, String>>? history,
      String? systemPersona}) async* {
    yield "Veo does not support text streaming.";
  }

  @override
  Future<List<double>> generateEmbeddings(String text,
          {required String apiKey, dio.CancelToken? cancelToken}) async =>
      [];

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    if (images.isEmpty) throw Exception("No images provided");
    return analyzeImage(images.first, prompt,
        apiKey: apiKey, history: history, systemPersona: systemPersona);
  }
}
