import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../core/models/canonical_ai_request.dart';
import '../core/models/api_provider.dart';

/// 🤖 Manus AI Service
/// محول العميل لمزود Manus API v2
/// يتصل بالبوابة السحابية الآمنة `aiManusGateway` في Back4App Cloud Code.
/// ⚠️ لا يحتوي على أي مفاتيح API إطلاقاً.
class ManusAiService extends GetxService {
  static const String _parseAppId = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2";
  static const String _parseRestKey = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp";
  static const String _parseBaseUrl = "https://parseapi.back4app.com";

  Map<String, String> get _headers => {
    'X-Parse-Application-Id': _parseAppId,
    'X-Parse-REST-API-Key': _parseRestKey,
    'Content-Type': 'application/json',
  };


  /// 💬 توليد نص عبر Manus API v2 (من خلال البوابة السحابية)
  Future<Map<String, dynamic>> generateText(CanonicalAiRequest request) async {
    final sw = Stopwatch()..start();
    debugPrint('[AI_PROVIDER] provider=manus operation=text status=start');

    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiManusGateway');

      final payload = {
        'prompt': request.prompt,
        'systemPersona': request.systemPersona,
        'history': request.history,
        'maxTokens': request.maxTokens,
        'temperature': request.temperature,
        'isModificationMode': request.isModificationMode,
        'templateId': request.templateId,
        'templateInputs': request.templateInputs,
        'taskType': request.taskType,
        'metadata': request.metadata,
      };

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 90));

      sw.stop();

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final result = decoded['result'] != null
            ? Map<String, dynamic>.from(decoded['result'] as Map)
            : Map<String, dynamic>.from(decoded as Map);

        if (result['success'] == true) {
          debugPrint(
              '[AI_PROVIDER] provider=manus operation=text status=success duration_ms=${sw.elapsedMilliseconds}');
          return result;
        } else {
          debugPrint(
              '[AI_PROVIDER] provider=manus operation=text status=error error=${result['error']}');
          return {
            'success': false,
            'error': result['error'] ?? 'Manus generation failed',
            'meta': {'provider': 'manus', 'status': 'error'},
          };
        }
      } else {
        debugPrint(
            '[AI_PROVIDER] provider=manus operation=text status=error httpStatus=${response.statusCode} body=${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
          'meta': {'provider': 'manus', 'status': 'error'},
        };
      }
    } catch (e) {
      sw.stop();
      debugPrint('[AI_PROVIDER] provider=manus operation=text status=error error=$e');
      return {
        'success': false,
        'error': _normalizeError(e),
        'meta': {'provider': 'manus', 'status': 'error'},
      };
    }
  }

  /// 📸 تحليل صورة أو صور منتج عبر Manus API v2 (من خلال البوابة السحابية)
  Future<Map<String, dynamic>> analyzeVision(CanonicalAiRequest request) async {
    final sw = Stopwatch()..start();
    debugPrint('[AI_PROVIDER] provider=manus operation=vision status=start');

    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiManusGateway');

      final List<String> base64Images = [];
      if (request.images != null && request.images!.isNotEmpty) {
        for (final img in request.images!) {
          base64Images.add(base64Encode(img));
        }
      } else if (request.imageBytes != null) {
        base64Images.add(base64Encode(request.imageBytes!));
      }

      final payload = {
        'prompt': request.prompt,
        'systemPersona': request.systemPersona,
        'history': request.history,
        'images': base64Images,
        'mimeType': request.mimeType,
        'maxTokens': request.maxTokens,
        'temperature': request.temperature,
        'isModificationMode': request.isModificationMode,
        'templateId': request.templateId,
        'templateInputs': request.templateInputs,
        'taskType': request.taskType.isNotEmpty ? request.taskType : 'vision',
        'metadata': request.metadata,
      };

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 90));

      sw.stop();

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final result = decoded['result'] != null
            ? Map<String, dynamic>.from(decoded['result'] as Map)
            : Map<String, dynamic>.from(decoded as Map);

        if (result['success'] == true) {
          debugPrint(
              '[AI_PROVIDER] provider=manus operation=vision status=success duration_ms=${sw.elapsedMilliseconds}');
          return result;
        } else {
          debugPrint(
              '[AI_PROVIDER] provider=manus operation=vision status=error error=${result['error']}');
          return {
            'success': false,
            'error': result['error'] ?? 'Manus vision analysis failed',
            'meta': {'provider': 'manus', 'status': 'error'},
          };
        }
      } else {
        debugPrint(
            '[AI_PROVIDER] provider=manus operation=vision status=error httpStatus=${response.statusCode} body=${response.body}');
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
          'meta': {'provider': 'manus', 'status': 'error'},
        };
      }
    } catch (e) {
      sw.stop();
      debugPrint(
          '[AI_PROVIDER] provider=manus operation=vision status=error error=$e');
      return {
        'success': false,
        'error': _normalizeError(e),
        'meta': {'provider': 'manus', 'status': 'error'},
      };
    }
  }

  /// 🔄 تحويل النتيجة إلى AiResult للتوافق مع طبقات العرض القديمة
  AiResult toAiResult(Map<String, dynamic> response) {
    return AiResult(
      description: response['data']?.toString() ?? '',
      provider: 'Manus (v2)',
    );
  }

  /// 🛡️ تطبيع وتوحيد أخطاء Manus
  String _normalizeError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('unauthenticated') || str.contains('auth')) {
      return 'AUTH_ERROR: Authentication failed for Manus Gateway';
    }
    if (str.contains('permission-denied') || str.contains('app check')) {
      return 'PERMISSION_DENIED: App Check or security verification failed';
    }
    if (str.contains('resource-exhausted') || str.contains('quota') || str.contains('429')) {
      return 'RATE_LIMITED: Manus rate limit or quota exceeded';
    }
    if (str.contains('deadline-exceeded') || str.contains('timeout')) {
      return 'TIMEOUT: Manus task timed out';
    }
    return e.toString();
  }
}
