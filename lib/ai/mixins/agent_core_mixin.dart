import 'dart:io';
import 'dart:convert';
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
import '../../services/activity_tracking_service.dart';
import '../../services/search/product_search_context.dart';
import '../../services/search/platform_query_builder.dart';

mixin AgentCoreMixin on GetxService {
  ChatSmartAgent get agent => this as ChatSmartAgent;

  Future<void> handleAction(String id, {dynamic payload, dio.CancelToken? cancelToken}) async {
    AppLogger.info('ENTERING: handleAction with id: $id, payload: $payload');
    LogService.info("🧩 Routing action to: $id (Payload: $payload)", tag: 'CoreMixin');

    switch (id) {
      case 'tiktok_link':
        final String tiktokQuery = getPlatformQuery('tiktok', payload);
        if (tiktokQuery.isEmpty) {
          debugPrint("⚠️ TikTok Action: Empty query, skipping.");
          return;
        }
        final tiktokEncoded = Uri.encodeComponent(tiktokQuery);
        for (final uri in [
          Uri.parse("tiktok://search?keyword=$tiktokEncoded"),
          Uri.parse("snssdk1233://search?keyword=$tiktokEncoded"),
          Uri.parse("snssdk1128://search?keyword=$tiktokEncoded"),
          Uri.parse("https://www.tiktok.com/search?q=$tiktokEncoded"),
        ]) {
          try {
            debugPrint("🔗 Attempting to launch TikTok URI: $uri");
            final launched = uri.scheme.startsWith('http')
                ? await launchUrl(uri, mode: LaunchMode.externalApplication)
                : await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            if (launched) {
              debugPrint("✅ TikTok launched: $uri (query: $tiktokQuery)");
              return;
            }
          } catch (e) {
            debugPrint("❌ Failed to launch $uri: $e");
          }
        }
        break;

      case 'tiktok_hashtag':
        // 🔖 TikTok Hashtag: يفتح صفحة هاشتاق مخصص للمنتج
        final ctx = _resolveSearchContext(payload);
        final hashtags = PlatformQueryBuilder.build('tiktok_hashtag', ctx);
        if (hashtags.isEmpty) {
          debugPrint("⚠️ TikTok Hashtag: No hashtags generated.");
          return;
        }
        // فتح أول هاشتاق في TikTok
        final hashtagRaw = hashtags.first.replaceAll('#', '').trim();
        final hashtagEncoded = Uri.encodeComponent(hashtagRaw);
        for (final uri in [
          Uri.parse("tiktok://tag?name=$hashtagEncoded"),
          Uri.parse("https://www.tiktok.com/tag/$hashtagEncoded"),
        ]) {
          try {
            final launched = uri.scheme.startsWith('http')
                ? await launchUrl(uri, mode: LaunchMode.externalApplication)
                : await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            if (launched) {
              debugPrint("✅ TikTok Hashtag launched: $hashtagRaw");
              // عرض كل الهاشتاقات للمستخدم في الشات
              final allTags = hashtags.take(8).join('  ');
              agent.addAndSaveMessage(ChatMessage.assistant(
                content: "🔖 **هاشتاقات مقترحة لمنتجك:**\n\n$allTags\n\n💡 تم فتح: `#$hashtagRaw`",
              ).copyWith(state: MessageState.completed));
              return;
            }
          } catch (e) {
            debugPrint("❌ TikTok Hashtag failed: $e");
          }
        }
        break;

      case 'instagram_link':
        final String instaQuery = getPlatformQuery('instagram', payload);
        if (instaQuery.isEmpty) return;
        final instaEncoded = Uri.encodeComponent(instaQuery).replaceAll('%20', '+');
        await launchUrl(Uri.parse("https://www.instagram.com/explore/search/keyword/?q=$instaEncoded"), mode: LaunchMode.inAppBrowserView);
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
        // 👁️ عدسة Google: يعمل بالصورة فقط — تماماً كـ Google Lens
        final File? lensImage = _getLastProductImage();
        if (lensImage != null) {
          await agent.handleGoogleLens(lensImage);
        } else {
          // ❌ لا توجد صورة → اطلب من المستخدم رفعها
          await agent.addAndSaveMessage(
            ChatMessage.assistant(
              content: "📸 **عدسة Google تحتاج إلى صورة المنتج.**\n\nيرجى إرسال صورة المنتج أولاً وسأقوم بالبحث عن مطابقات بصرية دقيقة له تلقائياً.",
            ).copyWith(state: MessageState.completed),
          );
        }
        break;

      case 'similar_videos':
        final String similarVideosQuery = getPlatformQuery('similar_videos', payload);
        if (similarVideosQuery.isEmpty) return;
        await agent.handleGoogleShortVideos(similarVideosQuery);
        break;

      case 'generate_creative_image':
      case 'image_generation':
      case 'generate_ad_image':
        final String adPrompt = payload is String && payload.isNotEmpty
            ? payload
            : (agent.lastAnalyzedProduct.value ?? "صورة منتج احترافية");
        await agent.handleImageGeneration(adPrompt);
        break;

      case 'generate_branded_ad':
        // 🚀 New, more powerful pipeline for professional ads
        final File? productImage = _getLastProductImage();
        if (productImage != null) {
          // This would call a new method in your agent that wraps the ProductPhotographyService
          await agent.handleBrandedAdPipeline(productImage);
        } else {
          agent.history.add(ChatMessage.assistant(
            content: "📸 **لتصميم إعلان احترافي، أحتاج إلى صورة المنتج أولاً.**\n\nيرجى إرسال صورة المنتج الذي تريد تصميم إعلان له.",
          ).copyWith(state: MessageState.completed));
        }
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
        await agent.handleVideoGeneration(prompt);
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

      case 'twitter_link':
        // 🐦 Twitter/X: بحث بكلمات engagement مخصصة
        final String twitterQuery = getPlatformQuery('twitter', payload);
        if (twitterQuery.isEmpty) return;
        final String twitterEncoded = Uri.encodeComponent(twitterQuery);
        for (final uri in [
          Uri.parse('twitter://search?query=$twitterEncoded'),
          Uri.parse('https://twitter.com/search?q=$twitterEncoded&src=typed_query'),
          Uri.parse('https://x.com/search?q=$twitterEncoded&src=typed_query'),
        ]) {
          try {
            final launched = uri.scheme.startsWith('http')
                ? await launchUrl(uri, mode: LaunchMode.externalApplication)
                : await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            if (launched) { debugPrint('✅ Twitter: $uri (query: $twitterQuery)'); return; }
          } catch (e) { debugPrint('❌ $uri: $e'); }
        }
        break;

      case 'douyin_link':
        // 🎵 抖音 (Douyin): بحث صيني مخصص بكلمات التجارة
        final String douyinQuery = getPlatformQuery('douyin', payload);
        if (douyinQuery.isEmpty) {
          debugPrint("⚠️ Douyin Action: Empty query, skipping.");
          return;
        }
        final douyinEncoded = Uri.encodeComponent(douyinQuery);
        for (final uri in [
          Uri.parse("snssdk1128://search?keyword=$douyinEncoded"),
          Uri.parse("https://www.douyin.com/search/$douyinEncoded"),
        ]) {
          try {
            debugPrint("🔗 Launching Douyin (query: $douyinQuery): $uri");
            final launched = uri.scheme.startsWith('http')
                ? await launchUrl(uri, mode: LaunchMode.externalApplication)
                : await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            if (launched) {
              debugPrint("✅ Douyin launched: $uri");
              return;
            }
          } catch (e) {
            debugPrint("❌ Failed to launch $uri: $e");
          }
        }
        break;

      case 'rednote_link':
        // 📕 小红书 (Rednote/Xiaohongshu): مراجعات وتجارب المنتجات
        final String rednoteQuery = getPlatformQuery('rednote', payload);
        if (rednoteQuery.isEmpty) return;
        final rednoteEncoded = Uri.encodeComponent(rednoteQuery);
        for (final uri in [
          Uri.parse("xhsdiscover://search/result?keyword=$rednoteEncoded"),
          Uri.parse("https://www.xiaohongshu.com/search_result/?keyword=$rednoteEncoded&source=web_search_result_notes"),
        ]) {
          try {
            final launched = uri.scheme.startsWith('http')
                ? await launchUrl(uri, mode: LaunchMode.externalApplication)
                : await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            if (launched) {
              debugPrint("✅ Rednote launched (query: $rednoteQuery)");
              return;
            }
          } catch (e) {
            debugPrint("❌ Rednote failed: $e");
          }
        }
        break;

      case 'kuaishou_link':
        // ⚡ 快手 (Kuaishou): منصة فيديو صينية شعبية
        final String kuaishouQuery = getPlatformQuery('kuaishou', payload);
        if (kuaishouQuery.isEmpty) return;
        final kuaishouEncoded = Uri.encodeComponent(kuaishouQuery);
        for (final uri in [
          Uri.parse("kwai://search?q=$kuaishouEncoded"),
          Uri.parse("https://www.kuaishou.com/search/video?searchKey=$kuaishouEncoded"),
        ]) {
          try {
            final launched = uri.scheme.startsWith('http')
                ? await launchUrl(uri, mode: LaunchMode.externalApplication)
                : await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            if (launched) {
              debugPrint("✅ Kuaishou launched (query: $kuaishouQuery)");
              return;
            }
          } catch (e) {
            debugPrint("❌ Kuaishou failed: $e");
          }
        }
        break;

      case 'youtube_shorts_link':
        // 🎬 YouTube Shorts: فيديوهات قصيرة عن المنتج
        final String ytQuery = getPlatformQuery('youtube_shorts', payload);
        if (ytQuery.isEmpty) return;
        // استخدام نفس محرك البحث الداخلي لعرض النتائج في التطبيق
        await agent.handleYoutubeSearch(ytQuery);
        break;

      case 'jd_link':
        // 🔧 京东 (JD.com): بحث brand + model لتثبيت هوية المنتج
        final String jdQuery = getPlatformQuery('jd', payload);
        if (jdQuery.isEmpty) return;
        final jdEncoded = Uri.encodeComponent(jdQuery);
        await launchUrl(
          Uri.parse("https://search.jd.com/Search?keyword=$jdEncoded&enc=utf-8"),
          mode: LaunchMode.externalApplication,
        );
        break;

      case 'full_platform_description':
        // 📋 وصف متكامل لكل المنصات — يرسل البرومبت الاحترافي الكامل للـ AI
        final String productCtx = payload is String && payload.isNotEmpty
            ? payload
            : (agent.lastAnalyzedProduct.value ?? '');

        // ابحث في التاريخ عن آخر صورة منتج متاحة
        ChatMessage? lastImageMsgFull;
        try {
          lastImageMsgFull = agent.history.lastWhere(
            (m) => m.image != null || m.mediaPath != null || m.responseImageUrl != null,
          );
        } catch (_) {}

        final bool hasProductImageFull = lastImageMsgFull != null;
        final String imageSourceSection = hasProductImageFull
            ? 'تم إرفاق صورة المنتج للتحليل — استخرج جميع المعلومات منها مباشرة.'
            : (productCtx.isNotEmpty
                ? 'لا توجد صورة مرفقة. يرجى استخدام الوصف المكتوب للمنتج الموضح في نهاية هذا الأمر.'
                : 'لا توجد صورة ولا وصف. اطلب من المستخدم تزويدك بمعلومات عن المنتج.');

        const String storeSignature = '''---
🛍️ اندكس ستور اختيارك الأفضل
📲 للطلب والاستفسار (واتساب): 771370740
📍 العنوان: صنعاء - شارع بينون - مقابل صيدلية الرعاية الصحية
🚚 متوفر لدينا خدمة التوصيل لجميع المحافظات 🇾🇪
---''';

        final String productDescSection = productCtx.isNotEmpty && !hasProductImageFull
            ? productCtx
            : '(يرجى تحليل الصورة المرفقة)';

        final String fullPlatformPrompt = """
تصرف كخبير عالمي في:

VIRAL MARKETING
FACEBOOK FEED ALGORITHM
FACEBOOK ORGANIC REACH STRATEGY
TIKTOK VIRAL CONTENT
ORGANIC PRODUCT SALES

هدفك تحويل المنتج إلى حزمة تسويقية كاملة جاهزة للنشر لزيادة المبيعات والوصول المجاني في السوق اليمني.

$imageSourceSection

⚠️ قواعد مهمة:

- جميع النتائج النهائية يجب أن تكون داخل CODE BLOCK منفصل.
- كل قسم داخل CODE BLOCK مستقل لسهولة النسخ.
- داخل CODE BLOCK يجب أن يكون النص النهائي الجاهز للنشر فقط.
- يمنع منعاً باتاً كتابة أي عناوين أو أسماء مراحل أو شروحات داخل CODE BLOCK.
- يمنع كتابة كلمات مثل: المرحلة، التحليل، العنوان، الوصف، أو أي تعليمات.
- CODE BLOCK يجب أن يحتوي فقط على النص النهائي الذي سيستخدم مباشرة في النشر.
- أي عناوين أو توضيحات يجب أن تكون خارج CODE BLOCK فقط.
- النصوص مختصرة لكن قوية تسويقياً.
- يجب ذكر أهم مميزات المنتج داخل الوصف بشكل واضح.
- ركز على الفائدة الحقيقية للزبون.
- اجعل بداية النص جذابة لزيادة التفاعل والتعليقات.

توقيع المتجر الذي سيُضاف في نهاية كل منصة:
$storeSignature

════════════════════════════
المرحلة الأولى: تحليل المنتج
════════════════════════════

استخرج المعلومات التالية:
- اسم المنتج
- فئة المنتج (اختر الفئة الأنسب للمنتج من هذه القائمة فقط: المطبخ، التنظيم والتخزين، الجمال والعناية، الصحة والمساج، العدد والأدوات، السيارات، الرياضة واللياقة، الرحلات والخارجية، الأطفال والألعاب، الإلكترونيات، المنزل والديكور، الإضاءة والطاقة، الحيوانات الأليفة، متنوعات)
- أهم المواصفات
- جميع المميزات
- الفائدة الأساسية للمستخدم
- المشكلة التي يحلها المنتج
- الفئة المستهدفة
- أقوى ميزة تنافسية (USP)

⚠️ اجعل الميزة التنافسية هي محور التسويق.

اعرض التحليل داخل CODE BLOCK.

════════════════════════════
المرحلة الثانية: عنوان SEO
════════════════════════════

أنشئ عنوان قوي قابل للبحث يجمع بين:
- اسم المنتج
- الميزة الأقوى
- كلمة بحث شائعة

ضع العنوان داخل CODE BLOCK.

════════════════════════════
المرحلة الثالثة: HOOK للصورة
════════════════════════════

اكتب جملة قصيرة جذابة توضع على الصورة الإعلانية.

يجب أن:
- تجذب الانتباه فوراً
- توضح الفائدة
- تثير الفضول

ضعها داخل CODE BLOCK.

════════════════════════════
المرحلة الرابعة: وصف فيسبوك (نسخة VIRAL)
════════════════════════════

اكتب وصف مقنع يحتوي على:
1️⃣ Hook قوي في البداية يجذب الانتباه
2️⃣ الفائدة الأساسية للمنتج
3️⃣ ذكر أهم مميزات المنتج بشكل مختصر
4️⃣ سؤال بسيط يشجع الناس على التعليق
5️⃣ دعوة واضحة للطلب

⚠️ لا تجعل الوصف طويلاً لكن يجب أن يوضح المميزات المهمة.

أضف 5 هاشتاقات مناسبة للسوق اليمني.

ضع الوصف داخل CODE BLOCK.

ثم أضف توقيع المتجر المذكور أعلاه خارج CODE BLOCK.

════════════════════════════
المرحلة الخامسة: وصف إنستغرام
════════════════════════════

اكتب وصف قصير بأسلوب lifestyle يحتوي على:
- جملة جذابة
- الفائدة من المنتج
- أهم المميزات بشكل مختصر
- ايموجي مناسب

أضف من 10 إلى 15 هاشتاق.
ضعه داخل CODE BLOCK.
ثم أضف توقيع المتجر.

════════════════════════════
المرحلة السادسة: وصف تيك توك
════════════════════════════

اكتب وصف قصير جداً يحتوي على:
- جملة فضولية
- ذكر ميزة قوية من المنتج
- 5 هاشتاقات ترند

ضعه داخل CODE BLOCK.
ثم أضف توقيع المتجر.

════════════════════════════
المرحلة السابعة: Prompt تصميم صورة غلاف ريلز (Reels Cover)
════════════════════════════

قم بإنشاء Prompt نصي جاهز لمولد الصور (مثل MidJourney أو DALL·E).
لا تنشئ الصورة مباشرة.

⚡ المواصفات:
1️⃣ استخدم صورة المنتج المرفقة عند تنفيذ المولد.
2️⃣ حافظ على شكل المنتج الأصلي 100٪ (اللون، الشكل، التفاصيل).
3️⃣ المقاس النهائي: عمودي 9:16 مناسب لغلاف Reels / TikTok / Instagram.
4️⃣ المنتج مربع 1:1 في منتصف الصورة مع فراغات أعلى وأسفل.
5️⃣ أضف عنوان المنتج بالعربية بخط كبير واضح لا يغطي المنتج.
6️⃣ تحسينات اختيارية: وضوح، إضاءة، تأثير pop خفيف.
7️⃣ لا رقم تواصل، لا شعار، لا نصوص تسويقية إضافية.

ضع النص داخل CODE BLOCK مستقل.

════════════════════════════
المرحلة الثامنة: توقيت النشر
════════════════════════════

حدد داخل CODE BLOCK:
1️⃣ أفضل وقت للنشر في السوق اليمني (بتوقيت صنعاء)
2️⃣ أقوى كلمة مفتاحية في أول سطر لزيادة الوصول
3️⃣ سؤال بسيط لزيادة التعليقات
4️⃣ سبب اختيار هذا التوقيت

════════════════════════════
مرحلة كلمات ريلز (Reels Keywords)
════════════════════════════

أنشئ من 6 إلى 8 كلمات مفتاحية للإشارات في ريلز فيسبوك.

⚠️ القواعد:
- كل كلمة في سطر منفصل داخل CODE BLOCK.
- بدون علامة # أو @.
- قصيرة ومرتبطة بالمنتج والسوق اليمني.

════════════════════════════
المرحلة التاسعة: وصف يوتيوب
════════════════════════════

اكتب وصف احترافي ليوتيوب يحتوي على:
- Hook قوي في أول سطر
- شرح مبسط للمنتج وفائدته
- أهم المميزات بشكل نقاط
- دعوة واضحة للتواصل أو الطلب
- 5 إلى 10 هاشتاقات مناسبة

ضعه داخل CODE BLOCK.
ثم أضف توقيع المتجر.

════════════════════════════
المرحلة العاشرة: منشور تويتر (X)
════════════════════════════

اكتب منشور قصير وجذاب يحتوي على:
- جملة قوية تلفت الانتباه
- ميزة أساسية للمنتج
- دعوة للتفاعل أو الطلب
- 2 إلى 4 هاشتاقات فقط

⚠️ يجب أن يكون مختصر وقابل للانتشار.

ضعه داخل CODE BLOCK.
ثم أضف توقيع المتجر.

════════════════════════════
وصف المنتج (استخدمه فقط إذا لم تكن هناك صورة)
════════════════════════════

$productDescSection
""";

        List<File> imagesToPass = [];
        if (lastImageMsgFull != null) {
          if (lastImageMsgFull.image != null) {
            imagesToPass.add(lastImageMsgFull.image!);
          } else if (lastImageMsgFull.images != null && lastImageMsgFull.images!.isNotEmpty) {
            imagesToPass.addAll(lastImageMsgFull.images!);
          } else if (lastImageMsgFull.mediaPath != null) {
            imagesToPass.add(File(lastImageMsgFull.mediaPath!));
          }
        }

        await agent.respondNormally(
          fullPlatformPrompt,
          images: imagesToPass.isNotEmpty ? imagesToPass : null,
        );
        break;

      default:
        LogService.warning("⚠️ Unknown AI Action received: $id", tag: 'CoreMixin');
    }
    AppLogger.info('EXITING: handleAction');
  }

  // ─────────────────────────────────────────────────────────────
  // 🧠 Platform Intelligence Helpers
  // ─────────────────────────────────────────────────────────────

  /// تحوّل الـ payload (نص خام أو Map) إلى ProductSearchContext غني
  ProductSearchContext _resolveSearchContext(dynamic payload) {
    // 1. إذا كان Map (JSON object من vision analysis)
    if (payload is Map<String, dynamic>) {
      return ProductSearchContext.fromMap(payload);
    }

    // 2. إذا كان String JSON محاط بـ {}
    if (payload is String && payload.trim().startsWith('{')) {
      try {
        final map = jsonDecode(payload) as Map<String, dynamic>;
        return ProductSearchContext.fromMap(map);
      } catch (_) {}
    }

    // 3. نص خام → تحليل بسيط
    final rawText = _getRawQuery(payload);
    if (rawText.isNotEmpty) {
      // 🔄 إذا كان لدينا searchQuery إنجليزي أفضل، استخدمه
      final betterQuery = agent.lastSearchQuery.value.isNotEmpty
          ? agent.lastSearchQuery.value
          : rawText;
      return ProductSearchContext.fromRawString(betterQuery);
    }

    // 4. Fallback: استخدم lastAnalyzedProduct
    final fallback = agent.lastAnalyzedProduct.value ?? '';
    return ProductSearchContext.fromRawString(fallback);
  }

  /// يُعيد أفضل استعلام لمنصة معينة بناءً على الـ payload
  String getPlatformQuery(String platform, dynamic payload) {
    final ctx = _resolveSearchContext(payload);
    if (ctx.isEmpty) {
      // آخر fallback: getCleanSearchQuery القديم
      return getCleanSearchQuery(payload);
    }
    final query = PlatformQueryBuilder.getBestQuery(platform, ctx);
    AppLogger.info('🎯 [PlatformQuery] $platform → "$query" (from: ${ctx.displayName})');
    return query;
  }

  /// استخراج النص الخام من الـ payload (backward compatible)
  String _getRawQuery(dynamic payload) {
    if (payload is String && payload.isNotEmpty) return payload;
    return '';
  }

  /// 📸 يجلب آخر صورة منتج متاحة من التاريخ أو الـ global state
  /// يُستخدم لـ Google Lens وأي action يحتاج الصورة الأصلية
  File? _getLastProductImage() {
    // 1. أولوية: global latestUploadPath (تم تحديثه عند آخر رفع)
    final path = agent.latestUploadPath.value;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (f.existsSync()) return f;
    }

    // 2. fallback: آخر رسالة في التاريخ تحتوي على صورة
    try {
      final lastMsg = agent.history.lastWhere(
        (m) => m.image != null || m.mediaPath != null,
        orElse: () => ChatMessage.user(content: ''),
      );
      if (lastMsg.image != null) return lastMsg.image;
      if (lastMsg.mediaPath != null) {
        final f = File(lastMsg.mediaPath!);
        if (f.existsSync()) return f;
      }
    } catch (_) {}

    return null;
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
    
    // 🧠 Prioritize high-quality English search query if the resolved candidate contains Arabic
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(query) && agent.lastSearchQuery.value.isNotEmpty) {
      debugPrint("🔄 [Search Query Translation]: Overriding Arabic query '$query' with English search query: '${agent.lastSearchQuery.value}'");
      query = agent.lastSearchQuery.value;
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

      final String response;
      if (images != null && images.isNotEmpty) {
        final finalPrompt = "$systemPersona\n\n$prompt";
        final result = await agent.unifiedService.analyzeImage(
          images.first,
          finalPrompt,
          history: chatHistory,
          cancelToken: cancelToken,
        );
        response = result.description;
      } else {
        response = await agent.unifiedService.generateText(
          prompt, 
          systemPersona: systemPersona,
          history: chatHistory,
          cancelToken: cancelToken,
        );
      }
      
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

  /// 📊 مساعد: تتبع إجراءات المستخدم بشكل آمن
  void trackAction(String action, {dynamic payload, String? provider, bool force = false}) {
    if ((action == 'send_message' || action == 'visual_search') && !force) {
      return;
    }
    try {
      if (Get.isRegistered<ActivityTrackingService>()) {
        final tracker = Get.find<ActivityTrackingService>();
        final uid = agent.firebaseUid;
        if (uid != null && uid.isNotEmpty) {
          final details = <String, dynamic>{};
          if (payload != null && payload is String && payload.isNotEmpty) {
            details['payload'] = payload.length > 100 ? payload.substring(0, 100) : payload;
          }
          final product = agent.lastAnalyzedProduct.value;
          if (product != null && product.isNotEmpty) {
            details['product'] = product;
          }

          // تحديد المزود الفعلي
          final String effectiveProvider = provider ?? agent.unifiedService.lastUsedProvider;
          if (effectiveProvider.isNotEmpty) {
            details['provider'] = effectiveProvider;
          }

          tracker.logAction(
            userId: uid,
            action: action,
            details: details,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ trackAction error: $e');
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
