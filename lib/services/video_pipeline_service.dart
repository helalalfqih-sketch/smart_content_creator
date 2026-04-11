import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:get/get.dart';
import '../controllers/api_controller.dart';
import '../services/ai/gemini_director_service.dart';
import '../services/ffmpeg_service.dart';
import 'kling_service.dart';

enum PipelineState {
  idle,
  uploading,
  analyzing,
  scripting,
  generatingImages,
  animating,
  merging,
  completed,
  failed
}

class PipelineStatus {
  final PipelineState state;
  final String message;
  final double progress;

  PipelineStatus({
    required this.state,
    required this.message,
    this.progress = 0.0,
  });
}

class VideoPipelineService extends GetxService {
  final ApiController _apiController = Get.find<ApiController>();
  final GeminiDirectorService _directorService =
      Get.put(GeminiDirectorService());

  bool _isCancelled = false;

  void cancelProcess() {
    _isCancelled = true;
    FfmpegService.cancelAll();
  }

  Future<String> generateVideo({
    required File image,
    required Function(PipelineStatus) onStatusUpdate,
  }) async {
    try {
      // 1️⃣ Uploading / Pre-processing
      _isCancelled = false;

      onStatusUpdate(PipelineStatus(
        state: PipelineState.uploading,
        message: "جاري رفع الصورة وتجهيز البيئة...",
        progress: 0.1,
      ));
      await Future.delayed(const Duration(seconds: 1));
      if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");

      // 2️⃣ & 3️⃣ Analysis & Scripting (Director Mode)
      onStatusUpdate(PipelineStatus(
        state: PipelineState.analyzing,
        message: "المخرج الذكي: تحليل المشهد وكتابة السيناريو...",
        progress: 0.35,
      ));

      String videoPrompt = "منتج مميز";
      try {
        final script = await _directorService.createScriptFromImage(image);
        videoPrompt =
            "${script['title']} - ${script['hook']}\n${script['script_outline']}";

        onStatusUpdate(PipelineStatus(
          state: PipelineState.scripting,
          message: "تم تجهيز الخطة: ${script['title']}",
          progress: 0.5,
        ));
      } catch (e) {
        if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");
        if (kDebugMode) {
          debugPrint("Director failed: $e, using default analysis");
        }
        final bytes = await image.readAsBytes();
        final analysis = await _apiController.analyzeSelectedImage(
          bytes,
          "استخرج اسم المنتج، الغرض منه، وأهم 3 مميزات.",
        );
        videoPrompt = analysis.description;
      }

      // 4️⃣ AI Video Generation (Kling AI)
      onStatusUpdate(PipelineStatus(
        state: PipelineState.animating,
        message: "جاري توليد الفيديو بالذكاء الاصطناعي (Kling AI)...",
        progress: 0.6,
      ));
      if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");

      // ✅ استخدام Kling AI الحقيقي بدلاً من Demo Mock
      final klingService = Get.find<KlingService>();
      final videoUrl = await klingService.generateVideoFromText(
        videoPrompt,
        imagePath: image.path,
      );

      if (videoUrl.isEmpty) {
        throw Exception("فشل Kling AI في توليد الفيديو");
      }

      // 5️⃣ Completed
      onStatusUpdate(PipelineStatus(
        state: PipelineState.completed,
        message: "تم تجهيز الفيديو بنجاح! ✅",
        progress: 1.0,
      ));

      return videoUrl;
    } catch (e) {
      onStatusUpdate(PipelineStatus(
        state: PipelineState.failed,
        message: "فشلت العملية: $e",
        progress: 0.0,
      ));
      rethrow;
    }
  }
}
