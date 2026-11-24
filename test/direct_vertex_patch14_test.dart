import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/direct_vertex_service.dart';

class DisabledVertex extends DirectVertexService {
  @override
  Future<bool> isAllowed() async => false;
}

class FakeVertex extends DirectVertexService {
  bool fail = false;
  int calls = 0;
  int imageCount = 0;

  @override
  Future<bool> isAllowed() async => true;

  @override
  Future<Map<String, dynamic>> generate({
    required String prompt,
    List<Map<String, String>>? history,
    List<Uint8List> images = const [],
    String? systemPersona,
    bool isModificationMode = false,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    calls++;
    imageCount = images.length;
    if (fail) {
      return DirectVertexService.failure(
        DirectVertexService.classify(Exception('HTTP 402')),
      );
    }
    return {
      'success': true, 'data': 'mock response',
      'meta': {'provider': DirectVertexService.backend},
    };
  }
}

class VertexRouter extends AIBackendRouter {
  VertexRouter(DirectVertexService service) : super(directVertexService: service);

  @override
  Future<String> resolveBackend() async => DirectVertexService.backend;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing, disabled or unapproved rollout configuration is closed', () {
    expect(DirectVertexService.permits(null, 'owner'), isFalse);
    expect(DirectVertexService.permits({'enabled': true}, 'owner'), isFalse);
    final config = {'enabled': true, 'allowed_uids': ['owner']};
    expect(DirectVertexService.permits(config, null), isFalse);
    expect(DirectVertexService.permits(config, 'other'), isFalse);
    expect(DirectVertexService.permits(config, 'owner'), isTrue);
  });

  test('global rollout includes new authenticated accounts only when enabled', () {
    final config = <String, dynamic>{
      'enabled': true,
      'allow_all_authenticated': true,
    };
    expect(DirectVertexService.permits(config, 'existing'), isTrue);
    expect(DirectVertexService.permits(config, 'new-account'), isTrue);
    expect(DirectVertexService.permits(config, null), isFalse);
    expect(DirectVertexService.permits(config, ''), isFalse);
    expect(DirectVertexService.permits({...config, 'enabled': false}, 'existing'), isFalse);
    expect(DirectVertexService.permits({'allow_all_authenticated': true}, 'existing'), isFalse);
    expect(DirectVertexService.permits({'enabled': true, 'allow_all_authenticated': 'true'}, 'existing'), isFalse);
    expect(DirectVertexService.permits({'enabled': true, 'allow_all_authenticated': false, 'allowed_uids': ['owner']}, 'owner'), isTrue);
    expect(DirectVertexService.permits({'enabled': true, 'allow_all_authenticated': false, 'allowed_uids': ['owner']}, 'other'), isFalse);
  });

  test('disabled provider does not issue a live request', () async {
    final service = DisabledVertex();
    final router = AIBackendRouter(directVertexService: service);
    expect(await router.switchBackend('vertex_direct'), isFalse);
    final result = await service.generate(prompt: 'hello');
    expect(result['success'], isFalse);
    expect(result['request_failure'].code, 'vertex_disabled');
  });

  test('Vertex direct text and multiple image routing use the new provider', () async {
    final fake = FakeVertex();
    final router = VertexRouter(fake);
    final result = await router.generateText(prompt: 'hello');
    expect(result['meta']['provider'], 'vertex_direct');
    final image = Uint8List.fromList([255, 216, 255, 0]);
    final vision = await router.analyzeProductVision(
      prompt: 'describe', imageBytes: image, additionalImages: [image],
    );
    expect(vision['success'], isTrue);
    expect(fake.calls, 2);
    expect(fake.imageCount, 2);
  });

  test('402 stays a typed billing error with no automatic retry or fallback', () async {
    final fake = FakeVertex()..fail = true;
    final router = VertexRouter(fake);
    final result = await router.generateText(prompt: 'hello');
    expect(result['success'], isFalse);
    expect(result['request_failure'].code, 'http_402');
    expect(fake.calls, 1);
    expect(router.findFailoverBackend('vertex_direct'), isNull);
    expect(DirectVertexService.classify(Exception('429')).code, 'http_429');
    expect(DirectVertexService.classify(Exception('403')).code, 'vertex_access_denied');
  });
}
