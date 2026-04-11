class ApiKeyModel {
  final int? id;
  final String serviceName;
  final String apiKey;
  final bool enabled;
  final DateTime createdAt;

  ApiKeyModel({
    this.id,
    required this.serviceName,
    required this.apiKey,
    this.enabled = true,
    required this.createdAt,
  });

  factory ApiKeyModel.fromMap(Map<String, dynamic> map) {
    return ApiKeyModel(
      id: map['id'] as int?,
      serviceName: map['service_name'] as String? ?? '',
      apiKey: map['api_key'] as String? ?? '',
      enabled: (map['enabled'] as int?) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service_name': serviceName,
      'api_key': apiKey,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ApiKeyModel copyWith({
    int? id,
    String? serviceName,
    String? apiKey,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return ApiKeyModel(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'ApiKeyModel(id: $id, serviceName: $serviceName, enabled: $enabled, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiKeyModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          serviceName == other.serviceName &&
          apiKey == other.apiKey &&
          enabled == other.enabled &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      serviceName.hashCode ^
      apiKey.hashCode ^
      enabled.hashCode ^
      createdAt.hashCode;
}
