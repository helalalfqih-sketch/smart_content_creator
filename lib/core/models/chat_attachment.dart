import 'dart:io';
import 'package:path/path.dart' as p;

/// 📦 نوع المرفق (Attachment Type)
enum AttachmentType {
  image,
  video,
  audio,
  document,
  file,
}

/// 🚥 حالة رفع/تخزين المرفق (Upload State)
enum UploadState {
  local,     // مخزن محلياً فقط
  uploading, // جاري الرفع للسحابة
  uploaded,  // تم الرفع ومتاح برابط سحابي
  failed,    // فشل الرفع
}

/// 📎 ChatAttachment — النموذج الموحد لجميع المرفقات والوسائط في المحادثة
///
/// يدعم الصور، مقاطع الفيديو، التسجيلات الصوتية، والمستندات
/// ثنائي الاتجاه: صالح لمرفقات المستخدم ولمخرجات الذكاء الاصطناعي (Manus وغيره).
class ChatAttachment {
  final String id;
  final AttachmentType type;
  final String mimeType;
  final String? filename;
  final String? localPath;
  final String? remoteUrl;
  final String? thumbnailUrl;
  final int? sizeBytes;
  final int? durationMs;
  final int? width;
  final int? height;
  final String source; // 'user_picker', 'camera', 'manus_generated', 'gemini_generated', 'url'
  final UploadState uploadState;
  final Map<String, dynamic>? metadata;

  const ChatAttachment({
    required this.id,
    required this.type,
    required this.mimeType,
    this.filename,
    this.localPath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.sizeBytes,
    this.durationMs,
    this.width,
    this.height,
    this.source = 'user_picker',
    this.uploadState = UploadState.local,
    this.metadata,
  });

  /// 📸 إنشاء مرفق من ملف محلي
  factory ChatAttachment.fromLocalFile({
    required File file,
    String? id,
    AttachmentType? type,
    String? mimeType,
    String source = 'user_picker',
    String? thumbnailUrl,
    int? durationMs,
    int? width,
    int? height,
    Map<String, dynamic>? metadata,
  }) {
    final path = file.path;
    final name = p.basename(path);
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');

    final resolvedType = type ?? _inferTypeFromExtension(ext);
    final resolvedMime = mimeType ?? _inferMimeFromExtension(ext, resolvedType);

    int? size;
    try {
      if (file.existsSync()) {
        size = file.lengthSync();
      }
    } catch (_) {}

    return ChatAttachment(
      id: id ?? "att_${DateTime.now().microsecondsSinceEpoch}",
      type: resolvedType,
      mimeType: resolvedMime,
      filename: name,
      localPath: path,
      sizeBytes: size,
      source: source,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
      width: width,
      height: height,
      uploadState: UploadState.local,
      metadata: metadata,
    );
  }

  /// 🤖 إنشاء مرفق من مخرجات الذكاء الاصطناعي (Manus / Cloud Output)
  factory ChatAttachment.fromRemote({
    required String url,
    String? id,
    String? contentType,
    String? filename,
    String? thumbnailUrl,
    String source = 'manus_generated',
    Map<String, dynamic>? metadata,
  }) {
    final resolvedType = _inferTypeFromContentType(contentType, url);
    final resolvedMime = contentType ?? _inferMimeFromExtension(p.extension(url).toLowerCase().replaceAll('.', ''), resolvedType);

    return ChatAttachment(
      id: id ?? "att_${DateTime.now().microsecondsSinceEpoch}",
      type: resolvedType,
      mimeType: resolvedMime,
      filename: filename ?? p.basename(Uri.tryParse(url)?.path ?? 'media'),
      remoteUrl: url,
      thumbnailUrl: thumbnailUrl,
      source: source,
      uploadState: UploadState.uploaded,
      metadata: metadata,
    );
  }

  /// 🛠️ تحويل إلى Map للتخزين في قاعدة البيانات / JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'mime_type': mimeType,
      if (filename != null) 'filename': filename,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (durationMs != null) 'duration_ms': durationMs,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'source': source,
      'upload_state': uploadState.name,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// 🛠️ استعادة من Map
  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id']?.toString() ?? "att_${DateTime.now().microsecondsSinceEpoch}",
      type: AttachmentType.values.firstWhere(
        (t) => t.name == (json['type']?.toString() ?? 'file'),
        orElse: () => AttachmentType.file,
      ),
      mimeType: json['mime_type']?.toString() ?? 'application/octet-stream',
      filename: json['filename']?.toString(),
      localPath: json['local_path']?.toString(),
      remoteUrl: json['remote_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      sizeBytes: json['size_bytes'] is int ? json['size_bytes'] as int : null,
      durationMs: json['duration_ms'] is int ? json['duration_ms'] as int : null,
      width: json['width'] is int ? json['width'] as int : null,
      height: json['height'] is int ? json['height'] as int : null,
      source: json['source']?.toString() ?? 'user_picker',
      uploadState: UploadState.values.firstWhere(
        (u) => u.name == (json['upload_state']?.toString() ?? 'local'),
        orElse: () => UploadState.local,
      ),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  ChatAttachment copyWith({
    String? id,
    AttachmentType? type,
    String? mimeType,
    String? filename,
    String? localPath,
    String? remoteUrl,
    String? thumbnailUrl,
    int? sizeBytes,
    int? durationMs,
    int? width,
    int? height,
    String? source,
    UploadState? uploadState,
    Map<String, dynamic>? metadata,
  }) {
    return ChatAttachment(
      id: id ?? this.id,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      filename: filename ?? this.filename,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      source: source ?? this.source,
      uploadState: uploadState ?? this.uploadState,
      metadata: metadata ?? this.metadata,
    );
  }

  // --- Convenience Getters ---
  bool get isImage => type == AttachmentType.image;
  bool get isVideo => type == AttachmentType.video;
  bool get isAudio => type == AttachmentType.audio;
  bool get isDocument => type == AttachmentType.document;
  bool get isFile => type == AttachmentType.file;

  /// الرابط الفعّال للعرض (المحلي أولاً، ثم السحابي)
  String? get displaySource {
    if (localPath != null && localPath!.isNotEmpty && File(localPath!).existsSync()) {
      return localPath;
    }
    return remoteUrl;
  }

  File? get asLocalFile {
    if (localPath != null && localPath!.isNotEmpty) {
      final f = File(localPath!);
      if (f.existsSync()) return f;
    }
    return null;
  }

  // --- Internal Helpers ---
  static AttachmentType _inferTypeFromExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'bmp':
      case 'heic':
        return AttachmentType.image;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
      case '3gp':
        return AttachmentType.video;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
      case 'flac':
        return AttachmentType.audio;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'csv':
      case 'xlsx':
        return AttachmentType.document;
      default:
        return AttachmentType.file;
    }
  }

  static AttachmentType _inferTypeFromContentType(String? contentType, String url) {
    if (contentType != null && contentType.isNotEmpty) {
      final ct = contentType.toLowerCase();
      if (ct.startsWith('image/')) return AttachmentType.image;
      if (ct.startsWith('video/')) return AttachmentType.video;
      if (ct.startsWith('audio/')) return AttachmentType.audio;
      if (ct.startsWith('application/pdf') || ct.startsWith('text/')) return AttachmentType.document;
    }
    final ext = p.extension(url).toLowerCase().replaceAll('.', '');
    return _inferTypeFromExtension(ext);
  }

  static String _inferMimeFromExtension(String ext, AttachmentType type) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'pdf':
        return 'application/pdf';
      default:
        switch (type) {
          case AttachmentType.image:
            return 'image/jpeg';
          case AttachmentType.video:
            return 'video/mp4';
          case AttachmentType.audio:
            return 'audio/mpeg';
          case AttachmentType.document:
            return 'application/pdf';
          case AttachmentType.file:
            return 'application/octet-stream';
        }
    }
  }
}
