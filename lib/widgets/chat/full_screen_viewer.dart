import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/snackbar_utils.dart'; // Using central snackbar utils

class FullScreenImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? mediaPath; // 📸 Added for local path support
  final String tag;

  const FullScreenImageViewer({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.mediaPath,
    required this.tag,
  });

  Future<void> _saveToGallery() async {
    try {
      if (imageFile != null) {
        await Gal.putImage(imageFile!.path);
        SnackBarUtils.showSuccess(
            "تم الحفظ", "تم حفظ الصورة في المعرض بنجاح ✨");
      } else if (mediaPath != null) {
        await Gal.putImage(mediaPath!);
        SnackBarUtils.showSuccess(
            "تم الحفظ", "تم حفظ الصورة في المعرض بنجاح ✨");
      } else if (imageUrl != null) {
        if (imageUrl!.startsWith('http')) {
          // ✅ تحميل الصورة من الرابط ثم حفظها
          SnackBarUtils.showSmartSnackBar(
              title: "جاري الحفظ", message: "جاري تحميل الصورة... ⏳");
          final response = await http.get(Uri.parse(imageUrl!));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final ext = imageUrl!.contains('.png') ? 'png' : 'jpg';
            final file = File(
                '${tempDir.path}/saved_${DateTime.now().millisecondsSinceEpoch}.$ext');
            await file.writeAsBytes(response.bodyBytes);
            await Gal.putImage(file.path);
            SnackBarUtils.showSuccess(
                "تم الحفظ", "تم حفظ الصورة في المعرض بنجاح ✨");
          } else {
            SnackBarUtils.showError("خطأ", "فشل تحميل الصورة من الرابط");
          }
        } else {
          await Gal.putImage(imageUrl!);
          SnackBarUtils.showSuccess(
              "تم الحفظ", "تم حفظ الصورة في المعرض بنجاح ✨");
        }
      }
    } catch (e) {
      SnackBarUtils.showError("خطأ", "فشل حفظ الصورة في المعرض");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _saveToGallery,
          ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            Get.back();
          }
        },
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: _buildImageSource(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSource() {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00FF88)),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image,
          color: Colors.white,
          size: 50,
        ),
      );
    }

    if (imageFile != null) {
      return Image.file(
        imageFile!,
        fit: BoxFit.contain,
      );
    }

    if (mediaPath != null) {
      return Image.file(
        File(mediaPath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image,
          color: Colors.white,
          size: 50,
        ),
      );
    }

    // Fallback if local URL but no file/path (e.g. storage ref)
    if (imageUrl != null) {
       return Image.file(
        File(imageUrl!),
        fit: BoxFit.contain,
      );
    }

    return const Icon(
      Icons.broken_image,
      color: Colors.white,
      size: 50,
    );
  }
}
