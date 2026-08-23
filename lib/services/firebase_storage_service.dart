import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 📁 خدمة إدارة تخزين الملفات في Firebase Storage
class FirebaseStorageService extends GetxService {
  // ✅ Use default instance which follows active Firebase configuration
  final FirebaseStorage _storage = FirebaseStorage.instance;

  void _logStorageConfig() {
    try {
      final projectId = Firebase.app().options.projectId;
      final bucket = _storage.bucket;
      debugPrint('[FIREBASE_STORAGE_CONFIG] projectId=$projectId bucket=$bucket');
    } catch (_) {}
  }

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

      _logStorageConfig();
      final String folder = isProfile ? 'profile_photos' : 'cover_photos';
      final String extension = file.path.split('.').last.toLowerCase();
      final String fileName = '$uid.$extension';
      final String filePath = '$folder/$fileName';

      debugPrint('🚀 Starting upload to: $filePath');
      final ref = _storage.ref().child(filePath);

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

      _logStorageConfig();
      final String extension = file.path.split('.').last.toLowerCase();
      final String fileName = 'forensic_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String filePath = 'temp_forensic/$fileName';

      debugPrint('🚀 Uploading temporary forensic image to: $filePath');
      final ref = _storage.ref().child(filePath);
      
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

      _logStorageConfig();
      final ext = file.path.split('.').last.toLowerCase();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('\\').last}';
      final filePath = 'users/$uid/catalog_media/$fileName';

      debugPrint('🚀 Uploading catalog $mediaType to: $filePath');
      final ref = _storage.ref().child(filePath);
      final bytes = await file.readAsBytes();
      final contentType = mediaType == 'video' ? 'video/$ext' : 'image/$ext';

      try {
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );

        if (uploadTask.state == TaskState.success) {
          final url = await ref.getDownloadURL();
          debugPrint('[CATALOG_MEDIA_UPLOAD] type=$mediaType status=success url=$url');
          return url;
        }
      } catch (storageError) {
        debugPrint('⚠️ Firebase Storage upload failed ($storageError). Retrying via authenticated Cloud Code...');
      }

      // ☁️ الرفع الاحتياطي الآمن عبر Cloud Code المشفر بمصادقة Firebase Token
      debugPrint('🚀 Falling back to authenticated Back4App Cloud Code for $mediaType...');
      final cloudUrl = await _uploadViaBack4AppCloudCode(bytes, fileName, contentType);
      if (cloudUrl != null) {
        debugPrint('[CATALOG_MEDIA_UPLOAD] type=$mediaType status=success url=$cloudUrl');
        return cloudUrl;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Catalog media upload error: $e');
      return null;
    }
  }

  /// ☁️ رفع ملف عبر Cloud Code الآمن بدون أي مفاتيح سرية في Flutter
  Future<String?> _uploadViaBack4AppCloudCode(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final base64Data = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://parseapi.back4app.com/functions/catalogUploadMedia'),
        headers: {
          'X-Parse-Application-Id': 'uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'fileBase64': base64Data,
          'fileName': fileName,
          'mimeType': mimeType,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['result']?['url'] as String?;
        if (url != null && url.startsWith('http')) {
          return url;
        }
      } else {
        debugPrint('⚠️ catalogUploadMedia returned HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ Back4App Cloud Code media upload fallback error: $e');
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
      _logStorageConfig();
      final filePath = 'catalogs/$uid/catalog.csv';
      debugPrint('🚀 Uploading catalog CSV feed to: $filePath');

      final ref = _storage.ref().child(filePath);
      final uploadTask = await ref.putData(
        Uint8List.fromList(utf8.encode(csvContent)),
        SettableMetadata(
          contentType: 'text/csv; charset=utf-8',
          customMetadata: {
            'uploaded_by': uid,
            'uploaded_at': DateTime.now().toIso8601String(),
          },
        ),
      );

      if (uploadTask.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        debugPrint('✅ Global Catalog feed uploaded successfully: $url');
        return url;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Global Catalog feed upload error: $e');
      return null;
    }
  }
}
