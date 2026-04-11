import 'dart:io';
import 'dart:ui'; // 🎨 للتأثيرات البصرية المتقدمة (Blur)
import 'dart:async'; // 🕒 للمؤقت
import 'package:flutter/material.dart' hide Intent;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/models/tiktok_video.dart'; // 📱 TikTok Model

// ... (existing imports)

import '../core/utils/snackbar_utils.dart';
import '../ai/chat_smart_agent.dart';
import '../services/video_pipeline_service.dart';
import '../services/ai/gemini_vision_service.dart';
import '../services/ffmpeg_service.dart';

import '../widgets/chat_drawer.dart';
import '../widgets/chat_bubble.dart';
import '../theme/app_theme.dart';
import '../widgets/permission_controlled_widget.dart';
import '../widgets/api_key_status_indicator.dart'; // 🔄 تمت إضافة مؤشر حالة مفتاح API
import '../widgets/tiktok_video_grid.dart'; // 🎞️ جديد: دعم شبكة فيديوهات تيك توك
import 'product_photography_screen.dart'; // 🎨 Product Photography Studio
import '../ai/core/agent_models.dart'; // 🔄 تمت الإضافة للمدخلات المعالجة
// 🎯 نمط النتيجة لمعالجة الأخطاء
import '../core/models/chat_message.dart'; // Using central ChatMessage
import '../widgets/chat/chat_input_area.dart'; // 💬 ودجت مستخرج لمنطقة الإدخال
import '../core/theme/animations/galactic_background_unified.dart'; // 🌌 الخلفية المجرية

import '../widgets/chat/swipe_to_reply.dart';
import '../widgets/animations/vip_message_entry.dart';
import '../widgets/chat_loading_shimmer.dart';
import '../core/services/log_service.dart';
import 'ai_chat/mixins/chat_media_mixin.dart';
import 'ai_chat/mixins/chat_action_mixin.dart';
import 'ai_chat/mixins/chat_enhancement_mixin.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialMode; // video_gen, script_writer
  const AiChatScreen({super.key, this.initialMode});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with ChatMediaMixin, ChatActionMixin, ChatEnhancementMixin {
  final TextEditingController _controller = TextEditingController();
  final ChatSmartAgent _agent = Get.find<ChatSmartAgent>();
  final ScrollController _scrollController = ScrollController();
  final VideoPipelineService _videoPipeline = Get.find<VideoPipelineService>();
  final GeminiVisionService _geminiVisionService = Get.find<GeminiVisionService>();

  // Overriding getters for mixins
  @override
  TextEditingController get controller => _controller;
  @override
  ChatSmartAgent get agent => _agent;
  
  // Property linkage for mixins
  @override
  ChatMessage? get replyingToMessage => _replyingToMessage;
  @override
  set replyingToMessage(ChatMessage? value) => setState(() => _replyingToMessage = value);

  // Implement the abstract methods from mixins by providing state
  @override
  List<File> get selectedImages => _localSelectedImages;
  @override
  set selectedImages(List<File> value) => setState(() => _localSelectedImages = value);
  List<File> _localSelectedImages = [];

  @override
  File? get selectedVideo => _localSelectedVideo;
  @override
  set selectedVideo(File? value) => setState(() => _localSelectedVideo = value);
  File? _localSelectedVideo;

  @override
  bool get isCompressingImage => _localIsCompressingImage;
  @override
  set isCompressingImage(bool value) => setState(() => _localIsCompressingImage = value);
  bool _localIsCompressingImage = false;

  @override
  List<File> get compressedImages => _localCompressedImages;
  @override
  set compressedImages(List<File> value) => setState(() => _localCompressedImages = value);
  List<File> _localCompressedImages = [];

  @override
  double get processingProgress => _localProcessingProgress;
  @override
  set processingProgress(double value) => setState(() => _localProcessingProgress = value);
  double _localProcessingProgress = 0.0;

  @override
  ProcessedInput? get preAnalysisResult => _localPreAnalysisResult;
  @override
  set preAnalysisResult(ProcessedInput? value) => setState(() => _localPreAnalysisResult = value);
  ProcessedInput? _localPreAnalysisResult;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialMode();
    });

    // 📜 مراقب ذكي: كلما تغيرت قائمة الرسائل، انزل للأسفل تلقائياً (WhatsApp Style)
    ever(_agent.history, (_) {
      _scrollToBottom();
    });

    // 🌊 مراقب الحالة: إعادة تفعيل التمرير التلقائي عند انتهاء التوليد
    ever(_agent.isLoading, (bool isLoading) {
      if (!isLoading) {
        _isUserScrolling = false;
        LogService.success("Message flow ended, auto-scroll re-enabled.", tag: 'CHAT');
      }
    });
  }

  // 🆕 حالة تتبع تصفح المستخدم
  bool _isUserScrolling = false;

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 400;
      if (show != _showScrollToBottom) {
        setState(() => _showScrollToBottom = show);
      }
    }
  }

  void _handleInitialMode() {
    if (widget.initialMode != null) {
      _agent.currentMode.value = widget.initialMode!;
    }
  }

  // Shortcuts
  bool _showScrollToBottom = false;
  ChatMessage? _replyingToMessage; // 🔗 الرسالة الجاري الرد عليها
  
  // Mixin overrides
  @override
  void scrollToBottom({bool force = false}) => _scrollToBottom(force: force);


  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _controller.dispose();
    progressTimer?.cancel();
    super.dispose();
  }

  /// 📜 دالة للتمرير التلقائي لأسفل المحادثة بنعومة
  void _scrollToBottom({bool force = false}) {
    if (force) _isUserScrolling = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isUserScrolling && !force) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 20,
              spacing: 20,
              children: [
                VisibilityControlled(
                  controlName: 'chat_file_attach',
                  child: _buildAttachmentItem(
                      Icons.attach_file, 'تحميل ملف', Colors.indigo, () async {
                    Navigator.pop(context);
                    pickAnyMediaFile();
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_image_attach',
                  child: _buildAttachmentItem(
                      Icons.image, 'صورة', Colors.purple, () {
                    Navigator.pop(context);
                    pickImage(ImageSource.gallery);
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_product_photography',
                  child: _buildAttachmentItem(
                      Icons.auto_awesome, 'استوديو الصور AI', Colors.deepPurple,
                      () async {
                    Navigator.pop(context);
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      Get.to(() => const ProductPhotographyScreen(),
                          arguments: File(image.path));
                    }
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_ai_image_gen',
                  child: _buildAttachmentItem(
                      Icons.palette_rounded, 'توليد صورة AI', Colors.pinkAccent,
                      () async {
                    Navigator.pop(context);
                    final TextEditingController promptController =
                        TextEditingController();
                    Get.defaultDialog(
                      title: 'توليد صورة بالذكاء الاصطناعي',
                      content: Column(
                        children: [
                          const Text(
                              'صف الصورة التي تريد توليدها بدقة لإخراج أفضل النتائج:'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: promptController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'مثال: سيارة رياضية تجري في دبي...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                      textConfirm: 'توليد',
                      textCancel: 'إلغاء',
                      confirmTextColor: Colors.white,
                      onConfirm: () {
                        if (promptController.text.isNotEmpty) {
                          Get.back();
                          _agent.generateCreatorImage(promptController.text);
                        }
                      },
                    );
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_camera_attach',
                  child: _buildAttachmentItem(
                      Icons.camera_alt, 'كاميرا', Colors.blue, () {
                    Navigator.pop(context);
                    pickImage(ImageSource.camera);
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_audio_enhance',
                  child: _buildAttachmentItem(
                      Icons.music_note_rounded, 'تحسين الصوت', Colors.indigoAccent, () {
                    Navigator.pop(context);
                    pickVideoForAudioEnhance();
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_fetch_trends',
                  child: _buildAttachmentItem(
                      Icons.trending_up, 'جلب ترند', Colors.orange, () async {
                    Navigator.pop(context);
                    if (selectedImages.isEmpty) {
                      SnackBarUtils.showSmartSnackBar(title: 'تنبيه', message: 'اختر صورة المنتج أولاً!', isError: true);
                      pickImage(ImageSource.gallery);
                      return;
                    }
                    final result = await _agent.extractProductName(selectedImages.first);
                    final productName = result.valueOrNull;
                    if (productName == null || productName.isEmpty) return;
                    _agent.searchTrendsForProduct(productName);
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.tiktok, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('فيديوهات لـ: $productName', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                                ],
                              ),
                            ),
                            if (mounted)
                              Expanded(
                                child: Obx(() => TikTokVideoGrid(videos: _agent.currentTrendVideos.cast<TikTokVideo>(), isScrollable: true)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_smart_video',
                  child: _buildAttachmentItem(Icons.movie_creation_outlined, 'فيديو ذكي', Colors.purpleAccent, () {
                    Navigator.pop(context);
                    if (selectedImages.isEmpty) {
                      SnackBarUtils.showSmartSnackBar(title: 'تنبيه', message: 'الرجاء اختيار صورة منتج أولاً!', isError: true);
                    } else {
                      _handleSmartVideoGeneration();
                    }
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_auto_director',
                  child: _buildAttachmentItem(Icons.auto_awesome, 'توليد تلقائي 🎬', Colors.deepPurple, () {
                    Navigator.pop(context);
                    _agent.autoDirectorMode();
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_video_enhancer',
                  child: _buildAttachmentItem(Icons.auto_fix_high, 'محسن الفيديو', Colors.deepPurple, () async {
                    Navigator.pop(context);
                    final XFile? videoFile = await picker.pickVideo(source: ImageSource.gallery);
                    if (videoFile != null) _showAspectRatioDialog(File(videoFile.path));
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAspectRatioDialog(File video) {
    Get.defaultDialog(
      title: "إطار الفيديو 🎞️",
      content: const Text("اختر المنصة المستهدفة لتنسيق الفيديو تلقائياً:"),
      backgroundColor: AppTheme.surfaceColor,
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ratioDialogItem(video, "Original", Icons.aspect_ratio),
            _ratioDialogItem(video, "9:16", Icons.smartphone),
            _ratioDialogItem(video, "16:9", Icons.tv),
            _ratioDialogItem(video, "1:1", Icons.crop_square),
          ],
        )
      ],
    );
  }

  Widget _ratioDialogItem(File video, String ratio, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color.fromARGB(255, 206, 109, 150)),
      title: Text(ratio == "Original" ? "الأصلي (كما هو)" : ratio),
      onTap: () {
        Get.back();
        _enhanceVideoWithAI(video, ratio: ratio);
      },
    );
  }

  Future<void> _enhanceVideoWithAI(File video, {String ratio = "Original"}) async {
    _agent.isLoading.value = true;
    try {
      final analysis = await _geminiVisionService.analyzeVideoQuality(video);
      final filters = await _geminiVisionService.buildEnhancementFilters(analysis);
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(tempDir.path, 'ai_enhanced_${DateTime.now().millisecondsSinceEpoch}.mp4');
      final result = await FfmpegService.enhanceVideo(inputPath: video.path, outputPath: outputPath, filterChain: filters, targetRatio: ratio);
      if (result != null) {
        _agent.history.add(ChatMessage.assistant(content: "✨ تم تحسين الفيديو بنجاح بمعايير Cinema 4K!").copyWith(state: MessageState.completed, videoUrl: result.path));
      }
    } catch (e) {
      SnackBarUtils.showSmartSnackBar(title: "❌ فشل التحسين", message: e.toString(), isError: true);
    } finally {
      _agent.isLoading.value = false;
    }
  }

  void _showQuickToolsMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 20, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Text("الأدوات السريعة ⚡", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 15,
              children: [
                _buildQuickToolItem(icon: Icons.shopping_cart_rounded, label: "تسوق 🛒", color: Colors.greenAccent, onTap: () => _triggerQuickTool("shopping")),
                _buildQuickToolItem(icon: Icons.trending_up_rounded, label: "تريندات 📈", color: Colors.pinkAccent, onTap: () => _triggerQuickTool("google_short_videos")),
                _buildQuickToolItem(icon: Icons.play_circle_fill_rounded, label: "فيديوهات 🎬", color: Colors.redAccent, onTap: () => _triggerQuickTool("videos")),
                _buildQuickToolItem(icon: Icons.newspaper_rounded, label: "أخبار 📰", color: Colors.lightBlueAccent, onTap: () => _triggerQuickTool("news")),
                _buildQuickToolItem(icon: Icons.auto_fix_high_rounded, label: "توليد صور 🎨", color: Colors.purpleAccent, onTap: () => _triggerQuickTool("image_gen")),
                _buildQuickToolItem(icon: Icons.camera_alt_rounded, label: "فحص صورة 🔍", color: Colors.indigoAccent, onTap: () => _triggerQuickTool("lens")),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _triggerQuickTool(String id) {
    Get.back();
    final query = _agent.lastAnalyzedProduct.value ?? _controller.text;
    _agent.handleSuggestedAction(SuggestedAction(label: id, toolId: id, parameters: {"query": query, "product": query}), selectedImages.isNotEmpty ? selectedImages.first : null);
  }

  Future<void> _handleSmartVideoGeneration() async {
    if (selectedImages.isEmpty) return;
    final imageToUse = selectedImages.first;
    _agent.isLoading.value = true;
    await _agent.sendUserMessage("قم بإنشاء فيديو تسويقي لهذا المنتج (Pipeline) 🎬", image: imageToUse, analyzeImage: false);
    try {
      final videoUrl = await _videoPipeline.generateVideo(image: imageToUse, onStatusUpdate: (status) {
        _agent.pipelineMessage.value = status.message;
        _agent.pipelineProgress.value = status.progress;
      });
      _agent.history.add(ChatMessage.assistant(content: "🚀 تم إنشاء الفيديو بنجاح!\n[VIDEO:$videoUrl]").copyWith(state: MessageState.completed, image: imageToUse));
    } catch (e) {
      _agent.history.add(ChatMessage.assistant(content: "❌ فشل الإنشاء: $e").copyWith(state: MessageState.completed));
    } finally {
      _agent.isLoading.value = false;
      setState(() => selectedImages = []);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.black,
        drawer: const ChatDrawer(),
        extendBodyBehindAppBar: true,
        appBar: _buildVipAppBar(context),
        body: Stack(
          children: [
            // 🌌 1. الخلفية المجرية (Fixed Layer)
            const Positioned.fill(child: GalacticBackgroundUnified()),

            // 💎 2. المحتوى الرئيسي (Interactive Layer)
            Positioned.fill(
              child: SafeArea(
                bottom: false, // نترك التعامل مع الأسفل لـ TextField والـ Scaffold
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    // 📜 منطقة الرسائل
                    Expanded(
                      child: Obx(() {
                        final msgs = _agent.history;
                        final isLoading = _agent.isLoading.value;

                        if (msgs.isEmpty && isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (msgs.isEmpty) return _buildEmptyState();

                        return RefreshIndicator(
                          onRefresh: () async {
                            await Future.delayed(const Duration(milliseconds: 800));
                            setState(() {});
                          },
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 15, // تقليل البادينج العلوي بعد إضافة SafeArea
                                  bottom: 20,
                                ),
                                itemCount: msgs.length + (isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == msgs.length) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Column(
                                        children: [
                                          const ChatLoadingShimmer(),
                                          if (_agent.pipelineMessage.value.isNotEmpty)
                                            Text(
                                              _agent.pipelineMessage.value,
                                              style: const TextStyle(
                                                  fontSize: 10, color: Colors.white54),
                                            )
                                        ],
                                      ),
                                    );
                                  }
                                  final msg = msgs[index];
                                  return VipMessageEntry(
                                    index: index,
                                    child: Align(
                                      alignment: msg.role == 'user'
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: SwipeToReply(
                                        isUser: msg.role == 'user',
                                        enabled: canReplyTo(msg),
                                        onSwipe: () =>
                                            setState(() => _replyingToMessage = msg),
                                        child: ChatBubble(
                                          id: msg.id,
                                          text: msg.content,
                                          isUser: msg.role == 'user',
                                          image: msg.image,
                                          state: msg.state,
                                          isError: msg.isError,
                                          agentResult: msg.agentResult,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_showScrollToBottom)
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  child: FloatingActionButton.small(
                                    onPressed: () => _scrollToBottom(force: true),
                                    backgroundColor: Colors.black54,
                                    child: const Icon(Icons.arrow_downward,
                                        color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),

                    // 💬 منطقة الإدخال
                    Obx(() => ChatInputArea(
                          controller: _controller,
                          isLoading: _agent.isLoading,
                          selectedImages: selectedImages,
                          selectedVideo: selectedVideo,
                          isCompressingImage: isCompressingImage,
                          processingProgress: processingProgress,
                          replyingToMessage: _replyingToMessage,
                          onClearReply: () =>
                              setState(() => _replyingToMessage = null),
                          productContext: _agent.lastAnalyzedProduct.value,
                          onClearContext: () =>
                              _agent.lastAnalyzedProduct.value = null,
                          smartActions: _agent.availableSmartActions,
                          onActionTap: (action) => _agent.handleSuggestedAction(
                              action,
                              selectedImages.isNotEmpty ? selectedImages.first : null,
                              images: selectedImages),
                          onSend: sendMessage,
                          onCancel: _agent.cancelCurrentOperation,
                          onShowQuickTools: _showQuickToolsMenu,
                          onShowAttachmentMenu: _showAttachmentMenu,
                          onAudioEnhance: handleAudioEnhancement,
                          onRemoveImage: (index) {
                            setState(() {
                              selectedImages.removeAt(index);
                            });
                          },
                          onClearVideo: () => setState(() => selectedVideo = null),
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildVipAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('المحتوى الذكي VIP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.black.withValues(alpha: 0.2),
            leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
            actions: [
              const ApiKeyStatusIndicator(),
              _buildAppBarAction(icon: Icons.add, color: Colors.greenAccent, onTap: () => _agent.forceClearHistory()),
              _buildAppBarAction(icon: Icons.settings, onTap: () => Get.toNamed('/settings')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction({required IconData icon, Color? color, required VoidCallback onTap}) {
    return IconButton(icon: Icon(icon, color: color ?? Colors.white70), onPressed: onTap);
  }

  Widget _buildQuickToolItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Column(children: [IconButton(icon: Icon(icon, color: color), onPressed: onTap), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))]);
  }

  Widget _buildAttachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(children: [IconButton(icon: Icon(icon, color: color), onPressed: onTap), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))]);
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome, size: 64, color: Colors.white.withValues(alpha: 0.2)), const Text("مرحباً! أنا جاهز لمساعدتك", style: TextStyle(color: Colors.white70, fontSize: 18))]));
  }
}
