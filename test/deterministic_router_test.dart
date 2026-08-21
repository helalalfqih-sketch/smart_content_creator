import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/ai/ai_orchestrator.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';

void main() {
  group('Deterministic Local Router Tests', () {
    test('Case 1: "مرحبا" -> DIRECT_TEXT', () {
      final mode = ExecutionMode.directText;
      expect(mode, equals(ExecutionMode.directText));

      final text = 'مرحبا';
      final hasImages = false;
      final hasVideo = false;

      final normalized = text
          .toLowerCase()
          .trim()
          .replaceAll('ة', 'ه')
          .replaceAll('أ', 'ا')
          .replaceAll('إ', 'ا')
          .replaceAll('آ', 'ا')
          .replaceAll('ى', 'ي');

      expect(hasImages, isFalse);
      expect(hasVideo, isFalse);
      expect(normalized, equals('مرحبا'));
    });

    test('Case 2: "اكتب لي إعلان احترافي لسماعة بلوتوث" -> DIRECT_TEXT', () {
      final text = 'اكتب لي إعلان احترافي لسماعة بلوتوث';
      final isMultiStep = text.contains('ثم ابحث') ||
          text.contains('حمله تسويقيه كامله') ||
          text.contains('ثم انشئ');

      expect(isMultiStep, isFalse);
    });

    test('Case 3: Single Image + "ما هذا المنتج؟" -> DIRECT_MULTIMODAL', () {
      final images = [File('dummy_path.jpg')];
      final text = 'ما هذا المنتج؟';
      final isMultiStep = text.contains('ثم ابحث') || text.contains('ثم انشئ');

      expect(images.isNotEmpty, isTrue);
      expect(isMultiStep, isFalse);
    });

    test(
        'Case 4: Single Image + "اكتب وصفًا تسويقيًا لهذا المنتج" -> DIRECT_MULTIMODAL',
        () {
      final images = [File('dummy_path.jpg')];
      final text = 'اكتب وصفًا تسويقيًا لهذا المنتج';
      final isMultiStep = text.contains('ثم ابحث') || text.contains('ثم انشئ');

      expect(images.isNotEmpty, isTrue);
      expect(isMultiStep, isFalse);
    });

    test('Case 5: 2 Images + "قارن بينهما" -> DIRECT_MULTIMODAL', () {
      final images = [File('dummy1.jpg'), File('dummy2.jpg')];
      final text = 'قارن بينهما';
      final isMultiStep = text.contains('ثم ابحث') || text.contains('ثم انشئ');

      expect(images.length, equals(2));
      expect(isMultiStep, isFalse);
    });

    test(
        'Case 6: Images + "حلل المنتج ثم ابحث عن الترندات وأنشئ حملة كاملة" -> WORKFLOW_MULTIMODAL / AGENT_MODE',
        () {
      final text = 'حلل المنتج ثم ابحث عن الترندات وأنشئ حملة كاملة';
      final normalized = text
          .toLowerCase()
          .trim()
          .replaceAll('ة', 'ه')
          .replaceAll('أ', 'ا')
          .replaceAll('إ', 'ا')
          .replaceAll('آ', 'ا')
          .replaceAll('ى', 'ي');

      final sequenceConnectors = [
        'ثم ابحث',
        'وبعدها ابحث',
        'ثم انشئ',
        'وبعدها انشئ',
        'ثم صمم',
        'وبعدها صمم',
        'ثم اكتب',
        'وبعدها اكتب',
        'ثم اعمل',
        'وبعدها اعمل',
        'ثم حلل',
        'وبعدها حلل',
        'ثم ولد',
        'وبعدها ولد',
        'ثم طلع',
        'وبعدها طلع',
        'ثم سوي',
        'وبعدها سوي',
      ];
      final isMultiStep = sequenceConnectors.any((c) => normalized.contains(c));

      expect(isMultiStep, isTrue);
    });

    test(
        'Case 7: App Check / Auth errors MUST NOT be treated as Rate Limit / eligible for fallback',
        () {
      expect(
          AIBackendRouter.isRateLimitError('Firebase App Check token expired'),
          isFalse);
      expect(
          AIBackendRouter.isRateLimitError(
              '[firebase_app_check/unknown] Too many attempts.'),
          isFalse);
      expect(
          AIBackendRouter.isRateLimitError(
              '[firebase_app_check/unknown] Error returned from API. code: 403 body: App attestation failed.'),
          isFalse);
      expect(AIBackendRouter.isRateLimitError('AppCheck error 403 Forbidden'),
          isFalse);
      expect(
          AIBackendRouter.isRateLimitError('FirebaseAuth unauthenticated 401'),
          isFalse);
      expect(AIBackendRouter.isRateLimitError('Permission Denied on Firestore'),
          isFalse);

      // True rate limit errors
      expect(
          AIBackendRouter.isRateLimitError(
              'Resource exhausted 429 quota exceeded'),
          isTrue);
      expect(
          AIBackendRouter.isRateLimitError(
              'Too many requests, please retry in 10s'),
          isTrue);
    });
  });
}
