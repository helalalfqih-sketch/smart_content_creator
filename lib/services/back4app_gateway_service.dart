import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../core/models/api_provider.dart';
import '../controllers/settings_controller.dart';


/// 🌐 Back4App AI Gateway Service
/// يتصل بـ Back4App Cloud Code لاستخدام نظام تدوير المفاتيح (18 مفتاح Gemini)
/// بدلاً من استخدام مفتاح محلي واحد
class Back4AppGatewayService extends GetxService {
  static const String _parseAppId = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2";
  static const String _parseRestKey = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp";
  static const String _parseBaseUrl = "https://parseapi.back4app.com";
  static const String _parseMasterKey = "8qRzu0pBFkDo0urIjpXeFGb23xR5C23JoOlD05ze";

  /// الهيدرز الأساسية لكل طلب
  Map<String, String> get _headers => {
    'X-Parse-Application-Id': _parseAppId,
    'X-Parse-REST-API-Key': _parseRestKey,
    'X-Parse-Master-Key': _parseMasterKey,
    'Content-Type': 'application/json',
  };

  /// 🚀 توليد نص عبر Vertex AI أولاً (ثم Fallback على aiGateway)
  /// هذا هو المدخل الرئيسي - يستخدم Vertex AI أولاً للحصول على أفضل أداء
  Future<AiResult> generateTextWithVertex(
    String prompt, {
    List<Map<String, String>>? history,
    String? image,
    String? mimeType,
    int maxTokens = 2048,
    double temperature = 0.7,
    String model = 'gemini-2.5-flash',
  }) async {
    // 1️⃣ المحاولة الأولى: Vertex AI Gateway
    try {
      if (kDebugMode) print('🚀 [Back4App-Vertex]: Trying aiVertexGateway...');
      
      final url = Uri.parse('$_parseBaseUrl/functions/aiVertexGateway');
      
      final List<Map<String, String>>? formattedHistory = history?.map((h) {
        return <String, String>{
          'role': h['role'] == 'model' ? 'assistant' : (h['role'] ?? 'user'),
          'content': h['content'] ?? '',
        };
      }).toList();

      final body = {
        'prompt': prompt,
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (formattedHistory != null && formattedHistory.isNotEmpty)
          'history': formattedHistory,
        if (image != null) 'image': image,
        if (mimeType != null) 'mimeType': mimeType,
      };

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 35));

      if (kDebugMode) {
        print('📡 [Back4App-Vertex]: Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null && result['success'] == true) {
          final text = result['data'] ?? '';
          final meta = result['meta'] ?? {};
          if (kDebugMode) print('✅ [Back4App-Vertex]: SUCCESS via Vertex AI! Model: ${meta["model"]}');
          return AiResult(
            description: text,
            provider: 'Vertex AI (${meta["model"] ?? model})',
          );
        }
      }
      
      // Vertex returned non-200 or non-success, fall through to aiGateway
      if (kDebugMode) print('⚠️ [Back4App-Vertex]: Vertex returned error, falling back to aiGateway...');
    } catch (e) {
      if (kDebugMode) print('⚠️ [Back4App-Vertex]: Vertex error: $e → Falling back to aiGateway...');
    }

    // 2️⃣ Fallback: aiGateway (مفاتيح مجانية)
    return generateText(
      prompt,
      history: history,
      image: image,
      mimeType: mimeType,
      maxTokens: maxTokens,
      temperature: temperature,
      model: model,
    );
  }

  /// 🧠 توليد نص عبر aiGateway (يستخدم تدوير المفاتيح التلقائي - Fallback فقط)
  Future<AiResult> generateText(
    String prompt, {
    List<Map<String, String>>? history,
    String? image,
    String? mimeType,
    int maxTokens = 2048,
    double temperature = 0.7,
    String model = 'gemini-2.0-flash',
  }) async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiGateway');

      // تحويل History من Gemini format إلى Back4App format
      final List<Map<String, String>>? formattedHistory = history?.map((h) {
        return <String, String>{
          'role': h['role'] == 'model' ? 'assistant' : (h['role'] ?? 'user'),
          'content': h['content'] ?? '',
        };
      }).toList();

      final body = {
        'prompt': prompt,
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (formattedHistory != null && formattedHistory.isNotEmpty)
          'history': formattedHistory,
        if (image != null) 'image': image,
        if (mimeType != null) 'mimeType': mimeType,
      };

      if (kDebugMode) {
        print('🌐 [Back4App-Gateway]: Calling aiGateway...');
        print('📝 [Back4App-Gateway]: Prompt length: ${prompt.length}, Image: ${image != null ? "YES" : "NO"}');
      }

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('📡 [Back4App-Gateway]: Status: ${response.statusCode}');
        print('📡 [Back4App-Gateway]: Body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];

        if (result != null && result['success'] == true) {
          final text = result['data'] ?? '';
          final meta = result['meta'] ?? {};
          
          if (kDebugMode) {
            print('✅ [Back4App-Gateway]: SUCCESS! Provider: ${meta['provider']}, Model: ${meta['model']}, Rotation: ${meta['rotation']}');
          }

          return AiResult(
            description: text,
            provider: 'Back4App (${meta['model'] ?? model})',
          );
        }
      }

      // Handle error responses
      final errorData = json.decode(response.body);
      final errorMsg = errorData['error'] ?? errorData['message'] ?? 'Unknown Back4App Error';
      final errorCode = errorData['code'] ?? response.statusCode;

      if (kDebugMode) {
        print('❌ [Back4App-Gateway]: Error $errorCode: $errorMsg');
      }

      throw Exception('Back4App ($errorCode): $errorMsg');
    } catch (e) {
      if (kDebugMode) {
        print('❌ [Back4App-Gateway]: Connection Error: $e');
      }
      rethrow;
    }
  }

  /// 🏥 فحص صحة السيرفر
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiServerHealth');
      final response = await http.post(url, headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['result'] ?? {});
      }
      return {'status': 'error', 'code': response.statusCode};
    } catch (e) {
      return {'status': 'offline', 'error': e.toString()};
    }
  }

  /// 🔑 فحص حالة جميع المفاتيح (مع timeout مخفّض)
  Future<List<Map<String, dynamic>>> checkAllKeys() async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/checkAllKeys');
      final response = await http.post(url, headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 15)); // ⚡ مخفّض من 30 إلى 15 ثانية

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['result'] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [Back4App]: checkAllKeys error: $e');
      return [];
    }
  }

  /// 🧪 اختبار حي للبوابة — يُرسل طلباً حقيقياً ويُرجع تفاصيل المفتاح المستخدم
  Future<Map<String, dynamic>> liveTestGateway() async {
    final sw = Stopwatch()..start();
    String lastError = '';

    // ── 1. جرّب Vertex أولاً
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiVertexGateway');
      final body = {
        'prompt': 'Say the word OK only.',
        'model': 'gemini-2.5-flash',
        'max_tokens': 10,
        'temperature': 0.0,
      };
      final response = await http.post(url, headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));
      sw.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null) {
          if (result['success'] == true) {
            final meta = result['meta'] ?? {};
            return {
              'success': true,
              'path': 'Vertex AI (Primary)',
              'provider': 'Vertex AI',
              'model': meta['model'] ?? 'gemini-2.5-flash',
              'keyIndex': null,
              'keyName': 'Google Vertex AI Service Account',
              'rotation': null,
              'latencyMs': sw.elapsedMilliseconds,
              'response': result['data']?.toString().trim() ?? '',
            };
          } else if (result['error'] != null) {
            lastError = 'Vertex Error: ${result['error']}';
          }
        }
      } else {
        try {
          final data = json.decode(response.body);
          if (data['error'] != null) {
            lastError = 'Vertex HTTP ${response.statusCode}: ${data['error']}';
          } else {
            lastError = 'Vertex HTTP ${response.statusCode}';
          }
        } catch (_) {
          lastError = 'Vertex HTTP ${response.statusCode}';
        }
      }
    } catch (e) {
      sw.stop();
      lastError = 'Vertex Exception: $e';
    }

    // ── 2. Vertex فشل → جرّب aiGateway (مفاتيح Gemini المجانية)
    final sw2 = Stopwatch()..start();
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiGateway');
      final body = {
        'prompt': 'Say the word OK only.',
        'model': 'gemini-2.0-flash',
        'max_tokens': 10,
        'temperature': 0.0,
      };
      final response = await http.post(url, headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));
      sw2.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null) {
          if (result['success'] == true) {
            final meta = result['meta'] ?? {};
            return {
              'success': true,
              'path': 'aiGateway (Fallback)',
              'provider': meta['provider'] ?? 'Gemini',
              'model': meta['model'] ?? 'gemini-2.0-flash',
              'keyIndex': meta['keyIndex'],
              'keyName': meta['keyName'] ?? meta['key'] ?? 'مفتاح ${meta['keyIndex'] ?? "؟"}',
              'rotation': meta['rotation'],
              'latencyMs': sw2.elapsedMilliseconds,
              'response': result['data']?.toString().trim() ?? '',
            };
          } else if (result['error'] != null) {
            lastError = 'Gateway Error: ${result['error']}';
          }
        }
      } else {
        try {
          final data = json.decode(response.body);
          if (data['error'] != null) {
            lastError = '${data['error']}';
          } else {
            lastError = 'Gateway HTTP ${response.statusCode}';
          }
        } catch (_) {
          lastError = 'Gateway HTTP ${response.statusCode}';
        }
      }
    } catch (e) {
      sw2.stop();
      lastError = 'Gateway Exception: $e';
    }

    return {
      'success': false,
      'path': 'فاشل',
      'provider': 'غير متاح',
      'model': '',
      'keyIndex': null,
      'keyName': lastError.isNotEmpty ? lastError : 'فشل غير معروف في الاتصال بالخادم',
      'rotation': null,
      'latencyMs': sw.elapsedMilliseconds + sw2.elapsedMilliseconds,
      'response': '',
    };
  }

  /// 🧪 اختبار تفصيلي لجميع المزودات المتاحة متوازياً
  Future<Map<String, dynamic>> liveTestDetailedProviders() async {
    final results = await Future.wait([
      _testVertexAI(),
      _testCloudGeminiPool(),
      _testLocalGeminiKey(),
    ]);

    return {
      'vertex': results[0],
      'cloudPool': results[1],
      'localKey': results[2],
    };
  }

  Future<Map<String, dynamic>> _testVertexAI() async {
    final sw = Stopwatch()..start();
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiVertexGateway');
      final body = {
        'prompt': 'Say the word OK only.',
        'model': 'gemini-2.5-flash',
        'max_tokens': 10,
        'temperature': 0.0,
      };
      final response = await http.post(url, headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 12));
      sw.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null && result['success'] == true) {
          final meta = result['meta'] ?? {};
          return {
            'success': true,
            'provider': 'Vertex AI (بوابة أساسية)',
            'model': meta['model'] ?? 'gemini-2.5-flash',
            'keyName': 'Google Vertex Service Account',
            'latencyMs': sw.elapsedMilliseconds,
            'response': result['data']?.toString().trim() ?? '',
          };
        } else {
          return {
            'success': false,
            'provider': 'Vertex AI (بوابة أساسية)',
            'model': 'gemini-2.5-flash',
            'keyName': 'Google Vertex Service Account',
            'latencyMs': sw.elapsedMilliseconds,
            'response': result != null && result['error'] != null ? result['error'].toString() : 'فشل غير معروف',
          };
        }
      } else {
        String errMsg = 'HTTP ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['error'] != null) errMsg = data['error'].toString();
        } catch (_) {}
        return {
          'success': false,
          'provider': 'Vertex AI (بوابة أساسية)',
          'model': 'gemini-2.5-flash',
          'keyName': 'Google Vertex Service Account',
          'latencyMs': sw.elapsedMilliseconds,
          'response': errMsg,
        };
      }
    } catch (e) {
      sw.stop();
      return {
        'success': false,
        'provider': 'Vertex AI (بوابة أساسية)',
        'model': 'gemini-2.5-flash',
        'keyName': 'Google Vertex Service Account',
        'latencyMs': sw.elapsedMilliseconds,
        'response': 'خطأ: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _testCloudGeminiPool() async {
    final sw = Stopwatch()..start();
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiGateway');
      final body = {
        'prompt': 'Say the word OK only.',
        'model': 'gemini-2.0-flash',
        'max_tokens': 10,
        'temperature': 0.0,
      };
      final response = await http.post(url, headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 12));
      sw.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null && result['success'] == true) {
          final meta = result['meta'] ?? {};
          return {
            'success': true,
            'provider': 'Gemini Key Pool (بوابة احتياطية)',
            'model': meta['model'] ?? 'gemini-2.0-flash',
            'keyName': meta['keyName'] ?? meta['key'] ?? 'مفتاح #${meta['keyIndex'] ?? "?"}',
            'latencyMs': sw.elapsedMilliseconds,
            'response': result['data']?.toString().trim() ?? '',
          };
        } else {
          return {
            'success': false,
            'provider': 'Gemini Key Pool (بوابة احتياطية)',
            'model': 'gemini-2.0-flash',
            'keyName': '—',
            'latencyMs': sw.elapsedMilliseconds,
            'response': result != null && result['error'] != null ? result['error'].toString() : 'فشل غير معروف',
          };
        }
      } else {
        String errMsg = 'HTTP ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['error'] != null) errMsg = data['error'].toString();
        } catch (_) {}
        return {
          'success': false,
          'provider': 'Gemini Key Pool (بوابة احتياطية)',
          'model': 'gemini-2.0-flash',
          'keyName': '—',
          'latencyMs': sw.elapsedMilliseconds,
          'response': errMsg,
        };
      }
    } catch (e) {
      sw.stop();
      return {
        'success': false,
        'provider': 'Gemini Key Pool (بوابة احتياطية)',
        'model': 'gemini-2.0-flash',
        'keyName': '—',
        'latencyMs': sw.elapsedMilliseconds,
        'response': 'خطأ: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _testLocalGeminiKey() async {
    final sw = Stopwatch()..start();
    try {
      final settingsCtrl = Get.isRegistered<SettingsController>() ? Get.find<SettingsController>() : null;
      if (settingsCtrl == null) {
        return {
          'success': false,
          'provider': 'Google AI Studio (مفتاح محلي)',
          'model': 'gemini-2.5-flash',
          'keyName': '—',
          'latencyMs': 0,
          'response': 'تعذر الوصول إلى SettingsController',
        };
      }
      final localKey = settingsCtrl.getApiKey(ProviderType.gemini);
      if (localKey.isEmpty) {
        return {
          'success': false,
          'provider': 'Google AI Studio (مفتاح محلي)',
          'model': 'gemini-2.5-flash',
          'keyName': 'غير متوفر',
          'latencyMs': 0,
          'response': 'لم يتم إدخال مفتاح Gemini محلي في الإعدادات.',
        };
      }

      final obscuredKey = localKey.length > 20
          ? '${localKey.substring(0, 6)}...${localKey.substring(localKey.length - 4)}'
          : 'مفتاح محلي';

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$localKey');
      final body = {
        'contents': [
          {
            'parts': [
              {'text': 'Say the word OK only.'}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 10,
          'temperature': 0.0,
        }
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 12));
      sw.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final first = candidates[0];
          final content = first['content'];
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text']?.toString().trim() ?? '';
              return {
                'success': true,
                'provider': 'Google AI Studio (مفتاح محلي)',
                'model': 'gemini-2.5-flash',
                'keyName': obscuredKey,
                'latencyMs': sw.elapsedMilliseconds,
                'response': text,
              };
            }
          }
        }
        return {
          'success': false,
          'provider': 'Google AI Studio (مفتاح محلي)',
          'model': 'gemini-2.5-flash',
          'keyName': obscuredKey,
          'latencyMs': sw.elapsedMilliseconds,
          'response': 'استجابة غير متوقعة: ${response.body}',
        };
      } else {
        String errMsg = 'HTTP ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['error'] != null && data['error']['message'] != null) {
            errMsg = data['error']['message'].toString();
          }
        } catch (_) {}
        return {
          'success': false,
          'provider': 'Google AI Studio (مفتاح محلي)',
          'model': 'gemini-2.5-flash',
          'keyName': obscuredKey,
          'latencyMs': sw.elapsedMilliseconds,
          'response': errMsg,
        };
      }
    } catch (e) {
      sw.stop();
      return {
        'success': false,
        'provider': 'Google AI Studio (مفتاح محلي)',
        'model': 'gemini-2.5-flash',
        'keyName': 'خطأ في المفتاح',
        'latencyMs': sw.elapsedMilliseconds,
        'response': 'خطأ: $e',
      };
    }
  }


  /// 📋 جلب سجل الأخطاء الأخيرة
  Future<List<Map<String, dynamic>>> getRecentErrors() async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/getRecentErrors');
      final response = await http.post(url, headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['result'] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [Back4App]: getRecentErrors error: $e');
      return [];
    }
  }

  /// 📊 جلب استهلاك اليوم
  Future<Map<String, dynamic>> getDailyUsage() async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiGetMyDailyUsage');
      final response = await http.post(url, headers: _headers, body: '{}')
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['result'] ?? {});
      }
      return {};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
