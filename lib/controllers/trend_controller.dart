import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart'; // 🖼️ For saving to gallery

class TrendController extends GetxController {
  final downloading = false.obs;
  final downloadProgress = 0.0.obs;
  final lastDownloadedPath = RxnString();
  final dio = Dio();

  Future<String?> startDownload(String? url, {bool saveToGal = true}) async {
    if (url == null || url.isEmpty) return null;

    try {
      downloading.value = true;
      downloadProgress.value = 0.0;

      // Get appropriate directory
      final appDir = await getApplicationDocumentsDirectory();
      final trendsDir = Directory(p.join(appDir.path, 'trends'));
      if (!await trendsDir.exists()) {
        await trendsDir.create(recursive: true);
      }

      // Generate filename from URL or timestamp
      final uri = Uri.parse(url);
      String fileName =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'video.mp4';
      if (!fileName.contains('.')) fileName += '.mp4';

      // Ensure unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      fileName = 'tiktok_${timestamp}_$fileName';

      final savePath = p.join(trendsDir.path, fileName);

      debugPrint('🚀 Starting download: $url -> $savePath');

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
          }
        },
      );

      debugPrint('✅ Download complete: $savePath');
      lastDownloadedPath.value = savePath;

      // 🔥 Auto-save to gallery if requested
      if (saveToGal) {
        await saveToGallery(savePath);
      }

      return savePath;
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      Get.snackbar(
        'خطأ في التحميل',
        'لم نتمكن من تحميل الفيديو: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      downloading.value = false;
      downloadProgress.value = 0.0;
    }
  }

  /// 🖼️ Save a file path to the device gallery
  Future<void> saveToGallery(String filePath) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      await Gal.putVideo(filePath);

      Get.snackbar(
        'تم الحفظ ✨',
        'تم حفظ الفيديو في معرض الصور بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF00FF88).withValues(alpha: 0.1),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('⚠️ Gallery Save Error: $e');
      // If it's a permission issue or platform not supported, we just log it
    }
  }
}
