// No foundation needed

class GoogleAiModeResult {
  final String? reconstructedMarkdown;
  final String? subsequentRequestToken;
  final List<AiTextBlock> textBlocks;
  final List<AiReference> references;
  final List<String> inlineImages;
  final List<AiShoppingResult> shoppingResults;
  final List<AiLocalResult> localResults;
  final List<AiInlineVideo> inlineVideos;
  final List<AiRelatedQuestion> relatedQuestions;

  GoogleAiModeResult({
    this.reconstructedMarkdown,
    this.subsequentRequestToken,
    this.textBlocks = const [],
    this.references = const [],
    this.inlineImages = const [],
    this.shoppingResults = const [],
    this.localResults = const [],
    this.inlineVideos = const [],
    this.relatedQuestions = const [],
  });

  factory GoogleAiModeResult.fromJson(Map<String, dynamic> json) {
    return GoogleAiModeResult(
      reconstructedMarkdown: json['reconstructed_markdown'],
      subsequentRequestToken: json['subsequent_request_token'],
      textBlocks: (json['text_blocks'] as List?)
              ?.map((x) => AiTextBlock.fromJson(x))
              .toList() ??
          [],
      references: (json['references'] as List?)
              ?.map((x) => AiReference.fromJson(x))
              .toList() ??
          [],
      inlineImages: (json['inline_images'] as List?)?.cast<String>() ?? [],
      shoppingResults: (json['shopping_results'] as List?)
              ?.map((x) => AiShoppingResult.fromJson(x))
              .toList() ??
          [],
      localResults: (json['local_results'] as List?)
              ?.map((x) => AiLocalResult.fromJson(x))
              .toList() ??
          [],
      inlineVideos: (json['inline_videos'] as List?)
              ?.map((x) => AiInlineVideo.fromJson(x))
              .toList() ??
          [],
      relatedQuestions: (json['related_questions'] as List?)
              ?.map((x) => AiRelatedQuestion.fromJson(x))
              .toList() ??
          [],
    );
  }
}

class AiTextBlock {
  final String type; // heading, paragraph, list, table, chart_block, etc.
  final String? snippet;
  final List<AiListItem> list;
  final List<List<String>>? table;
  final List<Map<String, dynamic>>? formattedTable;
  final List<int> referenceIndexes;
  final String? language; // for code_block
  final String? code; // for code_block
  final String? title; // for chart_block
  final String? chartType; // for chart_block

  AiTextBlock({
    required this.type,
    this.snippet,
    this.list = const [],
    this.table,
    this.formattedTable,
    this.referenceIndexes = const [],
    this.language,
    this.code,
    this.title,
    this.chartType,
  });

  factory AiTextBlock.fromJson(Map<String, dynamic> json) {
    return AiBlocksParser.parseBlock(json);
  }
}

class AiListItem {
  final String? title;
  final String? snippet;
  final List<int> referenceIndexes;
  final AiShoppingResult? shoppingResult;
  final AiLocalResult? localResult;
  final List<AiListItem> subList;
  final List<AiTextBlock> textBlocks;

  AiListItem({
    this.title,
    this.snippet,
    this.referenceIndexes = const [],
    this.shoppingResult,
    this.localResult,
    this.subList = const [],
    this.textBlocks = const [],
  });

  factory AiListItem.fromJson(Map<String, dynamic> json) {
    return AiListItem(
      title: json['title'],
      snippet: json['snippet'],
      referenceIndexes: (json['reference_indexes'] as List?)?.cast<int>() ?? [],
      shoppingResult: json['shopping_result'] != null
          ? AiShoppingResult.fromJson(json['shopping_result'])
          : null,
      localResult: json['local_result'] != null
          ? AiLocalResult.fromJson(json['local_result'])
          : null,
      subList: (json['list'] as List?)
              ?.map((x) => AiListItem.fromJson(x))
              .toList() ??
          [],
      textBlocks: (json['text_blocks'] as List?)
              ?.map((x) => AiTextBlock.fromJson(x))
              .toList() ??
          [],
    );
  }
}

class AiReference {
  final String title;
  final String link;
  final String? snippet;
  final String? source;
  final String? thumbnail;
  final String? sourceIcon;
  final int index;

  AiReference({
    required this.title,
    required this.link,
    this.snippet,
    this.source,
    this.thumbnail,
    this.sourceIcon,
    required this.index,
  });

  factory AiReference.fromJson(Map<String, dynamic> json) {
    return AiReference(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      snippet: json['snippet'],
      source: json['source'],
      thumbnail: json['thumbnail'],
      sourceIcon: json['source_icon'],
      index: json['index'] ?? 0,
    );
  }
}

class AiShoppingResult {
  final String title;
  final String? productLink;
  final String? thumbnail;
  final String? price;
  final double? extractedPrice;
  final String? oldPrice;
  final double? rating;
  final int? reviews;
  final int? index;

  AiShoppingResult({
    required this.title,
    this.productLink,
    this.thumbnail,
    this.price,
    this.extractedPrice,
    this.oldPrice,
    this.rating,
    this.reviews,
    this.index,
  });

  factory AiShoppingResult.fromJson(Map<String, dynamic> json) {
    return AiShoppingResult(
      title: json['title'] ?? '',
      productLink: json['product_link'],
      thumbnail: json['thumbnail'],
      price: json['price'],
      extractedPrice: (json['extracted_price'] as num?)?.toDouble(),
      oldPrice: json['old_price'],
      rating: (json['rating'] as num?)?.toDouble(),
      reviews: json['reviews'] as int?,
      index: json['index'] as int?,
    );
  }
}

class AiLocalResult {
  final String title;
  final String? link;
  final String? thumbnail;
  final double? rating;
  final int? reviews;
  final String? price;
  final String? openState;
  final String? type;
  final String? address;
  final int? index;

  AiLocalResult({
    required this.title,
    this.link,
    this.thumbnail,
    this.rating,
    this.reviews,
    this.price,
    this.openState,
    this.type,
    this.address,
    this.index,
  });

  factory AiLocalResult.fromJson(Map<String, dynamic> json) {
    return AiLocalResult(
      title: json['title'] ?? '',
      link: json['link'],
      thumbnail: json['thumbnail'],
      rating: (json['rating'] as num?)?.toDouble(),
      reviews: json['reviews'] as int?,
      price: json['price'],
      openState: json['open_state'],
      type: json['type'],
      address: json['address'],
      index: json['index'] as int?,
    );
  }
}

class AiInlineVideo {
  final String title;
  final String link;
  final String? thumbnail;
  final String? duration;
  final String? channel;
  final String? platform;

  AiInlineVideo({
    required this.title,
    required this.link,
    this.thumbnail,
    this.duration,
    this.channel,
    this.platform,
  });

  factory AiInlineVideo.fromJson(Map<String, dynamic> json) {
    return AiInlineVideo(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      thumbnail: json['thumbnail'],
      duration: json['duration'],
      channel: json['channel'],
      platform: json['platform'],
    );
  }
}

class AiRelatedQuestion {
  final String question;
  final String? serpapiLink;

  AiRelatedQuestion({required this.question, this.serpapiLink});

  factory AiRelatedQuestion.fromJson(Map<String, dynamic> json) {
    return AiRelatedQuestion(
      question: json['question'] ?? '',
      serpapiLink: json['serpapi_link'],
    );
  }
}

/// Helper class to handle complex polymorphic parsing of text blocks
class AiBlocksParser {
  static AiTextBlock parseBlock(Map<String, dynamic> json) {
    return AiTextBlock(
      type: json['type'] ?? 'unknown',
      snippet: json['snippet'],
      list: (json['list'] as List?)
              ?.map((x) => AiListItem.fromJson(x))
              .toList() ??
          [],
      table: (json['table'] as List?)
          ?.map((row) => (row as List).map((cell) => cell.toString()).toList())
          .toList(),
      formattedTable: (json['formatted'] is List)
          ? (json['formatted'] as List).cast<Map<String, dynamic>>()
          : null,
      referenceIndexes: (json['reference_indexes'] as List?)?.cast<int>() ?? [],
      language: json['language'],
      code: json['code'],
      title: json['title'],
      chartType: json['chart_type'],
    );
  }
}
