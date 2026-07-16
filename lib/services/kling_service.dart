import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../core/api/enterprise_api_client.dart';
import 'ai_provider.dart';

class KlingService extends GetxService implements AIProvider {
  SettingsController get _settings => Get.find<SettingsController>();
  final EnterpriseApiClient _apiClient = EnterpriseApiClient();

  String get _apiKey => _settings.getApiKey(ProviderType.kling);

  static const String _baseUrl = "https://api-singapore.klingai.com/v1";

  // --- AIProvider Implementation ---

  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken,
      String? customEndpoint}) async {
    // 🧪 Use this to test the connection (Called by SettingsController)
    final isConnected = await testConnection(apiKey);
    if (!isConnected) {
      throw Exception("فشل الاتصال: مفاتيح AK/SK غير صحيحة أو انتهت صلاحيتها.");
    }

    return AiResult(
      description:
          "Kling AI is specialized for video generation. Connection is ACTIVE.",
      provider: "Kling AI",
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
      description: "Image analysis is not supported by Kling AI yet.",
      provider: "Kling AI",
    );
  }

  @override
  Future<bool> testConnection(String apiKey) async {
    try {
      final token = await _getAuthToken(manualKey: apiKey);
      if (token.isEmpty) return false;

      // استخدام المحرك المركزي لفحص الاتصال
      await _apiClient.request(
        url: "$_baseUrl/videos/text2video",
        method: "POST",
        providerName: "kling",
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        data: {
          "prompt": "hi",
          "model": "kling-v1",
        }, 
      );
      return true;
    } on EnterpriseApiException catch (e) {
      // في Kling، الرمز 400 يعني أننا وصلنا للسيرفر بنجاح لكن المدخلات ناقصة (وهذا يعني أن المفتاح يعمل)
      return e.statusCode == 400;
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Kling Connection Test Error: $e");
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
    yield "Kling AI does not support streaming text. Use generateVideo instead.";
  }

  @override
  Future<List<double>> generateEmbeddings(String text,
      {required String apiKey, dio.CancelToken? cancelToken}) async {
    return []; // Not supported
  }

  // --- Kling Specific Methods ---

  /// 🔐 توليد JWT بنمط HS256 متوافق تماماً مع متطلبات Kling AI
  String _generateJWT(String accessKey, String secretKey) {
    final ak = accessKey.trim();
    final sk = secretKey.trim();

    // 💡 تنبيه استباقي: مفاتيح Kling الرسمية عادة ما تبدأ بـ AK أو AT لبعض الموزعين
    if (kDebugMode) {
      if (!ak.startsWith('AK') && !ak.startsWith('AT')) {
        debugPrint(
            "⚠️ Kling Warning: Access Key ID '$ak' DOES NOT look like a standard Kling Key. Official keys usually START with 'AK' or 'AT'.");
      }
      if (ak.contains('api') && !ak.contains('AT')) {
        debugPrint(
            "⚠️ Kling Hint: You entered something containing 'api'. Make sure you are using 'Access Key ID' and NOT an API Key from another platform.");
      }
    }

    // 1. Header
    final header = {"alg": "HS256", "typ": "JWT"};

    // 2. Payload
    // 🚀 [Time Drift Fix]: Some servers reject tokens if iat is slightly in the future
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = {
      "iss": ak,
      "exp": now + 3600, // 1 hour expiry
      "iat": now - 60,   // Set iat to 1 minute ago to handle clock drift
      "nbf": now - 60,   // Not before 1 minute ago
    };

    // Helper for URL-safe base64 without padding
    String base64UrlSafe(Map<String, dynamic> map) {
      final str = jsonEncode(map);
      return base64Url.encode(utf8.encode(str)).replaceAll('=', '');
    }

    final headerBase64 = base64UrlSafe(header);
    final payloadBase64 = base64UrlSafe(payload);
    final dataToSign = "$headerBase64.$payloadBase64";

    // 3. Signature: HMAC-SHA256 with Secret Key
    final hmac = Hmac(sha256, utf8.encode(sk));
    final signature = hmac.convert(utf8.encode(dataToSign));
    final signatureBase64 = base64Url.encode(signature.bytes).replaceAll('=', '');

    final token = "$dataToSign.$signatureBase64";

    if (kDebugMode) {
      final masked = ak.length > 8
          ? "${ak.substring(0, 4)}...${ak.substring(ak.length - 4)}"
          : ak;
      debugPrint("🛠️ Kling Auth Check - AK: $masked (Len: ${ak.length})");
    }

    return token;
  }

  /// 🔑 الحصول على التوكن النشط (يضمن دائماً إرجاع JWT)
  Future<String> _getAuthToken({String? manualKey}) async {
    String ak = "";
    String sk = "";

    // 1. تحديد المصدر الأساسي (يدوي أو من الإعدادات)
    String primaryKey = manualKey ?? _apiKey;

    // 2. تحليل المفتاح الأولي
    if (primaryKey.contains(':')) {
      final parts = primaryKey.split(':');
      if (parts.length >= 2) {
        ak = parts[0].trim();
        sk = parts[1].trim();
      }
    } else if (primaryKey.contains('.') && primaryKey.split('.').length == 3) {
      // إذا كان المفتاح هو توكن JWT جاهز، نرجعه مباشرة
      return primaryKey;
    } else {
      ak = primaryKey.trim();
      sk = await _settings.getSecretKey(ProviderType.kling);
    }

    if (ak.isNotEmpty && sk.isNotEmpty) {
      if (kDebugMode) debugPrint("🎯 Kling AI: Using Local Credentials");
    }

    // 4. إنشاء توكن JWT إذا توفرت المفاتيح
    if (ak.isNotEmpty && sk.isNotEmpty) {
      return _generateJWT(ak, sk);
    }

    if (kDebugMode) {
      debugPrint(
          "⚠️ KlingService Error: Incomplete Credentials (AK: ${ak.isNotEmpty}, SK: ${sk.isNotEmpty})");
    }

    return "";
  }

  /// 🎬 توليد فيديو من نص أو صورة
  @override
  Future<String> generateVideo(String prompt,
      {String? imagePath, String? apiKey, String model = "kling-v1"}) async {
    final token = await _getAuthToken(manualKey: apiKey);
    if (token.isEmpty || token.split('.').length != 3) {
      throw Exception(
          "مفتاح Kling AI غير صالح أو غير موجود. يرجى التأكد من إدخال AK و SK في الإعدادات.");
    }

    final isImage = imagePath != null;
    final path = isImage ? "/videos/image2video" : "/videos/text2video";

    // 🖼️ معالجة الصورة إذا وجدت (تحويل لمسار Base64)
    String? base64Image;
    if (imagePath != null && !imagePath.startsWith('http')) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          base64Image = base64Encode(bytes);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ KlingService: Failed to encode image to base64: $e");
        }
      }
    }

    try {
      final response = await _apiClient.request(
        url: "$_baseUrl$path",
        method: "POST",
        providerName: "kling-generate",
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
        data: {
          "prompt": prompt,
          "duration": "10",
          "model": "kling-v1",
          if (imagePath != null && imagePath.startsWith('http')) 
            "image_url": imagePath
          else if (base64Image != null) 
            "image": base64Image,
        },
      );

      if (response.statusCode == 200) {
        final resultData = response.data['data'] ?? response.data;
        return resultData['video_id'] ??
            resultData['task_id'] ??
            resultData['id'] ??
            "تم بدء التوليد";
      }
      throw Exception("فشل غير متوقع");
    } on EnterpriseApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("Kling AI Exception: $e");
      rethrow;
    }
  }

  /// 📊 التحقق من حالة المهمة بالتنسيق المركزي
  @override
  Future<Map<String, dynamic>> checkTaskStatus(String taskId) async {
    final token = await _getAuthToken();
    if (token.isEmpty) throw Exception("توكن Kling مفقود");

    try {
      // نحاول طلبين، نختار النوع الصحيح بناءً على الاستجابة
      // الميزه هنا أن EnterpriseApiClient سيتعامل مع الـ Timeout والـ Rate Limit
      final response = await _apiClient.request(
        url: "$_baseUrl/videos/text2video/$taskId",
        method: "GET",
        providerName: "kling-status",
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return response.data['data'] ?? response.data;
      }

      // إذا لم يجدها في النص، نجرب في الصورة (Kling يفصل بينهما)
      final imgResponse = await _apiClient.request(
        url: "$_baseUrl/videos/image2video/$taskId",
        method: "GET",
        providerName: "kling-status",
        headers: {"Authorization": "Bearer $token"},
      );

      return imgResponse.data['data'] ?? imgResponse.data;
    } on EnterpriseApiException catch (e) {
      throw Exception("خطأ فحص الحالة: ${e.message}");
    } catch (e) {
      throw Exception("فشل التحقق من المهمة: $e");
    }
  }

  @override
  Future<AiResult> analyzeBatchImages(List<Uint8List> images, String prompt,
      {required String apiKey,
      List<Map<String, String>>? history,
      int? maxTokens,
      String? systemPersona,
      dio.CancelToken? cancelToken}) async {
    // Kling is a video generation model, vision analysis fallback
    if (images.isEmpty) throw Exception("No images provided");
    return analyzeImage(images.first, prompt, apiKey: apiKey, history: history);
  }
}
