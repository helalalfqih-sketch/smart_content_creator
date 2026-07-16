import 'dart:io';
import 'dart:ui'; // 🎨 للتأثيرات البصرية المتقدمة (Blur)
import 'package:flutter/material.dart' hide Intent;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

// ... (existing imports)

import '../ai/chat_smart_agent.dart';

import '../widgets/chat_drawer.dart';
import '../widgets/chat_bubble.dart';
import '../theme/app_theme.dart';
import '../widgets/permission_controlled_widget.dart';
import '../widgets/api_key_status_indicator.dart'; // 🔄 تمت إضافة مؤشر حالة مفتاح API
import 'product_photography_screen.dart'; // 🎨 Product Photography Studio
import '../ai/core/agent_models.dart'; // 🔄 تمت الإضافة للمدخلات المعالجة
// 🎯 نمط النتيجة لمعالجة الأخطاء
import '../core/models/chat_message.dart'; // Using central ChatMessage
import '../widgets/chat/chat_input_area.dart'; // 💬 ودجت مستخرج لمنطقة الإدخال
import '../core/theme/animations/galactic_background_unified.dart'; // 🌌 الخلفية المجرية

import '../widgets/chat/swipe_to_reply.dart';
import '../widgets/animations/vip_message_entry.dart';
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return; // 🛡️ حماية من الـ defunct element
      if (_scrollController.hasClients) {
        final show = _scrollController.offset > 400;
        if (show != _showScrollToBottom) {
          setState(() => _showScrollToBottom = show);
        }
      }
    });
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
  void _scrollToBottom({bool force = false}) async {
    if (force) _isUserScrolling = false;
    await Future.delayed(const Duration(milliseconds: 30));
    if (!mounted) return; // 🛡️ حماية إضافية بعد التأخير
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1117).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
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
                      Icons.attach_file, 'إرفاق ملف', AppTheme.accent, () async {
                    Navigator.pop(context);
                    pickAnyMediaFile();
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_image_attach',
                  child: _buildAttachmentItem(
                      Icons.image, 'صورة', AppTheme.primary, () {
                    Navigator.pop(context);
                    pickImage(ImageSource.gallery);
                  }),
                ),
                VisibilityControlled(
                  controlName: 'chat_product_photography',
                  child: _buildAttachmentItem(
                      Icons.auto_awesome, 'استوديو المنتجات الذكي', AppTheme.accent,
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
                  controlName: 'chat_camera_attach',
                  child: _buildAttachmentItem(
                      Icons.camera_alt, 'كاميرا', AppTheme.accent, () {
                    Navigator.pop(context);
                    pickImage(ImageSource.camera);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    Expanded(
                      child: Stack(
                        children: [
                          // 📜 القائمة الأساسية: تراقب فقط طول السجل
                           Obx(() {
                              final msgs = _agent.history;
                              if (msgs.isEmpty) return _buildEmptyState();

                              return ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(left: 16, right: 16, top: 15, bottom: 80),
                                itemCount: msgs.length,
                                itemBuilder: (context, index) {
                                final msg = msgs[index];
                                return VipMessageEntry(
                                  index: index,
                                  child: Align(
                                    alignment: msg.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                                    child: SwipeToReply(
                                      isUser: msg.role == 'user',
                                      enabled: canReplyTo(msg),
                                      onSwipe: () => setState(() => _replyingToMessage = msg),
                                      child: ChatBubble(
                                        id: msg.id,
                                        text: msg.content,
                                        isUser: msg.role == 'user',
                                        type: msg.type,
                                        image: msg.image,
                                        videoUrl: msg.videoUrl,
                                        videoThumbnail: msg.videoThumbnail,
                                        videoAuthor: msg.videoAuthor,
                                        mediaPath: msg.mediaPath,
                                        state: msg.state,
                                        isError: msg.isError,
                                        agentResult: msg.agentResult,
                                        productContext: msg.productContext,
                                        provider: msg.provider,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),

                          // ⚙️ منطقة حالة المعالجة (منفصلة تماماً لعدم كسر الفيديوهات)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Obx(() {
                              if (!_agent.isLoading.value) return const SizedBox.shrink();
                              return Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          _agent.pipelineMessage.value.isEmpty ? "جاري المعالجة..." : _agent.pipelineMessage.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_showScrollToBottom)
                            Positioned(
                              bottom: 20,
                              left: 20,
                              child: FloatingActionButton.small(
                                onPressed: () => _scrollToBottom(force: true),
                                backgroundColor: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black54
                                    : Colors.white.withValues(alpha: 0.8),
                                child: Icon(Icons.arrow_downward,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                        ],
                      ),
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
                          productContext: (_agent.lastSearchQuery.value.isNotEmpty)
                              ? _agent.lastSearchQuery.value
                              : _agent.lastAnalyzedProduct.value,
                          onClearContext: () {
                            _agent.lastAnalyzedProduct.value = null;
                            _agent.lastSearchQuery.value = ""; // 🔥 مسح الاستعلام التفصيلي أيضاً
                          },
                          smartActions: _agent.availableSmartActions,
                          onActionTap: (action) => _agent.handleSuggestedAction(
                              action,
                              selectedImages.isNotEmpty ? selectedImages.first : null,
                              images: selectedImages),
                          onSend: sendMessage,
                          onCancel: _agent.cancelCurrentOperation,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            automaticallyImplyLeading: false,
            title: Text('صانع المحتوى  ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2),
            leading: Builder(builder: (context) => IconButton(icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87), onPressed: () => Scaffold.of(context).openDrawer())),
            actions: [
              const ApiKeyStatusIndicator(),
              _buildAppBarAction(context: context, icon: Icons.add, color: AppTheme.primary, onTap: () => _agent.forceClearHistory()),
              _buildAppBarAction(context: context, icon: Icons.settings, onTap: () => Get.toNamed('/settings')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction({required BuildContext context, required IconData icon, Color? color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(icon: Icon(icon, color: color ?? (isDark ? Colors.white70 : Colors.black54)), onPressed: onTap);
  }


  Widget _buildAttachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [IconButton(icon: Icon(icon, color: color), onPressed: onTap), Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10))]);
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome, size: 64, color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1)), Text("مرحباً! أنا جاهز لمساعدتك", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 18))]));
  }
}
