import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/services/openai_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/ai/vision_product_service.dart';
import 'package:smart_content_creator/services/firebase_ai_logic_service.dart';

class SelectedRouter extends AIBackendRouter {
  SelectedRouter(OpenAIService service, {String key = 'test-only-key'})
    : super(openRouterService: service, openRouterKeyReader: () => key);
  @override
  Future<String> resolveBackend() async => 'openrouter';
}

class ForbiddenFirebaseVision extends FirebaseAiLogicService {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> analyzeProductVision({
    required String prompt,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    calls++;
    throw StateError('The selected OpenRouter route must not call Firebase');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7l8AAAAASUVORK5CYII=',
  );
  final jpeg = Uint8List.fromList([255, 216, 255, 224, 0, 16, 255, 217]);
  late dio.Dio client;
  late OpenAIService service;
  final requests = <dio.RequestOptions>[];
  dynamic responseData;
  int status = 200;

  Map<String, dynamic> completion(String text) => {
    'choices': [
      {
        'message': {'role': 'assistant', 'content': text},
      },
    ],
  };

  setUp(() {
    Get.testMode = true;
    requests.clear();
    status = 200;
    responseData = completion('Camera with a screen and handheld grip');
    client = dio.Dio();
    client.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            dio.Response(
              requestOptions: options,
              statusCode: status,
              data: responseData,
            ),
          );
        },
      ),
    );
    service = OpenAIService(
      client: client,
      baseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'anthropic/claude-opus-5.5',
      providerOnly: const ['google-vertex'],
      allowProviderFallbacks: false,
    );
  });

  tearDown(() async {
    client.close(force: true);
    await Get.reset();
  });

  test(
    'photo + question contains actual bytes, selected model and provider',
    () async {
      final result = await service.analyzeImage(
        png,
        'What is visible?',
        apiKey: 'test-only-key',
        maxTokens: 700,
        systemPersona: 'Describe visible evidence only.',
        history: [
          {'role': 'assistant', 'content': 'Previous verified description'},
        ],
      );
      final request = requests.single;
      expect(
        request.uri.toString(),
        'https://openrouter.ai/api/v1/chat/completions',
      );
      expect(request.headers['Authorization'], 'Bearer test-only-key');
      expect(request.data['model'], 'anthropic/claude-opus-5.5');
      expect(request.data['provider'], {
        'only': ['google-vertex'],
        'allow_fallbacks': false,
      });
      expect(request.data['max_tokens'], 700);
      final messages = request.data['messages'] as List;
      expect(messages.first['role'], 'system');
      expect(messages[1]['content'], 'Previous verified description');
      final parts = messages.last['content'] as List;
      expect(parts.first, {'type': 'text', 'text': 'What is visible?'});
      final dataUrl = parts[1]['image_url']['url'] as String;
      expect(dataUrl, startsWith('data:image/png;base64,'));
      expect(base64Decode(dataUrl.split(',').last), png);
      expect(result.provider, 'openrouter');
      expect(result.description, contains('Camera'));
    },
  );

  test('multiple images are sent together with their own MIME types', () async {
    await service.analyzeBatchImages(
      [jpeg, png],
      'Compare',
      apiKey: 'test-only-key',
    );
    final parts = requests.single.data['messages'].last['content'] as List;
    expect(parts.length, 3);
    expect(parts[1]['image_url']['url'], startsWith('data:image/jpeg;base64,'));
    expect(parts[2]['image_url']['url'], startsWith('data:image/png;base64,'));
  });

  test('empty or unsupported files fail before making a request', () async {
    for (final invalid in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      await expectLater(
        service.analyzeImage(invalid, 'Describe', apiKey: 'test-only-key'),
        throwsException,
      );
    }
    await expectLater(
      service.analyzeBatchImages([], 'Describe', apiKey: 'test-only-key'),
      throwsException,
    );
    expect(requests, isEmpty);
  });

  test('missing key does not send an unauthenticated request', () async {
    await expectLater(
      service.analyzeImage(png, 'Describe'),
      throwsA(predicate((Object e) => e.toString().contains('401'))),
    );
    expect(requests, isEmpty);
  });

  test('oversized file is rejected without an upload', () async {
    final oversized = Uint8List(5 * 1024 * 1024 + 1)..setAll(0, png);
    await expectLater(
      service.analyzeImage(oversized, 'Describe', apiKey: 'test-only-key'),
      throwsException,
    );
    expect(requests, isEmpty);
  });

  for (final code in [400, 401, 402, 404, 429, 503]) {
    test(
      'provider failure $code stays an error and does not expose response data',
      () async {
        status = code;
        responseData = {
          'error': {'message': 'sensitive-response-body'},
        };
        await expectLater(
          service.analyzeImage(png, 'Describe', apiKey: 'test-only-key'),
          throwsA(
            predicate(
              (Object e) =>
                  e.toString().contains('$code') &&
                  !e.toString().contains('sensitive-response-body') &&
                  !e.toString().contains('test-only-key'),
            ),
          ),
        );
      },
    );
  }

  test(
    'HTTP 200 error payload and missing/empty answer cannot become success',
    () async {
      for (final invalid in [
        {
          'error': {'code': 402, 'message': 'Insufficient credits'},
        },
        {'choices': []},
        completion(''),
        completion('   '),
      ]) {
        responseData = invalid;
        await expectLater(
          service.analyzeImage(png, 'Describe', apiKey: 'test-only-key'),
          throwsException,
        );
      }
    },
  );

  test('cancelled request does not upload an image', () async {
    final token = dio.CancelToken()..cancel();
    await expectLater(
      service.analyzeImage(
        png,
        'Describe',
        apiKey: 'test-only-key',
        cancelToken: token,
      ),
      throwsA(
        isA<dio.DioException>().having(
          (e) => e.type,
          'type',
          dio.DioExceptionType.cancel,
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test(
    'selected OpenRouter vision uses all images and never Firebase',
    () async {
      final firebase = ForbiddenFirebaseVision();
      Get.put<FirebaseAiLogicService>(firebase);
      final router = SelectedRouter(service);
      final result = await router.analyzeProductVision(
        prompt: 'Compare these photos',
        imageBytes: png,
        additionalImages: [jpeg],
        history: [
          {'role': 'assistant', 'content': 'Prior context'},
        ],
        systemPersona: 'Use visible evidence.',
      );
      expect(result['success'], isTrue);
      expect(result['meta']['provider'], 'openrouter');
      expect(result['meta']['upstream_provider'], 'google-vertex');
      expect(requests.single.data['messages'].last['content'].length, 3);
      expect(firebase.calls, 0);
    },
  );

  test(
    'selected provider 429 does not silently switch vision backend',
    () async {
      final firebase = ForbiddenFirebaseVision();
      Get.put<FirebaseAiLogicService>(firebase);
      status = 429;
      responseData = {
        'error': {'message': 'Rate limited'},
      };
      final result = await SelectedRouter(service).analyzeProductVision(
        prompt: 'Describe',
        imageBytes: png,
        autoRetry: false,
      );
      expect(result['success'], isFalse);
      expect(result['is_throttled'], isTrue);
      expect(firebase.calls, 0);
      expect(requests.length, 1);
    },
  );

  test(
    'selected provider with no key fails without Firebase or HTTP calls',
    () async {
      final firebase = ForbiddenFirebaseVision();
      Get.put<FirebaseAiLogicService>(firebase);
      final result = await SelectedRouter(
        service,
        key: '',
      ).analyzeProductVision(prompt: 'Describe', imageBytes: png);
      expect(result['success'], isFalse);
      expect(firebase.calls, 0);
      expect(requests, isEmpty);
    },
  );

  group('image-only product analysis', () {
    late Directory directory;
    late File file;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('scc-vision-test-');
      // Name intentionally contains "watch": filenames must not fabricate products.
      file = await File(directory.path + '/watch.png').writeAsBytes(png);
      Get.put<AIBackendRouter>(SelectedRouter(service));
    });
    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test(
      'validated provider JSON reaches product description and provenance',
      () async {
        responseData = completion(
          jsonEncode({
            'name': 'Handheld camera',
            'description': 'كاميرا بشاشة ومقبض أسود',
            'is_commercial': true,
            'category': 'Electronics',
            'confidence': 0.8,
          }),
        );
        final result = await VisionProductService().analyzeImage(file);
        expect(result.productName, 'Handheld camera');
        expect(result.data?['description'], 'كاميرا بشاشة ومقبض أسود');
        expect(result.data?['provider'], 'openrouter');
        expect(result.isProduct, isTrue);
      },
    );

    test(
      'valid scene description is retained without a product name',
      () async {
        responseData = completion(
          jsonEncode({
            'name': null,
            'description': 'سماء زرقاء وأشجار',
            'is_commercial': false,
            'category': 'Landscape',
          }),
        );
        final result = await VisionProductService().analyzeImage(file);
        expect(result.isProduct, isFalse);
        expect(result.productName, isNull);
        expect(result.data?['description'], 'سماء زرقاء وأشجار');
      },
    );

    test(
      'provider error cannot produce generic successful description',
      () async {
        status = 402;
        responseData = {
          'error': {'message': 'Insufficient credits'},
        };
        await expectLater(
          VisionProductService().analyzeImage(file),
          throwsException,
        );
      },
    );

    test(
      'invalid structured result is rejected instead of guessing from filename',
      () async {
        for (final invalid in [
          'not JSON',
          '{}',
          '{"name":"Watch"}',
          '{"name":"Watch","description":"","is_commercial":true}',
        ]) {
          responseData = completion(invalid);
          await expectLater(
            VisionProductService().analyzeImage(file),
            throwsException,
          );
        }
      },
    );
  });
}
