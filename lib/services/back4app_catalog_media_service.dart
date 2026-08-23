import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// ☁️ Back4AppCatalogMediaService
/// خدمة مخصصة وحصرية لإدارة وسائط وتغذية الكتالوج (Catalog Media & Feeds)
/// عبر خوادم Back4App Cloud Code و Parse Files دون استخدام Firebase Storage
class Back4AppCatalogMediaService extends GetxService {
  static const String _parseAppId = 'uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2';
  static const String _parseRestKey = 'Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp';
  static const String _parseBaseUrl = 'https://parseapi.back4app.com/functions';

  Map<String, String> get _headers => {
    'X-Parse-Application-Id': _parseAppId,
    'X-Parse-REST-API-Key': _parseRestKey,
    'Content-Type': 'application/json',
  };

  /// 🔑 الحصول على التوكن الموثق للمستخدم
  Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return await user?.getIdToken(true);
    } catch (e) {
      debugPrint('⚠️ Back4AppCatalogMediaService: Failed to get auth token: $e');
      return null;
    }
  }

  /// 📤 رفع صورة أو فيديو للمنتج مباشرة إلى Back4App Parse Files
  Future<String?> uploadProductMedia({
    required File file,
    required String mediaType, // 'image' or 'video'
    String? uid,
  }) async {
    try {
      if (!await file.exists()) {
        debugPrint('❌ [CATALOG_MEDIA_UPLOAD] File does not exist: ${file.path}');
        return null;
      }

      final ext = file.path.split('.').last.toLowerCase();
      final originalName = file.path.split('/').last.split('\\').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final mimeType = mediaType == 'video' ? 'video/$ext' : 'image/$ext';

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final token = await _getAuthToken();

      final response = await http.post(
        Uri.parse('$_parseBaseUrl/catalogUploadMedia'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'fileBase64': base64Data,
          'fileName': fileName,
          'mimeType': mimeType,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['result']?['url'] as String?;
        if (url != null && url.startsWith('http')) {
          debugPrint('[CATALOG_MEDIA_UPLOAD] backend=back4app type=$mediaType status=success url=$url');
          return url;
        }
      }

      debugPrint('❌ [CATALOG_MEDIA_UPLOAD] backend=back4app type=$mediaType status=${response.statusCode} error=${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ [CATALOG_MEDIA_UPLOAD] backend=back4app type=$mediaType exception=$e');
      return null;
    }
  }

  /// 📑 رفع تغذية الكتالوج (CSV Feed) مباشرة إلى Back4App Parse Files
  Future<String?> uploadCatalogFeed({
    required String csvContent,
    required String uid,
  }) async {
    try {
      final token = await _getAuthToken();
      final fileName = 'catalog_${uid}_feed.csv';

      final response = await http.post(
        Uri.parse('$_parseBaseUrl/catalogUploadFeed'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'csvContent': csvContent,
          'fileName': fileName,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['result']?['url'] as String?;
        if (url != null && url.startsWith('http')) {
          debugPrint('[CATALOG_FEED_UPLOAD] backend=back4app status=success url=$url');
          return url;
        }
      }

      debugPrint('❌ [CATALOG_FEED_UPLOAD] backend=back4app status=${response.statusCode} error=${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ [CATALOG_FEED_UPLOAD] backend=back4app exception=$e');
      return null;
    }
  }
}
