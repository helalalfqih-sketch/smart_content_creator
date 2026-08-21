import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/firebase_ai_logic_service.dart';
import 'package:smart_content_creator/services/back4app_gateway_service.dart';
import 'package:smart_content_creator/core/models/api_provider.dart';

class MockFirebaseAiLogicService extends FirebaseAiLogicService {
  bool generateTextCalled = false;
  bool analyzeProductVisionCalled = false;
  String lastPrompt = '';
  Uint8List? lastImageBytes;

  @override
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
    generateTextCalled = true;
    lastPrompt = prompt;
    return {
      'success': true,
      'data': 'Response from Firebase AI Logic',
      'meta': {'provider': 'firebase_ai_logic', 'status': 'active'},
    };
  }

  @override
  Future<Map<String, dynamic>> analyzeProductVision({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    analyzeProductVisionCalled = true;
    lastPrompt = prompt;
    lastImageBytes = imageBytes;
    return {
      'success': true,
      'data': '{"name": "Smart Watch", "category": "Electronics"}',
      'meta': {'provider': 'firebase_ai_logic', 'status': 'active'},
    };
  }
}

class MockBack4AppGatewayService extends Back4AppGatewayService {
  bool generateTextWithVertexCalled = false;
  String lastPrompt = '';
  String? lastImage;

  @override
  Future<AiResult> generateTextWithVertex(
    String prompt, {
    List<Map<String, String>>? history,
    String? image,
    String? mimeType,
    int maxTokens = 2048,
    double temperature = 0.7,
    String model = 'gemini-2.5-flash',
  }) async {
    generateTextWithVertexCalled = true;
    lastPrompt = prompt;
    lastImage = image;
    return AiResult(
      description: 'Response from Back4App Vertex',
      provider: 'back4app',
    );
  }
}

class TestableAIBackendRouter extends AIBackendRouter {
  String testBackend = 'firebase_ai';

  @override
  Future<String> resolveBackend() async {
    return testBackend;
  }
}

void main() {
  group('AIBackendRouter Contract & Configuration Tests', () {
    test('Default backend should be firebase_ai', () {
      expect(AIBackendRouter.defaultBackend, equals('firebase_ai'));
    });

    test('Valid backends must contain firebase_ai, backend, and manus', () {
      expect(AIBackendRouter.validBackends, contains('firebase_ai'));
      expect(AIBackendRouter.validBackends, contains('backend'));
      expect(AIBackendRouter.validBackends, contains('manus'));
      expect(AIBackendRouter.validBackends.length, equals(3));
    });
  });

  group('AIBackendRouter Routing Verification (Tests A to E)', () {
    late TestableAIBackendRouter router;
    late MockFirebaseAiLogicService mockFirebase;
    late MockBack4AppGatewayService mockBack4App;

    setUp(() {
      Get.reset();
      mockFirebase = MockFirebaseAiLogicService();
      mockBack4App = MockBack4AppGatewayService();

      Get.put<FirebaseAiLogicService>(mockFirebase);
      Get.put<Back4AppGatewayService>(mockBack4App);

      router = TestableAIBackendRouter();
      Get.put<AIBackendRouter>(router);
    });

    tearDown(() {
      Get.reset();
    });

    test(
        'Test A: user.ai_backend = firebase_ai text request routes to FirebaseAiLogicService and NOT Back4App',
        () async {
      router.testBackend = 'firebase_ai';

      final res =
          await router.generateText(prompt: 'Write a caption for treadmill');

      expect(res['success'], isTrue);
      expect(res['data'], equals('Response from Firebase AI Logic'));
      expect(mockFirebase.generateTextCalled, isTrue);
      expect(mockFirebase.lastPrompt, equals('Write a caption for treadmill'));
      expect(mockBack4App.generateTextWithVertexCalled, isFalse);
    });

    test(
        'Test B: user.ai_backend = firebase_ai image request routes to FirebaseAiLogicService multimodal and NOT Back4App',
        () async {
      router.testBackend = 'firebase_ai';
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final res = await router.analyzeProductVision(
        prompt: 'Analyze this product',
        imageBytes: dummyBytes,
      );

      expect(res['success'], isTrue);
      expect(res['data'], contains('Smart Watch'));
      expect(mockFirebase.analyzeProductVisionCalled, isTrue);
      expect(mockFirebase.lastImageBytes, equals(dummyBytes));
      expect(mockBack4App.generateTextWithVertexCalled, isFalse);
    });

    test('Test C: user.ai_backend = backend text request routes to Back4App',
        () async {
      router.testBackend = 'backend';

      final res =
          await router.generateText(prompt: 'Write a caption for shoes');

      expect(res['success'], isTrue);
      expect(res['data'], equals('Response from Back4App Vertex'));
      expect(mockBack4App.generateTextWithVertexCalled, isTrue);
      expect(mockBack4App.lastPrompt, equals('Write a caption for shoes'));
      expect(mockFirebase.generateTextCalled, isFalse);
    });

    test(
        'Test D: user.ai_backend = backend image request routes to Back4App vision',
        () async {
      router.testBackend = 'backend';
      final dummyBytes = Uint8List.fromList([10, 20, 30]);

      final res = await router.analyzeProductVision(
        prompt: 'Analyze this product on backend',
        imageBytes: dummyBytes,
      );

      expect(res['success'], isTrue);
      expect(res['data'], equals('Response from Back4App Vertex'));
      expect(mockBack4App.generateTextWithVertexCalled, isTrue);
      expect(mockBack4App.lastImage, isNotNull);
      expect(mockFirebase.analyzeProductVisionCalled, isFalse);
    });

    test(
        'Test E: changing ai_backend dynamically takes effect immediately without restart',
        () async {
      // 1. Initial request in firebase_ai mode
      router.testBackend = 'firebase_ai';
      await router.generateText(prompt: 'Prompt 1');
      expect(mockFirebase.generateTextCalled, isTrue);
      expect(mockBack4App.generateTextWithVertexCalled, isFalse);

      // Reset flags
      mockFirebase.generateTextCalled = false;
      mockBack4App.generateTextWithVertexCalled = false;

      // 2. Switch mode to backend in Firestore / state
      router.testBackend = 'backend';
      await router.generateText(prompt: 'Prompt 2');
      expect(mockBack4App.generateTextWithVertexCalled, isTrue);
      expect(mockFirebase.generateTextCalled, isFalse);

      // 3. Switch back to firebase_ai
      mockFirebase.generateTextCalled = false;
      mockBack4App.generateTextWithVertexCalled = false;

      router.testBackend = 'firebase_ai';
      await router.generateText(prompt: 'Prompt 3');
      expect(mockFirebase.generateTextCalled, isTrue);
      expect(mockBack4App.generateTextWithVertexCalled, isFalse);
    });
  });

  group('AIBackendRouter Rate Limit, Cooldown & Backoff Tests', () {
    test('parseRetryDuration correctly parses various error formats', () {
      final d1 = AIBackendRouter.parseRetryDuration(
          'Quota exceeded. Please retry in 30.61511719s.');
      expect(d1.inSeconds, equals(31));

      final d2 = AIBackendRouter.parseRetryDuration(
          'Exception: Back4App (429): Please retry in 6.66s.');
      expect(d2.inSeconds, equals(7));

      final d3 = AIBackendRouter.parseRetryDuration(
          'Resource exhausted. wait 20 seconds');
      expect(d3.inSeconds, equals(20));

      final d4 = AIBackendRouter.parseRetryDuration('Unknown rate error');
      expect(d4.inSeconds, equals(15));
    });

    test('isRateLimitError identifies 429 and quota errors', () {
      expect(
          AIBackendRouter.isRateLimitError('429: Too Many Requests'), isTrue);
      expect(AIBackendRouter.isRateLimitError('Quota exceeded for metric'),
          isTrue);
      expect(AIBackendRouter.isRateLimitError('Too many attempts.'), isTrue);
      expect(AIBackendRouter.isRateLimitError('RESOURCE_EXHAUSTED'), isTrue);
      expect(
          AIBackendRouter.isRateLimitError('Normal server error 500'), isFalse);
      expect(AIBackendRouter.isRateLimitError(null), isFalse);
    });

    test('recordCooldown correctly sets and releases cooldown timer', () {
      final testRouter = AIBackendRouter();
      expect(testRouter.isBackendCoolingDown('firebase_ai'), isFalse);
      expect(testRouter.remainingCooldownSeconds('firebase_ai'), equals(0));

      testRouter.recordCooldown('firebase_ai', const Duration(seconds: 10));
      expect(testRouter.isBackendCoolingDown('firebase_ai'), isTrue);
      expect(testRouter.remainingCooldownSeconds('firebase_ai'),
          inInclusiveRange(8, 11));
    });
  });
}
