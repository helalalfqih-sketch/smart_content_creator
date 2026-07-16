import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:smart_content_creator/controllers/api_controller.dart';
import 'package:smart_content_creator/controllers/settings_controller.dart';
import 'package:smart_content_creator/core/models/api_provider.dart';
import 'package:smart_content_creator/services/ai/gemini_director_service.dart';
import 'package:smart_content_creator/services/ffmpeg_service.dart';
import 'package:smart_content_creator/services/kling_service.dart';
import 'package:smart_content_creator/services/higgsfield_service.dart';
import 'package:smart_content_creator/services/ai/openrouter_video_service.dart';
import 'package:smart_content_creator/services/firebase_storage_service.dart';
import 'package:smart_content_creator/core/utils/image_utils.dart';

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
    File? image,
    String? prompt,
    String? imageUrl,
    String? taskId,
    Function(PipelineStatus)? onStatusUpdate,
    Function(String)? onTaskIdReceived,
  }) async {
    try {
      // 1️⃣ Uploading / Pre-processing
      _isCancelled = false;

      try {
        // 🚀 Production Strategy: Compress and Upload
        if (image != null) {
          final compressedFile = await ImageUtils.compressForAi(image);
          final storage = Get.find<FirebaseStorageService>();
          imageUrl = await storage.uploadTemporaryImage(compressedFile);
        }

        if (imageUrl == null && image != null) {
          debugPrint(
              "⚠️ Firebase Storage failed (Null URL). Falling back to Base64...");
        }
      } catch (e) {
        debugPrint("⚠️ Firebase Storage Error: $e. Falling back to Base64...");
      }

      if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");

      // 2️⃣ & 3️⃣ Analysis & Scripting (Director Mode)
      onStatusUpdate?.call(PipelineStatus(
        state: PipelineState.analyzing,
        message: "جاري تحليل المنتج واقتراح فكرة الفيديو... 🧠",
        progress: 0.3,
      ));

      String videoPrompt = "منتج مميز لـ Car Seat Gap Filler";
      try {
        if (image != null) {
          final script = await _directorService.createScriptFromImage(image);
          final title = script['title'] ?? "منتج إبداعي";
          final hook = script['hook'] ?? "اكتشف الجديد";
          final outline = script['script_outline'] ?? "عرض تفصيلي للمميزات";

          videoPrompt = "$title - $hook\n$outline";

          onStatusUpdate?.call(PipelineStatus(
            state: PipelineState.scripting,
            message: "تم تجهيز الخطة: $title",
            progress: 0.5,
          ));
        }
      } catch (e) {
        if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");
        if (kDebugMode) {
          debugPrint("Director failed: $e, using default analysis");
        }
        if (image != null) {
          final bytes = await image.readAsBytes();
          final analysis = await _apiController.analyzeSelectedImage(
            bytes,
            "استخرج اسم المنتج، الغرض منه، وأهم 3 مميزات.",
          );
          videoPrompt = analysis.description.isNotEmpty
              ? analysis.description
              : "توليد فيديو إبداعي لمنتج عصري";
        }
      }

      // 4️⃣ AI Video Generation (Dynamic Provider)
      final settings = Get.find<SettingsController>();
      final activeProvider = settings.getActiveVideoProvider();
      final isHiggsfield = activeProvider == ProviderType.higgsfield;
      final isOpenRouter = activeProvider == ProviderType.openrouter;
      final providerName = activeProvider.displayName;

      onStatusUpdate?.call(PipelineStatus(
        state: PipelineState.animating,
        message: "جاري توليد الفيديو بالذكاء الاصطناعي ($providerName)...",
        progress: 0.6,
      ));
      if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");

      String activeTaskId = "";

      if (taskId != null && taskId.isNotEmpty) {
        activeTaskId = taskId;
      } else {
        if (isHiggsfield) {
          activeTaskId = await Get.find<HiggsfieldService>().generateVideo(
            videoPrompt,
            imagePath: imageUrl ?? image?.path ?? '',
          );
        } else if (isOpenRouter) {
          activeTaskId = await Get.find<OpenRouterVideoService>().generateVideo(
            videoPrompt,
            imagePath: imageUrl ?? image?.path ?? '',
          );
        } else {
          activeTaskId = await Get.find<KlingService>().generateVideo(
            videoPrompt,
            imagePath: imageUrl ?? image?.path ?? '',
          );
        }
        if (onTaskIdReceived != null) onTaskIdReceived(activeTaskId);
      }

      if (activeTaskId.isEmpty) {
        throw Exception("فشل $providerName في توليد المهمة");
      }

      // --- نظام الانتظار الذكي (Polling) ---
      String finalVideoUrl = "";
      bool isFinished = false;
      int attempts = 0;
      const maxAttempts = 120; // الحد الأقصى 10 دقائق (5 ثوانٍ * 120 محاولة)

      while (!isFinished && attempts < maxAttempts) {
        if (_isCancelled) throw Exception("تم إلغاء عملية التوليد.");
        attempts++;
        int percentage = (attempts / maxAttempts * 100).toInt();

        try {
          Map<String, dynamic> data;
          String state = "";

          if (isHiggsfield) {
            data = await Get.find<HiggsfieldService>()
                .checkTaskStatus(activeTaskId);
            state =
                data['status'] ?? data['state'] ?? data['task_status'] ?? "";

            if (state == 'succeed' ||
                state == 'completed' ||
                state == 'success') {
              final videoUrl =
                  data['video']?['url'] ?? data['url'] ?? data['video_url'];
              if (videoUrl != null) {
                finalVideoUrl = videoUrl;
                isFinished = true;
              } else {
                isFinished = false;
              }
            } else if (state == 'failed' || state == 'error') {
              final errorMsg =
                  data['message'] ?? data['task_status_msg'] ?? "خطأ غير معروف";
              throw Exception("فشل التوليد في Higgsfield AI: $errorMsg");
            }
          } else if (isOpenRouter) {
            data = await Get.find<OpenRouterVideoService>()
                .checkTaskStatus(activeTaskId);
            state = data['status'] ?? "";

            if (state == 'completed') {
              final urls = data['unsigned_urls'] as List?;
              if (urls != null && urls.isNotEmpty) {
                finalVideoUrl = urls[0].toString();
              } else {
                finalVideoUrl = data['content_url'] ?? data['url'] ?? "";
              }
              isFinished = finalVideoUrl.isNotEmpty;
            } else if (state == 'failed') {
              throw Exception("فشل التوليد في OpenRouter: ${data['error']}");
            }
          } else {
            data = await Get.find<KlingService>().checkTaskStatus(activeTaskId);
            state = data['task_status'] ?? "";

            if (state == 'succeed') {
              final taskResult = data['task_result'];
              final videos =
                  taskResult != null ? (taskResult['videos'] as List?) : null;

              if (videos != null && videos.isNotEmpty) {
                finalVideoUrl = videos[0]['url'] ?? "";
              }
              isFinished = true;
            } else if (state == 'failed') {
              final errorMsg = data['task_status_msg'] ?? "خطأ غير معروف";
              throw Exception("فشل التوليد في Kling AI: $errorMsg");
            }
          }

          if (!isFinished &&
              !state.contains('fail') &&
              !state.contains('error')) {
            onStatusUpdate?.call(PipelineStatus(
              state: PipelineState.animating,
              message: "جاري التوليد عبر $providerName... ($percentage/100) ⏳",
              progress: 0.6 + (percentage / 100 * 0.3),
            ));
            await Future.delayed(const Duration(seconds: 5));
          }
        } catch (e) {
          // 🔐 Non-retryable: invalid credentials / unauthorized
          final err = e.toString();
          if (err.contains('Invalid credentials') ||
              err.contains('Unauthorized') ||
              err.contains('مفتاح الـ API غير صالح') ||
              err.contains('غير صالح') && err.contains('API')) {
            throw Exception(
                'فشل التحقق من حالة المهمة: بيانات الدخول غير صحيحة لمزوّد $providerName. تأكد من صحة المفتاح (Secret Key) في الإعدادات.');
          }
          if (e.toString().contains('فشل التوليد في')) rethrow;
          if (kDebugMode) {
            debugPrint(
                "⚠️ Polling glitch (Attempt $attempts): $e. Retrying...");
          }
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      if (finalVideoUrl.isEmpty) {
        throw Exception("انتهى وقت الانتظار لتوليد الفيديو في $providerName.");
      }

      // 5️⃣ Completed
      onStatusUpdate?.call(PipelineStatus(
        state: PipelineState.completed,
        message: "تم تجهيز الفيديو بنجاح! ✅",
        progress: 1.0,
      ));

      return finalVideoUrl;
    } catch (e) {
      onStatusUpdate?.call(PipelineStatus(
        state: PipelineState.failed,
        message: "فشلت العملية: $e",
        progress: 0.0,
      ));
      rethrow;
    }
  }
}
