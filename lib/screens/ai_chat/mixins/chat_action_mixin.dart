import 'dart:io';
import 'package:flutter/material.dart' hide Intent;
import 'package:get/get.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/log_service.dart';
import '../../../ai/ai_orchestrator.dart';
import '../../../ai/chat_smart_agent.dart';
import '../../../core/models/chat_message.dart';
import '../../ai_chat_screen.dart';
import 'chat_media_mixin.dart';

mixin ChatActionMixin on State<AiChatScreen> {
  TextEditingController get controller;
  ChatSmartAgent get agent;
  void scrollToBottom({bool force = false});
  ChatMessage? get replyingToMessage;
  set replyingToMessage(ChatMessage? value);

  Future<void> sendMessage() async {
    if (agent.isLoading.value) return; 
    
    final text = controller.text.trim();
    final media = this as ChatMediaMixin;
    
    if (media.isCompressingImage) return;

    final imgs = media.compressedImages.isNotEmpty ? media.compressedImages : media.selectedImages;
    final video = media.selectedVideo;
    
    if (text.isEmpty && imgs.isEmpty && video == null) return;

    if (text.isNotEmpty && text.length <= 6 && imgs.isEmpty && video == null) {
      agent.pipelineMessage.value = "";
    } else {
      agent.pipelineMessage.value = "انتضر ثواني... 🤔";
    }
    agent.pipelineProgress.value = 0.05;

    controller.clear();
    setState(() {
      media.selectedImages = [];
      media.compressedImages = [];
      media.selectedVideo = null;
    });

    scrollToBottom(force: true);

    try {
      if (!await hasInternet()) {
        agent.isLoading.value = false;
        SnackBarUtils.showSmartSnackBar(title: '📵 لا يوجد اتصال', message: 'تحقق من الشبكة', isError: true);
        return;
      }

      final orchestrator = Get.find<AIOrchestrator>();

      if (imgs.isNotEmpty && media.preAnalysisResult != null) {
        await agent.completeWithPreAnalysis(
            content: text.isEmpty ? "تحليل الصورة" : text,
            image: imgs.first,
            images: imgs,
            preResult: media.preAnalysisResult!,
            replyToId: replyingToMessage?.id,
            replyToContent: replyingToMessage?.content,
            replyToRole: replyingToMessage?.role);
      } else {
        await orchestrator.processUserInput(
          text: text,
          images: imgs,
          video: video,
          replyToId: replyingToMessage?.id,
          replyToContent: replyingToMessage?.content,
          replyToRole: replyingToMessage?.role,
        );
      }
    } catch (e) {
      handleError(e);
    }

    if (mounted) {
      agent.isLoading.value = false;
      agent.pipelineMessage.value = "";
      agent.pipelineProgress.value = 0.0;
      scrollToBottom();
    }
  }

  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String truncate(String text, {int maxLength = 150}) {
    if (text.length <= maxLength) return text;
    return "${text.substring(0, maxLength)}...";
  }

  bool canReplyTo(ChatMessage msg) {
    if (msg.isError) return false;
    if (msg.state != MessageState.completed) return false;
    final content = msg.content.trim();
    if (content.isEmpty) return false;
    if (msg.type == 'action_menu') return false;
    return true;
  }

  void handleError(dynamic e) {
    final errorMsg = e.toString();
    LogService.error("Chat Error: $errorMsg", tag: 'CHAT');
    String title = '❌ خطأ غير متوقع';
    String message = 'التفاصيل: $errorMsg';

    if (errorMsg.contains('SocketException') ||
        errorMsg.contains('Failed host lookup') ||
        errorMsg.contains('No address')) {
      title = '📵 انقطع الاتصال بالإنترنت';
      message = 'تأكد من الشبكة وحاول مرة أخرى';
    } else if (errorMsg.contains('404') ||
        errorMsg.contains('403') ||
        errorMsg.contains('Quota') ||
        errorMsg.contains('Model not found')) {
      title = '⚠️ خدمة الذكاء غير متاحة';
      message = 'سنحاول لاحقاً أو استخدم مزوداً آخر';
    }
    
    SnackBarUtils.showSmartSnackBar(title: title, message: message, isError: true);
  }
}
