import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'gallery_item.dart';

String galleryImageHash(Uint8List thumbnail) {
  final decoded = img.decodeImage(thumbnail);
  if (decoded == null) return '';
  final small = img.copyResize(decoded, width: 9, height: 8);
  var hash = BigInt.zero;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      hash =
          (hash << 1) |
          (img.getLuminance(small.getPixel(x, y)) >
                  img.getLuminance(small.getPixel(x + 1, y))
              ? BigInt.one
              : BigInt.zero);
    }
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

class GalleryImportResult {
  final bool duplicate;
  final String id;
  const GalleryImportResult(this.id, {this.duplicate = false});
}

/// One database and private file directory per app account. Google tokens,
/// API keys and Google download URLs are never persisted here.
class GalleryStore {
  final Directory root;
  final Database db;
  GalleryStore._(this.root, this.db);
  static const maxPhotoBytes = 40 * 1024 * 1024;
  static const maxVideoBytes = 512 * 1024 * 1024;
  static const schema = '''CREATE TABLE media (
    id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
    original_name TEXT NOT NULL, extension TEXT NOT NULL, mime_type TEXT NOT NULL,
    source TEXT NOT NULL, digest TEXT NOT NULL UNIQUE, imported_at INTEGER NOT NULL,
    captured_at INTEGER, bytes INTEGER NOT NULL, album TEXT,
    perceptual_hash TEXT, analysis TEXT)''';

  static Future<GalleryStore> open(String owner, {Directory? documents}) async {
    final base = documents ?? await getApplicationDocumentsDirectory();
    final ownerHash = sha256.convert(utf8.encode(owner)).toString();
    final root = Directory(p.join(base.path, 'smart_gallery', ownerHash));
    await root.create(recursive: true);
    for (final child in ['media', 'thumbs', 'staging', 'exports']) {
      await Directory(p.join(root.path, child)).create();
    }
    final db = await openDatabase(
      p.join(root.path, 'gallery.sqlite'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(schema);
        await db.execute(
          'CREATE TABLE albums (name TEXT PRIMARY KEY COLLATE NOCASE)',
        );
        await db.execute('CREATE INDEX media_album ON media(album)');
        for (final name in [
          'المنتجات',
          'الإلكترونيات',
          'الطبيعة',
          'المستندات',
        ]) {
          await db.insert('albums', {'name': name});
        }
      },
    );
    final store = GalleryStore._(root, db);
    await store._recover();
    return store;
  }

  String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  File mediaFile(GalleryItem item) =>
      File(p.join(root.path, 'media', item.storedName));
  File thumbnailFile(GalleryItem item) =>
      File(p.join(root.path, 'thumbs', '${item.id}.jpg'));
  Future<File> temporaryFile() async =>
      File(p.join(root.path, 'staging', '${_id()}.part'));
  Future<List<GalleryItem>> list() async => (await db.query(
    'media',
    orderBy: 'imported_at DESC, id',
  )).map(GalleryItem.fromRow).toList();
  Future<List<String>> albums() async => (await db.query(
    'albums',
    orderBy: 'name',
  )).map((x) => x['name'] as String).toList();

  static (String, String) format(String name, String? mime) {
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'avif': 'image/avif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'm4v': 'video/mp4',
      'webm': 'video/webm',
      '3gp': 'video/3gpp',
    };
    if (types.containsKey(ext)) return (ext, types[ext]!);
    final matching = types.entries.where((x) => x.value == mime);
    if (matching.isNotEmpty) return (matching.first.key, matching.first.value);
    throw const GalleryFailure(
      'صيغة غير مدعومة. اختر صورة أو فيديو قابلاً للعرض على الهاتف.',
    );
  }

  Future<GalleryImportResult> importFile(
    File sourceFile, {
    required String name,
    required String source,
    String? mimeType,
    DateTime? capturedAt,
    required bool Function() cancelled,
  }) async {
    final (ext, mime) = format(name, mimeType);
    final video = mime.startsWith('video/');
    final limit = video ? maxVideoBytes : maxPhotoBytes;
    final length = await sourceFile.length();
    if (length <= 0 || length > limit) {
      throw GalleryFailure(
        video ? 'حد الفيديو 512 ميغابايت.' : 'حد الصورة 40 ميغابايت.',
      );
    }
    final id = _id();
    final staged = await temporaryFile();
    final target = File(p.join(root.path, 'media', '$id.$ext'));
    final thumb = File(p.join(root.path, 'thumbs', '$id.jpg'));
    var committed = false;
    try {
      final sink = staged.openWrite();
      try {
        var size = 0;
        await for (final chunk in sourceFile.openRead()) {
          if (cancelled()) throw const GalleryFailure('أُلغي الاستيراد.');
          size += chunk.length;
          if (size > limit) {
            throw const GalleryFailure('الملف أكبر من الحد المسموح.');
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final digest = (await sha256.bind(staged.openRead()).first).toString();
      final duplicate = await db.query(
        'media',
        columns: ['id'],
        where: 'digest = ?',
        whereArgs: [digest],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        return GalleryImportResult(
          duplicate.first['id'] as String,
          duplicate: true,
        );
      }
      await staged.rename(target.path);
      Uint8List? preview;
      if (video) {
        preview = await VideoThumbnail.thumbnailData(
          video: target.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 70,
        );
      } else {
        preview = await FlutterImageCompress.compressWithFile(
          target.path,
          minWidth: 480,
          minHeight: 480,
          quality: 70,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
      }
      if (preview == null || preview.isEmpty) {
        throw const GalleryFailure(
          'تعذر قراءة هذا الملف. استخدم صيغة يدعمها الهاتف.',
        );
      }
      await thumb.writeAsBytes(preview, flush: true);
      final hash = video ? null : await compute(galleryImageHash, preview);
      if (cancelled()) throw const GalleryFailure('أُلغي الاستيراد.');
      final used = (await db.query(
        'media',
        columns: ['name'],
      )).map((x) => (x['name'] as String).toLowerCase()).toSet();
      await db.insert('media', {
        'id': id,
        'name': availableGalleryName(name, ext, used),
        'original_name': galleryFileName(name, ext),
        'extension': ext,
        'mime_type': mime,
        'source': source,
        'digest': digest,
        'imported_at': DateTime.now().millisecondsSinceEpoch,
        'captured_at': capturedAt?.millisecondsSinceEpoch,
        'bytes': await target.length(),
        'perceptual_hash': hash == '' ? null : hash,
      });
      committed = true;
      return GalleryImportResult(id);
    } finally {
      if (await staged.exists()) await staged.delete();
      if (!committed) {
        if (await target.exists()) await target.delete();
        if (await thumb.exists()) await thumb.delete();
      }
    }
  }

  Future<void> rename(Map<String, String> names) async {
    await db.transaction((tx) async {
      final rows = (await tx.query('media')).map(GalleryItem.fromRow).toList();
      final selected = rows.where((x) => names.containsKey(x.id)).toList();
      if (selected.length != names.length) {
        throw const GalleryFailure(
          'تغيرت المكتبة؛ افتح معاينة الأسماء مجدداً.',
        );
      }
      final plan = planGalleryRename(rows, selected, names);
      // Reject stale previews instead of silently changing approved names.
      if (plan.entries.any((x) => names[x.key] != x.value)) {
        throw const GalleryFailure(
          'اسم متكرر أو غير صالح. راجع معاينة الأسماء مجدداً.',
        );
      }
      for (final id in names.keys) {
        await tx.update(
          'media',
          {'name': '.rename_$id'},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      for (final entry in names.entries) {
        await tx.update(
          'media',
          {'name': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });
  }

  Future<void> saveAnalysis(String id, GalleryAnalysis analysis) => db.update(
    'media',
    {'analysis': jsonEncode(analysis.toJson())},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> createAlbum(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.runes.length > 60) {
      throw const GalleryFailure('اسم الألبوم من 1 إلى 60 حرفاً.');
    }
    await db.insert('albums', {
      'name': clean,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> moveToAlbum(List<String> ids, String? album) async {
    await db.transaction((tx) async {
      if (album != null &&
          (await tx.query(
            'albums',
            where: 'name = ?',
            whereArgs: [album],
          )).isEmpty) {
        throw const GalleryFailure('الألبوم غير موجود.');
      }
      for (final id in ids) {
        await tx.update(
          'media',
          {'album': album},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> removeAlbum(String album) async => db.transaction((tx) async {
    await tx.update(
      'media',
      {'album': null},
      where: 'album = ?',
      whereArgs: [album],
    );
    await tx.delete('albums', where: 'name = ?', whereArgs: [album]);
  });

  Future<void> deleteCopies(List<GalleryItem> items) async {
    await db.transaction((tx) async {
      for (final item in items) {
        await tx.delete('media', where: 'id = ?', whereArgs: [item.id]);
      }
    });
    // Unreferenced files are also removed on next open if the process dies here.
    await _recover();
  }

  Future<List<File>> exportCopies(
    List<GalleryItem> items,
    bool Function() cancelled,
  ) async {
    final directory = await Directory(
      p.join(root.path, 'exports', _id()),
    ).create();
    final files = <File>[];
    try {
      for (final item in items) {
        if (cancelled()) throw const GalleryFailure('أُلغي التصدير.');
        final name = galleryFileName(item.name, item.extension);
        files.add(await mediaFile(item).copy(p.join(directory.path, name)));
      }
      return files;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _recover() async {
    final rows = await list();
    final media = rows.map((x) => x.storedName).toSet();
    final thumbs = rows.map((x) => '${x.id}.jpg').toSet();
    for (final pair in [
      ('media', media),
      ('thumbs', thumbs),
      ('staging', <String>{}),
    ]) {
      await for (final file in Directory(
        p.join(root.path, pair.$1),
      ).list(followLinks: false)) {
        if (file is File && !pair.$2.contains(p.basename(file.path))) {
          await file.delete();
        }
      }
    }
    // Exported copies are disposable and must not survive deletion of a photo.
    final exports = Directory(p.join(root.path, 'exports'));
    await for (final entry in exports.list(followLinks: false)) {
      if (entry is Directory) await entry.delete(recursive: true);
    }
  }

  Future<void> close() => db.close();
}
