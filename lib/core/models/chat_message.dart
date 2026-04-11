import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smart_content_creator/widgets/media_action_bar.dart';
import 'package:smart_content_creator/ai/core/agent_models.dart';

/// 🎬 استوديو صنع المحتوى (AI Creator Studio) - أنواع الرسائل
enum CreatorMessageType {
  text,
  image,
  video,
  audio,
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
  final String content;
  final bool isError;
  final File? image;
  final List<File>? images; // 📸 New: Multiple images
  final String
      type; // 'text', 'image', 'action_menu', 'scenario', 'generated_image', 'generated_video', 'multi_image'
  final String? mediaPath; // Local path for persistence
  final List<String>? mediaPaths; // 📸 New: Multiple local paths
  final String? videoUrl; // URL for video playback
  final String? videoThumbnail; // 📸 Preview Image for TikTok Rich Cards
  final String? videoAuthor; // 👤 Creator Name
  final String? responseImageUrl; // URL for AI generated image
  final String? audioPath; // 🎬 Path to audio file (music/voice)
  final List<Map<String, dynamic>>? actions; // Smart buttons
  final List<MediaAction>? mediaActions; // 🎬 Creator Studio actions
  final bool
      isGenerating; // 🎬 Legacy field (keep for safety if used elsewhere, but state is preferred)
  final MessageState state; // 🚥 The Source of Truth
  final List<String>? words; // 📑 List of words for caption preview
  final bool
      isNew; // 🆕 Flag to indicate if message should stream character-by-character
  final String? replyToId; // 🔗 ID of the message being replied to
  final String? replyToContent; // 📝 Snippet of the replied message content
  final String?
      replyToRole; // 👤 Role of message being replied to ('user'/'assistant')
  final ReplyMode
      replyMode; // 🧬 Operation Mode (discussion/modification/transform)
  final String? styleSummary; // 🎨 Brief style hint for LLM
  final List<Map<String, dynamic>>? recommendations; // 🧠 Related Topics
  final AgentResult? agentResult; // 🤖 Typed AI Agent results
  final Map<String, dynamic>? errorDetails; // 🔴 UI payload for glassmorphic error cards
  final String? productContext; // 🧠 The product name/brand this message refers to

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.isError = false,
    this.image,
    this.images,
    this.type = 'text',
    this.mediaPath,
    this.mediaPaths,
    this.videoUrl,
    this.videoThumbnail,
    this.videoAuthor,
    this.responseImageUrl,
    this.audioPath,
    this.actions,
    this.mediaActions,
    this.isGenerating = false,
    this.state =
        MessageState.completed, // Default to completed (e.g. for history)
    this.words,
    this.isNew = false, // 🆕 Default to false (old message, no streaming)
    this.replyToId,
    this.replyToContent,
    this.replyToRole,
    this.replyMode = ReplyMode.discussion,
    this.styleSummary,
    this.recommendations,
    this.agentResult,
    this.errorDetails,
    this.productContext,
  });

  /// 🛠️ منشئ مخصص لرسائل المستخدم (Named Constructor)
  factory ChatMessage.user({
    required String content,
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
  }) {
    String finalType = type;
    File? firstImage = image;
    List<String>? finalMediaPaths = mediaPaths;

    if (images != null && images.isNotEmpty) {
      firstImage = images.first;
      if (images.length >= 3) {
        finalType = 'reconstruction_3d';
      } else if (images.length > 1) {
        finalType = 'multi_image';
      } else {
        finalType = 'image';
      }
      
      finalMediaPaths ??= images.map((f) => f.path).toList();
    }

    return ChatMessage(
      id: "user_${DateTime.now().microsecondsSinceEpoch}",
      role: 'user',
      content: content,
      image: firstImage,
      images: images,
      type: finalType,
      mediaPath: mediaPath ?? firstImage?.path,
      mediaPaths: finalMediaPaths,
      state: MessageState.completed,
      isNew: isNew, // 🆕 User messages are new by default
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToRole: replyToRole,
      replyMode: replyMode,
      styleSummary: styleSummary,
      productContext: productContext,
    );
  }

  /// 🛠️ منشئ مخصص لرسائل المساعد (Assistant)
  factory ChatMessage.assistant({
    String content = "",
    String type = 'text',
    MessageState state = MessageState.pending,
    List<Map<String, dynamic>>? actions,
    String? videoUrl,
    String? videoThumbnail,
    String? videoAuthor,
    bool isNew = false, // 🆕 Default to false to avoid repeated streaming
    AgentResult? agentResult,
    Map<String, dynamic>? errorDetails,
    bool isError = false,
    String? productContext,
  }) {
    return ChatMessage(
      id: "asst_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey().toString()}",
      role: 'assistant',
      content: content,
      type: type,
      state: state,
      actions: actions,
      videoUrl: videoUrl,
      videoThumbnail: videoThumbnail,
      videoAuthor: videoAuthor,
      isNew: isNew, // 🆕 Control streaming behavior
      agentResult: agentResult,
      isError: state == MessageState.error || (errorDetails != null),
      errorDetails: errorDetails,
      productContext: productContext,
    );
  }

  /// إنشاء نسخة مع تحديث الحقول (Copy with Updated Fields)
  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
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
    bool? isNew, // 🆕 Support updating isNew flag
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    List<Map<String, dynamic>>? recommendations,
    AgentResult? agentResult,
    Map<String, dynamic>? errorDetails,
    String? productContext,
  }) {
    return ChatMessage(
      id: id ?? this.id, // Support updating ID if needed (e.g. for history)
      role: role ?? this.role,
      content: content ?? this.content,
      isError: isError ?? this.isError,
      image: image ?? this.image,
      images: images ?? this.images,
      type: type ?? this.type,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnail: videoThumbnail ?? this.videoThumbnail,
      videoAuthor: videoAuthor ?? this.videoAuthor,
      responseImageUrl: responseImageUrl ?? this.responseImageUrl,
      audioPath: audioPath ?? this.audioPath,
      actions: actions ?? this.actions,
      mediaActions: mediaActions ?? this.mediaActions,
      isGenerating: isGenerating ?? this.isGenerating,
      state: state ?? this.state,
      words: words ?? this.words,
      isNew: isNew ?? this.isNew, // 🆕 Preserve isNew flag
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToRole: replyToRole ?? this.replyToRole,
      recommendations: recommendations ?? this.recommendations,
      agentResult: agentResult ?? this.agentResult,
      errorDetails: errorDetails ?? this.errorDetails,
      productContext: productContext ?? this.productContext,
    );
  }

  bool get isStreaming => state == MessageState.streaming;
  bool get isDone => state == MessageState.completed;

  /// 🛠️ تحويل الخريطة (Map) إلى كائن (Object) - لقاعدة البيانات
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      role: map['role'] ?? 'assistant',
      content: map['content'] ?? (map['ai_response'] ?? map['user_message'] ?? ''),
      type: map['type'] ?? (map['message_type'] ?? 'text'),
      mediaPath: map['media_path'],
      videoUrl: map['video_url'],
      videoThumbnail: map['video_thumbnail'],
      videoAuthor: map['video_author'],
      responseImageUrl: map['response_image_url'],
      audioPath: map['audio_path'],
      isError: (map['is_error'] == 1 || map['is_error'] == true),
      state: MessageState.values.firstWhere(
        (e) => e.name == (map['state'] ?? 'completed'),
        orElse: () => MessageState.completed,
      ),
      productContext: map['product_context'],
    );
  }

  /// 🛠️ تحويل الكائن (Object) إلى خريطة (Map) - لقاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'type': type,
      'media_path': mediaPath,
      'video_url': videoUrl,
      'video_thumbnail': videoThumbnail,
      'video_author': videoAuthor,
      'response_image_url': responseImageUrl,
      'audio_path': audioPath,
      'is_error': isError ? 1 : 0,
      'state': state.name,
      'product_context': productContext,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
