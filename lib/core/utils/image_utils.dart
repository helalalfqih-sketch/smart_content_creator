import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 📸 نتيجة دمج الصور (Composition Result)
class CompositeResult {
  final File compositeFile;
  final File maskFile;
  CompositeResult({required this.compositeFile, required this.maskFile});
}

/// 📦 مدخلات عملية الدمج (Cross-Isolate Data)
class CompositionInput {
  final String templatePath;
  final String productPath;
  final String? boxPath;
  final String? logoPath;
  final String? handPath;
  final String position;
  final String tempDirPath;

  CompositionInput({
    required this.templatePath,
    required this.productPath,
    required this.tempDirPath,
    this.boxPath,
    this.logoPath,
    this.handPath,
    this.position = 'Center',
  });
}

/// 🎬 أدوات معالجة الصور الموحدة للتطبيق
class ImageUtils {
  /// 📐 ضغط الصورة للتعامل مع الذكاء الاصطناعي (AI Optimization)
  /// يحافظ على الجودة مع تقليل الحجم لسرعة الرفع
  static Future<File> compressForAi(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = "${tempDir.path}/ai_comp_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );
      
      if (result == null) return file;
      return File(result.path);
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Compression error: $e");
      return file; // Fallback to original if compression fails
    }
  }

  /// 🚀 معالجة مجموعة صور للرؤية في Isolate واحد (Performance Fix)
  /// يمنع تجمد الواجهة (Davey Lag) عند معالجة صور متعددة للقوالب والمنتجات
  static Future<List<Uint8List>> batchPrepareForVision(List<File> files) async {
    final paths = files.map((f) => f.path).toList();
    return await compute((List<String> ps) async {
      final List<Uint8List> results = [];
      for (final p in ps) {
        try {
          final b = await File(p).readAsBytes();
          final image = img.decodeImage(b);
          if (image == null) {
             results.add(b);
             continue;
          }
          final resized = img.copyResize(image, height: 512); 
          results.add(Uint8List.fromList(img.encodeJpg(resized, quality: 80)));
        } catch (e) {
          results.add(Uint8List(0));
        }
      }
      return results;
    }, paths);
  }

  /// 🚀 ضغط الصورة وتحويلها لـ Uint8List (Vision Optimization)
  static Future<Uint8List> compressAndResizeForVision(File file) async {
    final path = file.path;
    return await compute((String p) async {
      try {
        final b = await File(p).readAsBytes();
        final image = img.decodeImage(b);
        if (image == null) return b;
        
        // تصغير الصورة لتقليل التكلفة والسرعة
        final resized = img.copyResize(image, height: 512); 
        return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
      } catch (e) {
        // Fallback to reading on main if something fails in isolate (though unlikely)
        return await File(p).readAsBytes();
      }
    }, path);
  }

  /// 🚀 معالجة مجموعة صور في الخلفية (Batch Processing for Isolate)
  /// ملاحظة: تستخدم مع compute() في الشاشات لضمان سلاسة الواجهة
  static Future<List<File>> batchCompressAndRead(List<File> files) async {
    List<File> compressed = [];
    for (var f in files) {
      compressed.add(f); 
    }
    return compressed;
  }

  /// 📦 تشفير الصور بـ Base64 في الخلفية (Isolate-friendly)
  static String encodeBase64(Uint8List bytes) => base64Encode(bytes);

  /// 📦 تشفير مجموعة صور بـ Base64 (Isolate-friendly)
  static List<String> encodeBatchBase64(List<Uint8List> images) => 
      images.map((img) => base64Encode(img)).toList();

  /// 🎭 إنشاء قناع (Mask) من صورة شفافة في الخلفية
  static Uint8List? generateMaskTask(Uint8List pngBytes) {
    try {
      final image = img.decodeImage(pngBytes);
      if (image == null) return null;

      final mask = img.Image(width: image.width, height: image.height);
      for (final pixel in image) {
        // White (255) = Inpaint/Background, Black (0) = Keep/Product
        if (pixel.a < 10) {
          mask.setPixelRgb(pixel.x, pixel.y, 255, 255, 255);
        } else {
          mask.setPixelRgb(pixel.x, pixel.y, 0, 0, 0);
        }
      }
      return img.encodePng(mask);
    } catch (e) {
      if (kDebugMode) print('❌ Mask Task Error: $e');
      return null;
    }
  }

  /// 🏮 اكتشاف مصدر الضوء في القالب (Quadrant Luminance Analysis)
  static img.Point _detectLightSource(img.Image image) {
    final w = image.width;
    final h = image.height;
    final halfW = w ~/ 2;
    final halfH = h ~/ 2;

    double q1 = _calculateLuminance(image, 0, 0, halfW, halfH);         // Top-Left
    double q2 = _calculateLuminance(image, halfW, 0, w, halfH);         // Top-Right
    double q3 = _calculateLuminance(image, 0, halfH, halfW, h);         // Bottom-Left
    double q4 = _calculateLuminance(image, halfW, halfH, w, h);         // Bottom-Right

    if ((q1 - q2).abs() < 5 && (q1 - q3).abs() < 5) return img.Point(halfW, 0); 
    if (q1 >= q2 && q1 >= q3 && q1 >= q4) return img.Point(0, 0);
    if (q2 >= q1 && q2 >= q3 && q2 >= q4) return img.Point(w, 0);
    if (q3 >= q1 && q3 >= q2 && q3 >= q4) return img.Point(0, h);
    return img.Point(w, h);
  }

  static double _calculateLuminance(img.Image imgData, int x1, int y1, int x2, int y2) {
    double total = 0;
    int count = 0;
    for (int y = y1; y < y2; y += 20) {
      for (int x = x1; x < x2; x += 20) {
        final pixel = imgData.getPixel(x, y);
        total += pixel.luminance;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  static img.Color _getAverageColor(img.Image image) {
    double r = 0, g = 0, b = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += 40) {
      for (int x = 0; x < image.width; x += 40) {
        final pixel = image.getPixel(x, y);
        r += pixel.r;
        g += pixel.g;
        b += pixel.b;
        count++;
      }
    }
    return img.ColorRgb8((r / count).toInt(), (g / count).toInt(), (b / count).toInt());
  }

  static void _drawGroundShadow(img.Image canvas, img.Image object, int dstX, int dstY, img.Point lightSource, img.Color tintColor) {
    final shadowOpacity = 0.5;
    final shadowLength = (object.height * 0.35).toInt();
    final skewX = (dstX + object.width / 2 - lightSource.x) / canvas.width;
    
    final shadowMask = img.Image(width: object.width, height: shadowLength + 10);
    final shadowColor = img.ColorRgba8((tintColor.r * 0.2).toInt(), (tintColor.g * 0.1).toInt(), 0, (255 * shadowOpacity).toInt());

    for (int y = 0; y < shadowMask.height; y++) {
      final rowSkew = skewX * y * 0.8;
      for (int x = 0; x < shadowMask.width; x++) {
        final sourceX = (x - rowSkew).toInt();
        if (sourceX >= 0 && sourceX < object.width) {
          final p = object.getPixel(sourceX, (object.height * 0.9).toInt());
          if (p.a > 0) shadowMask.setPixel(x, y, shadowColor);
        }
      }
    }
    img.gaussianBlur(shadowMask, radius: 8);
    img.compositeImage(canvas, shadowMask, dstX: dstX, dstY: dstY + (object.height * 0.92).toInt());
  }

  static void _applyLightWrap(img.Image object, img.Color tintColor) {
    for (final pixel in object) {
      if (pixel.a > 0 && pixel.luminance > 170) {
        pixel.r = (pixel.r * 0.92 + tintColor.r * 0.08).toInt();
        pixel.g = (pixel.g * 0.92 + tintColor.g * 0.08).toInt();
        pixel.b = (pixel.b * 0.92 + tintColor.b * 0.08).toInt();
      }
    }
  }

  /// 🎨 دمج صور متعددة في قالب واحد (Isolate-Optimized)
  static Future<CompositeResult?> createCompositeAd({
    required File templateFile,
    required File productFile,
    File? boxFile,
    File? logoFile,
    File? handFile,
    String position = 'Center',
  }) async {
    try {
      if (kDebugMode) debugPrint('🚀 Offloading Cinematic Engine to Isolate...');
      
      // 1. استخراج المسارات قبل الدخول إلى الـ Isolate (لأن platform channels لا تعمل هناك)
      final tempDir = await getTemporaryDirectory();
      
      final input = CompositionInput(
        templatePath: templateFile.path,
        productPath: productFile.path,
        tempDirPath: tempDir.path,
        boxPath: boxFile?.path,
        logoPath: logoFile?.path,
        handPath: handFile?.path,
        position: position,
      );

      // 2. تشغيل المعالجة الثقيلة في Isolate منفصل
      return await compute(_renderTask, input);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Isolate Execution Error: $e');
      return null;
    }
  }

  /// 🛠️ المهمة الخلفية للرندر (Isolated Render Task)
  static Future<CompositeResult?> _renderTask(CompositionInput input) async {
    try {
      final templateFile = File(input.templatePath);
      final productFile = File(input.productPath);
      
      final templateImg = img.decodeImage(await templateFile.readAsBytes());
      final productImg = img.decodeImage(await productFile.readAsBytes());
      if (templateImg == null || productImg == null) return null;

      final canvas = img.copyResize(templateImg, width: 1080, height: 1080);
      final lightSource = _detectLightSource(canvas);
      final avgColor = _getAverageColor(canvas);

      final scaledProduct = img.copyResize(productImg, width: 600);
      _applyLightWrap(scaledProduct, avgColor);

      // حساب الموقع (Positioning Physics)
      int pX = (1080 - scaledProduct.width) ~/ 2;
      final pos = input.position.toLowerCase();
      if (pos == 'left') pX = 80;
      if (pos == 'right') pX = 400;
      
      final pY = (1080 - scaledProduct.height) ~/ 2;

      // رسم العناصر الإضافية
      if (input.boxPath != null) {
        final boxImg = img.decodeImage(await File(input.boxPath!).readAsBytes());
        if (boxImg != null) {
          final tiltedBox = img.copyRotate(img.copyResize(boxImg, width: 450), angle: -15);
          final bX = pX - 320;
          final bY = pY + 120;
          _drawGroundShadow(canvas, tiltedBox, bX, bY, lightSource, avgColor);
          img.compositeImage(canvas, tiltedBox, dstX: bX, dstY: bY);
        }
      }

      _drawGroundShadow(canvas, scaledProduct, pX, pY, lightSource, avgColor);
      img.compositeImage(canvas, scaledProduct, dstX: pX, dstY: pY);

      if (input.handPath != null) {
        final handImg = img.decodeImage(await File(input.handPath!).readAsBytes());
        if (handImg != null) {
          final scaledHand = img.copyResize(handImg, width: 700);
          img.compositeImage(canvas, scaledHand, dstX: pX + 150, dstY: pY + 200);
        }
      }

      // إنشاء الماسك (Mask Generation for Inpainting)
      // 🎯 Fix: Background=Black (Keep), Product=Black (Keep), Shadow Area=White (Edit/Blend)
      final mask = img.Image(width: 1080, height: 1080);
      img.fill(mask, color: img.ColorRgb8(0, 0, 0)); // ⬅️ Background is fixed
      
      // ننشئ ماسك للـ Shadow (الظلال السفلى) ليعطيه لمسة واقعية عبر الذكاء الاصطناعي
      // أما المنتج نفسه فهو أسود (يتم الحفاظ عليه بدقة 100%)
      final shadowMask = img.Image(width: 600, height: (scaledProduct.height * 0.3).toInt());
      img.fill(shadowMask, color: img.ColorRgb8(255, 255, 255)); // ⬅️ فقط منطقة الظل سيتم مزجها
      img.compositeImage(mask, shadowMask, dstX: pX, dstY: pY + (scaledProduct.height * 0.8).toInt());

      if (input.logoPath != null) {
        final logoImg = img.decodeImage(await File(input.logoPath!).readAsBytes());
        if (logoImg != null) {
          img.fillRect(canvas, x1: 0, y1: 0, x2: 300, y2: 120, color: img.ColorRgb8(255, 102, 0));
          img.compositeImage(canvas, img.copyResize(logoImg, width: 220), dstX: 40, dstY: 20);
        }
      }

      // حفظ الرموز
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cFile = File('${input.tempDirPath}/composite_$timestamp.png');
      await cFile.writeAsBytes(img.encodePng(canvas));
      final mFile = File('${input.tempDirPath}/mask_$timestamp.png');
      await mFile.writeAsBytes(img.encodePng(mask));

      return CompositeResult(compositeFile: cFile, maskFile: mFile);
    } catch (e) {
      if (kDebugMode) print('❌ Isolate Render Task Error: $e');
      return null;
    }
  }

}
