import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:smart_content_creator/controllers/settings_controller.dart';
import 'package:smart_content_creator/core/models/api_provider.dart';
import 'package:smart_content_creator/core/api/enterprise_api_client.dart';

class OpenRouterVideoService extends GetxService {
  SettingsController get _settings => Get.find<SettingsController>();
  final EnterpriseApiClient _apiClient = EnterpriseApiClient();

  String get _apiKey => _settings.getApiKey(ProviderType.openrouter);
  static const String _baseUrl = "https://openrouter.ai/api/v1";

  /// 🎬 توليد فيديو عبر OpenRouter
  Future<String> generateVideo(String prompt, {
    String? imagePath, 
    String? apiKey, 
    String model = "google/veo-3.1-fast"
  }) async {
    final keyToUse = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _apiKey;
    if (keyToUse.isEmpty) {
      throw Exception("مفتاح OpenRouter مفقود. يرجى إضافته في الإعدادات.");
    }

    try {
      final response = await _apiClient.request(
        url: "$_baseUrl/videos",
        method: "POST",
        providerName: "openrouter-video",
        headers: {
          "Authorization": "Bearer $keyToUse",
          "Content-Type": "application/json",
          "HTTP-Referer": "https://smartcontentcreator-d49f2.web.app",
          "X-Title": "Smart Content Creator",
        },
        data: {
          "model": model,
          "prompt": prompt,
          "generate_audio": true,
          if (imagePath != null && imagePath.isNotEmpty)
            "frame_images": [
              {
                "type": "image_url",
                "frame_type": "first_frame",
                "image_url": {
                  "url": imagePath.startsWith('http') 
                      ? imagePath 
                      : "data:image/jpeg;base64,${base64Encode(File(imagePath).readAsBytesSync())}"
                }
              }
            ],
        },
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        final jobId = response.data['job_id'] ?? response.data['id'];
        if (jobId == null) throw Exception("لم يتم استلام معرف المهمة (Job ID) من OpenRouter");
        return jobId;
      }
      throw Exception("فشل بدء توليد الفيديو في OpenRouter: ${response.data}");
    } on EnterpriseApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("OpenRouter Video Exception: $e");
      rethrow;
    }
  }

  /// 📊 التحقق من حالة المهمة
  Future<Map<String, dynamic>> checkTaskStatus(String jobId, {String? apiKey}) async {
    final keyToUse = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _apiKey;
    
    try {
      final response = await _apiClient.request(
        url: "$_baseUrl/videos/$jobId",
        method: "GET",
        providerName: "openrouter-video-status",
        headers: {
          "Authorization": "Bearer $keyToUse",
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception("استجابة غير صالحة من OpenRouter");
    } catch (e) {
      throw Exception("فشل فحص حالة المهمة في OpenRouter: $e");
    }
  }
}
