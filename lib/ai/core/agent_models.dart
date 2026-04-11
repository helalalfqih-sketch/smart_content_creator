import 'dart:io';

enum Intent {
  // Conversational
  casualChat,

  // Product
  productDetected,
  trendRequest,
  youtubeRequest,
  googleTrendsRequest,
  adRequest,

  // Technical
  codeRequest,
  largeTextAnalysis,
  urlAnalysis,

  // New Intents
  videoGeneration, // 📹
  imageGeneration, // 🎨
  analysis, // 📊
  searchTrends, // 📈
  instagramSearch, // 📸
  alibabaSource, // 📦
  visualSearch, // 🖼️🔍
  googleSearch, // 🌍
  visualExpansion, // 📸➡️🌐
  reconstruction3D, // 🏺 New: Multi-image 3D Product Reconstruction
  amazonRequest, // 🛒
  shoppingRequest, // 🛍️

  // Security
  suspicious,

  // Fallback
  unknown
}

enum MediaType { none, image, video, url }

enum ContentType { product, person, animal, food, landscape, document, unknown }

enum ReplyMode {
  discussion,
  modification,
  transform;

  bool get isContentRewrite => this == modification || this == transform;
}

class ReplyModeResult {
  final ReplyMode mode;
  final double confidence;

  const ReplyModeResult({
    required this.mode,
    required this.confidence,
  });
}

class MediaAnalysisResult {
  final MediaType mediaType;
  final ContentType contentType;
  final List<String> detectedObjects;

  const MediaAnalysisResult({
    required this.mediaType,
    required this.contentType,
    this.detectedObjects = const [],
  });
}

class ProductVisionResult {
  final bool isProduct;
  final String? productName;
  final double confidence;
  final Map<String, dynamic>? data;

  const ProductVisionResult({
    required this.isProduct,
    this.productName,
    this.confidence = 0.0,
    this.data,
  });

  String? get searchQuery => data?['search_query'];
  String? get brand => data?['brand'];
  String? get model => data?['model'];
}

class ProcessedInput {
  final Intent intent;
  final String? detectedProduct;
  final double confidence;
  final bool isSafe;
  final String? warningMessage;
  final MediaAnalysisResult? mediaResult;
  final ProductVisionResult? productResult;

  const ProcessedInput({
    required this.intent,
    required this.isSafe,
    this.detectedProduct,
    this.warningMessage,
    this.confidence = 1.0,
    this.mediaResult,
    this.productResult,
  });
}

class AIIntentResult {
  final String intent;
  final double confidence;
  final Map<String, dynamic> parameters;
  final List<String> suggestedActions;

  AIIntentResult({
    required this.intent,
    required this.confidence,
    required this.parameters,
    required this.suggestedActions,
  });

  factory AIIntentResult.fromJson(Map<String, dynamic> json) => AIIntentResult(
        intent: json['intent'] ?? 'TEXT',
        confidence: (json['confidence'] ?? 0.0).toDouble(),
        parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
        suggestedActions: List<String>.from(json['suggested_actions'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'confidence': confidence,
        'parameters': parameters,
        'suggested_actions': suggestedActions,
      };
}

enum AgentResultType {
  text,
  productGallery,
  supplierList,
  priceAnalysis,
  richResult,
  videoDiscovery, // 🎞️ For unified multi-platform video carousels
  expertResearch, // 🤖 For deep structured research (Bing Copilot)
  imageGallery, // 🖼️ For high-quality visual inspiration grid
  contentPlan, // 🚀 New: Specialized for marketing/content output
  error,
}

enum ExecutionMode {
  reactive,
  autonomous,
}

/// 🏛️ Typed Data for Product Gallery Rendering
class ProductGalleryData {
  final List<String> imageUrls;
  final String title;
  final String priceRange;
  final String? analysis;

  const ProductGalleryData({
    required this.imageUrls,
    required this.title,
    required this.priceRange,
    this.analysis,
  });

  Map<String, dynamic> toJson() => {
        'imageUrls': imageUrls,
        'title': title,
        'priceRange': priceRange,
        'analysis': analysis,
      };

  factory ProductGalleryData.fromJson(Map<String, dynamic> json) =>
      ProductGalleryData(
        imageUrls: List<String>.from(json['imageUrls'] ?? []),
        title: json['title'] ?? '',
        priceRange: json['priceRange'] ?? '',
        analysis: json['analysis'],
      );
}

/// 🎞️ Typed Data for Video Discovery Rendering (TikTok, Reels, Shorts)
class VideoDiscoveryData {
  final List<dynamic> videos; // List of TikTokVideo as Maps
  final String query;
  final String title;

  const VideoDiscoveryData({
    required this.videos,
    required this.query,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'videos': videos,
        'query': query,
        'title': title,
      };

  factory VideoDiscoveryData.fromJson(Map<String, dynamic> json) =>
      VideoDiscoveryData(
        videos: json['videos'] ?? [],
        query: json['query'] ?? '',
        title: json['title'] ?? '',
      );
}

/// 🤖 Typed Data for Expert Research Rendering (Bing Copilot)
class ExpertResearchData {
  final String? header;
  final Map<String, dynamic>? headerVideo;
  final List<dynamic> textBlocks;
  final List<dynamic> references;
  final String? imagesLink;
  final String? videosLink;

  const ExpertResearchData({
    this.header,
    this.headerVideo,
    required this.textBlocks,
    required this.references,
    this.imagesLink,
    this.videosLink,
  });

  Map<String, dynamic> toJson() => {
        'header': header,
        'header_video': headerVideo,
        'text_blocks': textBlocks,
        'references': references,
        'images_link': imagesLink,
        'videos_link': videosLink,
      };

  factory ExpertResearchData.fromJson(Map<String, dynamic> json) =>
      ExpertResearchData(
        header: json['header'],
        headerVideo: json['header_video'],
        textBlocks: json['text_blocks'] ?? [],
        references: json['references'] ?? [],
        imagesLink: json['images_link'],
        videosLink: json['videos_link'],
      );
}

/// 🖼️ Typed Data for Visual Inspiration Gallery
class ImageGalleryData {
  final List<ImageItem> images;
  final String query;
  final String title;

  const ImageGalleryData({
    required this.images,
    required this.query,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'images': images.map((i) => i.toJson()).toList(),
        'query': query,
        'title': title,
      };

  factory ImageGalleryData.fromJson(Map<String, dynamic> json) =>
      ImageGalleryData(
        images: (json['images'] as List? ?? [])
            .map((i) => ImageItem.fromJson(Map<String, dynamic>.from(i)))
            .toList(),
        query: json['query'] ?? '',
        title: json['title'] ?? '',
      );
}

class ImageItem {
  final String title;
  final String link;
  final String thumbnail;
  final String source;
  final String? originalUrl; // 🔗 New field for direct image URL
  final Map<String, dynamic>? metadata;

  const ImageItem({
    required this.title,
    required this.link,
    required this.thumbnail,
    required this.source,
    this.originalUrl,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'thumbnail': thumbnail,
        'source': source,
        'original_url': originalUrl,
        'metadata': metadata,
      };

  factory ImageItem.fromJson(Map<String, dynamic> json) => ImageItem(
        title: json['title'] ?? '',
        link: json['link'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        source: json['source'] ?? '',
        originalUrl: json['original_url'] ?? json['original'],
        metadata: json['metadata'],
      );
}

/// 🚀 Typed Data for Structured Content & Marketing Plans
class ContentPlanData {
  final String title;
  final String? audience;
  final List<String> hooks;
  final String adCopy;
  final String? videoScript;
  final String? visualPrompt;
  final String? seoTags;

  const ContentPlanData({
    required this.title,
    this.audience,
    required this.hooks,
    required this.adCopy,
    this.videoScript,
    this.visualPrompt,
    this.seoTags,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'audience': audience,
        'hooks': hooks,
        'adCopy': adCopy,
        'videoScript': videoScript,
        'visualPrompt': visualPrompt,
        'seoTags': seoTags,
      };

  factory ContentPlanData.fromJson(Map<String, dynamic> json) => ContentPlanData(
        title: json['title'] ?? '',
        audience: json['audience'],
        hooks: List<String>.from(json['hooks'] ?? []),
        adCopy: json['adCopy'] ?? '',
        videoScript: json['videoScript'],
        visualPrompt: json['visualPrompt'],
        seoTags: json['seoTags'],
      );
}

class AgentRequest {
  final String userMessage;
  final String userId;
  final String? projectId;
  final String activePlatform;
  final double creditBalance;
  final ExecutionMode mode;
  final Map<String, dynamic> extraContext;

  const AgentRequest({
    required this.userMessage,
    required this.userId,
    this.projectId,
    this.activePlatform = 'alibaba',
    this.creditBalance = 0.0,
    this.mode = ExecutionMode.reactive,
    this.extraContext = const {},
  });
}

class SuggestedAction {
  final String label;
  final String toolId;
  final Map<String, dynamic> parameters;

  const SuggestedAction({
    required this.label,
    required this.toolId,
    this.parameters = const {},
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'toolId': toolId,
        'parameters': parameters,
      };

  factory SuggestedAction.fromJson(Map<String, dynamic> json) =>
      SuggestedAction(
        label: json['label'] ?? '',
        toolId: json['toolId'] ?? '',
        parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      );
}

class IncomingMessage {
  final String? text;
  final File? image;
  final List<File>? images; // 📸 Multiple images support
  final File? video;
  final File? audio;
  final Uri? url;

  const IncomingMessage({
    this.text,
    this.image,
    this.images,
    this.video,
    this.audio,
    this.url,
    this.replyToId,
    this.replyToContent,
    this.replyToRole,
    this.replyMode = ReplyMode.discussion,
    this.styleSummary,
  });

  bool get hasMedia => image != null || (images != null && images!.isNotEmpty) || video != null || audio != null;
  bool get hasText => text?.isNotEmpty ?? false;
  File? get file => image ?? (images != null && images!.isNotEmpty ? images!.first : null) ?? video ?? audio;

  final String? replyToId;
  final String? replyToContent;
  final String? replyToRole;
  final ReplyMode replyMode;
  final String? styleSummary;
}

class AiTask {
  final Intent intent;
  final String? productName;
  final File? mediaFile;
  final List<File>? images; // 📸 Multiple images support
  final String? userText;
  final Map<String, dynamic> metadata;
  final bool requiresVision;
  final bool isVideo;
  final String? aiMode;
  final String? suggestedTool;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToRole;
  final ReplyMode replyMode;
  final String? styleSummary;

  const AiTask({
    required this.intent,
    this.productName,
    this.mediaFile,
    this.images,
    this.userText,
    this.metadata = const {},
    this.requiresVision = false,
    this.isVideo = false,
    this.aiMode,
    this.suggestedTool,
    this.replyToId,
    this.replyToContent,
    this.replyToRole,
    this.replyMode = ReplyMode.discussion,
    this.styleSummary,
  });
}

class AiPlan {
  final String goal;
  final List<AiPlanStep> steps;
  final double confidence;
  final String? reasoning;

  const AiPlan({
    required this.goal,
    required this.steps,
    this.confidence = 0.0,
    this.reasoning,
  });
}

class AiPlanStep {
  final int order;
  final String tool;
  final String description;
  final Map<String, dynamic> parameters;

  const AiPlanStep({
    required this.order,
    required this.tool,
    required this.description,
    this.parameters = const {},
  });
}

/// 🧠 AgentResult - The standardized output of any agent.
class AgentResult<T> {
  final AgentResultType type;
  final T data;
  final List<SuggestedAction>? actions;
  final String? reasoning;
  final int executionTimestamp;

  const AgentResult({
    required this.type,
    required this.data,
    required this.executionTimestamp,
    this.actions,
    this.reasoning,
  });

  static AgentResult<String> error(String message) {
    return AgentResult<String>(
      type: AgentResultType.error,
      data: message,
      executionTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'data': (data is ProductGalleryData)
            ? (data as ProductGalleryData).toJson()
            : (data is VideoDiscoveryData)
                ? (data as VideoDiscoveryData).toJson()
                : (data is ExpertResearchData)
                    ? (data as ExpertResearchData).toJson()
                    : (data is ImageGalleryData)
                        ? (data as ImageGalleryData).toJson()
                        : (data is ContentPlanData)
                            ? (data as ContentPlanData).toJson()
                            : data,
        'actions': actions?.map((a) => a.toJson()).toList(),
        'reasoning': reasoning,
        'executionTimestamp': executionTimestamp,
      };

  factory AgentResult.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = AgentResultType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => AgentResultType.text,
    );

    dynamic data = json['data'];
    if (type == AgentResultType.productGallery && data is Map) {
      data = ProductGalleryData.fromJson(Map<String, dynamic>.from(data));
    } else if (type == AgentResultType.videoDiscovery && data is Map) {
      data = VideoDiscoveryData.fromJson(Map<String, dynamic>.from(data));
    } else if (type == AgentResultType.expertResearch && data is Map) {
      data = ExpertResearchData.fromJson(Map<String, dynamic>.from(data));
    } else if (type == AgentResultType.imageGallery && data is Map) {
      data = ImageGalleryData.fromJson(Map<String, dynamic>.from(data));
    } else if (type == AgentResultType.contentPlan && data is Map) {
      data = ContentPlanData.fromJson(Map<String, dynamic>.from(data));
    }

    return AgentResult(
      type: type,
      data: data as T,
      actions: (json['actions'] as List?)
          ?.map((a) => SuggestedAction.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      reasoning: json['reasoning'],
      executionTimestamp: json['executionTimestamp'] ?? 0,
    );
  }
}
