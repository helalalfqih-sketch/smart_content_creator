class GoogleShortVideosResponse {
  final List<ShortVideoResult> videoResults;

  GoogleShortVideosResponse({required this.videoResults});

  factory GoogleShortVideosResponse.fromJson(Map<String, dynamic> json) {
    var list = json['short_video_results'] as List? ?? [];
    List<ShortVideoResult> results =
        list.map((i) => ShortVideoResult.fromJson(i)).toList();
    return GoogleShortVideosResponse(videoResults: results);
  }
}

class ShortVideoResult {
  final String title;
  final String link;
  final String thumbnail;
  final String? clip;
  final String? source;
  final String? sourceIcon;
  final String? channel;
  final String? duration;

  ShortVideoResult({
    required this.title,
    required this.link,
    required this.thumbnail,
    this.clip,
    this.source,
    this.sourceIcon,
    this.channel,
    this.duration,
  });

  factory ShortVideoResult.fromJson(Map<String, dynamic> json) {
    return ShortVideoResult(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      clip: json['clip'],
      source: json['source'],
      sourceIcon: json['source_icon'],
      channel: json['channel'],
      duration: json['duration'],
    );
  }
}
