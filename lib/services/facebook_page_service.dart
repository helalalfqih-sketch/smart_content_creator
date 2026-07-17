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

    try {
      if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
        // نشر صورة مع النص كتعليق عليها
        final response = await http.post(
          Uri.parse('https://graph.facebook.com/v20.0/$pageId/photos'),
          body: {
            'url': imageUrl,
            'caption': postText,
            'access_token': pageToken,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = json.decode(response.body);
          if (resData['id'] != null) {
            return true;
          }
        }
      } else {
        // نشر منشور نصي فقط
        final response = await http.post(
          Uri.parse('https://graph.facebook.com/v20.0/$pageId/feed'),
          body: {
            'message': postText,
            'link': link.isNotEmpty ? link : 'https://smartcontentcreator-d49f2.web.app/app',
            'access_token': pageToken,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Facebook publish error: $e');
    }
    return false;
  }
}
