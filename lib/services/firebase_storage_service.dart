import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
}
