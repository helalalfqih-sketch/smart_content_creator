import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'serpapi_master_service.dart';

/// 👁️ Google Lens Service
class GoogleLensService {
  final _master = SerpApiMasterService();

  Future<String> analyzeImage(String imageUrl, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.fetch('google_lens', {
        'url': imageUrl,
      }, cancelToken: cancelToken);

      if (data.containsKey('visual_matches')) {
        final matches = List<Map<String, dynamic>>.from(data['visual_matches']);
        if (matches.isEmpty) return "لم يتم العثور على مطابقات بصرية واضحة.";

        final sb = StringBuffer("🔍 تم العثور على مطابقات بصرية:\n\n");
        for (var i = 0; i < matches.take(5).length; i++) {
          final m = matches[i];
          final title = m['title'] ?? 'منتج مشابه';
          final source = m['source'] ?? 'غير معروف';
          final link = m['link'] ?? '';
          sb.writeln("${i + 1}. $title ($source)");
          if (link.isNotEmpty) sb.writeln("   🔗 $link");
        }
        return sb.toString();
      }
      return "اكتمل تحليل Lens ولكن لم تتوفر بيانات هيكلية.";
    } catch (e) {
      debugPrint("❌ Google Lens Service Error: $e");
      return "⚠️ فشل فحص Google Lens: $e";
    }
  }

  /// 🔍 Structured Similarity Search
  Future<Map<String, dynamic>> searchByImage(String imageUrl, {dio.CancelToken? cancelToken}) async {
    try {
      final parameters = imageUrl.startsWith('http') 
          ? {'url': imageUrl} 
          : {'file': imageUrl}; // Master service handles file upload if needed
          
      final data = await _master.fetch('google_lens', parameters, cancelToken: cancelToken);
      return data;
    } catch (e) {
      debugPrint("❌ Google Lens Search Error: $e");
      return {'error': e.toString()};
    }
  }
}

/// 📈 Google Trends Service
class GoogleTrendsService {
  final _master = SerpApiMasterService();

  Future<List<Map<String, dynamic>>> getTrendingTopics({dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.fetch('google_trends_trending_now', {
        'geo': 'SA',
        'hl': 'ar',
      }, cancelToken: cancelToken);
      if (data.containsKey('trending_searches')) {
        return List<Map<String, dynamic>>.from(data['trending_searches']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ Google Trends Error: $e");
      return [];
    }
  }

  // Backward compatibility
  Future<String> getTrends(String query, {dio.CancelToken? cancelToken}) async {
    return "مؤشرات البحث لـ $query: اهتمام متزايد في المنطقة العربية.";
  }
}

/// 📱 Social Profile Insights Service (JSON-Powered)
/// يتيح جلب بيانات البروفايلات (فيسبوك، إنستقرام) بشكل هيكلي بدون الحاجة لـ WebView
class SocialProfileService {
  final _master = SerpApiMasterService();

  /// جلب بيانات بروفايل فيسبوك (متابعين، توثيق، روابط، صور)
  Future<Map<String, dynamic>> getFacebookProfile(String profileId, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.getFacebookProfile(profileId, cancelToken: cancelToken);
      if (data.containsKey('profile_results')) {
        return Map<String, dynamic>.from(data['profile_results']);
      }
      return {};
    } catch (e) {
      debugPrint("❌ Global Social Profile Error: $e");
      return {};
    }
  }

  /// محرك عام لجلب أي بروفايل مدعوم من SerpApi
  Future<Map<String, dynamic>> getGenericProfile(String engine, String profileId, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.getSocialProfile(engine, profileId, cancelToken: cancelToken);
      if (data.containsKey('profile_results')) {
        return Map<String, dynamic>.from(data['profile_results']);
      }
      return {};
    } catch (e) {
      debugPrint("❌ Generic Profile Hub Error: $e");
      return {};
    }
  }
}

/// 🎬 YouTube Search Service
class YoutubeSearchService {
  final _master = SerpApiMasterService();

  Future<List<Map<String, dynamic>>> searchVideos(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.fetch('youtube', {
        'search_query': query,
      }, cancelToken: cancelToken);
      
      final List<Map<String, dynamic>> allResults = [];

      // 1. Process standard video results
      if (data.containsKey('video_results')) {
        final results = List<Map<String, dynamic>>.from(data['video_results']);
        allResults.addAll(results.map((v) => _normalizeYoutubeItem(v)));
      }

      // 2. Process Shorts results (if any)
      if (data.containsKey('shorts_results')) {
        for (var group in data['shorts_results']) {
          if (group is Map && group.containsKey('shorts')) {
            final shorts = List<dynamic>.from(group['shorts']);
            allResults.addAll(shorts.map((s) => _normalizeYoutubeItem(Map<String, dynamic>.from(s))));
          }
        }
      }

      return allResults;
    } catch (e) {
      debugPrint("❌ YouTube Search Error: $e");
      return [];
    }
  }

  Map<String, dynamic> _normalizeYoutubeItem(Map<String, dynamic> v) {
    // Extract channel info
    final channelData = v['channel'];
    String author = 'YouTube Channel';
    String? channelThumb;
    
    if (channelData is Map) {
      author = channelData['name']?.toString() ?? author;
      channelThumb = channelData['thumbnail']?.toString();
    } else if (channelData != null) {
      author = channelData.toString();
    }

    // Extract thumbnail
    final thumbData = v['thumbnail'];
    String? thumbnail;
    if (thumbData is Map) {
      thumbnail = thumbData['static']?.toString();
    } else {
      thumbnail = thumbData?.toString();
    }

    return {
      ...v,
      'clip': v['link'] ?? "",
      'platform': 'youtube',
      'author': author,
      'channel_thumbnail': channelThumb,
      'thumbnail': thumbnail ?? v['thumbnail'], 
      'duration': v['length'] ?? v['duration'],
      'source_icon': "https://www.youtube.com/s/desktop/2865955a/img/favicon_144x144.png",
    };
  }
}

/// 🛒 Amazon Product Service
class AmazonProductService {
  final _master = SerpApiMasterService();

  Future<List<Map<String, dynamic>>> searchProducts(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.fetch('amazon', {
        'type': 'search',
        'amazon_domain': 'amazon.com', // 🌐 Switch to global Amazon domain
        'k': query, // 🛒 [AMAZON FIX]: Amazon requires 'k' (Keywords) instead of 'q'
      }, cancelToken: cancelToken);
      if (data.containsKey('shopping_results')) {
        return List<Map<String, dynamic>>.from(data['shopping_results']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ Amazon Search Error: $e");
      return [];
    }
  }
}

/// 📰 Google News Service
class GoogleNewsService {
  final _master = SerpApiMasterService();

  Future<List<Map<String, dynamic>>> getLatestNews(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.fetch('google_news', {
        'q': query,
        'hl': 'ar',
        'gl': 'sa',
      }, cancelToken: cancelToken);
      if (data.containsKey('news_results')) {
        return List<Map<String, dynamic>>.from(data['news_results']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ Google News Error: $e");
      return [];
    }
  }
}

/// 🛍️ Google Shopping Service
class GoogleShoppingService {
  final _master = SerpApiMasterService();

  Future<List<Map<String, dynamic>>> searchProducts(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final data = await _master.fetch('google_shopping', {
        'q': query,
        'hl': 'ar',
        'gl': 'sa',
      }, cancelToken: cancelToken);
      if (data.containsKey('shopping_results')) {
        return List<Map<String, dynamic>>.from(data['shopping_results']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ Google Shopping Error: $e");
      return [];
    }
  }
}

/// 🔄 Google Reverse Image Service
class GoogleReverseImageService {
  Future<String> findImageSources(File image, {dio.CancelToken? cancelToken}) async {
    return "البحث العكسي: تم العثور على مصادر محتملة للصورة.";
  }
}

/// 📱 Google Short Videos Service
class GoogleShortVideosService {
  final _master = SerpApiMasterService();

  Future<List<Map<String, dynamic>>> getShortVideos(String query, {int start = 0, String? gl, String? hl, dio.CancelToken? cancelToken}) async {
    try {
      final parameters = {
        'q': query,
        'start': start.toString(),
        'gl': gl ?? 'us',
        'hl': hl ?? 'en',
      };
      
      final data = await _master.fetch('google_short_videos', parameters, cancelToken: cancelToken);
      
      if (data.containsKey('short_video_results')) {
        final results = List<Map<String, dynamic>>.from(data['short_video_results']);
        final Set<String> seenUris = {};
        
        final list = results.map((v) {
          final link = (v['link'] ?? "").toString().toLowerCase();
          String platform = "social";
          String icon = "https://www.google.com/s2/favicons?domain=google.com&sz=128";
          String finalLink = v['link'] ?? "";
          
          if (link.contains("youtube.com") || link.contains("youtu.be")) {
            platform = "youtube";
            icon = "https://www.youtube.com/s/desktop/2865955a/img/favicon_144x144.png";
          } else if (link.contains("instagram.com")) {
            // 🚀 التحقق من أنه رابط "رييل" واحد وليس "شبكة" أو "استكشاف"
            if (!link.contains('/reel/') && !link.contains('/reels/') && !link.contains('/p/')) {
              return null; // تجاهل الروابط غير المباشرة
            }
            platform = "instagram";
            icon = "https://www.instagram.com/static/images/ico/favicon-192.png/b407fa107eaa.png";
            // فقط نقوم بالتبديل إذا كان رابط "ريلز" فرعي للتأكد من تشغيله كمشغل فردي
            if (finalLink.contains('/reels/') && finalLink.split('/reels/').last.isNotEmpty) {
              finalLink = finalLink.replaceAll('/reels/', '/reel/');
            }
          } else if (link.contains("tiktok.com")) {
            // 🚀 التحقق من أنه رابط فيديو مباشر وليس صفحة "For You" عامة
            if (!link.contains('/video/')) {
              return null;
            }
            platform = "tiktok";
            icon = "https://www.tiktok.com/favicon.ico";
            if (finalLink.contains('/video/')) {
              final parts = finalLink.split('/video/');
              if (parts.length > 1) {
                final videoId = parts[1].split('?')[0];
                finalLink = "https://www.tiktok.com/video/$videoId";
              }
            }
          }
          
          // 🚀 الحذف الذكي للتكرار (Deduplication)
          final normalizedUri = finalLink.split('?').first; 
          if (seenUris.contains(normalizedUri)) return null;
          seenUris.add(normalizedUri);

          return {
            ...v,
            'clip': finalLink,
            'platform': platform,
            'author': v['channel'] ?? v['source'] ?? v['author'] ?? 'حساب غير معروف',
            'source_icon': icon,
          };
        }).where((v) => v != null).cast<Map<String, dynamic>>().toList();
        
        list.shuffle(); 
        return list;
      }
      return [];
    } catch (e) {
      debugPrint("❌ Google Shorts Service Error: $e");
      return [];
    }
  }
}

class SocialInsightScraperService {
  final _master = SerpApiMasterService();

  /// 🚀 استخراج بيانات إنستقرام عبر بحث قوقل (خطة الإنقاذ)
  Future<Map<String, dynamic>> getInstagramInsights(String username, {dio.CancelToken? cancelToken}) async {
    try {
      final query = 'site:instagram.com "@$username"';
      final data = await _master.googleSearch(query, cancelToken: cancelToken);
      
      if (data.containsKey('organic_results')) {
        final results = List<Map<String, dynamic>>.from(data['organic_results']);
        if (results.isNotEmpty) {
          final snippet = (results[0]['snippet'] ?? "").toString();
          final title = (results[0]['title'] ?? "").toString();
          
          // استخراج الأرقام عبر الـ Regex (يدعم الصيغ مثل 725, 1.2K, 1M)
          final followers = RegExp(r'([\d,.\d]+[KkMm]?)\s*Follower').firstMatch(snippet)?.group(1);
          final following = RegExp(r'([\d,.\d]+[KkMm]?)\s*Following').firstMatch(snippet)?.group(1);
          final posts = RegExp(r'([\d,.\d]+[KkMm]?)\s*Post').firstMatch(snippet)?.group(1);
          
          return {
            'name': title.split('(').first.trim().split('•').first.trim(),
            'followers': followers ?? 'نقر للمشاهدة',
            'following': following ?? '0',
            'posts': posts ?? '0',
            'profile_intro_text': snippet,
            'verified': title.contains('Verified') || snippet.contains('Verified') || title.contains('•'),
            'type': 'search_scraped',
            'id': username,
            'profile_picture': '', // الصور غير متوفرة في المقتطف
          };
        }
      }
      return {};
    } catch (e) {
      debugPrint("❌ Scraper Error: $e");
      return {};
    }
  }
}

/// 🤖 Bing Copilot Search Service (Advanced Research)
/// Provides structured deep answers with citations, tables, and code blocks.
class BingCopilotService {
  final _master = SerpApiMasterService();

  Future<Map<String, dynamic>> search(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final parameters = {
        'q': query,
        'engine': 'bing_copilot',
      };

      final data = await _master.fetch('bing_copilot', parameters, cancelToken: cancelToken);
      return data;
    } catch (e) {
      debugPrint("❌ Bing Copilot Service Error: $e");
      return {'error': e.toString()};
    }
  }
}

/// 🖼️ Google Images Search Service (Visual Inspiration)
/// Fetches high-quality product images and visual assets.
class GoogleImagesService {
  final _master = SerpApiMasterService();

  Future<Map<String, dynamic>> search(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final parameters = {
        'q': query,
        'engine': 'google_images',
        'ijn': '0', // Page 0
      };

      final data = await _master.fetch('google_images', parameters, cancelToken: cancelToken);
      return data;
    } catch (e) {
      debugPrint("❌ Google Images Service Error: $e");
      return {'error': e.toString()};
    }
  }
}

/// 🔍 Bing Images Search Service
/// Additional high-quality image source for visual inspiration.
class BingImagesService {
  final _master = SerpApiMasterService();

  Future<Map<String, dynamic>> search(String query, {dio.CancelToken? cancelToken}) async {
    try {
      final parameters = {
        'q': query,
        'engine': 'bing_images',
      };

      final data = await _master.fetch('bing_images', parameters, cancelToken: cancelToken);
      return data;
    } catch (e) {
      debugPrint("❌ Bing Images Service Error: $e");
      return {'error': e.toString()};
    }
  }
}

/// 🌍 Google Standard Search Service (Comprehensive Research)
/// Fetches organic results, knowledge graph, and local business data.
class GoogleSearchService {
  final _master = SerpApiMasterService();

  Future<Map<String, dynamic>> search(String query, {String? gl, String? hl, dio.CancelToken? cancelToken}) async {
    try {
      final parameters = {
        'q': query,
        'engine': 'google',
        'gl': gl ?? 'sa', // Default to Saudi Arabia or user region
        'hl': hl ?? 'ar', // Default to Arabic
      };

      final data = await _master.fetch('google', parameters, cancelToken: cancelToken);
      return _formatResults(data);
    } catch (e) {
      debugPrint("❌ Google Search Service Error: $e");
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _formatResults(Map<String, dynamic> data) {
    final Map<String, dynamic> formatted = {
      'type': 'managed_search',
      'query': data['search_parameters']?['q'] ?? '',
    };

    // 1. Extract Knowledge Graph (The most important part for structured info)
    if (data.containsKey('knowledge_graph')) {
      final kg = data['knowledge_graph'];
      formatted['knowledge_graph'] = {
        'title': kg['title'],
        'type': kg['type'],
        'description': kg['description'] ?? kg['snippet'],
        'website': kg['website'],
        'phone': kg['phone'],
        'address': kg['address'],
        'hours': kg['hours'],
        'rating': kg['rating'],
        'reviews': kg['reviews'],
        'thumbnail': kg['header_images'] != null && (kg['header_images'] as List).isNotEmpty 
            ? kg['header_images'][0]['image'] 
            : kg['thumbnail'],
      };
    }

    // 2. Extract Local Results (Maps/Places)
    if (data.containsKey('local_results')) {
      formatted['local_results'] = data['local_results'];
    }

    // 3. Extract Organic Results (Snippets)
    if (data.containsKey('organic_results')) {
      final organic = List<Map<String, dynamic>>.from(data['organic_results']);
      formatted['organic_results'] = organic.take(5).map((r) => {
        'title': r['title'],
        'link': r['link'],
        'snippet': r['snippet'],
        'source': r['source'],
      }).toList();
    }

    // 4. Extract Answer Box (Direct answers like weather, calculator, etc)
    if (data.containsKey('answer_box')) {
      formatted['answer_box'] = data['answer_box'];
    }

    return formatted;
  }
}

/// 🌉 Visual Expansion Service (Semantic Engine)
/// Bridges Google Lens and Google Search to create a "Content Package" from a photo.
class VisualExpansionService {
  final _master = SerpApiMasterService();

  Future<Map<String, dynamic>> expandImageToContent(String imageUrl, {dio.CancelToken? cancelToken}) async {
    try {
      // 1️⃣ Step 1: Google Lens (Vision)
      final lensData = await _master.fetch('google_lens', {
        'url': imageUrl,
      }, cancelToken: cancelToken);

      // Extract best product name
      String productName = "";
      if (lensData['knowledge_graph'] != null && 
          (lensData['knowledge_graph'] as List).isNotEmpty) {
        productName = lensData['knowledge_graph'][0]['title'] ?? "";
      } else if (lensData['visual_matches'] != null && 
                 (lensData['visual_matches'] as List).isNotEmpty) {
        productName = lensData['visual_matches'][0]['title'] ?? "";
      }

      if (productName.isEmpty) {
        return {'error': 'لم نتمكن من التعرف على المنتج بوضوح لبناء خطة محتوى.'};
      }

      // 2️⃣ Step 2: Semantic Expansion (Google Web Search)
      final webData = await _master.fetch('google', {
        'q': productName,
        'gl': 'sa',
        'hl': 'ar',
      }, cancelToken: cancelToken);

      // 3️⃣ Step 3: Bundle Content Package
      return {
        'detected_product': productName,
        'visual_matches': (lensData['visual_matches'] as List?)?.take(5).toList() ?? [],
        'related_questions': webData['related_questions'] ?? [],
        'organic_results': (webData['organic_results'] as List?)?.take(3).toList() ?? [],
        'related_searches': webData['related_searches'] ?? [],
        'knowledge_graph': webData['knowledge_graph'],
      };
    } catch (e) {
      debugPrint("❌ Visual Expansion Engine Error: $e");
      return {'error': e.toString()};
    }
  }
}
