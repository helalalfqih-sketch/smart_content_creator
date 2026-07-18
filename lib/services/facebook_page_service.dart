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
        if (kDebugMode) print('Facebook: Uploading video from url...');
        final response = await http.post(
          Uri.parse('https://graph.facebook.com/v20.0/$pageId/videos'),
          body: {
            'file_url': selectedVideo,
            'description': message,
            'access_token': pageToken,
          },
        );
        
        if (kDebugMode) {
          print('Facebook Video Response Status: ${response.statusCode}');
          print('Facebook Video Response Body: ${response.body}');
        }

        final success = response.statusCode == 200 || response.statusCode == 201;
        if (!success) {
          _showDetailedError('فشل نشر الفيديو على فيسبوك', response.body);
        }
        return success;
      }

      // 2. إذا تم اختيار صور متعددة (أو صورة واحدة)
      if (selectedPhotos.isNotEmpty) {
        final List<String> photoIds = [];
        
        for (final imgUrl in selectedPhotos) {
          if (imgUrl.isEmpty || !imgUrl.startsWith('http')) continue;
          
          if (kDebugMode) print('Facebook: Uploading photo: $imgUrl...');
          final response = await http.post(
            Uri.parse('https://graph.facebook.com/v20.0/$pageId/photos'),
            body: {
              'url': imgUrl,
              'published': 'false', // رفع بدون نشر فوري
              'access_token': pageToken,
            },
          );
          
          if (kDebugMode) {
            print('Facebook Photo Upload Response Status: ${response.statusCode}');
            print('Facebook Photo Upload Response Body: ${response.body}');
          }

          if (response.statusCode == 200 || response.statusCode == 201) {
            final resData = json.decode(response.body);
            if (resData['id'] != null) {
              photoIds.add(resData['id'].toString());
            }
          } else {
            _showDetailedError('فشل رفع الصورة على فيسبوك', response.body);
          }
        }

        if (photoIds.isNotEmpty) {
          if (kDebugMode) print('Facebook: Creating feed post with attached photos...');
          final mediaList = photoIds.map((id) => {'media_fbid': id}).toList();
          final response = await http.post(
            Uri.parse('https://graph.facebook.com/v20.0/$pageId/feed'),
            body: {
              'message': message,
              'attached_media': json.encode(mediaList),
              'access_token': pageToken,
            },
          );
          
          if (kDebugMode) {
            print('Facebook Multi-Photo Feed Response Status: ${response.statusCode}');
            print('Facebook Multi-Photo Feed Response Body: ${response.body}');
          }

          final success = response.statusCode == 200 || response.statusCode == 201;
          if (!success) {
            _showDetailedError('فشل نشر المنشور مع الصور', response.body);
          }
          return success;
        }
      }

      // 3. نشر منشور نصي فقط
      if (kDebugMode) print('Facebook: Creating text-only feed post...');
      final response = await http.post(
        Uri.parse('https://graph.facebook.com/v20.0/$pageId/feed'),
        body: {
          'message': message,
          'access_token': pageToken,
        },
      );
      
      if (kDebugMode) {
        print('Facebook Text Feed Response Status: ${response.statusCode}');
        print('Facebook Text Feed Response Body: ${response.body}');
      }

      final success = response.statusCode == 200 || response.statusCode == 201;
      if (!success) {
        _showDetailedError('فشل نشر المنشور النصي', response.body);
      }
      return success;
    } catch (e) {
      if (kDebugMode) print('Facebook custom publish error: $e');
    }
    return false;
  }

  void _showDetailedError(String title, String responseBody) {
    try {
      final errorData = json.decode(responseBody);
      if (errorData['error'] != null && errorData['error']['message'] != null) {
        Get.snackbar(
          '❌ $title',
          'فيسبوك: ${errorData['error']['message']}',
          backgroundColor: const Color(0xFF3D1F1F),
          colorText: const Color(0xFFFFD3D3),
          duration: const Duration(seconds: 5),
        );
      }
    } catch (_) {}
  }
}
