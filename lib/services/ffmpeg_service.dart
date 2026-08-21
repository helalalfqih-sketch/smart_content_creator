import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'media_processing_service.dart';

/// 🎬 FfmpegService (Compatibility Adapter)
///
/// Serves as a backward-compatible adapter routing all legacy requests to
/// [MediaProcessingService] on the backend.
/// Contains ZERO local native FFmpeg executions or native C++ binaries.
class FfmpegService extends GetxService {
  static MediaProcessingService get _mediaService {
    if (Get.isRegistered<MediaProcessingService>()) {
      return Get.find<MediaProcessingService>();
    }
    return Get.put(MediaProcessingService());
  }

  /// Check if media processing is ready
  static Future<bool> isAvailable() async {
    return _mediaService.isAvailable();
  }

  /// Extracts a single frame at a specific timestamp.
  static Future<File?> extractFrame({
    required String videoPath,
    required String outputPath,
    required String timestamp,
    int quality = 5,
  }) async {
    if (kDebugMode) debugPrint("[🎬 FfmpegService Adapter]: extractFrame routing to MediaProcessingService");
    return _mediaService.extractFrame(
      videoPath: videoPath,
      outputPath: outputPath,
      timestamp: timestamp,
      quality: quality,
    );
  }

  /// Applies audio filter complex
  static Future<File?> applyAudioFilter({
    required String videoPath,
    required String outputPath,
    required String filterComplex,
  }) async {
    if (kDebugMode) debugPrint("[🎬 FfmpegService Adapter]: applyAudioFilter routing to MediaProcessingService");
    return _mediaService.applyAudioFilter(
      videoPath: videoPath,
      outputPath: outputPath,
      filterComplex: filterComplex,
    );
  }

  /// Extracts audio only from video
  static Future<String?> extractAudio(String videoPath) async {
    if (kDebugMode) debugPrint("[🎬 FfmpegService Adapter]: extractAudio routing to MediaProcessingService");
    return _mediaService.extractAudio(videoPath);
  }

  /// Merges audio and video streams
  static Future<File?> mergeAudioVideo({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    if (kDebugMode) debugPrint("[🎬 FfmpegService Adapter]: mergeAudioVideo routing to MediaProcessingService");
    return _mediaService.mergeAudioVideo(
      videoPath: videoPath,
      audioPath: audioPath,
      outputPath: outputPath,
    );
  }

  /// AI Cinematic Enhancement
  static Future<File?> enhanceVideo({
    required String inputPath,
    required String outputPath,
    required String filterChain,
    String? targetRatio,
  }) async {
    if (kDebugMode) debugPrint("[🎬 FfmpegService Adapter]: enhanceVideo routing to MediaProcessingService");
    return _mediaService.enhanceVideo(
      inputPath: inputPath,
      outputPath: outputPath,
      filterChain: filterChain,
      targetRatio: targetRatio,
    );
  }

  /// 🛑 Global Cancellation
  static Future<void> cancelAll() async {
    _mediaService.cancelAll();
  }

  /// 🔍 Detects errors to show user-friendly messages (Compatibility)
  static Future<void> handleFFmpegError(dynamic session, String stage) async {
    throw Exception("فشلت عملية $stage عبر الخادم السحابي. يرجى المحاولة مرة أخرى.");
  }

  /// 📊 Get Media Information
  static Future<Map<String, dynamic>?> getMediaInfo(String path) async {
    return _mediaService.getMediaInfo(path);
  }
}
