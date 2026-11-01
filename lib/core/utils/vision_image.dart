import 'dart:typed_data';

/// Detect the uploaded bytes, not the filename: compression may change format.
String? visionImageMimeType(Uint8List bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (startsWith([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10])) return 'image/png';
  if (startsWith([71, 73, 70, 56, 55, 97]) ||
      startsWith([71, 73, 70, 56, 57, 97]))
    return 'image/gif';
  if (bytes.length >= 12 &&
      startsWith([82, 73, 70, 70]) &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return 'image/webp';
  }
  return null;
}
