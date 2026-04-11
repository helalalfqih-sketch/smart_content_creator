class ContentModel {
  final int? id;
  final String? inputType;
  final String? inputPath;
  final String? prompt;
  final String? result;
  final String? model;
  final DateTime createdAt;

  ContentModel({
    this.id,
    this.inputType,
    this.inputPath,
    this.prompt,
    this.result,
    this.model,
    required this.createdAt,
  });

  factory ContentModel.fromMap(Map<String, dynamic> map) {
    return ContentModel(
      id: map['id'] as int?,
      inputType: map['input_type'] as String?,
      inputPath: map['input_path'] as String?,
      prompt: map['prompt'] as String?,
      result: map['result'] as String?,
      model: map['model'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'input_type': inputType,
      'input_path': inputPath,
      'prompt': prompt,
      'result': result,
      'model': model,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ContentModel copyWith({
    int? id,
    String? inputType,
    String? inputPath,
    String? prompt,
    String? result,
    String? model,
    DateTime? createdAt,
  }) {
    return ContentModel(
      id: id ?? this.id,
      inputType: inputType ?? this.inputType,
      inputPath: inputPath ?? this.inputPath,
      prompt: prompt ?? this.prompt,
      result: result ?? this.result,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'ContentModel(id: $id, inputType: $inputType, model: $model, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          inputType == other.inputType &&
          inputPath == other.inputPath &&
          prompt == other.prompt &&
          result == other.result &&
          model == other.model &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      inputType.hashCode ^
      inputPath.hashCode ^
      prompt.hashCode ^
      result.hashCode ^
      model.hashCode ^
      createdAt.hashCode;
}
