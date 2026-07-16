import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../core/api/enterprise_api_client.dart';
import 'ai_provider.dart';

/// 🚀 Higgsfield AI (Evo) Video Generation Service
class HiggsfieldService extends GetxService implements AIProvider {
  SettingsController get _settings => Get.find<SettingsController>();
  final EnterpriseApiClient _apiClient = EnterpriseApiClient();

  String get _apiKey => _settings.getApiKey(ProviderType.higgsfield);
  String get _secretKey =>
      _settings.providerSecrets[ProviderType.higgsfield] ?? '';

  String _getEffectiveToken({String? manualKey}) {
    String token;
    String source;
    if (manualKey != null && manualKey.isNotEmpty) {
      token = manualKey;
      source = "Manual Overide";
    } else if (_secretKey.isNotEmpty) {
      token = _secretKey;
      source = "Secret Key (Settings)";
    } else {
      token = _apiKey;
      source = "API Key (Settings)";
    }

    if (kDebugMode) {
      debugPrint(
          "🔑 [Higgsfield Auth]: Using $source (Length: ${token.length})");
      if (token.length > 4) {
        debugPrint("🔑 [Higgsfield Auth]: Prefix: ${token.substring(0, 4)}...");
      }
    }
    return token;
  }

  // 🌐 Discovered via community documentation (platform.higgsfield.ai)
  static const String _baseUrl = "https://platform.higgsfield.ai";

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    final isConnected = await testConnection(apiKey);
    if (!isConnected) {
      throw Exception(
          "فشل الاتصال: مفتاح Higgsfield غير صحيح أو منتهي الصلاحية.");
    }
    return AiResult(
      description: "Higgsfield AI (Evo) is Active. Ready for Video Generation.",
      provider: "Higgsfield AI",
    );
  }

  @override
  Future<AiResult> analyzeImage(Uint8List bytes, String prompt,
      {String? apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    return AiResult(
      description:
          "تحليل الصور غير مدعوم مباشرة في Higgsfield. استخدم توليد الفيديو بدلاً من ذلك.",
      provider: "Higgsfield AI",
    );
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    final keyToUse = apiKey.isNotEmpty ? apiKey : _apiKey;
    if (keyToUse.isEmpty) {
      if (kDebugMode) {
        debugPrint("🔍 [Higgsfield]: No API Key provided for test.");
      }
      return false;
    }

    final url = "$_baseUrl/v1/generations";

    if (kDebugMode) {
      debugPrint("🚀 [Higgsfield]: Testing connection to $url");
    }

    try {
      final response = await _apiClient.request(
        url: url,
        method: "GET",
        providerName: "higgsfield-test",
        headers: {
          "Authorization": "Bearer ${_getEffectiveToken(manualKey: keyToUse)}",
        },
      );

      if (kDebugMode) {
        debugPrint(
            "✅ [Higgsfield]: Connection Success. Status: ${response.statusCode}");
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ [Higgsfield]: Connection Failed: $e");
      // 🎯 405 Method Not Allowed means the server IS there but wants POST. This is a SUCCESS for a connectivity test!
      if (e.toString().contains("405")) {
        if (kDebugMode) {
          debugPrint(
              "✅ [Higgsfield]: Server reached successfully (405 confirms endpoint exists).");
        }
        return true;
      }
      return false;
    }
  }

  /// 🎬 توليد فيديو احترافي
  @override
  Future<String> generateVideo(String prompt,
      {String? imagePath, String? apiKey, String model = "evo-1"}) async {
    final keyToUse = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _apiKey;
    if (keyToUse.isEmpty) throw Exception("مفتاح Higgsfield AI مطلوب.");

    String? base64Image;
    if (imagePath != null && !imagePath.startsWith('http')) {
      final bytes = await File(imagePath).readAsBytes();
      base64Image = base64Encode(bytes);
    }

    try {
      final response = await _apiClient.request(
        url: "$_baseUrl/v1/generations",
        method: "POST",
        providerName: "higgsfield-generate",
        headers: {
          "Authorization": "Bearer ${_getEffectiveToken(manualKey: keyToUse)}",
          "Content-Type": "application/json",
        },
        data: {
          "model": "evo-1",
          "prompt": prompt,
          "input_images": [
            if (imagePath != null && imagePath.startsWith('http'))
              imagePath
            else if (base64Image != null)
              "data:image/jpeg;base64,$base64Image"
          ],
          "motion_id":
              "31177282-bde3-4870-b283-1135ca0a201a", // Default cinematic motion
          "quality": "standard"
        },
      );

      final data = response.data;
      final jobId = data['id'] ?? data['generation_id'];
      if (jobId == null) {
        throw Exception("لم يتم استلام معرف المهمة.");
      }
      return jobId.toString();
    } catch (e) {
      rethrow;
    }
  }

  /// 📊 فحص الحالة (Polling)
  @override
  Future<Map<String, dynamic>> checkTaskStatus(String taskId) async {
    final url = "$_baseUrl/v1/generations/$taskId";
    try {
      final response = await _apiClient.request(
        url: url,
        method: "GET",
        providerName: "higgsfield-status",
        headers: {
          "Authorization": "Bearer ${_getEffectiveToken()}",
        },
      );
      return response.data;
    } on EnterpriseApiException catch (e) {
      // Higgsfield API frequently returns 405 for GET and allows POST.
      if (e.statusCode == 405) {
        final response = await _apiClient.request(
          url: url,
          method: "POST",
          providerName: "higgsfield-status",
          headers: {
            "Authorization": "Bearer ${_getEffectiveToken()}",
            "Content-Type": "application/json",
          },
          data: const {},
        );
        return response.data;
      }
      rethrow;
    }
  }

  @override
  Stream<String> generateTextStream(String prompt,
      {required String apiKey,
      Uint8List? imageBytes,
      Uint8List? videoBytes,
      List<Map<String, String>>? history,
      String? systemPersona}) async* {
    yield "Higgsfield supports video generation only.";
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
    if (images.isEmpty) throw Exception("لم يتم تقديم أي صور");
    return analyzeImage(images.first, prompt);
  }
}
