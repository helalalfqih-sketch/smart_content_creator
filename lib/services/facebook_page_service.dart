import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../controllers/settings_controller.dart';

class FacebookPageService extends GetxService {
  static FacebookPageService get to => Get.find();

  Future<bool> publishProduct({
    required String title,
    required String description,
    required String price,
    required String link,
    required String imageUrl,
    String videoUrl = '',
  }) async {
    final settings = Get.find<SettingsController>();
    final pageId = settings.fbPageId.value;
    final pageToken = settings.fbPageToken.value;

    if (pageId.isEmpty || pageToken.isEmpty) {
      Get.snackbar(
        '⚠️ فيسبوك غير مرتبط',
        'يرجى الذهاب للإعدادات وربط صفحة فيسبوك أولاً.',
        backgroundColor: const Color(0xFF3A3A1A),
        colorText: const Color(0xFFFFC107),
      );
      return false;
    }

    final postText = '🛍️ $title\n\n$description\n\n💰 السعر: $price\n\n🔗 رابط المنتج: $link';

    return await publishCustomPost(
      message: postText,
      selectedPhotos: imageUrl.isNotEmpty ? [imageUrl] : [],
      selectedVideo: videoUrl,
    );
  }

  Future<bool> publishCustomPost({
    required String message,
    required List<String> selectedPhotos,
    required String selectedVideo,
  }) async {
    final settings = Get.find<SettingsController>();
    final pageId = settings.fbPageId.value;
    final pageToken = settings.fbPageToken.value;

    if (pageId.isEmpty || pageToken.isEmpty) {
      return false;
    }

    try {
      // 1. إذا تم اختيار فيديو
      if (selectedVideo.isNotEmpty && selectedVideo.startsWith('http')) {
        final response = await http.post(
          Uri.parse('https://graph.facebook.com/v20.0/$pageId/videos'),
          body: {
            'file_url': selectedVideo,
            'description': message,
            'access_token': pageToken,
          },
        );
        return response.statusCode == 200 || response.statusCode == 201;
      }

      // 2. إذا تم اختيار صور متعددة (أو صورة واحدة)
      if (selectedPhotos.isNotEmpty) {
        final List<String> photoIds = [];
        
        for (final imgUrl in selectedPhotos) {
          if (imgUrl.isEmpty || !imgUrl.startsWith('http')) continue;
          
          final response = await http.post(
            Uri.parse('https://graph.facebook.com/v20.0/$pageId/photos'),
            body: {
              'url': imgUrl,
              'published': 'false', // رفع بدون نشر فوري
              'access_token': pageToken,
            },
          );
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final resData = json.decode(response.body);
            if (resData['id'] != null) {
              photoIds.add(resData['id'].toString());
            }
          }
        }

        if (photoIds.isNotEmpty) {
          // نشر منشور مجمع يحتوي على جميع معرفات الصور المرفوعة
          final mediaList = photoIds.map((id) => {'media_fbid': id}).toList();
          final response = await http.post(
            Uri.parse('https://graph.facebook.com/v20.0/$pageId/feed'),
            body: {
              'message': message,
              'attached_media': json.encode(mediaList),
              'access_token': pageToken,
            },
          );
          return response.statusCode == 200 || response.statusCode == 201;
        }
      }

      // 3. نشر منشور نصي فقط
      final response = await http.post(
        Uri.parse('https://graph.facebook.com/v20.0/$pageId/feed'),
        body: {
          'message': message,
          'access_token': pageToken,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('Facebook custom publish error: $e');
    }
    return false;
  }
}
