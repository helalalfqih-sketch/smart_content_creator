import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/core/utils/ai_request_exception.dart';
import 'package:smart_content_creator/core/models/api_provider.dart';
import 'package:smart_content_creator/services/serpapi_gateway_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/ai_provider.dart';
import 'package:smart_content_creator/services/serpapi_services.dart';

class LensTestGateway extends SerpApiGatewayService {
  LensTestGateway({super.client, super.tokenReader, super.imagePreparer});
  @override
  void onInit() {} // Tests provide their identity reader; no live Firebase session.
}

class GatewayWire implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  GatewayWire(this.respond);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    requests.add(options);
    return respond(options);
  }
  @override
  void close({bool force = false}) {}
}

class SearchProvider extends Fake implements AIProvider {
  int calls = 0;
  String? receivedKey;
  bool fail = false;
  @override
  Future<AiResult> generateText(String prompt,
      {required String apiKey, List<Map<String, String>>? history,
      int? maxTokens, String? systemPersona, CancelToken? cancelToken,
      String? customEndpoint}) async {
    calls++;
    receivedKey = apiKey;
    if (fail) throw const AiRequestException('http_429', '429 retry in 1s');
    return AiResult(description: 'A sourced search answer', provider: 'SerpApi');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ResponseBody body(Object value, int status) => ResponseBody.fromString(
      jsonEncode(value), status, headers: {'content-type': ['application/json']});

  test('connect verifies account without searching; searches use fresh Firebase tokens and no provider key', () async {
    var issuedTokens = 0;
    final wire = GatewayWire((request) => request.method == 'GET'
        ? body({'status': 'authorized', 'engine': 'google_ai_mode', 'limits': {'hourly': 10, 'daily': 50}}, 200)
        : body({'reconstructed_markdown': 'A real response shape'}, 200));
    final service = SerpApiGatewayService(client: Dio()..httpClientAdapter = wire,
        tokenReader: () async => 'firebase-token-${++issuedTokens}');
    expect(await service.connect(), isTrue);
    expect(wire.requests.single.uri.path, '/serpapi/mobile/status');
    expect(wire.requests.single.data, isNull);
    expect((await service.search('coffee'))['reconstructed_markdown'], 'A real response shape');
    expect(wire.requests.length, 2);
    final request = wire.requests.last;
    expect(request.uri.origin, 'https://waha.indexesstore.com');
    expect(request.uri.query, isEmpty);
    expect(request.headers['Authorization'], 'Bearer firebase-token-2');
    expect(request.data, {'q': 'coffee', 'hl': 'ar'});
    expect(request.followRedirects, isFalse);
  });

  test('missing identity and invalid query make no network request', () async {
    final wire = GatewayWire((_) => throw StateError('Network must not run'));
    final service = SerpApiGatewayService(client: Dio()..httpClientAdapter = wire,
        tokenReader: () async => null);
    expect(await service.connect(), isFalse);
    await expectLater(service.search('coffee'), throwsA(isA<AiRequestException>()));
    await expectLater(service.search('x' * 4001), throwsA(isA<AiRequestException>()));
    expect(wire.requests, isEmpty);
  });

  test('forbidden, quota, redirect and provider errors are sanitized and never retried', () async {
    for (final status in [302, 401, 403, 429, 502]) {
      final wire = GatewayWire((_) => body({'error': 'unsafe echo of token or key'}, status));
      final service = SerpApiGatewayService(client: Dio()..httpClientAdapter = wire,
          tokenReader: () async => 'test-only-id-token');
      await expectLater(service.search('coffee'), throwsA(isA<AiRequestException>()
          .having((error) => error.message.contains('unsafe'), 'safe message', isFalse)));
      expect(wire.requests.length, 1);
    }
  });

  test('SerpApi router preserves actual text and does not silently fall back or send images', () async {
    final provider = SearchProvider();
    final router = AIBackendRouter(serpApiService: provider);
    final success = await router.generateText(prompt: 'coffee', backendOverride: 'serpapi');
    expect(success['data'], 'A sourced search answer');
    expect(provider.receivedKey, isEmpty);
    expect(router.findFailoverBackend('serpapi'), isNull);
    final unsupported = await router.generateText(prompt: 'describe', image: 'image-bytes', backendOverride: 'serpapi');
    expect(unsupported['success'], isFalse);
    expect(provider.calls, 1);
    provider.fail = true;
    final failure = await router.generateText(prompt: 'coffee', backendOverride: 'serpapi');
    expect(failure['success'], isFalse);
    expect(provider.calls, 2, reason: 'No retry or paid-provider fallback');
  });

  test('Lens smart tool uses the managed gateway without a personal key or selected chat provider', () async {
    Get.testMode = true;
    addTearDown(Get.reset);
    final bytes = Uint8List.fromList([255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1]);
    final wire = GatewayWire((_) => body({'visual_matches': [{'title': 'Similar product'}]}, 200));
    final gateway = LensTestGateway(client: Dio()..httpClientAdapter = wire,
      tokenReader: () async => 'fresh-firebase-token',
      imagePreparer: (path) async { expect(path, '/phone/image.jpg'); return bytes; });
    // Lazy registration avoids Firebase lifecycle setup; no SettingsController exists.
    Get.lazyPut<SerpApiGatewayService>(() => gateway);
    final result = await GoogleLensService().searchByImage('/phone/image.jpg');
    expect(result['visual_matches'], hasLength(1));
    final request = wire.requests.single;
    expect(request.uri.toString(), 'https://waha.indexesstore.com/serpapi/mobile/lens');
    expect(request.data, {'hl': 'ar', 'image_base64': base64Encode(bytes)});
    expect(request.headers['Authorization'], 'Bearer fresh-firebase-token');
    expect(request.data.toString(), isNot(contains('api_key')));
  });

  test('Lens rejects invalid responses and exposes provider failure instead of empty success', () async {
    for (final response in [body({}, 200), body({'error': 'lens_provider_failed'}, 502)]) {
      final wire = GatewayWire((_) => response);
      final gateway = SerpApiGatewayService(client: Dio()..httpClientAdapter = wire,
        tokenReader: () async => 'fresh-firebase-token');
      await expectLater(gateway.searchLens('https://example.com/image.jpg'), throwsA(isA<AiRequestException>()));
      expect(wire.requests.length, 1);
    }
  });

  test('Lens refuses oversized prepared images and canceled actions without network traffic', () async {
    final wire = GatewayWire((_) => throw StateError('No network expected'));
    final gateway = SerpApiGatewayService(client: Dio()..httpClientAdapter = wire,
      tokenReader: () async => 'fresh-firebase-token', imagePreparer: (_) async => Uint8List(480001));
    await expectLater(gateway.searchLens('/phone/large.jpg'), throwsA(isA<AiRequestException>()));
    final cancelled = CancelToken()..cancel();
    await expectLater(gateway.searchLens('/phone/image.jpg', cancelToken: cancelled), throwsA(isA<AiRequestException>()));
    expect(wire.requests, isEmpty);
  });
}
