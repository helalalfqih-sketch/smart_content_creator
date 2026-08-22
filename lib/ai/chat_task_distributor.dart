import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import '../core/services/chat_state_service.dart';
import '../core/models/chat_message.dart';
import 'core/agent_models.dart';
import '../services/ai_backend_router.dart';

/// 🤖 ChatTaskDistributor (Sub-Agent)
/// المسؤول عن توزيع المهام المعقدة لمجموعات فرعية من "الوكلاء"
class ChatTaskDistributor extends GetxService {
  final ChatStateService _state = Get.find();
  AIBackendRouter get _aiRouter => Get.find<AIBackendRouter>();

  /// 🧠 Classify Intent for routing
  Future<AIIntentResult> getClassifiedIntent(String text, {File? image, dio.CancelToken? cancelToken}) async {
    // Use UnifiedAIService if available for intent classification
    try {
      final unifiedService = Get.find<dynamic>(tag: 'UnifiedAIService');
      return await unifiedService.classifyUserIntent(text, image: image, cancelToken: cancelToken);
    } catch (_) {
      return AIIntentResult(intent: 'TEXT', confidence: 0.5, parameters: {}, suggestedActions: []);
    }
  }

  /// 🍌 Image editing via Manus
  Future<ChatMessage> handleNanoBanana(File originalImage, String prompt) async {
    _updateStatus("جاري تعديل الصورة عبر Manus... 🍌", 0.2);
    try {
      final imageBytes = await originalImage.readAsBytes();
      final gatewayResponse = await _aiRouter.submitMediaTask(
        prompt: prompt,
        taskType: 'image_generation',
        imageBytes: imageBytes,
      );

      if (!gatewayResponse.success) {
        return ChatMessage.assistant(
          content: "فشل التعديل: ${gatewayResponse.error}",
          state: MessageState.error,
          productContext: _state.lastAnalyzedProduct.value,
        ).copyWith(isError: true);
      }

      if (gatewayResponse.taskId != null && gatewayResponse.isAsync) {
        final result = await _aiRouter.pollMediaUntilComplete(gatewayResponse.taskId!);
        if (result.isCompleted && result.hasImages) {
          _updateStatus("تم التعديل بنجاح! ✨", 1.0);
          return ChatMessage.assistant(
            content: "إليك النتيجة بعد التعديل:",
            type: 'generated_image',
            productContext: _state.lastAnalyzedProduct.value,
          ).copyWith(
            responseImageUrl: result.firstImageUrl,
            state: MessageState.completed,
          );
        }
      }

      return ChatMessage.assistant(
        content: "فشل التعديل: لم يتم إرجاع صورة",
        state: MessageState.error,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(isError: true);
    } catch (e) {
      return ChatMessage.assistant(
        content: "فشل التعديل: $e",
        state: MessageState.error,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(isError: true);
    } finally {
      _resetStatus();
    }
  }

  /// 🎬 Image-to-Video via Manus (Correction #11: Manus ONLY)
  Future<ChatMessage> handleImageToVideo(File image, String prompt) async {
    _updateStatus("Manus: تحضير الفيديو من الصورة... 🪄", 0.1);
    try {
      final imageBytes = await image.readAsBytes();
      final gatewayResponse = await _aiRouter.submitMediaTask(
        prompt: prompt,
        taskType: 'image_to_video',
        imageBytes: imageBytes,
      );

      if (!gatewayResponse.success) {
        return ChatMessage.assistant(
          content: "فشل توليد الفيديو: ${gatewayResponse.error}",
          state: MessageState.error,
          productContext: _state.lastAnalyzedProduct.value,
        ).copyWith(isError: true);
      }

      if (gatewayResponse.taskId != null && gatewayResponse.isAsync) {
        final result = await _aiRouter.pollMediaUntilComplete(
          gatewayResponse.taskId!,
          onStatusUpdate: (status) {
            _updateStatus(status.displayMessage, 0.5);
          },
        );

        if (result.isCompleted && result.hasVideos) {
          _updateStatus("تم تحريك الصورة بنجاح! ✨", 1.0);
          return ChatMessage.assistant(
            content: "إليك الفيديو الذي حولناه من الصورة:",
            type: 'video',
            videoUrl: result.firstVideoUrl,
            productContext: _state.lastAnalyzedProduct.value,
          ).copyWith(state: MessageState.completed);
        } else {
          return ChatMessage.assistant(
            content: "❌ ${result.error ?? 'فشل توليد الفيديو'}",
            state: MessageState.error,
            productContext: _state.lastAnalyzedProduct.value,
          ).copyWith(isError: true);
        }
      }

      return ChatMessage.assistant(
        content: "❌ لم يتم إرجاع معرف المهمة",
        state: MessageState.error,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(isError: true);
    } catch (e) {
      _updateStatus("فشل التوليد: $e", 0.0);
      return ChatMessage.assistant(
        content: "فشل توليد الفيديو: $e",
        state: MessageState.error,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(isError: true);
    } finally {
      _resetStatus();
    }
  }

  /// 🎬 Text-to-Video via Manus (Correction #11: Manus ONLY)
  Future<ChatMessage> handleTextToVideo(String prompt) async {
    _updateStatus("Manus: إخراج المشهد السينمائي... 🎬", 0.3);
    try {
      final gatewayResponse = await _aiRouter.submitMediaTask(
        prompt: prompt,
        taskType: 'video_generation',
      );

      if (!gatewayResponse.success) {
        return ChatMessage.assistant(
          content: "فشل الإنتاج: ${gatewayResponse.error}",
          state: MessageState.error,
          productContext: _state.lastAnalyzedProduct.value,
        ).copyWith(isError: true);
      }

      if (gatewayResponse.taskId != null && gatewayResponse.isAsync) {
        final result = await _aiRouter.pollMediaUntilComplete(
          gatewayResponse.taskId!,
          onStatusUpdate: (status) {
            _updateStatus(status.displayMessage, 0.5);
          },
        );

        if (result.isCompleted && result.hasVideos) {
          _updateStatus("تم الإنتاج السينمائي بنجاح! 🌟", 1.0);
          return ChatMessage.assistant(
            content: "إليك المشهد الذي أنتجناه من النص:",
            type: 'video',
            videoUrl: result.firstVideoUrl,
            productContext: _state.lastAnalyzedProduct.value,
          ).copyWith(state: MessageState.completed);
        } else {
          return ChatMessage.assistant(
            content: "❌ ${result.error ?? 'فشل الإنتاج'}",
            state: MessageState.error,
            productContext: _state.lastAnalyzedProduct.value,
          ).copyWith(isError: true);
        }
      }

      return ChatMessage.assistant(
        content: "❌ لم يتم إرجاع معرف المهمة",
        state: MessageState.error,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(isError: true);
    } catch (e) {
      _updateStatus("فشل الإنتاج: $e", 0.0);
      return ChatMessage.assistant(
        content: "فشل إنتاج الفيديو: $e",
        state: MessageState.error,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(isError: true);
    } finally {
      _resetStatus();
    }
  }

  void _updateStatus(String msg, double progress) {
    _state.isLoading.value = true;
    _state.updatePipeline(msg, progress);
  }

  void _resetStatus() {
    _state.isLoading.value = false;
    _state.updatePipeline("", 0.0);
  }
}
