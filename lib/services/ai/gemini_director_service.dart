import 'dart:io';
import 'package:get/get.dart';
import '../ai_provider.dart';
import '../../core/models/api_provider.dart';
import '../../controllers/settings_controller.dart';
import '../gemini_service.dart';
import '../../core/utils/json_utils.dart';

class GeminiDirectorService {
  
  GeminiService get _geminiService {
    return AIProviderFactory.getServiceByType(ProviderType.gemini) as GeminiService;
  }

  String get _apiKey {
    final settings = Get.find<SettingsController>();
    return settings.getApiKey(ProviderType.gemini);
  }

  Future<Map<String, dynamic>> createScriptFromDescription(String description) async {
    final prompt = """
      أنت مخرج فيديو محترف.
      قم بتحويل هذا الوصف: "$description" إلى خطة فيديو كاملة (Script).
      
      أحتاج الناتج بتنسيق JSON:
      {
        "title": "عنوان الفيديو",
        "scenes": [
          {
            "scene_number": 1,
            "visual": "وصف المشهد البصري",
            "audio": "التعليق الصوتي أو الحوار",
            "duration": "المدة بالثواني"
          }
        ],
        "music_mood": "جو الموسيقى",
        "estimated_duration": "المدة الكلية"
      }
    """;
    
    final result = await _geminiService.generateText(prompt, apiKey: _apiKey);
    return _parseJson(result.description);
  }

  Future<Map<String, dynamic>> createScriptFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final prompt = """
      أنت مخرج إبداعي.
      انظر إلى هذه الصورة وتخيل قصة أو إعلان فيديو يبدأ منها.
      
      أحتاج الناتج بتنسيق JSON خطة فيديو complète:
      {
        "title": "عنوان مقترح",
        "hook": "جملة افتتاحية قوية",
        "script_outline": "ملخص السيناريو",
        "scenes": [
           { "visual": "...", "audio": "..." }
        ]
      }
    """;

    final result = await _geminiService.generateMarketingAd(prompt, imageBytes: bytes, apiKey: _apiKey);
    return _parseJson(result);
  }

  Future<Map<String, dynamic>> transformToViral(File videoFile) async {
    final prompt = """
      أنت خبير في ترندات TikTok و Instagram Reels.
      حلل فكرة هذا الفيديو واقترح خطة تحويله إلى "Viral Trend".
      
      أعد الناتج بصيغة JSON:
      {
        "strategy": "وصف الاستراتيجية",
        "preset": "Cinematic/Vivid/...",
        "hooks": ["نص 1", "نص 2"],
        "music_type": "مثلاً Trending Pop",
        "edit_instructions": "تعليمات للمحرر"
      }
    """;

    final result = await _geminiService.generateText(prompt, apiKey: _apiKey);
    return _parseJson(result.description);
  }

  Map<String, dynamic> _parseJson(String text) {
    return JsonUtils.parseSafe(text);
  }
}
