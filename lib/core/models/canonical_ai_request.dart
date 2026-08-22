import 'dart:typed_data';
import 'chat_attachment.dart';

/// 🌐 Canonical AI Request
/// المصدر الموحد الوحيد لجميع بيانات الطلب الموجهة للذكاء الاصطناعي
/// يضمن عدم تكرار البرومبتات أو منطق العمل بين المزودات المختلفة (Gemini, Manus, Back4App).
class CanonicalAiRequest {
  final String prompt;
  final int? appSessionId;
  final String? systemPersona;
  final List<Map<String, String>>? history;
  final List<ChatAttachment>? attachments; // 📎 القائمة الموحدة للمرفقات متعددة الوسائط
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
    this.appSessionId,
    this.systemPersona,
    this.history,
    this.attachments,
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

  bool get hasImage =>
      imageBytes != null ||
      (images != null && images!.isNotEmpty) ||
      (attachments != null && attachments!.any((a) => a.isImage));

  bool get hasMedia =>
      hasImage || (attachments != null && attachments!.isNotEmpty);

  bool get hasVideos =>
      attachments != null && attachments!.any((a) => a.isVideo);

  bool get hasAudio =>
      attachments != null && attachments!.any((a) => a.isAudio);

  Map<String, dynamic> toJson({bool includeRawBytes = false}) {
    return {
      'prompt': prompt,
      if (appSessionId != null) 'appSessionId': appSessionId,
      'systemPersona': systemPersona,
      'history': history,
      if (attachments != null && attachments!.isNotEmpty)
        'attachments': attachments!.map((a) => a.toJson()).toList(),
      'mimeType': mimeType,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'isModificationMode': isModificationMode,
      'templateId': templateId,
      'templateInputs': templateInputs,
      'taskType': taskType,
      'hasImage': hasImage,
      'hasMedia': hasMedia,
      'metadata': metadata,
      if (includeRawBytes && imageBytes != null) 'imageBytesLength': imageBytes!.length,
    };
  }

  CanonicalAiRequest copyWith({
    String? prompt,
    int? appSessionId,
    String? systemPersona,
    List<Map<String, String>>? history,
    List<ChatAttachment>? attachments,
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
      appSessionId: appSessionId ?? this.appSessionId,
      systemPersona: systemPersona ?? this.systemPersona,
      history: history ?? this.history,
      attachments: attachments ?? this.attachments,
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
