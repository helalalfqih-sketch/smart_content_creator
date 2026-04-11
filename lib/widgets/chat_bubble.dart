import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/utils/snackbar_utils.dart';
import '../core/utils/responsive_helper.dart';

// المكونات الداخلية والموديلات
import 'smart_ad_bubble.dart';
import 'media_action_bar.dart';
import 'recommendation_panel.dart';
import 'scenario_display_widget.dart';
import 'modern_video_bubble.dart';
import 'tiktok_video_widget.dart';
import 'chat/full_screen_viewer.dart';
import '../ai/chat_smart_agent.dart';
import '../core/models/chat_message.dart';
import '../core/models/tiktok_video.dart';
import '../ai/core/agent_models.dart';
import '../ai/ui/agent_result_renderer.dart';

class ChatBubble extends StatefulWidget {
  final String id;
  final String text;
  final bool isUser;
  final File? image;
  final String? videoUrl;
  final String? videoThumbnail;
  final String? videoAuthor;
  final String? responseImageUrl;
  final List<dynamic>? actions;
  final List<MediaAction>? mediaActions;
  final String? audioPath;
  final bool isGenerating;
  final MessageState state;
  final bool isError;
  final List<Map<String, dynamic>>? recommendations;
  final VoidCallback? onRetry;
  final bool isNew;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToRole;
  final String? mediaPath; // 📸 Local path for persistence
  final String? productContext; // 🧠 Active product context
  final AgentResult? agentResult; // 🤖 Added AgentResult Support
  final Map<String, dynamic>? errorDetails; // 🔴 For glassmorphic error cards

  const ChatBubble({
    super.key,
    required this.id,
    required this.text,
    required this.isUser,
    this.image,
    this.videoUrl,
    this.videoThumbnail,
    this.videoAuthor,
    this.responseImageUrl,
    this.actions,
    this.mediaActions,
    this.audioPath,
    this.isGenerating = false,
    this.state = MessageState.completed,
    this.isError = false,
    this.recommendations,
    this.onRetry,
    this.isNew = false,
    this.replyToId,
    this.replyToContent,
    this.replyToRole,
    this.mediaPath,
    this.productContext,
    this.agentResult,
    this.errorDetails,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  Map<String, dynamic>? _smartAdData;
  String? _currentVideoSource;
  String _displayText = '';
  bool _isActionsExpanded = false; // 🪄 Toggle for Action Hub

  @override
  void initState() {
    super.initState();
    _initializeContent();
  }

  void _initializeContent() {
    if (widget.text.contains('[SMART_AD:')) _parseSmartAd();

    // استخراج الفيديو من النص أو الـ property
    if (widget.text.contains('[VIDEO:')) {
      final regex = RegExp(r'\[VIDEO:([^\]]+)\]');
      final match = regex.firstMatch(widget.text);
      if (match != null) _currentVideoSource = match.group(1);
    } else {
      _currentVideoSource = widget.videoUrl;
    }

    // منطق الـ Streaming (الكتابة الحية)
    if (!widget.isUser && widget.text.isNotEmpty) {
      if (widget.state == MessageState.streaming) {
        _displayText = _cleanText();
      } else if (widget.isNew) {
        _startFakeStreaming(_cleanText());
      } else {
        _displayText = _cleanText();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.state != widget.state ||
        oldWidget.id != widget.id ||
        oldWidget.agentResult != widget.agentResult) {
      _initializeContent();
    }
  }

  void _startFakeStreaming(String fullText) async {
    if (fullText.isEmpty) return;
    _displayText = '';
    final runes = fullText.runes.toList();
    for (int i = 0; i < runes.length; i++) {
      await Future.delayed(const Duration(milliseconds: 6));
      if (!mounted) return;
      if (widget.state == MessageState.streaming) {
        setState(() => _displayText = _cleanText());
        return;
      }
      setState(() {
        _displayText = String.fromCharCodes(runes.getRange(0, i + 1));
      });
    }
  }

  void _parseSmartAd() {
    final regex = RegExp(r'\[SMART_AD:(\{.*\})\]');
    final match = regex.firstMatch(widget.text);
    if (match != null) {
      try {
        _smartAdData = jsonDecode(match.group(1)!);
      } catch (e) {
        debugPrint("Ad Parse Error: $e");
      }
    }
  }

  String _cleanText() {
    var s = widget.text;
    if (s.isEmpty) return s;
    s = s.replaceAll(RegExp(r'\[(SYSTEM|DEBUG|INTERNAL|STAGE|LOG).*?\]'), '');
    s = s.replaceAll(RegExp(r'\[ACTIONS\].*?$', dotAll: true), '');
    s = s.replaceAll(RegExp(r'\[VIDEO:[^\]]+\]'), '');
    s = s.replaceAll(RegExp(r'\[IMAGE:[^\]]+\]'), '');
    s = s.replaceAll(RegExp(r'\[SMART_AD:\{.*\}\]'), '');
    s = s.replaceAll(RegExp(r'\[صورة\]'), '');
    s = s.replaceAll('صورة منتج', '');
    s = s.replaceAll('صورة محددة', '');
    s = s.replaceAll('N/A', '');

    final trimmed = s.trim();
    if (trimmed.isEmpty && widget.text.trim().isNotEmpty) {
      if (widget.text.startsWith('[')) return '';
      return widget.text.trim();
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isError = widget.isError || widget.text.contains('❌');
    final String cleanText = widget.isUser ? widget.text : _displayText;
    final bool hasImage = widget.image != null ||
        widget.responseImageUrl != null ||
        widget.mediaPath != null;
    final bool isImageOnly = hasImage && cleanText.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!widget.isUser) _buildAssistantAvatar(),
              const SizedBox(width: 8),
              _buildMessageBody(
                  context, cleanText, isImageOnly, hasImage, isDark, isError),
            ],
          ),
          if (!widget.isUser) _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildAssistantAvatar() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD486), Color(0xFF00E5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD486).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, size: 18, color: Colors.black),
      ),
    );
  }

  Widget _buildMessageBody(BuildContext context, String cleanText,
      bool isImageOnly, bool hasImage, bool isDark, bool isError) {
    return Flexible(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment:
              widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.replyToContent != null) _buildReplyReference(isDark),

            // محتوى الرسالة الرئيسي
            Container(
              padding: widget.isUser && isImageOnly
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(12),
              decoration:
                  _getBubbleDecoration(isDark, isImageOnly && widget.isUser),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_smartAdData != null)
                    SmartAdBubble(
                      image: widget.image,
                      title: _smartAdData!['title'] ?? '',
                      subtitles: List<String>.from(_smartAdData!['subs'] ?? []),
                      footer: _smartAdData!['footer'] ?? '',
                    ),
                  if (hasImage && _smartAdData == null) _buildImageDisplay(),
                  if (widget.videoUrl != null && widget.videoThumbnail != null)
                    _buildTikTokVideoWidget(cleanText),
                  if (_currentVideoSource != null &&
                      widget.videoThumbnail == null)
                    _buildModernVideoPlayer(),

                  // 🔴 Glassmorphic Error Card for AI Errors
                  if (widget.errorDetails != null)
                    _buildErrorCard(
                        widget.errorDetails!['title'] ?? 'خطأ',
                        widget.errorDetails!['message'] ?? '',
                        widget.errorDetails!['isApiKeyError'] == true,
                        isDark),

                  if (cleanText.isNotEmpty && widget.errorDetails == null)
                    _buildTextWithExpand(cleanText, isDark, isError),

                  // 🤖 AI Agent Result Rendering (Decoupled)
                  if (widget.agentResult != null) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.psychology,
                              color: Colors.purple, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "SMART_DATA: ${widget.agentResult!.type.toString().split('.').last.toUpperCase()}",
                              style: const TextStyle(
                                  color: Colors.purple,
                                  fontSize: 9, // 📏 Smaller for safety
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AgentResultRenderer.render(widget.agentResult!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _getBubbleDecoration(bool isDark, bool isImageOnly) {
    if (widget.isUser) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22).copyWith(
          bottomRight: const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      );
    }

    if (widget.errorDetails != null) {
      return const BoxDecoration(
        color: Colors.transparent, // الزجاجية تعالج خلفية الخطأ
      );
    }

    if (widget.isError) {
      return BoxDecoration(
        color: const Color(0xFF1A0A0A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22).copyWith(
          bottomLeft: const Radius.circular(4),
        ),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.1),
            blurRadius: 15,
          )
        ],
      );
    }

    return BoxDecoration(
      color: isDark ? const Color(0xFF121217) : Colors.white,
      borderRadius: BorderRadius.circular(22).copyWith(
        bottomLeft: const Radius.circular(4),
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  Widget _buildTextWithExpand(String text, bool isDark, bool isError) {
    return _buildTextContent(text, isDark, isError);
  }

  Widget _buildTextContent(String text, bool isDark, bool isError) {
    if (_isScenario(text)) return ScenarioDisplayWidget(content: text);

    final color = widget.isUser
        ? Colors.white
        : (isError
            ? Colors.redAccent
            : (isDark ? Colors.white : Colors.black87));

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(
          color: color,
          fontSize: 15,
          height: 1.6,
          fontFamily: 'IBMPlexSansArabic',
        ),
        strong: const TextStyle(
          color: Color(0xFF2DD486),
          fontWeight: FontWeight.bold,
        ),
        em: const TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.white70,
        ),
        code: TextStyle(
            backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
            fontFamily: 'monospace'),
      ),
      onTapLink: (text, href, title) => launchUrl(Uri.parse(href!)),
    );
  }

  Widget _buildErrorCard(
      String title, String message, bool isApiKeyError, bool isDark) {
    return Container(
      width: 280, // 🛠️ Fix: Add strict width to prevent intrinsic layout crash
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.redAccent.withValues(alpha: 0.1)
            : Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.5,
                  ),
            ),
          ],
          if (isApiKeyError) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Get.toNamed('/settings'),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('الذهاب للإعدادات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageDisplay() {
    final heroTag = "img_${widget.id}";
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          Get.to(
            () => FullScreenImageViewer(
              imageFile: widget.image,
              imageUrl: widget.responseImageUrl,
              mediaPath: widget.mediaPath, // 📸 Pass local path
              tag: heroTag,
            ),
            transition: Transition.fadeIn,
            fullscreenDialog: true,
          );
        },
        child: Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: widget.responseImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.responseImageUrl!,
                    width: 280,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 280,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00FF88))),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image),
                  )
                : (kIsWeb
                    ? Image.network(
                        widget.image!.path,
                        width: 280,
                        fit: BoxFit.cover,
                      )
                    : (widget.mediaPath != null
                        ? Image.file(
                            File(widget.mediaPath!),
                            width: 280,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            widget.image!,
                            width: 280,
                            fit: BoxFit.cover,
                          ))),
          ),
        ),
      ),
    );
  }

  Widget _buildTikTokVideoWidget(String cleanText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TikTokVideoWidget(
        video: TikTokVideo(
          id: widget.id,
          videoUrl: widget.videoUrl!,
          thumbnailUrl: widget.videoThumbnail!,
          author: widget.videoAuthor ?? 'Creator',
          title: _extractTitleFromClean(cleanText),
          createdAt: DateTime.now(),
          views: int.tryParse(_extractViewsFromText(widget.text) ?? '0') ?? 0,
        ),
      ),
    );
  }

  Widget _buildModernVideoPlayer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModernVideoBubble(
        videoPath: _currentVideoSource,
        thumbnailUrl: widget.videoThumbnail,
        isLocal: widget.image != null ||
            (_currentVideoSource != null &&
                !_currentVideoSource!.startsWith('http')),
      ),
    );
  }

  Widget _buildBottomActions() {
    // 🧠 Dynamic Action Compilation
    List<dynamic> effectiveActions = [];
    if (widget.actions != null && widget.actions!.isNotEmpty) {
      effectiveActions = List<dynamic>.from(widget.actions!);
    } else {
      effectiveActions = [
        {
          "label": "📊 تريندات جوجل",
          "action": "trend_search",
          "payload": widget.productContext
        },
        {
          "label": "🔎 بحث تيك توك",
          "action": "tiktok_link",
          "payload": widget.productContext
        },
        {
          "label": "📸 بحث انستقرام",
          "action": "instagram_link",
          "payload": widget.productContext
        },
        {
          "label": "🔍 بحث بصري (Lens)",
          "action": "visual_search",
          "payload": widget.productContext
        },
        {
          "label": "🛍️ بحث امازون",
          "action": "amazon_search",
          "payload": widget.productContext
        },
        {
          "label": "📦 استيراد علي بابا",
          "action": "alibaba_sourcing",
          "payload": widget.productContext
        },
        {
          "label": "✍️ وصف تسويقي ✨",
          "action": "generate_ad",
          "payload": widget.productContext
        },
        {
          "label": "✂️ إزالة الخلفية",
          "action": "remove_background",
          "payload": widget.productContext
        },
        {
          "label": "🎬 فيديو Kling AI 🚀",
          "action": "generate_kling_video",
          "payload": widget.productContext
        },
        {
          "label": "🎨 استوديو الصور 🖼️",
          "action": "generate_creative_image",
          "payload": widget.productContext
        },
        {
          "label": "🖼️ صور المنتج",
          "action": "google_images",
          "payload": widget.productContext
        },
        {
          "label": "📰 أخبار جوجل",
          "action": "google_news",
          "payload": widget.productContext
        },
        {
          "label": "🧠 فحص ذكي",
          "action": "bing_copilot",
          "payload": widget.productContext
        },
        {
          "label": "🎬 فيديوهات مشابهة",
          "action": "similar_videos",
          "payload": widget.productContext
        },
      ];
    }

    // ✂️ Inject Background Removal for any assistant message that has a direct image attached (like generated ones)
    final bool hasImage = widget.image != null ||
        widget.responseImageUrl != null ||
        widget.mediaPath != null;
    if (hasImage &&
        !effectiveActions.any((a) => a['action'] == 'remove_background')) {
      effectiveActions.insert(0, {
        "label": "✂️ إزالة الخلفية",
        "action": "remove_background",
        "payload": widget.productContext
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🛠️ Utility Bar (Copy + Action Hub Toggle)
        if (!widget.isUser &&
            (_displayText.isNotEmpty || effectiveActions.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 4, bottom: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 📋 Copy Button
                if (_displayText.isNotEmpty)
                  _buildGlassActionButton(
                    label: "نسخ",
                    icon: Icons.copy_rounded,
                    color: const Color(0xFF00FF88),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _displayText));
                      SnackBarUtils.showSuccess(
                          'تم النسخ', 'تم نسخ النص إلى الحافظة');
                    },
                  ),

                // 🪄 Action Hub Toggle (Permanently visible for Assistant)
                if (!widget.isUser && _displayText.isNotEmpty)
                  _buildGlassActionButton(
                    label: _isActionsExpanded
                        ? "إخفاء الأدوات"
                        : "الأدوات الذكية ⚡",
                    icon: _isActionsExpanded
                        ? Icons.close_rounded
                        : Icons.auto_awesome_rounded,
                    color: Colors.cyanAccent,
                    onTap: () => setState(
                        () => _isActionsExpanded = !_isActionsExpanded),
                  ),
              ],
            ),
          ),

        if (widget.recommendations != null &&
            widget.recommendations!.isNotEmpty)
          RecommendationPanel(
            recommendations: widget.recommendations!,
            onItemTap: (item) => _handleAction(
                item['action'] ?? 'search_trends', item['payload']),
          ),
        if (!widget.isUser)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isActionsExpanded
                ? _buildActionChips(effectiveActions)
                : const SizedBox.shrink(),
          ),
        if (widget.mediaActions != null && widget.mediaActions!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MediaActionBar(
              actions: widget.mediaActions!,
              onAction: (a) => _handleAction(a.id, a.payload),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyReference(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(
            right: BorderSide(
                color: widget.isUser ? Colors.white30 : const Color(0xFF00FF88),
                width: 3)),
      ),
      child: Text(
        widget.replyToContent!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12, color: widget.isUser ? Colors.white70 : Colors.grey),
      ),
    );
  }

  Widget _buildActionChips(List<dynamic> actions) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 16, right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 2, right: 4),
            child: Text(
              "الإجراءات الذكية 🧠",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final int crossAxisCount = FluidGridHelper.calculateColumns(
                constraints,
                150.0, // Targeted width for action buttons
                min: 2,
                max: 4,
              );

              return GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets
                    .zero, // 🚀 Eliminate default GridView top padding
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 28, // Height of each button
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  final label = action['label'] ?? 'Action';
                  final id = action['action'] ?? action['id'];
                  final color = _getActionColor(id);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleAction(id, action['payload']),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.15),
                              color.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getIconForAction(id),
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: color.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String? id) {
    switch (id) {
      case 'open_tiktok_search':
      case 'tiktok_link':
        return Colors.pinkAccent;
      case 'open_instagram_search':
      case 'instagram_link':
        return Colors.purpleAccent;
      case 'generate_ad':
        return const Color(0xFF00FF88);
      case 'generate_kling_video':
        return Colors.orangeAccent;
      case 'generate_creative_image':
        return Colors.cyanAccent;
      case 'analyze_instagram_reels':
        return Colors.blueAccent;
      case 'open_alibaba_search':
      case 'alibaba_sourcing':
        return const Color(0xFFFF5000); // Alibaba Orange
      case 'trend_search':
        return Colors.blueAccent;
      case 'visual_search':
      case 'google_lens':
        return Colors.yellowAccent;
      case 'amazon_search':
        return Colors.orange;
      case 'google_images':
        return Colors.lightBlueAccent;
      case 'google_news':
        return Colors.redAccent;
      case 'bing_copilot':
      case 'expert_research':
        return Colors.lightGreenAccent;
      case 'similar_videos':
        return Colors.deepOrangeAccent;
      default:
        return const Color(0xFF00FF88);
    }
  }

  void _handleAction(String id, dynamic payload) {
    if (Get.isRegistered<ChatSmartAgent>()) {
      Get.find<ChatSmartAgent>().handleAction(id, payload: payload);
    }
  }

  IconData _getIconForAction(String? action) {
    switch (action) {
      case 'open_tiktok_search':
      case 'tiktok_link':
        return Icons.video_collection_rounded;
      case 'open_instagram_search':
      case 'instagram_link':
        return Icons.camera_alt_rounded;
      case 'generate_ad':
        return Icons.campaign_rounded;
      case 'generate_kling_video':
        return Icons.auto_awesome_motion_rounded;
      case 'generate_creative_image':
        return Icons.brush_rounded;
      case 'analyze_instagram_reels':
        return Icons.analytics_rounded;
      case 'open_alibaba_search':
      case 'alibaba_sourcing':
        return Icons.inventory_2_rounded;
      case 'similar_videos':
        return Icons.play_circle_fill_rounded;
      case 'trend_search':
        return Icons.trending_up_rounded;
      case 'visual_search':
      case 'google_lens':
        return Icons.center_focus_strong_rounded;
      case 'amazon_search':
        return Icons.shopping_bag_rounded;
      case 'google_images':
        return Icons.image_search_rounded;
      case 'google_news':
        return Icons.newspaper_rounded;
      case 'bing_copilot':
      case 'expert_research':
        return Icons.psychology_rounded;
      case 'generate_hashtags':
        return Icons.tag_rounded;
      case 'copy_text':
        return Icons.copy_rounded;
      default:
        return Icons.ads_click_rounded;
    }
  }

  Widget _buildGlassActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isScenario(String text) =>
      text.contains("تحليل الفكرة") ||
      text.contains("Concept") ||
      text.contains("1️⃣");
  String _extractTitleFromClean(String cleanText) {
    final lines = cleanText.split('\n');
    return lines.length >= 2 ? lines[1].trim() : cleanText;
  }

  String? _extractViewsFromText(String text) {
    if (!text.contains('👁️')) return null;
    try {
      final parts = text.split('👁️');
      if (parts.length > 1) return parts[1].trim().split(' ').first;
    } catch (_) {}
    return null;
  }
}
