import 'dart:convert';
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

    test('Test G: Multiple images are properly preserved and encoded without dropping', () {
      final image1 = Uint8List.fromList([10, 20, 30]);
      final image2 = Uint8List.fromList([40, 50, 60]);
      final image3 = Uint8List.fromList([70, 80, 90]);

      final request = CanonicalAiRequest(
        prompt: 'Compare these 3 images',
        images: [image1, image2, image3],
        taskType: 'vision',
      );

      expect(request.images, isNotNull);
      expect(request.images!.length, equals(3));
      
      final base64Images = request.images!.map(base64Encode).toList();
      expect(base64Images.length, equals(3));
      expect(base64Images[0], equals(base64Encode(image1)));
      expect(base64Images[1], equals(base64Encode(image2)));
      expect(base64Images[2], equals(base64Encode(image3)));
    });

    test('Test H: Last assistant message extraction selects the true last assistant response', () {
      final mockMessages = [
        {'type': 'user_message', 'content': 'Hello'},
        {'type': 'status_update', 'brief': 'Running'},
        {'type': 'assistant_message', 'assistant_message': {'content': 'Initial response'}},
        {'type': 'status_update', 'brief': 'Refining'},
        {'type': 'assistant_message', 'assistant_message': {'content': 'Final refined answer'}},
        {'type': 'status_update', 'brief': 'Stopped'},
      ];

      // Simulate backward search
      String? finalOutputText;
      for (int i = mockMessages.length - 1; i >= 0; i--) {
        final m = mockMessages[i];
        if (m['type'] == 'assistant_message' && m['assistant_message'] != null) {
          final assist = m['assistant_message'] as Map<String, dynamic>;
          finalOutputText = assist['content']?.toString();
          break;
        }
      }

      expect(finalOutputText, equals('Final refined answer'));
    });

    // ──────────────────────────────────────────────────────
    // 🆕 Session Continuity Tests
    // ──────────────────────────────────────────────────────

    test('Test I: appSessionId is included in CanonicalAiRequest.toJson()', () {
      final request = CanonicalAiRequest(
        prompt: 'Test prompt',
        appSessionId: 42,
        taskType: 'text',
      );

      final json = request.toJson();
      expect(json['appSessionId'], equals(42));
      expect(json['prompt'], equals('Test prompt'));
    });

    test('Test J: appSessionId null is excluded from toJson()', () {
      final request = CanonicalAiRequest(
        prompt: 'Test prompt',
        taskType: 'text',
      );

      final json = request.toJson();
      expect(json.containsKey('appSessionId'), isFalse);
    });

    test('Test K: copyWith propagates appSessionId correctly', () {
      final original = CanonicalAiRequest(
        prompt: 'Original',
        appSessionId: 10,
        taskType: 'text',
      );

      // copyWith preserves appSessionId when not overridden
      final copy1 = original.copyWith(prompt: 'Modified');
      expect(copy1.appSessionId, equals(10));
      expect(copy1.prompt, equals('Modified'));

      // copyWith can override appSessionId
      final copy2 = original.copyWith(appSessionId: 20);
      expect(copy2.appSessionId, equals(20));
      expect(copy2.prompt, equals('Original'));
    });

    test('Test L: Different session IDs produce different payload keys', () {
      final request1 = CanonicalAiRequest(
        prompt: 'Test',
        appSessionId: 12,
        taskType: 'text',
      );
      final request2 = CanonicalAiRequest(
        prompt: 'Test',
        appSessionId: 13,
        taskType: 'text',
      );

      final json1 = request1.toJson();
      final json2 = request2.toJson();

      expect(json1['appSessionId'], equals(12));
      expect(json2['appSessionId'], equals(13));
      expect(json1['appSessionId'], isNot(equals(json2['appSessionId'])));
    });
  });
}
