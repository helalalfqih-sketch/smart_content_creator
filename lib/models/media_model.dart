class MediaModel {
  final int? id;
  final String? type;
  final String? path;
  final DateTime createdAt;

  MediaModel({
    this.id,
    this.type,
    this.path,
    required this.createdAt,
  });

  factory MediaModel.fromMap(Map<String, dynamic> map) {
    return MediaModel(
      id: map['id'] as int?,
      type: map['type'] as String?,
      path: map['path'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'path': path,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MediaModel copyWith({
    int? id,
    String? type,
    String? path,
    DateTime? createdAt,
  }) {
    return MediaModel(
      id: id ?? this.id,
      type: type ?? this.type,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'MediaModel(id: $id, type: $type, path: $path, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          path == other.path &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^ type.hashCode ^ path.hashCode ^ createdAt.hashCode;
}
