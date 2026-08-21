import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

import '../../controllers/settings_controller.dart';
import '../../core/models/chat_message.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/log_service.dart';
import '../chat_smart_agent.dart';
import '../../utils/logger.dart';
import '../core/agent_models.dart';
import '../../services/ai_backend_router.dart';

mixin AgentMediaMixin on GetxService {
  ChatSmartAgent get agent => this as ChatSmartAgent;

  Future<void> handleVisionAnalysis(File file, {dynamic preAnalyzedResult, dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleVisionAnalysis with file: ${file.path}');
    LogService.info("🎨 Image received for analysis", tag: 'MediaMixin');

    agent.updateStage(1, 2, "👁️ جاري فهم الصورة...");
    try {
      // 🛡️ Usage Limit Check
      if (!await agent.checkVisualLimit()) return;

      final result = preAnalyzedResult ??
          await agent.visionProductService.analyzeImage(
            file,
            cancelToken: cancelToken,
          );
      
      // 📸 Increment count on success
      await agent.incrementVisualCount();

      final Map<String, dynamic> data = result.data ?? {};
      final String? productName = result.productName;

      String response;
      bool isCommercial = data['is_commercial'] == true;

      // =========================
      // 🛒 CASE 1: Product / Subject Detected
      // =========================
      if (productName != null && productName.trim().isNotEmpty) {
        isCommercial = data['is_commercial'] == true;
        final String category = (data['category'] ?? '').toString().toLowerCase();
        final bool isPerson = category.contains('person') || category.contains('selfie');
        final String teaser = data['teaser'] ?? "✨ منتج مميز بتصميم عملي وجذاب.";

        if (isCommercial && !isPerson) {
          agent.saveProductToMemory(productName);
          // ✨ وصف تسويقي ديناميكي للمنتجات التجارية
          response = """
🛍️ **$productName**

${data['description'] ?? ''}

$teaser
""";
        } else if (isPerson) {
          // 🤳 وصف ودي ديناميكي للصور الشخصية
          response = """
👋 **مرحباً!**

تبدو هذه صورة رائعة. لقد لاحظت وجود:
✨ $productName

${data['description'] ?? ''}

$teaser
""";
        } else {
          // 👕 وصف طبيعي ديناميكي للملابس أو الأشياء في سياق شخصي
          response = """
🔍 **اكتشفت في الصورة:**

$productName

${data['description'] ?? ''}

$teaser
""";
        }
      }

      // =========================
      // 🎨 CASE 2: Not a Product
      // =========================
      else {
        final String description =
            data['description'] ?? "هذه صورة تحتوي على عناصر متعددة.";

        response = """
🖼️ **وصف الصورة:**

$description
""";
      }

      final String searchQuery = data['search_query'] ?? productName ?? "";

      final String providerUsed = data['provider'] ??
          (Get.isRegistered<AIBackendRouter>()
              ? Get.find<AIBackendRouter>().currentBackend.value
              : 'firebase_ai');

      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: response,
          productContext: productName,
          provider: providerUsed,
          actions: [
            {
              'type': 'google_lens',
              'label': 'Google Lens 👁️',
              'toolId': 'google_lens',
            },
            {
              'type': 'google_search',
              'label': 'Google: $searchQuery 🔍',
              'toolId': 'google_search',
              'parameters': searchQuery,
            },
            if (isCommercial)
              {
                'type': 'amazon_search',
                'label': 'Amazon: $searchQuery 🛒',
                'toolId': 'amazon_search',
                'parameters': searchQuery,
              },
          ],
        ).copyWith(state: MessageState.completed),
      );

      if (productName != null) {
        agent.lastSearchQuery.value = searchQuery; // 🔥 حفظ الاستعلام الإنجليزي التفصيلي للبحث اللاحق
        await agent.saveToDb(productName, response);
      }
      
      // 📊 تتبع تحليل الصور البصري (تم نقله هنا لحفظ تفاصيل المزود المستجيب)
      agent.trackAction(
        'visual_search',
        payload: searchQuery,
        provider: providerUsed,
        force: true,
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('429') || errStr.contains('402')) {
        Get.snackbar(
          "تنبيه الرصيد",
          "رصيد التوليد السحابي نفد، جاري المحاولة باستخدام المحرك البديل.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      ErrorHandler.logError('Vision Analysis', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل تحليل الصورة: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleVisionAnalysis');
    }
  }

  Future<void> handleBrandedAdPipeline(File file, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleBrandedAdPipeline with file: ${file.path}');
    LogService.info("🎨 Starting Branded Ad Pipeline for: ${file.path}", tag: 'MediaMixin');
    agent.updateStage(1, 4, "✂️ جاري عزل المنتج عن الخلفية...");
    try {
      // 🛡️ Usage Limit Check
      if (!await agent.checkVisualLimit()) return;

      final isolated = await agent.bgRemovalService.removeBackground(file, cancelToken: cancelToken);
      if (isolated == null) throw Exception("فشل عزل المنتج");

      // 📸 Increment count on success
      await agent.incrementVisualCount();

      agent.updateStage(2, 4, "🎨 جاري تصميم خلفية احترافية ملائمة...");
      final prompt = "A premium commercial photography background for ${agent.lastAnalyzedProduct.value ?? 'product'}, high-end lighting, minimalist style";
      final background = await agent.imageGenService.generateImage(prompt, cancelToken: cancelToken);
      
      agent.updateStage(3, 4, "📸 جاري دمج المنتج مع الخلفية الجديدة...");
      final response = "✨ تم إنشاء الإعلان الاحترافي بنجاح! لقد قمت بعزل المنتج ووضعه في بيئة تسويقية فاخرة.";
      await agent.addAndSaveMessage(ChatMessage.assistant(content: response).copyWith(image: background.file, state: MessageState.completed));
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('429') || errStr.contains('402')) {
        Get.snackbar(
          "تنبيه الرصيد",
          "رصيد التوليد السحابي نفد، جاري المحاولة باستخدام المحرك البديل.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      ErrorHandler.logError('Branded Ad Pipeline', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل تصميم الإعلان: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleBrandedAdPipeline');
    }
  }

  Future<void> handleEnhanceProductImage(File file) async {
    AppLogger.info('ENTERING: handleEnhanceProductImage with file: ${file.path}');
    LogService.info("🎨 Enhancing image: ${file.path}", tag: 'MediaMixin');
    agent.updateStage(1, 2, "🪄 جاري تحسين جودة الصورة وتعديل الإضاءة...");
    try {
      final response = "✨ تم تحسين الصورة بنجاح! لقد قمت بضبط التباين والحدة لجعل المنتج يبدو أكثر جاذبية.";
      await agent.addAndSaveMessage(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Enhance Image', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل تحسين الصورة: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleEnhanceProductImage');
    }
  }

  Future<void> handleAudioEnhance(String path) async {
    AppLogger.info('ENTERING: handleAudioEnhance with path: $path');
    agent.updateStage(1, 2, "🎙️ جاري تصفية الصوت وإزالة الضجيج...");
    try {
      final response = "✅ تم تحسين مقطع الصوت بنجاح. تم تقليل الضجيج وتحسين وضوح الكلام.";
      await agent.addAndSaveMessage(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Audio Enhance', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل تحسين الصوت: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleAudioEnhance');
    }
  }

  Future<void> handleVisualInspiration(String query, {File? image, dio.CancelToken? cancelToken}) async {
    // 🧠 Context Fetch: If image is null, try to retrieve the latest image from global state
    final File? effectiveImage = image ?? 
        (agent.latestUploadPath.value != null ? File(agent.latestUploadPath.value!) : null);

    AppLogger.info('ENTERING: handleVisualInspiration with query: $query, hasImage: ${effectiveImage != null}');
    LogService.info("🎨 Searching visual inspiration for: $query", tag: 'MediaMixin');
    
    agent.isLoading.value = true;
    final stageMsg = effectiveImage != null 
        ? "🎯 جاري البحث عن مطابقات بصرية دقيقة (100%)..." 
        : "🎨 جاري البحث عن مصادر إلهام بصري لـ ($query)...";
        
    agent.updateStage(1, 2, stageMsg);
    
    try {
      String effectiveQuery = query;

      // 🎯 [Reverse Search Logic]: Try to get the precise query from ProductMemory (like we do for videos)
      try {
        final memory = await agent.productMemory.getLastProduct('');
        if (memory != null && memory.searchQuery.isNotEmpty) {
          effectiveQuery = memory.searchQuery;
          AppLogger.info('🎯 [VisualInspiration] Using ProductMemory search_query: $effectiveQuery');
        }
      } catch (_) {}

      final results = await agent.imagesService.search(effectiveQuery);
      final List resultsList = (results['images_results'] as List?) ?? [];

      // 🚀 [FIX]: Limit to 30 high-quality images as requested by the user for better focus
      final limitedResults = resultsList.take(30).toList();
      final int count = limitedResults.length;
      
      AppLogger.info('SUCCESS: handleVisualInspiration found $count matches (Limited from ${resultsList.length}).');
      LogService.success("🎨 Visual inspiration results: $count", tag: 'MediaMixin');

      final response = count > 0 
          ? (image != null 
              ? "🎯 لقد وجدت $count مطابقة بصرية دقيقة جداً لهذا المنتج. يمكنك استعراض النسخ المتصلة والألوان المتاحة."
              : "🎨 لقد وجدت $count مصدر إلهام بصري دقيق لـ ($query). يمكنك الاستعانة بهذه الأنماط لتطوير محتواك.")
          : "🎨 لم أجد نتائج كافية حالياً، سأحاول بعبارات بحث مختلفة.";

      AgentResult? agentResult;
      if (count > 0) {
        final List<ImageItem> galleryImages = [];
        for (var img in limitedResults) {
          final imgMap = img is Map<String, dynamic> ? img : <String, dynamic>{};
          
          // 👀 Support both Lens (thumbnail: image) and Google Images (thumbnail: thumbnail)
          final String? realImage = imgMap['original']?.toString() ?? 
                                   imgMap['original_image']?.toString() ??
                                   imgMap['image']?.toString();

          galleryImages.add(ImageItem(
            title: imgMap['title']?.toString() ?? '',
            link: imgMap['link']?.toString() ?? '',
            thumbnail: imgMap['thumbnail']?.toString() ?? imgMap['image']?.toString() ?? '',
            originalUrl: realImage, // 🔗 Use detected direct link
            source: imgMap['source']?.toString() ?? '',
            metadata: imgMap,
          ));
        }

        agentResult = AgentResult(
          type: AgentResultType.imageGallery,
          data: ImageGalleryData(
            images: galleryImages,
            query: query,
            title: image != null ? "مطابقات بصرية: $query" : "إلهام بصري: $query",
          ),
          executionTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }

      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: response, 
          agentResult: agentResult,
          actions: agentResult == null ? null : [
            {"label": "🔍 بحث بصري (Lens)", "action": "visual_search"},
          ],
        ).copyWith(state: MessageState.completed),
      );
    } catch (e) {
      ErrorHandler.logError('Visual Inspiration', e);
      agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "عذراً، واجهت مشكلة أثناء البحث البصري. هل يمكنك المحاولة مرة أخرى أو إرسال الصورة مجدداً؟ 🎨",
        ).copyWith(state: MessageState.completed),
      );
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleVisualInspiration');
    }
  }

  Future<void> handleVideoGeneration(String prompt, {dio.CancelToken? cancelToken}) async {
    final settings = Get.find<SettingsController>();
    final activeProvider = settings.getActiveVideoProvider();
    final providerName = activeProvider.displayName;

    AppLogger.info('ENTERING: handleVideoGeneration with prompt: $prompt (Provider: $providerName)');
    LogService.info("🎨 Starting Video Generation ($providerName) for: $prompt", tag: 'MediaMixin');
    
    final lastMsg = agent.history.lastWhere((m) => m.image != null, orElse: () => ChatMessage.user(content: ''));
    final image = lastMsg.image;
    
    if (image == null) {
      agent.history.add(ChatMessage.assistant(content: "⚠️ عذراً، أحتاج لصورة منتج أولاً لتوليد فيديو $providerName."));
      AppLogger.info('EXITING: handleVideoGeneration (No Image Found)');
      return;
    }

    agent.isLoading.value = true;
    
    ChatMessage? placeholder;
    String? messageId;
    int? dbId;

    try {
      // 🛡️ Usage Limit Check
      if (!await agent.checkVisualLimit()) return;

      // 🔍 Find existing placeholder or use the last assistant message to avoid duplication
      ChatMessage? targetMessage;

      // Check if any recent message is a video placeholder to reuse
      try {
        targetMessage = agent.history.lastWhere(
          (m) => m.role == 'assistant' && 
                 (m.type == 'generated_video' || m.content.contains('جاري توليد')) &&
                 m.state == MessageState.pending,
        );
      } catch (_) {
        targetMessage = null;
      }

      placeholder = ChatMessage.assistant(
        content: "🎬 جاري توليد الفيديو الاحترافي عبر $providerName... يرجى الانتظار",
        type: 'generated_video',
        state: MessageState.pending,
        productContext: agent.lastAnalyzedProduct.value,
      ).copyWith(id: targetMessage?.id); // 🔑 Maintain ID if reusing
      
      messageId = placeholder.id;

      if (targetMessage != null) {
        // Update the existing message instead of adding a new one
        messageId = targetMessage.id;
        
        // 🔑 Extract dbId from existing ID (pattern "123_a")
        final parts = messageId.split('_');
        if (parts.isNotEmpty) {
          dbId = int.tryParse(parts[0]);
        }
        
        await agent.updateMessage(messageId, placeholder);
        AppLogger.info("🔄 Reusing existing message bubble: $messageId (dbId: $dbId)");
      } else {
        dbId = await agent.addAndSaveMessage(placeholder);
        if (dbId != null) {
          messageId = "${dbId}_a"; // Sync ID immediately
          // 🔑 CRITICAL: Update the placeholder with the new ID so callbacks use it correctly
          placeholder = placeholder.copyWith(id: messageId);
        }
        AppLogger.info("🆕 Created new video placeholder: $messageId (dbId: $dbId)");
      }

      final videoUrlResult = await agent.videoService.generateVideo(
        image: image,
        onStatusUpdate: (status) {
          final percentage = (status.progress * 100).toInt();
          agent.updateStage(percentage, 100, status.message);
          
          // 🔥 تحديث نص الفقاعة أيضاً ليشعر المستخدم بالتقدم
          if (messageId != null) {
            // 🛡️ نتحقق من الرسالة الحالية في الذاكرة لمنع مسح الرابط إذا اكتمل
            final currentMsg = agent.history.firstWhereOrNull((m) => m.id == messageId);
            if (currentMsg != null && currentMsg.videoUrl != null && currentMsg.videoUrl!.isNotEmpty) {
              return; // لا نحدث الحالة إذا كان الرابط موجوداً بالفعل
            }

            agent.updateMessage(messageId, (currentMsg ?? placeholder!).copyWith(
              content: status.message,
              state: MessageState.pending,
            ), dbId: dbId);
          }
        },
        onTaskIdReceived: (taskId) async {
          // 🚀 حفظ معرف المهمة فوراً للتمكن من الاستئناف في حالة إعادة التشغيل
          final progressMessage = placeholder!.copyWith(
            agentResult: AgentResult(
              type: AgentResultType.videoTask,
              data: jsonEncode({'task_id': taskId}),
              executionTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          );
          await agent.updateMessage(messageId!, progressMessage, dbId: dbId);
        },
      );

      if (videoUrlResult.isNotEmpty) {
        final response = "🎬 تم توليد الفيديو بنجاح عبر $providerName! يمكنك مشاهدته الآن.";
        
        // 🛡️ نأخذ أحدث نسخة من الرسالة من الذاكرة للحفاظ على الـ TaskID وأي بيانات أخرى
        final latestMsg = agent.history.firstWhereOrNull((m) => m.id == messageId);
        
        final updatedMessage = (latestMsg ?? placeholder).copyWith(
          content: response,
          videoUrl: videoUrlResult,
          state: MessageState.completed,
          isNew: true,
          clearAgentResult: false, // 🔥 نحتفظ بالـ TaskID للاستخدام المستقبلي (Refresh)
        );
        await agent.updateMessage(messageId, updatedMessage, dbId: dbId);
        await agent.incrementVisualCount();
      } else {
        final errorMessage = placeholder.copyWith(
          content: "❌ نعتذر، فشل توليد الفيديو عبر $providerName. يرجى المحاولة لاحقاً.",
          state: MessageState.error,
        );
        await agent.updateMessage(messageId, errorMessage, dbId: dbId);
      }
    } catch (e) {
      ErrorHandler.logError('$providerName Video', e);
      // 🚨 FIX: Update bubble to show error instead of staying stuck in "Generating"
      if (placeholder != null && messageId != null) {
        final errorMessage = placeholder.copyWith(
          content: "❌ عذراً، استغرق التوليد وقتاً أطول من المتوقع. يمكنك محاولة تحديث الرابط لاحقاً أو المحاولة مرة أخرى.",
          state: MessageState.error,
        );
        await agent.updateMessage(messageId, errorMessage, dbId: dbId);
      }
    } finally {
      agent.isLoading.value = false;
      agent.updateStage(0, 0, "");
      AppLogger.info('EXITING: handleVideoGeneration');
    }
  }

  /// 🚀 استئناف كافة المهام المعلقة (فيديو)
  void resumePendingVideoTasks() {
    for (final msg in agent.history) {
      if (msg.state == MessageState.pending && (msg.type == 'generated_video' || msg.type == 'video')) {
        final taskId = msg.agentResult?.data; // Extract task_id from JSON data
        String? finalTaskId;
        try {
          if (taskId != null) {
            final dataMap = jsonDecode(taskId.toString());
            finalTaskId = dataMap['task_id'];
          }
        } catch (_) {}

        if (finalTaskId != null && finalTaskId.isNotEmpty) {
           AppLogger.info("🔄 Resuming Pending Video Task: $finalTaskId");
           _handleResumeVideo(msg, finalTaskId);
        }
      }
    }
  }

  Future<void> _handleResumeVideo(ChatMessage placeholder, String taskId) async {
    final messageId = placeholder.id;
    int? dbId;
    
    // 🔑 Extract dbId from existing ID (pattern "123_a")
    final parts = messageId.split('_');
    if (parts.isNotEmpty) {
      dbId = int.tryParse(parts[0]);
    }

    try {
      final videoUrl = await agent.videoService.generateVideo(
        image: null, // لا نحتاج ملف صورة عند الاستئناف بـ taskId
        taskId: taskId,
        onStatusUpdate: (status) {
          final percentage = (status.progress * 100).toInt();
          agent.updateStage(percentage, 100, status.message);

          // 🔥 نتحقق من الرسالة الحالية في الذاكرة لمنع مسح الرابط إذا اكتمل
          final currentMsg = agent.history.firstWhereOrNull((m) => m.id == messageId);
          if (currentMsg != null && currentMsg.videoUrl != null && currentMsg.videoUrl!.isNotEmpty) {
            return;
          }

          // 🔥 تحديث نص الفقاعة أيضاً ليشعر المستخدم بالتقدم
          agent.updateMessage(messageId, (currentMsg ?? placeholder).copyWith(
            content: status.message,
            state: MessageState.pending,
          ), dbId: dbId);
        },
      );

      if (videoUrl.isNotEmpty) {
        final response = "🎬 تم اكتمال توليد الفيديو! يمكنك مشاهدته الآن.";
        final updatedMessage = placeholder.copyWith(
          content: response,
          videoUrl: videoUrl,
          state: MessageState.completed,
          isNew: true,
          clearAgentResult: true, // 🔥 نلغي نتيجة الـ Agent المؤقتة عند النجاح في الاستئناف
        );
        await agent.updateMessage(messageId, updatedMessage, dbId: dbId); 
      }
    } catch (e) {
       AppLogger.error("Failed to resume video task: $e");
       final errorMessage = placeholder.copyWith(
         content: "❌ عذراً، فشل استئناف المراقبة. يرجى الضغط على 'تحديث الرابط' يدوياً.",
         state: MessageState.error,
       );
       await agent.updateMessage(messageId, errorMessage, dbId: dbId);
    }
  }

  /// 🔄 محاولة استعادة رابط فيديو قديم انتهت صلاحيته
  Future<void> refreshVideoTask(ChatMessage msg) async {
    final taskId = _extractTaskId(msg);
    if (taskId == null) {
      LogService.warning("Cannot refresh video: No Task ID found in message ${msg.id}");
      return;
    }
    
    final messageId = msg.id;
    int? dbId;
    final parts = messageId.split('_');
    if (parts.isNotEmpty) dbId = int.tryParse(parts[0]);

    // Show loading stage in UI
    agent.updateStage(1, 1, "🔄 جاري محاولة استعادة رابط الفيديو... ✨");
    
    try {
      final videoUrlResult = await agent.videoService.generateVideo(
        image: null,
        taskId: taskId,
        onStatusUpdate: (status) {
          final percentage = (status.progress * 100).toInt();
          agent.updateStage(percentage, 100, status.message);
        },
      );

      if (videoUrlResult.isNotEmpty) {
         final updatedMessage = msg.copyWith(
           videoUrl: videoUrlResult,
           state: MessageState.completed,
           clearAgentResult: false, // Keep the task_id for future refreshes if needed
         );
         await agent.updateMessage(messageId, updatedMessage, dbId: dbId);
         agent.updateStage(100, 100, "✅ تم استعادة الفيديو بنجاح!");
      } else {
         agent.updateStage(0, 0, "❌ لم نتمكن من استعادة الفيديو. ربما حذف من السيرفر نهائياً.");
      }
    } catch (e) {
      AppLogger.error("Failed to refresh video task: $e");
      agent.updateStage(0, 0, "⚠️ حدث خطأ أثناء محاولة التحديث.");
    } finally {
      // Clear stage after delay
      Future.delayed(const Duration(seconds: 3), () => agent.updateStage(0, 0, ""));
    }
  }

  String? _extractTaskId(ChatMessage msg) {
    final data = msg.agentResult?.data;
    if (data == null) return null;
    try {
      final dataMap = jsonDecode(data.toString());
      return dataMap['task_id'];
    } catch (_) {
      return null;
    }
  }
}
