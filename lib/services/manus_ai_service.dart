import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/models/canonical_ai_request.dart';
import '../core/models/api_provider.dart';

/// 🤖 Manus AI Service
/// محول العميل لمزود Manus API v2
/// يتصل بالبوابة السحابية الآمنة `aiManusGateway` المحمية بـ Firebase Auth & App Check.
/// ⚠️ لا يحتوي على أي مفاتيح API إطلاقاً.
class ManusAiService extends GetxService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 💬 توليد نص عبر Manus API v2 (من خلال البوابة السحابية)
  Future<Map<String, dynamic>> generateText(CanonicalAiRequest request) async {
    final sw = Stopwatch()..start();
    debugPrint('[AI_PROVIDER] provider=manus operation=text status=start');

    try {
      final callable = _functions.httpsCallable(
        'aiManusGateway',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final payload = {
        'prompt': request.prompt,
        'systemPersona': request.systemPersona,
        'history': request.history,
        'maxTokens': request.maxTokens,
        'temperature': request.temperature,
        'taskType': request.taskType,
      };

      final response = await callable.call(payload);
      sw.stop();

      final result = Map<String, dynamic>.from(response.data as Map);
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

  /// 📸 تحليل صورة منتج عبر Manus API v2 (من خلال البوابة السحابية)
  Future<Map<String, dynamic>> analyzeVision(CanonicalAiRequest request) async {
    final sw = Stopwatch()..start();
    debugPrint('[AI_PROVIDER] provider=manus operation=vision status=start');

    try {
      final callable = _functions.httpsCallable(
        'aiManusGateway',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      String? base64Image;
      if (request.imageBytes != null) {
        base64Image = base64Encode(request.imageBytes!);
      } else if (request.images != null && request.images!.isNotEmpty) {
        base64Image = base64Encode(request.images!.first);
      }

      final payload = {
        'prompt': request.prompt,
        'systemPersona': request.systemPersona,
        'history': request.history,
        'image': base64Image,
        'mimeType': request.mimeType,
        'taskType': 'vision',
      };

      final response = await callable.call(payload);
      sw.stop();

      final result = Map<String, dynamic>.from(response.data as Map);
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
