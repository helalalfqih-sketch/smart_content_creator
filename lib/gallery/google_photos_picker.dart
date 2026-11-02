import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'gallery_item.dart';
import 'gallery_store.dart';

class PickedGalleryMedia {
  final String name, mime, baseUrl;
  final DateTime? created;
  final bool videoReady;
  const PickedGalleryMedia({
    required this.name,
    required this.mime,
    required this.baseUrl,
    this.created,
    this.videoReady = true,
  });
  factory PickedGalleryMedia.fromJson(Map<String, dynamic> json) {
    final file = json['mediaFile'];
    if (file is! Map ||
        file['filename'] is! String ||
        file['mimeType'] is! String ||
        file['baseUrl'] is! String) {
      throw const GalleryFailure('تعذر قراءة بيانات صورة Google Photos.');
    }
    final meta = file['mediaFileMetadata'];
    final video = meta is Map ? meta['videoMetadata'] : null;
    return PickedGalleryMedia(
      name: file['filename'],
      mime: file['mimeType'],
      baseUrl: file['baseUrl'],
      created: DateTime.tryParse('${json['createTime']}'),
      videoReady:
          json['type'] != 'VIDEO' ||
          (video is Map && video['processingStatus'] == 'READY'),
    );
  }
}

/// Uses the existing Android OAuth client. No client secret or refresh token is
/// embedded in the app. This does not sign in/out of the app's Firebase account.
class GalleryPhotosAuthorization {
  static const scope =
      'https://www.googleapis.com/auth/photospicker.mediaitems.readonly';
  final GoogleSignIn _google = GoogleSignIn(
    serverClientId:
        '663916675240-lraulfk0fs7hsjoa4d83fi480t68970q.apps.googleusercontent.com',
    scopes: const ['email', scope],
  );

  Future<String?> authorize() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      if (auth.accessToken == null) {
        throw const GalleryFailure('لم يمنح Google صلاحية اختيار الصور.');
      }
      return auth.accessToken;
    } on GalleryFailure {
      rethrow;
    } catch (_) {
      throw const GalleryFailure(
        'تعذر ربط Google Photos. تحقق من الإنترنت وصلاحية Photos Picker لحساب Google وتوقيع نسخة التطبيق.',
      );
    }
  }
}

class GooglePhotosPicker {
  final Dio _client;
  final Future<bool> Function(Uri) _open;
  final Future<void> Function(Duration, CancelToken) _wait;
  final DateTime Function() _now;
  static const origin = 'https://photospicker.googleapis.com/v1';
  GooglePhotosPicker({
    Dio? client,
    Future<bool> Function(Uri)? open,
    Future<void> Function(Duration, CancelToken)? wait,
    DateTime Function()? now,
  }) : _client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 90),
               sendTimeout: const Duration(seconds: 30),
             ),
           ),
       _open =
           open ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _wait =
           wait ??
           ((delay, cancel) => Future.any<void>([
             Future<void>.delayed(delay),
             cancel.whenCancel.then<void>((_) {}),
           ])),
       _now = now ?? DateTime.now;

  static Duration seconds(Object? value, int fallback) {
    final number = double.tryParse('$value'.replaceFirst(RegExp(r's$'), ''));
    return Duration(
      milliseconds: ((number ?? fallback).clamp(0, 3600) * 1000).ceil(),
    );
  }

  static Uri contentUri(String baseUrl, bool video) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        !uri.host.endsWith('.googleusercontent.com') ||
        uri.fragment.isNotEmpty) {
      throw const GalleryFailure('رابط تنزيل Google Photos غير صالح.');
    }
    return Uri.parse('$baseUrl=${video ? 'dv' : 'd'}');
  }

  static void _checkStatus(int? code) {
    if (code != null && code >= 200 && code < 300) return;
    throw GalleryFailure(switch (code) {
      401 => 'انتهت صلاحية Google Photos. ابدأ الاستيراد مجدداً وسجّل الدخول.',
      403 =>
        'لم يُسمح بالوصول إلى Google Photos. تحقق من موافقة Photos Picker وإعدادات حسابك.',
      404 || 410 => 'انتهت جلسة اختيار الصور. ابدأ استيراداً جديداً.',
      429 => 'بلغ Google حد الطلبات. انتظر قليلاً ثم أعد الاستيراد.',
      _ => 'تعذر استيراد الصور من Google الآن. النسخ المستوردة سابقاً محفوظة.',
    });
  }

  Future<Map<String, dynamic>> _api(
    String method,
    String path,
    String token,
    CancelToken cancel, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    final result = await _client.request<String>(
      '$origin/$path',
      data: data,
      queryParameters: query,
      cancelToken: cancel,
      options: Options(
        method: method,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (_) => true,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    _checkStatus(result.statusCode);
    if (result.data == null || result.data!.isEmpty) return {};
    if (result.data!.length > 2 * 1024 * 1024) {
      throw const GalleryFailure('استجابة Google Photos أكبر من المتوقع.');
    }
    final decoded = jsonDecode(result.data!);
    if (decoded is! Map<String, dynamic>) {
      throw const GalleryFailure('استجابة Google Photos غير صالحة.');
    }
    return decoded;
  }

  /// The session stays alive until the selected bytes have been imported.
  /// Cleanup runs after success, cancellation, denied access and partial failure.
  Future<void> pick(
    String token,
    CancelToken cancel, {
    required void Function(String) progress,
    required Future<void> Function(PickedGalleryMedia) import,
  }) async {
    String? sessionId;
    try {
      var session = await _api(
        'POST',
        'sessions',
        token,
        cancel,
        data: {
          'pickingConfig': {'maxItemCount': '100'},
        },
      );
      sessionId = session['id'] as String?;
      final uri = Uri.tryParse('${session['pickerUri']}');
      if (sessionId == null ||
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sessionId) ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'photos.google.com' ||
          uri.userInfo.isNotEmpty ||
          uri.port != 443) {
        throw const GalleryFailure('تعذر فتح جلسة اختيار الصور.');
      }
      if (!await _open(uri)) {
        throw const GalleryFailure('تعذر فتح Google Photos في المتصفح.');
      }
      progress('اختر الصور في Google Photos ثم اضغط «تم» وعد إلى التطبيق.');
      var deadline = _now().add(const Duration(minutes: 10));
      while (session['mediaItemsSet'] != true) {
        if (cancel.isCancelled) throw cancel.cancelError!;
        final config = session['pollingConfig'];
        final timeout = seconds(
          config is Map ? config['timeoutIn'] : null,
          600,
        );
        final poll = seconds(config is Map ? config['pollInterval'] : null, 5);
        final recommended = _now().add(timeout);
        if (recommended.isBefore(deadline)) deadline = recommended;
        final expiration = DateTime.tryParse('${session['expireTime']}');
        if (expiration != null && expiration.isBefore(deadline)) {
          deadline = expiration;
        }
        if (!_now().add(poll).isBefore(deadline)) {
          throw const GalleryFailure(
            'انتهت مهلة الاختيار. ابدأ الاستيراد مجدداً.',
          );
        }
        await _wait(
          poll < const Duration(seconds: 1) ? const Duration(seconds: 1) : poll,
          cancel,
        );
        if (cancel.isCancelled) throw cancel.cancelError!;
        session = await _api('GET', 'sessions/$sessionId', token, cancel);
      }
      String? page;
      var count = 0;
      final pages = <String>{};
      do {
        if (cancel.isCancelled) throw cancel.cancelError!;
        final response = await _api(
          'GET',
          'mediaItems',
          token,
          cancel,
          query: {
            'sessionId': sessionId,
            'pageSize': '100',
            if (page != null) 'pageToken': page,
          },
        );
        final items = response['mediaItems'];
        if (items != null && items is! List) {
          throw const GalleryFailure('قائمة صور Google غير صالحة.');
        }
        for (final json in (items as List? ?? [])) {
          if (cancel.isCancelled) throw cancel.cancelError!;
          if (++count > 100) {
            throw const GalleryFailure('حد الاستيراد 100 ملف في كل مرة.');
          }
          progress('استيراد ملف $count من Google Photos…');
          await import(
            PickedGalleryMedia.fromJson(Map<String, dynamic>.from(json as Map)),
          );
        }
        page = response['nextPageToken'] as String?;
        if (page != null && page.isNotEmpty && !pages.add(page)) {
          throw const GalleryFailure('تكررت صفحة نتائج Google Photos.');
        }
      } while (page != null && page.isNotEmpty);
    } finally {
      if (sessionId != null &&
          RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sessionId)) {
        try {
          await _api('DELETE', 'sessions/$sessionId', token, CancelToken());
        } catch (_) {
          /* Session expires at Google's deadline. */
        }
      }
    }
  }

  Future<void> download(
    PickedGalleryMedia item,
    String token,
    File target,
    CancelToken cancel,
  ) async {
    if (!item.videoReady) {
      throw const GalleryFailure(
        'الفيديو ما زال قيد المعالجة في Google Photos.',
      );
    }
    final video = item.mime.startsWith('video/');
    var uri = contentUri(item.baseUrl, video);
    final limit = video
        ? GalleryStore.maxVideoBytes
        : GalleryStore.maxPhotoBytes;
    var completed = false;
    try {
      for (var redirects = 0; redirects <= 3; redirects++) {
        final response = await _client.get<ResponseBody>(
          uri.toString(),
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (_) => true,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          await response.data?.stream.listen((_) {}).cancel();
          final location = response.headers.value('location');
          if (redirects == 3 || location == null) {
            throw const GalleryFailure('تعذر تنزيل ملف Google Photos.');
          }
          final next = uri.resolve(location);
          // Validate the redirect before forwarding the Google bearer token.
          contentUri(next.toString(), video);
          uri = next;
          continue;
        }
        if (response.statusCode != 200) {
          await response.data?.stream.listen((_) {}).cancel();
          _checkStatus(response.statusCode);
          throw const GalleryFailure('استجابة تنزيل غير مكتملة.');
        }
        final body = response.data;
        if (body == null) throw const GalleryFailure('الملف المستلم فارغ.');
        final advertised = int.tryParse(
          response.headers.value('content-length') ?? '',
        );
        if (advertised != null && advertised > limit) {
          await body.stream.listen((_) {}).cancel();
          throw const GalleryFailure('الملف أكبر من الحد المسموح للاستيراد.');
        }
        final sink = target.openWrite();
        try {
          var size = 0;
          final deadline = _now().add(const Duration(minutes: 10));
          await for (final chunk in body.stream.timeout(
            const Duration(seconds: 90),
          )) {
            if (cancel.isCancelled) throw cancel.cancelError!;
            size += chunk.length;
            if (size > limit || _now().isAfter(deadline)) {
              throw const GalleryFailure('تجاوز التنزيل حد الحجم أو الوقت.');
            }
            sink.add(chunk);
          }
          if (size == 0 || (advertised != null && size != advertised)) {
            throw const GalleryFailure('لم يكتمل تنزيل الملف.');
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        completed = true;
        return;
      }
    } finally {
      if (!completed && await target.exists()) await target.delete();
    }
  }
}
