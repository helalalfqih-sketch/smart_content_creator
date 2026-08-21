import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Backend Routing Integration Tests', () {
    testWidgets('Requirement A: New user defaults to firebase_ai',
        (WidgetTester tester) async {
      expect(AIBackendRouter.defaultBackend, equals('firebase_ai'));
      expect(AIBackendRouter.validBackends.contains('firebase_ai'), isTrue);
    });

    testWidgets('Requirement B & C: Valid backends include firebase_ai and backend',
        (WidgetTester tester) async {
      final backends = AIBackendRouter.validBackends;
      expect(backends, contains('firebase_ai'));
      expect(backends, contains('backend'));
      expect(backends.length, equals(2));
    });

    testWidgets('Requirement D: Unauthorized/Invalid backend values are rejected',
        (WidgetTester tester) async {
      final invalidValues = ['direct_gemini', 'custom_key', 'unauthorized_api', ''];
      for (final val in invalidValues) {
        expect(AIBackendRouter.validBackends.contains(val), isFalse);
      }
    });
  });
}
