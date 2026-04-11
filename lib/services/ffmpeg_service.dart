import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:flutter/foundation.dart';

class FfmpegService {
  /// Check if FFmpeg is ready (implicitly always true with Kit effectively, but good placeholder)
  static Future<bool> isAvailable() async {
    return true; 
  }

  /// Extracts a single frame at a specific timestamp.
  static Future<File?> extractFrame({
    required String videoPath,
    required String outputPath,
    required String timestamp,
    int quality = 5,
  }) async {
    // -qn is not standard, using -q:v.
    // FFmpegKit execution
    final command = '-ss $timestamp -i "$videoPath" -frames:v 1 -q:v $quality -y "$outputPath"';
    
    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) return file;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint("FFmpeg Error (Extract Frame): $logs");
      }
    } catch (e) {
      debugPrint("FFmpegKit Exception: $e");
    }
    return null;
  }

  static Future<File?> applyAudioFilter({
    required String videoPath,
    required String outputPath,
    required String filterComplex, 
  }) async {
    // -i input -af filter -c:v copy -y output
    final command = '-i "$videoPath" -af "$filterComplex" -c:v copy -y "$outputPath"';

    try {
       final session = await FFmpegKit.execute(command);
       final returnCode = await session.getReturnCode();

       if (ReturnCode.isSuccess(returnCode)) {
         final file = File(outputPath);
         if (await file.exists()) return file; 
       } else {
         final logs = await session.getAllLogsAsString();
         debugPrint("FFmpeg Audio Error: $logs");
       }
    } catch (e) {
      debugPrint("FFmpegKit Exception (Audio): $e");
    }
    return null;
  }
  
  /// Helper to extract audio only
  static Future<String?> extractAudio(String videoPath) async {
    final audioPath = videoPath.replaceAll('.mp4', '_audio.mp3');
    final command = '-i "$videoPath" -vn -acodec mp3 -y "$audioPath"';
    
    try {
      final session = await FFmpegKit.execute(command);
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        return audioPath;
      }
    } catch (e) {
      debugPrint("Audio Extraction Error: $e");
    }
    return null;
  }
  static Future<File?> mergeAudioVideo({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    // Merge video (stream 0) and audio (stream 1)
    // -map 0:v -map 1:a ensures we pick video from file 1 and audio from file 2
    // -c:v copy avoids re-encoding video (fast)
    // -shortest ends when the shortest stream ends
    final command = '-i "$videoPath" -i "$audioPath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest -y "$outputPath"';
    
    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) return file;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint("FFmpeg Merge Error: $logs");
      }
    } catch (e) {
      debugPrint("FFmpegKit Merge Exception: $e");
    }
    return null;
  }

  /// 🎬 AI Cinematic Enhancement
  /// Executes high-quality processing including upscaling, denoising, and color correction.
  static Future<File?> enhanceVideo({
    required String inputPath,
    required String outputPath,
    required String filterChain,
    String? targetRatio, // Original, 9:16, 16:9, 1:1, 4:5
  }) async {
    String finalFilters = filterChain;
    
    // Add Smart Aspect Ratio Formatting if requested
    if (targetRatio != null && targetRatio != 'Original') {
      String scaleCrop = "";
      switch (targetRatio) {
        case '9:16':
          scaleCrop = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920";
          break;
        case '16:9':
          scaleCrop = "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080";
          break;
        case '1:1':
          scaleCrop = "scale=1080:1080:force_original_aspect_ratio=increase,crop=1080:1080";
          break;
        case '4:5':
          scaleCrop = "scale=1080:1350:force_original_aspect_ratio=increase,crop=1080:1350";
          break;
      }
      
      if (scaleCrop.isNotEmpty) {
        // If the filterChain already contains a scale, we might need to replace it or append.
        // For simplicity and to avoid conflicts, we append it at the end.
        finalFilters = "$finalFilters,$scaleCrop";
      }
    }

    // We use a slightly slower preset for better quality and detail retention.
    final command = '-i "$inputPath" -vf "$finalFilters" -c:v libx264 -preset medium -crf 18 -c:a copy -y "$outputPath"';
    debugPrint("🚀 FFmpeg AI Enhancement Command: ffmpeg $command");
    
    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) return file;
      } else if (ReturnCode.isCancel(returnCode)) {
        if (kDebugMode) debugPrint("FFmpeg Operation Cancelled by User");
      } else {
        await handleFFmpegError(session, "Enhancement");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("FFmpegKit Enhancement Exception: $e");
    }
    return null;
  }

  /// 🛑 Global Cancellation
  static Future<void> cancelAll() async {
    await FFmpegKit.cancel();
    if (kDebugMode) debugPrint("🚫 All FFmpeg sessions requested to cancel.");
  }

  /// 🔍 Detects specific errors from logs to show user-friendly messages
  static Future<void> handleFFmpegError(FFmpegSession session, String stage) async {
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isCancel(returnCode)) {
       throw Exception("تم إلغاء عملية $stage.");
    }

    final logs = await session.getAllLogsAsString();
    
    if (logs?.contains("No such file or directory") ?? false) {
      throw Exception("الملف غير موجود أو المسار خاطئ.");
    } else if (logs?.contains("out of memory") ?? false) {
      throw Exception("ذاكرة الجهاز غير كافية لمعالجة هذا الفيديو.");
    } else if ((logs?.contains("Invalid data found when processing input") ?? false) || (logs?.contains("could not find codec parameters") ?? false)) {
      throw Exception("تنسيق الفيديو غير مدعوم أو الملف تالف.");
    } else if (logs?.contains("Read-only file system") ?? false) {
      throw Exception("لا يمكن الكتابة في ذاكرة التخزين. تأكد من الأذونات.");
    }
    
    if (kDebugMode) debugPrint("FFmpeg Error ($stage): $logs");
    throw Exception("فشل عملية $stage: تأكد من سلامة الملف ومساحة التخزين.");
  }

  /// 📊 Get Metadata (Codec, Resolution, Duration)
  static Future<Map<String, dynamic>?> getMediaInfo(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) return null;

      final props = info.getAllProperties();
      return {
        'duration': info.getDuration(),
        'format': info.getFormat(),
        'bitrate': info.getBitrate(),
        'codec': props?['streams']?[0]?['codec_name'],
        'width': props?['streams']?[0]?['width'],
        'height': props?['streams']?[0]?['height'],
      };
    } catch (e) {
      if (kDebugMode) debugPrint("FFprobe Error: $e");
      return null;
    }
  }
}
