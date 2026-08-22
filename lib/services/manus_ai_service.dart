import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models/canonical_ai_request.dart';
import '../core/models/api_provider.dart';
import '../core/models/manus_media_models.dart';

/// 🤖 Manus AI Service (Production v2 - Hardened Auth)
///
/// Authentication:
///   - Requires signed-in Firebase user (FirebaseAuth.instance.currentUser)
///   - Retrieves fresh Firebase ID token (getIdToken()) on every request
///   - Fails closed if user is unauthenticated
///   - Backend cryptographically verifies the token against Google certificates
///   - NEVER transmits client-specified userId as trusted identity
///
/// Async media lifecycle:
///   submitMediaTask() → returns task_id immediately for media tasks
///   pollTaskStatus() → calls aiManusTaskStatus cloud function
///   Webhook fallback → aiManusWebhook cloud function
///
/// Security:
///   ⚠️ No MANUS_API_KEY in this file or anywhere in Flutter
///   ⚠️ No X-Parse-Master-Key in this file
///   All requests go through Back4App Cloud Code
///
/// Session continuity:
///   verifiedFirebaseUid + appSessionId → manusTaskId (managed server-side)
class ManusAiService extends GetxService {
  static const String _parseAppId = "uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2";
  static const String _parseRestKey = "Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp";
  static const String _parseBaseUrl = "https://parseapi.back4app.com";
  // 🔒 SECURITY: No Master Key. Cloud Code runs with useMasterKey on the server.

  Map<String, String> get _headers => {
    'X-Parse-Application-Id': _parseAppId,
    'X-Parse-REST-API-Key': _parseRestKey,
    'Content-Type': 'application/json',
  };

  /// 🔒 Retrieve fresh Firebase ID Token (Fails closed if not signed in)
  Future<String?> _getFreshFirebaseIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final projectId = Firebase.apps.isNotEmpty ? Firebase.app().options.projectId : '<none>';
      if (user == null) {
        debugPrint('[MANUS_AUTH_DIAG] currentUser=false uid=<none> firebase_project_id=$projectId token_present=false token_length=0');
        return null;
      }
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        final redactedUid = user.uid.length > 6 ? "${user.uid.substring(0, 3)}...${user.uid.substring(user.uid.length - 3)}" : "***";
        debugPrint('[MANUS_AUTH_DIAG] currentUser=true uid=$redactedUid firebase_project_id=$projectId token_present=false token_length=0');
        return null;
      }

      // Safe JWT payload inspection for diagnostics only
      String tokenAud = '<unknown>';
      String tokenIssProject = '<unknown>';
      try {
        final parts = idToken.split('.');
        if (parts.length == 3) {
          final normalized = base64Url.normalize(parts[1]);
          final payloadStr = utf8.decode(base64Url.decode(normalized));
          final claims = json.decode(payloadStr) as Map<String, dynamic>;
          tokenAud = claims['aud']?.toString() ?? '<none>';
          final iss = claims['iss']?.toString() ?? '';
          tokenIssProject = iss.contains('securetoken.google.com/') ? iss.split('securetoken.google.com/').last : iss;
        }
      } catch (_) {}

      final redactedUid = user.uid.length > 6 ? "${user.uid.substring(0, 3)}...${user.uid.substring(user.uid.length - 3)}" : "***";
      debugPrint('[MANUS_AUTH_DIAG] currentUser=true uid=$redactedUid firebase_project_id=$projectId token_present=true token_length=${idToken.length} token_aud=$tokenAud token_iss_project=$tokenIssProject');

      return idToken;
    } catch (e) {
      debugPrint('[MANUS_AUTH] Fail-closed: error retrieving Firebase ID token: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // 💬 TEXT GENERATION (synchronous — gateway polls internally)
  // ──────────────────────────────────────────────────────

  /// 💬 Generate text via Manus (through aiManusGateway)
  Future<Map<String, dynamic>> generateText(CanonicalAiRequest request) async {
    final sw = Stopwatch()..start();
    debugPrint('[AI_PROVIDER] provider=manus operation=text status=start');

    try {
      final response = await _callGateway(request, taskType: 'general');
      sw.stop();

      final gatewayResponse = ManusGatewayResponse.fromJson(response);

      if (gatewayResponse.success) {
        debugPrint(
            '[AI_PROVIDER] provider=manus operation=text status=success duration_ms=${sw.elapsedMilliseconds}');
        debugPrint(
            '[MANUS_SESSION] app_session=${request.appSessionId} action=${gatewayResponse.conversationMode} task_id=${_redactId(gatewayResponse.taskId)}');

        if (gatewayResponse.isAsync && gatewayResponse.taskId != null) {
          // Gateway timed out — poll for completion
          final result = await _pollUntilComplete(gatewayResponse.taskId!);
          return {
            'success': true,
            'data': result.data ?? '',
            'media': result.media.map((m) => {'type': m.type, 'url': m.url, 'filename': m.filename}).toList(),
            'meta': {'provider': 'manus', 'task_id': gatewayResponse.taskId, 'conversation_mode': gatewayResponse.conversationMode},
          };
        }

        return response;
      } else {
        debugPrint('[AI_PROVIDER] provider=manus operation=text status=error error=${response['error']}');
        return response;
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

  /// 📸 Analyze image(s) via Manus (through aiManusGateway)
  Future<Map<String, dynamic>> analyzeVision(CanonicalAiRequest request) async {
    final sw = Stopwatch()..start();
    debugPrint('[AI_PROVIDER] provider=manus operation=vision status=start');

    try {
      final List<String> base64Images = [];
      if (request.images != null && request.images!.isNotEmpty) {
        for (final img in request.images!) {
          base64Images.add(base64Encode(img));
        }
      } else if (request.imageBytes != null) {
        base64Images.add(base64Encode(request.imageBytes!));
      }

      final response = await _callGateway(
        request,
        taskType: request.taskType.isNotEmpty ? request.taskType : 'vision',
        extraPayload: {
          'images': base64Images,
          'mimeType': request.mimeType,
        },
      );
      sw.stop();

      final gatewayResponse = ManusGatewayResponse.fromJson(response);
      if (gatewayResponse.success) {
        debugPrint(
            '[AI_PROVIDER] provider=manus operation=vision status=success duration_ms=${sw.elapsedMilliseconds}');
        debugPrint(
            '[MANUS_SESSION] app_session=${request.appSessionId} action=${gatewayResponse.conversationMode} task_id=${_redactId(gatewayResponse.taskId)}');
      }

      return response;
    } catch (e) {
      sw.stop();
      debugPrint('[AI_PROVIDER] provider=manus operation=vision status=error error=$e');
      return {
        'success': false,
        'error': _normalizeError(e),
        'meta': {'provider': 'manus', 'status': 'error'},
      };
    }
  }

  // ──────────────────────────────────────────────────────
  // 🎨 MEDIA GENERATION (async — returns task_id immediately)
  // ──────────────────────────────────────────────────────

  /// 🎨 Submit a media generation task (image/video/etc)
  Future<ManusGatewayResponse> submitMediaTask(
    CanonicalAiRequest request, {
    required String taskType,
  }) async {
    debugPrint('[AI_PROVIDER] provider=manus operation=$taskType status=start');

    try {
      final List<String> base64Images = [];
      if (request.images != null && request.images!.isNotEmpty) {
        for (final img in request.images!) {
          base64Images.add(base64Encode(img));
        }
      } else if (request.imageBytes != null) {
        base64Images.add(base64Encode(request.imageBytes!));
      }

      final response = await _callGateway(
        request,
        taskType: taskType,
        extraPayload: {
          if (base64Images.isNotEmpty) 'images': base64Images,
          if (base64Images.isNotEmpty) 'mimeType': request.mimeType,
        },
      );

      final gatewayResponse = ManusGatewayResponse.fromJson(response);

      debugPrint(
          '[AI_PROVIDER] provider=manus operation=$taskType status=${gatewayResponse.success ? "submitted" : "error"} '
          'async=${gatewayResponse.isAsync} task_id=${_redactId(gatewayResponse.taskId)}');

      return gatewayResponse;
    } catch (e) {
      debugPrint('[AI_PROVIDER] provider=manus operation=$taskType status=error error=$e');
      return ManusGatewayResponse(
        success: false,
        error: _normalizeError(e),
      );
    }
  }

  /// 🔄 Poll task status via aiManusTaskStatus cloud function
  /// Uses verified Firebase ID token for authorization.
  Future<ManusTaskStatus> pollTaskStatus(String taskId) async {
    try {
      final idToken = await _getFreshFirebaseIdToken();
      if (idToken == null) {
        return ManusTaskStatus(
          success: false,
          taskId: taskId,
          status: 'error',
          isError: true,
          error: 'AUTH_ERROR: User must be signed in with Firebase to check task status',
        );
      }

      final url = Uri.parse('$_parseBaseUrl/functions/aiManusTaskStatus');

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode({
          'task_id': taskId,
          'firebaseIdToken': idToken,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final result = decoded['result'] != null
            ? Map<String, dynamic>.from(decoded['result'] as Map)
            : Map<String, dynamic>.from(decoded as Map);

        return ManusTaskStatus.fromJson(result);
      } else {
        return ManusTaskStatus(
          success: false,
          taskId: taskId,
          status: 'error',
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return ManusTaskStatus(
        success: false,
        taskId: taskId,
        status: 'error',
        isError: true,
        error: _normalizeError(e),
      );
    }
  }

  /// 🔄 Poll until task completes or errors (with callback for status updates)
  Future<ManusTaskStatus> pollUntilComplete(
    String taskId, {
    Duration pollInterval = const Duration(seconds: 5),
    Duration maxWait = const Duration(minutes: 10),
    void Function(ManusTaskStatus status)? onStatusUpdate,
  }) async {
    return _pollUntilComplete(
      taskId,
      pollInterval: pollInterval,
      maxWait: maxWait,
      onStatusUpdate: onStatusUpdate,
    );
  }

  // ──────────────────────────────────────────────────────
  // 🔧 INTERNAL HELPERS
  // ──────────────────────────────────────────────────────

  /// Core gateway call — shared by text, vision, and media methods
  Future<Map<String, dynamic>> _callGateway(
    CanonicalAiRequest request, {
    required String taskType,
    Map<String, dynamic>? extraPayload,
  }) async {
    // 🔒 Fail-closed authentication check
    final idToken = await _getFreshFirebaseIdToken();
    if (idToken == null) {
      return {
        'success': false,
        'error': 'AUTH_ERROR: User must be signed in with Firebase to access Manus AI services.',
        'meta': {'provider': 'manus', 'status': 'auth_error'},
      };
    }

    final url = Uri.parse('$_parseBaseUrl/functions/aiManusGateway');

    final payload = <String, dynamic>{
      'prompt': request.prompt,
      'systemPersona': request.systemPersona,
      'history': request.history,
      'maxTokens': request.maxTokens,
      'temperature': request.temperature,
      'isModificationMode': request.isModificationMode,
      'templateId': request.templateId,
      'templateInputs': request.templateInputs,
      'taskType': taskType,
      'metadata': request.metadata,
      // Session continuity & trusted cryptographic token
      if (request.appSessionId != null) 'appSessionId': request.appSessionId,
      'firebaseIdToken': idToken,
      // Merge extra payload (images, mimeType, etc.)
      ...?extraPayload,
    };

    final response = await http.post(
      url,
      headers: _headers,
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final result = decoded['result'] != null
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : Map<String, dynamic>.from(decoded as Map);
      return result;
    } else {
      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.body}',
        'meta': {'provider': 'manus', 'status': 'error'},
      };
    }
  }

  /// Internal polling loop
  Future<ManusTaskStatus> _pollUntilComplete(
    String taskId, {
    Duration pollInterval = const Duration(seconds: 5),
    Duration maxWait = const Duration(minutes: 10),
    void Function(ManusTaskStatus status)? onStatusUpdate,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < maxWait) {
      await Future.delayed(pollInterval);

      final status = await pollTaskStatus(taskId);

      // Notify caller with real status (Correction #4)
      onStatusUpdate?.call(status);

      if (status.isCompleted || status.isError) {
        stopwatch.stop();
        debugPrint(
            '[MANUS_POLL] task_id=${_redactId(taskId)} final_status=${status.status} '
            'duration_ms=${stopwatch.elapsedMilliseconds} media_count=${status.media.length}');
        return status;
      }

      // Log progress with real Manus status text
      if (kDebugMode) {
        debugPrint(
            '[MANUS_POLL] task_id=${_redactId(taskId)} status=${status.status} '
            'brief="${status.statusBrief ?? ""}" elapsed=${stopwatch.elapsed.inSeconds}s');
      }
    }

    stopwatch.stop();
    return ManusTaskStatus(
      success: false,
      taskId: taskId,
      status: 'timeout',
      isError: true,
      error: 'Task polling timed out after ${maxWait.inMinutes} minutes',
    );
  }

  /// 🔄 Convert response to AiResult for legacy compatibility
  AiResult toAiResult(Map<String, dynamic> response) {
    return AiResult(
      description: response['data']?.toString() ?? '',
      provider: 'Manus (v2)',
    );
  }

  /// 🔒 Redact task ID for safe logging
  String _redactId(String? id) {
    if (id == null || id.isEmpty) return '<none>';
    if (id.length <= 8) return '***';
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  /// 🛡️ Normalize errors
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
