import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/ai/ai_orchestrator.dart';
import 'package:smart_content_creator/ai/chat_smart_agent.dart';
import 'package:smart_content_creator/core/models/chat_message.dart';
import 'package:smart_content_creator/gallery/gallery_library_screen.dart';
import 'package:smart_content_creator/screens/ai_chat_screen.dart';
import 'package:smart_content_creator/screens/ai_chat/mixins/chat_action_mixin.dart';
import 'package:smart_content_creator/screens/ai_chat/mixins/chat_media_mixin.dart';

class _Agent extends GetxController implements ChatSmartAgent {
  @override
  final isLoading = false.obs;
  @override
  final pipelineMessage = ''.obs;
  @override
  final pipelineProgress = 0.0.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Orchestrator extends GetxController implements AIOrchestrator {
  final calls = <({String? text, List<File> images, File? video})>[];
  @override
  Future<void> processUserInput({
    String? text,
    List<File>? images,
    File? video,
    String? replyToId,
    String? replyToContent,
    String? replyToRole,
    bool forceNewSession = false,
    CancelToken? cancelToken,
  }) async {
    calls.add((text: text, images: List.of(images ?? []), video: video));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness extends AiChatScreen {
  const _Harness({super.key});
  @override
  State<AiChatScreen> createState() => _HarnessState();
}

class _HarnessState extends State<AiChatScreen>
    with ChatMediaMixin, ChatActionMixin {
  @override
  final controller = TextEditingController();
  @override
  ChatMessage? replyingToMessage;
  String owner = 'account:one';
  Future<List<File>> Function(List<File>)? prepare;
  @override
  String galleryAccountOwner() => owner;
  @override
  Future<List<File>> prepareImagesForChat(List<File> files) async =>
      await (prepare?.call(files) ?? Future.value(files));
  @override
  void scrollToBottom({bool force = false}) {}
  @override
  void handleError(dynamic error) =>
      throw StateError('Unexpected send failure: $error');
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Draft'));
  @override
  void dispose() {
    disposeMedia();
    controller.dispose();
    super.dispose();
  }
}

void main() {
  late _Orchestrator orchestrator;
  setUp(() {
    Get.testMode = true;
    Get.put<ChatSmartAgent>(_Agent());
    orchestrator = _Orchestrator();
    Get.put<AIOrchestrator>(orchestrator);
  });
  tearDown(Get.reset);

  Future<_HarnessState> mount(WidgetTester tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(MaterialApp(home: _Harness(key: key)));
    return key.currentState!;
  }

  testWidgets(
    'library selection only stages photos; send uses the reviewed draft after removal',
    (tester) async {
      final state = await mount(tester);
      await state.attachGallerySelection(
        GalleryChatSelection('account:one', [
          File('/first.jpg'),
          File('/second.jpg'),
        ]),
      );
      expect(orchestrator.calls, isEmpty);
      expect(state.selectedImages.length, 2);
      await state.removePickedImage(0);
      state.controller.text = 'اكتب وصفًا للصورة';
      await state.sendMessage();
      expect(orchestrator.calls.single.images.map((x) => x.path), [
        '/second.jpg',
      ]);
      expect(orchestrator.calls.single.text, 'اكتب وصفًا للصورة');
      expect(state.selectedImages, isEmpty);
      expect(state.compressedImages, isEmpty);
    },
  );

  testWidgets(
    'late preparation cannot restore an image removed from the draft',
    (tester) async {
      final state = await mount(tester);
      final jobs = <Completer<List<File>>>[];
      final inputs = <List<File>>[];
      state.prepare = (files) {
        inputs.add(files);
        final c = Completer<List<File>>();
        jobs.add(c);
        return c.future;
      };
      final adding = state.handlePickedImages([
        File('/one.jpg'),
        File('/two.jpg'),
      ]);
      final removing = state.removePickedImage(0);
      jobs[1].complete(inputs[1]);
      await removing;
      jobs[0].complete(inputs[0]);
      await adding;
      await state.sendMessage();
      expect(orchestrator.calls.single.images.map((x) => x.path), ['/two.jpg']);
    },
  );

  testWidgets(
    'account change rejects old library selections and clears staged photos before send',
    (tester) async {
      final state = await mount(tester);
      await state.attachGallerySelection(
        GalleryChatSelection('account:other', [File('/private.jpg')]),
      );
      expect(state.selectedImages, isEmpty);
      await state.attachGallerySelection(
        GalleryChatSelection('account:one', [File('/private.jpg')]),
      );
      state.owner = 'account:two';
      await state.sendMessage();
      expect(orchestrator.calls, isEmpty);
      expect(state.selectedImages, isEmpty);
      expect(state.compressedImages, isEmpty);
    },
  );

  testWidgets(
    'new-account selection cannot inherit a previous-account draft before the auth stream arrives',
    (tester) async {
      final state = await mount(tester);
      await state.attachGallerySelection(
        GalleryChatSelection('account:one', [File('/private.jpg')]),
      );
      state.owner = 'account:two';
      await state.attachGallerySelection(
        GalleryChatSelection('account:two', [File('/current.jpg')]),
      );
      await state.sendMessage();
      expect(orchestrator.calls.single.images.map((x) => x.path), [
        '/current.jpg',
      ]);
    },
  );

  testWidgets('selecting a video removes stale prepared images', (
    tester,
  ) async {
    final state = await mount(tester);
    await state.handlePickedImages([File('/one.jpg')]);
    state.handlePickedVideo(File('/video.mp4'));
    await state.sendMessage();
    expect(orchestrator.calls.single.images, isEmpty);
    expect(orchestrator.calls.single.video?.path, '/video.mp4');
  });

  testWidgets(
    'repeat selection is deduplicated and disposal cancels pending draft preparation',
    (tester) async {
      final state = await mount(tester);
      await state.handlePickedImages([File('/one.jpg'), File('/one.jpg')]);
      expect(state.selectedImages.length, 1);
      final done = Completer<List<File>>();
      state.prepare = (_) => done.future;
      final preparing = state.handlePickedImages([File('/two.jpg')]);
      await tester.pumpWidget(const SizedBox.shrink());
      done.complete([File('/one.jpg'), File('/two.jpg')]);
      await preparing;
      expect(tester.takeException(), isNull);
      expect(orchestrator.calls, isEmpty);
    },
  );
}
