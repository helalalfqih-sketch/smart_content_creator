import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

class BackgroundRemovalService extends GetxService {
  late final SelfieSegmenter _segmenter;

  @override
  void onInit() {
    super.onInit();
    // تهيئة نموذج العزل ليكون دقيقاً قدر الإمكان
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true, // مهم جداً لمطابقة أبعاد الصورة الأصلية بدقة
    );
  }

  @override
  void onClose() {
    _segmenter.close();
    super.onClose();
  }

  /// ✂️ تقوم هذه الدالة بعزل الخلفية من الصورة المُعطاة وإرجاع مسار الصورة الشفافة (PNG)
  Future<File?> removeBackground(File sourceImage, {dio.CancelToken? cancelToken}) async {
    try {
      if (kDebugMode) debugPrint("[✂️ Background Removal]: Starting ML Kit Analysis...");
      
      final inputImage = InputImage.fromFile(sourceImage);
      final mask = await _segmenter.processImage(inputImage);
      
      if (mask == null) {
        if (kDebugMode) debugPrint("[⚠️ Background Removal]: No mask generated!");
        return null;
      }

      if (kDebugMode) {
        debugPrint("[🧠 Mask Created]: Width: ${mask.width}, Height: ${mask.height}");
      }

      // 1. قراءة بكسلات الصورة الأصلية باستخدام مكتبة image
      final bytes = await sourceImage.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        throw Exception("Failed to decode image.");
      }

      // مطابقة الأبعاد لتجنب أي تفاوت بين الـ Mask والصورة المجهزة
      // إذا كان الماسك بأبعاد مختلفة، نقوم بإعادة تحجيم الصورة لتطابقه (نادراً ما يحدث مع enableRawSizeMask)
      if (originalImage.width != mask.width || originalImage.height != mask.height) {
        originalImage = img.copyResize(originalImage, width: mask.width, height: mask.height);
      }

      // 2. تطبيق الماسك على كل بكسل لجعل الخلفية شفافة
      // mask.confidences هو مصفوفة 1D تحتوي على احتمالية (0.0 إلى 1.0) كون البكسل يمثل (الشخص/العنصر البارز)
      for (int y = 0; y < originalImage.height; y++) {
        for (int x = 0; x < originalImage.width; x++) {
          int index = y * originalImage.width + x;
          double confidence = mask.confidences[index];

          // Threshold: إذا كان اليقين أقل من الشريحة المحددة، فهو خلفية عشوائية
          if (confidence < 0.65) {
            // تفريغ البكسل (تعيين الشفافية Alpha إلى 0)
            originalImage.setPixelRgba(x, y, 0, 0, 0, 0);
          } else {
             // (تنعيم الحواف Edge Smoothing - اختياري)
            // إذا كان البكسل على الحافة (مثلاً 0.65 إلى 0.90)، نجعله شبه شفاف بدلاً من الحواف الحادة
            if (confidence < 0.95) {
               final pixel = originalImage.getPixel(x, y);
               final colorAlpha = (confidence * 255).toInt();
               // في مكتبة image v4+ خصائص اللون تختلف قليلاً، يمكن استخدام setPixelRgba لكن الأسهل هو تعديل الـ Alpha
               originalImage.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, colorAlpha);
            }
          }
        }
      }

      // 3. حفظ النتيجة بصيغة PNG لدعم الشفافية
      final directory = await getTemporaryDirectory();
      final String outputPath = '${directory.path}/transparent_isolated_${DateTime.now().millisecondsSinceEpoch}.png';
      
      final File outputFile = File(outputPath);
      final pngBytes = img.encodePng(originalImage);
      await outputFile.writeAsBytes(pngBytes);

      if (kDebugMode) debugPrint("[✅ Background Removal]: Successfully saved to $outputPath");

      return outputFile;

    } catch (e) {
      if (kDebugMode) debugPrint("[❌ Background Removal Error]: $e");
      return null;
    }
  }
}
