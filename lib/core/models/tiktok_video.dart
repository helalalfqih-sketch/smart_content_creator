class TikTokVideo {
  final String id;
  final String videoUrl;
  final String? videoUrlNoWatermark;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String? dynamicCoverUrl;
  final int views;
  final int likes;
  final int shares;
  final int trendingPosition;
  final String country;
  final String? duration; // ⏱️ Added duration field
  final DateTime createdAt;
  final Map<String, dynamic>? rawJson;

  TikTokVideo({
    required this.id,
    required this.videoUrl,
    this.videoUrlNoWatermark,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.dynamicCoverUrl,
    this.views = 0,
    this.likes = 0,
    this.shares = 0,
    this.trendingPosition = 0,
    this.country = '',
    required this.createdAt,
    this.duration,
    this.rawJson,
  });

  factory TikTokVideo.fromJson(Map<String, dynamic> json) => TikTokVideo.fromMap(json);

  /// 🛠️ تحويل الخريطة (Map) إلى كائن (Object) - لقاعدة البيانات
  factory TikTokVideo.fromMap(Map<String, dynamic> map) {
    // Helper for safe strings
    String str(dynamic value) => value?.toString() ?? '';

    // Safely extract author
    String authorName = '';
    final authorField = map['author'];
    if (authorField is Map) {
      authorName = str(authorField['nickname']).isEmpty
          ? str(authorField['uniqueId'])
          : str(authorField['nickname']);
    } else {
      authorName = str(authorField);
    }

    if (authorName.isEmpty) {
      authorName = str(map['channel'] ??
          map['username'] ??
          map['nickname'] ??
          map['author_name'] ??
          map['author'] ??
          map['source'] ??
          'Unknown');
    }

    // Helper for safe ints
    int numVal(dynamic val) => int.tryParse(val?.toString() ?? '0') ?? 0;

    // Handle nested video object if it exists
    final videoObj = map['video'] is Map ? map['video'] as Map : null;

    final videoId = str(map['video_id'] ??
        map['id'] ??
        videoObj?['id'] ??
        map['position'] ??
        '');

    // Dynamic Cover (GIF/Animated) extraction
    final dynamicCover = str(map['dynamic_cover'] ??
        map['dynamicCover'] ??
        videoObj?['dynamicCover'] ??
        videoObj?['dynamic_cover'] ??
        '');

    // Support for SerpApi fields: 'link', 'clip', 'thumbnail'
    final videoUrl = str(map['play'] ??
        map['videoUrl'] ??
        map['link'] ??
        map['clip'] ??
        videoObj?['playAddr'] ??
        map['play_url'] ??
        map['url'] ??
        '');

    final coverUrl = str((map['cover'] != null && str(map['cover']).isNotEmpty)
        ? map['cover']
        : (map['thumbnail'] != null && str(map['thumbnail']).isNotEmpty)
            ? map['thumbnail']
            : (map['thumbnailUrl'] != null && str(map['thumbnailUrl']).isNotEmpty)
                ? map['thumbnailUrl']
                : (videoObj != null && videoObj['originCover'] != null && str(videoObj['originCover']).isNotEmpty)
                    ? videoObj['originCover']
                    : (videoObj != null && videoObj['cover'] != null && str(videoObj['cover']).isNotEmpty)
                        ? videoObj['cover']
                        : (videoObj != null && videoObj['dynamicCover'] != null && str(videoObj['dynamicCover']).isNotEmpty)
                            ? videoObj['dynamicCover']
                            : (map['imageUrl'] ?? ''));

    return TikTokVideo(
      id: videoId,
      title: str(map['title'] ?? map['caption'] ?? map['description'] ?? map['text'] ?? ''),
      thumbnailUrl: coverUrl,
      dynamicCoverUrl: dynamicCover.isNotEmpty ? dynamicCover : null,
      videoUrl: videoUrl,
      videoUrlNoWatermark: str(map['videoUrlNoWatermark'] ?? map['video_url_no_watermark'] ?? videoUrl),
      author: authorName,
      views: numVal(map['play_count'] ?? map['views'] ?? videoObj?['playCount']),
      likes: numVal(map['digg_count'] ?? map['likes'] ?? videoObj?['diggCount']),
      shares: numVal(map['share_count'] ?? map['shares'] ?? videoObj?['shareCount']),
      trendingPosition: numVal(map['trending_position'] ?? map['position']),
      country: str(map['country']),
      duration: str(map['duration'] ?? videoObj?['duration'] ?? map['length']),
      createdAt: map['create_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(numVal(map['create_time']) * 1000)
          : (map['createdAt'] != null && map['createdAt'] is String
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : DateTime.now().subtract(const Duration(days: 1))),
      rawJson: map,
    );
  }

  // Helper to maintain compatibility with existing UI which expects Map<String, dynamic>
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': author,
      'caption': title,
      'videoUrl': videoUrl,
      'likes': formatViews(likes),
      'shares': formatViews(shares),
      'views': formatViews(views),
      'comments': '0',
      'hashtags': _extractHashtags(title),
      'category': 'General',
      'categoryEnum': null,
      'savedPath': null,
      'rawJson': rawJson,
      'created_at': createdAt.toIso8601String(),
    };
  }

  List<String> _extractHashtags(String text) {
    return RegExp(r'\#\w+').allMatches(text).map((m) => m.group(0)!).toList();
  }

  static String formatViews(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  double get engagementRate => views > 0 ? likes / views : 0.0;
}
