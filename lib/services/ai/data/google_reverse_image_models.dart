class GoogleReverseImageResponse {
  final List<ReverseImageResult> imageResults;
  final ReverseImageKnowledgeGraph? knowledgeGraph;

  GoogleReverseImageResponse({
    required this.imageResults,
    this.knowledgeGraph,
  });

  factory GoogleReverseImageResponse.fromJson(Map<String, dynamic> json) {
    return GoogleReverseImageResponse(
      imageResults: (json['image_results'] as List? ?? [])
          .map((e) => ReverseImageResult.fromJson(e))
          .toList(),
      knowledgeGraph: json['knowledge_graph'] != null
          ? ReverseImageKnowledgeGraph.fromJson(json['knowledge_graph'])
          : null,
    );
  }
}

class ReverseImageResult {
  final int? position;
  final String? title;
  final String? link;
  final String? source;
  final String? thumbnail;

  ReverseImageResult({
    this.position,
    this.title,
    this.link,
    this.source,
    this.thumbnail,
  });

  factory ReverseImageResult.fromJson(Map<String, dynamic> json) {
    return ReverseImageResult(
      position: json['position'],
      title: json['title'],
      link: json['link'],
      source: json['source'],
      thumbnail: json['thumbnail'],
    );
  }
}

class ReverseImageKnowledgeGraph {
  final String? title;
  final String? type;
  final String? description;
  final String? image;
  final String? sourceName;
  final String? sourceLink;

  ReverseImageKnowledgeGraph({
    this.title,
    this.type,
    this.description,
    this.image,
    this.sourceName,
    this.sourceLink,
  });

  factory ReverseImageKnowledgeGraph.fromJson(Map<String, dynamic> json) {
    return ReverseImageKnowledgeGraph(
      title: json['title'],
      type: json['type'],
      description: json['description'],
      image: json['image'],
      sourceName: json['source']?['name'],
      sourceLink: json['source']?['link'],
    );
  }
}
