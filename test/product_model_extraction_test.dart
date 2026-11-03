import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/ai/core/product_image_source.dart';
import 'package:smart_content_creator/core/models/chat_attachment.dart';
import 'package:smart_content_creator/core/models/chat_message.dart';
import 'package:smart_content_creator/core/utils/ai_request_exception.dart';
import 'package:smart_content_creator/models/product_model_reading.dart';
import 'package:smart_content_creator/services/ai/product_model_image_service.dart';
import 'package:smart_content_creator/services/openai_service.dart';
import 'package:smart_content_creator/services/serpapi_services.dart';

class _Lens extends GoogleLensService {
  int calls = 0;
  String? path;
  Map<String, dynamic> reply = {'visual_matches': <dynamic>[]};
  @override
  Future<Map<String, dynamic>> searchByImage(
    String imageInput, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    path = imageInput;
    return reply;
  }
}

Map<String, dynamic> code({
  String kind = 'model',
  String value = '001-Ab-09',
  String label = 'Model',
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
    'reads a printed model without losing leading zeros, case or separators',
    () {
      final result = ProductModelReading.parse(response(), imageCount: 1);
      expect(result.codes.single.value, '001-Ab-09');
      expect(result.toChatText(), contains('`001-Ab-09`'));
      expect(result.toChatText(), contains('الصورة 1'));
      expect(result.toChatText(), contains('راجع الأحرف'));
    },
  );

  test('SKU and barcode cannot produce a found model', () {
    final result = ProductModelReading.parse(
      response(
        status: 'not_visible',
        codes: [
          code(kind: 'sku', label: 'SKU', value: 'X-100'),
          code(kind: 'barcode', label: 'EAN', value: '0012345678905'),
        ],
      ),
      imageCount: 1,
    );
    expect(result.toChatText(), contains('لم يظهر اسم أو رقم موديل'));
    expect(result.toChatText(), contains('رمز المخزون SKU — ليس رقم الموديل'));
    expect(result.toChatText(), contains('`0012345678905`'));
    expect(result.codes.any((c) => c.kind == 'model'), isFalse);
  });

  test('no label and unreadable label each produce a useful honest result', () {
    for (final status in ['not_visible', 'unreadable']) {
      final reading = ProductModelReading.parse(
        response(status: status, codes: []),
        imageCount: 1,
      );
      expect(reading.codes, isEmpty);
      expect(
        reading.toChatText(),
        contains(
          status == 'unreadable' ? 'غير مقروء' : 'لم يظهر اسم أو رقم موديل',
        ),
      );
    }
  });

  test(
    'prints model first even when SKU appears first in the provider result',
    () {
      final result = ProductModelReading.parse(
        response(
          codes: [
            code(kind: 'sku', label: 'SKU', value: 'STORE-999'),
            code(value: 'WH-1000XM5', label: ''),
          ],
        ),
        imageCount: 1,
      );
      final text = result.toChatText();
      expect(text.indexOf('WH-1000XM5'), lessThan(text.indexOf('STORE-999')));
      expect(text, contains('الموديل المقروء'));
      expect(text, isNot(contains('لم يظهر')));
    },
  );

  test(
    'no visible model offers explicit Lens search without asserting a model',
    () {
      final result = ProductModelReading.parse(
        response(status: 'not_visible', codes: []),
        imageCount: 1,
      );
      expect(result.toChatText(), contains('عدسة Google'));
      expect(result.toChatText(), contains('ليست تأكيدًا للموديل'));
    },
  );

  test(
    'Lens candidates preserve sources and exclude non-web or credential URLs',
    () {
      final candidates = ProductModelCandidate.parseMatches([
        {
          'title': 'Possible X-100',
          'link': 'https://example.test/model',
          'thumbnail': 'https://example.test/image.jpg',
          'source': 'Shop',
        },
        {'title': 'Unsafe', 'link': 'javascript:alert(1)'},
        {'title': 'Credential', 'link': 'https://user:pass@example.test/model'},
        {'title': '', 'link': 'https://example.test/'},
        {
          'title': 'Valid source',
          'link': 'https://example.test/second',
          'thumbnail': 'data:text/html,unsafe',
        },
      ]);
      expect(candidates.length, 2);
      expect(candidates.first.title, 'Possible X-100');
      expect(candidates.first.link, 'https://example.test/model');
      expect(candidates.last.thumbnail, isEmpty);
      expect(ProductModelCandidate.parseMatches([]), isEmpty);
      expect(
        () => ProductModelCandidate.parseMatches(null),
        throwsA(isA<AiRequestException>()),
      );
    },
  );

  test(
    'multiple labels retain their image index and can include Arabic model labels',
    () {
      final reading = ProductModelReading.parse(
        response(
          codes: [
            code(),
            code(value: '٠٠١-أ', label: 'رقم الموديل', image: 2),
          ],
        ),
        imageCount: 2,
      );
      expect(reading.codes[1].imageNumber, 2);
      expect(reading.toChatText(), contains('٠٠١-أ'));
    },
  );

  test(
    'rejects mislabelled model, numeric values, false success, and truncated JSON',
    () {
      final invalid = <String>[
        'A general product description',
        '{"status":"found",',
        response(codes: []),
        response(codes: [code(label: 'SKU')]),
        response(codes: [code(label: 'S/N')]),
        response(codes: [code(label: 'P/N')]),
        response(codes: [code(label: 'EAN')]),
        response(
          codes: [code(kind: 'sku', label: 'Model')],
        ),
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
          () => ProductModelReading.parse(raw, imageCount: 1),
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
      expect(productImagesForMessage(history, answer.id).map((f) => f.path), [
        '/a.jpg',
        '/b.png',
      ]);
      expect(productImagesForMessage(history, 'deleted-id'), isEmpty);
      final textTurn = ChatMessage.user(content: 'A different subject');
      final textAnswer = ChatMessage.assistant(content: 'Text answer');
      expect(
        productImagesForMessage([
          ...history,
          textTurn,
          textAnswer,
        ], textAnswer.id),
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
      expect(
        productImagesForMessage([old, remote, answer], answer.id),
        isEmpty,
      );
      final missing = ChatMessage.user(image: File('/missing.jpg'));
      expect(
        productImagesForMessage([old, missing, answer], answer.id).single.path,
        '/missing.jpg',
      );
    },
  );

  group('OpenRouter transport', () {
    late Directory temp;
    late File photo;
    late Dio client;
    late OpenAIService provider;
    late ProductModelImageService service;
    final calls = <RequestOptions>[];
    var reply = response();
    var status = 200;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('model-test-');
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
      service = ProductModelImageService(
        provider: provider,
        prepare: (_) async => png,
      );
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
          contains('Never infer or generate a model'),
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

    test(
      'explicit Lens uses the chosen local image and validates before calling',
      () async {
        final lens = _Lens()
          ..reply = {
            'visual_matches': [
              {'title': 'Candidate X-100', 'link': 'https://example.test/x100'},
            ],
          };
        final searching = ProductModelImageService(lens: lens);
        final matches = await searching.searchSimilar(
          image: photo,
          cancelToken: CancelToken(),
        );
        expect(lens.calls, 1);
        expect(lens.path, photo.path);
        expect(matches.single.title, 'Candidate X-100');
        expect(
          calls,
          isEmpty,
        ); // No OpenRouter call or key is needed for this action.
        await expectLater(
          searching.searchSimilar(
            image: File('${temp.path}/missing.png'),
            cancelToken: CancelToken(),
          ),
          throwsA(isA<AiRequestException>()),
        );
        await expectLater(
          searching.searchSimilar(
            image: photo,
            cancelToken: CancelToken(),
            isCurrent: () => false,
          ),
          throwsA(isA<DioException>()),
        );
        expect(lens.calls, 1);
      },
    );

    test('invalid prepared images fail before billing', () async {
      for (final bytes in <Uint8List?>[
        null,
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List(5 * 1024 * 1024 + 1)..setAll(0, png),
      ]) {
        final bad = ProductModelImageService(
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
      service = ProductModelImageService(
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
      'provider failures are not retried or converted to a fabricated model',
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
      reply = 'The product looks like a blender. model ABC-123.';
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
            'invalid_model_response',
          ),
        ),
      );
    });
  });
}
