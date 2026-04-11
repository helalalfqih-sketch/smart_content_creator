import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart' hide Intent;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/error_handler.dart';
import '../../../ai/chat_smart_agent.dart';
import '../../../ai/core/agent_models.dart';
import '../../ai_chat_screen.dart';

mixin ChatMediaMixin on State<AiChatScreen> {
  final ImagePicker picker = ImagePicker();
  final ChatSmartAgent agent = Get.find<ChatSmartAgent>();

  List<File> selectedImages = [];
  bool isCompressingImage = false;
  List<File> compressedImages = [];
  double processingProgress = 0.0;
  Timer? progressTimer;
  ProcessedInput? preAnalysisResult;
  File? selectedVideo;

  void scrollToBottom({bool force = false});

  Future<void> pickAnyMediaFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'mp4',
          'mov',
          'mp3',
          'wav',
          'aac'
        ],
      );

      if (result != null) {
        final List<File> pickedFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        for (var file in pickedFiles) {
          final extension = p.extension(file.path).toLowerCase().replaceAll('.', '');

          if (['jpg', 'jpeg', 'png'].contains(extension)) {
            handlePickedImages([file]);
          } else if (['mp4', 'mov'].contains(extension)) {
            handlePickedVideo(file);
          } else if (['mp3', 'wav', 'aac'].contains(extension)) {
            handlePickedAudio(file);
          }
        }
      }
    } catch (e) {
      ErrorHandler.showFileError();
    }
  }

  Future<void> handlePickedImages(List<File> images) async {
    progressTimer?.cancel();
    setState(() {
      selectedImages.addAll(images);
      selectedVideo = null;
      isCompressingImage = true;
      processingProgress = 0.0;
      preAnalysisResult = null;
    });

    startSimulatedProgress();

    await compressImages(selectedImages);
    if (processingProgress < 0.4) setState(() => processingProgress = 0.4);

    if (selectedImages.isNotEmpty) {
      if (mounted) {
        progressTimer?.cancel();
        setState(() {
          processingProgress = 1.0;
          preAnalysisResult = null; // Analysis will be done properly by AIOrchestrator on send
        });
      }
    }
  }

  void startSimulatedProgress() {
    progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (processingProgress < 0.90) {
          processingProgress += 0.005;
        } else {
          if (processingProgress > 0.95) {
            processingProgress = 0.90;
          } else {
            processingProgress += 0.001;
          }
        }
      });
    });
  }

  void handlePickedVideo(File video) {
    setState(() {
      selectedVideo = video;
      selectedImages = [];
    });
    
    // logic moved from screen to mixin if applicable, or kept in UI
    // For now, let's keep the UI bottom sheet in the screen but call this method
  }

  void handlePickedAudio(File audio) {
    setState(() {
      selectedVideo = audio;
    });
    // This will trigger enhancement flow in the screen or another mixin
  }

  Future<void> compressImages(List<File> files) async {
    try {
      final List<File> compressedList = await compute(ImageUtils.batchCompressAndRead, files);
      if (!mounted) return;
      setState(() {
        compressedImages = compressedList;
        isCompressingImage = false;
      });
    } catch (e) {
      debugPrint("Compression failed: $e");
      if (mounted) {
        setState(() {
          isCompressingImage = false;
          compressedImages = files;
        });
      }
    }
  }

  Future<void> pickVideoForAudioEnhance() async {
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      if (mounted) {
        setState(() => selectedVideo = File(video.path));
        // Note: The screen will usually call handleAudioEnhancement right after
      }
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          final List<File> files = pickedFiles.map((x) => File(x.path)).toList();
          handlePickedImages(files);
        }
      } else {
        final XFile? pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          handlePickedImages([File(pickedFile.path)]);
        }
      }
    } catch (e) {
      ErrorHandler.showFileError();
    }
  }
}
