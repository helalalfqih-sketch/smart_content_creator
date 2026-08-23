import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/whatsapp_sync_models.dart';

/// 📱 WhatsAppSyncService
/// خدمة التواصل مع دوال Back4App Cloud Code الخاصة بـ WhatsApp Media Sync
class WhatsAppSyncService extends GetxService {
  static const String _parseAppId = 'uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2';
  static const String _parseRestKey = 'Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp';
  static const String _parseBaseUrl = 'https://parseapi.back4app.com/functions';

  Map<String, String> get _headers => {
    'X-Parse-Application-Id': _parseAppId,
    'X-Parse-REST-API-Key': _parseRestKey,
    'Content-Type': 'application/json',
  };

  Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return await user?.getIdToken(false);
    } catch (e) {
      debugPrint('⚠️ WhatsAppSyncService auth error: $e');
      return null;
    }
  }

  /// 📥 جلب إعدادات الواتساب وحسابات WABA
  Future<WhatsAppSyncConfig> getConfig() async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppGetConfig'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final configMap = decoded['result']?['config'] as Map<String, dynamic>?;
        if (configMap != null) {
          return WhatsAppSyncConfig.fromMap(configMap);
        }
      }
    } catch (e) {
      debugPrint('⚠️ getConfig error: $e');
    }
    return WhatsAppSyncConfig.fromMap({});
  }

  /// 💾 حفظ إعدادات الواتساب
  Future<bool> saveConfig(WhatsAppSyncConfig config) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppSaveConfig'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          ...config.toMap(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ saveConfig error: $e');
    }
    return false;
  }

  /// 🧪 محاكاة استقبال وسائط واتساب (AI Test Sandbox)
  Future<Map<String, dynamic>?> simulateInbound({
    required String fileUrl,
    required String caption,
    required String senderPhone,
    String fileType = 'image',
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppSimulateInbound'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'fileUrl': fileUrl,
          'caption': caption,
          'senderPhone': senderPhone,
          'fileType': fileType,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['result'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('⚠️ simulateInbound error: $e');
    }
    return null;
  }

  /// 📋 جلب مسودات الواتساب بانتظار المراجعة
  Future<List<WhatsAppDraftModel>> getPendingDrafts() async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppGetPendingDrafts'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['result']?['drafts'] as List? ?? [];
        return list
            .map((d) => WhatsAppDraftModel.fromMap(Map<String, dynamic>.from(d)))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ getPendingDrafts error: $e');
    }
    return [];
  }

  /// ✅ اعتماد مسودة وتحويلها إلى منتج حقيقي في الكتالوج
  Future<bool> approveDraft(
    String draftId, {
    String? title,
    double? price,
    String? description,
    String? categoryName,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppApproveDraft'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'draftId': draftId,
          if (title != null) 'title': title,
          if (price != null) 'price': price,
          if (description != null) 'description': description,
          if (categoryName != null) 'categoryName': categoryName,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ approveDraft error: $e');
    }
    return false;
  }

  /// 📤 إرسال منتج عبر الواتساب
  Future<bool> sendProductToWhatsApp({
    required String productId,
    required String destinationPhone,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppSendProduct'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'productId': productId,
          'destinationPhone': destinationPhone,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ sendProductToWhatsApp error: $e');
    }
    return false;
  }

  /// 📦 معالجة وحفظ دفعة وسائط الموردين المعزولة من ملفات الإكسل
  Future<Map<String, dynamic>?> processSupplierBatch({
    required List<Map<String, dynamic>> mediaItems,
    String? supplierPhone,
  }) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('$_parseBaseUrl/whatsAppProcessSupplierBatch'),
        headers: _headers,
        body: jsonEncode({
          if (token != null) 'firebaseIdToken': token,
          'mediaItems': mediaItems,
          'supplierPhone': supplierPhone ?? '+967738609222',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['result'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('⚠️ processSupplierBatch error: $e');
    }
    return null;
  }
}
