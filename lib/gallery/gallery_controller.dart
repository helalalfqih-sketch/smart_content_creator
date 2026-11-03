import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/utils/ai_request_exception.dart';
import 'gallery_analyzer.dart';
import 'gallery_item.dart';
import 'gallery_store.dart';

class GalleryController extends ChangeNotifier {
  final GalleryStore store;
  final bool Function() accountIsCurrent;
  final String Function() readKey;
  GalleryController({
    required this.store,
    required this.accountIsCurrent,
    required this.readKey,
  });
  List<GalleryItem> items = [];
  List<String> albums = [];
  Set<String> similar = {};
  final selected = <String>{};
  String query = '', sort = 'newest', filter = 'all';
  String? album;
  bool onlySimilar = false, busy = false, locked = false;
  bool _disposed = false;
  String status = '';
  CancelToken? _cancel;
  Future<void>? _task;
  List<GalleryItem> get selection =>
      items.where((x) => selected.contains(x.id)).toList();
  List<GalleryItem> get visible {
    final needle = query.trim().toLowerCase();
    final result = items
        .where(
          (x) =>
              (album == null || x.album == album) &&
              (filter == 'all' ||
                  (filter == 'video' ? x.isVideo : !x.isVideo)) &&
              (!onlySimilar || similar.contains(x.id)) &&
              (needle.isEmpty ||
                  [
                    x.name,
                    x.originalName,
                    x.analysis?.description ?? '',
                    x.analysis?.text ?? '',
                    x.analysis?.category ?? '',
                    ...?x.analysis?.tags,
                  ].any((s) => s.toLowerCase().contains(needle))),
        )
        .toList();
    result.sort(
      (a, b) => switch (sort) {
        'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        'oldest' => a.importedAt.compareTo(b.importedAt),
        'type' => a.mimeType.compareTo(b.mimeType),
        _ => b.importedAt.compareTo(a.importedAt),
      },
    );
    return result;
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  void cancel() {
    _cancel?.cancel();
  }

  void lockIfAccountChanged() {
    if (!accountIsCurrent()) {
      locked = true;
      cancel();
      selected.clear();
      items = [];
      changed();
    }
  }

  bool get cancelled =>
      _disposed ||
      locked ||
      !accountIsCurrent() ||
      (_cancel?.isCancelled ?? false);
  void _check() {
    if (cancelled) {
      throw const GalleryFailure('أُوقفت العملية. النتائج المكتملة محفوظة.');
    }
  }

  Future<void> refresh() async {
    if (_disposed || !accountIsCurrent()) return;
    items = await store.list();
    albums = await store.albums();
    similar = await compute(similarGalleryIds, items);
    selected.removeWhere((id) => !items.any((x) => x.id == id));
    changed();
  }

  void toggle(GalleryItem item) {
    if (busy) return;
    if (!selected.add(item.id)) selected.remove(item.id);
    changed();
  }

  void setStatus(String text) {
    status = text;
    changed();
  }

  Future<void> run(Future<void> Function() operation) {
    if (busy || locked || _disposed) return Future.value();
    busy = true;
    _cancel = CancelToken();
    changed();
    final future = _run(operation);
    _task = future;
    return future;
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      _check();
      await operation();
    } catch (error) {
      setStatus(safeError(error));
    } finally {
      try {
        if (!_disposed && accountIsCurrent()) await refresh();
      } catch (_) {
        setStatus(
          'تعذر قراءة مكتبة الصور. تحقق من مساحة الهاتف وأعد فتح المعرض.',
        );
      }
      busy = false;
      _cancel = null;
      changed();
    }
  }

  static String safeError(Object error) {
    if (error is GalleryFailure) return error.message;
    if (error is AiRequestException) return error.message;
    if (error is DioException && CancelToken.isCancel(error)) {
      return 'أُوقفت العملية. النتائج المكتملة محفوظة.';
    }
    if (error is DioException ||
        error is SocketException ||
        error is TimeoutException) {
      return 'تعذر الاتصال. تحقق من الإنترنت ثم أعد المحاولة؛ النتائج المكتملة محفوظة.';
    }
    if (error is FileSystemException) {
      return 'تعذر حفظ الملف. تحقق من المساحة المتاحة على الهاتف.';
    }
    if (error is PlatformException) {
      return 'تعذر فتح الملف أو منتقي الصور. تحقق من صلاحيات التطبيق ثم أعد المحاولة.';
    }
    return 'لم تكتمل العملية. أعد فتح المعرض وحاول مجدداً.';
  }

  Future<void> importPhone() => run(() async {
    setStatus('اختر الصور والفيديوهات من الهاتف.');
    final pending = File('${store.root.path}/phone-selection.pending');
    await pending.writeAsString('selected');
    try {
      final files = await ImagePicker().pickMultipleMedia(
        limit: 100,
        requestFullMetadata: false,
      );
      _check();
      await importPicked(files);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  });

  Future<void> recoverPhoneSelection() async {
    if (!Platform.isAndroid) return;
    final pending = File('${store.root.path}/phone-selection.pending');
    if (!await pending.exists()) return;
    await run(() async {
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (lost.exception != null) throw lost.exception!;
        if (lost.files != null) await importPicked(lost.files!);
      } finally {
        if (await pending.exists()) await pending.delete();
      }
    });
  }

  Future<void> importPicked(List<XFile> files) async {
    if (files.isEmpty) {
      setStatus('لم تُحدد ملفات للاستيراد.');
      return;
    }
    var imported = 0, duplicates = 0, failed = 0;
    String? reason;
    for (final file in files.take(100)) {
      _check();
      setStatus(
        'استيراد ${imported + duplicates + failed + 1} / ${files.length.clamp(0, 100)}…',
      );
      try {
        final result = await store.importFile(
          File(file.path),
          name: file.name,
          source: 'phone',
          mimeType: file.mimeType,
          cancelled: () => cancelled,
        );
        if (result.duplicate) {
          duplicates++;
        } else {
          imported++;
        }
      } catch (e) {
        _check();
        failed++;
        reason = safeError(e);
      }
    }
    setStatus(
      'استُورد $imported • مكرر $duplicates • تعذر $failed${reason == null ? '' : '\n$reason'}',
    );
  }

  Future<void> analyze(List<GalleryItem> chosen) => run(() async {
    final photos = chosen.where((x) => !x.isVideo).toList();
    if (photos.isEmpty || photos.length > 20) {
      throw const GalleryFailure(
        'حدد من 1 إلى 20 صورة للتحليل. تحليل الفيديو غير متاح.',
      );
    }
    final key = readKey();
    if (key.trim().isEmpty) {
      throw const GalleryFailure(
        'أضف مفتاح OpenRouter من إعدادات الخدمات أولاً.',
      );
    }
    final analyzer = GalleryAnalyzer();
    var completed = 0;
    for (final item in photos) {
      _check();
      setStatus('OpenRouter: تحليل ${completed + 1} / ${photos.length}…');
      final analysis = await analyzer.analyze(
        store.mediaFile(item).path,
        key,
        _cancel!,
      );
      _check();
      await store.saveAnalysis(item.id, analysis);
      completed++;
    }
    setStatus(
      'حُفظ تحليل $completed صورة. راجع النتائج والأسماء المقترحة قبل اعتمادها.',
    );
  });

  Future<void> rename(Map<String, String> names) => run(() async {
    await store.rename(names);
    setStatus('حُفظت أسماء ${names.length} نسخة داخل المعرض.');
  });
  Future<void> deleteSelected(List<GalleryItem> chosen) => run(() async {
    await store.deleteCopies(chosen);
    selected.clear();
    setStatus('حُذفت ${chosen.length} نسخة من التطبيق. الصور الأصلية محفوظة.');
  });
  Future<void> move(List<GalleryItem> chosen, String? album) => run(() async {
    await store.moveToAlbum(chosen.map((x) => x.id).toList(), album);
    setStatus(
      album == null
          ? 'أُزيلت الصور من الألبوم.'
          : 'أُضيفت ${chosen.length} نسخة إلى $album.',
    );
  });

  @override
  void dispose() {
    _disposed = true;
    cancel();
    // Let an in-flight import finish cleanup before closing SQLite.
    unawaited((_task ?? Future<void>.value()).then((_) => store.close()));
    super.dispose();
  }
}
