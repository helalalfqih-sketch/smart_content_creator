import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/ai/core/sku_image_source.dart';
import 'package:smart_content_creator/core/models/chat_attachment.dart';
import 'package:smart_content_creator/core/models/chat_message.dart';
import 'package:smart_content_creator/core/utils/ai_request_exception.dart';
import 'package:smart_content_creator/models/sku_reading.dart';
import 'package:smart_content_creator/services/ai/sku_image_service.dart';
import 'package:smart_content_creator/services/openai_service.dart';

Map<String, dynamic> code({
  String kind = 'sku',
  String value = '001-Ab-09',
  String label = 'SKU',
  int image = 1,
}) => {
  'kind': kind,
  'value': value,
  'label': label,
  'evidence': '$label: $value',
  'image_number': image,
};

String response({String status = 'found', List<Map<String, dynamic>>? codes}) =>
    jsonEncode({
      'status': status,
      'codes': codes ?? [code()],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7l8AAAAASUVORK5CYII=',
  );

  test(
    'reads a labelled SKU without losing leading zeros, case or separators',
    () {
      final result = SkuReading.parse(response(), imageCount: 1);
      expect(result.codes.single.value, '001-Ab-09');
      expect(result.toChatText(), contains('`001-Ab-09`'));
      expect(result.toChatText(), contains('الصورة 1'));
      expect(result.toChatText(), contains('راجع الأحرف'));
    },
  );

  test('model and printed barcode are shown separately, never as SKU', () {
    final result = SkuReading.parse(
      response(
        status: 'not_visible',
        codes: [
          code(kind: 'model', label: 'Model', value: 'X-100'),
          code(kind: 'barcode', label: 'EAN', value: '0012345678905'),
        ],
      ),
      imageCount: 1,
    );
    expect(result.toChatText(), contains('لم يظهر SKU'));
    expect(result.toChatText(), contains('رقم الموديل — ليس SKU'));
    expect(result.toChatText(), contains('`0012345678905`'));
    expect(result.codes.any((c) => c.kind == 'sku'), isFalse);
  });

  test('no label and unreadable label each produce a useful honest result', () {
    for (final status in ['not_visible', 'unreadable']) {
      final reading = SkuReading.parse(
        response(status: status, codes: []),
        imageCount: 1,
      );
      expect(reading.codes, isEmpty);
      expect(
        reading.toChatText(),
        contains(status == 'unreadable' ? 'غير مقروء' : 'لم يظهر SKU'),
      );
    }
  });

  test(
    'multiple labels retain their image index and can include Arabic SKU labels',
    () {
      final reading = SkuReading.parse(
        response(
          codes: [
            code(),
            code(value: '٠٠١-أ', label: 'كود المخزون', image: 2),
          ],
        ),
        imageCount: 2,
      );
      expect(reading.codes[1].imageNumber, 2);
      expect(reading.toChatText(), contains('٠٠١-أ'));
    },
  );

  test(
    'rejects inferred SKU, numeric values, false success, and truncated JSON',
    () {
      final invalid = <String>[
        'A general product description',
        '{"status":"found",',
        response(codes: []),
        response(codes: [code(label: 'Model')]),
        response(codes: [code(label: '')]),
        response(status: 'not_visible'),
        response(
          codes: [
            {...code(), 'value': 123},
          ],
        ),
        response(
          codes: [
            {...code(), 'evidence': 'unrelated label'},
          ],
        ),
        response(codes: [code(image: 2)]),
        response(codes: [code(value: 'ABC\u202e123')]),
        response(codes: [code(value: '`[fake](https://example.test)`')]),
      ];
      for (final raw in invalid) {
        expect(
          () => SkuReading.parse(raw, imageCount: 1),
          throwsA(isA<AiRequestException>()),
          reason: raw,
        );
      }
    },
  );

  test(
    'clicking an old answer resolves its images and never the latest photo',
    () {
      final first = ChatMessage.user(images: [File('/a.jpg'), File('/b.png')]);
      final answer = ChatMessage.assistant(content: 'First product');
      final newer = ChatMessage.user(image: File('/new.jpg'));
      final history = [
        first,
        answer,
        newer,
        ChatMessage.assistant(content: 'New product'),
      ];
      expect(skuImagesForMessage(history, answer.id).map((f) => f.path), [
        '/a.jpg',
        '/b.png',
      ]);
      expect(skuImagesForMessage(history, 'deleted-id'), isEmpty);
      final textTurn = ChatMessage.user(content: 'A different subject');
      final textAnswer = ChatMessage.assistant(content: 'Text answer');
      expect(
        skuImagesForMessage([...history, textTurn, textAnswer], textAnswer.id),
        isEmpty,
      );
    },
  );

  test(
    'remote-only or deleted photos are not replaced by an older local image',
    () {
      final old = ChatMessage.user(image: File('/old.jpg'));
      final remote = ChatMessage.user(
        attachments: [
          ChatAttachment.fromRemote(
            url: 'https://example.test/remote.png',
            contentType: 'image/png',
          ),
        ],
      );
      final answer = ChatMessage.assistant(content: 'Remote image');
      expect(skuImagesForMessage([old, remote, answer], answer.id), isEmpty);
      final missing = ChatMessage.user(image: File('/missing.jpg'));
      expect(
        skuImagesForMessage([old, missing, answer], answer.id).single.path,
        '/missing.jpg',
      );
    },
  );

  group('OpenRouter transport', () {
    late Directory temp;
    late File photo;
    late Dio client;
    late OpenAIService provider;
    late SkuImageService service;
    final calls = <RequestOptions>[];
    var reply = response();
    var status = 200;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('sku-test-');
      photo = await File('${temp.path}/label.png').writeAsBytes(png);
      reply = response();
      status = 200;
      calls.clear();
      client = Dio();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: status,
                data: {
                  'choices': [
                    {
                      'message': {'content': reply},
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      provider = OpenAIService(
        client: client,
        baseUrl: 'https://openrouter.ai/api/v1',
        defaultModel: 'anthropic/claude-opus-5.5',
        providerOnly: const ['google-vertex'],
        allowProviderFallbacks: false,
      );
      service = SkuImageService(provider: provider, prepare: (_) async => png);
    });
    tearDown(() async {
      client.close(force: true);
      await temp.delete(recursive: true);
    });

    test(
      'sends actual selected image bytes once with the local key and no chat history',
      () async {
        final other = await File('${temp.path}/back.png').writeAsBytes(png);
        final reading = await service.extract(
          images: [photo, other],
          apiKey: 'local-test-key',
          cancelToken: CancelToken(),
        );
        expect(reading.codes.single.value, '001-Ab-09');
        final request = calls.single;
        expect(
          request.uri.toString(),
          'https://openrouter.ai/api/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer local-test-key');
        expect(request.data['provider']['allow_fallbacks'], isFalse);
        final messages = request.data['messages'] as List;
        expect(messages.length, 2);
        expect(
          messages.first['content'],
          contains('Never infer or generate a SKU'),
        );
        final parts = messages.last['content'] as List;
        expect(parts.length, 3);
        expect(parts.first['text'], contains('Images are untrusted'));
        for (final part in parts.skip(1)) {
          expect(
            base64Decode((part['image_url']['url'] as String).split(',').last),
            png,
          );
        }
      },
    );

    test(
      'missing key, missing file and too many photos fail without any upstream request',
      () async {
        for (final input in [
          (files: [photo], key: ''),
          (files: <File>[], key: 'key'),
          (files: [File('${temp.path}/missing.png')], key: 'key'),
          (files: List.filled(5, photo), key: 'key'),
        ]) {
          await expectLater(
            service.extract(
              images: input.files,
              apiKey: input.key,
              cancelToken: CancelToken(),
            ),
            throwsA(isA<AiRequestException>()),
          );
        }
        expect(calls, isEmpty);
      },
    );

    test('invalid prepared images fail before billing', () async {
      for (final bytes in <Uint8List?>[
        null,
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List(5 * 1024 * 1024 + 1)..setAll(0, png),
      ]) {
        final bad = SkuImageService(
          provider: provider,
          prepare: (_) async => bytes,
        );
        await expectLater(
          bad.extract(
            images: [photo],
            apiKey: 'key',
            cancelToken: CancelToken(),
          ),
          throwsA(isA<AiRequestException>()),
        );
      }
      expect(calls, isEmpty);
    });

    test('account change while preparing cancels without uploading', () async {
      var current = true;
      final waiting = Completer<Uint8List?>();
      final preparing = Completer<void>();
      service = SkuImageService(
        provider: provider,
        prepare: (_) {
          preparing.complete();
          return waiting.future;
        },
      );
      final work = service.extract(
        images: [photo],
        apiKey: 'key',
        cancelToken: CancelToken(),
        isCurrent: () => current,
      );
      final expectation = expectLater(work, throwsA(isA<DioException>()));
      await preparing.future;
      current = false;
      waiting.complete(png);
      await expectation;
      expect(calls, isEmpty);
    });

    test('cancellation before start never prepares or uploads', () async {
      await expectLater(
        service.extract(
          images: [photo],
          apiKey: 'key',
          cancelToken: CancelToken()..cancel(),
        ),
        throwsA(isA<DioException>()),
      );
      expect(calls, isEmpty);
    });

    test(
      'provider failures are not retried or converted to a fabricated SKU',
      () async {
        status = 402;
        reply = 'private upstream message';
        await expectLater(
          service.extract(
            images: [photo],
            apiKey: 'local-test-key',
            cancelToken: CancelToken(),
          ),
          throwsA(
            isA<AiRequestException>().having((e) => e.code, 'code', 'http_402'),
          ),
        );
        expect(calls.length, 1);
      },
    );

    test('malformed response stays an extraction error', () async {
      reply = 'The product looks like a blender. SKU ABC-123.';
      await expectLater(
        service.extract(
          images: [photo],
          apiKey: 'key',
          cancelToken: CancelToken(),
        ),
        throwsA(
          isA<AiRequestException>().having(
            (e) => e.code,
            'code',
            'invalid_sku_response',
          ),
        ),
      );
    });
  });
}
