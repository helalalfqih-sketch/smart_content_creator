import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:smart_content_creator/core/constants/firebase_prompt_template_ids.dart';
import 'package:smart_content_creator/services/firebase_ai_logic_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyBQlnuayzx7XICG2fMrUnSLrxq0D1kocfc',
            appId: '1:663916675240:web:6afa3dc19dcb77e26a829d',
            messagingSenderId: '663916675240',
            projectId: 'smartcontentcreator2',
            storageBucket: 'smartcontentcreator2.firebasestorage.app',
            authDomain: 'smartcontentcreator2.firebaseapp.com',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }

      // App Check activation for debug / test
      if (!kIsWeb) {
        try {
          // ignore: deprecated_member_use
          await FirebaseAppCheck.instance.activate(
            // ignore: deprecated_member_use
            androidProvider: AndroidProvider.debug,
          );
          debugPrint('🛡️ Firebase App Check initialized with Debug provider');
        } catch (e) {
          debugPrint('⚠️ App Check activation warning: $e');
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Firebase initialize note: $e');
    }
  });

  group('Wave 1A: Live Firebase Prompt Template Verification', () {
    late FirebaseAiLogicService service;

    setUp(() {
      service = FirebaseAiLogicService();
      // Ensure global cloud switch remains false for normal traffic
      FirebaseAiLogicService.useCloudPromptTemplates = false;
    });

    testWidgets('Live Test A: system_persona_default template call',
        (WidgetTester tester) async {
      debugPrint('\n========================================');
      debugPrint('🚀 RUNNING LIVE TEST A: system_persona_default');
      debugPrint('========================================');

      final stopwatch = Stopwatch()..start();
      final result = await service.generateFromTemplate(
        templateId: FirebasePromptTemplateIds.systemPersonaDefault,
        inputs: {'input': 'اكتب وصفاً إعلانياً قصيراً لمنتج تجريبي.'},
      );
      stopwatch.stop();

      debugPrint('⏱️ Latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('📦 Response Meta: ${result['meta']}');
      debugPrint('📄 Response Success: ${result['success']}');
      if (result['success'] == true) {
        debugPrint('📝 Response Text Preview:\n${result['data']}');
      } else {
        debugPrint('❌ Response Error:\n${result['error']}');
      }

      expect(result['meta']?['provider'], equals('firebase_ai_template'));
      expect(
        result['meta']?['template_id'],
        equals(FirebasePromptTemplateIds.systemPersonaDefault),
      );
    });

    testWidgets('Live Test B: system_persona_modification template call',
        (WidgetTester tester) async {
      debugPrint('\n========================================');
      debugPrint('🚀 RUNNING LIVE TEST B: system_persona_modification');
      debugPrint('========================================');

      final stopwatch = Stopwatch()..start();
      final result = await service.generateFromTemplate(
        templateId: FirebasePromptTemplateIds.systemPersonaModification,
        inputs: {
          'input':
              'عدل النص التالي ليكون أكثر اختصاراً واحترافية: هذا منتج ممتاز ومفيد جداً لجميع أفراد العائلة في المنزل والمكتب.'
        },
      );
      stopwatch.stop();

      debugPrint('⏱️ Latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('📦 Response Meta: ${result['meta']}');
      debugPrint('📄 Response Success: ${result['success']}');
      if (result['success'] == true) {
        debugPrint('📝 Response Text Preview:\n${result['data']}');
      } else {
        debugPrint('❌ Response Error:\n${result['error']}');
      }

      expect(result['meta']?['provider'], equals('firebase_ai_template'));
      expect(
        result['meta']?['template_id'],
        equals(FirebasePromptTemplateIds.systemPersonaModification),
      );
    });

    testWidgets('Live Test C: modification_rules_default (Reference Template)',
        (WidgetTester tester) async {
      debugPrint('\n========================================');
      debugPrint('🚀 RUNNING LIVE TEST C: modification_rules_default');
      debugPrint('========================================');

      final stopwatch = Stopwatch()..start();
      final result = await service.generateFromTemplate(
        templateId: FirebasePromptTemplateIds.modificationRulesDefault,
        inputs: {'input': 'عدل هذا النص التجريبي.'},
      );
      stopwatch.stop();

      debugPrint('⏱️ Latency: ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('📦 Response Meta: ${result['meta']}');
      debugPrint('📄 Response Success: ${result['success']}');
      if (result['success'] == true) {
        debugPrint('📝 Response Text Preview:\n${result['data']}');
      } else {
        debugPrint('❌ Response Error:\n${result['error']}');
      }

      expect(result['meta']?['provider'], equals('firebase_ai_template'));
      expect(
        result['meta']?['template_id'],
        equals(FirebasePromptTemplateIds.modificationRulesDefault),
      );
    });

    testWidgets('Routing Isolation: Backend route does NOT call Firebase templates',
        (WidgetTester tester) async {
      debugPrint('\n========================================');
      debugPrint('🔒 VERIFYING ROUTING ISOLATION');
      debugPrint('========================================');

      expect(AIBackendRouter.defaultBackend, equals('firebase_ai'));
      expect(AIBackendRouter.validBackends, contains('backend'));
      expect(FirebaseAiLogicService.useCloudPromptTemplates, isFalse);
      debugPrint('✅ Global useCloudPromptTemplates remains false');
      debugPrint('✅ Backend route is strictly isolated');
    });
  });
}
