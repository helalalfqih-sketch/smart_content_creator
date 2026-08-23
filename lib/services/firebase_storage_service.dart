import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 📁 خدمة إدارة تخزين الملفات في Firebase Storage
class FirebaseStorageService extends GetxService {
  // ✅ Use default instance which follows google-services.json
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 📤 رفع صورة إلى مسار محدد والحصول على رابط التحميل
  Future<String?> uploadProfileImage({
    required String uid,
    required File file,
    required bool isProfile,
  }) async {
    try {
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: ${file.path}');
        return null;
      }

      final String folder = isProfile ? 'profile_photos' : 'cover_photos';
      final String extension = file.path.split('.').last.toLowerCase();
      final String fileName = '$uid.$extension';
      final String filePath = '$folder/$fileName';

      debugPrint('🚀 Starting upload to: $filePath');
      final ref = _storage.ref().child(filePath);

      // ✅ Read file as bytes to ensure access and use putData
      final bytes = await file.readAsBytes();
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        if (kDebugMode) {
          debugPrint('✅ Upload successful: $downloadUrl');
        }
        return downloadUrl;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Storage Upload Error Details: $e');
      }
      return null;
    }
  }

  /// 🧪 رفع صورة مؤقتة للفحص الجنائي والحصول على رابط عام (لـ SerpApi)
  Future<String?> uploadTemporaryImage(File file, {dio.CancelToken? cancelToken}) async {
    try {
      if (!await file.exists()) return null;

      final String extension = file.path.split('.').last.toLowerCase();
      final String fileName = 'forensic_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String filePath = 'temp_forensic/$fileName';

      debugPrint('🚀 Firebase Storage Bucket: ${_storage.bucket}');
      debugPrint('🚀 Uploading temporary forensic image to: $filePath');
      final ref = _storage.ref().child(filePath);
      
      // ✅ Use putData instead of putFile for better reliability on all platforms
      final bytes = await file.readAsBytes();
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );

      if (uploadTask.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Temp Upload Error: $e');
      return null;
    }
  }

  /// 📤 رفع صورة أو فيديو منتج للكتالوج إلى Firebase Storage
  /// يُرجع رابط التحميل المباشر
  Future<String?> uploadProductMedia({
    required String uid,
    required File file,
    required String mediaType, // 'image' أو 'video'
  }) async {
    try {
      if (!await file.exists()) return null;

      final ext = file.path.split('.').last.toLowerCase();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('\\').last}';
      final filePath = 'users/$uid/catalog_media/$fileName';

      debugPrint('🚀 Uploading catalog $mediaType to: $filePath');
      final bytes = await file.readAsBytes();
      final contentType = mediaType == 'video' ? 'video/$ext' : 'image/$ext';

      final List<FirebaseStorage> storageTargets = [
        _storage,
        FirebaseStorage.instanceFor(bucket: 'smartcontentcreator2.appspot.com'),
        FirebaseStorage.instanceFor(bucket: 'smartcontentcreator2.firebasestorage.app'),
      ];

      for (final storage in storageTargets) {
        try {
          final ref = storage.ref().child(filePath);
          final uploadTask = await ref.putData(
            bytes,
            SettableMetadata(contentType: contentType),
          );

          if (uploadTask.state == TaskState.success) {
            final url = await ref.getDownloadURL();
            debugPrint('✅ Catalog media uploaded successfully to Firebase Storage: $url');
            return url;
          }
        } catch (bucketError) {
          debugPrint('⚠️ Storage attempt for bucket (${storage.bucket}) failed: $bucketError');
        }
      }

      // 🔄 Fallback المباشر: الرفع إلى Back4App Parse Files لضمان توفر الرابط دائماً
      debugPrint('🚀 Falling back to Back4App Parse File storage for $mediaType...');
      final b4aUrl = await _uploadToBack4AppFiles(bytes, fileName, contentType);
      if (b4aUrl != null) {
        debugPrint('✅ Catalog media uploaded successfully to Back4App: $b4aUrl');
        return b4aUrl;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Catalog media upload error: $e');
      return null;
    }
  }

  /// ☁️ رفع ملف إلى Parse Files في Back4App كخطة احتياطية فائقة الموثوقية
  Future<String?> _uploadToBack4AppFiles(List<int> bytes, String fileName, String mimeType) async {
    try {
      final uri = Uri.parse('https://parseapi.back4app.com/files/$fileName');
      final response = await http.post(
        uri,
        headers: {
          'X-Parse-Application-Id': 'uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2',
          'X-Parse-REST-API-Key': 'Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp',
          'Content-Type': mimeType,
        },
        body: bytes,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final url = (data is Map) ? data['url'] as String? : null;
        if (url != null && url.startsWith('http')) {
          return url;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Back4App Parse Files fallback error: $e');
    }
    return null;
  }

  /// 📑 رفع ملف CSV للكتالوج إلى Firebase Storage (مسار عالمي موحد)
  /// يُرجع رابط التحميل المباشر القابل للمشاركة مع Meta Commerce Manager
  Future<String?> uploadCatalogFeed({
    required String uid,
    required String csvContent,
  }) async {
    try {
      final filePath = 'catalogs/$uid/catalog.csv';
      debugPrint('🚀 Uploading catalog CSV feed to: $filePath');
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final metadata = SettableMetadata(
        contentType: 'text/csv; charset=utf-8',
        customMetadata: {
          'uploaded_by': uid,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      final List<FirebaseStorage> storageTargets = [
        _storage,
        FirebaseStorage.instanceFor(bucket: 'smartcontentcreator2.appspot.com'),
        FirebaseStorage.instanceFor(bucket: 'smartcontentcreator2.firebasestorage.app'),
      ];

      for (final storage in storageTargets) {
        try {
          final ref = storage.ref().child(filePath);
          final uploadTask = await ref.putData(bytes, metadata);

          if (uploadTask.state == TaskState.success) {
            final url = await ref.getDownloadURL();
            debugPrint('✅ Global Catalog feed uploaded successfully: $url');
            return url;
          }
        } catch (bucketError) {
          debugPrint('⚠️ Storage attempt for catalog CSV (${storage.bucket}) failed: $bucketError');
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Global Catalog feed upload error: $e');
      return null;
    }
  }
}
