import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SocialMediaApiClient {
  // 🔑 Provider 1: All-In-One (Existing)
  static const String _apiKey1 = '409ef64155mshd42a0fcfa03acb3p15198djsn4729fcaa5865'; 
  static const String _apiHost1 = 'all-in-one-social-scraper-tiktok-instagram-pro.p.rapidapi.com'; 

  // 🔑 Provider 2: TIKWM (TikTok Specific - High Reliability)
  static const String _apiHostTikTok = 'tiktok-scraper7.p.rapidapi.com';

  // 🔑 Provider 3: MediaCrawlers (Instagram Specific)
  static const String _apiHostInstagram = 'instagram-api-fast-reliable-data-scraper.p.rapidapi.com';

  /// 🎯 المحاولة عبر المزود الرئيسي (All-In-One)
  Future<Map<String, dynamic>?> getVideoInfoPrimary(String url) async {
    String endpoint = url.contains('tiktok.com') ? 'tiktok' : 'fetch';
    final Uri uri = Uri.parse('https://$_apiHost1/$endpoint?url=${Uri.encodeComponent(url)}');
    return _makeRequest(uri, _apiHost1, _apiKey1);
  }

  /// 🎯 المحاولة عبر TIKWM (للتيك توك فقط)
  Future<Map<String, dynamic>?> getTikTokInfoBackup(String url) async {
    // التصحيح: المزود يتوقع video_url وليس url
    final Uri uri = Uri.parse('https://$_apiHostTikTok/feed/video?video_url=${Uri.encodeComponent(url)}');
    return _makeRequest(uri, _apiHostTikTok, _apiKey1);
  }

  /// 🎯 المحاولة عبر MediaCrawlers (للانستقرام فقط)
  Future<Map<String, dynamic>?> getInstagramInfoBackup(String url) async {
    // التصحيح: التأكد من معامل url
    final Uri uri = Uri.parse('https://$_apiHostInstagram/reels?url=${Uri.encodeComponent(url)}');
    return _makeRequest(uri, _apiHostInstagram, _apiKey1);
  }

  /// 🌐 دالة تنفيذ الطلب الموحدة
  Future<Map<String, dynamic>?> _makeRequest(Uri uri, String host, String key) async {
    try {
      final response = await http.get(uri, headers: {
        'x-rapidapi-key': key,
        'x-rapidapi-host': host,
      });

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 429) {
        debugPrint('⚠️ Quota Limit Reached for $host');
        return {'error': '429', 'message': 'Quota exceeded'};
      } else {
        debugPrint('❌ API Error ($host): ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ SocialMediaApiClient Exception ($host): $e');
      return null;
    }
  }
}
