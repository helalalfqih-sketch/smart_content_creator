import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:smart_content_creator/services/manus_ai_service.dart';
import 'package:smart_content_creator/core/models/canonical_ai_request.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('Firebase init note: $e');
    }
  });

  group('Live Manus API v2 & Back4App Production Verification', () {
    testWidgets('Live Verification: Concurrency, Auth, and Session Continuity', (WidgetTester tester) async {
      debugPrint('\n======================================================');
      debugPrint('🚀 STARTING LIVE PRODUCTION VERIFICATION ON ANDROID');
      debugPrint('======================================================');

      // 1. Ensure user is authenticated
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          final userCred = await FirebaseAuth.instance.signInAnonymously();
          user = userCred.user;
        } catch (authErr) {
          debugPrint('Auth sign-in warning: $authErr');
        }
      }

      expect(user, isNotNull, reason: 'Must have an authenticated Firebase user on device');
      final idToken = await user!.getIdToken(true);
      expect(idToken, isNotNull, reason: 'Must have a fresh Firebase ID token');
      expect(idToken!.length, greaterThan(50));

      debugPrint('[MANUS_AUTH] Authenticated Firebase UID obtained securely in-memory.');

      // 2. Run 20 Concurrent Requests Test against Back4App Gateway
      debugPrint('\n--- TEST A: 20 Concurrent First Requests (Same Session) ---');
      final session20 = DateTime.now().millisecondsSinceEpoch % 10000000;
      const gatewayUrl = 'https://parseapi.back4app.com/functions/aiManusGateway';
      final headers = {
        'X-Parse-Application-Id': 'uWUMmdbdRjcuOKuCcl9Pg7zEYxnYGVaLXjmveGF2',
        'X-Parse-REST-API-Key': 'Zsvk14ko9rvXD25G1hflNeY2Dg2hJtkocPvh6tMp',
        'Content-Type': 'application/json',
      };

      final payload20 = jsonEncode({
        'prompt': 'Hello Manus, testing 20 concurrent requests.',
        'taskType': 'general',
        'appSessionId': session20,
        'firebaseIdToken': idToken,
      });

      final stopwatch20 = Stopwatch()..start();
      final futures20 = List.generate(20, (_) => http.post(Uri.parse(gatewayUrl), headers: headers, body: payload20));
      final responses20 = await Future.wait(futures20);
      stopwatch20.stop();

      final taskIds20 = <String>{};
      int successCount20 = 0;

      for (final res in responses20) {
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final result = body['result'] ?? body;
          final taskId = result['task_id'] ?? result['meta']?['task_id'];
          if (taskId != null && taskId is String && taskId.isNotEmpty) {
            taskIds20.add(taskId);
          }
          if (result['success'] == true) {
            successCount20++;
          }
        } else {
          debugPrint('HTTP error in 20-concurrency: ${res.statusCode} ${res.body}');
        }
      }

      debugPrint('[MANUS_SESSION] 20 Concurrent Requests: successes=$successCount20/20, distinct_task_ids=${taskIds20.length}, duration_ms=${stopwatch20.elapsedMilliseconds}');
      expect(taskIds20.length, equals(1), reason: 'All 20 concurrent requests must resolve to exactly 1 task_id');
      expect(successCount20, equals(20), reason: 'All 20 requests must succeed');

      // 3. Test Session Continuity via ManusAiService
      debugPrint('\n--- TEST B: Session Continuity (Session N: Request 1 -> Request 2 -> Media Task) ---');
      final manusService = ManusAiService();
      final sessionN = DateTime.now().millisecondsSinceEpoch % 10000000;

      // Request 1
      final req1 = CanonicalAiRequest(
        prompt: 'مرحبا، ما هي أفضل خطة تسويقية لمنتج جديد؟',
        appSessionId: sessionN,
        taskType: 'general',
      );
      final res1 = await manusService.generateText(req1);
      debugPrint('[MANUS_SESSION] Request 1 in Session N: success=${res1['success']}, taskId=${res1['meta']?['task_id']}, mode=${res1['meta']?['conversation_mode']}');
      expect(res1['success'], isTrue);
      final taskIdN = res1['meta']?['task_id'];
      expect(taskIdN, isNotNull);

      // Request 2 (Follow-up)
      final req2 = CanonicalAiRequest(
        prompt: 'لخص الخطة في 3 نقاط رئيسية',
        appSessionId: sessionN,
        taskType: 'general',
      );
      final res2 = await manusService.generateText(req2);
      debugPrint('[MANUS_SESSION] Request 2 (Follow-up) in Session N: success=${res2['success']}, taskId=${res2['meta']?['task_id']}, mode=${res2['meta']?['conversation_mode']}');
      expect(res2['success'], isTrue);
      expect(res2['meta']?['task_id'], equals(taskIdN), reason: 'Follow-up request must reuse the exact same taskId');

      // 4. Test New Session (Session N+1) -> Distinct Task ID
      debugPrint('\n--- TEST C: New Session Isolation (Session N+1 != Session N) ---');
      final sessionN1 = (DateTime.now().millisecondsSinceEpoch + 1) % 10000000;
      final reqN1 = CanonicalAiRequest(
        prompt: 'مرحبا من جلسة جديدة',
        appSessionId: sessionN1,
        taskType: 'general',
      );
      final resN1 = await manusService.generateText(reqN1);
      final taskIdN1 = resN1['meta']?['task_id'];
      debugPrint('[MANUS_SESSION] Request in Session N+1: taskId=$taskIdN1, originalTaskId=$taskIdN');
      expect(resN1['success'], isTrue);
      expect(taskIdN1, isNot(equals(taskIdN)), reason: 'New session must generate a new distinct taskId');

      debugPrint('\n🎉 ALL ON-DEVICE LIVE VERIFICATION TESTS PASSED SUCCESSFULLY!');
    });
  });
}
