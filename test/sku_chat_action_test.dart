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
import 'package:smart_content_creator/models/sku_reading.dart';
import 'package:smart_content_creator/services/ai/sku_image_service.dart';
import 'package:smart_content_creator/widgets/chat_bubble.dart';

const reading = SkuReading('found', [
  PrintedProductCode(
    kind: 'sku',
    value: 'N/A-001',
    label: 'SKU',
    evidence: 'SKU: N/A-001',
    imageNumber: 1,
  ),
]);

class _Service extends SkuImageService {
  final started = Completer<void>();
  var result = Completer<SkuReading>();
  int calls = 0;
  List<File> images = [];
  CancelToken? cancel;
  @override
  Future<SkuReading> extract({
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
}

class _Agent extends ChatSmartAgent {
  _Agent(_Service service) : super(skuImageService: service);
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
  String get skuRequestContext => context;
  @override
  String get skuApiKey => key;
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
    'SKU action analyzes the clicked image once and saves its source with the result',
    () async {
      final work = agent.handleAction(
        'extract_sku',
        payload: {'messageId': answer.id},
      );
      await service.started.future.timeout(const Duration(seconds: 2));
      expect(agent.activeActionId.value, 'extract_sku');
      expect(agent.isLoading.value, isTrue);
      await agent.handleAction(
        'extract_sku',
        payload: {'messageId': answer.id},
      );
      expect(service.calls, 1);
      expect(service.images.single.path, '/old-label.jpg');
      service.result.complete(reading);
      await work;
      expect(agent.counted, 1);
      final result = agent.history.last;
      expect(result.provider, 'openrouter');
      expect(result.type, 'sku_result');
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
      await agent.extractSkuForMessage(noImage.id);
      expect(agent.history.last.content, contains('sku_image_required'));
      agent.history.assignAll([
        ChatMessage.user(image: File('/photo.jpg')),
        answer,
      ]);
      agent.key = '';
      await agent.extractSkuForMessage(answer.id);
      expect(agent.history.last.content, contains('missing_openrouter_key'));
      expect(service.calls, 0);
      expect(agent.counted, 0);
    },
  );

  test('usage denial does not start a paid request', () async {
    agent.allowed = false;
    await agent.extractSkuForMessage(answer.id);
    expect(service.calls, 0);
    expect(agent.isLoading.value, isFalse);
  });

  for (final change in ['account', 'session', 'deleted']) {
    test('late result is not written after $change change', () async {
      final work = agent.extractSkuForMessage(answer.id);
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
    final work = agent.extractSkuForMessage(answer.id);
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
    final work = agent.extractSkuForMessage(answer.id);
    await service.started.future.timeout(const Duration(seconds: 2));
    service.result.completeError(AiRequestException.http(402));
    await work;
    expect(agent.history.last.state, MessageState.error);
    expect(agent.history.last.content, contains('http_402'));
    expect(agent.counted, 0);
    expect(agent.isLoading.value, isFalse);
  });

  testWidgets(
    'smart tools SKU button carries the visible bubble identity to the handler',
    (tester) async {
      // This completion must belong to the widget test's FakeAsync zone.
      service.result = Completer<SkuReading>();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatBubble(
                id: answer.id,
                text: answer.content,
                isUser: false,
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
      expect(find.text('استخراج SKU'), findsOneWidget);
      await tester.tap(find.text('استخراج SKU'));
      await tester.pump();
      expect(
        service.calls,
        1,
        reason: 'The visible SKU button must start extraction',
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

  testWidgets(
    'SKU copy preserves literal identifiers instead of running legacy text cleanup',
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
              id: 'sku-result',
              type: 'sku_result',
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
