class GoogleShoppingResult {
  final String title;
  final String link;
  final String? price;
  final double? extractedPrice;
  final String? source;
  final String? sourceIcon;
  final String? thumbnail;
  final double? rating;
  final int? reviews;
  final String? snippet;
  final String? delivery;
  final String? tag;

  GoogleShoppingResult({
    required this.title,
    required this.link,
    this.price,
    this.extractedPrice,
    this.source,
    this.sourceIcon,
    this.thumbnail,
    this.rating,
    this.reviews,
    this.snippet,
    this.delivery,
    this.tag,
  });

  factory GoogleShoppingResult.fromJson(Map<String, dynamic> json) {
    return GoogleShoppingResult(
      title: json['title'] ?? '',
      link: json['product_link'] ?? '',
      price: json['price'],
      extractedPrice: (json['extracted_price'] as num?)?.toDouble(),
      source: json['source'],
      sourceIcon: json['source_icon'],
      thumbnail: json['thumbnail'],
      rating: (json['rating'] as num?)?.toDouble(),
      reviews: json['reviews'] as int?,
      snippet: json['snippet'],
      delivery: json['delivery'],
      tag: json['tag'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'product_link': link,
      'price': price,
      'extracted_price': extractedPrice,
      'source': source,
      'source_icon': sourceIcon,
      'thumbnail': thumbnail,
      'rating': rating,
      'reviews': reviews,
      'snippet': snippet,
      'delivery': delivery,
      'tag': tag,
    };
  }
}
