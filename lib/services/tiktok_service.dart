import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/utils/snackbar_utils.dart';

import '../controllers/settings_controller.dart';
import '../core/models/tiktok_video.dart';
import 'api/tiktok_api_client.dart';

class TikTokService {
  final Dio _dio = Dio();

  /// Helper to safely parse any value to String
  String parseSafe(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  // Apify Configuration
  // Cache Definition: Query -> {ts, videos}
  final Map<String, Map<String, dynamic>> _resultCache = {};

  final String _fallbackApiToken = ''; // 🛡️ Removed hardcoded token for GitHub security

  String get _activeApiToken {
    try {
      final settings = Get.find<SettingsController>();
      final token = settings.tiktokApifyToken.value.trim();
      if (token.isNotEmpty) return token;

      final proxyKey = settings.tiktokProxyKey.value.trim();
      if (proxyKey.startsWith('apify_api_')) return proxyKey;

      final clientKey = settings.tiktokClientKey.value.trim();
      if (clientKey.startsWith('apify_api_')) return clientKey;
    } catch (_) {}
    return _fallbackApiToken;
  }

  /// 🔗 جلب رابط تسجيل الدخول الصحيح (v2)
  String generateAuthUrl() {
    final settings = Get.find<SettingsController>();
    final clientKey = settings.tiktokClientKey.value.trim();

    // 💡 هذا الرابط يجب أن يكون مسجلاً في TikTok Developer Portal بالملي!
    const redirectUri =
        "https://smartcontentcreator-d49f2.web.app/auth/tiktok/callback";

    if (clientKey.isEmpty) return "";

    // 🚀 Using simplified scopes with comma for test
    const scopes = "user.info.basic,video.list,video.upload";

    return "https://www.tiktok.com/v2/auth/authorize/"
        "?client_key=$clientKey"
        "&scope=${Uri.encodeComponent(scopes)}"
        "&response_type=code"
        "&redirect_uri=${Uri.encodeComponent(redirectUri)}"
        "&state=${DateTime.now().millisecondsSinceEpoch}";
  }

  /// 🔌 التحقق من حالة الاتصال برصيد Apify
  Future<bool> testConnection() async {
    final token = _activeApiToken;
    if (token.isEmpty) return false;

    try {
      // محاولة استدعاء بسيط للـ API (جلب معلومات المستخدم) للتحقق من الصلاحية والارصدة
      final response = await _dio
          .get(
            'https://api.apify.com/v2/users/me?token=$token',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ TikTokService Test Connection Failed: $e');
      if (e.toString().contains('402')) {
        // Budget exhausted
        throw Exception(
            "رصيد Apify استنفذ بالكامل (402). يرجى شحن الرصيد أو تغيير المفتاح.");
      }
      if (e.toString().contains('401')) {
        // Invalid token
        throw Exception("مفتاح Apify غير صحيح (401).");
      }
      return false;
    }
  }

  final String _defaultActorId = 'clockworks~tiktok-scraper';

  // Dynamic Endpoint Helper - Using 'acts' for better compatibility with ~ format names
  String _getRunsEndpoint(String actorId) =>
      'https://api.apify.com/v2/acts/$actorId/runs';
  String _getRunStatusEndpoint(String runId) =>
      'https://api.apify.com/v2/actor-runs/$runId';

  /// 🎯 Smart Query Builder: Generate precise search queries
  /// Combines brand names, bilingual keywords, and filtering terms
  String _buildSmartSearchQuery({
    required String productName,
    String? brandName,
    String? brandNameEn,
    bool includeReviewKeywords = true,
  }) {
    List<String> queryParts = [];

    // 🛡️ Filter generic placeholders (N/A, Unknown, etc.)
    bool isGeneric(String? s) {
      if (s == null || s.isEmpty) return true;
      final lower = s.toLowerCase();
      return [
        'n/a',
        'unknown',
        'none',
        'null',
        'undefined',
        'غير معروف',
        'لا يوجد',
        'غير واضح',
        'غير محدد',
        'product',
        'item',
        'منتج'
      ].any((p) => lower.contains(p));
    }

    bool hasBrand = !isGeneric(brandName);
    bool hasBrandEn = !isGeneric(brandNameEn);

    // 🧼 Clean product name from conversational fillers
    String cleanProduct = _cleanProductName(productName);

    // If cleaned name is generic, we try to use brands instead
    if (isGeneric(cleanProduct)) {
      if (hasBrandEn) {
        cleanProduct = brandNameEn!;
      } else if (hasBrand) {
        cleanProduct = brandName!;
      } else {
        cleanProduct = "viral trends"; // Fallback to avoid empty query
      }
    }

    final Set<String> uniqueTokens = {};

    // 1. Brand + Product (Only quote if short, otherwise let TikTok's algorithm handle broad match)
    if (hasBrand) {
      if (hasBrandEn) {
        final combined = "$brandNameEn $cleanProduct";
        uniqueTokens
            .add(combined.split(' ').length <= 3 ? '"$combined"' : combined);
      }
      final combinedAr = "$brandName $cleanProduct";
      uniqueTokens.add(
          combinedAr.split(' ').length <= 3 ? '"$combinedAr"' : combinedAr);
    } else {
      // No valid brand detected, use product name only
      uniqueTokens.add(cleanProduct);
    }

    queryParts.addAll(uniqueTokens);

    // 2. Add filtering keywords to eliminate irrelevant results
    if (includeReviewKeywords) {
      queryParts.add('مراجعة'); // Arabic: review
      queryParts.add('review'); // English: review
      queryParts.add('unboxing'); // Unboxing videos
      queryParts.add('الأصلي'); // Arabic: original/authentic
    }

    final smartQuery = queryParts.join(' ');
    debugPrint('🎯 Smart Query Built: $smartQuery');
    return smartQuery;
  }

  /// 🧼 Cleans conversational filler words and truncates long product names for better search matching
  String _cleanProductName(String text) {
    if (text.isEmpty) return "";

    // 1️⃣ Remove content inside parentheses or brackets (often AI-generated SEO noise)
    // e.g., "Product Name (Unboxing, Review)" -> "Product Name"
    String result = text.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '');

    // 2️⃣ Remove Arabic & English fillers
    final fillers = [
      'ما هي',
      'اريد',
      'بحث عن',
      'ترندات',
      'مناسبة ل',
      'عرض لي',
      'اعطني',
      'تيك توك',
      'TikTok',
      'فيديو',
      'مقاطع',
      '؟',
      '!',
      'المنتج',
      'review',
      'unboxing',
      'demonstration',
      'presentation'
    ];

    for (var filler in fillers) {
      // Use regex with caseInsensitive for English fillers
      result = result.replaceAll(RegExp(filler, caseSensitive: false), '');
    }

    // 3️⃣ Clean punctuation that might break simple keyword matching
    result = result.replaceAll(RegExp(r'[,.;:|#]'), ' ');

    // 4️⃣ ✂️ Smart Truncation: Limit to core keywords (Max 6 words)
    // Long sentences in search queries often lead to ZERO results
    List<String> words =
        result.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length > 6) {
      result = words.take(6).join(' ');
      debugPrint("✂️ Truncated long name to keywords: $result");
    } else {
      result = words.join(' ');
    }

    return result.isEmpty ? text : result;
  }

  /// Dual-Mode Trending Fetch: 'deep' (Strict engagement/quality) or 'general' (Search match)
  Future<List<Map<String, dynamic>>> fetchTrendingVideos({
    String query = '',
    int limit = 4,
    int offset = 0,
    String country = 'United States',
    String mode = 'general', // 'deep' or 'general'
    bool allowEnhancement = true, // 🚀 Control query expansion
    String? brandName, // 🎯 NEW: Brand name in Arabic
    String? brandNameEn, // 🎯 NEW: Brand name in English
    bool useSmartQuery = false, // 🎯 NEW: Use smart query builder
  }) async {
    // 🎯 Smart Query Builder: Use if brand info is provided
    String enhancedQuery = query.trim();

    // Calculate shouldEnhance for later use
    bool shouldEnhance = allowEnhancement &&
        enhancedQuery.isNotEmpty &&
        enhancedQuery.toLowerCase() != 'trending' &&
        !enhancedQuery.startsWith('http') &&
        enhancedQuery.split(' ').length <= 3;

    if (useSmartQuery && enhancedQuery.isNotEmpty) {
      enhancedQuery = _buildSmartSearchQuery(
        productName: enhancedQuery,
        brandName: brandName,
        brandNameEn: brandNameEn,
        includeReviewKeywords: true,
      );
    } else {
      // 🧠 Legacy Enhancement: Only add keywords if it's a generic/short query
      if (shouldEnhance) {
        if (mode == 'deep') {
          enhancedQuery =
              "$enhancedQuery 4k high quality trending viral cinematic";
        } else {
          enhancedQuery = "$enhancedQuery review unboxing demonstration";
        }
        debugPrint("🔍 Enhanced Query ($mode): $enhancedQuery");
      }
    }

    final cacheKey = "${enhancedQuery}_${mode}_${offset}_$limit";

    // 📦 Check Cache First (High Performance)
    if (_resultCache.containsKey(cacheKey)) {
      final entry = _resultCache[cacheKey]!;
      final age = DateTime.now().difference(entry['ts']).inMinutes;
      if (age < 5) {
        debugPrint("🚀 Cache Hit: Returning stored results for '$cacheKey'");
        return entry['videos'] as List<Map<String, dynamic>>;
      }
    }

    // Check if query is a direct TikTok URL
    if (query.trim().startsWith('http') &&
        (query.contains('tiktok.com') || query.contains('vt.tiktok.com'))) {
      debugPrint('🔗 Detect direct TikTok URL import: $query');
      final videoInfo = await getVideoInfo(query.trim());
      if (videoInfo != null) {
        return [videoInfo];
      }
    }

    // 1. Try Official TikTok API or Proxy if keys exist
    try {
      final settings = Get.find<SettingsController>();
      if (settings.tiktokClientKey.value.trim().isNotEmpty ||
          settings.tiktokProxyKey.value.trim().isNotEmpty) {
        final client = TikTokApiClient(
          clientKey: settings.tiktokClientKey.value,
          clientSecret: settings.tiktokClientSecret.value,
          apiKey: settings.tiktokProxyKey.value,
        );
        // Note: Offset support depends on the API implementation
        return await client.getTrendingVideos(
            query: enhancedQuery, limit: limit);
      }
    } catch (e) {
      debugPrint('⚠️ فشل استخدام API تيك توك: $e');
    }

    final settings = Get.find<SettingsController>();
    String actorId = settings.tiktokActorId.value.trim();

    if (actorId.isEmpty || actorId.contains('apify~tiktok-scraper')) {
      actorId = _defaultActorId;
    }

    // 2. Fallback to Apify Scraper
    final apiToken = _activeApiToken;

    if (apiToken == 'YOUR_APIFY_API_TOKEN' || apiToken.isEmpty) {
      debugPrint('⚠️ لا يوجد رمز دخول Apify. سيتم استخدام بيانات تجريبية.');
      return _getMockTrendingVideos(enhancedQuery);
    }

    try {
      Map<String, dynamic>? runData;
      String usedActorId =
          actorId.contains('/') ? actorId.replaceAll('/', '~') : actorId;

      try {
        // Fetch MORE than needed to allow for strict filtering on our side
        // offset/limit handled by slicing the dataset results
        final fetchCount = offset + limit + 10;
        runData = await _startActorRun(usedActorId, country, fetchCount,
            query: enhancedQuery);
      } catch (e) {
        if (e.toString().contains('402')) {
          SnackBarUtils.showSmartSnackBar(
            title: 'تنبيه Apify',
            message: 'انتهى رصيد Apify! يرجى مراجعة اشتراكك أو مفتاح API.',
            isError: true,
          );
        }
        debugPrint('❌ Failed to start actor $usedActorId: $e');
        throw Exception("فشل تشغيل الكاشط: $e");
      }

      final runId = runData['id'];
      final defaultDatasetId = runData['defaultDatasetId'];

      if (runId == null || defaultDatasetId == null) {
        throw Exception('فشل بدء التشغيل: استجابة غير صالحة');
      }

      debugPrint('🚀 بدأ تشغيل الكاشط (Scraper): $runId');

      // 3. Poll for Completion
      await _waitForRunToFinish(usedActorId, runId);

      // 4. Fetch Results from Dataset
      final items = await _fetchDatasetItems(defaultDatasetId);

      // 5. Convert to Model & Filter
      final List<TikTokVideo> allVideos = [];
      for (var item in items) {
        try {
          // 🚀 FIX: Handle nested video object if present
          final video = item['video'] is Map
              ? item['video'] as Map<String, dynamic>
              : null;

          final json = {
            'title': parseSafe(item['text'] ??
                item['desc'] ??
                item['caption'] ??
                item['title']),
            'cover': parseSafe(video?['originCover'] ??
                video?['cover'] ??
                video?['dynamicCover'] ??
                item['imageUrl'] ??
                item['covers']?['default']),
            'videoUrl': parseSafe(
                item['videoUrl'] ?? item['webVideoUrl'] ?? video?['playAddr']),
            'videoUrlNoWatermark': parseSafe(
                item['videoUrlNoWatermark'] ?? video?['downloadAddr']),
            'author': {
              'nickname': parseSafe(item['authorMeta']?['name'] ??
                  item['authorMeta']?['nickName'] ??
                  item['author']?['nickname'] ??
                  item['username'] ??
                  'Unknown')
            },
            'play_count':
                item['playCount'] ?? item['views'] ?? video?['playCount'] ?? 0,
            'digg_count':
                item['diggCount'] ?? item['likes'] ?? video?['diggCount'] ?? 0,
            'create_time': item['createTime'] ?? item['createdAt'],
          };
          allVideos.add(TikTokVideo.fromJson(json));
        } catch (_) {}
      }

      // 🛡️ Apply Filters based on MODE
      allVideos.sort((a, b) => b.likes.compareTo(a.likes));

      List<TikTokVideo> filteredVideos =
          allVideos.where((v) => _isHighQualityTrend(v, mode: mode)).toList();

      // Pagination Slice
      if (offset >= filteredVideos.length) return [];

      final paginatedVideos = filteredVideos.skip(offset).take(limit).toList();

      // Fallback: If strict filtered EVERYTHING and offset is 0
      if (paginatedVideos.isEmpty && offset == 0 && allVideos.isNotEmpty) {
        debugPrint("⚠️ Strict filter removed all results. Returning top raw.");
        return allVideos.take(limit).map((v) => _videoToResult(v)).toList();
      }

      final videos = paginatedVideos.map((v) => _videoToResult(v)).toList();

      // 🚀 FIX: If zero results found with enhanced query, RETRY with raw query
      if (videos.isEmpty && shouldEnhance && offset == 0) {
        debugPrint(
            "🔄 Zero results with enhanced query. Retrying with raw: $query");
        return await fetchTrendingVideos(
          query: query,
          limit: limit,
          offset: offset,
          country: country,
          mode: 'general', // Force general on retry
          allowEnhancement: false, // 🚀 Disable expansion on retry
        );
      }

      // 💾 Save to Cache
      _resultCache[cacheKey] = {'ts': DateTime.now(), 'videos': videos};

      return videos;
    } catch (e) {
      debugPrint('❌ Error: $e. Returning mock.');
      return await _getMockTrendingVideos(enhancedQuery);
    }
  }

  /// 👤 جلب فيديوهات مستخدم محدد (حساب المستخدم الشخصي)
  Future<List<Map<String, dynamic>>> fetchUserVideos({
    required String username,
    int limit = 10,
  }) async {
    // تنظيف اسم المستخدم (إضافة @ إذا غابت)
    final cleanUsername = username.startsWith('@') ? username : '@$username';
    
    debugPrint('👤 Fetching videos for user: $cleanUsername');
    
    // نستخدم نفس محرك البحث ولكن بتركيز على اليوزر
    return await fetchTrendingVideos(
      query: cleanUsername,
      limit: limit,
      mode: 'general', // نستخدم general لضمان جلب كل شيء وليس فقط الفيديوهات الفايرال
      allowEnhancement: false, // لا نريد تحسين الكلمات، نريد اليوزر بالارتباط المباشر
    );
  }

  Map<String, dynamic> _videoToResult(TikTokVideo v) {
    return {
      'id': v.id,
      'author': v.author, // 👤 Unified key
      'title': v.title,   // 📱 Unified key
      'clip': v.videoUrl, // 🎬 Unified key
      'thumbnail': v.thumbnailUrl,
      'platform': 'tiktok',// 🌐 Explicit platform
      'duration': v.duration, // ⏱️ Duration support
      'views': v.views,
      'likes': v.likes,
      'create_time': v.createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  // Cache: Query -> {timestamp, data}
  final Map<String, dynamic> _trendCache = {};

  // Step 1: Start Run (with Cache Check)
  Future<Map<String, dynamic>> _startActorRun(
      String actorId, String country, int limit,
      {String query = ''}) async {
    // 🧠 Check Cache (5 min validity)
    if (_trendCache.containsKey(query)) {
      final cached = _trendCache[query];
      final age = DateTime.now().difference(cached['ts']).inMinutes;
      if (age < 5) {
        debugPrint("📦 Using Cached Result for '$query'");
        return cached['data'];
      }
    }

    final bool isSearchQuery =
        query.isNotEmpty && query.toLowerCase() != 'trending';

    final Map<String, dynamic> input = {
      "searchQueries": [isSearchQuery ? query : "trending"],
      "search": isSearchQuery ? query : "trending",
      "type": isSearchQuery ? "search" : "trending",
      "maxItems": limit, // Scraper limit matches request
      "resultsPerPage": limit,
      "shouldDownloadVideos": false,
    };

    final response = await _dio.post(
      '${_getRunsEndpoint(actorId)}?token=$_activeApiToken',
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
      data: input,
    );

    if (response.statusCode == 201) {
      final data = response.data['data'];
      return data;
    } else {
      throw Exception('فشل بدء التشغيل: ${response.statusCode}');
    }
  }

  // Step 2: Poll Check (Optimized)
  Future<void> _waitForRunToFinish(String actorId, String runId) async {
    bool isRunning = true;
    while (isRunning) {
      // 🚀 Turbo Poll: 1 second interval
      await Future.delayed(const Duration(seconds: 1));

      final response = await _dio.get(
        '${_getRunStatusEndpoint(runId)}?token=$_activeApiToken',
      );

      if (response.statusCode == 200) {
        final status = response.data['data']['status'];
        debugPrint('⏳ حالة التشغيل ($actorId): $status');
        if (status == 'SUCCEEDED') {
          isRunning = false;
        } else if (status == 'FAILED' || status == 'ABORTED') {
          throw Exception('فشل التشغيل في Apify: $status');
        }
      }
    }
  }

  // Step 3: Get Items
  Future<List<dynamic>> _fetchDatasetItems(String datasetId) async {
    final response = await _dio.get(
      'https://api.apify.com/v2/datasets/$datasetId/items?token=$_activeApiToken',
    );

    if (response.statusCode == 200) {
      return response.data; // List of items
    } else {
      throw Exception('فشل جلب البيانات: ${response.statusCode}');
    }
  }

  /// Fetch specific video info by URL
  Future<Map<String, dynamic>?> getVideoInfo(String videoUrl) async {
    try {
      final settings = Get.find<SettingsController>();
      final client = TikTokApiClient(
        apiKey: settings.tiktokProxyKey.value,
        clientKey: settings.tiktokClientKey.value,
        clientSecret: settings.tiktokClientSecret.value,
      );
      return await client.getVideoInfoByUrl(videoUrl);
    } catch (e) {
      debugPrint('❌ Scraper Error: $e');
      return null;
    }
  }

  // --- MOCK DATA FALLBACK ---
  Future<List<Map<String, dynamic>>> _getMockTrendingVideos(
      String query) async {
    debugPrint('ℹ️ استخدام البيانات التجريبية (Query: $query)...');

    try {
      // Load from asset
      final String jsonString = await rootBundle
          .loadString('lib/services/data/mock_tiktok_trends.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final allVideos =
          jsonList.map((item) => item as Map<String, dynamic>).toList();

      if (query.isEmpty || query.toLowerCase() == 'trending') return allVideos;

      // Filter mock data by query
      final filtered = allVideos.where((v) {
        final caption = parseSafe(v['caption']).toLowerCase();
        final user = parseSafe(v['username']).toLowerCase();
        final q = query.toLowerCase();

        return caption.contains(q) || user.contains(q);
      }).toList();

      return filtered;
    } catch (e) {
      debugPrint("⚠️ Failed to load mock JSON: $e");
      return [
        {
          'id': '6974862859000073478',
          'username': 'tiktok_trending',
          'caption': 'Check out this trending effect! ✨ #trending #viral',
          'hashtags': ['#trending', '#viral', '#effect'],
          'videoUrl':
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          'likes': '12M',
          'comments': '500K',
          'shares': '1M',
          'views': '100M',
          'cover':
              'https://picsum.photos/400/600', // Non-CORS-protected placeholder
        }
      ];
    }
  }

  /// Multi-layer Filter: Mode-aware
  bool _isHighQualityTrend(TikTokVideo v, {String mode = 'general'}) {
    final text = (v.title + v.author).toLowerCase();

    // 🥇 Layer 1: ALWAYS REJECT: Low Effort/Templates
    final lowEffortTerms = [
      'capcut',
      'template',
      'slideshow',
      'photo dump',
      'repost'
    ];
    if (lowEffortTerms.any((term) => text.contains(term))) {
      return false;
    }

    // 🚫 Spam/Ads
    if (text.contains('promo') ||
        text.contains('buy now') ||
        text.contains('link in bio')) {
      return false;
    }

    // 💎 MODE LOGIC
    final engagement = v.engagementRate;

    if (mode == 'deep') {
      // Deep Mode: Strict bar for viral potential
      if (engagement < 0.10) {
        return false;
      } // 10% engagement min
      if (v.views < 50000) {
        return false;
      } // High reach only
      if (v.likes < 5000) {
        return false;
      }

      // Video age: Prefer recent gems (under 90 days)
      final ageDays = DateTime.now().difference(v.createdAt).inDays;
      if (ageDays > 90) {
        return false;
      }
    } else {
      // General Mode: Relaxed bar for relevance (FIXED for niche products)
      if (engagement < 0.0) {
        return false;
      } // 🚀 Allow ANY positive engagement
      if (v.views < 100) {
        return false;
      } // 🚀 Relaxed to 100 views to show niche content
    }

    return true;
  }

  // 🚀 PLAN 3: Smart Trend Search & Social Commerce Logic

  /// 🧠 Generates a Deep Search Link for TikTok based on Product & Intent
  String generateTikTokSearchLink(String productName,
      {String? brand, String? model, bool isOriginalCheck = false}) {
    String query = "";

    // 🛠️ Strict Query Builder (Prioritize English for better results globally)
    // Format: Brand + Model + Product Name
    if (brand != null && brand.isNotEmpty) {
      query += "$brand ";
    }

    if (model != null && model.isNotEmpty) {
      query += "$model ";
    }

    query += productName; // Core product name

    if (isOriginalCheck) {
      // Authenticity Check
      query += " original vs fake review";
    } else {
      // General Reviews & Trends
      query += " review unboxing viral";
    }

    // Encode for URL
    String encodedQuery = Uri.encodeComponent(query.trim());

    // 📱 Deep Link (Forces App Open)
    // URL Scheme: tiktok://search?keyword=...
    // We return this scheme. The handler in ChatSmartAgent must handle the fallback to HTTPS if app is not installed.
    return "tiktok://search?keyword=$encodedQuery";
  }

  /// 🧠 Suggests Smart Hashtags based on Category
  List<String> getSuggestedHashtags(String category) {
    category = category.toLowerCase();
    if (category.contains("electronics") || category.contains("tech")) {
      return ["#tech", "#unboxing", "#أدوات_ذكية", "#review"];
    }
    if (category.contains("kitchen") || category.contains("food")) {
      return [
        "#kitchenhacks",
        "#cooking",
        "#عصارة_راف",
        "#أدوات_منزلية",
        "#طبخ"
      ];
    }
    if (category.contains("fashion") || category.contains("style")) {
      return ["#fashion", "#style", "#ootd", "#fashionhacks"];
    }
    if (category.contains("beauty") || category.contains("makeup")) {
      return ["#beauty", "#makeup", "#skincare", "#beautytips"];
    }

    // Default
    return ["#trending", "#explore", "#fyp", "#viral"];
  }
}
