import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as raster;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/vision_image.dart';

class GeneratedImage {
  final File file;
  final String mimeType;
  final String model;

  const GeneratedImage(this.file, this.mimeType, this.model);
}

/// Image output uses its own model and endpoint; the chat model stays unchanged.
class OpenRouterImageService {
  static const model = 'google/gemini-2.5-flash-image';
  static const maxReferences = 3;
  static const _maxBytes = 20 * 1024 * 1024;

  final Dio _client;
  final Future<Directory> Function() _documentsDirectory;

  OpenRouterImageService({
    Dio? client,
    Future<Directory> Function()? documentsDirectory,
  }) : _client =
           client ??
           Dio(BaseOptions(connectTimeout: const Duration(seconds: 45))),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<GeneratedImage> generate({
    required String prompt,
    required String apiKey,
    List<File> referenceImages = const [],
    String aspectRatio = '1:1',
    CancelToken? cancelToken,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const ImageGenerationException(
        'أضف مفتاح OpenRouter في إعدادات الخدمات.',
      );
    }
    if (prompt.trim().isEmpty) {
      throw const ImageGenerationException(
        'اكتب وصف الصورة التي تريد إنشاءها.',
      );
    }
    if (referenceImages.length > maxReferences) {
      throw const ImageGenerationException(
        'يمكن استخدام ثلاث صور مرجعية كحد أقصى في هذا الطلب.',
      );
    }
    if (cancelToken?.isCancelled == true) {
      throw const ImageGenerationException('تم إلغاء إنشاء الصورة.');
    }

    final references = <Map<String, dynamic>>[];
    for (final file in referenceImages) {
      if (!await file.exists() || await file.length() > _maxBytes) {
        throw const ImageGenerationException(
          'الصورة المرجعية غير متاحة أو يتجاوز حجمها 20 ميجابايت. أرفقها مجددًا.',
        );
      }
      final bytes = await file.readAsBytes();
      final mime = visionImageMimeType(bytes);
      if (mime == null || mime == 'image/gif') {
        throw const ImageGenerationException(
          'استخدم صورة مرجعية بصيغة PNG أو JPEG أو WebP.',
        );
      }
      references.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'},
      });
    }

    try {
      // One paid request only. A transport timeout must not trigger a second charge.
      final response = await _client.post<dynamic>(
        'https://openrouter.ai/api/v1/images',
        data: {
          'model': model,
          'prompt': prompt.trim(),
          'n': 1,
          'aspect_ratio': aspectRatio,
          'provider': {
            'only': ['google-vertex/global'],
            'allow_fallbacks': false,
          },
          if (references.isNotEmpty) 'input_references': references,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://smartcontentcreator.com/',
            'X-Title': 'Smart Content Creator',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(minutes: 3),
        ),
        cancelToken: cancelToken,
      );
      if (response.statusCode != 200) {
        throw ImageGenerationException(_statusMessage(response.statusCode));
      }
      final body = response.data;
      final images = body is Map ? body['data'] : null;
      final first = images is List && images.isNotEmpty ? images.first : null;
      final encoded = first is Map ? first['b64_json'] : null;
      if (encoded is! String ||
          encoded.isEmpty ||
          encoded.length > _maxBytes * 4 ~/ 3 + 4) {
        throw const ImageGenerationException(
          'لم يُرجع المزوّد ملف صورة صالحًا. لم يتم إنشاء صورة.',
        );
      }
      final bytes = base64Decode(encoded);
      final mime = await compute(_validateRaster, bytes);
      if (cancelToken?.isCancelled == true) {
        throw const ImageGenerationException('تم إلغاء إنشاء الصورة.');
      }
      final dir = Directory(
        '${(await _documentsDirectory()).path}/generated_images',
      );
      await dir.create(recursive: true);
      final extension = {
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/webp': 'webp',
      }[mime]!;
      final file = File(
        '${dir.path}/openrouter_${DateTime.now().microsecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(bytes, flush: true);
      return GeneratedImage(file, mime, model);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const ImageGenerationException('تم إلغاء إنشاء الصورة.');
      }
      throw ImageGenerationException(
        _statusMessage(error.response?.statusCode),
      );
    } on FormatException {
      throw const ImageGenerationException(
        'تعذّرت قراءة الصورة التي أعادها المزوّد.',
      );
    }
  }

  static String _statusMessage(int? status) {
    switch (status) {
      case 401:
      case 403:
        return 'مفتاح OpenRouter غير صالح أو لا يملك صلاحية استخدام نموذج الصور.';
      case 402:
        return 'رصيد OpenRouter غير كافٍ لإنشاء الصورة.';
      case 429:
        return 'وصل المزوّد إلى حد الطلبات. أعد المحاولة لاحقًا.';
      case 400:
      case 404:
        return 'تعذّر تنفيذ طلب الصور بهذا النموذج. راجع إعدادات OpenRouter.';
      default:
        return 'تعذّر الحصول على الصورة من OpenRouter. راجع سجل الطلب قبل إعادة المحاولة.';
    }
  }
}

String _validateRaster(Uint8List bytes) {
  final mime = visionImageMimeType(bytes);
  if (!const ['image/png', 'image/jpeg', 'image/webp'].contains(mime)) {
    throw const FormatException('Not a supported raster image');
  }
  final decoder = raster.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > 16777216 ||
      decoder!.decodeFrame(0) == null) {
    throw const FormatException('Invalid image pixels');
  }
  return mime!;
}

class ImageGenerationException implements Exception {
  final String message;
  const ImageGenerationException(this.message);
  @override
  String toString() => message;
}
