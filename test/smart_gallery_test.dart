import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/gallery/gallery_analyzer.dart';
import 'package:smart_content_creator/gallery/gallery_item.dart';
import 'package:smart_content_creator/gallery/gallery_store.dart';
import 'package:smart_content_creator/services/openai_service.dart';
import 'package:image/image.dart' as img;

GalleryItem item(
  String id,
  String name, {
  String? hash,
  String mime = 'image/jpeg',
}) => GalleryItem(
  id: id,
  name: name,
  originalName: name,
  extension: 'jpg',
  mimeType: mime,
  source: 'phone',
  digest: id,
  importedAt: 1,
  bytes: 1,
  perceptualHash: hash,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Arabic names preserve extension, strip path/control input, and avoid reserved names',
    () {
      expect(galleryFileName('هاتف أسود.JPG', 'jpg'), 'هاتف_أسود.jpg');
      final hostile = galleryFileName('../../secret\\image\u202E.exe', 'jpg');
      expect(hostile, endsWith('.jpg'));
      expect(hostile, isNot(contains('/')));
      expect(hostile, isNot(contains('\\')));
      expect(hostile, isNot(contains('\u202E')));
      expect(galleryFileName('CON', 'jpg'), 'ملف_CON.jpg');
      expect(galleryFileName('..', 'jpg'), 'صورة.jpg');
    },
  );
  test(
    'batch preview resolves existing and intra-batch collisions deterministically',
    () {
      final all = [
        item('1', 'one.jpg'),
        item('2', 'two.jpg'),
        item('3', 'منتج.jpg'),
      ];
      final plan = planGalleryRename(all, all.take(2).toList(), {
        '1': 'منتج',
        '2': 'منتج',
      });
      expect(plan, {'1': 'منتج_2.jpg', '2': 'منتج_3.jpg'});
      expect(
        planGalleryRename(all, all.take(2).toList(), {
          '1': 'two.jpg',
          '2': 'one.jpg',
        }),
        {'1': 'two.jpg', '2': 'one.jpg'},
      );
      expect(availableGalleryName('ONE.jpg', 'jpg', {'one.jpg'}), 'ONE_2.jpg');
    },
  );
  test(
    'strict AI parsing rejects truncated or fabricated shapes; it never applies names',
    () {
      expect(
        () => GalleryAnalysis.parse('a general image description'),
        throwsA(isA<GalleryFailure>()),
      );
      expect(
        () => GalleryAnalysis.parse('{"description":"ok"}'),
        throwsA(isA<GalleryFailure>()),
      );
      final result = GalleryAnalysis.parse(
        '```json\n${jsonEncode({
          'description': 'كاميرا محمولة',
          'category': 'إلكترونيات',
          'text': '4K',
          'tags': ['كاميرا', 'كاميرا', 'تصوير'],
          'suggested_name': '../كاميرا',
        })}\n```',
      );
      expect(result.tags, ['كاميرا', 'تصوير']);
      expect(result.text, '4K');
      expect(galleryFileName(result.suggestedName, 'jpg'), '_كاميرا.jpg');
    },
  );
  test('similarity candidates exclude video and distant images', () {
    final values = [
      item('a', 'a.jpg', hash: '0000000000000000'),
      item('b', 'b.jpg', hash: '0000000000000007'),
      item('c', 'c.jpg', hash: 'ffffffffffffffff'),
      item('d', 'd.jpg', hash: '0000000000000000', mime: 'video/mp4'),
    ];
    expect(similarGalleryIds(values), {'a', 'b'});
    expect(galleryHashDistance('bad', 'ffffffffffffffff'), 65);
    final image = img.Image(width: 24, height: 24);
    img.fill(image, color: img.ColorRgb8(50, 80, 120));
    final hash = galleryImageHash(Uint8List.fromList(img.encodeJpg(image)));
    expect(hash, hasLength(16));
    expect(galleryHashDistance(hash, hash), 0);
  });
  test(
    'gallery sends image bytes only to explicit OpenRouter, existing key, and no history',
    () async {
      final client = Dio();
      final requests = <RequestOptions>[];
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: jsonEncode({
                  'choices': [
                    {
                      'message': {
                        'content': jsonEncode({
                          'description': 'كاميرا',
                          'category': 'منتجات',
                          'text': '',
                          'tags': ['تصوير'],
                          'suggested_name': 'كاميرا_سوداء',
                        }),
                      },
                    },
                  ],
                }),
              ),
            );
          },
        ),
      );
      final provider = OpenAIService(
        client: client,
        baseUrl: 'https://openrouter.ai/api/v1',
        defaultModel: 'anthropic/claude-opus-5.5',
        providerOnly: const ['google-vertex'],
        allowProviderFallbacks: false,
      );
      final bytes = Uint8List.fromList([255, 216, 255, 224, 0, 16, 255, 217]);
      final analyzer = GalleryAnalyzer(
        provider: provider,
        prepare: (_) async => bytes,
      );
      final result = await analyzer.analyze(
        'private/local/photo.jpg',
        'existing-user-key',
        CancelToken(),
      );
      expect(result.description, 'كاميرا');
      expect(requests, hasLength(1));
      expect(requests.single.uri.host, 'openrouter.ai');
      expect(
        requests.single.headers['Authorization'],
        'Bearer existing-user-key',
      );
      final payload = requests.single.data as Map;
      expect((payload['messages'] as List), hasLength(2));
      expect(jsonEncode(payload), contains('data:image/jpeg;base64,'));
      expect(jsonEncode(payload), isNot(contains('private/local')));
      expect(payload['provider']['allow_fallbacks'], false);
      client.close();
    },
  );
  test(
    'missing key and cancellation stop before sending or decoding photos',
    () async {
      var reads = 0;
      final analyzer = GalleryAnalyzer(
        prepare: (_) async {
          reads++;
          return Uint8List(0);
        },
      );
      await expectLater(
        analyzer.analyze('photo', '', CancelToken()),
        throwsA(isA<GalleryFailure>()),
      );
      final cancel = CancelToken()..cancel();
      await expectLater(
        analyzer.analyze('photo', 'key', cancel),
        throwsA(isA<DioException>()),
      );
      expect(reads, 0);
    },
  );
}
