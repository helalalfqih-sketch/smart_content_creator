import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import '../core/services/chat_state_service.dart';
import '../services/ai_image_generation_service.dart';
import '../services/unified_ai_service.dart';
import '../core/models/chat_message.dart';
import 'core/agent_models.dart';

/// 🤖 ChatTaskDistributor (Sub-Agent)
/// المسؤول عن توزيع المهام المعقدة لمجموعات فرعية من "الوكلاء"
class ChatTaskDistributor extends GetxService {
  final ChatStateService _state = Get.find();
  final AiImageGenerationService _imageService = Get.put(AiImageGenerationService());
  final UnifiedAIService _geminiService = Get.find();

  /// 🧠 Classify Intent for routing (Bridge to UnifiedAIService)
  Future<AIIntentResult> getClassifiedIntent(String text, {File? image, dio.CancelToken? cancelToken}) async {
    return await _geminiService.classifyUserIntent(text, cancelToken: cancelToken);
  }

  /// 🍌 معالجة مهام Nano Banana (تعديل الصور)
  Future<ChatMessage> handleNanoBanana(File originalImage, String prompt) async {
    _updateStatus("جاري استدعاء Nano Banana لتعديل الصورة... 🍌", 0.2);
    try {
      final result = await _imageService.generateImage(prompt);
      _updateStatus("تم التعديل بنجاح! ✨", 1.0);
      if (result.success && result.hasImage) {
        return ChatMessage.assistant(
          content: "إليك النتيجة بعد التعديل باستخدام Nano Banana:",
          type: 'image',
          productContext: _state.lastAnalyzedProduct.value,
        ).copyWith(
            mediaPath: result.localPath,
            image: result.file,
            state: MessageState.completed);
      } else {
        return ChatMessage.assistant(
                content: "فشل التعديل: ${result.error}",
                state: MessageState.error,
                productContext: _state.lastAnalyzedProduct.value)
            .copyWith(isError: true);
      }
    } catch (e) {
      return ChatMessage.assistant(
              content: "فشل التعديل: $e",
              state: MessageState.error,
              productContext: _state.lastAnalyzedProduct.value)
          .copyWith(isError: true);
    } finally {
      _resetStatus();
    }
  }

  /// 🎥 تحويل صورة إلى فيديو (Whisk with Veo 3)
  Future<ChatMessage> handleImageToVideo(File image, String prompt) async {
    _updateStatus("Whisk: تحضير المشهد من الصورة عبر Veo 3... 🪄", 0.1);
    try {
      final videoUrl = await _imageService.generateWithSelectedProvider('veo', prompt, originalImage: image);
      _updateStatus("تم تحريك الصورة بنجاح! ✨", 1.0);
      return ChatMessage.assistant(
        content: "إليك الفيديو الذي حولناه عبر Whisk:",
        type: 'video',
        videoUrl: videoUrl,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(state: MessageState.completed);
    } catch (e) {
      return ChatMessage.assistant(
              content: "فشل Whisk: $e",
              state: MessageState.error,
              productContext: _state.lastAnalyzedProduct.value)
          .copyWith(isError: true);
    } finally {
      _resetStatus();
    }
  }

  /// 🎬 إنشاء فيديو من النص (Flow with Veo 3 Fast)
  Future<ChatMessage> handleTextToVideo(String prompt) async {
    _updateStatus("Flow: إخراج المشهد السينمائي عبر Veo 3 Fast... 🎬", 0.3);
    try {
      final videoUrl = await _imageService.generateWithSelectedProvider('veo', prompt);
      _updateStatus("تم الإنتاج السينمائي بنجاح! 🌟", 1.0);
      return ChatMessage.assistant(
        content: "إليك المشهد الذي أنتجناه عبر Flow:",
        type: 'video',
        videoUrl: videoUrl,
        productContext: _state.lastAnalyzedProduct.value,
      ).copyWith(state: MessageState.completed);
    } catch (e) {
      return ChatMessage.assistant(
              content: "فشل Flow: $e",
              state: MessageState.error,
              productContext: _state.lastAnalyzedProduct.value)
          .copyWith(isError: true);
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
