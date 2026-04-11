import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart' as dio;
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import 'kling_service.dart';
import 'google_veo_service.dart';
import 'ai/model_capability_service.dart';
import '../core/api/enterprise_api_client.dart';
// import 'gemini_service.dart'; // Removed unused import
import 'ai_provider.dart';
import '../core/utils/image_utils.dart';
import 'ai/background_removal_service.dart';

class AiImageGenerationService extends GetxService {
  static AiImageGenerationService get to => Get.find();

  // Provider enum
  static const String providerGemini = 'gemini';
  static const String providerStability = 'stability';
  static const String providerDalle = 'dalle';
  static const String providerMock = 'mock';

  // Demo mode flag - automatically disabled in production logic
  bool demoMode = false;

  // Current provider - default to Gemini
  String currentProvider = providerGemini;
  
  final EnterpriseApiClient _apiClient = EnterpriseApiClient();


  // ✅ Smart Multi-Engine Router (No Mock Data)
  Future<String> generateWithSelectedProvider(String provider, String prompt,
      {File? originalImage}) async {
    switch (provider.toLowerCase()) {
      case "nano":
        // Nano Banana Mode = Professional Product Photography Workflow
        if (originalImage != null) {
          final res = await generateProfessionalProductPhoto(
            originalImageFile: originalImage,
            prompt: prompt,
          );
          return res.localPath ?? "";
        }
        return (await generateImage(prompt, provider: providerStability))
                .localPath ??
            "";

      case "veo":
        // Veo Mode with Fallback logic
        final capability = Get.find<ModelCapabilityService>();
        if (capability.isModelAvailable('veo-3.1-fast')) {
          final veoService = Get.find<GoogleVeoService>();
          return await veoService.generateVideo(prompt,
              imagePath: originalImage?.path, fastMode: true);
        } else {
          // 🔄 Fallback to Kling if Veo is not enabled in this API project
          final kling = Get.find<KlingService>();
          debugPrint(
              "⚠️ Veo not available in this project, falling back to Kling...");
          return await kling.generateVideoFromText(prompt,
              imagePath: originalImage?.path);
        }

      case "stability":
      default:
        final res = await generateImage(prompt, provider: providerStability);
        return res.localPath ?? "";
    }
  }

  /// 🔌 التحقق من اتصال Stability AI وفحص الرصيد (Enterprise Mode)
  Future<bool> testStabilityConnection(String apiKey) async {
    if (apiKey.isEmpty) return false;
    try {
      // فحص الرصيد باستخدام المحرك المركزي
      final response = await _apiClient.request(
        url: 'https://api.stability.ai/v1/user/balance',
        method: 'GET',
        providerName: 'stability',
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 200) {
        final double credits = (response.data['credits'] as num).toDouble();
        debugPrint('💰 Stability Credits: $credits');
        if (credits <= 0) throw Exception("رصيدك 0");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Stability Connection Error: $e');
      rethrow;
    }
  }

  /// 🔌 التحقق من اتصال Remove.bg
  Future<bool> testRemoveBgConnection(String apiKey) async {
    if (apiKey.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('https://api.remove.bg/v1.0/account'),
        headers: {
          'X-Api-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final credits = data['data']['attributes']['credits']['total'] ?? 0;
        final freeCalls = data['data']['attributes']['api']['free_calls'] ?? 0;
        
        debugPrint('💰 Remove.bg Credits: $credits, Free Calls: $freeCalls');
        
        if (credits <= 0 && freeCalls <= 0) {
          debugPrint('⚠️ Remove.bg connection OK but 0 credits remaining');
          // We return true because the key IS valid, but we might want to warn.
          // For now, let's return true, but the actual request will fail with 402.
          return true;
        }
        return true;
      }

      debugPrint('⚠️ Remove.bg Test failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('⚠️ Remove.bg Connection Error: $e');
      return false;
    }
  }

  /// 🖼️ Generate an image from a text prompt
  /// Returns the local file path of the generated image
  Future<ImageGenerationResult> generateImage(
    String prompt, {
    String? provider,
    String style = 'cinematic',
    String aspectRatio = '1:1',
    int? seed,
    dio.CancelToken? cancelToken,
  }) async {
    String effectiveProvider = provider ?? currentProvider;

    // 🧠 Smart Auto-Selection: Pick the best available provider if not specified
    if (provider == null && !demoMode) {
      effectiveProvider = await _smartSelectProvider();
    }

    try {
      return await _executeGeneration(effectiveProvider, prompt,
          style: style, aspectRatio: aspectRatio, cancelToken: cancelToken);
    } catch (e) {
      debugPrint('⚠️ Primary Provider ($effectiveProvider) Failed: $e');

      // 🧠 Smart Fallback Logic
      if (effectiveProvider != providerMock) {
        String fallbackProvider = providerStability;
        if (effectiveProvider == providerStability) {
          fallbackProvider = providerMock; // Last resort
        }

        debugPrint(
            '🔁 [FALLBACK]: Switching from $effectiveProvider to $fallbackProvider...');

        try {
          return await _executeGeneration(fallbackProvider, prompt,
              style: style, aspectRatio: aspectRatio, cancelToken: cancelToken);
        } catch (fallbackError) {
          debugPrint(
              '❌ Fallback Provider ($fallbackProvider) also failed: $fallbackError');
        }
      }

      return ImageGenerationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Helper to execute the specific generation method
  Future<ImageGenerationResult> _executeGeneration(
      String provider, String prompt,
      {required String style, required String aspectRatio, dio.CancelToken? cancelToken}) async {
    switch (provider) {
      case providerMock:
        return await _generateMockImage(prompt, style: style);
      case providerGemini:
        return await _generateWithGemini(prompt, style: style, cancelToken: cancelToken);
      case providerStability:
        return await _generateWithStability(prompt,
            style: style, aspectRatio: aspectRatio, cancelToken: cancelToken);
      case providerDalle:
        return await _generateWithDalle(prompt, style: style, cancelToken: cancelToken);
      default:
        return await _generateMockImage(prompt, style: style);
    }
  }

  /// 🖌️ توليد صورة دمج احترافية (Inpainting) بناءً على قالب وحصيرة
  Future<ImageGenerationResult> generateInpaintingComposite({
    required File imageFile,
    required File maskFile,
    required String prompt,
  }) async {
    final imageBytes = await imageFile.readAsBytes();
    final maskBytes = await maskFile.readAsBytes();
    
    return await _editWithStabilityInpaintingV2(
      imageBytes: imageBytes,
      maskBytes: maskBytes,
      prompt: prompt,
    );
  }

  /// 🧪 Mock Image Generator (Demo Mode)
  /// Returns a placeholder image for UI development
  Future<ImageGenerationResult> _generateMockImage(
    String prompt, {
    String style = 'cinematic',
  }) async {
    // In production, mock generation is disabled.
    if (!demoMode && !kDebugMode) {
      return ImageGenerationResult(
          success: false, error: "Demo mode is disabled");
    }

    // Generate a unique seed based on prompt
    final seed = prompt.hashCode.abs() % 1000;

    // Use Picsum for random placeholder images
    // Or Unsplash source for more relevant images
    final imageUrls = [
      'https://picsum.photos/seed/$seed/1024/1024',
      'https://source.unsplash.com/1024x1024/?${Uri.encodeComponent(_extractKeywords(prompt))}',
    ];

    // Download and save locally
    try {
      final response = await http.get(Uri.parse(imageUrls[0]));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = 'ai_gen_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        return ImageGenerationResult(
          success: true,
          localPath: file.path,
          imageUrl: imageUrls[0],
          prompt: prompt,
          provider: providerMock,
          metadata: {
            'style': style,
            'seed': seed,
            'demo_mode': true,
          },
        );
      }
    } catch (e) {
      debugPrint('Mock image download failed: $e');
    }

    // Fallback: return URL only
    return ImageGenerationResult(
      success: true,
      imageUrl: imageUrls[0],
      prompt: prompt,
      provider: providerMock,
      metadata: {'demo_mode': true},
    );
  }

  /// 🌟 Gemini Imagen API
  Future<ImageGenerationResult> _generateWithGemini(
    String prompt, {
    String style = 'cinematic',
    dio.CancelToken? cancelToken,
  }) async {
    // Get API key from settings
    final settings = Get.find<SettingsController>();
    final apiKey = settings.getApiKey(ProviderType.gemini);

    if (apiKey.isEmpty) {
      return ImageGenerationResult(
        success: false,
        error: 'مفتاح Gemini API غير موجود',
      );
    }

    // Enhanced prompt with style
    final enhancedPrompt = _enhancePrompt(prompt, style);

    try {
      // استخدام المحرك المركزي
      final response = await _apiClient.request(
        url:
            'https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:predict',
        method: 'POST',
        providerName: 'gemini-image',
        queryParameters: {'key': apiKey},
        headers: {'Content-Type': 'application/json'},
        cancelToken: cancelToken,
        data: {
          'instances': [
            {'prompt': enhancedPrompt}
          ],
          'parameters': {
            'sampleCount': 1,
            'aspectRatio': '1:1',
            'safetySetting': 'block_some',
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final predictions = data['predictions'] as List?;

        if (predictions != null && predictions.isNotEmpty) {
          final base64Image = predictions[0]['bytesBase64Encoded'] as String?;
          if (base64Image != null) {
            // Save to local file
            final bytes = base64Decode(base64Image);
            final dir = await getTemporaryDirectory();
            final fileName =
                'gemini_${DateTime.now().millisecondsSinceEpoch}.png';
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(bytes);

            return ImageGenerationResult(
              success: true,
              localPath: file.path,
              prompt: prompt,
              provider: providerGemini,
            );
          }
        }
      }

      return ImageGenerationResult(
        success: false,
        error: 'فشل توليد الصورة: ${response.statusCode}',
      );
    } on EnterpriseApiException catch (e) {
      return ImageGenerationResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      return ImageGenerationResult(
        success: false,
        error: 'خطأ في Gemini: $e',
      );
    }
  }

  /// 🎨 Stability AI (Stable Diffusion)
  Future<ImageGenerationResult> _generateWithStability(
    String prompt, {
    String style = 'cinematic',
    String aspectRatio = '1:1',
    dio.CancelToken? cancelToken,
  }) async {
    // Get API key from settings
    final settings = Get.find<SettingsController>();
    final apiKey = settings.getApiKey(ProviderType.stability);

    if (apiKey.isEmpty) {
      return ImageGenerationResult(
        success: false,
        error: 'مفتاح Stability API غير موجود',
      );
    }

    final enhancedPrompt = _enhancePrompt(prompt, style);

    try {
      final response = await _apiClient.request(
        url:
            'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image',
        method: 'POST',
        providerName: 'stability',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
        cancelToken: cancelToken,
        data: {
          'text_prompts': [
            {'text': enhancedPrompt, 'weight': 1}
          ],
          'cfg_scale': 7,
          'height': 1024,
          'width': 1024,
          'samples': 1,
          'steps': 30,
        },
      );

      if (response.statusCode == 200) {
        final artifacts = response.data['artifacts'] as List?;
        if (artifacts != null && artifacts.isNotEmpty) {
          final base64Image = artifacts[0]['base64'] as String?;
          if (base64Image != null) {
            final bytes = base64Decode(base64Image);
            final dir = await getTemporaryDirectory();
            final fileName =
                'stability_${DateTime.now().millisecondsSinceEpoch}.png';
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(bytes);

            return ImageGenerationResult(
              success: true,
              localPath: file.path,
              prompt: prompt,
              provider: providerStability,
            );
          }
        }
      }

      return ImageGenerationResult(
        success: false,
        error: 'فشل Stability AI: ${response.statusCode}',
      );
    } on EnterpriseApiException catch (e) {
      return ImageGenerationResult(success: false, error: e.message);
    } catch (e) {
      return ImageGenerationResult(
        success: false,
        error: 'خطأ في Stability: $e',
      );
    }
  }

  /// 🎭 OpenAI DALL·E
  Future<ImageGenerationResult> _generateWithDalle(
    String prompt, {
    String style = 'cinematic',
    dio.CancelToken? cancelToken,
  }) async {
    final settings = Get.find<SettingsController>();
    final apiKey = settings.getApiKey(ProviderType.openai);

    if (apiKey.isEmpty) {
      return ImageGenerationResult(
        success: false,
        error: 'مفتاح OpenAI API غير موجود',
      );
    }

    final enhancedPrompt = _enhancePrompt(prompt, style);

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'dall-e-3',
          'prompt': enhancedPrompt,
          'n': 1,
          'size': '1024x1024',
          'quality': 'hd',
          'style': style == 'cinematic' ? 'vivid' : 'natural',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['data'] as List?;

        if (images != null && images.isNotEmpty) {
          final imageUrl = images[0]['url'] as String?;
          if (imageUrl != null) {
            // Download and save locally
            final imageResponse = await http.get(Uri.parse(imageUrl));
            if (imageResponse.statusCode == 200) {
              final dir = await getTemporaryDirectory();
              final fileName =
                  'dalle_${DateTime.now().millisecondsSinceEpoch}.png';
              final file = File('${dir.path}/$fileName');
              await file.writeAsBytes(imageResponse.bodyBytes);

              return ImageGenerationResult(
                success: true,
                localPath: file.path,
                imageUrl: imageUrl,
                prompt: prompt,
                provider: providerDalle,
              );
            }
          }
        }
      }

      return ImageGenerationResult(
        success: false,
        error: 'فشل DALL·E: ${response.statusCode}',
      );
    } catch (e) {
      return ImageGenerationResult(
        success: false,
        error: 'خطأ في DALL·E: $e',
      );
    }
  }

  /// 🎨 Enhance prompt with style modifiers (Refined to avoid duplication)
  String _enhancePrompt(String prompt, String style) {
    final styleModifiers = {
      'cinematic':
          'cinematic lighting, dramatic composition, film grain, 35mm photography, masterpiece, highly detailed, 8k uhd',
      'anime':
          'anime style, vibrant colors, Studio Ghibli inspired, beautiful artwork, high resolution',
      'realistic':
          'photorealistic, 8k uhd, highly detailed, professional photography, sharp focus',
      'artistic':
          'oil painting style, artistic, expressive brushstrokes, gallery quality, fine art',
      'yemeni':
          'traditional Yemeni architecture, Old Sanaa, ancient buildings, warm golden light, authentic Middle Eastern atmosphere, 8k',
    };

    final modifier = styleModifiers[style] ?? styleModifiers['cinematic']!;
    
    // 🔥 تذكية بسيطة: إزالة الكلمات المتكررة لضمان أفضل نتيجة من الذكاء الاصطناعي
    final List<String> userWords = prompt.toLowerCase().split(RegExp(r'[, ]+'));
    final List<String> modifierParts = modifier.split(', ');
    
    final List<String> filteredModifiers = modifierParts.where((part) {
      final String firstWord = part.split(' ').first.toLowerCase();
      return !userWords.contains(firstWord);
    }).toList();

    if (filteredModifiers.isEmpty) return prompt;

    return '$prompt, ${filteredModifiers.join(', ')}';
  }

  /// 🔍 Extract keywords from prompt for fallback image search
  String _extractKeywords(String prompt) {
    // Simple keyword extraction
    final words = prompt
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.length > 3)
        .take(3)
        .join(',');
    return words.isNotEmpty ? words : 'art,creative';
  }

  /// 🔄 Switch provider
  void switchProvider(String provider) {
    if ([providerGemini, providerStability, providerDalle, providerMock]
        .contains(provider)) {
      currentProvider = provider;
      demoMode = provider == providerMock;
    }
  }

  /// 📋 Get available providers
  List<Map<String, String>> getAvailableProviders() {
    return [
      {'id': providerMock, 'name': 'Demo Mode', 'icon': '🧪'},
      {'id': providerGemini, 'name': 'Gemini Imagen', 'icon': '🌟'},
      {'id': providerStability, 'name': 'Stability AI', 'icon': '🎨'},
      {'id': providerDalle, 'name': 'DALL·E 3', 'icon': '🎭'},
    ];
  }

  /// 🧠 Smart Auto-Selection Logic
  Future<String> _smartSelectProvider() async {
    try {
      if (!Get.isRegistered<SettingsController>()) return currentProvider;
      final settings = Get.find<SettingsController>();

      // 1. Stability AI (Best Quality for Images)
      if (settings.getApiKey(ProviderType.stability).isNotEmpty) {
        return providerStability;
      }

      // 2. Gemini Imagen (Good Quality, often free tier)
      if (settings.getApiKey(ProviderType.gemini).isNotEmpty) {
        return providerGemini;
      }

      // 3. DALL·E 3 (High Quality, Expensive)
      if (settings.getApiKey(ProviderType.openai).isNotEmpty) {
        return providerDalle;
      }
    } catch (e) {
      debugPrint("⚠️ Smart Provider Selection Error: $e");
    }

    // Fallback based on current default or Mock if nothing configured
    return currentProvider == providerMock ? providerMock : currentProvider;
  }

  /// 🪄 تحسين البرومبت وتحويله للإنجليزية باحترافية مع الحفاظ على شكل المنتج
  Future<String> enhanceProductPrompt(String userPrompt, File imageFile, {bool isTemplateFusion = false, dio.CancelToken? cancelToken}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final settings = Get.find<SettingsController>();
      final apiKey = settings.getApiKey(ProviderType.gemini);

      if (apiKey.isEmpty) {
        debugPrint('⚠️ مفتاح Gemini غير موجود، سيتم استخدام النص الأصلي');
        return userPrompt;
      }

      const systemPrompt = """
You are a High-End Product Photography Prompt Engineer.
Your mission is to generate a prompt that transforms the background while keeping the PRODUCT IDENTICAL.

RULES:
1. (STRICT PRODUCT PRESERVATION): The product in the original image MUST REMAIN UNTOUCHED. Do not change its shape, branding, color, or texture.
2. (SCENE ENHANCEMENT): Place the product in a professional setting described by the user.
3. (LIGHTING): Use cinematic studio lighting (Rim light, Softbox, High-end commercial style).
4. (QUALITY): Return ONLY the English prompt containing keywords like: 8k resolution, cinematic bokeh, photorealistic, sharp focus on product, masterpiece.
5. DO NOT include any introductory text.

User Input: """;

      final response = await AIProviderFactory.analyzeWithSmartFallback(bytes, "$systemPrompt $userPrompt", cancelToken: cancelToken);
      
      final String enhanced = response.description.trim();
      if (enhanced.isEmpty || enhanced.contains('غير متوفر') || enhanced.contains('Not Available')) {
        return userPrompt;
      }

      if (isTemplateFusion) {
        // ✅ قواعد الدمج الصارمة: إذا كان هناك قالب، امنع اختراع مشاهد جديدة تماماً
        return '''
        IMPORTANT: The background must be the EXACT digital template provided.
        DO NOT add kitchens, countertops, tables, or any new real-life scenes.
        Just place the product smoothly into the center of the design.
        (STRICT PRODUCT PRESERVATION): Keep the product exactly as it appears. DO NOT alter its shape or branding.
        (SCENE BLEND): $enhanced
        (TECHNICAL): 8k, photorealistic, sharp focus, perfectly matched lighting.
        ''';
      } else {
        // ✅ قواعد التصوير الفردي: للمنتج العادي في استوديو أو ببيئة معينة يطلبها المستخدم
        return '''
        (STRICT PRODUCT PRESERVATION): Keep the product exactly as it appears. DO NOT alter its shape or branding.
        (SCENE ENHANCEMENT): $enhanced
        (TECHNICAL): 8k, photorealistic, cinematic lighting, sharp focus.
        ''';
      }
    } catch (e) {
      debugPrint("⚠️ Error in prompt enhancement: $e");
      return userPrompt;
    }
  }
}

/// 📦 Image Generation Result
class ImageGenerationResult {
  final bool success;
  final String? localPath;
  final String? imageUrl;
  final String? prompt;
  final String? provider;
  final String? error;
  final Map<String, dynamic>? metadata;

  ImageGenerationResult({
    required this.success,
    this.localPath,
    this.imageUrl,
    this.prompt,
    this.provider,
    this.error,
    this.metadata,
  });

  /// Get file if available
  File? get file => localPath != null ? File(localPath!) : null;

  /// Check if we have a valid image
  bool get hasImage => localPath != null || imageUrl != null;
}

// =============================================================================
// 🎨 PRODUCT PHOTOGRAPHY v2.0 - Extension Methods
// =============================================================================

extension ProductPhotographyExtension on AiImageGenerationService {
  /// 🚀 الدالة الرئيسية: المايسترو الذي يدير العملية
  /// Complete workflow: Background Removal → Mask Generation → Stability AI Inpainting
  Future<ImageGenerationResult> generateProfessionalProductPhoto({
    required File originalImageFile,
    required String prompt,
    String? negativePrompt,
    bool isTemplateFusion = false,
    dio.CancelToken? cancelToken,
  }) async {
    try {
      if (kDebugMode) debugPrint('🚀 بدأت عملية التصوير الاحترافي...');

      // 🔥 0. تحسين الوصف (Prompt Enhancement) للمحرك
      String optimizedPrompt = prompt;
      try {
        debugPrint("✨ جاري تحسين الوصف عبر Gemini...");
        optimizedPrompt = await enhanceProductPrompt(prompt, originalImageFile, isTemplateFusion: isTemplateFusion, cancelToken: cancelToken);
        debugPrint("📝 الوصف المحسن: $optimizedPrompt");
      } catch (e) {
        debugPrint("⚠️ فشل تحسين الوصف: $e");
      }

      // أ. إزالة الخلفية أولاً (باستخدام remove.bg أو محلياً)
      if (kDebugMode) debugPrint('🧹 جاري إزالة الخلفية الأصلية...');
      final originalBytes = await originalImageFile.readAsBytes();
      final transparentImageBytes = await removeBackground(originalBytes);

      if (transparentImageBytes == null) {
        return ImageGenerationResult(
          success: false,
          error: 'فشل في إزالة الخلفية',
        );
      }

      // ج. استخراج القناع (Mask) في الخلفية لضمان سلاسة الواجهة
      if (kDebugMode) debugPrint('🎭 جاري استخراج القناع في الخلفية...');
      final maskBytes = await compute(ImageUtils.generateMaskTask, transparentImageBytes);

      if (maskBytes == null) {
        return ImageGenerationResult(
          success: false,
          error: 'فشل في إنشاء القناع (قد تكون الخلفية لم تزل)',
        );
      }

      // د. الإرسال لـ Stability AI للدمج (Inpainting)
      if (kDebugMode) debugPrint('🎨 جاري الدمج والرسم عبر Stability AI...');
      return await _editWithStabilityInpaintingV2(
        imageBytes: transparentImageBytes, 
        maskBytes: maskBytes, 
        prompt: optimizedPrompt,
        negativePrompt: negativePrompt,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Photo Process Error: $e');
      return ImageGenerationResult(
        success: false,
        error: e.toString(),
      );
    }
  }


  /// 🖼️ خدمة إزالة الخلفية (Remove.bg)
  Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    try {
      // Get API key from settings
      final settingsController = Get.find<SettingsController>();
      final apiKey = settingsController.getApiKey(ProviderType.removebg);

      if (apiKey.isEmpty) {
        debugPrint('⚠️ مفتاح remove.bg غير موجود');
        return null;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );

      request.headers['X-Api-Key'] = apiKey;
      request.files.add(http.MultipartFile.fromBytes(
        'image_file',
        imageBytes,
        filename: 'product.jpg',
      ));
      request.fields['size'] = 'auto';
      request.fields['format'] = 'png';

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        debugPrint('✅ تمت إزالة الخلفية بنجاح');
        return await response.stream.toBytes();
      } else if (response.statusCode == 402) {
        debugPrint('❌ خطأ remove.bg: 402 (رصيدك نفد). جاري استخدام Stability AI كبديل للطوارئ...');
        final stabResult = await _removeBackgroundWithStability(imageBytes);
        if (stabResult != null) return stabResult;
        
        debugPrint('❌ فشل خيار Stability AI (رصيد غير كافٍ). جاري استخدام ML Kit (المحلي والمجاني) كحل أخير...');
        return await _removeBackgroundWithLocalAi(imageBytes);
      } else {
        debugPrint('❌ خطأ remove.bg: ${response.statusCode}');
        
        // Always try local fallback on failure
        return await _removeBackgroundWithLocalAi(imageBytes);
      }
    } catch (e) {
      debugPrint('❌ استثناء في إزالة الخلفية: $e');
      return await _removeBackgroundWithLocalAi(imageBytes);
    }
  }

  /// 🧠 خدمة العزل المحلي (ML Kit) كحل أخير مجاني ومضمون
  Future<Uint8List?> _removeBackgroundWithLocalAi(Uint8List imageBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/temp_original_bg_$timestamp.png');
      await tempFile.writeAsBytes(imageBytes);
      
      final bgService = Get.find<BackgroundRemovalService>();
      final resultFile = await bgService.removeBackground(tempFile);
      
      if (resultFile != null) {
        debugPrint('✅ تمت إزالة الخلفية محلياً بنجاح عبر ML Kit!');
        return await resultFile.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint("❌ فشل العزل المحلي (ML Kit): $e");
      return null;
    }
  }


  /// 🛡️ خدمة الاسترداد والطوارئ (Stability AI Background Removal)
  Future<Uint8List?> _removeBackgroundWithStability(Uint8List imageBytes) async {
    try {
      final settingsController = Get.find<SettingsController>();
      final apiKey = settingsController.getApiKey(ProviderType.stability);
      
      if (apiKey.isEmpty) {
        throw Exception("فشل البديل: مفتاح Stability غير متوفر");
      }

      debugPrint('🚀 إرسال طلب Remove Background إلى Stability AI (التكلفة: 2 Credits)...');

      final response = await _apiClient.request(
        url: 'https://api.stability.ai/v2beta/stable-image/edit/remove-background',
        method: 'POST',
        providerName: 'stability-bg-removal',
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'image/*',
        },
        responseType: dio.ResponseType.bytes,
        data: dio.FormData.fromMap({
          'image': dio.MultipartFile.fromBytes(imageBytes,
              filename: 'fallback_product.png',
              contentType: http_parser.MediaType('image', 'png')),
          'output_format': 'webp',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ تمت إزالة الخلفية عبر محرك Stability البديل بنجاح!');
        return response.data; // responseType is bytes
      } else {
        debugPrint('❌ خطأ في المحرك البديل: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ فشل كلي في إزالة الخلفية البديلة: $e');
      return null;
    }
  }

  /// 🎨 خدمة التعديل (Stability AI Inpainting v2)
  Future<ImageGenerationResult> _editWithStabilityInpaintingV2({
    required Uint8List imageBytes,
    required Uint8List maskBytes,
    required String prompt,
    String? negativePrompt,
  }) async {
    try {
      // Get API key from settings
      final settingsController = Get.find<SettingsController>();
      final apiKey = settingsController.getApiKey(ProviderType.stability);

      if (apiKey.isEmpty) {
        return ImageGenerationResult(
          success: false,
          error: 'مفتاح Stability API غير موجود في الإعدادات',
        );
      }

      debugPrint('🚀 إرسال طلب Inpainting إلى Stability AI...');

      final response = await _apiClient.request(
        url: 'https://api.stability.ai/v2beta/stable-image/edit/inpaint',
        method: 'POST',
        providerName: 'stability-inpaint',
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'image/*',
        },
        responseType: dio.ResponseType.bytes,
        data: dio.FormData.fromMap({
          'image': dio.MultipartFile.fromBytes(imageBytes,
              filename: 'image.png',
              contentType: http_parser.MediaType('image', 'png')),
          'mask': dio.MultipartFile.fromBytes(maskBytes,
              filename: 'mask.png',
              contentType: http_parser.MediaType('image', 'png')),
          'prompt': prompt.trim(),
          'output_format': 'webp',
          'grow_mask': 3, // 🎯 Pass as int for strict type validation
        }),

      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/final_product_$timestamp.png');
        await file.writeAsBytes(
            response.data); // Dio returns bytes directly for image/*

        debugPrint('✅ تم إنشاء الصورة من المحرك المركزي بنجاح!');
        return ImageGenerationResult(
          success: true,
          localPath: file.path,
          provider: 'stability-inpainting-v2',
        );
      }

      return ImageGenerationResult(success: false, error: "فشل غير معروف");
    } on dio.DioException catch (e) {
      if (kDebugMode && e.response != null) {
        debugPrint('❌ Stability AI Error Response (${e.response?.statusCode}): ${e.response?.data}');
        
        // 🔍 Handle common 422 errors: 
        // e.g., {'name': 'invalid_parameter', 'errors': [{'image': 'dimensions must be between 64x64 and 2048x2048'}]}
      }
      return ImageGenerationResult(success: false, error: "خطأ في Stability AI: ${e.response?.statusCode}");
    } on EnterpriseApiException catch (e) {
      return ImageGenerationResult(success: false, error: e.message);
    } catch (e) {
      debugPrint('❌ استثناء في Stability Inpainting: $e');
      return ImageGenerationResult(success: false, error: e.toString());
    }
  }

}
