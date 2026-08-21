import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/models/chat_message.dart'; // Using central ChatMessage
import 'context_preview_bar.dart';
import '../../ai/core/agent_models.dart'; // 🧬 Needed for SuggestedAction
import '../../controllers/settings_controller.dart';
import '../../services/ai_backend_router.dart';
import '../../core/utils/snackbar_utils.dart';

/// 💬 Chat Input Area - Complete input section for chat
///
/// Includes TextField, send button, attachment menu, and media preview
class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final RxBool isLoading;
  final List<File>? selectedImages; // 📸 New: Multiple images
  final File? selectedVideo;
  final bool isCompressingImage;
  final double processingProgress;

  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onClearVideo;
  final Function(int)? onRemoveImage; // 📸 New: Remove specific image
  final ChatMessage? replyingToMessage; // 🔗 الرسالة الجاري الرد عليها
  final VoidCallback? onClearReply; // 🧹 مسح الرد

  final String? productContext;
  final VoidCallback? onClearContext;

  final List<SuggestedAction>? smartActions; // 🧠 New: Smart Actions from AI
  final Function(SuggestedAction)? onActionTap; // ⚡ Action Handler
  final VoidCallback? onAudioEnhance; // 🎵 AI Audio Enhancement Trigger

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onCancel,
    required this.onShowAttachmentMenu,
    required this.onClearVideo,
    this.onRemoveImage,
    this.selectedImages,
    this.selectedVideo,
    this.isCompressingImage = false,
    this.processingProgress = 0.0,
    this.replyingToMessage,
    this.onClearReply,
    this.productContext,
    this.onClearContext,
    this.smartActions,
    this.onActionTap,
    this.onAudioEnhance,
  });

  @override
  Widget build(BuildContext context) {
    // 🛠️ ضمان استقرار الواجهة قبل الرسم (تغطية للـ Frame Drops)
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // استقرار شجرة الودجت وتفادي الـ Layout Assertions
    });

    final settings = Get.find<SettingsController>();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Container(
        // 💎 المنصة العائمة (Floating Dock)
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
        boxShadow: [
          // Aura Glow (توهج هادئ)
          BoxShadow(
            color: const Color(0xFF00FF88).withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: const Color(0xFF0F1117).withValues(alpha: 0.8),
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔗 الرد (إذا وجد) مدمج بشكل أنيق
                  if (replyingToMessage != null) _buildReplyPreview(),
  
                  // 🎯 [Quick Selector Row] - Removed from top, now inside bar
                  // _buildQuickSelectorRow(),
  
                  // 🧠 Smart Actions (Removed to reduce clutter)
                  // AnimatedSwitcher removed per user request
  
                  // 🧊 Context Preview & Media Preview
                  if (productContext != null && productContext!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ContextPreviewBar(
                        productName: productContext,
                        onClose: onClearContext ?? () {},
                      ),
                    ),
  
                  if ((selectedImages != null && selectedImages!.isNotEmpty) || selectedVideo != null)
                    _buildMediaStrip(),
  
                   // --- 🚀 Official Gemini Style Unified Bar ---
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1F23), // 🌑 Deep Dark Gray
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        // 1. Add (+) Button
                        IconButton(
                          onPressed: onShowAttachmentMenu,
                          icon: const Icon(Icons.add_rounded,
                              color: Colors.white70, size: 28),
                        ),
  
                        const SizedBox(width: 4),
  
                        // 2. Main Input
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLines: 5,
                            minLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                            decoration: InputDecoration(
                              hintText: _getGeminiHint(),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.1),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
  
                        const SizedBox(width: 8),
  
                        // Action Group: Model Chip + Mic/Send
                        _buildGoogleActionGroup(settings),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMediaStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (selectedImages != null && selectedImages!.isNotEmpty)
              ...selectedImages!.asMap().entries.map((entry) {
                final int index = entry.key;
                final File img = entry.value;
                return _buildMediaMiniPreview(
                  label: 'صورة',
                  icon: Icons.image_rounded,
                  onClear: () => onRemoveImage?.call(index),
                  imageFile: img,
                );
              }),
            if (selectedVideo != null)
              Row(
                children: [
                   _buildMediaMiniPreview(
                    label: 'فيديو',
                    icon: Icons.movie_filter_rounded,
                    onClear: onClearVideo,
                    imageFile: selectedVideo,
                  ),
                  if (onAudioEnhance != null)
                   Padding(
                     padding: const EdgeInsets.only(left: 8),
                     child: _buildAudioEnhanceButton(),
                   ),
                ],
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00FF88).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              color: const Color(0xFF00FF88).withValues(alpha: 0.5), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _cleanPreview(replyingToMessage?.content ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ),
          GestureDetector(
            onTap: onClearReply,
            child: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 12),
          ),
        ],
      ),
    );
  }

  String _cleanPreview(String text) {
    return text.replaceAll('✨ تم :', '').replaceAll('✨ تم :', '').trim();
  }


  Widget _buildMediaMiniPreview({
    required String label,
    required IconData icon,
    required VoidCallback onClear,
    File? imageFile,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 🖼️ التوهج الخلفي للميديا
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
          ),

          // Image thumbnail or icon with glass border
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              image: (imageFile != null && imageFile.path.isNotEmpty)
                  ? DecorationImage(
                      image: ResizeImage(
                        FileImage(imageFile),
                        width: 150,
                        height: 150,
                      ),
                      fit: BoxFit.cover,
                      colorFilter: isCompressingImage
                          ? ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.5),
                              BlendMode.darken,
                            )
                          : null,
                    )
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: imageFile == null
                ? Center(
                    child: Icon(icon, size: 28, color: const Color(0xFF00FF88)),
                  )
                : null,
          ),

          // Progress overlay (Pulsing style)
          if (label == 'صورة' && isCompressingImage)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: processingProgress,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF88)),
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ),

          // ❌ Close button VIP Style
          Positioned(
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A22),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4)
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAudioEnhanceButton() {
    return GestureDetector(
      onTap: onAudioEnhance,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6200EE), Color(0xFF03DAC6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6200EE).withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_fix_high, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                "تحسين تلقائي 🎵",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🎯 Google Gemini UI Helper Methods ---


  Widget _buildGoogleActionGroup(SettingsController settings) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final hasText = value.text.isNotEmpty;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🧠 Gemini Style Model Selector Chip
            Flexible(child: _buildGeminiModelChip(settings)),

            const SizedBox(width: 8),

            // 🎙️ Send/Mic/3D or STOP Button
            Obx(() {
              final loading = isLoading.value;
              return GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (loading) {
                    onCancel();
                  } else {
                    onSend();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: loading
                        ? const LinearGradient(
                            colors: [Colors.redAccent, Color(0xFFFF5252)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : (selectedImages != null && selectedImages!.length >= 3)
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold / Orange
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                    color: loading
                        ? null
                        : (selectedImages != null && selectedImages!.length >= 3)
                            ? null
                            : (hasText || (selectedImages != null && selectedImages!.isNotEmpty) || selectedVideo != null)
                                ? const Color(0xFF2DD486) // Metallic Green
                                : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    boxShadow: (loading || hasText || (selectedImages != null && selectedImages!.isNotEmpty) || selectedVideo != null)
                        ? [
                            BoxShadow(
                              color: loading
                                  ? Colors.redAccent.withValues(alpha: 0.4)
                                  : (selectedImages != null && selectedImages!.length >= 3)
                                      ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                                      : const Color(0xFF2DD486).withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    loading
                        ? Icons.stop_rounded
                        : (selectedImages != null && selectedImages!.length >= 3)
                            ? Icons.view_in_ar_rounded // 3D Icon
                            : (hasText || (selectedImages != null && selectedImages!.isNotEmpty) || selectedVideo != null)
                                ? Icons.arrow_upward_rounded
                                : Icons.mic_rounded,
                    color: (loading || hasText || (selectedImages != null && selectedImages!.isNotEmpty) || selectedVideo != null)
                        ? Colors.black
                        : Colors.white,
                    size: 20,
                  ),
                ),
              );
            }),

          ],
        );
      },
    );
  }

  Widget _buildGeminiModelChip(SettingsController settings) {
    final aiRouter = Get.isRegistered<AIBackendRouter>()
        ? Get.find<AIBackendRouter>()
        : null;

    if (aiRouter == null) return const SizedBox.shrink();

    return Obx(() {
      final isFirebase = aiRouter.currentBackend.value == 'firebase_ai';
      final chipColor = isFirebase ? const Color(0xFF8B5CF6) : const Color(0xFF00E5FF);

      return GestureDetector(
        onTap: () => _showModelSwitcherSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  isFirebase ? "Firebase AI 🟣" : "Back4App ☁️",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: chipColor,
                size: 14,
              ),
            ],
          ),
        ),
      );
    });
  }

  String _getGeminiHint() {
    final router = Get.isRegistered<AIBackendRouter>()
        ? Get.find<AIBackendRouter>()
        : null;
    final isFirebase = router?.currentBackend.value == 'firebase_ai';
    return isFirebase ? "اسأل Firebase AI..." : "اسأل Back4App Gateway...";
  }

  void _showModelSwitcherSheet() {
    final aiRouter = Get.isRegistered<AIBackendRouter>()
        ? Get.find<AIBackendRouter>()
        : Get.put(AIBackendRouter());

    Get.bottomSheet(
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: Get.height * 0.8,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D10).withValues(alpha: 0.95), // 🌑 Premium Space
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      "اختر محرك الذكاء الاصطناعي 🧠",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ),

                  // 1. Firebase AI Logic (Gemini SDK)
                  Obx(() => _buildBackendMenuItem(
                    label: "Firebase AI Logic (Vertex) 🟣",
                    sublabel: "smart ai",
                    icon: Icons.auto_awesome_rounded,
                    backendKey: 'firebase_ai',
                    aiRouter: aiRouter,
                  )),

                  // 2. Back4App Gateway (Multi-Key)
                  Obx(() => _buildBackendMenuItem(
                    label: "Back4App Gateway ☁️",
                    sublabel: "بوابة ai )",
                    icon: Icons.hub_rounded,
                    backendKey: 'backend',
                    aiRouter: aiRouter,
                  )),

                  const Divider(color: Colors.white10, height: 30),

                  // 3. Status Info Box
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          aiRouter.currentBackend.value == 'firebase_ai'
                              ? Icons.verified_rounded
                              : Icons.cloud_sync_rounded,
                          color: aiRouter.currentBackend.value == 'firebase_ai'
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF00E5FF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            aiRouter.currentBackend.value == 'firebase_ai'
                                ? "المحرك النشط الآن: Firebase AI Logic SDK"
                                : "المحرك النشط الآن: Back4App Cloud Proxy",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'IBMPlexSansArabic',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildBackendMenuItem({
    required String label,
    required String sublabel,
    required IconData icon,
    required String backendKey,
    required AIBackendRouter aiRouter,
  }) {
    final bool isSelected = aiRouter.currentBackend.value == backendKey;
    final accentColor = backendKey == 'firebase_ai'
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? accentColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        onTap: () {
          aiRouter.switchBackend(backendKey);
          Get.back();
          SnackBarUtils.showSuccess(
            "تم تبديل المحرك",
            backendKey == 'firebase_ai'
                ? "تم التبديل إلى Firebase AI Logic 🟣"
                : "تم التبديل إلى Back4App Gateway ☁️",
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        subtitle: Text(
          sublabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isSelected ? 0.75 : 0.4),
            fontSize: 11,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: accentColor, size: 22)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }


}
