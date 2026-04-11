import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/chat_message.dart';
import '../core/agent_models.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/utils/log_service.dart';
import '../chat_smart_agent.dart';
import '../../utils/logger.dart';

mixin AgentCoreMixin on GetxService {
  ChatSmartAgent get agent => this as ChatSmartAgent;

  Future<void> handleAction(String id, {dynamic payload, dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleAction with id: $id, payload: $payload');
    LogService.info("🧩 Routing action to: $id (Payload: $payload)", tag: 'CoreMixin');

    switch (id) {
      case 'tiktok_link':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) {
          debugPrint("⚠️ TikTok Action: Empty query, skipping.");
          return;
        }
        final encodedQuery = Uri.encodeComponent(query);
        
        final uris = [
          Uri.parse("tiktok://search?keyword=$encodedQuery"),
          Uri.parse("snssdk1233://search?keyword=$encodedQuery"),
          Uri.parse("snssdk1128://search?keyword=$encodedQuery"),
          Uri.parse("https://www.tiktok.com/search?q=$encodedQuery"),
        ];

        for (final uri in uris) {
          try {
            debugPrint("🔗 Attempting to launch TikTok URI: $uri");
            bool launched = false;
            // Try to launch as a non-browser app first if it's a custom scheme
            if (!uri.scheme.startsWith('http')) {
               launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            } else {
               launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            
            if (launched) {
              debugPrint("✅ Successfully launched: $uri");
              return;
            }
          } catch (e) {
            debugPrint("❌ Failed to launch $uri: $e");
          }
        }
        break;

      case 'instagram_link':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        final encodedQuery = Uri.encodeComponent(query).replaceAll('%20', '+');
        await launchUrl(Uri.parse("https://www.instagram.com/explore/search/keyword/?q=$encodedQuery"), mode: LaunchMode.inAppBrowserView);
        break;

      case 'youtube_link':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleYoutubeSearch(query);
        break;

      case 'amazon_search':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleAmazonSearch(query);
        break;

      case 'google_news':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleGoogleNews(query);
        break;

      case 'trend_search':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleGoogleTrends(query);
        break;

      case 'generate_ad':
        final String product = payload is String ? payload : (agent.lastAnalyzedProduct.value ?? "المنتج");
        await agent.respondNormally("اكتب لي وصف تسويقي احترافي لمنتج: $product");
        break;

      case 'google_images':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleVisualInspiration(query);
        break;

      case 'similar_videos':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleGoogleShortVideos(query);
        break;

      case 'generate_creative_image':
      case 'image_generation':
        final String prompt = payload is String ? payload : (agent.lastAnalyzedProduct.value ?? "صورة منتج احترافية");
        await agent.handleImageGeneration(prompt);
        break;

      case 'remove_background':
        final lastMsg = agent.history.lastWhere((m) => m.image != null || m.mediaPath != null, orElse: () => ChatMessage.user(content: ''));
        final targetFile = lastMsg.image ?? (lastMsg.mediaPath != null ? File(lastMsg.mediaPath!) : null);
        if (targetFile != null) {
          agent.updateStage(1, 1, "✂️ جاري إزالة الخلفية...");
          final isolated = await agent.bgRemovalService.removeBackground(targetFile);
          if (isolated != null) {
            agent.history.add(ChatMessage.assistant(content: "تم إزالة الخلفية بنجاح ✂️✨").copyWith(image: isolated, mediaPath: isolated.path));
          }
        }
        break;

      case 'edit_with_prompt':
        agent.isWaitingForProductName.value = true;
        agent.history.add(ChatMessage.assistant(content: "📝 اكتب لي اسم المنتج الآن وسأقوم بتحليله. 👇"));
        break;

      case 'generate_kling_video':
        final String prompt = payload is String ? payload : (agent.lastAnalyzedProduct.value ?? 'فيديو منتج احترافي');
        await agent.handleKlingVideoGeneration(prompt);
        break;

      case 'bing_copilot':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleExpertResearch(query);
        break;

      case 'alibaba_sourcing':
        final String query = getCleanSearchQuery(payload);
        if (query.isEmpty) return;
        await agent.handleAmazonSearch(query); // الحل الموحد للبحث عن المصادر حالياً
        break;

      case 'visual_search':
        final lastMsg = agent.history.lastWhere((m) => m.image != null || m.mediaPath != null, orElse: () => ChatMessage.user(content: ''));
        final targetFile = lastMsg.image ?? (lastMsg.mediaPath != null ? File(lastMsg.mediaPath!) : null);
        if (targetFile != null) {
          await agent.handleVisionAnalysis(targetFile);
        } else {
          agent.history.add(ChatMessage.assistant(content: '⚠️ عذراً، لم أجد صورة للمنتج لتحليلها بصرياً.'));
        }
        break;

      case 'copy_text':
        if (payload is String) {
          await Clipboard.setData(ClipboardData(text: payload));
          SnackBarUtils.showSmartSnackBar(title: "تم النسخ", message: "تم نسخ النص بنجاح ✅");
        }
        break;

      default:
        LogService.warning("⚠️ Unknown AI Action received: $id", tag: 'CoreMixin');
    }
    AppLogger.info('EXITING: handleAction');
  }

  String getCleanSearchQuery(dynamic payload) {
    String query = "";
    if (payload is String && payload.isNotEmpty) {
      query = payload;
    } else if (agent.lastAnalyzedProduct.value != null && agent.lastAnalyzedProduct.value!.isNotEmpty) {
      // ⚠️ Use global fallback ONLY if payload is absolutely missing
      query = agent.lastAnalyzedProduct.value!;
    } else {
      // 🕵️ History Lookup: If both are missing, find the most recent message with a product context
      try {
        final lastContextMsg = agent.history.lastWhere(
          (m) => m.productContext != null && m.productContext!.isNotEmpty,
          orElse: () => ChatMessage.user(content: ''),
        );
        if (lastContextMsg.productContext != null) {
          query = lastContextMsg.productContext!;
          debugPrint("🕵️ [History Lookup]: Found context in previous message: $query");
        }
      } catch (_) {}
    }
    
    // 🧹 Robust Cleansing: Remove emojis and metadata marks
    query = query.replaceAll(RegExp(r'[\*✨✅📊🎬🔎📸📦🚀💡⚠️❌👁️⚡🔗🛠️✂️🎨🧠]'), '').trim();
    
    // 🛡️ Length Limit for API safety
    if (query.length > 80) query = query.substring(0, 80);
    
    AppLogger.info('EXITING: getCleanSearchQuery result: $query');
    return query;
  }

  Future<void> retryLastAssistantMessage() async {
    AppLogger.info('ENTERING: retryLastAssistantMessage');
    if (agent.history.isEmpty) return;
    
    final lastUserMsgIndex = agent.history.lastIndexWhere((m) => m.role == 'user');
    if (lastUserMsgIndex == -1) return;

    final userText = agent.history[lastUserMsgIndex].content;
    final userImage = agent.history[lastUserMsgIndex].image;

    if (lastUserMsgIndex < agent.history.length - 1) {
      agent.history.removeRange(lastUserMsgIndex + 1, agent.history.length);
    }

    await agent.sendUserMessage(userText, image: userImage);
    AppLogger.info('EXITING: retryLastAssistantMessage');
  }

  Future<void> respondNormally(String prompt, {List<File>? images, dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: respondNormally with prompt: $prompt');
    agent.isLoading.value = true;
    agent.activeRequests.value++;
    try {
      // 📜 Contextual Injection: Pass the last 5 messages as history (Reduced from 10 to prevent bloat/repetition)
      final List<Map<String, String>> chatHistory = agent.history
          .where((m) => m.content.isNotEmpty)
          .toList()
          .reversed
          .take(5)
          .toList()
          .reversed
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'assistant',
                'content': m.content.length > 500 ? m.content.substring(0, 500) : m.content, // Sanitize length
              })
          .toList();


      // 🧠 Context Persona: Tell the AI about the product
      final currentProduct = agent.lastAnalyzedProduct.value;
      final systemPersona = currentProduct != null 
          ? "You are a helpful AI assistant for a Content Creation app. The user is currently focusing on this product: $currentProduct. Answer naturally and helpfully in the same language as the user. Use context from the history if provided."
          : "You are a helpful AI assistant for a Content Creation app. Answer naturally and helpfully in the same language as the user. Use context from the history if provided.";

      final response = await agent.unifiedService.generateText(
        prompt, 
        systemPersona: systemPersona,
        history: chatHistory,
        cancelToken: cancelToken,
      );
      
      String cleanContent = stripJsonFromResponse(response);
      if (cleanContent.length > 4000) cleanContent = cleanContent.substring(0, 4000);
      
      final agentResult = tryExtractAgentResult(response);

      agent.history.add(ChatMessage.assistant(
        content: cleanContent,
        agentResult: agentResult,
        productContext: agent.lastAnalyzedProduct.value,
      ).copyWith(state: MessageState.completed));

      agent.lastGeneratedContent.value = cleanContent;
      await agent.saveToDb(prompt, cleanContent, productContext: currentProduct);
    } catch (e) {
      ErrorHandler.logError('Normal Response', e);
    } finally {
      agent.isLoading.value = false;
      agent.activeRequests.value--;
      AppLogger.info('EXITING: respondNormally');
    }
  }

  AgentResult? tryExtractAgentResult(String text) {
    try {
      String cleanText = text.trim();
      if (cleanText.contains('```')) {
        final match = RegExp(r'```(?:json)?([\s\S]*?)```').firstMatch(cleanText);
        if (match != null) cleanText = match.group(1)?.trim() ?? cleanText;
      }
      final jsonMap = JsonUtils.parseSafe(cleanText);
      if (jsonMap.isEmpty) return null;

      final action = jsonMap['action'];
      if (action == 'productGallery') {
        return AgentResult(type: AgentResultType.productGallery, data: jsonMap['action_input'], executionTimestamp: DateTime.now().millisecondsSinceEpoch);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String stripJsonFromResponse(String text) {
    if (!text.contains('{') || !text.contains('}')) return text;
    
    // 1. Remove Markdown code blocks
    String clean = text.replaceAll(RegExp(r'```(?:json)?[\s\S]*?```'), '').trim();
    
    // 2. Remove isolated JSON objects that look like actions
    final actionRegex = RegExp(r'''\{[\s\S]*?["']action["'][\s\S]*?\}''');
    clean = clean.replaceAll(actionRegex, '').trim();
    
    // 3. Remove trailing history residue (Gemini sometimes repeats history as JSON)
    final residueRegex = RegExp(r'\n\n\{[\s\S]*?role[\s\S]*?user[\s\S]*?\}[\s\S]*$');
    clean = clean.replaceAll(residueRegex, '').trim();

    // 4. Final check: if it still has trailing brackets from repeated history
    if (clean.endsWith('}]}]}') || clean.endsWith('}]}')) {
      final index = clean.lastIndexOf('\n');
      if (index != -1) clean = clean.substring(0, index).trim();
    }

    return clean.isEmpty ? "إليك ما وجدته: ✨" : clean;
  }

}
