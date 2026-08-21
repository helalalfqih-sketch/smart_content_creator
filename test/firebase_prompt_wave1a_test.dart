import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/core/constants/firebase_prompt_template_ids.dart';
import 'package:smart_content_creator/ai/core/ai_constants.dart';
import 'package:smart_content_creator/services/firebase_ai_logic_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';

void main() {
  group('Wave 1A: Template Registry Tests', () {
    test('FirebasePromptTemplateIds contains correct canonical identifiers', () {
      expect(
        FirebasePromptTemplateIds.systemPersonaDefault,
        equals('system_persona_default'),
      );
      expect(
        FirebasePromptTemplateIds.modificationRulesDefault,
        equals('modification_rules_default'),
      );
      expect(
        FirebasePromptTemplateIds.systemPersonaModification,
        equals('system_persona_modification'),
      );
    });
  });

  group('Wave 1A: Legacy Prompts Preservation', () {
    test('AIConstants.systemPersona is preserved verbatim', () {
      expect(AIConstants.systemPersona, contains('أنت خبير في صناعة المحتوى'));
      expect(AIConstants.systemPersona, contains('ممنوع الدردشة الجانبية'));
      expect(AIConstants.systemPersona, contains('ممنوع المقدمات والتعريف بالنفس'));
    });

    test('AIConstants.modificationRules is preserved verbatim', () {
      expect(
        AIConstants.modificationRules,
        contains('MODIFICATION MODE RULES (Highest Priority):'),
      );
      expect(
        AIConstants.modificationRules,
        contains('Output ONLY the final content.'),
      );
      expect(
        AIConstants.modificationRules,
        contains('Do not mention that this is a modification'),
      );
    });
  });

  group('Wave 1A: Switch useCloudPromptTemplates = false (Local Fallback Behavior)', () {
    late FirebaseAiLogicService service;

    setUp(() {
      service = FirebaseAiLogicService();
      FirebaseAiLogicService.useCloudPromptTemplates = false;
    });

    test('Template resolution returns null when switch is false', () {
      expect(
        FirebaseAiLogicService.resolveCloudTemplateId(isModificationMode: false),
        isNull,
      );
      expect(
        FirebaseAiLogicService.resolveCloudTemplateId(isModificationMode: true),
        isNull,
      );
    });

    test('Normal mode uses local systemPersona without modification rules', () {
      final resolved = service.resolveSystemInstruction(
        isModificationMode: false,
      );

      expect(resolved, contains('أنت خبير في صناعة المحتوى'));
      expect(
        resolved.contains('MODIFICATION MODE RULES'),
        isFalse,
        reason: 'Normal chat MUST NOT receive modification rules',
      );
    });

    test('Modification mode uses local systemPersona + modificationRules', () {
      final resolved = service.resolveSystemInstruction(
        isModificationMode: true,
      );

      expect(resolved, contains('أنت خبير في صناعة المحتوى'));
      expect(
        resolved,
        contains('MODIFICATION MODE RULES (Highest Priority):'),
        reason: 'Modification mode MUST include modification rules',
      );
    });

    test('Custom persona is respected in local normal and modification modes', () {
      const custom = 'You are a Custom Marketing Director';

      final normalResolved = service.resolveSystemInstruction(
        customPersona: custom,
        isModificationMode: false,
      );
      expect(normalResolved, equals(custom));
      expect(normalResolved.contains('MODIFICATION MODE RULES'), isFalse);

      final modResolved = service.resolveSystemInstruction(
        customPersona: custom,
        isModificationMode: true,
      );
      expect(modResolved, startsWith(custom));
      expect(modResolved, contains('MODIFICATION MODE RULES'));
    });
  });

  group('Wave 1A: Switch useCloudPromptTemplates = true (Cloud Template Routing)', () {
    setUp(() {
      FirebaseAiLogicService.useCloudPromptTemplates = true;
    });

    tearDown(() {
      FirebaseAiLogicService.useCloudPromptTemplates = false;
    });

    test('Normal mode selects system_persona_default template ID', () {
      final templateId = FirebaseAiLogicService.resolveCloudTemplateId(
        isModificationMode: false,
      );
      expect(
        templateId,
        equals(FirebasePromptTemplateIds.systemPersonaDefault),
      );
      expect(templateId, equals('system_persona_default'));
    });

    test('Modification mode selects system_persona_modification template ID', () {
      final templateId = FirebaseAiLogicService.resolveCloudTemplateId(
        isModificationMode: true,
      );
      expect(
        templateId,
        equals(FirebasePromptTemplateIds.systemPersonaModification),
      );
      expect(templateId, equals('system_persona_modification'));
    });

    test('Combined modification template text matches exact concatenation', () {
      final expectedCombined =
          "${AIConstants.systemPersona}\n\n${AIConstants.modificationRules}";
      expect(expectedCombined, contains(AIConstants.systemPersona.trim()));
      expect(expectedCombined, contains(AIConstants.modificationRules.trim()));
      expect(
        expectedCombined,
        equals("${AIConstants.systemPersona}\n\n${AIConstants.modificationRules}"),
      );
    });
  });

  group('Wave 1A: AIBackendRouter Route & Backend Isolation', () {
    test('AIBackendRouter defines valid independent backends', () {
      expect(AIBackendRouter.validBackends, contains('firebase_ai'));
      expect(AIBackendRouter.validBackends, contains('backend'));
      expect(AIBackendRouter.defaultBackend, equals('firebase_ai'));
    });

    test('Backend route is unaffected by Firebase template configuration', () {
      // Back4App / backend route is separate and never invokes Firebase template models
      expect(AIBackendRouter.validBackends.length, equals(2));
      expect(AIBackendRouter.validBackends[1], equals('backend'));
    });
  });
}
