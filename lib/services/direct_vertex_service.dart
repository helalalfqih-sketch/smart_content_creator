// Direct Gemini text/vision on Vertex (Agent Platform) through Firebase AI Logic.
// This client-side rollout gate is not a billing cap or an authorization boundary.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../ai/core/ai_constants.dart';
import '../core/utils/ai_request_exception.dart';
import '../core/utils/vision_image.dart';

class DirectVertexService {
  static const backend = 'vertex_direct';
  static const modelName = 'gemini-3.8-flash';

  static bool permits(Map<String, dynamic>? config, String? uid) =>
      uid != null &&
      config?['enabled'] == true &&
      config?['allowed_uids'] is List &&
      (config!['allowed_uids'] as List).contains(uid);

  Future<bool> isAllowed() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('vertex_direct')
          .get(const GetOptions(source: Source.server));
      return FirebaseAuth.instance.currentUser?.uid == uid &&
          permits(doc.data(), uid);
    } catch (_) {
      return false;
    }
  }

  static const disabled = AiRequestException(
    'vertex_disabled',
    'Vertex غير مفعّل لهذا الحساب. يلزم تأكيد إعدادات الفوترة وتفعيل الخدمة من المسؤول.',
  );

  static Map<String, dynamic> failure(AiRequestException error) => {
    'success': false,
    'error': error.toString(),
    'request_failure': error,
    'meta': {'provider': backend, 'model': modelName, 'status': 'error'},
  };

  static AiRequestException classify(Object error) {
    if (error is AiRequestException) return error;
    final message = error.toString().toLowerCase();
    bool hasCode(int code) => RegExp('(^|[^0-9])$code([^0-9]|\$)').hasMatch(message);
    if (hasCode(402) || message.contains('billing_disabled') ||
        message.contains('billing is disabled') ||
        message.contains('billing account') ||
        message.contains('payment required')) {
      return const AiRequestException(
        'http_402',
        'تعذر استخدام Vertex بسبب الفوترة أو الرصيد. لم يتم التحويل إلى مزود آخر.',
      );
    }
    if (hasCode(429) || message.contains('resource_exhausted') ||
        message.contains('resource exhausted')) {
      return AiRequestException.http(429);
    }
    if (hasCode(403) || hasCode(401) || message.contains('permission_denied') ||
        message.contains('app check') || message.contains('appcheck') ||
        message.contains('unauthenticated')) {
      return const AiRequestException(
        'vertex_access_denied',
        'تحقق من إعداد Firebase AI Logic وصلاحيات Vertex وApp Check.',
      );
    }
    if (hasCode(404) || message.contains('not_found')) {
      return AiRequestException.http(404);
    }
    return const AiRequestException(
      'vertex_request_failed',
      'تعذر إتمام الطلب عبر Vertex. تحقق من إعدادات الخدمة والشبكة.',
    );
  }

  Future<Map<String, dynamic>> generate({
    required String prompt,
    List<Map<String, String>>? history,
    List<Uint8List> images = const [],
    String? systemPersona,
    bool isModificationMode = false,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    if (!await isAllowed()) return failure(disabled);
    try {
      final persona = systemPersona ?? AIConstants.systemPersona;
      final system = isModificationMode
          ? '$persona\n\n${AIConstants.modificationRules}'
          : persona;
      final model = FirebaseAI.agentPlatform(location: 'global').generativeModel(
        model: modelName,
        systemInstruction: Content.system(system),
        generationConfig: GenerationConfig(
          maxOutputTokens: maxTokens.clamp(1, 2048).toInt(),
          temperature: temperature.clamp(0.0, 1.0).toDouble(),
        ),
      );
      final context = <Content>[];
      for (final h in history ?? const <Map<String, String>>[]) {
        final text = (h['content'] ?? h['text'] ?? '').trim();
        if (text.isEmpty) continue;
        final role = h['role'] == 'assistant' || h['role'] == 'model'
            ? 'model' : 'user';
        context.add(Content(role, [TextPart(text)]));
      }
      final parts = <Part>[TextPart(prompt)];
      for (final bytes in images) {
        final mime = visionImageMimeType(bytes);
        if (mime == null) {
          return failure(const AiRequestException(
            'unsupported_media', 'صيغة الصورة غير مدعومة في Vertex.',
          ));
        }
        parts.add(InlineDataPart(mime, bytes));
      }
      final response = await model.generateContent([
        ...context,
        Content.multi(parts),
      ]);
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) return failure(AiRequestException.invalidResponse);
      return {
        'success': true,
        'data': text,
        'meta': {'provider': backend, 'model': modelName, 'status': 'active'},
      };
    } catch (error) {
      return failure(classify(error));
    }
  }
}
