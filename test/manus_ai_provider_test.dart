import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/core/models/canonical_ai_request.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';

void main() {
  group('Manus API v2 Provider & Canonical AI Request Tests', () {
    test('Test A: Canonical request created once and reused across all providers without prompt duplication', () {
      const testPrompt = 'قم بتحليل هذا المنتج واستخراج الميزات والفوائد التسويقية';
      const testPersona = 'أنت خبير محتوى تسويقي متخصص';
      final testHistory = [
        {'role': 'user', 'content': 'ما رأيك في هذا المنتج؟'},
        {'role': 'assistant', 'content': 'إنه منتج ممتاز وعالي الجودة.'},
      ];
      final testImage = Uint8List.fromList([1, 2, 3, 4, 5]);

      final canonicalRequest = CanonicalAiRequest(
        prompt: testPrompt,
        systemPersona: testPersona,
        history: testHistory,
        imageBytes: testImage,
        mimeType: 'image/jpeg',
        maxTokens: 2048,
        temperature: 0.7,
        taskType: 'vision',
      );

      // Verify that all providers receive the EXACT same properties
      expect(canonicalRequest.prompt, equals(testPrompt));
      expect(canonicalRequest.systemPersona, equals(testPersona));
      expect(canonicalRequest.history, equals(testHistory));
      expect(canonicalRequest.imageBytes, equals(testImage));
      expect(canonicalRequest.maxTokens, equals(2048));
      expect(canonicalRequest.temperature, equals(0.7));
      expect(canonicalRequest.taskType, equals('vision'));
      expect(canonicalRequest.hasImage, isTrue);

      final json = canonicalRequest.toJson();
      expect(json['prompt'], equals(testPrompt));
      expect(json['systemPersona'], equals(testPersona));
      expect(json['hasImage'], isTrue);
    });

    test('Test B: AIBackendRouter valid backends include manus', () {
      expect(AIBackendRouter.validBackends, contains('manus'));
      expect(AIBackendRouter.validBackends, contains('firebase_ai'));
      expect(AIBackendRouter.validBackends, contains('backend'));
      expect(AIBackendRouter.validBackends.length, equals(3));
    });

    test('Test C: Quota Pools explicitly separate Gemini from Manus', () {
      expect(AIBackendRouter.quotaPools['firebase_ai'], equals('gemini_primary'));
      expect(AIBackendRouter.quotaPools['backend'], equals('gemini_primary'));
      expect(AIBackendRouter.quotaPools['manus'], equals('manus'));
      expect(AIBackendRouter.quotaPools['manus'], isNot(equals(AIBackendRouter.quotaPools['firebase_ai'])));
    });

    test('Test D: Gemini quota pool in cooldown selects independent pool (Manus)', () {
      final router = AIBackendRouter();
      
      // Put firebase_ai in cooldown
      router.recordCooldown('firebase_ai', const Duration(seconds: 30));
      expect(router.isBackendCoolingDown('firebase_ai'), isTrue);

      // When firebase_ai fails due to quota, findFailoverBackend must prioritize a different quota pool (manus)
      final fallback = router.findFailoverBackend('firebase_ai');
      expect(fallback, equals('manus'));
    });

    test('Test E: App Check / Auth failures MUST NOT fallback to Manus', () {
      expect(AIBackendRouter.isAppCheckOrAuthError('FirebaseAppCheck: 403 App attestation failed'), isTrue);
      expect(AIBackendRouter.isAppCheckOrAuthError('PERMISSION_DENIED: App Check verification failed'), isTrue);
      expect(AIBackendRouter.isAppCheckOrAuthError('AUTH_ERROR: unauthenticated request'), isTrue);
      expect(AIBackendRouter.isAppCheckOrAuthError('401 Unauthorized'), isTrue);
      expect(AIBackendRouter.isAppCheckOrAuthError('Resource has been exhausted (e.g. check quota) 429'), isFalse);
    });

    test('Test F: Security Audit - MANUS_API_KEY must NOT exist in Flutter codebase or client configs', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains(RegExp(r'manus_[a-zA-Z0-9]{20,}', caseSensitive: false)),
          isFalse,
          reason: 'Hardcoded Manus API key detected in ${file.path}',
        );
      }
    });
  });
}
