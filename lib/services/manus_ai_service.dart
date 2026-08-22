import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models/canonical_ai_request.dart';
import '../core/models/api_provider.dart';
import '../core/models/manus_media_models.dart';

/// 🤖 Manus AI Service (Production v2)
///
/// Async media lifecycle:
///   submitTask() → returns task_id immediately for media tasks
///   pollTaskStatus() → calls aiManusTaskStatus cloud function
///   Webhook fallback → aiManusWebhook cloud function
///
/// Security:
///   ⚠️ No MANUS_API_KEY in this file or anywhere in Flutter
///   ⚠️ No X-Parse-Master-Key in this file
///   All requests go through Back4App Cloud Code
///
/// Session continuity:
///   userId + appSessionId → manusTaskId (managed server-side)
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

  /// 🔒 Get current Firebase UID safely
  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // 💬 TEXT GENERATION (synchronous — gateway polls internally)
  // ──────────────────────────────────────────────────────

  /// 💬 Generate text via Manus (through aiManusGateway)
  /// For text tasks, the gateway polls internally and returns the result.
  /// If it times out, returns task_id for client-side polling.
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
  /// Returns ManusGatewayResponse with task_id for polling.
  /// Does NOT wait for completion — caller must poll.
  ///
  /// Correction #5: No synchronous waits for media.
  /// Correction #8: Caller maintains ONE placeholder message.
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
  /// Correction #7: Flutter calls Back4App, never Manus directly.
  /// Correction #4: Returns real status_update.brief/description, NO fake percentages.
  Future<ManusTaskStatus> pollTaskStatus(String taskId) async {
    try {
      final url = Uri.parse('$_parseBaseUrl/functions/aiManusTaskStatus');

      String? idToken;
      try {
        idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode({
          'task_id': taskId,
          if (idToken != null) 'firebaseIdToken': idToken,
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
  /// Correction #8: Status updates go to a SINGLE placeholder message.
  /// Correction #4: NO fake progress percentages.
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
    final url = Uri.parse('$_parseBaseUrl/functions/aiManusGateway');

    String? idToken;
    try {
      idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {}

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
      // Session continuity & trusted identity
      if (request.appSessionId != null) 'appSessionId': request.appSessionId,
      if (idToken != null) 'firebaseIdToken': idToken,
      if (_currentUserId != null) 'userId': _currentUserId,
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
