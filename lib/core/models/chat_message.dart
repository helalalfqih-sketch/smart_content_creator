import 'dart:io';
import 'dart:convert';
import 'package:smart_content_creator/widgets/media_action_bar.dart';
import 'package:smart_content_creator/ai/core/agent_models.dart';
import 'chat_attachment.dart';

/// 🎬 استوديو صنع المحتوى (AI Creator Studio) - أنواع الرسائل
enum CreatorMessageType {
  text,
  image,
  video,
  audio,
  document,
  file,
  actionMenu,
  scenario,
  generatedImage, // AI-generated images
  generatedVideo, // AI-generated videos
  captionPreview, // 📑 Word-by-word captions preview
}

/// 🚥 حالات رسائل الدردشة (للبث القوي) (Chat Message States)
enum MessageState {
  pending, // placeholder/queued
  streaming, // receiving chunks
  completed, // DONE forever
  error,
}

class ChatMessage {
  final String id; // Unique ID for state mapping
  final String role; // 'user' or 'assistant'
  final String content; // 📝 النص (اختياري، يمكن أن تكون الرسالة وسائط فقط)
  final bool isError;
  final List<ChatAttachment> attachments; // 📎 المرفقات الموحدة (الصور، الفيديو، الصوت، المستندات)
  final String type; // 'text', 'image', 'video', 'multimodal', 'action_menu', 'scenario', 'generated_image', 'generated_video', 'multi_image'
  final String? videoAuthor; // 👤 Creator Name
  final List<Map<String, dynamic>>? actions; // Smart buttons
  final List<MediaAction>? mediaActions; // 🎬 Creator Studio actions
  final bool isGenerating; // 🎬 Legacy field (keep for safety if used elsewhere)
  final MessageState state; // 🚥 The Source of Truth
  final List<String>? words; // 📑 List of words for caption preview
  final bool isNew; // 🆕 Flag to indicate if message should stream character-by-character
  final String? replyToId; // 🔗 ID of the message being replied to
  final String? replyToContent; // 📝 Snippet of the replied message content
  final String? replyToRole; // 👤 Role of message being replied to ('user'/'assistant')
  final ReplyMode replyMode; // 🧬 Operation Mode (discussion/modification/transform)
  final String? styleSummary; // 🎨 Brief style hint for LLM
  final List<Map<String, dynamic>>? recommendations; // 🧠 Related Topics
  final AgentResult? agentResult; // 🤖 Typed AI Agent results
  final Map<String, dynamic>? errorDetails; // 🔴 UI payload for glassmorphic error cards
  final String? productContext; // 🧠 The product name/brand this message refers to
  final String? provider; // 🤖 اسم محرك الذكاء الاصطناعي المستخدم

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.attachments = const [],
    this.isError = false,
    this.type = 'text',
    this.videoAuthor,
    this.actions,
    this.mediaActions,
    this.isGenerating = false,
    this.state = MessageState.completed,
    this.words,
    this.isNew = false,
    this.replyToId,
    this.replyToContent,
    this.replyToRole,
    this.replyMode = ReplyMode.discussion,
    this.styleSummary,
    this.recommendations,
    this.agentResult,
    this.errorDetails,
    this.productContext,
    this.provider,
    // Legacy support in constructor
    File? image,
    List<File>? images,
    String? mediaPath,
    List<String>? mediaPaths,
    String? videoUrl,
    String? videoThumbnail,
    String? responseImageUrl,
    String? audioPath,
  }) : _legacyImage = image,
       _legacyImages = images,
       _legacyMediaPath = mediaPath,
       _legacyMediaPaths = mediaPaths,
       _legacyVideoUrl = videoUrl,
       _legacyVideoThumbnail = videoThumbnail,
       _legacyResponseImageUrl = responseImageUrl,
       _legacyAudioPath = audioPath;

  // Stored legacy inputs if provided directly to constructor
  final File? _legacyImage;
  final List<File>? _legacyImages;
  final String? _legacyMediaPath;
  final List<String>? _legacyMediaPaths;
  final String? _legacyVideoUrl;
  final String? _legacyVideoThumbnail;
  final String? _legacyResponseImageUrl;
  final String? _legacyAudioPath;

  // --- Backwards Compatibility Getters ---
  File? get image {
    if (_legacyImage != null) return _legacyImage;
    final imgAtt = attachments.where((a) => a.isImage).firstOrNull;
    return imgAtt?.asLocalFile;
  }

  List<File>? get images {
    if (_legacyImages != null && _legacyImages.isNotEmpty) return _legacyImages;
    final imgList = attachments.where((a) => a.isImage && a.asLocalFile != null).map((a) => a.asLocalFile!).toList();
    return imgList.isNotEmpty ? imgList : null;
  }

  String? get mediaPath {
    if (_legacyMediaPath != null) return _legacyMediaPath;
    final first = attachments.firstOrNull;
    return first?.localPath ?? first?.remoteUrl;
  }

  List<String>? get mediaPaths {
    if (_legacyMediaPaths != null && _legacyMediaPaths.isNotEmpty) return _legacyMediaPaths;
    final paths = attachments.map((a) => a.localPath ?? a.remoteUrl).where((p) => p != null).cast<String>().toList();
    return paths.isNotEmpty ? paths : null;
  }

  String? get videoUrl {
    if (_legacyVideoUrl != null && _legacyVideoUrl.isNotEmpty) return _legacyVideoUrl;
    return attachments.where((a) => a.isVideo).firstOrNull?.remoteUrl;
  }

  String? get videoThumbnail {
    if (_legacyVideoThumbnail != null) return _legacyVideoThumbnail;
    return attachments.where((a) => a.isVideo).firstOrNull?.thumbnailUrl;
  }

  String? get responseImageUrl {
    if (_legacyResponseImageUrl != null) return _legacyResponseImageUrl;
    return attachments.where((a) => a.isImage).firstOrNull?.remoteUrl;
  }

  String? get audioPath {
    if (_legacyAudioPath != null) return _legacyAudioPath;
    final audioAtt = attachments.where((a) => a.isAudio).firstOrNull;
    return audioAtt?.localPath ?? audioAtt?.remoteUrl;
  }

  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasImages => attachments.any((a) => a.isImage);
  bool get hasVideos => attachments.any((a) => a.isVideo);
  bool get hasAudio => attachments.any((a) => a.isAudio);
  bool get hasDocuments => attachments.any((a) => a.isDocument || a.isFile);

  /// 🛠️ منشئ مخصص لرسائل المستخدم (User Message)
  factory ChatMessage.user({
    String content = '',
    List<ChatAttachment>? attachments,
    File? image,
    List<File>? images,
    String type = 'text',
    String? mediaPath,
    List<String>? mediaPaths,
    bool isNew = true,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    ReplyMode replyMode = ReplyMode.discussion,
    String? styleSummary,
    String? productContext,
    String? provider,
  }) {
    // بناء قائمة المرفقات الموحدة
    final List<ChatAttachment> resolvedAttachments = [];

    if (attachments != null && attachments.isNotEmpty) {
      resolvedAttachments.addAll(attachments);
    } else {
      // هجرة الحقول القديمة تلقائياً
      if (images != null && images.isNotEmpty) {
        for (var f in images) {
          resolvedAttachments.add(ChatAttachment.fromLocalFile(file: f, source: 'user_picker'));
        }
      } else if (image != null) {
        resolvedAttachments.add(ChatAttachment.fromLocalFile(file: image, source: 'user_picker'));
      } else if (mediaPath != null && mediaPath.isNotEmpty) {
        final f = File(mediaPath);
        if (f.existsSync()) {
          resolvedAttachments.add(ChatAttachment.fromLocalFile(file: f, source: 'user_picker'));
        }
      }
    }

    String finalType = type;
    if (resolvedAttachments.isNotEmpty) {
      if (resolvedAttachments.every((a) => a.isImage)) {
        if (resolvedAttachments.length >= 3) {
          finalType = 'reconstruction_3d';
        } else if (resolvedAttachments.length > 1) {
          finalType = 'multi_image';
        } else {
          finalType = 'image';
        }
      } else if (resolvedAttachments.every((a) => a.isVideo)) {
        finalType = 'video';
      } else if (resolvedAttachments.every((a) => a.isAudio)) {
        finalType = 'audio';
      } else {
        finalType = 'multimodal';
      }
    }

    return ChatMessage(
      id: "user_${DateTime.now().microsecondsSinceEpoch}",
      role: 'user',
      content: content,
      attachments: resolvedAttachments,
      type: finalType,
      state: MessageState.completed,
      isNew: isNew,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToRole: replyToRole,
      replyMode: replyMode,
      styleSummary: styleSummary,
      productContext: productContext,
      provider: provider,
    );
  }

  /// 🛠️ منشئ مخصص لرسائل المساعد (Assistant Message)
  factory ChatMessage.assistant({
    String? id,
    String content = "",
    List<ChatAttachment>? attachments,
    String type = 'text',
    MessageState state = MessageState.pending,
    List<Map<String, dynamic>>? actions,
    String? videoUrl,
    String? videoThumbnail,
    String? videoAuthor,
    String? responseImageUrl,
    String? audioPath,
    bool isNew = false,
    AgentResult? agentResult,
    Map<String, dynamic>? errorDetails,
    bool isError = false,
    String? productContext,
    String? provider,
  }) {
    final List<ChatAttachment> resolvedAttachments = [];
    if (attachments != null && attachments.isNotEmpty) {
      resolvedAttachments.addAll(attachments);
    } else {
      if (responseImageUrl != null && responseImageUrl.isNotEmpty) {
        resolvedAttachments.add(ChatAttachment.fromRemote(url: responseImageUrl, contentType: 'image/jpeg'));
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        resolvedAttachments.add(ChatAttachment.fromRemote(url: videoUrl, contentType: 'video/mp4', thumbnailUrl: videoThumbnail));
      }
      if (audioPath != null && audioPath.isNotEmpty) {
        resolvedAttachments.add(ChatAttachment.fromRemote(url: audioPath, contentType: 'audio/mpeg'));
      }
    }

    String finalType = type;
    if (resolvedAttachments.isNotEmpty && finalType == 'text') {
      if (resolvedAttachments.any((a) => a.isVideo)) {
        finalType = 'generated_video';
      } else if (resolvedAttachments.any((a) => a.isImage)) {
        finalType = 'generated_image';
      } else {
        finalType = 'multimodal';
      }
    }

    return ChatMessage(
      id: id ?? "asst_${DateTime.now().microsecondsSinceEpoch}",
      role: 'assistant',
      content: content,
      attachments: resolvedAttachments,
      type: finalType,
      state: state,
      actions: actions,
      videoAuthor: videoAuthor,
      isNew: isNew,
      agentResult: agentResult,
      isError: state == MessageState.error || (errorDetails != null),
      errorDetails: errorDetails,
      productContext: productContext,
      provider: provider,
      videoUrl: videoUrl,
      videoThumbnail: videoThumbnail,
      responseImageUrl: responseImageUrl,
      audioPath: audioPath,
    );
  }

  /// إنشاء نسخة مع تحديث الحقول (Copy with Updated Fields)
  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    List<ChatAttachment>? attachments,
    bool? isError,
    File? image,
    List<File>? images,
    String? type,
    String? mediaPath,
    List<String>? mediaPaths,
    String? videoUrl,
    String? videoThumbnail,
    String? videoAuthor,
    String? responseImageUrl,
    String? audioPath,
    List<Map<String, dynamic>>? actions,
    List<MediaAction>? mediaActions,
    bool? isGenerating,
    MessageState? state,
    List<String>? words,
    bool? isNew,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    List<Map<String, dynamic>>? recommendations,
    AgentResult? agentResult,
    Map<String, dynamic>? errorDetails,
    String? productContext,
    String? provider,
    bool clearAgentResult = false,
    bool clearVideoUrl = false,
  }) {
    List<ChatAttachment> nextAttachments = attachments ?? this.attachments;

    // إذا تم تمرير حقول وسائط صريحة جديدة دون تمرير attachments
    if (attachments == null) {
      if (videoUrl != null && !nextAttachments.any((a) => a.remoteUrl == videoUrl)) {
        nextAttachments = [...nextAttachments, ChatAttachment.fromRemote(url: videoUrl, contentType: 'video/mp4', thumbnailUrl: videoThumbnail)];
      }
      if (responseImageUrl != null && !nextAttachments.any((a) => a.remoteUrl == responseImageUrl)) {
        nextAttachments = [...nextAttachments, ChatAttachment.fromRemote(url: responseImageUrl, contentType: 'image/jpeg')];
      }
      if (image != null && !nextAttachments.any((a) => a.localPath == image.path)) {
        nextAttachments = [...nextAttachments, ChatAttachment.fromLocalFile(file: image)];
      }
    }

    if (clearVideoUrl) {
      nextAttachments = nextAttachments.where((a) => !a.isVideo).toList();
    }

    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      attachments: nextAttachments,
      isError: isError ?? this.isError,
      type: type ?? this.type,
      videoAuthor: videoAuthor ?? this.videoAuthor,
      actions: actions ?? this.actions,
      mediaActions: mediaActions ?? this.mediaActions,
      isGenerating: isGenerating ?? this.isGenerating,
      state: state ?? this.state,
      words: words ?? this.words,
      isNew: isNew ?? this.isNew,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToRole: replyToRole ?? this.replyToRole,
      recommendations: recommendations ?? this.recommendations,
      agentResult: clearAgentResult ? null : (agentResult ?? this.agentResult),
      errorDetails: errorDetails ?? this.errorDetails,
      productContext: productContext ?? this.productContext,
      provider: provider ?? this.provider,
    );
  }

  bool get isStreaming => state == MessageState.streaming;
  bool get isDone => state == MessageState.completed;

  /// 🛠️ تحويل الخريطة (Map) إلى كائن (Object) - لقاعدة البيانات
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    List<ChatAttachment> parsedAttachments = [];

    // 1. محاولة قراءة attachments من meta_data
    if (map['meta_data'] != null && map['meta_data'].toString().isNotEmpty) {
      try {
        final meta = jsonDecode(map['meta_data'].toString());
        if (meta is Map && meta['attachments'] is List) {
          parsedAttachments = (meta['attachments'] as List)
              .map((a) => ChatAttachment.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList();
        }
      } catch (_) {}
    }

    // 2. إذا لم تكن موجودة، نبنيها من الحقول القديمة (هجرة سلسة)
    if (parsedAttachments.isEmpty) {
      final mediaPath = map['media_path']?.toString();
      final videoUrl = map['video_url']?.toString();
      final responseImg = map['response_image_url']?.toString();
      final audioPath = map['audio_path']?.toString();

      if (mediaPath != null && mediaPath.isNotEmpty) {
        final f = File(mediaPath);
        if (f.existsSync()) {
          parsedAttachments.add(ChatAttachment.fromLocalFile(file: f));
        } else {
          parsedAttachments.add(ChatAttachment.fromRemote(url: mediaPath));
        }
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        parsedAttachments.add(ChatAttachment.fromRemote(
          url: videoUrl,
          contentType: 'video/mp4',
          thumbnailUrl: map['video_thumbnail']?.toString(),
        ));
      }
      if (responseImg != null && responseImg.isNotEmpty) {
        parsedAttachments.add(ChatAttachment.fromRemote(url: responseImg, contentType: 'image/jpeg'));
      }
      if (audioPath != null && audioPath.isNotEmpty) {
        parsedAttachments.add(ChatAttachment.fromRemote(url: audioPath, contentType: 'audio/mpeg'));
      }
    }

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      role: map['role'] ?? 'assistant',
      content: map['content'] ?? (map['ai_response'] ?? map['user_message'] ?? ''),
      attachments: parsedAttachments,
      type: map['type'] ?? (map['message_type'] ?? 'text'),
      videoAuthor: map['video_author']?.toString(),
      isError: (map['is_error'] == 1 || map['is_error'] == true),
      state: MessageState.values.firstWhere(
        (e) => e.name == (map['state'] ?? 'completed'),
        orElse: () => MessageState.completed,
      ),
      productContext: map['product_context']?.toString(),
      provider: map['provider']?.toString(),
    );
  }

  /// 🛠️ تحويل الكائن (Object) إلى خريطة (Map) - لقاعدة البيانات
  Map<String, dynamic> toMap() {
    final firstImg = attachments.where((a) => a.isImage).firstOrNull;
    final firstVid = attachments.where((a) => a.isVideo).firstOrNull;
    final firstAud = attachments.where((a) => a.isAudio).firstOrNull;

    return {
      'id': id,
      'role': role,
      'content': content,
      'type': type,
      'media_path': firstImg?.localPath ?? firstImg?.remoteUrl ?? attachments.firstOrNull?.localPath ?? attachments.firstOrNull?.remoteUrl,
      'video_url': firstVid?.remoteUrl ?? firstVid?.localPath,
      'video_thumbnail': firstVid?.thumbnailUrl,
      'video_author': videoAuthor,
      'response_image_url': firstImg?.remoteUrl,
      'audio_path': firstAud?.localPath ?? firstAud?.remoteUrl,
      'is_error': isError ? 1 : 0,
      'state': state.name,
      'product_context': productContext,
      'provider': provider,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
