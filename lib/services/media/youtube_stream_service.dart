import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:get/get.dart';

class YoutubeStreamService extends GetxService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, String> _cache = {};

  @override
  void onClose() {
    _yt.close();
    super.onClose();
  }

  /// Extracts the direct MP4 stream URL from a YouTube URL or Video ID.
  Future<String?> getDirectStreamUrl(String url) async {
    if (url.isEmpty) return null;
    
    // Check cache first
    if (_cache.containsKey(url)) {
      return _cache[url]!;
    }

    try {
      final videoId = _extractVideoId(url);
      if (videoId == null) {
        debugPrint("⚠️ [YoutubeStreamService] Invalid YouTube URL: $url");
        return null;
      }

      debugPrint("🎥 [YoutubeStreamService] Fetching ID: $videoId");

      // Check if video is accessible
      final videoInfo = await _yt.videos.get(videoId).timeout(const Duration(seconds: 5));
      debugPrint("📖 [YoutubeStreamService] Video Title: ${videoInfo.title}");

      // 2. Fetch manifest with timeout
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 10));
      
      // 3. Try Muxed first (Video + Audio in one)
      var streamInfo = _getHighestQualityStream(manifest.muxed);
      
      // 4. Fallback: If no muxed, try only video
      if (streamInfo == null && manifest.videoOnly.isNotEmpty) {
        debugPrint("⚠️ [YoutubeStreamService] No Muxed stream, falling back to VideoOnly");
        streamInfo = _getHighestQualityStream(manifest.videoOnly);
      }
      
      if (streamInfo == null) {
        debugPrint("❌ [YoutubeStreamService] No playable streams found for $videoId");
        return null;
      }
      
      final streamUrl = streamInfo.url.toString();
      debugPrint("✅ [YoutubeStreamService] Stream Found: ${streamInfo.videoQuality} | Format: ${streamInfo.container.name}");
      
      _cache[url] = streamUrl;
      return streamUrl;
    } catch (e) {
      debugPrint("❌ [YoutubeStreamService] Error ($url): $e");
    }
    return null;
  }

  /// Helper to get highest quality stream from a list
  VideoStreamInfo? _getHighestQualityStream(Iterable<VideoStreamInfo> streams) {
    if (streams.isEmpty) return null;
    final list = streams.toList();
    list.sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));
    return list.first;
  }

  String? _extractVideoId(String url) {
    if (url.length == 11) return url; // Already an ID
    
    // Handle shorts, watch, and direct links
    RegExp regExp = RegExp(
      r'(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/|youtube\.com/shorts/)([^"&?/\s]{11})',
      caseSensitive: false,
    );
    
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }
}
