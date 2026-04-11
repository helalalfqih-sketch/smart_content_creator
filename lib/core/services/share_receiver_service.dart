import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:smart_content_creator/ai/ai_orchestrator.dart';
import 'package:smart_content_creator/controllers/navigation_controller.dart';

/// 📥 ShareReceiverService - Handles incoming shared content (images, videos, text)
/// from other apps like WhatsApp, Gallery, etc.
class ShareReceiverService extends GetxService {
  late StreamSubscription _intentDataStreamSubscription;
  final AIOrchestrator _orchestrator = Get.find<AIOrchestrator>();

  @override
  void onInit() {
    super.onInit();
    _initShareListener();
  }

  void _initShareListener() {
    debugPrint("📥 ShareReceiver: Initializing listeners...");
    
    // 1. For sharing coming from outside the app while the app is in the memory (All types: media, text, url)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      debugPrint("📥 ShareReceiver: Received intent stream update (${value.length} items)");
      if (value.isNotEmpty) {
        _processSharedMedia(value);
      }
    }, onError: (err) {
      debugPrint("❌ ShareReceiver Error (Stream): $err");
    });

    // 2. For sharing coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      debugPrint("📥 ShareReceiver: Checked initial intent (${value.length} items)");
      if (value.isNotEmpty) {
        _processSharedMedia(value);
      }
    }).catchError((err) {
      debugPrint("❌ ShareReceiver Error (Initial): $err");
    });
  }

  Future<void> _processSharedMedia(List<SharedMediaFile> media) async {
    debugPrint("📥 ShareReceiver: Processing ${media.length} shared items...");
    
    for (var file in media) {
      try {
        final path = file.path;
        final type = file.type;
        
        debugPrint("📂 ShareReceiver: Intent Data: '$path'");
        debugPrint("📂 ShareReceiver: Data Type: $type");
        
        if (path.isEmpty) {
          debugPrint("⚠️ ShareReceiver: Data is empty, skipping.");
          continue;
        }

        // 🛡️ Logic Refinement: Text/URL don't need File.exists() check
        if (type == SharedMediaType.text || type == SharedMediaType.url) {
          debugPrint("🚀 ShareReceiver: Sending text/url to AIOrchestrator...");
          await _orchestrator.processUserInput(text: path, forceNewSession: true);
          debugPrint("✅ ShareReceiver: Text/URL processed successfully.");
          continue; // ✅ Done with this item
        }

        // 🛡️ Images/Videos need File.exists() check
        final sharedFile = File(path);
        if (!await sharedFile.exists()) {
          debugPrint("❌ ShareReceiver: File does not exist at path: $path");
          continue;
        }

        debugPrint("🚀 ShareReceiver: Sending file to AIOrchestrator...");
        
        if (type == SharedMediaType.image) {
          await _orchestrator.processUserInput(images: [sharedFile], forceNewSession: true);
          debugPrint("✅ ShareReceiver: Image sent successfully.");
        } else if (type == SharedMediaType.video) {
          await _orchestrator.processUserInput(video: sharedFile, forceNewSession: true);
          debugPrint("✅ ShareReceiver: Video sent successfully.");
        } else {
          debugPrint("⚠️ ShareReceiver: Unknown media type: $type");
        }
      } catch (e, stack) {
        debugPrint("❌ ShareReceiver Error processing item: $e");
        debugPrint(stack.toString());
      }
    }

    // 🏎️ الانتقال التلقائي للمحادثة لرؤية النتائج
    _navigateToChat();
  }

  Future<void> _navigateToChat() async {
    try {
      debugPrint("🏎️ ShareReceiver: Navigating to Chat Screen...");
      
      // 1. التأكد من أننا في الواجهة الرئيسية
      // If we are already on home, we just switch tabs.
      // If we are on some deep screen, we go back to home first.
      if (Get.currentRoute != '/home' && Get.currentRoute != '/main') {
        Get.offAllNamed('/home');
        // انتظار بسيط لجاهزية المسار الجديد وتفاعليات GetX
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 2. تغيير التبويب إلى "الذكاء" (Index 1)
      if (Get.isRegistered<NavigationController>()) {
        final nav = Get.find<NavigationController>();
        nav.changePage(1);
        debugPrint("✅ ShareReceiver: Switched to Chat tab.");
      } else {
        // Fallback if NavigationController is not ready
        debugPrint("⚠️ ShareReceiver: NavigationController not found. Trying manual switch...");
        Get.toNamed('/home', arguments: {'index': 1});
      }
    } catch (e) {
      debugPrint("❌ ShareReceiver Navigation Error: $e");
    }
  }

  @override
  void onClose() {
    _intentDataStreamSubscription.cancel();
    super.onClose();
  }
}
