// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  if (args.length < 3) {
    print('❌ Usage: dart test_facebook_publish.dart <access_token> <page_id> <video_url> [message]');
    exit(1);
  }

  final token = args[0];
  final pageId = args[1];
  final videoUrl = args[2];
  final message = args.length > 3 ? args[3] : 'Test Facebook video post from Smart Content Creator CLI';

  final endpoint = 'https://graph.facebook.com/v20.0/$pageId/videos';
  
  print('🌐 Request Endpoint: $endpoint');
  print('📤 Payload:');
  print('  - file_url: $videoUrl');
  print('  - description: $message');
  print('  - access_token: [HIDDEN]');
  
  try {
    // 1. تنفيذ طلب النشر الفعلي
    final response = await http.post(
      Uri.parse(endpoint),
      body: {
        'file_url': videoUrl,
        'description': message,
        'access_token': token,
      },
    ).timeout(Duration(seconds: 30));

    print('\n📥 Raw Meta Response (Status Code: ${response.statusCode}):');
    print(response.body);

    final resData = json.decode(response.body);
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final postId = resData['id'] ?? resData['post_id'] ?? 'N/A';
      print('\n✅ Published Request: SUCCESS');
      print('🆔 post_id: $postId');
      
      print('\n⏳ Waiting 5 seconds for Facebook to process the media before detailed diagnostics...');
      await Future.delayed(Duration(seconds: 5));

      // 2. فحص تفاصيل المنشور: GET /{post-id}?fields=id,permalink_url,is_published,status,from,created_time
      final checkUrl = 'https://graph.facebook.com/v20.0/$postId?fields=id,permalink_url,is_published,status,from,created_time&access_token=$token';
      print('\n🔍 Step 1: Querying Published Post Details:');
      print('🌐 GET: https://graph.facebook.com/v20.0/$postId?fields=id,permalink_url,is_published,status,from,created_time');
      
      final checkResponse = await http.get(Uri.parse(checkUrl)).timeout(Duration(seconds: 15));
      print('📥 Response:');
      print(checkResponse.body);

      final checkData = json.decode(checkResponse.body);
      
      bool isPublished = false;
      String status = 'unknown';
      String fromId = '';
      String fromName = '';

      if (checkResponse.statusCode == 200) {
        isPublished = checkData['is_published'] ?? false;
        status = checkData['status'] ?? 'N/A';
        fromId = checkData['from'] != null ? checkData['from']['id']?.toString() ?? '' : '';
        fromName = checkData['from'] != null ? checkData['from']['name']?.toString() ?? '' : '';
      }

      // 3. فحص خلاصة الصفحة: GET /{page-id}/feed?fields=id,message,permalink_url,is_published,from
      final feedUrl = 'https://graph.facebook.com/v20.0/$pageId/feed?fields=id,message,permalink_url,is_published,from&access_token=$token';
      print('\n🔍 Step 2: Querying Page Feed to verify visibility:');
      print('🌐 GET: https://graph.facebook.com/v20.0/$pageId/feed?fields=id,message,permalink_url,is_published,from');
      
      final feedResponse = await http.get(Uri.parse(feedUrl)).timeout(Duration(seconds: 15));
      print('📥 Response:');
      print(feedResponse.body);

      final feedData = json.decode(feedResponse.body);
      
      bool foundInFeed = false;
      if (feedResponse.statusCode == 200 && feedData['data'] != null) {
        final List<dynamic> posts = feedData['data'];
        for (final post in posts) {
          final pId = post['id']?.toString() ?? '';
          if (pId == postId) {
            foundInFeed = true;
            break;
          }
        }
      }

      // 4. تحليل النتيجة والتشخيص النهائي
      print('\n📊 --- FINAL DIAGNOSTIC REPORT ---');
      print('🟢 is_published: $isPublished');
      print('📋 status: $status');
      print('👤 from: $fromName (ID: $fromId)');
      print('📰 Found in Page Feed: $foundInFeed');

      if (!isPublished) {
        print('\n🚨 DIAGNOSIS: The post is NOT published yet (is_published = false).');
        print('💡 Reason: It is still in Draft/Processing phase or published as unpublished content.');
        print('🛠️ Solution: Ensure video finishes encoding, or ensure you are not passing published=false parameters.');
      } else if (status.toLowerCase() != 'published') {
        print('\n🚨 DIAGNOSIS: The post status is not "published" (status = $status).');
        print('💡 Reason: Facebook has not finalized the media processing or it failed post-processing.');
      } else if (fromId.isNotEmpty && fromId != pageId) {
        print('\n🚨 DIAGNOSIS: The post owner is NOT the Page itself (from = $fromId, pageId = $pageId).');
        print('💡 Reason: You used a User Access Token (posted as user) instead of a Page Access Token.');
        print('🛠️ Solution: Obtain a proper Page Access Token. You must request a token for the specific Page, not the user account.');
      } else if (!foundInFeed) {
        print('\n🚨 DIAGNOSIS: The post is published but NOT present in the Page\'s public feed.');
        print('💡 Reason: This indicates restrictions on the page or the post (e.g. demographic restrictions, App is in Development Mode, or published to an unpublished page).');
        print('🛠️ Solution: Verify Page settings, Country/Age restrictions, and make sure your Meta App is switched to Live Mode.');
      } else {
        print('\n🎉 CONFIRMED: The post is successfully published, owned by the Page, and visible on the Page feed!');
        print('💡 Note: If other users still cannot see it, check if your Meta Developer App is in Development Mode.');
      }
    } else {
      print('\n❌ Published: FAILED');
      if (resData['error'] != null) {
        final err = resData['error'];
        print('⚠️ Error Message: ${err['message']}');
        print('🔴 Error Code: ${err['code']}');
        print('🔴 Error Subcode: ${err['error_subcode'] ?? 'N/A'}');
      } else {
        print('⚠️ Unknown Error occurred');
      }
    }
  } catch (e) {
    print('❌ Connection Error: $e');
  }
}
