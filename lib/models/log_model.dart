class LogModel {
  final int? id;
  final String action;
  final String? details;
  final DateTime createdAt;

  LogModel({
    this.id,
    required this.action,
    this.details,
    required this.createdAt,
  });

  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: map['id'] as int?,
      action: map['action'] as String? ?? '',
      details: map['details'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LogModel copyWith({
    int? id,
    String? action,
    String? details,
    DateTime? createdAt,
  }) {
    return LogModel(
      id: id ?? this.id,
      action: action ?? this.action,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'LogModel(id: $id, action: $action, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          action == other.action &&
          details == other.details &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^ action.hashCode ^ details.hashCode ^ createdAt.hashCode;
}
