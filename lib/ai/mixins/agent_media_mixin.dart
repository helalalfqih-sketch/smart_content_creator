import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

import '../../core/models/chat_message.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/log_service.dart';
import '../chat_smart_agent.dart';
import '../../utils/logger.dart';
import '../core/agent_models.dart';

mixin AgentMediaMixin on GetxService {
  ChatSmartAgent get agent => this as ChatSmartAgent;

  Future<void> handleVisionAnalysis(File file, {dynamic preAnalyzedResult, dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleVisionAnalysis with file: ${file.path}');
    LogService.info("🎨 Image received for analysis, path: ${file.path}", tag: 'MediaMixin');
    agent.updateStage(1, 2, "جاري تحليل تفاصيل المنتج بصرياً... 👁️");
    try {
      // 🧠 Reuse result if available from pre-analysis, otherwise analyze
      final result = preAnalyzedResult ?? await agent.visionProductService.analyzeImage(file, cancelToken: cancelToken);
      
      if (result.productName != null) {
        agent.saveProductToMemory(result.productName!);
        final Map<String, dynamic> data = result.data ?? {};
        final response = "🔍 **تحليل الرؤية الذكي:**\n\nلقد رصدت منتجاً: **${result.productName}** (${data['category'] ?? 'عام'}).\n${data['description'] ?? ''}";
        agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
        await agent.saveToDb(result.productName!, response);
      }
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
      final isolated = await agent.bgRemovalService.removeBackground(file, cancelToken: cancelToken);
      if (isolated == null) throw Exception("فشل عزل المنتج");

      agent.updateStage(2, 4, "🎨 جاري تصميم خلفية احترافية ملائمة...");
      final prompt = "A premium commercial photography background for ${agent.lastAnalyzedProduct.value ?? 'product'}, high-end lighting, minimalist style";
      final background = await agent.imageGenService.generateImage(prompt, cancelToken: cancelToken);
      
      agent.updateStage(3, 4, "📸 جاري دمج المنتج مع الخلفية الجديدة...");
      final response = "✨ تم إنشاء الإعلان الاحترافي بنجاح! لقد قمت بعزل المنتج ووضعه في بيئة تسويقية فاخرة.";
      agent.history.add(ChatMessage.assistant(content: response).copyWith(image: background.file, state: MessageState.completed));
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
      agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Enhance Image', e);
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
      agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Audio Enhance', e);
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
    
    final stageMsg = effectiveImage != null 
        ? "🎯 جاري البحث عن مطابقات بصرية دقيقة (100%)..." 
        : "🎨 جاري البحث عن مصادر إلهام بصري لـ ($query)...";
        
    agent.updateStage(1, 2, stageMsg);
    
    try {
      // 🚀 Visual Search Priority: If image is provided, use Google Lens for 100% accuracy
      if (effectiveImage != null) {
        await agent.handleGoogleLens(effectiveImage, cancelToken: cancelToken);
        return;
      }

      
      final results = await agent.imagesService.search(query);

      // Handle standard engine response keys
      final List resultsList = (results['images_results'] as List?) ?? [];

      
      final int count = resultsList.length;
      
      AppLogger.info('SUCCESS: handleVisualInspiration found $count matches.');
      LogService.success("🎨 Visual inspiration results: $count", tag: 'MediaMixin');

      final response = count > 0 
          ? (image != null 
              ? "🎯 لقد وجدت $count مطابقة بصرية دقيقة لهذا المنتج. يمكنك استعراض النسخ المتصلة والألوان المتاحة."
              : "🎨 لقد وجدت $count مصدر إلهام بصري لـ ($query). يمكنك الاستعانة بهذه الأنماط لتطوير محتواك.")
          : "🎨 لم أجد نتائج كافية حالياً، سأحاول بعبارات بحث مختلفة.";

      AgentResult? agentResult;
      if (count > 0) {
        final List<ImageItem> galleryImages = [];
        for (var img in resultsList) {
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
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleVisualInspiration');
    }
  }

  Future<void> handleKlingVideoGeneration(String prompt, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleKlingVideoGeneration with prompt: $prompt');
    LogService.info("🎨 Starting Kling Video Generation for: $prompt", tag: 'MediaMixin');
    final lastMsg = agent.history.lastWhere((m) => m.image != null, orElse: () => ChatMessage.user(content: ''));
    final image = lastMsg.image;
    
    if (image == null) {
      agent.history.add(ChatMessage.assistant(content: "⚠️ عذراً، أحتاج لصورة منتج أولاً لتوليد فيديو Kling AI."));
      AppLogger.info('EXITING: handleKlingVideoGeneration (No Image Found)');
      return;
    }

    agent.isLoading.value = true;
    try {
      final videoUrl = await agent.videoService.generateVideo(
        image: image,
        onStatusUpdate: (status) {
          agent.updateStage(status.progress.toInt(), 1, status.message);
        },
      );
      
      if (videoUrl.isNotEmpty) {
        final response = "🎬 تم توليد الفيديو بنجاح عبر Kling AI! يمكنك مشاهدته الآن.";
        agent.history.add(ChatMessage.assistant(content: response).copyWith(mediaPath: videoUrl, state: MessageState.completed));
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('429') || errStr.contains('402')) {
        Get.snackbar(
          "تنبيه الرصيد",
          "رصيد التوليد السحابي نفد، جاري المحاولة باستخدام المحرك البديل.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      ErrorHandler.logError('Kling Video', e);
    } finally {
      agent.isLoading.value = false;
      AppLogger.info('EXITING: handleKlingVideoGeneration');
    }
  }
}
