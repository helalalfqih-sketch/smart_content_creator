import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'media_processing_service.dart';
import 'ffmpeg_service.dart';
import 'unified_ai_service.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';

/// 🎬 خدمة دمج الصور مع الفيديو (Smart Media Merge)
///
/// تدعم:
/// 1. إزالة خلفية صورة المنتج (Remove.bg)
/// 2. تحليل ذكي لموضع الدمج عبر Gemini
/// 3. دمج الصورة فوق الفيديو كطبقة (FFmpeg Overlay)
/// 4. تحكم بالحجم والموضع والشفافية
/// 5. معالجة محلية كحل احتياطي
class MediaMergeService extends GetxService {
  // ────────────────────────── الحالة ──────────────────────────
  final RxBool isProcessing = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString statusMessage = ''.obs;

  // ────────────────────────── إعدادات الدمج ──────────────────────────
  /// موضع الصورة (نسبة مئوية من أبعاد الفيديو)
  final RxDouble positionX = 0.5.obs; // 0.0 = يسار، 1.0 = يمين
  final RxDouble positionY = 0.5.obs; // 0.0 = أعلى، 1.0 = أسفل
  final RxDouble imageScale = 0.3.obs; // حجم الصورة نسبة للفيديو
  final RxDouble opacity = 1.0.obs; // شفافية (0.0 - 1.0)
  final RxBool removeBackground = true.obs; // إزالة الخلفية تلقائياً

  // ────────────────────────── النتيجة ──────────────────────────
  final Rxn<String> resultVideoPath = Rxn<String>();
  final Rxn<String> processedImagePath = Rxn<String>();

  // ═══════════════════════════════════════════════════════════════
  //                    🚀 الدالة الرئيسية
  // ═══════════════════════════════════════════════════════════════

  /// 🎬 دمج صورة المنتج مع الفيديو
  ///
  /// [productImage] - صورة المنتج (JPG/PNG)
  /// [videoPath] - مسار الفيديو
  /// [smartPosition] - استخدام Gemini لتحديد الموضع الذكي
  /// [aspectRatio] - نسبة العرض (9:16 للريلز)
  Future<String?> mergeImageWithVideo({
    required File productImage,
    required String videoPath,
    bool smartPosition = true,
    String aspectRatio = '9:16',
    String? customPrompt,
  }) async {
    isProcessing.value = true;
    progress.value = 0.0;
    resultVideoPath.value = null;

    try {
      // ────── 1. إزالة الخلفية ──────
      File overlayImage = productImage;
      if (removeBackground.value) {
        _updateStatus('🔍 إزالة خلفية المنتج...', 0.1);
        final bgRemoved = await _removeBackgroundFromImage(productImage);
        if (bgRemoved != null) {
          overlayImage = bgRemoved;
          processedImagePath.value = bgRemoved.path;
        } else {
          _updateStatus(
              '⚠️ فشل إزالة الخلفية، سيتم الاستمرار بالصورة الأصلية', 0.15);
        }
      }

      // ────── 2. تحليل ذكي للموضع (اختياري) ──────
      if (smartPosition) {
        _updateStatus('🧠 تحليل ذكي لأفضل موضع...', 0.2);
        await _analyzeSmartPosition(productImage, videoPath, customPrompt);
      }

      // ────── 3. جلب معلومات الفيديو ──────
      _updateStatus('📐 قراءة أبعاد الفيديو...', 0.3);
      final videoInfo = await FfmpegService.getMediaInfo(videoPath);
      final int videoWidth = videoInfo?['width'] ?? 1080;
      final int videoHeight = videoInfo?['height'] ?? 1920;

      // ────── 4. تحضير الصورة بالحجم المناسب ──────
      _updateStatus('📏 تحضير صورة المنتج...', 0.4);
      final resizedImage = await _resizeOverlayImage(
        overlayImage,
        videoWidth,
        videoHeight,
      );

      // ────── 5. الدمج عبر FFmpeg ──────
      _updateStatus('🎬 دمج المنتج مع الفيديو...', 0.5);
      final outputPath = await _executeMerge(
        videoPath: videoPath,
        overlayPath: resizedImage.path,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        aspectRatio: aspectRatio,
      );

      if (outputPath != null) {
        resultVideoPath.value = outputPath;
        _updateStatus('✅ تم الدمج بنجاح!', 1.0);
        return outputPath;
      }

      // ────── 6. الحل الاحتياطي (Fallback) ──────
      _updateStatus('🔄 محاولة دمج بسيط...', 0.8);
      final fallback = await _fallbackMerge(
        videoPath: videoPath,
        overlayPath: resizedImage.path,
      );
      resultVideoPath.value = fallback;
      _updateStatus(fallback != null ? '✅ تم الدمج!' : '❌ فشل الدمج', 1.0);
      return fallback;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ MediaMerge Error: $e');
      _updateStatus('❌ خطأ: ${e.toString().substring(0, 50)}', 0.0);
      return null;
    } finally {
      isProcessing.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //                    🔧 الدوال المساعدة
  // ═══════════════════════════════════════════════════════════════

  /// 🖼️ إزالة الخلفية باستخدام Remove.bg API
  Future<File?> _removeBackgroundFromImage(File image) async {
    try {
      String apiKey = '';
      try {
        final settings = Get.find<SettingsController>();
        apiKey = settings.getApiKey(ProviderType.removebg).trim();
      } catch (_) {}

      if (apiKey.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Remove.bg API key not configured');
        return null;
      }

      final bytes = await image.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );

      request.headers['X-Api-Key'] = apiKey;
      request.files.add(http.MultipartFile.fromBytes(
        'image_file',
        bytes,
        filename: 'product.png',
      ));
      request.fields['size'] = 'auto';
      request.fields['format'] = 'png';

      final response = await request.send();
      if (response.statusCode == 200) {
        final resultBytes = await response.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final outputFile = File(
            '${tempDir.path}/product_nobg_${DateTime.now().millisecondsSinceEpoch}.png');
        await outputFile.writeAsBytes(resultBytes);

        if (kDebugMode) debugPrint('✅ Background removed successfully');
        return outputFile;
      } else {
        if (kDebugMode) {
          debugPrint('❌ Remove.bg failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ BG Removal Error: $e');
    }
    return null;
  }

  Future<void> _analyzeSmartPosition(
      File image, String videoPath, String? customPrompt) async {
    try {
      final ai = Get.find<UnifiedAIService>();

      final prompt = customPrompt ??
          '''أنت خبير تصوير منتجات ومونتاج فيديو.
لدي صورة منتج أريد وضعها فوق فيديو.
أين أفضل موضع لوضع صورة المنتج على الفيديو؟

أجب فقط بصيغة JSON:
{
  "x": 0.5,
  "y": 0.6,
  "scale": 0.3,
  "reasoning": "سبب اختيار هذا الموضع"
}

حيث x و y نسبة مئوية (0.0 = أعلى/يسار، 1.0 = أسفل/يمين)
و scale هو حجم المنتج نسبة للفيديو (0.1 - 0.6)''';

      final response = await ai.generateText(prompt);

      // محاولة استخراج JSON من الرد
      final jsonMatch =
          RegExp(r'\{[^}]*"x"\s*:\s*[\d.]+[^}]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final data = json.decode(jsonMatch.group(0)!);
        positionX.value = (data['x'] as num?)?.toDouble() ?? 0.5;
        positionY.value = (data['y'] as num?)?.toDouble() ?? 0.6;
        imageScale.value = (data['scale'] as num?)?.toDouble() ?? 0.3;

        if (kDebugMode) {
          debugPrint(
              '🧠 Smart Position: x=${positionX.value}, y=${positionY.value}, scale=${imageScale.value}');
          debugPrint('📝 Reason: ${data['reasoning']}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Smart position analysis failed: $e');
      // استخدام القيم الافتراضية
    }
  }

  /// 📏 تغيير حجم الصورة للتناسب مع الفيديو
  Future<File> _resizeOverlayImage(
      File image, int videoWidth, int videoHeight) async {
    try {
      final bytes = await image.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return image;

      // حساب الأبعاد المطلوبة
      final targetWidth = (videoWidth * imageScale.value).toInt();
      final targetHeight =
          (targetWidth * decoded.height / decoded.width).toInt();

      final resized = img.copyResize(decoded,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear);

      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
          '${tempDir.path}/overlay_resized_${DateTime.now().millisecondsSinceEpoch}.png');
      await outputFile.writeAsBytes(img.encodePng(resized));

      return outputFile;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Resize failed, using original: $e');
      return image;
    }
  }

  /// 🎬 تنفيذ الدمج عبر الخادم (MediaProcessingService)
  Future<String?> _executeMerge({
    required String videoPath,
    required String overlayPath,
    required int videoWidth,
    required int videoHeight,
    String aspectRatio = '9:16',
  }) async {
    try {
      progress.value = 0.6;
      final mediaService = Get.find<MediaProcessingService>();
      final result = await mediaService.mergeImageWithVideo(
        productImage: File(overlayPath),
        videoPath: videoPath,
        positionX: positionX.value,
        positionY: positionY.value,
        imageScale: imageScale.value,
        opacity: opacity.value,
        aspectRatio: aspectRatio,
        onProgress: (p, status) {
          progress.value = p;
          _updateStatus(status, p);
        },
      );
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Media Merge Error: $e');
    }
    return null;
  }

  /// 🔄 حل احتياطي (Fallback)
  Future<String?> _fallbackMerge({
    required String videoPath,
    required String overlayPath,
  }) async {
    return _executeMerge(
      videoPath: videoPath,
      overlayPath: overlayPath,
      videoWidth: 1080,
      videoHeight: 1920,
    );
  }

  /// 🔄 إعادة تعيين الإعدادات
  void resetSettings() {
    positionX.value = 0.5;
    positionY.value = 0.5;
    imageScale.value = 0.3;
    opacity.value = 1.0;
    removeBackground.value = true;
    resultVideoPath.value = null;
    processedImagePath.value = null;
    statusMessage.value = '';
    progress.value = 0.0;
  }

  /// 📊 تحديث حالة التقدم
  void _updateStatus(String message, double prog) {
    statusMessage.value = message;
    progress.value = prog;
    if (kDebugMode) debugPrint('📊 MediaMerge: $message ($prog)');
  }
}
