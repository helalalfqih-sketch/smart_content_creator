import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';

import 'package:path/path.dart' as p;
import '../ai_provider.dart';
import '../../core/models/api_provider.dart';
import '../../controllers/settings_controller.dart';
import '../gemini_service.dart';
import '../../services/ffmpeg_service.dart';
import '../../core/utils/json_utils.dart';

class GeminiVisionService {
  
  GeminiService get _geminiService {
    return AIProviderFactory.getServiceByType(ProviderType.gemini) as GeminiService;
  }

  String get _apiKey {
    final settings = Get.find<SettingsController>();
    return settings.getApiKey(ProviderType.gemini);
  }

  /// Analyzes video by extracting 3 key frames (Start, Middle, End)
  Future<Map<String, dynamic>> analyzeVideo(File videoFile) async {
    final frames = await _extractKeyFrames(videoFile);
    if (frames.isEmpty) throw Exception("Could not extract frames from video");

    final prompt = """
      قم بتحليل هذا الفيديو (من خلال هذه اللقطات).
      أحتاج الناتج بتنسيق JSON:
      {
        "summary": "ملخص شامل للفيديو",
        "mood": "جو الفيديو",
        "keywords": ["tag1", "tag2"],
        "category": "تصنيف",
        "engagement_score": 8
      }
    """;
    
    final result = await _geminiService.analyzeBatchImages(frames, prompt, apiKey: _apiKey);
    return JsonUtils.parseSafe(result.description);
  }

  /// Extracts scenes by taking more frames (e.g. every 5 seconds or 5 frames total)
  Future<List<Map<String, dynamic>>> extractScenes(File videoFile) async {
    // For scenes, we take more frames, e.g., 5 frames
    final frames = await _extractKeyFrames(videoFile, count: 5);
    
    final prompt = """
      هذه لقطات متتابعة من فيديو. حدد المشاهد (Scenes) وتغيراتها.
      أحتاج قائمة JSON:
      [
        {
          "timestamp": "approximate time",
          "description": "وصف المشهد",
          "significance": "أهمية المشهد"
        }
      ]
    """;

    final result = await _geminiService.analyzeBatchImages(frames, prompt, apiKey: _apiKey);
    return JsonUtils.parseListSafe(result.description).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> suggestOverlays(File videoFile) async {
    final frames = await _extractKeyFrames(videoFile, count: 3);
    final prompt = """
      بناءً على محتوى الفيديو، اقترح نصوصًا (Overlays) لزيادة التفاعل.
      الناتج JSON:
      [
         { "text": "...", "position": "center", "color": "#FFFFFF", "start_time": 0 }
      ]
    """;
    
    final result = await _geminiService.analyzeBatchImages(frames, prompt, apiKey: _apiKey);
    return JsonUtils.parseListSafe(result.description).cast<Map<String, dynamic>>();
  }

  Future<List<String>> suggestMusic(File videoFile) async {
    final frames = await _extractKeyFrames(videoFile);
    final prompt = """
      اقترح 5 مقطوعات موسيقى تناسب جو الفيديو.
      الناتج JSON قائمة نصوص.
    """;
    
    final result = await _geminiService.analyzeBatchImages(frames, prompt, apiKey: _apiKey);
    return JsonUtils.parseListSafe(result.description).map((e) => e.toString()).toList();
  }

  /// 🤖 Stage 1: Analyze Video Quality
  Future<Map<String, dynamic>> analyzeVideoQuality(File videoFile) async {
    final frames = await _extractKeyFrames(videoFile, count: 4); // More frames for better technical analysis
    if (frames.isEmpty) throw Exception("Could not extract frames for analysis");

    final prompt = """
      أنت خبير في جودة الفيديو السينمائية. حلل لقطات هذا الفيديو من الناحية التقنية.
      أريد تقريراً دقيقاً بتنسيق JSON يحتوي على الحقول التالية فقط:
      {
        "noise": "low/medium/high",
        "brightness": "low/normal/high",
        "contrast": "flat/normal/strong",
        "sharpness": "blurry/normal/sharp",
        "resolution": "estimated (e.g. 720p)",
        "needs_upscale": true/false,
        "cinematic_style": "recommended style (e.g. vivid, dramatic, natural)"
      }
    """;
    
    final result = await _geminiService.analyzeBatchImages(frames, prompt, apiKey: _apiKey);
    return JsonUtils.parseSafe(result.description);
  }

  /// 🖼️ NEW: Generic Image Analysis with Custom Prompt
  Future<AiResult> analyzeImageWithPrompt(File image, {required String prompt}) async {
    final bytes = await image.readAsBytes();
    return await _geminiService.analyzeImage(bytes, prompt, apiKey: _apiKey);
  }

  /// 🧠 Stage 2: Build FFmpeg Enhancement Filters
  Future<String> buildEnhancementFilters(Map<String, dynamic> analysis) async {
    final prompt = """
      بناءً على تحليل جودة الفيديو التالي:
      $analysis

      قم بإنشاء سلسلة فلاتر (Filter Chain) صالحة لمحرك FFmpeg (داخل وسيط -vf) لتحسين الفيديو بجودة سينمائية 4K.
      المطلوب تحسين ذكي وهادئ (Subtle):
      1. إزالة الضوضاء (Denoise): استخدم hqdn3d بقيم منخفضة (مثلاً 1.0:1.0:3:3) لتجنب تشويه التفاصيل، أو استخدم nlmeans للنتائج الأكثر احترافية.
      2. زيادة الحدة (Sharpen): استخدم cas (Contrast Adaptive Sharpen) بدلاً من unsharp للحصول على تفاصيل طبيعية بدون هالات (مثلاً cas=0.5).
      3. تصحيح الألوان (Color): استخدم eq أو curves. تجنب المبالغة في التشبع (Saturation).
      4. رفع الدقة (Upscale): ارفع إلى 3840:2160 باستخدام flags=lanczos مع المحافظة على نسبة العرض (force_original_aspect_ratio=increase) وقص الزوائد (crop).

      شروط الرد:
      - أعد فقط نص سلسلة الفلاتر (filter chain) بدون أي شرح أو علامات اقتباس.
      - مثال مثالي: hqdn3d=1.0:1.0:3:3,cas=0.5,eq=contrast=1.05:saturation=1.1,scale=3840:2160:force_original_aspect_ratio=increase,crop=3840:2160
    """;

    final result = await _geminiService.generateText(prompt, apiKey: _apiKey);
    return result.description.trim();
  }

  /// 🎨 Stage 3: Build filters for specific Presets
  Future<String> buildPresetFilters(String presetName, Map<String, dynamic> analysis) async {
    final prompt = """
      بناءً على تحليل جودة الفيديو: $analysis
      قم بإنشاء سلسلة فلاتر FFmpeg لنمط: $presetName.
      
      الأنماط المتاحة:
      1. Cinematic Warm: ألوان دافئة (temperature)، تباين سينمائي، حدة طبيعية (cas=0.3).
      2. TikTok Vivid: ألوان حيوية، إضاءة معززة، حدة قوية (cas=0.8).
      3. YouTube Clean: وضوح عالي، إزالة ضوضاء ذكية، ألوان واقعية.
      4. Night Enhance: رفع السطوع في المناطق المظلمة (darker areas) مع منع نويز الظل، استخدام nlmeans.
      5. Old Film Restore: تصحيح الألوان الباهتة، إزالة التغبيش، موازنة اللون الأبيض.

      شروط الرد:
      - أعد فقط نص سلسلة الفلاتر (filter chain) بدون أي شرح أو علامات اقتباس.
      - تأكد من أن السلسلة نظيفة ولا تسبب تشويهاً (Distortion) في الصورة.
    """;

    final result = await _geminiService.generateText(prompt, apiKey: _apiKey);
    return result.description.trim();
  }

  // --- Helper: Frame Extraction ---
  Future<List<Uint8List>> _extractKeyFrames(File file, {int count = 3}) async {
    final frames = <Uint8List>[];
    
    // 🛡️ Standardizing on FFmpeg for both platforms to solve ImageReader/Buffer issues
    if (!await FfmpegService.isAvailable()) return [];

    // Note: To get precise frames at percentages, we'd need duration.
    // For now, we use the robust logic of extracting at 1s, 6s, 11s...
    // which is safe and avoids native buffer locks often seen in video_thumbnail.
    
    for (int i = 0; i < count; i++) {
      final sec = 1 + (i * 5); // 1s, 6s, 11s...
      final timestamp = "00:00:${sec.toString().padLeft(2, '0')}.000";
      final tempName = "frame_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final outPath = p.join(Directory.systemTemp.path, tempName);
      
      final f = await FfmpegService.extractFrame(
        videoPath: file.path, 
        outputPath: outPath, 
        timestamp: timestamp
      );
      
      if (f != null) {
        final b = await f.readAsBytes();
        frames.add(b);
        // 🛡️ Immediately delete the file to free system resources (satisfying 'close every image')
        try { await f.delete(); } catch (_) {}
      }
    }
    
    return frames;
  }

  // Helper methods removed in favor of JsonUtils
}
