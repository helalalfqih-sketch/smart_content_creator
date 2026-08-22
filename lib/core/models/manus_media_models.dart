import 'chat_attachment.dart';

/// 🎬 ManusMediaItem — Single media attachment from Manus task
/// Maps to assistant_message.attachments[] fields
class ManusMediaItem {
  final String type;        // 'image', 'video', 'audio', 'file'
  final String? filename;
  final String? url;
  final String? contentType;

  const ManusMediaItem({
    required this.type,
    this.filename,
    this.url,
    this.contentType,
  });

  factory ManusMediaItem.fromJson(Map<String, dynamic> json) {
    return ManusMediaItem(
      type: json['type']?.toString() ?? 'file',
      filename: json['filename']?.toString(),
      url: json['url']?.toString(),
      contentType: json['content_type']?.toString(),
    );
  }

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isAudio => type == 'audio';
  bool get isFile => type == 'file';

  /// تحويل إلى كائن ChatAttachment الموحد
  ChatAttachment toChatAttachment() {
    return ChatAttachment.fromRemote(
      url: url ?? '',
      filename: filename,
      contentType: contentType,
      source: 'manus_generated',
    );
  }
}

/// 🤖 ManusTaskStatus — Polling result from aiManusTaskStatus
/// Correction #4: Real Manus states — running, stopped, waiting, error
/// NO fake progress percentages
class ManusTaskStatus {
  final bool success;
  final String taskId;
  final String status;         // 'running', 'stopped', 'waiting', 'error', 'completed'
  final bool isCompleted;
  final bool isError;
  final bool isRunning;
  final bool isWaiting;
  final String? statusBrief;       // From status_update.brief
  final String? statusDescription; // From status_update.description
  final String? data;              // Assistant text response (when completed)
  final List<ManusMediaItem> media; // Attachments (when completed)
  final String? error;

  const ManusTaskStatus({
    required this.success,
    required this.taskId,
    required this.status,
    this.isCompleted = false,
    this.isError = false,
    this.isRunning = false,
    this.isWaiting = false,
    this.statusBrief,
    this.statusDescription,
    this.data,
    this.media = const [],
    this.error,
  });

  factory ManusTaskStatus.fromJson(Map<String, dynamic> json) {
    final mediaList = (json['media'] as List?)
        ?.map((m) => ManusMediaItem.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList() ?? [];

    return ManusTaskStatus(
      success: json['success'] == true,
      taskId: json['task_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      isCompleted: json['is_completed'] == true,
      isError: json['is_error'] == true,
      isRunning: json['is_running'] == true,
      isWaiting: json['is_waiting'] == true,
      statusBrief: json['status_brief']?.toString(),
      statusDescription: json['status_description']?.toString(),
      data: json['data']?.toString(),
      media: mediaList,
      error: json['error']?.toString(),
    );
  }

  /// Get the best status message for UI display
  /// Correction #4: Use real status_update text, NO fake percentages
  String get displayMessage {
    if (statusBrief != null && statusBrief!.isNotEmpty) return statusBrief!;
    if (statusDescription != null && statusDescription!.isNotEmpty) return statusDescription!;
    if (isCompleted) return 'تمت المهمة بنجاح ✅';
    if (isError) return error ?? 'حدث خطأ ❌';
    if (isWaiting) return 'في انتظار المزيد من المعلومات... ⏳';
    if (isRunning) return 'جاري المعالجة... 🔄';
    return 'جاري التحضير...';
  }

  /// Check if any image attachments exist
  bool get hasImages => media.any((m) => m.isImage);

  /// Check if any video attachments exist
  bool get hasVideos => media.any((m) => m.isVideo);

  /// Get first image URL
  String? get firstImageUrl => media.where((m) => m.isImage).firstOrNull?.url;

  /// Get first video URL
  String? get firstVideoUrl => media.where((m) => m.isVideo).firstOrNull?.url;

  /// تحويل كافة المرفقات إلى ChatAttachment
  List<ChatAttachment> get chatAttachments =>
      media.map((m) => m.toChatAttachment()).toList();
}

/// 🚀 ManusGatewayResponse — Initial response from aiManusGateway
/// For media tasks: async=true, task_id returned immediately
/// For text tasks: async=false, data returned synchronously
class ManusGatewayResponse {
  final bool success;
  final bool isAsync;
  final String? data;
  final String? taskId;
  final List<ManusMediaItem> media;
  final Map<String, dynamic> meta;
  final String? error;

  const ManusGatewayResponse({
    required this.success,
    this.isAsync = false,
    this.data,
    this.taskId,
    this.media = const [],
    this.meta = const {},
    this.error,
  });

  factory ManusGatewayResponse.fromJson(Map<String, dynamic> json) {
    final mediaList = (json['media'] as List?)
        ?.map((m) => ManusMediaItem.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList() ?? [];

    return ManusGatewayResponse(
      success: json['success'] == true,
      isAsync: json['async'] == true,
      data: json['data']?.toString(),
      taskId: json['task_id']?.toString() ?? (json['meta'] as Map?)?['task_id']?.toString(),
      media: mediaList,
      meta: Map<String, dynamic>.from((json['meta'] as Map?) ?? {}),
      error: json['error']?.toString(),
    );
  }

  String? get conversationMode => meta['conversation_mode']?.toString();

  List<ChatAttachment> get chatAttachments =>
      media.map((m) => m.toChatAttachment()).toList();
}
