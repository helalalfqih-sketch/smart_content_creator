import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

import '../../core/models/chat_message.dart';
import '../core/agent_models.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/log_service.dart';
import '../chat_smart_agent.dart';
import '../../utils/logger.dart';

mixin AgentSearchMixin on GetxService {
  ChatSmartAgent get agent => this as ChatSmartAgent;

  Future<void> handleGoogleLens(File? image, {dio.CancelToken? cancelToken}) async {
    // 🧠 Context Fetch: Allow null input by searching for latest session image
    final File? effectiveImage = image ?? 
        (agent.latestUploadPath.value != null ? File(agent.latestUploadPath.value!) : null);

    if (effectiveImage == null) {
      agent.history.add(ChatMessage.assistant(content: "⚠️ عذراً، لم أجد صورة منتج في هذه المحادثة لبدء المطابقة البصرية."));
      return;
    }

    AppLogger.info('ENTERING: handleGoogleLens with image: ${effectiveImage.path}');
    LogService.info("🔍 Starting Google Lens Visual Matching for: ${effectiveImage.path}", tag: 'SearchMixin');
    agent.updateStage(1, 4, "جاري تحضير الصورة للبحث البصري... 📤");
    try {
      // 🛡️ Usage Limit Check
      if (!await agent.checkVisualLimit()) return;

      // 🚀 BYPASS: We now use direct file upload to SerpApi to avoid Firebase Storage 404 issues
      final String imageInput = effectiveImage.path;

      agent.updateStage(2, 4, "جاري مطابقة المنتج تقنياً (Visual Match)... 👁️");
      final results = await agent.lensService.searchByImage(imageInput, cancelToken: cancelToken);
      
      // 📸 Increment count on success
      await agent.incrementVisualCount();
      
      agent.updateStage(3, 4, "جاري تنظيم معرض المطابقات البصرية... 🍱");
      
      final List resultsList = (results['visual_matches'] as List?) ?? [];
      final int count = resultsList.length;

      if (count == 0) {
        agent.history.add(ChatMessage.assistant(content: "🔍 لم أتمكن من العثور على مطابقات بصرية دقيقة جداً لهذا المنتج حالياً.").copyWith(state: MessageState.completed));
        return;
      }

      final List<ImageItem> galleryImages = [];
      for (var img in resultsList) {
        final imgMap = img is Map<String, dynamic> ? img : <String, dynamic>{};
        
        galleryImages.add(ImageItem(
          title: imgMap['title']?.toString() ?? '',
          link: imgMap['link']?.toString() ?? '',
          thumbnail: imgMap['thumbnail']?.toString() ?? imgMap['image']?.toString() ?? '',
          originalUrl: imgMap['image']?.toString() ?? imgMap['thumbnail']?.toString(), // Use direct image if available
          source: imgMap['source']?.toString() ?? '',
          metadata: imgMap,
        ));
      }

      final agentResult = AgentResult(
        type: AgentResultType.imageGallery,
        data: ImageGalleryData(
          images: galleryImages,
          query: "Google Lens",
          title: "🎯 مطابقات بصرية دقيقة (100%)",
        ),
        executionTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final response = "🎯 لقد وجدت $count مطابقة بصرية دقيقة لهذا المنتج عبر Google Lens. هذه صور لنفس الموديل والعلامة التجارية من مصادر مختلفة.";
      
      agent.history.add(ChatMessage.assistant(
        content: response,
        agentResult: agentResult,
      ).copyWith(state: MessageState.completed));

      await agent.saveToDb("Google Lens", response, messageType: 'image_gallery');
    } catch (e) {
      ErrorHandler.logError('Google Lens Gallery', e);
      // 🔥 NEW: Clarification message for the user when a technical failure occurs
      agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "عذراً، لم أستطع التعرف على الصورة. هل يمكنك إرسالها لي مرة أخرى؟ 📸",
        ).copyWith(state: MessageState.completed),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }


  Future<void> handleGoogleTrends(String query, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleGoogleTrends with query: $query');
    LogService.info("🔍 Fetching Google Trends for: $query", tag: 'SearchMixin');
    agent.updateStage(1, 100, "جاري تحليل مؤشرات Google Trends لـ ($query)... 📈");
    try {
      String result = await agent.trendsService.getTrends(query, cancelToken: cancelToken);
      if (result.length > 4000) result = result.substring(0, 4000);
      
      final response = "📈 **نبض السوق لـ ($query):**\n\n$result";
      agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
      await agent.saveToDb(query, response);
    } catch (e) {
      ErrorHandler.logError('Google Trends', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل تحليل Google Trends: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  Future<void> handleYoutubeSearch(String query, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleYoutubeSearch with query: $query');
    
    // 🧹 Query Sanitization: If query is too long/descriptive, refine it to keywords
    String effectiveQuery = query;
    if (query.length > 50 || (query.contains(' ') && query.split(' ').length > 8)) {
      agent.updateStage(1, 100, "تحسين كلمات البحث لنتائج أدق... 🔎");
      effectiveQuery = await agent.refineSearchQuery(query, cancelToken: cancelToken);
    }

    LogService.info("🔍 Searching YouTube for: $effectiveQuery", tag: 'SearchMixin');
    agent.updateStage(1, 100, "جاري البحث في YouTube عن ($effectiveQuery)... 🎬");
    try {
      final results = await agent.youtubeService.searchVideos(effectiveQuery, cancelToken: cancelToken);

      if (results.isEmpty) {
        agent.history.add(ChatMessage.assistant(content: "🔍 لم أجد فيديوهات يوتيوب لـ ($query) حالياً.").copyWith(state: MessageState.completed));
        return;
      }
      
      final videoData = VideoDiscoveryData(
        videos: results,
        query: effectiveQuery,
        title: "🎬 نتائج يوتيوب لـ **$effectiveQuery**:",
      );

      final response = "🎬 تم العثور على ${results.length} فيديو ذو صلة. يمكنك تصفحها أدناه! ✨";
      
      agent.history.add(ChatMessage.assistant(
        content: response,
        agentResult: AgentResult(
          type: AgentResultType.videoDiscovery,
          data: videoData,
          executionTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ).copyWith(state: MessageState.completed));

      await agent.saveToDb("YouTube: $effectiveQuery", response, messageType: 'video_discovery');
    } catch (e) {
      ErrorHandler.logError('YouTube Search', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل البحث في YouTube: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  Future<void> handleAmazonSearch(String query, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleAmazonSearch with query: $query');

    // 🧹 Query Sanitization
    String effectiveQuery = query;
    if (query.length > 50 || (query.contains(' ') && query.split(' ').length > 8)) {
      effectiveQuery = await agent.refineSearchQuery(query, cancelToken: cancelToken);
    }

    LogService.info("🔍 Searching Amazon for: $effectiveQuery", tag: 'SearchMixin');
    agent.updateStage(1, 100, "جاري البحث في Amazon عن ($effectiveQuery)... 🛒");
    try {
      final results = await agent.amazonService.searchProducts(effectiveQuery, cancelToken: cancelToken);

      if (results.isEmpty) {
        agent.history.add(ChatMessage.assistant(content: "🔍 لم أجد منتجات في أمازون لـ ($query) حالياً.").copyWith(state: MessageState.completed));
        return;
      }
      
      final sb = StringBuffer("🛒 **أفضل النتائج من Amazon:**\n\n");
      for (var p in results.take(5)) {
        sb.writeln("🔹 [${p['title']}](${p['link']})\n💰 السعر: ${p['price']}\n");
      }
      
      agent.history.add(ChatMessage.assistant(content: sb.toString()).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Amazon Search', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل البحث في أمازون: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  Future<void> handleGoogleNews(String query, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleGoogleNews with query: $query');
    LogService.info("🔍 Searching Google News for: $query", tag: 'SearchMixin');
    agent.updateStage(1, 100, "جاري البحث عن آخر الأخبار لـ ($query)... 📰");
    try {
      final results = await agent.newsService.getLatestNews(query, cancelToken: cancelToken);
      final sb = StringBuffer("📰 **آخر أخبار ($query):**\n\n");
      for (var n in results.take(5)) {
        sb.writeln("🔹 [${n['title']}](${n['link']})\n🕒 ${n['date']}\n");
      }
      
      String response = sb.toString();
      if (response.length > 4000) response = response.substring(0, 4000);
      
      agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Google News', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل جلب أخبار Google: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  Future<void> handleGoogleShopping(String query, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleGoogleShopping with query: $query');
    agent.updateStage(1, 100, "جاري البحث في Google Shopping... 🛍️");
    try {
      final results = await agent.shoppingService.searchProducts(query, cancelToken: cancelToken);
      final sb = StringBuffer("🛍️ **اقتراحات تسويقية لـ ($query):**\n\n");
      for (var item in results.take(5)) {
        sb.writeln("🔹 [${item['title']}](${item['link']})\n💰 السعر: ${item['price']}\n");
      }
      
      String response = sb.toString();
      if (response.length > 4000) response = response.substring(0, 4000);
      
      agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Google Shopping', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل البحث في Google Shopping: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  Future<void> handleGoogleReverseImage(File image, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleGoogleReverseImage with image: ${image.path}');
    agent.updateStage(1, 100, "جاري البحث العكسي عن الصورة... 🔍");
    try {
      final response = await agent.reverseImageService.findImageSources(image, cancelToken: cancelToken);
      agent.history.add(ChatMessage.assistant(content: response).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Reverse Image', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل البحث العكسي عن الصورة: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  Future<void> handleGoogleShortVideos(String rawQuery, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleGoogleShortVideos with query: $rawQuery');
    
    // 🧠 TikTok-Style Discovery Intelligence: Refine the query for 100% matching
    final String refinedQuery = _refineVideoSearchQuery(rawQuery);
    AppLogger.info('🚀 [Search Intelligence]: Original: "$rawQuery" -> Refined: "$refinedQuery"');

    agent.updateStage(1, 100, "جاري البحث عن فيديوهات قصيرة... 🎞️");
    try {
      final videos = await agent.shortVideosService.getShortVideos(refinedQuery, cancelToken: cancelToken);
      if (videos.isEmpty) {
        agent.history.add(ChatMessage.assistant(content: "🔍 لم أجد فيديوهات قصيرة لـ **$refinedQuery** حالياً.").copyWith(state: MessageState.completed));
        return;
      }
      
      final videoData = VideoDiscoveryData(
        videos: videos,
        query: refinedQuery,
        title: "✨ أفضل فيديوهات قصيرة لـ **$refinedQuery**:",
      );

      agent.history.add(ChatMessage.assistant(
        content: videoData.title,
        agentResult: AgentResult(type: AgentResultType.videoDiscovery, data: videoData, executionTimestamp: DateTime.now().millisecondsSinceEpoch),
      ).copyWith(state: MessageState.completed));
    } catch (e) {
      ErrorHandler.logError('Short Videos', e);
      final mapped = ErrorHandler.mapError(e);
      await agent.addAndSaveMessage(
        ChatMessage.assistant(
          content: "⚠️ فشل جلب الفيديوهات القصيرة: ${mapped.message}",
        ).copyWith(state: MessageState.error, isError: true),
      );
    } finally {
      agent.isLoading.value = false;
    }
  }

  /// 🔍 بحث عكسي بالصورة لاستخراج فيديوهات مطابقة 100%
  Future<void> handleReverseVideoSearch({dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleReverseVideoSearch');
    
    agent.isLoading.value = true;
    agent.updateStage(1, 3, "🔍 جاري استخراج بيانات المنتج للبحث الدقيق...");

    try {
      // 1. 🎯 استخدام search_query الدقيق من تحليل المنتج (الأكثر دقة)
      String? preciseQuery;
      
      // محاولة جلب الاستعلام من ذاكرة المنتج
      try {
        final memory = await agent.productMemory.getLastProduct('');
        if (memory != null && memory.searchQuery.isNotEmpty) {
          preciseQuery = memory.searchQuery;
          AppLogger.info('🎯 [ReverseVideo] Using ProductMemory search_query: $preciseQuery');
        }
      } catch (_) {}
      
      // Fallback: استخدام اسم المنتج المحلل
      preciseQuery ??= agent.lastAnalyzedProduct.value;
      
      if (preciseQuery == null || preciseQuery.isEmpty || preciseQuery == 'غير معروف') {
        agent.addAndSaveMessage(ChatMessage.assistant(
          content: "❌ لا يوجد منتج محلل حالياً. يرجى إرسال صورة المنتج أولاً.",
        ).copyWith(state: MessageState.completed));
        return;
      }

      agent.updateStage(2, 3, "🎬 جاري البحث عن فيديوهات مطابقة لـ $preciseQuery...");

      // 2. بحث فيديوهات قصيرة باستخدام الاستعلام الدقيق
      final videos = await agent.shortVideosService.getShortVideos(
        preciseQuery, 
        cancelToken: cancelToken,
      );

      agent.updateStage(3, 3, "✅ تم العثور على ${videos.length} فيديو!");

      if (videos.isEmpty) {
        agent.addAndSaveMessage(ChatMessage.assistant(
          content: "🔍 لم أجد فيديوهات مطابقة لـ **$preciseQuery** حالياً.\n\n"
              "💡 جرب البحث يدوياً عبر زر \"شورت يوتيوب\" أو \"بحث تيك توك\".",
        ).copyWith(state: MessageState.completed));
        return;
      }

      // 3. عرض النتائج
      final videoData = VideoDiscoveryData(
        videos: videos,
        query: preciseQuery,
        title: "🎯 **فيديوهات مطابقة لمنتجك ($preciseQuery):**",
      );

      agent.addAndSaveMessage(ChatMessage.assistant(
        content: videoData.title,
        agentResult: AgentResult(
          type: AgentResultType.videoDiscovery,
          data: videoData,
          executionTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ).copyWith(state: MessageState.completed));

    } catch (e) {
      ErrorHandler.logError('Reverse Video Search', e);
      agent.addAndSaveMessage(ChatMessage.assistant(
        content: "❌ حدث خطأ أثناء البحث. يرجى المحاولة لاحقاً.",
      ).copyWith(state: MessageState.completed));
    } finally {
      agent.isLoading.value = false;
    }
  }

  /// 🧠 Smart Query Refinement logic (TikTok-Style)
  String _refineVideoSearchQuery(String text) {
    if (text.isEmpty) return text;
    
    // 🎯 أولوية: استخدام اسم المنتج المحلل مسبقاً (الأكثر دقة)
    final productName = agent.lastAnalyzedProduct.value;
    if (productName != null && productName.isNotEmpty && productName != 'غير معروف') {
      return productName;
    }
    // تنظيف النص من الكلمات العامة
    final cleanText = text.replaceAll('منتج', '').replaceAll('جهاز', '').trim();
    
    // استخراج رقم الموديل (مثل YT-M2052)
    final modelRegex = RegExp(r'\b[A-Za-z]+[-]?\d+[A-Za-z]*\b');
    final modelMatch = modelRegex.allMatches(cleanText).map((m) => m.group(0)).join(' ');
    
    // استخراج الكلمات الأساسية لوصف المنتج (أول كلمتين مثل Air Humidifier)
    final words = cleanText.split(' ');
    final categoryContext = words.where((w) => !modelMatch.contains(w)).take(2).join(' ');

    if (modelMatch.isNotEmpty && modelMatch.length > 2) {
      // دمج السياق (الفئة) مع الموديل لضمان الدقة
      return "$categoryContext $modelMatch"; 
    }

    final coreName = words.take(5).join(' '); 
    return coreName;
  }

  String refineSocialSearchQuery(String original, {String platform = 'instagram'}) {
    if (original.isEmpty) return original;
    // تنظيف النص من الرموز والكلمات التقنية جداً
    final clean = original.replaceAll(RegExp(r'[YT|DX|M|B][-]?\d+[A-Za-z]*'), '').trim();
    final parts = clean.split(' ');
    
    if (parts.length > 7) {
      // 🚀 Expanded limit: Focus on first 7 words to include Brand, Model, and Category
      return parts.take(7).join(' ');
    }
    return clean.isNotEmpty ? clean : original;
  }

  Future<void> handleExpertResearch(String query, {dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleExpertResearch with query: $query');
    agent.isLoading.value = true;
    agent.updateStage(1, 100, "⚡ جاري البحث العميق عبر Bing Copilot...");
    try {
      final data = await agent.bingService.search(query, cancelToken: cancelToken);
      if (data.containsKey('error')) {
        agent.history.add(ChatMessage.assistant(content: "⚠️ عذراً، محرك البحث معطل حالياً."));
      } else {
        final researchData = ExpertResearchData.fromJson(data);
        agent.history.add(ChatMessage.assistant(
          content: researchData.header ?? "نتائج البحث العميق لـ $query",
          agentResult: AgentResult(type: AgentResultType.expertResearch, data: researchData, executionTimestamp: DateTime.now().millisecondsSinceEpoch),
        ).copyWith(state: MessageState.completed));
      }
    } catch (e) {
      ErrorHandler.logError('Expert Research', e);
    } finally {
      agent.isLoading.value = false;
    }
  }
}
