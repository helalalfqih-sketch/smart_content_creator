/// 🎬 CatalogProductMedia Model
/// نموذج بيانات وسائط المنتج (الصور والفيديوهات والمستندات) للكتالوج
class CatalogProductMedia {
  final String? id; // Parse objectId / local ID
  final String productId; // معرف المنتج المرتبط (SKU)
  final String type; // 'image', 'video', 'audio', 'file'
  final String url; // رابط الملف الأصلي
  final String thumbnailUrl; // رابط الصورة المصغرة
  final String? mimeType;
  final String? filename;
  final int sortOrder;
  final bool isPrimary;
  final String source; // 'excel', 'upload', 'ai_gen'
  final String status; // 'active', 'deleted'
  final int? width;
  final int? height;
  final int? durationMs;
  final Map<String, dynamic>? metadata;
  final String dedupeKey; // SHA256(productId|type|url)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CatalogProductMedia({
    this.id,
    required this.productId,
    this.type = 'image',
    required this.url,
    this.thumbnailUrl = '',
    this.mimeType,
    this.filename,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.source = 'app',
    this.status = 'active',
    this.width,
    this.height,
    this.durationMs,
    this.metadata,
    required this.dedupeKey,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'mime_type': mimeType,
      'filename': filename,
      'sort_order': sortOrder,
      'is_primary': isPrimary ? 1 : 0,
      'source': source,
      'status': status,
      'width': width,
      'height': height,
      'duration_ms': durationMs,
      'dedupe_key': dedupeKey,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory CatalogProductMedia.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CatalogProductMedia(
      id: docId ?? map['id']?.toString() ?? map['objectId']?.toString(),
      productId: map['product_id']?.toString() ?? map['productId']?.toString() ?? '',
      type: map['type'] as String? ?? 'image',
      url: map['url'] as String? ?? '',
      thumbnailUrl: (map['thumbnail_url'] ?? map['thumbnailUrl']) as String? ?? '',
      mimeType: (map['mime_type'] ?? map['mimeType']) as String?,
      filename: map['filename'] as String?,
      sortOrder: (map['sort_order'] ?? map['sortOrder'] as num?)?.toInt() ?? 0,
      isPrimary: map['is_primary'] == 1 || map['is_primary'] == true || map['isPrimary'] == true,
      source: map['source'] as String? ?? 'app',
      status: map['status'] as String? ?? 'active',
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      durationMs: (map['duration_ms'] ?? map['durationMs'] as num?)?.toInt(),
      dedupeKey: map['dedupe_key']?.toString() ?? map['dedupeKey']?.toString() ?? '',
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  CatalogProductMedia copyWith({
    String? id,
    String? productId,
    String? type,
    String? url,
    String? thumbnailUrl,
    String? mimeType,
    String? filename,
    int? sortOrder,
    bool? isPrimary,
    String? source,
    String? status,
    int? width,
    int? height,
    int? durationMs,
    Map<String, dynamic>? metadata,
    String? dedupeKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatalogProductMedia(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      filename: filename ?? this.filename,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      source: source ?? this.source,
      status: status ?? this.status,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      metadata: metadata ?? this.metadata,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
