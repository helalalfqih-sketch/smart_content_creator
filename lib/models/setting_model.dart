class SettingModel {
  final int? id;
  final String key;
  final String value;
  final DateTime updatedAt;

  SettingModel({
    this.id,
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  factory SettingModel.fromMap(Map<String, dynamic> map) {
    return SettingModel(
      id: map['id'] as int?,
      key: map['key'] as String? ?? '',
      value: map['value'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SettingModel copyWith({
    int? id,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) {
    return SettingModel(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'SettingModel(id: $id, key: $key, value: $value, updatedAt: $updatedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          key == other.key &&
          value == other.value &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^ key.hashCode ^ value.hashCode ^ updatedAt.hashCode;
}
