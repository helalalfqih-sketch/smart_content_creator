import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../core/utils/ai_request_exception.dart';

/// SerpApi's Image API accepts at most 500 KB. Send a JPEG without EXIF metadata.
Future<Uint8List> prepareLensImage(String path) async {
  try {
    final file = File(path);
    final length = await file.length();
    if (length == 0 || length > 25 * 1024 * 1024) {
      throw const AiRequestException('invalid_image', 'اختر صورة بحجم أقل من 25 ميغابايت.');
    }
    final bytes = await file.readAsBytes();
    for (final settings in [(1280, 75), (960, 60), (720, 45), (512, 35)]) {
      final compressed = await FlutterImageCompress.compressWithList(bytes,
        minWidth: settings.$1, minHeight: settings.$1, quality: settings.$2,
        format: CompressFormat.jpeg, keepExif: false,
      );
      if (compressed.length >= 12 && compressed.length <= 480000 &&
          compressed[0] == 255 && compressed[1] == 216 && compressed[2] == 255) {
        return compressed;
      }
    }
    throw const AiRequestException('invalid_image', 'تعذر تصغير الصورة للبحث بعدسة Google. اختر صورة أصغر.');
  } on AiRequestException {
    rethrow;
  } catch (_) {
    throw const AiRequestException('invalid_image', 'تعذر تجهيز الصورة. اختر صورة من الهاتف وأعد المحاولة.');
  }
}
