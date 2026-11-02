import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_content_creator/gallery/google_photos_picker.dart';
import 'package:smart_content_creator/gallery/gallery_item.dart';

void main() {
  late Dio client;
  final calls = <RequestOptions>[];
  setUp(() {
    client = Dio();
    calls.clear();
  });
  tearDown(() => client.close(force: true));
  Map<String, dynamic> media(String id) => {
    'id': id,
    'type': 'PHOTO',
    'createTime': '2026-11-02T00:00:00Z',
    'mediaFile': {
      'filename': '$id.jpg',
      'mimeType': 'image/jpeg',
      'baseUrl': 'https://lh3.googleusercontent.com/p/$id',
    },
  };

  test(
    'real Picker contract: scope, poll recommendations, pagination, and cleanup after importing bytes',
    () async {
      var polls = 0;
      final delays = <Duration>[];
      final imported = <String>[];
      Uri? opened;
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            dynamic result;
            if (options.method == 'POST') {
              result = {
                'id': 'session_1',
                'pickerUri': 'https://photos.google.com/picker/session_1',
                'mediaItemsSet': false,
                'pollingConfig': {'pollInterval': '3.5s', 'timeoutIn': '60s'},
              };
            } else if (options.method == 'DELETE') {
              expect(imported, ['a.jpg', 'b.jpg']);
              result = {};
            } else if (options.path.endsWith('/sessions/session_1')) {
              polls++;
              result = {'id': 'session_1', 'mediaItemsSet': true};
            } else {
              result = options.queryParameters['pageToken'] == null
                  ? {
                      'mediaItems': [media('a')],
                      'nextPageToken': 'page2',
                    }
                  : {
                      'mediaItems': [media('b')],
                    };
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: jsonEncode(result),
              ),
            );
          },
        ),
      );
      final picker = GooglePhotosPicker(
        client: client,
        open: (uri) async {
          opened = uri;
          return true;
        },
        wait: (delay, _) async {
          delays.add(delay);
        },
      );
      await picker.pick(
        'google-token',
        CancelToken(),
        progress: (_) {},
        import: (item) async {
          imported.add(item.name);
        },
      );
      expect(opened!.host, 'photos.google.com');
      expect(polls, 1);
      expect(delays, [const Duration(milliseconds: 3500)]);
      expect(imported, ['a.jpg', 'b.jpg']);
      expect(calls.last.method, 'DELETE');
      expect(
        calls.every((r) => r.uri.host == 'photospicker.googleapis.com'),
        true,
      );
      expect(
        calls.every((r) => r.headers['Authorization'] == 'Bearer google-token'),
        true,
      );
      expect(calls.first.data['pickingConfig']['maxItemCount'], '100');
      expect(
        GalleryPhotosAuthorization.scope,
        endsWith('photospicker.mediaitems.readonly'),
      );
    },
  );
  test(
    'cancelling external picker cleans session and makes no media request',
    () async {
      final cancel = CancelToken();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: jsonEncode(
                  options.method == 'DELETE'
                      ? {}
                      : {
                          'id': 'cancelled',
                          'pickerUri':
                              'https://photos.google.com/picker/cancelled',
                          'pollingConfig': {
                            'pollInterval': '2s',
                            'timeoutIn': '60s',
                          },
                          'mediaItemsSet': false,
                        },
                ),
              ),
            );
          },
        ),
      );
      final picker = GooglePhotosPicker(
        client: client,
        open: (_) async => true,
        wait: (_, token) async {
          token.cancel();
        },
      );
      await expectLater(
        picker.pick(
          'token',
          cancel,
          progress: (_) {},
          import: (_) async => fail('No import'),
        ),
        throwsA(isA<DioException>()),
      );
      expect(calls.map((x) => x.method), ['POST', 'DELETE']);
    },
  );
  test(
    'auth failures are safe and contain neither credentials nor remote body',
    () async {
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 403,
              data: 'secret-token internal-error',
            ),
          ),
        ),
      );
      await expectLater(
        GooglePhotosPicker(client: client).pick(
          'secret-token',
          CancelToken(),
          progress: (_) {},
          import: (_) async {},
        ),
        throwsA(
          isA<GalleryFailure>().having(
            (e) => e.message,
            'safe error',
            isNot(contains('secret-token')),
          ),
        ),
      );
    },
  );
  test('download parameters, host validation, and video processing status', () {
    expect(
      GooglePhotosPicker.contentUri(
        'https://lh3.googleusercontent.com/p/id',
        false,
      ).toString(),
      endsWith('=d'),
    );
    expect(
      GooglePhotosPicker.contentUri(
        'https://lh3.googleusercontent.com/p/id',
        true,
      ).toString(),
      endsWith('=dv'),
    );
    for (final url in [
      'http://lh3.googleusercontent.com/p/id',
      'https://evil.test/image',
      'https://lh3.googleusercontent.com.evil.test/id',
      'https://user@lh3.googleusercontent.com/id',
      'https://lh3.googleusercontent.com:8443/id',
    ]) {
      expect(
        () => GooglePhotosPicker.contentUri(url, false),
        throwsA(isA<GalleryFailure>()),
      );
    }
    expect(
      PickedGalleryMedia.fromJson({
        'type': 'VIDEO',
        'mediaFile': {
          'filename': 'v.mp4',
          'mimeType': 'video/mp4',
          'baseUrl': 'https://lh3.googleusercontent.com/id',
          'mediaFileMetadata': {
            'videoMetadata': {'processingStatus': 'PROCESSING'},
          },
        },
      }).videoReady,
      false,
    );
  });
  test(
    'image bytes include bearer authorization; hostile redirects cannot receive it',
    () async {
      final dir = await Directory.systemTemp.createTemp('gallery-picker-test');
      addTearDown(() => dir.delete(recursive: true));
      var hostile = false;
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: hostile ? 302 : 200,
                headers: Headers.fromMap(
                  hostile
                      ? {
                          'location': ['https://evil.test/image'],
                        }
                      : {},
                ),
                data: ResponseBody.fromBytes(
                  hostile ? [] : [255, 216, 255, 217],
                  hostile ? 302 : 200,
                ),
              ),
            );
          },
        ),
      );
      final picker = GooglePhotosPicker(client: client);
      final item = PickedGalleryMedia.fromJson(media('a'));
      final file = File('${dir.path}/image.jpg');
      await picker.download(item, 'download-token', file, CancelToken());
      expect(await file.readAsBytes(), [255, 216, 255, 217]);
      expect(calls.single.headers['Authorization'], 'Bearer download-token');
      hostile = true;
      calls.clear();
      final failed = File('${dir.path}/failed.jpg');
      await expectLater(
        picker.download(item, 'download-token', failed, CancelToken()),
        throwsA(isA<GalleryFailure>()),
      );
      expect(calls, hasLength(1));
      expect(await failed.exists(), false);
    },
  );
}
