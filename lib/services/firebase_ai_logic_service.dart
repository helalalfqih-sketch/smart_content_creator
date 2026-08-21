// ignore_for_file: experimental_member_use

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../ai/core/ai_constants.dart';
import '../core/constants/firebase_prompt_template_ids.dart';

/// 🟣 خدمة Firebase AI Logic المستقلة
/// تتصل مباشرة مع Google Gemini عبر Firebase AI Logic SDK الرسمي.
/// تدعم كلاً من النماذج المباشرة مع تعليمات النظام (System Instructions)
/// واستدعاء قوالب البرومبت السحابية (Firebase Prompt Templates).
/// لا تحتوي على أي مفاتيح API - Firebase يتولى المصادقة والحماية تلقائياً.
class FirebaseAiLogicService extends GetxService {
  GenerativeModel? _defaultModelInstance;
  TemplateGenerativeModel? _templateModelInstance;
  ChatSession? _chatSession;

  static const String _defaultModel = 'gemini-3.6-flash';

  /// ⚙️ مفتاح تفعيل استدعاء قوالب البرومبت السحابية (Wave 1A)
  /// - `false`: الحفاظ على السلوك المحلي الحالي (System Instructions محلية عبر GenerativeModel)
  /// - `true`: تفعيل القوالب السحابية (system_persona_default للوضع العادي و system_persona_modification لوضع التعديل)
  static bool useCloudPromptTemplates = false;

  /// 🔀 تحديد معرف قالب البرومبت السحابي المناسب
  static String? resolveCloudTemplateId({
    bool isModificationMode = false,
    bool? useCloudTemplates,
  }) {
    final active = useCloudTemplates ?? useCloudPromptTemplates;
    if (!active) return null;
    return isModificationMode
        ? FirebasePromptTemplateIds.systemPersonaModification
        : FirebasePromptTemplateIds.systemPersonaDefault;
  }

  /// 🎯 بناء تعليمات النظام المحلية (Local System Instruction Resolution)
  /// يطبق `systemPersona` كقاعدة عامة،
  /// ويضيف `modificationRules` فقط عندما يكون `isModificationMode == true`.
  String resolveSystemInstruction({
    String? customPersona,
    bool isModificationMode = false,
  }) {
    final basePersona = customPersona ?? AIConstants.systemPersona;
    if (isModificationMode) {
      return "$basePersona\n\n${AIConstants.modificationRules}";
    }
    return basePersona;
  }

  /// تهيئة نموذج Gemini المباشر مع تعليمات النظام المحددة
  GenerativeModel _getModel({
    String? customPersona,
    bool isModificationMode = false,
    int? maxTokens,
    double? temperature,
  }) {
    final systemText = resolveSystemInstruction(
      customPersona: customPersona,
      isModificationMode: isModificationMode,
    );

    // إذا لم يكن هناك تخصيص، نستخدم النسخة الافتراضية المخزنة
    if (customPersona == null &&
        !isModificationMode &&
        maxTokens == null &&
        temperature == null &&
        _defaultModelInstance != null) {
      return _defaultModelInstance!;
    }

    final model = FirebaseAI.googleAI().generativeModel(
      model: _defaultModel,
      systemInstruction: Content.system(systemText),
      generationConfig: (maxTokens != null || temperature != null)
          ? GenerationConfig(
              maxOutputTokens: maxTokens,
              temperature: temperature,
            )
          : null,
    );

    if (customPersona == null &&
        !isModificationMode &&
        maxTokens == null &&
        temperature == null) {
      _defaultModelInstance = model;
    }

    return model;
  }

  /// ☁️ تهيئة نموذج القوالب السحابية (Template Generative Model)
  TemplateGenerativeModel _getTemplateModel() {
    _templateModelInstance ??=
        FirebaseAI.googleAI().templateGenerativeModel();
    return _templateModelInstance!;
  }

  /// 💬 توليد نص من برومبت نصي أو عبر قالب (Text / Template Generation)
  Future<Map<String, dynamic>> generateText({
    required String prompt,
    List<Map<String, String>>? history,
    int? maxTokens,
    double? temperature,
    bool isModificationMode = false,
    String? systemPersona,
    String? templateId,
    Map<String, Object?>? templateInputs,
  }) async {
    try {
      // تحديد معرف القالب السحابي: إما الممرر صراحة، أو المحدد عبر switch التفعيل
      final effectiveTemplateId = templateId ??
          resolveCloudTemplateId(isModificationMode: isModificationMode);

      // 🚀 المسار 1: استدعاء عبر قالب Firebase Prompt Template إذا تم تحديد templateId
      if (effectiveTemplateId != null && effectiveTemplateId.isNotEmpty) {
        return await generateFromTemplate(
          templateId: effectiveTemplateId,
          inputs: templateInputs ?? (prompt.isNotEmpty ? {'input': prompt} : const {}),
          history: history,
        );
      }

      // 🎯 المسار 2: توليد مباشر عبر GenerativeModel مع تعليمات النظام المحسوبة
      final model = _getModel(
        customPersona: systemPersona,
        isModificationMode: isModificationMode,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      // إذا كان هناك محفوظات، استخدم ChatSession
      if (history != null && history.isNotEmpty) {
        _chatSession = model.startChat(
          history: history.map((h) {
            return Content(h['role'] ?? 'user', [TextPart(h['text'] ?? '')]);
          }).toList(),
        );

        final response = await _chatSession!.sendMessage(
          Content.text(prompt),
        );

        final text = response.text ?? '';
        return {
          'success': true,
          'data': text,
          'meta': {
            'provider': 'firebase_ai_logic',
            'model': _defaultModel,
            'status': 'active',
            'is_modification_mode': isModificationMode,
          },
        };
      }

      // طلب مستقل بدون محفوظات
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text ?? '';
      return {
        'success': true,
        'data': text,
        'meta': {
          'provider': 'firebase_ai_logic',
          'model': _defaultModel,
          'status': 'active',
          'is_modification_mode': isModificationMode,
        },
      };
    } catch (e) {
      debugPrint('❌ [FIREBASE_AI] Text Error details: $e');
      return {
        'success': false,
        'error': e.toString(),
        'meta': {
          'provider': 'firebase_ai_logic',
          'model': _defaultModel,
          'status': 'error',
        },
      };
    }
  }

  /// ☁️ توليد محتوى من قالب سحابي مسجل في Firebase AI Logic (Prompt Templates)
  Future<Map<String, dynamic>> generateFromTemplate({
    required String templateId,
    Map<String, Object?> inputs = const {},
    List<Map<String, String>>? history,
  }) async {
    try {
      final templateModel = _getTemplateModel();

      GenerateContentResponse response;

      if (history != null && history.isNotEmpty) {
        final historyContent = history.map((h) {
          return Content(h['role'] ?? 'user', [TextPart(h['text'] ?? '')]);
        }).toList();

        response = await templateModel.templateGenerateContentWithHistory(
          historyContent,
          templateId,
          inputs: inputs,
        );
      } else {
        response = await templateModel.generateContent(
          templateId,
          inputs: inputs,
        );
      }

      final text = response.text ?? '';
      return {
        'success': true,
        'data': text,
        'meta': {
          'provider': 'firebase_ai_template',
          'template_id': templateId,
          'status': 'active',
        },
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FirebaseAiLogicService.generateFromTemplate Error [$templateId]: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'meta': {
          'provider': 'firebase_ai_template',
          'template_id': templateId,
          'status': 'error',
        },
      };
    }
  }

  /// 📸 تحليل صورة منتج بالذكاء الاصطناعي (Vision)
  Future<Map<String, dynamic>> analyzeProductVision({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final model = _getModel();

      final response = await model.generateContent([
        Content.multi([
          InlineDataPart(mimeType, imageBytes),
          TextPart(prompt),
        ]),
      ]);

      final text = response.text ?? '';
      return {
        'success': true,
        'data': text,
        'meta': {
          'provider': 'firebase_ai_logic',
          'model': _defaultModel,
          'status': 'active',
        },
      };
    } catch (e) {
      debugPrint('❌ [FIREBASE_AI] Error details: $e');
      return {
        'success': false,
        'error': e.toString(),
        'meta': {
          'provider': 'firebase_ai_logic',
          'model': _defaultModel,
          'status': 'error',
        },
      };
    }
  }

  /// 🔄 إعادة تعيين جلسة المحادثة
  void resetChatSession() {
    _chatSession = null;
  }
}
