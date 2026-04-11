class BingImageSearchResponse {
  final List<BingImageResult> images;
  final List<BingImageSuggestion>? suggestions;

  BingImageSearchResponse({required this.images, this.suggestions});

  factory BingImageSearchResponse.fromJson(Map<String, dynamic> json) {
    var imagesList = (json['images_results'] as List?) ?? [];
    var suggestionsList = (json['suggested_searches'] as List?) ?? [];

    return BingImageSearchResponse(
      images: imagesList.map((e) => BingImageResult.fromJson(e)).toList(),
      suggestions: suggestionsList.map((e) => BingImageSuggestion.fromJson(e)).toList(),
    );
  }
}

class BingImageResult {
  final String title;
  final String link;
  final String thumbnail;
  final String original;
  final String source;
  final String domain;
  final String? size;

  BingImageResult({
    required this.title,
    required this.link,
    required this.thumbnail,
    required this.original,
    required this.source,
    required this.domain,
    this.size,
  });

  factory BingImageResult.fromJson(Map<String, dynamic> json) {
    return BingImageResult(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      original: json['original'] ?? '',
      source: json['source'] ?? '',
      domain: json['domain'] ?? '',
      size: json['size'],
    );
  }
}

class BingImageSuggestion {
  final String name;
  final String thumbnail;
  final String link;

  BingImageSuggestion({
    required this.name,
    required this.thumbnail,
    required this.link,
  });

  factory BingImageSuggestion.fromJson(Map<String, dynamic> json) {
    return BingImageSuggestion(
      name: json['name'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      link: json['link'] ?? '',
    );
  }
}
