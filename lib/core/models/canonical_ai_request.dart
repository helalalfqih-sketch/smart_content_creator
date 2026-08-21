import 'dart:typed_data';

/// 🌐 Canonical AI Request
/// المصدر الموحد الوحيد لجميع بيانات الطلب الموجهة للذكاء الاصطناعي
/// يضمن عدم تكرار البرومبتات أو منطق العمل بين المزودات المختلفة (Gemini, Manus, Back4App).
class CanonicalAiRequest {
  final String prompt;
  final String? systemPersona;
  final List<Map<String, String>>? history;
  final Uint8List? imageBytes;
  final List<Uint8List>? images;
  final String mimeType;
  final int maxTokens;
  final double temperature;
  final bool isModificationMode;
  final String? templateId;
  final Map<String, Object?>? templateInputs;
  final String taskType;
  final Map<String, dynamic>? metadata;

  const CanonicalAiRequest({
    required this.prompt,
    this.systemPersona,
    this.history,
    this.imageBytes,
    this.images,
    this.mimeType = 'image/jpeg',
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.isModificationMode = false,
    this.templateId,
    this.templateInputs,
    this.taskType = 'general',
    this.metadata,
  });

  bool get hasImage => imageBytes != null || (images != null && images!.isNotEmpty);

  Map<String, dynamic> toJson({bool includeRawBytes = false}) {
    return {
      'prompt': prompt,
      'systemPersona': systemPersona,
      'history': history,
      'mimeType': mimeType,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'isModificationMode': isModificationMode,
      'templateId': templateId,
      'templateInputs': templateInputs,
      'taskType': taskType,
      'hasImage': hasImage,
      'metadata': metadata,
      if (includeRawBytes && imageBytes != null) 'imageBytesLength': imageBytes!.length,
    };
  }

  CanonicalAiRequest copyWith({
    String? prompt,
    String? systemPersona,
    List<Map<String, String>>? history,
    Uint8List? imageBytes,
    List<Uint8List>? images,
    String? mimeType,
    int? maxTokens,
    double? temperature,
    bool? isModificationMode,
    String? templateId,
    Map<String, Object?>? templateInputs,
    String? taskType,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalAiRequest(
      prompt: prompt ?? this.prompt,
      systemPersona: systemPersona ?? this.systemPersona,
      history: history ?? this.history,
      imageBytes: imageBytes ?? this.imageBytes,
      images: images ?? this.images,
      mimeType: mimeType ?? this.mimeType,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      isModificationMode: isModificationMode ?? this.isModificationMode,
      templateId: templateId ?? this.templateId,
      templateInputs: templateInputs ?? this.templateInputs,
      taskType: taskType ?? this.taskType,
      metadata: metadata ?? this.metadata,
    );
  }
}
