import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/log_service.dart';
import '../../../services/ai/gemini_audio_service.dart';
import '../../../services/ai/gemini_vision_service.dart';
import '../../../services/ffmpeg_service.dart';
import '../../../services/db_service.dart';
import '../../../core/models/chat_message.dart';
import '../../../ai/chat_smart_agent.dart';
import '../../ai_chat_screen.dart';

mixin ChatEnhancementMixin on State<AiChatScreen> {
  final GeminiAudioService geminiAudioService = Get.find<GeminiAudioService>();
  final GeminiVisionService geminiVisionService = GeminiVisionService();
  final ChatSmartAgent agent = Get.find<ChatSmartAgent>();
  
  // These should be available in the state (from ChatMediaMixin)
  // or abstract getters
  File? get selectedVideo;
  set selectedVideo(File? value);
  void scrollToBottom({bool force = false});

  Future<void> handleAudioEnhancement() async {
    final video = selectedVideo;
    if (video == null) return;

    LogService.info("Starting Audio Enhancement analysis", tag: 'ENHANCE');
    SnackBarUtils.showSmartSnackBar(
        title: "جاري التحليل",
        message: "يتم تحليل الصوت بواسطة المساعد الذكي...",
        isError: false);
    agent.isLoading.value = true;

    try {
      final analysis = await geminiAudioService.analyzeAudio(video);
      if (!mounted) return;
      agent.isLoading.value = false;

      // UI logic kept partially here as it's a bottom sheet
      Get.bottomSheet(
        _buildEnhancementOptions(analysis),
        isScrollControlled: true,
      );
    } catch (e) {
      if (!mounted) return;
      agent.isLoading.value = false;
      LogService.error("Audio Analysis failed: $e", tag: 'ENHANCE');
      SnackBarUtils.showSmartSnackBar(
          title: "خطأ", message: "فشل تحليل الصوت: $e", isError: true);
    }
  }

  Widget _buildEnhancementOptions(Map<String, dynamic> analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("تحليل الصوت: ${analysis['audio_type']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          if (analysis['voice_gender'] != null)
            Text("صوت: ${analysis['voice_gender']}",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const Divider(color: Colors.white12),
          const Text("التحسينات المقترحة:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: (analysis['suggested_actions'] as List).map<Widget>((action) {
              return ActionChip(
                avatar: const Icon(Icons.auto_fix_high, size: 16, color: Colors.white),
                label: Text(action['label']),
                backgroundColor: Colors.blueAccent,
                labelStyle: const TextStyle(color: Colors.white),
                onPressed: () {
                  Get.back();
                  applyAudioEnhancement(action['id'], analysis);
                },
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Future<void> applyAudioEnhancement(String actionId, Map<String, dynamic> analysis) async {
    final video = selectedVideo;
    if (video == null) return;

    agent.isLoading.value = true;
    LogService.info("Applying Audio filter: $actionId", tag: 'ENHANCE');
    SnackBarUtils.showSmartSnackBar(
        title: "جاري التحسين",
        message: "يقوم المساعد الذكي بتطبيق الفلاتر الصوتية...",
        isError: false);

    try {
      final filterString = await geminiAudioService.getAudioFilterCommand(actionId, analysis);
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/enhanced_audio_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final resultFile = await FfmpegService.applyAudioFilter(
          videoPath: video.path,
          outputPath: outputPath,
          filterComplex: filterString);

      if (!mounted) return;
      agent.isLoading.value = false;

      if (resultFile != null) {
        await Get.find<DBService>().insertRecord('generated_content', {
          'type': 'audio_enhancement',
          'prompt': actionId,
          'result': json.encode({
            'original_path': video.path,
            'enhanced_path': resultFile.path,
          }),
          'created_at': DateTime.now().toIso8601String(),
        });

        agent.history.add(ChatMessage.assistant(
          content: "تم تحسين الصوت بنجاح! 🎵✨\nتم تطبيق: $actionId",
        ).copyWith(
          state: MessageState.completed,
          videoUrl: resultFile.path,
        ));
        scrollToBottom();
        selectedVideo = null;
      } else {
        throw Exception("FFmpeg processing failed");
      }
    } catch (e) {
      if (!mounted) return;
      agent.isLoading.value = false;
      LogService.error("Audio Enhancement failed: $e", tag: 'ENHANCE');
      SnackBarUtils.showSmartSnackBar(
          title: "خطأ", message: "فشل التحسين: $e", isError: true);
    }
  }
}
