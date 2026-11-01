import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as raster;
import 'package:smart_content_creator/ai/ai_decision_engine.dart';
import 'package:smart_content_creator/ai/chat_smart_agent.dart';
import 'package:smart_content_creator/ai/core/agent_models.dart';
import 'package:smart_content_creator/ai/core/image_generation_request.dart';
import 'package:smart_content_creator/controllers/settings_controller.dart';
import 'package:smart_content_creator/core/models/api_provider.dart';
import 'package:smart_content_creator/core/models/chat_message.dart';
import 'package:smart_content_creator/core/services/chat_state_service.dart';
import 'package:smart_content_creator/services/ai/openrouter_image_service.dart';
import 'package:smart_content_creator/services/ai_backend_router.dart';
import 'package:smart_content_creator/services/ai_image_generation_service.dart';

class ImageTestSettings extends SettingsController {
  @override
  void onInit() {}
  @override
  String getApiKey(ProviderType type) =>
      type == ProviderType.openrouter ? 'test-only-key' : '';
  @override
  ProviderType getActiveProvider() => ProviderType.openrouter;
}

class ImageTestRouter extends AIBackendRouter {
  @override
  Future<String> resolveBackend() async => 'openrouter';
}

class RecordingImageAgent extends ChatSmartAgent {
  final messages = <ChatMessage>[].obs;
  final AiImageGenerationService service;
  final router = ImageTestRouter();
  int counted = 0;
  int saved = 0;
  int updated = 0;

  RecordingImageAgent(this.service);
  @override
  RxList<ChatMessage> get history => messages;
  @override
  AiImageGenerationService get imageGenService => service;
  @override
  AIBackendRouter get aiRouter => router;
  @override
  Future<int?> addAndSaveMessage(ChatMessage message) async {
    messages.add(message);
    saved++;
    return null;
  }

  @override
  Future<void> updateMessage(
    String messageId,
    ChatMessage updatedMsg, {
    int? dbId,
  }) async {
    final index = messages.indexWhere((message) => message.id == messageId);
    messages[index] = updatedMsg;
    updated++;
  }

  @override
  Future<void> incrementVisualCount() async {
    counted++;
  }

  @override
  Future<void> respondNormally(
    String prompt, {
    List<File>? images,
    dio.CancelToken? cancelToken,
  }) async {
    throw StateError('Image creation was incorrectly sent to text chat');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late dio.Dio client;
  late OpenRouterImageService renderer;
  late AiImageGenerationService service;
  late Uint8List png;
  late Map<String, dynamic> response;
  late RecordingImageAgent agent;
  final requests = <dio.RequestOptions>[];
  int status = 200;
  dio.DioExceptionType? transportError;

  setUp(() async {
    Get.testMode = true;
    Get.put<SettingsController>(ImageTestSettings());
    Get.put(ChatStateService());
    directory = await Directory.systemTemp.createTemp('scc-image-test-');
    png = Uint8List.fromList(
      raster.encodePng(raster.Image(width: 2, height: 2)),
    );
    response = {
      'data': [
        {'b64_json': base64Encode(png), 'media_type': 'image/png'},
      ],
    };
    status = 200;
    transportError = null;
    requests.clear();
    client = dio.Dio();
    client.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (transportError != null) {
            handler.reject(
              dio.DioException(requestOptions: options, type: transportError!),
            );
          } else {
            handler.resolve(
              dio.Response(
                requestOptions: options,
                statusCode: status,
                data: response,
              ),
            );
          }
        },
      ),
    );
    renderer = OpenRouterImageService(
      client: client,
      documentsDirectory: () async => directory,
    );
    service = AiImageGenerationService(openRouterImages: renderer);
    agent = RecordingImageAgent(service);
  });

  tearDown(() async {
    client.close(force: true);
    Get.reset();
    await directory.delete(recursive: true);
  });

  test(
    'planned generate_image task renders, persists and displays the actual PNG',
    () async {
      final reference = await File(
        '${directory.path}/reference.png',
      ).writeAsBytes(png);
      final task = AiDecisionEngine.createTask(
        'صمم صورة لهذا المنتج',
        overrideIntent: Intent.imageGeneration,
        hasImage: true,
        mediaFile: reference,
        images: [reference],
      );
      await agent.executeTask(task, skipHistory: true);
      final request = requests.single;
      expect(request.uri.toString(), 'https://openrouter.ai/api/v1/images');
      expect(request.data['model'], OpenRouterImageService.model);
      expect(request.data['provider'], {
        'only': ['google-vertex/global'],
        'allow_fallbacks': false,
      });
      expect(
        request.headers['HTTP-Referer'],
        'https://smartcontentcreator.com/',
      );
      expect(request.headers['Authorization'], 'Bearer test-only-key');
      final referenceUrl =
          request.data['input_references'][0]['image_url']['url'] as String;
      expect(base64Decode(referenceUrl.split(',').last), png);
      expect(agent.saved, 1);
      expect(agent.updated, 1);
      expect(agent.counted, 1);
      final message = agent.messages.single;
      expect(message.state, MessageState.completed);
      expect(message.type, 'generated_image');
      expect(message.hasImages, isTrue);
      expect(message.attachments.single.source, 'openrouter_generated');
      expect(message.image, isNotNull);
      expect(await message.image!.readAsBytes(), png);
      expect(message.image!.path, contains('generated_images'));
      final restored = ChatMessage.fromMap(message.toMap());
      expect(restored.hasImages, isTrue);
      expect(await restored.image!.readAsBytes(), png);
      expect(agent.isLoading.value, isFalse);
    },
  );

  test(
    'automatic provider selection uses the configured OpenRouter key',
    () async {
      final result = await service.generateImage('صمم صورة قطة');
      expect(result.success, isTrue);
      expect(result.provider, AiImageGenerationService.providerOpenRouter);
      expect(requests, hasLength(1));
    },
  );

  test(
    'contextual design uses the last user image, not a generated image',
    () async {
      final reference = await File(
        '${directory.path}/product.png',
      ).writeAsBytes(png);
      agent.messages.add(ChatMessage.user(image: reference));
      agent.messages.add(ChatMessage.assistant(content: 'تحليل المنتج'));
      await agent.handleImageGeneration('هل تستطيع تصميم صورة');
      expect(requests.single.data['input_references'], hasLength(1));
      expect(agent.messages.last.hasImages, isTrue);
    },
  );

  test('unrelated new subject does not reuse old product references', () async {
    final reference = await File(
      '${directory.path}/product.png',
    ).writeAsBytes(png);
    agent.messages.add(ChatMessage.user(image: reference));
    await agent.handleImageGeneration('صمم صورة قطة في حديقة');
    expect(requests.single.data.containsKey('input_references'), isFalse);
  });

  test(
    'text follow-up with an empty image list retains product context',
    () async {
      final reference = await File(
        '${directory.path}/product.png',
      ).writeAsBytes(png);
      agent.messages.add(ChatMessage.user(image: reference));
      final task = AiDecisionEngine.createTask(
        'صمم صورة لهذا المنتج',
        overrideIntent: Intent.imageGeneration,
        images: [],
      );
      await agent.executeTask(task, skipHistory: true);
      expect(requests.single.data['input_references'], hasLength(1));
      expect(agent.messages.last.hasImages, isTrue);
    },
  );

  test('creator bridge displays the result instead of discarding it', () async {
    await agent.generateCreatorImage('صمم صورة شاطئ');
    expect(agent.messages.single.hasImages, isTrue);
    expect(agent.counted, 1);
  });

  for (final invalid in [
    <String, dynamic>{
      'choices': [
        {
          'message': {'content': 'Here is a design idea'},
        },
      ],
    },
    <String, dynamic>{'data': []},
    <String, dynamic>{
      'data': [
        {'b64_json': base64Encode(utf8.encode('<html>error</html>'))},
      ],
    },
    <String, dynamic>{
      'data': [
        {'b64_json': 'not-valid-base64%%%'},
      ],
    },
    <String, dynamic>{
      'data': [
        {
          'b64_json': base64Encode([137, 80, 78, 71, 13, 10, 26, 10]),
        },
      ],
    },
  ]) {
    test(
      'text-only or corrupt response never becomes a successful image: $invalid',
      () async {
        response = invalid;
        await agent.handleImageGeneration('صمم صورة شاطئ');
        expect(agent.messages.single.state, MessageState.error);
        expect(agent.messages.single.hasImages, isFalse);
        expect(agent.counted, 0);
        expect(requests, hasLength(1));
        expect(agent.isLoading.value, isFalse);
      },
    );
  }

  for (final code in [401, 402, 403, 429, 500]) {
    test(
      'HTTP $code stays an error without changing provider or billing twice',
      () async {
        status = code;
        await agent.handleImageGeneration('صمم صورة شاطئ');
        expect(agent.messages.single.state, MessageState.error);
        expect(agent.counted, 0);
        expect(requests, hasLength(1));
        expect(agent.messages.single.content, isNot(contains('test-only-key')));
      },
    );
  }

  test('timeout does not retry a paid generation', () async {
    transportError = dio.DioExceptionType.receiveTimeout;
    await agent.handleImageGeneration('صمم صورة شاطئ');
    expect(requests, hasLength(1));
    expect(agent.messages.single.state, MessageState.error);
    expect(agent.counted, 0);
  });

  test('cancelled operation never starts a generation', () async {
    final cancellation = dio.CancelToken()..cancel();
    await agent.handleImageGeneration(
      'صمم صورة شاطئ',
      cancelToken: cancellation,
    );
    expect(requests, isEmpty);
    expect(agent.messages.single.state, MessageState.error);
    expect(agent.counted, 0);
  });

  test('missing or too many reference files fail before charging', () async {
    for (final files in [
      [File('${directory.path}/missing.png')],
      List.filled(4, File('missing.png')),
    ]) {
      await expectLater(
        renderer.generate(
          prompt: 'Create a photo',
          apiKey: 'test-only-key',
          referenceImages: files,
        ),
        throwsA(isA<ImageGenerationException>()),
      );
    }
    expect(requests, isEmpty);
  });

  test(
    'actual JPEG bytes determine extension even if response MIME is wrong',
    () async {
      final jpeg = raster.encodeJpg(raster.Image(width: 2, height: 2));
      response = {
        'data': [
          {'b64_json': base64Encode(jpeg), 'media_type': 'image/png'},
        ],
      };
      final result = await renderer.generate(
        prompt: 'Create a photo',
        apiKey: 'test-only-key',
      );
      expect(result.mimeType, 'image/jpeg');
      expect(result.file.path, endsWith('.jpg'));
    },
  );

  test(
    'creation requests route while analysis, negation and prompt-writing stay text',
    () {
      for (final text in [
        'هل تستطيع تصميم صورة',
        'هل تستطيع أن تصمم صورة',
        'صَمِّم صورة لهذا المنتج',
        'أنشئ صورة بدون خلفية',
        'Create an image of this product',
      ]) {
        expect(ImageGenerationRequest.matches(text), isTrue, reason: text);
      }
      for (final text in [
        'حلل هذه الصورة',
        'اكتب وصفًا لهذه الصورة',
        'كيف أصمم صورة؟',
        'لا تنشئ صورة',
        'لا تصمم صورة',
        'اكتب برومبت لتصميم صورة',
        "Don't create an image",
        'Explain how to generate an image',
      ]) {
        expect(ImageGenerationRequest.matches(text), isFalse, reason: text);
      }
    },
  );
}
