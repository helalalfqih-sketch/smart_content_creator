import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_content_creator/ai/chat_smart_agent.dart';
import 'package:smart_content_creator/core/models/chat_message.dart';
import 'package:smart_content_creator/core/utils/ai_request_exception.dart';
import 'package:smart_content_creator/models/product_model_reading.dart';
import 'package:smart_content_creator/services/ai/product_model_image_service.dart';
import 'package:smart_content_creator/widgets/chat_bubble.dart';

const reading = ProductModelReading('found', [
  PrintedProductCode(
    kind: 'model',
    value: 'N/A-001',
    label: 'Model',
    evidence: 'Model: N/A-001',
    imageNumber: 1,
  ),
]);

class _Service extends ProductModelImageService {
  final started = Completer<void>();
  var result = Completer<ProductModelReading>();
  var lensResult = Completer<List<ProductModelCandidate>>();
  int calls = 0;
  int lensCalls = 0;
  List<File> images = [];
  CancelToken? cancel;
  @override
  Future<ProductModelReading> extract({
    required List<File> images,
    required String apiKey,
    required CancelToken cancelToken,
    bool Function()? isCurrent,
  }) {
    calls++;
    this.images = images;
    cancel = cancelToken;
    if (!started.isCompleted) started.complete();
    return result.future;
  }

  @override
  Future<List<ProductModelCandidate>> searchSimilar({
    required File image,
    required CancelToken cancelToken,
    bool Function()? isCurrent,
  }) {
    lensCalls++;
    images = [image];
    cancel = cancelToken;
    if (!started.isCompleted) started.complete();
    return lensResult.future;
  }
}

class _Agent extends ChatSmartAgent {
  _Agent(_Service service) : super(productModelImageService: service);
  @override
  // ignore: must_call_super
  void onInit() {} // Offline harness: no auth, database or cloud services.
  @override
  final history = <ChatMessage>[].obs;
  @override
  final isLoading = false.obs;
  @override
  final activeRequests = 0.obs;
  String context = 'account-one:session-one';
  String key = 'local-test-key';
  int counted = 0;
  bool allowed = true;
  @override
  String get modelRequestContext => context;
  @override
  String get modelApiKey => key;
  @override
  Future<bool> checkVisualLimit() async => allowed;
  @override
  Future<void> incrementVisualCount() async {
    counted++;
  }

  @override
  Future<int?> addAndSaveMessage(ChatMessage message) async {
    history.add(message);
    return null;
  }
}

void main() {
  late _Service service;
  late _Agent agent;
  late ChatMessage answer;
  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    service = _Service();
    agent = _Agent(service);
    Get.put<ChatSmartAgent>(agent);
    answer = ChatMessage.assistant(
      content: 'First product',
      state: MessageState.completed,
    );
    agent.history.addAll([
      ChatMessage.user(image: File('/old-label.jpg')),
      answer,
      ChatMessage.user(image: File('/new-product.jpg')),
    ]);
  });
  tearDown(Get.reset);

  test(
    'Model action analyzes the clicked image once and saves its source with the result',
    () async {
      final work = agent.handleAction(
        'identify_model',
        payload: {'messageId': answer.id},
      );
      await service.started.future.timeout(const Duration(seconds: 2));
      expect(agent.activeActionId.value, 'identify_model');
      expect(agent.isLoading.value, isTrue);
      await agent.handleAction(
        'identify_model',
        payload: {'messageId': answer.id},
      );
      expect(service.calls, 1);
      expect(service.images.single.path, '/old-label.jpg');
      service.result.complete(reading);
      await work;
      expect(agent.counted, 1);
      final result = agent.history.last;
      expect(result.provider, 'openrouter');
      expect(result.type, 'model_result');
      expect(result.content, contains('N/A-001'));
      expect(result.attachments.single.localPath, '/old-label.jpg');
      expect(agent.isLoading.value, isFalse);
      expect(agent.activeActionId.value, isEmpty);
    },
  );

  test(
    'missing image or local key shows useful errors without an AI request',
    () async {
      final noImage = ChatMessage.assistant(content: 'Text');
      agent.history.assignAll([ChatMessage.user(content: 'Hello'), noImage]);
      await agent.identifyProductModelForMessage(noImage.id);
      expect(agent.history.last.content, contains('model_image_required'));
      agent.history.assignAll([
        ChatMessage.user(image: File('/photo.jpg')),
        answer,
      ]);
      agent.key = '';
      await agent.identifyProductModelForMessage(answer.id);
      expect(agent.history.last.content, contains('missing_openrouter_key'));
      expect(service.calls, 0);
      expect(agent.counted, 0);
    },
  );

  test('usage denial does not start a paid request', () async {
    agent.allowed = false;
    await agent.identifyProductModelForMessage(answer.id);
    expect(service.calls, 0);
    expect(agent.isLoading.value, isFalse);
  });

  test(
    'missing model is honest and never triggers a second paid search automatically',
    () async {
      final work = agent.identifyProductModelForMessage(answer.id);
      await service.started.future;
      service.result.complete(const ProductModelReading('not_visible', []));
      await work;
      expect(agent.history.last.content, contains('لم يظهر اسم أو رقم موديل'));
      expect(agent.history.last.content, contains('عدسة Google'));
      expect(service.calls, 1);
      expect(service.lensCalls, 0);
    },
  );

  test(
    'explicit Lens uses selected older photo, no OpenRouter key, and saves candidates',
    () async {
      agent.key = '';
      agent.history[0] = ChatMessage.user(
        images: [File('/front.jpg'), File('/back.jpg')],
      );
      final work = agent.handleAction(
        'model_lens_search',
        payload: {'messageId': answer.id, 'imageNumber': 2},
      );
      await service.started.future;
      await agent.handleAction(
        'model_lens_search',
        payload: {'messageId': answer.id, 'imageNumber': 2},
      );
      expect(service.lensCalls, 1);
      expect(service.calls, 0);
      expect(service.images.single.path, '/back.jpg');
      service.lensResult.complete([
        const ProductModelCandidate(
          title: 'Possible X-100',
          link: 'https://example.test/x100',
          thumbnail: 'https://example.test/x100.jpg',
          source: 'Shop',
        ),
      ]);
      await work;
      final result = agent.history.last;
      expect(result.type, 'model_candidates');
      expect(result.provider, 'serpapi');
      expect(result.content, contains('الموديل غير مؤكد'));
      expect(result.attachments.single.localPath, '/back.jpg');
      expect(result.agentResult, isNotNull);
      expect(agent.counted, 1);
    },
  );

  test(
    'invalid Lens photo index does not select a different photo or start billing',
    () async {
      for (final index in [0, -1, 2, '1']) {
        await agent.handleAction(
          'model_lens_search',
          payload: {'messageId': answer.id, 'imageNumber': index},
        );
        expect(agent.history.last.state, MessageState.error);
      }
      expect(service.lensCalls, 0);
      expect(service.calls, 0);
      expect(agent.counted, 0);
    },
  );

  for (final change in ['account', 'session', 'deleted', 'cancelled']) {
    test('Lens result is discarded after $change', () async {
      final work = agent.identifyProductModelForMessage(
        answer.id,
        visualImageNumber: 1,
      );
      await service.started.future;
      if (change == 'deleted') {
        agent.history.removeWhere((m) => m.id == answer.id);
      } else if (change == 'cancelled') {
        agent.cancelCurrentOperation();
      } else {
        agent.context = 'new-$change';
      }
      final count = agent.history.length;
      service.lensResult.complete([]);
      await work;
      expect(agent.history.length, count);
      expect(agent.counted, 0);
    });
  }

  test('empty Lens result is not a model identification', () async {
    final work = agent.identifyProductModelForMessage(
      answer.id,
      visualImageNumber: 1,
    );
    await service.started.future;
    service.lensResult.complete([]);
    await work;
    expect(agent.history.last.content, contains('لم تظهر ترشيحات'));
    expect(agent.history.last.agentResult, isNull);
  });

  test(
    'saved SKU action delegates to model reading for compatibility',
    () async {
      final work = agent.handleAction(
        'extract_sku',
        payload: {'messageId': answer.id},
      );
      await service.started.future;
      service.result.complete(reading);
      await work;
      expect(agent.history.last.type, 'model_result');
      expect(agent.history.last.content, contains('الموديل المقروء'));
    },
  );

  for (final change in ['account', 'session', 'deleted']) {
    test('late result is not written after $change change', () async {
      final work = agent.identifyProductModelForMessage(answer.id);
      await service.started.future.timeout(const Duration(seconds: 2));
      if (change == 'deleted') {
        agent.history.removeWhere((m) => m.id == answer.id);
      } else {
        agent.context = 'new-$change';
      }
      final count = agent.history.length;
      service.result.complete(reading);
      await work;
      expect(agent.history.length, count);
      expect(agent.counted, 0);
    });
  }

  test('stop cancels transport and ignores a late provider result', () async {
    final work = agent.identifyProductModelForMessage(answer.id);
    await service.started.future.timeout(const Duration(seconds: 2));
    agent.cancelCurrentOperation();
    expect(service.cancel!.isCancelled, isTrue);
    service.result.complete(reading);
    await work;
    expect(agent.history.length, 3);
    expect(agent.isLoading.value, isFalse);
    expect(agent.counted, 0);
  });

  test('provider errors remain errors and clear the busy state', () async {
    final work = agent.identifyProductModelForMessage(answer.id);
    await service.started.future.timeout(const Duration(seconds: 2));
    service.result.completeError(AiRequestException.http(402));
    await work;
    expect(agent.history.last.state, MessageState.error);
    expect(agent.history.last.content, contains('http_402'));
    expect(agent.counted, 0);
    expect(agent.isLoading.value, isFalse);
  });

  testWidgets(
    'smart tools Model button carries the visible bubble identity to the handler',
    (tester) async {
      // This completion must belong to the widget test's FakeAsync zone.
      service.result = Completer<ProductModelReading>();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatBubble(
                id: answer.id,
                text: answer.content,
                isUser: false,
                actions: const [
                  {'label': 'استخراج SKU', 'action': 'extract_sku'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('الأدوات الذكية ⚡'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('تحديد موديل المنتج'), findsOneWidget);
      expect(find.text('استخراج SKU'), findsNothing);
      await tester.tap(find.text('تحديد موديل المنتج'));
      await tester.pump();
      expect(
        service.calls,
        1,
        reason: 'The visible Model button must start extraction',
      );
      expect(service.images.single.path, '/old-label.jpg');
      service.result.complete(reading);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(agent.history.last.content, contains('N/A-001'));
    },
  );

  testWidgets('Lens buttons keep each saved result photo and show candidates', (
    tester,
  ) async {
    service.lensResult = Completer<List<ProductModelCandidate>>();
    final saved = ChatMessage.fromMap(
      ChatMessage.assistant(
        content: 'لم يظهر اسم أو رقم موديل',
        type: 'model_result',
        images: [File('/front.jpg'), File('/back.jpg')],
      ).toMap(),
    );
    agent.history.insert(2, saved);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatBubble(
              id: saved.id,
              text: saved.content,
              type: saved.type,
              attachments: saved.attachments,
              isUser: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('الأدوات الذكية ⚡'));
    await tester.pumpAndSettle();
    expect(find.text('عدسة Google · الصورة 1'), findsOneWidget);
    expect(find.text('عدسة Google · الصورة 2'), findsOneWidget);
    expect(find.text('🖼️ عدسة google'), findsNothing);
    await tester.ensureVisible(find.text('عدسة Google · الصورة 2'));
    await tester.tap(find.text('عدسة Google · الصورة 2'));
    await tester.pump();
    expect(service.lensCalls, 1);
    expect(service.images.single.path, '/back.jpg');
    service.lensResult.complete([]);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(agent.history.last.content, contains('لم تظهر ترشيحات'));
  });

  testWidgets(
    'Model copy preserves literal identifiers instead of running legacy text cleanup',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ChatBubble(
              id: 'model-result',
              type: 'model_result',
              text: reading.toChatText(),
              isUser: false,
            ),
          ),
        ),
      );
      await tester.tap(find.text('نسخ'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(copied, contains('N/A-001'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );
}
