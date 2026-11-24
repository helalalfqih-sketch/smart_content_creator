import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/services/ai_provider.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/firebase_ai_logic_service.dart';

class FakeDirectService extends FirebaseAiLogicService {
  bool fail = false;
  int textCalls = 0;
  int visionCalls = 0;

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
    textCalls++;
    return fail
        ? {'success': false, 'error': 'http_402'}
        : {'success': true, 'data': 'mock text'};
  }

  @override
  Future<Map<String, dynamic>> analyzeProductVision({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    visionCalls++;
    return fail
        ? {'success': false, 'error': 'http_402'}
        : {'success': true, 'data': 'mock vision'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabled = bool.fromEnvironment('ENABLE_DIRECT_VERTEX_AI');
  late FakeDirectService fake;

  setUp(() {
    Get.testMode = true;
    fake = FakeDirectService();
    Get.put<FirebaseAiLogicService>(fake);
  });

  tearDown(() async {
    await Get.reset();
  });

  test('Provider identity matches the explicit build setting', () {
    expect(FirebaseAiLogicService.directVertexEnabled, enabled);
    expect(
      FirebaseAiLogicService.providerName,
      enabled ? 'firebase_agent_platform' : 'firebase_ai_logic',
    );
  });

  test('Direct mode routes through Firebase instead of legacy providers', () async {
    expect(await AIBackendRouter().resolveBackend(), 'firebase_ai');
    final text = await AIProviderFactory.generateWithSmartFallback('test');
    final vision = await AIProviderFactory.analyzeWithSmartFallback(
      Uint8List.fromList([1, 2, 3]),
      'test image',
    );
    expect(text.description, 'mock text');
    expect(vision.description, 'mock vision');
    expect(text.provider, 'firebase_agent_platform');
    expect(vision.provider, 'firebase_agent_platform');
    expect(fake.textCalls, 1);
    expect(fake.visionCalls, 1);
  }, skip: !enabled);

  test('Direct mode surfaces 402 without legacy fallback', () async {
    fake.fail = true;
    await expectLater(
      AIProviderFactory.generateWithSmartFallback('test'),
      throwsA(predicate((Object e) => e.toString().contains('http_402'))),
    );
    await expectLater(
      AIProviderFactory.analyzeWithSmartFallback(
        Uint8List.fromList([1, 2, 3]), 'test image',
      ),
      throwsA(predicate((Object e) => e.toString().contains('http_402'))),
    );
    expect(fake.textCalls, 1);
    expect(fake.visionCalls, 1);
  }, skip: !enabled);
}
