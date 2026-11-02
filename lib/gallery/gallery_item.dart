import 'dart:convert';

class GalleryFailure implements Exception {
  final String message;
  const GalleryFailure(this.message);
  @override
  String toString() => message;
}

/// All names are display/export names. Originals and immutable storage IDs
/// are never renamed using user input or model output.
String galleryFileName(String input, String extension) {
  var name = input.trim().replaceAll(
    RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|\u202a-\u202e\u2066-\u2069]'),
    '_',
  );
  final ext = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (ext.isEmpty) throw const GalleryFailure('صيغة الملف غير معروفة.');
  if (name.toLowerCase().endsWith('.$ext'))
    name = name.substring(0, name.length - ext.length - 1);
  name = name
      .replaceAll(RegExp(r'^\.+|[.\s]+$'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  name = String.fromCharCodes(name.runes.take(70));
  if (name.isEmpty) name = 'صورة';
  if (RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
    caseSensitive: false,
  ).hasMatch(name))
    name = 'ملف_$name';
  return '$name.$ext';
}

String availableGalleryName(
  String proposed,
  String extension,
  Set<String> used,
) {
  final first = galleryFileName(proposed, extension);
  var candidate = first;
  var index = 2;
  while (used.contains(candidate.toLowerCase())) {
    candidate =
        '${first.substring(0, first.lastIndexOf('.'))}_${index++}.${extension.toLowerCase()}';
  }
  used.add(candidate.toLowerCase());
  return candidate;
}

class GalleryAnalysis {
  final String description, category, text, suggestedName;
  final List<String> tags;
  const GalleryAnalysis({
    required this.description,
    required this.category,
    required this.text,
    required this.suggestedName,
    required this.tags,
  });

  factory GalleryAnalysis.parse(String response) {
    if (response.length > 40000)
      throw const GalleryFailure('نتيجة التحليل أكبر من الحد المسموح.');
    var raw = response.trim();
    if (raw.startsWith('```')) {
      raw = raw
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      throw const GalleryFailure(
        'لم يُرجع OpenRouter تحليلاً منظماً صالحاً. لم تتغير الأسماء.',
      );
    }
    if (data is! Map) throw const GalleryFailure('استجابة التحليل غير صالحة.');
    String field(String key, int max, {bool required = false}) {
      final value = data is Map ? data[key] : null;
      if (value is! String || (required && value.trim().isEmpty)) {
        throw const GalleryFailure(
          'نتيجة التحليل غير مكتملة. لم تتغير الأسماء.',
        );
      }
      return String.fromCharCodes(value.trim().runes.take(max));
    }

    final tags = data['tags'];
    if (tags is! List || tags.any((tag) => tag is! String))
      throw const GalleryFailure('وسوم التحليل غير صالحة.');
    return GalleryAnalysis(
      description: field('description', 2400, required: true),
      category: field('category', 80),
      text: field('text', 8000),
      suggestedName: field('suggested_name', 100, required: true),
      tags: tags
          .cast<String>()
          .map((s) => String.fromCharCodes(s.trim().runes.take(60)))
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(20)
          .toList(),
    );
  }

  Map<String, Object> toJson() => {
    'description': description,
    'category': category,
    'text': text,
    'suggested_name': suggestedName,
    'tags': tags,
  };
}

class GalleryItem {
  final String id, name, originalName, extension, mimeType, source, digest;
  final int importedAt, bytes;
  final String? album, perceptualHash;
  final int? capturedAt;
  final GalleryAnalysis? analysis;
  bool get isVideo => mimeType.startsWith('video/');
  String get storedName => '$id.$extension';
  const GalleryItem({
    required this.id,
    required this.name,
    required this.originalName,
    required this.extension,
    required this.mimeType,
    required this.source,
    required this.digest,
    required this.importedAt,
    required this.bytes,
    this.album,
    this.perceptualHash,
    this.capturedAt,
    this.analysis,
  });

  factory GalleryItem.fromRow(Map<String, Object?> row) => GalleryItem(
    id: row['id'] as String,
    name: row['name'] as String,
    originalName: row['original_name'] as String,
    extension: row['extension'] as String,
    mimeType: row['mime_type'] as String,
    source: row['source'] as String,
    digest: row['digest'] as String,
    importedAt: row['imported_at'] as int,
    bytes: row['bytes'] as int,
    album: row['album'] as String?,
    perceptualHash: row['perceptual_hash'] as String?,
    capturedAt: row['captured_at'] as int?,
    analysis: row['analysis'] == null
        ? null
        : GalleryAnalysis.parse(row['analysis'] as String),
  );
}

Map<String, String> planGalleryRename(
  List<GalleryItem> all,
  List<GalleryItem> selected,
  Map<String, String> proposals,
) {
  final ids = selected.map((x) => x.id).toSet();
  final used = all
      .where((x) => !ids.contains(x.id))
      .map((x) => x.name.toLowerCase())
      .toSet();
  return {
    for (final item in selected)
      item.id: availableGalleryName(
        proposals[item.id] ?? item.name,
        item.extension,
        used,
      ),
  };
}

int galleryHashDistance(String a, String b) {
  if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(a) ||
      !RegExp(r'^[0-9a-f]{16}$').hasMatch(b))
    return 65;
  var bits = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  var count = 0;
  while (bits != BigInt.zero) {
    bits &= bits - BigInt.one;
    count++;
  }
  return count;
}

/// A deterministic, conservative candidate index, never an automatic deletion.
Set<String> similarGalleryIds(List<GalleryItem> items) {
  final photos = items
      .where((x) => !x.isVideo && x.perceptualHash != null)
      .toList();
  final ids = <String>{};
  // Index the four 16-bit blocks. Distance <= 3 guarantees one equal block.
  final buckets = <String, List<GalleryItem>>{};
  for (final item in photos) {
    final hash = item.perceptualHash!;
    if (hash.length != 16) continue;
    final candidates = <String, GalleryItem>{};
    for (var block = 0; block < 4; block++) {
      final key = '$block:${hash.substring(block * 4, block * 4 + 4)}';
      for (final other in buckets[key] ?? <GalleryItem>[]) {
        candidates[other.id] = other;
      }
      (buckets[key] ??= []).add(item);
    }
    for (final other in candidates.values) {
      if (galleryHashDistance(hash, other.perceptualHash!) <= 3) {
        ids.add(item.id);
        ids.add(other.id);
      }
    }
  }
  return ids;
}
