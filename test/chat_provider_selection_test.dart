import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/core/storage/app_storage_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';

class SelectionStorage extends AppStorageService {
  String? selection;
  SelectionStorage(this.selection);
  @override
  String? readString(String key, {String? defaultValue}) => selection ?? defaultValue;
  @override
  Future<void> writeString(String key, String value) async { selection = value; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { Get.testMode = true; });
  tearDown(Get.reset);

  test('saved hidden choices require user selection and never activate another paid provider', () async {
    for (final hidden in ['firebase_ai', 'backend', 'manus']) {
      await Get.reset();
      final storage = Get.put<AppStorageService>(SelectionStorage(hidden));
      final router = Get.put(AIBackendRouter());
      expect(router.currentBackend.value, 'unselected');
      expect(await router.resolveBackend(), 'unselected');
      expect(await router.switchBackend(hidden), isFalse);
      expect(storage.readString('chat_ai_backend'), hidden);
      final result = await router.generateText(prompt: 'hello');
      expect(result['success'], isFalse);
      expect(result['meta']['status'], 'selection_required');
      expect(router.findFailoverBackend(hidden), isNull);
    }
  });

  test('existing OpenRouter and SerpApi choices survive the update', () async {
    expect(AIBackendRouter.chatBackends, ['openrouter', 'serpapi']);
    for (final active in AIBackendRouter.chatBackends) {
      await Get.reset();
      Get.put<AppStorageService>(SelectionStorage(active));
      final router = Get.put(AIBackendRouter());
      expect(router.currentBackend.value, active);
      expect(await router.resolveBackend(), active);
      expect(router.findFailoverBackend(active), isNull);
    }
  });

  test('image requests with a removed saved provider stop before any service call', () async {
    Get.put<AppStorageService>(SelectionStorage('firebase_ai'));
    final router = Get.put(AIBackendRouter());
    final result = await router.analyzeProductVision(prompt: 'describe', imageBytes: Uint8List.fromList([1, 2, 3]));
    expect(result['success'], isFalse);
    expect(result['meta']['status'], 'selection_required');
  });
}
