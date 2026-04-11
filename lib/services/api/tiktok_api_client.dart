import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/log_service.dart';

class TikTokApiClient {
  final String? apiKey;
  final String? clientKey;
  final String? clientSecret;
  final Dio _dio = Dio();

  TikTokApiClient({this.apiKey, this.clientKey, this.clientSecret}) {
    _dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      logPrint: (obj) => LogService.debug('🎵 [TIKTOK_LOG]: $obj', tag: 'TikTok'),
    ));
  }

  /// Optimized fetch: Trending or Search
  Future<List<Map<String, dynamic>>> getTrendingVideos(
      {String query = '', int limit = 20}) async {
    final cleanQuery = query.trim();

    // 1. If we have a Proxy API Key (TikAPI / RapidAPI / etc.)
    if (apiKey != null && apiKey!.trim().isNotEmpty) {
      debugPrint(
          '🌐 استخدام مفتاح Proxy (RapidAPI)${cleanQuery.isNotEmpty ? " للبحث عن: $cleanQuery" : ""}...');

      // Try multiple hosts in order
      final hosts = [
        'api.tikapi.io', // Direct TikAPI
        'tikapi.p.rapidapi.com',
        'tiktok-scraper2.p.rapidapi.com',
        'tiktok-video-no-watermark2.p.rapidapi.com',
      ];

      for (final host in hosts) {
        try {
          // Add slight random delay to avoid burst rate limits if retrying
          if (hosts.indexOf(host) > 0) {
            await Future.delayed(const Duration(milliseconds: 500));
          }

          final result = await _fetchWithProxyHost(host, apiKey!.trim(), limit,
              query: cleanQuery);
          if (result.isNotEmpty) return result;
          debugPrint('⚠️ Host $host returned empty result, trying next...');
        } catch (e) {
          debugPrint('⚠️ Host $host failed: $e');
          // Continue to next host if it's a 403, 404, or 429
        }
      }
    }

    // 2. If we have official Client Key/Secret
    // 🛡️ Guard: Only try official if key doesn't look like an Apify token
    final cKey = clientKey?.trim() ?? '';
    final cSecret = clientSecret?.trim() ?? '';

    if (cKey.isNotEmpty &&
        cSecret.isNotEmpty &&
        !cKey.startsWith('apify_') &&
        !cKey.contains('rapidapi')) {
      debugPrint('🔐 استخدام API تيك توك الرسمي (Client Credentials)...');
      try {
        final token = await _getAccessToken();
        return await _fetchOfficial(token, limit);
      } catch (e) {
        debugPrint('⚠️ فشل استخدام API تيك توك الرسمي: $e');
      }
    }

    throw Exception("TikTok API credentials not configured or failed.");
  }

  /// Fetch info for a specific video URL
  Future<Map<String, dynamic>?> getVideoInfoByUrl(String videoUrl) async {
    if (apiKey == null || apiKey!.isEmpty) return null;

    // Extract ID from URL if possible (e.g., .../video/123456)
    String? videoId;
    final idMatch = RegExp(r'\/video\/(\d+)').firstMatch(videoUrl);
    if (idMatch != null) {
      videoId = idMatch.group(1);
    }

    final hosts = [
      'tiktok-scraper2.p.rapidapi.com',
      'tikapi.p.rapidapi.com',
    ];

    for (final host in hosts) {
      try {
        String endpoint = '';
        Map<String, dynamic> params = {};

        if (host.contains('scraper2')) {
          endpoint = 'https://$host/video/info_v2';
          params['video_url'] = videoUrl;
          if (videoId != null) params['video_id'] = videoId;
        } else {
          endpoint = 'https://$host/rest/tiktok/video/info';
          params['url'] = videoUrl;
        }

        debugPrint('🚀 Requesting Video Info ($host): $videoUrl');

        final response = await _dio.get(
          endpoint,
          options: Options(headers: {
            'X-RapidAPI-Key': apiKey,
            'X-RapidAPI-Host': host,
          }, validateStatus: (status) => true), // Don't throw to see code
          queryParameters: params,
        );

        debugPrint('📥 Info Response Status ($host): ${response.statusCode}');

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          // Scraper2 usually returns video info in 'video_info' or directly
          final info = data['video_info'] ?? data['data'] ?? data;
          if (info is Map) {
            final mapped = _mapProxyToInternal(info as Map<String, dynamic>);
            if (mapped.isNotEmpty) {
              debugPrint('✅ Successfully mapped video info from $host');
              return mapped;
            }
          }
        } else {
          debugPrint(
              '⚠️ Host $host returned status ${response.statusCode}: ${response.data}');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to get video info from $host: $e');
      }
    }
    return null;
  }

  Future<String> _getAccessToken() async {
    try {
      final response = await _dio.post(
        'https://open-api.tiktok.com/oauth/client_token/',
        data: {
          'client_key': clientKey?.trim(),
          'client_secret': clientSecret?.trim(),
          'grant_type': 'client_credentials',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data != null && data['access_token'] != null) {
          return data['access_token'] as String;
        }
      }
      throw Exception("Response error: ${response.data}");
    } on DioException catch (e) {
      throw Exception("DioError: ${e.response?.data ?? e.message}");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOfficial(
      String token, int limit) async {
    // Official TikTok Display API - Trending
    // Note: Official API often needs specific permissions (e.g., 'video.list')
    final response = await _dio.get(
      'https://open-api.tiktok.com/video/list/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      queryParameters: {
        'cursor': 0,
        'max_count': limit,
        'fields': 'id,desc,video,author,statistics',
      },
    );

    if (response.statusCode == 200) {
      final List videos = response.data['data']['videos'] ?? [];
      return videos
          .map<Map<String, dynamic>>(
              (v) => _mapOfficialToInternal(v as Map<String, dynamic>))
          .toList();
    }
    throw Exception("Failed to fetch official TikTok videos.");
  }

  Future<List<Map<String, dynamic>>> _fetchWithProxyHost(
      String host, String key, int limit,
      {String query = ''}) async {
    try {
      String endpoint = '';
      Map<String, dynamic> params = {'count': limit};

      if (host.contains('tikapi')) {
        // Support both RapidAPI and Direct TikAPI
        endpoint = query.isEmpty
            ? 'https://$host/public/trending' // TikAPI Direct/Rapid often use /public or /rest
            : 'https://$host/public/search/top';

        // Fallback for RapidAPI specific paths if different
        if (host.contains('rapidapi')) {
          endpoint = query.isEmpty
              ? 'https://$host/rest/tiktok/trending'
              : 'https://$host/rest/tiktok/search';
        }

        if (query.isNotEmpty) params['query'] = query;
      } else if (host.contains('scraper2')) {
        // tiktok-scraper2 specific endpoints
        if (query.isEmpty || query == 'trending') {
          endpoint = 'https://$host/video/feed';
        } else {
          endpoint = 'https://$host/video/search';
          params['keywords'] = query;
        }
      } else {
        // Generic / standard endpoints for other hosts (like no-watermark2)
        // Adjust these common patterns
        if (query.isEmpty) {
          endpoint = 'https://$host/feed'; // Try generic feed
          // Fallback URLs if 'feed' is not standard on this host
          if (host.contains('no-watermark2')) {
            endpoint = 'https://$host/feed/list';
          }
        } else {
          endpoint = 'https://$host/feed/search';
          params['keywords'] = query;
        }
      }

      debugPrint('🚀 Requesting TikTok Proxy ($host): $endpoint');

      final Map<String, String> headers = {
        'Accept': 'application/json',
      };

      // AUTH HEADER LOGIC
      if (host == 'api.tikapi.io') {
        headers['X-API-KEY'] = key;
      } else {
        headers['X-RapidAPI-Key'] = key;
        headers['X-RapidAPI-Host'] = host;
      }

      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: headers,
          validateStatus: (status) => true,
        ),
        queryParameters: params,
      );

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
            'خطأ في الصلاحيات (403) لـ $host. تأكد من الاشتراك في الخدمة.');
      }

      if (response.statusCode == 404) {
        // Special logic for scraper2 trending/feed 404 - FORCE SEARCH to break loop
        if ((query.isEmpty || query == 'trending') &&
            host.contains('scraper2') &&
            endpoint.contains('feed')) {
          debugPrint(
              '🔄 Scraper2 feed 404. Switching to specific search for "viral" to allow fallback...');
          // Use a different query to force the search path, preventing infinite loop
          return _fetchWithProxyHost(host, key, limit, query: 'tiktok viral');
        }
        debugPrint('ℹ️ Endpoint $endpoint not supported by $host (404)');
        return [];
      }

      if (response.statusCode == 429) {
        debugPrint('⚠️ Rate limit (429) on $host. Switching provider...');
        throw Exception('Rate limit exceeded');
      }

      if (response.data != null) {
        dynamic data = response.data;

        // Handle HTML or String responses
        if (data is String) {
          final trimmed = data.trim();
          if (trimmed.startsWith('<!doctype html>') ||
              trimmed.startsWith('<html') ||
              trimmed.contains('<body')) {
            debugPrint('⚠️ Warning: API returned HTML instead of JSON.');
            debugPrint('   Check if your API Key is valid and active.');
            return [];
          }
          try {
            data = json.decode(data);
          } catch (e) {
            debugPrint('❌ JSON Decode Error: $e');
            return [];
          }
        }

        List videos = [];
        if (data is Map) {
          final map = data as Map<String, dynamic>;

          // TikAPI usually wraps items in 'itemList' or 'data'
          // Scraper2 might use 'videos', 'posts', or 'data'
          videos = map['itemList'] ??
              map['item_list'] ??
              map['data'] ??
              map['videos'] ??
              map['posts'] ??
              map['items'] ??
              [];

          if (videos.isEmpty && map['data'] is Map) {
            final internalData = map['data'] as Map;
            videos = internalData['itemList'] ??
                internalData['item_list'] ??
                internalData['videos'] ??
                internalData['posts'] ??
                internalData['items'] ??
                [];
          }

          // Final fallback for direct list results
          if (videos.isEmpty && map.containsKey('aweme_list')) {
            videos = map['aweme_list'];
          }
          if (videos.isEmpty && map.containsKey('video_list')) {
            videos = map['video_list'];
          }

          if (videos.isEmpty) {
            debugPrint('🔦 Deep searching JSON for any data list...');
            map.forEach((key, value) {
              if (value is List &&
                  value.isNotEmpty &&
                  videos.isEmpty &&
                  key != 'challenges') {
                videos = value;
              }
            });
          }
        } else if (data is List) {
          videos = data;
        }

        debugPrint('✅ Found ${videos.length} items from API');

        return videos
            .map<Map<String, dynamic>>((v) {
              try {
                if (v is! Map) return <String, dynamic>{};
                return _mapProxyToInternal(v as Map<String, dynamic>);
              } catch (e) {
                return <String, dynamic>{};
              }
            })
            .where((v) => v.isNotEmpty)
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error in _fetchWithProxyKey: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _mapOfficialToInternal(Map<String, dynamic> v) {
    return {
      'id': v['id'] ?? '',
      'username': (v['author'] as Map?)?['unique_id'] ?? 'TikTok User',
      'caption': v['desc'] ?? '',
      'videoUrl': (v['video'] as Map?)?['play_addr'] ?? '',
      'thumbnailUrl': (v['video'] as Map?)?['cover'] ?? '',
      'shareUrl':
          'https://www.tiktok.com/@${(v['author'] as Map?)?['unique_id']}/video/${v['id']}',
      'likes': (v['statistics'] as Map?)?['digg_count'] ?? 0,
      'views': (v['statistics'] as Map?)?['play_count'] ?? 0,
      'shares': (v['statistics'] as Map?)?['share_count'] ?? 0,
      'comments': (v['statistics'] as Map?)?['comment_count'] ?? 0,
      'hashtags': [], // Will be parsed locally or from desc
      'rawJson': v,
    };
  }

  Map<String, dynamic> _mapProxyToInternal(Map<String, dynamic> v) {
    // TikAPI/Scraper structure can vary wildly
    final author = (v['author'] as Map?) ??
        (v['authorMeta'] as Map?) ??
        (v['user'] as Map?) ??
        {};
    final video = (v['video'] as Map?) ?? v; // sometimes flat
    final stats = (v['stats'] as Map?) ??
        (v['statistics'] as Map?) ??
        v; // sometimes flat

    // Extracting Video URL - try standard then nested
    String videoUrl = video['downloadAddr'] ??
        video['playAddr'] ??
        video['play_addr'] ??
        video['download_url'] ??
        v['webVideoUrl'] ??
        v['play'] ?? // scraper2 common field
        '';

    if (videoUrl.isEmpty && video['play_addr'] is Map) {
      videoUrl = video['play_addr']['url_list']?[0] ?? '';
    }

    return {
      'id': v['id'] ?? v['item_id'] ?? v['aweme_id'] ?? '',
      'username': author['uniqueId'] ??
          author['unique_id'] ??
          author['name'] ??
          author['nickname'] ??
          author['nickName'] ??
          'TikTok User',
      'caption': v['desc'] ?? v['title'] ?? v['text'] ?? v['description'] ?? '',
      'videoUrl': videoUrl,
      'videoUrlNoWatermark': video['downloadAddr'] ??
          video['download_url'], // 🆕 Specific no-watermark field
      'thumbnailUrl': video['originCover'] ??
          video['origin_cover'] ??
          video['cover'] ??
          video['dynamicCover'] ??
          '',
      'shareUrl': v['share_url'] ??
          v['shareUrl'] ??
          'https://www.tiktok.com/@${author['uniqueId'] ?? author['unique_id']}/video/${v['id'] ?? v['item_id'] ?? v['aweme_id']}',
      'likes': stats['diggCount'] ?? stats['digg_count'] ?? 0,
      'views': stats['playCount'] ?? stats['play_count'] ?? 0,
      'shares': stats['shareCount'] ?? stats['share_count'] ?? 0,
      'comments': stats['commentCount'] ?? stats['comment_count'] ?? 0,
      'hashtags':
          (v['challenges'] as List?)?.map((c) => '#${c['title']}').toList() ??
              [],
      'rawJson': v,
    };
  }
}
