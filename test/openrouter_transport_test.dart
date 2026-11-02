import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/core/utils/ai_request_exception.dart';
import 'package:smart_content_creator/core/utils/error_handler.dart';
import 'package:smart_content_creator/services/ai/vision_product_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/openai_service.dart';

// Exercise Dio's actual response transformation, rather than resolving an
// interceptor with an already-decoded object (which misses this regression).
class WireAdapter implements dio.HttpClientAdapter {
  final dio.ResponseBody Function(dio.RequestOptions) respond;
  final requests = <dio.RequestOptions>[];
  WireAdapter(this.respond);

  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class TransportRouter extends AIBackendRouter {
  TransportRouter(OpenAIService service)
    : super(
        openRouterService: service,
        openRouterKeyReader: () => 'test-only-secret',
      );
  @override
  Future<String> resolveBackend() async => 'openrouter';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7l8AAAAASUVORK5CYII=',
  );
  late dio.Dio client;
  late WireAdapter wire;
  late OpenAIService service;
  late Directory directory;
  late File image;
  late dio.ResponseBody Function(dio.RequestOptions) respond;

  dio.ResponseBody body(
    String text,
    int status, {
    String contentType = 'application/json',
  }) => dio.ResponseBody.fromString(
    text,
    status,
    headers: {
      'content-type': [contentType],
    },
  );

  setUp(() async {
    Get.testMode = true;
    respond = (_) => body(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'name': null,
                'description': 'سماء زرقاء',
                'is_commercial': false,
              }),
            },
          },
        ],
      }),
      200,
    );
    wire = WireAdapter((options) => respond(options));
    client = dio.Dio()..httpClientAdapter = wire;
    service = OpenAIService(
      client: client,
      baseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'anthropic/claude-opus-5.5',
      providerOnly: const ['google-vertex'],
      allowProviderFallbacks: false,
    );
    Get.put<AIBackendRouter>(TransportRouter(service));
    directory = await Directory.systemTemp.createTemp('vision-transport-');
    image = await File('${directory.path}/photo.png').writeAsBytes(png);
  });

  tearDown(() async {
    client.close(force: true);
    Get.reset();
    await directory.delete(recursive: true);
  });

  Future<AiRequestException> failedAnalysis() async {
    try {
      await VisionProductService().analyzeImage(image);
    } on AiRequestException catch (failure) {
      final mapped = ErrorHandler.mapError(failure);
      expect(mapped.message, failure.toString());
      expect(mapped.canRetry, failure.canRetry);
      expect(mapped.message, isNot(contains('Exception')));
      expect(mapped.message, isNot(contains('test-only-secret')));
      expect(mapped.message, isNot(contains('private-response')));
      expect(mapped.technicalDetails, failure.code);
      expect(
        wire.requests,
        hasLength(1),
      ); // No charge retries or provider switch.
      return failure;
    }
    fail('An invalid response must never produce successful image analysis');
  }

  test('real Dio decoding still returns validated image analysis', () async {
    final result = await VisionProductService().analyzeImage(image);
    expect(result.data?['description'], 'سماء زرقاء');
    final request = wire.requests.single;
    expect(request.data['provider'], {
      'only': ['google-vertex'],
      'allow_fallbacks': false,
    });
    expect(
      request.data['messages'].last['content'][1]['image_url']['url'],
      'data:image/png;base64,${base64Encode(png)}',
    );
  });

  for (final status in [401, 402, 413, 502, 503]) {
    test(
      'HTML HTTP $status keeps status instead of connection_error',
      () async {
        // Some gateways mislabel their HTML response as JSON.
        respond = (_) => body('<html>private-response</html>', status);
        expect((await failedAnalysis()).code, 'http_$status');
      },
    );
  }

  for (final response in [
    '',
    '  \n',
    '{"choices":',
    '<html>private-response</html>',
    'null',
    '[]',
    '{"choices":[]}',
  ]) {
    test(
      'malformed or incomplete success response stays invalid_response: $response',
      () async {
        respond = (_) => body(response, 200);
        expect((await failedAnalysis()).code, 'invalid_response');
      },
    );
  }

  test('HTTP 200 with provider quota error remains quota error', () async {
    respond = (_) =>
        body('{"error":{"code":402,"message":"private-response"}}', 200);
    expect((await failedAnalysis()).code, 'http_402');
  });

  final failures = <String, (dio.DioExceptionType, Object?)>{
    'dns_error': (
      dio.DioExceptionType.connectionError,
      const SocketException('Failed host lookup: private-response'),
    ),
    'connection_error': (
      dio.DioExceptionType.connectionError,
      const SocketException('private-response'),
    ),
    'connection_interrupted': (
      dio.DioExceptionType.unknown,
      const HttpException('Connection closed: private-response'),
    ),
    'tls_error': (
      dio.DioExceptionType.unknown,
      const HandshakeException('private-response'),
    ),
    'invalid_response': (
      dio.DioExceptionType.unknown,
      const FormatException('private-response'),
    ),
    'request_error': (
      dio.DioExceptionType.unknown,
      StateError('private-response'),
    ),
    'connect_timeout': (dio.DioExceptionType.connectionTimeout, null),
    'upload_timeout': (dio.DioExceptionType.sendTimeout, null),
    'response_timeout': (dio.DioExceptionType.receiveTimeout, null),
  };
  for (final entry in failures.entries) {
    test(
      '${entry.key} survives service, router, product service and UI mapping',
      () async {
        respond = (options) => throw dio.DioException(
          requestOptions: options,
          type: entry.value.$1,
          error: entry.value.$2,
          message: 'private-response',
        );
        expect((await failedAnalysis()).code, entry.key);
      },
    );
  }

  test(
    'bad certificate is never mislabeled as a generic connection error',
    () async {
      respond = (options) => throw dio.DioException(
        requestOptions: options,
        type: dio.DioExceptionType.badCertificate,
      );
      expect((await failedAnalysis()).code, 'tls_error');
    },
  );

  test(
    'cancellation reaches caller unchanged without another request',
    () async {
      final token = dio.CancelToken()..cancel('cancelled');
      await expectLater(
        VisionProductService().analyzeImage(image, cancelToken: token),
        throwsA(
          isA<dio.DioException>().having(
            (e) => e.type,
            'type',
            dio.DioExceptionType.cancel,
          ),
        ),
      );
      expect(wire.requests, isEmpty);
    },
  );

  test('legacy double Exception message remains readable without fake retry', () {
    final mapped = ErrorHandler.mapError(
      Exception(
        Exception(
          '❌ connection_error: تعذر الاتصال بالخدمة. تحقق من الإنترنت وأعد المحاولة.',
        ),
      ),
    );
    expect(mapped.message, contains('تعذر الاتصال'));
    expect(mapped.message, isNot(contains('Exception')));
    expect(mapped.message, isNot(contains('غير متوقع')));
    expect(mapped.message, isNot(contains('جاري إعادة')));
    expect(mapped.message, isNot(contains('...')));
  });
}
