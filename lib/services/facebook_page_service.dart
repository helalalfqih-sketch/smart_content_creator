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

    // ⚡ تشخيص أولي لنوع الرمز المستعمل قبل البدء بالنشر
    await _debugTokenAndPost(pageToken, pageId, null);

    try {
      // 1. إذا تم اختيار فيديو
      if (selectedVideo.isNotEmpty && selectedVideo.startsWith('http')) {
        if (kDebugMode) debugPrint('Facebook: Uploading video from url...');
        final response = await http.post(
          Uri.parse('https://graph.facebook.com/v20.0/$pageId/videos'),
          body: {
            'file_url': selectedVideo,
            'description': message,
            'access_token': pageToken,
          },
        );
        
        if (kDebugMode) {
          debugPrint('Facebook Video Response Status: ${response.statusCode}');
          debugPrint('Facebook Video Response Body: ${response.body}');
        }

        final success = response.statusCode == 200 || response.statusCode == 201;
        if (success) {
          String? postId;
          try {
            final resData = json.decode(response.body);
            postId = resData['id']?.toString() ?? resData['post_id']?.toString();
          } catch (_) {}
          // ⚡ فحص ما بعد النشر للتحقق من المالك والناشر
          await _debugTokenAndPost(pageToken, pageId, postId);
        } else {
          _showDetailedError('فشل نشر الفيديو على فيسبوك', response.body);
        }
        return success;
      }

      // 2. إذا تم اختيار صور متعددة (أو صورة واحدة)
      if (selectedPhotos.isNotEmpty) {
        final List<String> photoIds = [];
        
        for (final imgUrl in selectedPhotos) {
          if (imgUrl.isEmpty || !imgUrl.startsWith('http')) continue;
          
          if (kDebugMode) debugPrint('Facebook: Uploading photo: $imgUrl...');
          final response = await http.post(
            Uri.parse('https://graph.facebook.com/v20.0/$pageId/photos'),
            body: {
              'url': imgUrl,
              'published': 'false', // رفع بدون نشر فوري
              'access_token': pageToken,
            },
          );
          
          if (kDebugMode) {
            debugPrint('Facebook Photo Upload Response Status: ${response.statusCode}');
            debugPrint('Facebook Photo Upload Response Body: ${response.body}');
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
          if (kDebugMode) debugPrint('Facebook: Creating feed post with attached photos...');
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
            debugPrint('Facebook Multi-Photo Feed Response Status: ${response.statusCode}');
            debugPrint('Facebook Multi-Photo Feed Response Body: ${response.body}');
          }

          final success = response.statusCode == 200 || response.statusCode == 201;
          if (success) {
            String? postId;
            try {
              final resData = json.decode(response.body);
              postId = resData['id']?.toString() ?? resData['post_id']?.toString();
            } catch (_) {}
            await _debugTokenAndPost(pageToken, pageId, postId);
          } else {
            _showDetailedError('فشل نشر المنشور مع الصور', response.body);
          }
          return success;
        }
      }

      // 3. نشر منشور نصي فقط
      if (kDebugMode) debugPrint('Facebook: Creating text-only feed post...');
      final response = await http.post(
        Uri.parse('https://graph.facebook.com/v20.0/$pageId/feed'),
        body: {
          'message': message,
          'access_token': pageToken,
        },
      );
      
      if (kDebugMode) {
        debugPrint('Facebook Text Feed Response Status: ${response.statusCode}');
        debugPrint('Facebook Text Feed Response Body: ${response.body}');
      }

      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success) {
        String? postId;
        try {
          final resData = json.decode(response.body);
          postId = resData['id']?.toString() ?? resData['post_id']?.toString();
        } catch (_) {}
        await _debugTokenAndPost(pageToken, pageId, postId);
      } else {
        _showDetailedError('فشل نشر المنشور النصي', response.body);
      }
      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('Facebook custom publish error: $e');
    }
    return false;
  }

  /// 🧠 تشخيص ونوع التوكن المستعمل ومالك المنشور بعد النشر
  Future<void> _debugTokenAndPost(String token, String pageId, String? postId) async {
    try {
      // 1. فحص نوع التوكن عبر الاستعلام عن الهوية المستعارة
      final meResponse = await http.get(Uri.parse('https://graph.facebook.com/v20.0/me?access_token=$token'));
      if (meResponse.statusCode == 200) {
        final meData = json.decode(meResponse.body);
        final meId = meData['id']?.toString() ?? '';
        final meName = meData['name']?.toString() ?? '';
        
        if (meId == pageId) {
          debugPrint('ℹ️ [Facebook Diagnostics] Token Type Check: PAGE ACCESS TOKEN (Page: $meName, ID: $meId)');
        } else {
          debugPrint('⚠️ [Facebook Diagnostics] Token Type Check: USER ACCESS TOKEN (User: $meName, ID: $meId). This token will post as User instead of the Page!');
          Get.snackbar(
            '⚠️ تنبيه رمز الوصول',
            'الرمز المستخدم حالياً هو رمز مستخدم (User Token) وليس رمز صفحة. قد تظهر المنشورات باسمك الشخصي بدلاً من صفحة العمل.',
            backgroundColor: const Color(0xFF3D2E1F),
            colorText: const Color(0xFFFFE0B2),
            duration: const Duration(seconds: 6),
          );
        }
      } else {
        debugPrint('⚠️ [Facebook Diagnostics] Failed to query /me endpoint: ${meResponse.body}');
      }

      // 2. فحص تفاصيل ومالك المنشور في حال توفر postId
      if (postId != null && postId.isNotEmpty) {
        // لتجنب خطأ deprecation لبعض المنشورات، نضمن استعلامها بصيغة المعرف المدمج {page-id}_{post-id}
        final finalPostId = postId.contains('_') ? postId : '${pageId}_$postId';
        final postCheckUrl = 'https://graph.facebook.com/v20.0/$finalPostId?fields=id,from&access_token=$token';
        final checkResponse = await http.get(Uri.parse(postCheckUrl));
        if (checkResponse.statusCode == 200) {
          final checkData = json.decode(checkResponse.body);
          final fromData = checkData['from'];
          final fromId = fromData != null ? fromData['id']?.toString() : '';
          final fromName = fromData != null ? fromData['name']?.toString() : '';

          debugPrint('📊 [Facebook Diagnostics] Post Check Details:');
          debugPrint('  - ID: $postId');
          debugPrint('  - Publisher (from): $fromName (ID: $fromId)');

          if (fromId != pageId) {
            debugPrint('🚨 [Facebook Diagnostics] CRITICAL: Post was made by User ($fromId) and not the Page ($pageId)!');
            Get.snackbar(
              '🚨 خطأ في ملكية المنشور',
              'تم النشر ولكن باسم حسابك الشخصي وليس باسم الصفحة التجارية. يرجى تعديل الربط في الإعدادات واستخدام رمز الصفحة.',
              backgroundColor: const Color(0xFF3D1F1F),
              colorText: const Color(0xFFFFD3D3),
              duration: const Duration(seconds: 8),
            );
          } else {
            debugPrint('🎉 [Facebook Diagnostics] SUCCESS: Post is successfully owned by the Page ($fromName).');
          }
        } else {
          debugPrint('⚠️ [Facebook Diagnostics] Failed to verify post ownership details: ${checkResponse.body}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Facebook Diagnostics] Exception in diagnostic checker: $e');
    }
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
