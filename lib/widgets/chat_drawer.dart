import 'dart:io';
import 'dart:ui'; // For ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/chat_history_controller.dart';
import '../theme/app_theme.dart';
import '../screens/creator_profile_screen.dart';
import '../screens/media_merge_screen.dart';

import '../controllers/auth_controller.dart';
import '../screens/home_screen.dart';
import '../widgets/permission_controlled_widget.dart';
import '../ai/chat_smart_agent.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatHistoryController>();

    // 💎 VIP Glassmorphism Design
    return Drawer(
      backgroundColor: Colors.transparent, // Important for blur
      elevation: 0,
      width:
          MediaQuery.of(context).size.width * 0.85, // Slightly wider for luxury
      child: Stack(
        children: [
          // 1. Blur Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85), // Deep dark glass
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                _buildVipHeader(),
                const SizedBox(height: 20),

                // 🌟 New Chat Action (Prominent)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildVipActionButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'محادثة جديدة',
                    color: AppTheme.primary,
                    onTap: () {
                      if (Get.isRegistered<ChatSmartAgent>()) {
                        Get.find<ChatSmartAgent>().forceClearHistory();
                      }
                      controller.startNewChat();
                    },
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        "سجل الإبداع",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                      const Spacer(),
                      Obx(() => controller.sessions.isNotEmpty
                          ? IconButton(
                              onPressed: () => _confirmDeleteAll(controller),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              padding: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            )
                          : const SizedBox.shrink()),
                      Icon(Icons.history,
                          size: 16, color: Colors.white.withValues(alpha: 0.5)),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 📜 Scrollable History List
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: AppTheme.primary));
                    }

                    if (controller.sessions.isEmpty) {
                      return _buildEmptyState(controller);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: controller.sessions.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final session = controller.sessions[index];
                        // 🎭 Staggered Animation Logic
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds: 400 +
                                  (index * 100).clamp(0, 1000)), // Cascade effect
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 50 * (1 - value)), // Slide up
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child:
                              _buildRichHistoryCard(context, controller, session),
                        );
                      },
                    );
                  }),
                ),

                // Footer Actions
                _buildVipFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.black,
              backgroundImage: AssetImage('assets/images/logoapp.jpg'),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Smart Content',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Creator Pro',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVipActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 💎 Rich History Card Implementation
  Widget _buildRichHistoryCard(BuildContext context,
      ChatHistoryController controller, Map<String, dynamic> session) {
    final isSelected = controller.currentSessionId.value == session['id'];
    final imagePath =
        session['image_path'] as String?; // Fetched from DB subquery
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.selectSession(session['id']),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.05),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // 1. Thumbnail (Image or Icon)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(20)), // RTL Support (right side)
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: hasImage
                        ? Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholderIcon(isSelected),
                          )
                        : Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: _buildPlaceholderIcon(isSelected),
                          ),
                  ),
                ),

                // 2. Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          session['title'] ?? 'بدون عنوان',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(session['last_message_at']),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Actions / Indicator
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: Colors.white.withValues(alpha: 0.3)),
                      color: const Color(0xFF2C2C2C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) => _handleMenuAction(
                          context, controller, session, value),
                      itemBuilder: (context) => [
                        _buildMenuItem('share', Icons.share_rounded, 'مشاركة',
                            Colors.green),
                        _buildMenuItem(
                            'rename', Icons.edit, 'إعادة تسمية', Colors.blue),
                        _buildMenuItem(
                            'delete', Icons.delete_outline, 'حذف', Colors.red),
                      ],
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 12),
                        child: Icon(Icons.check_circle,
                            color: AppTheme.primary, size: 16),
                      )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(bool isSelected) {
    return Center(
      child: Icon(
        Icons.chat_bubble_outline_rounded,
        color:
            isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.2),
        size: 28,
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      String value, IconData icon, String text, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'IBMPlexSansArabic')),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, ChatHistoryController controller,
      Map<String, dynamic> session, String value) async {
    if (value == 'share') {
      await SharePlus.instance.share(
        ShareParams(
          text: "محادثة: ${session['title']}\n\nتم إنشاؤها بواسطة Smart Content Creator 🚀",
        ),
      );
    } else if (value == 'rename') {
      _showRenameDialog(context, controller, session['id'], session['title']);
    } else if (value == 'delete') {
      _confirmDelete(controller, session['id']);
    }
  }

  Widget _buildEmptyState(ChatHistoryController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 48, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'ابدأ رحلة الإبداع الآن! ✨',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'IBMPlexSansArabic'),
            ),
            if (controller.canMigrate.value) ...[
              const SizedBox(height: 24),
              _buildVipActionButton(
                icon: Icons.auto_fix_high_rounded,
                label: 'استعادة المحادثات',
                color: Colors.amber,
                onTap: () => controller.migrateLegacySessions(),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildVipFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        children: [
          _buildFooterItem(
            icon: Icons.dashboard_outlined,
            text: 'استوديو الإبداع',
            onTap: () => Get.offAll(() => const HomeScreen()),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(Icons.build_circle_outlined, color: Colors.blueAccent.withValues(alpha: 0.8), size: 20),
              title: Text(
                'أدوات  ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              iconColor: Colors.amberAccent,
              collapsedIconColor: Colors.white70,
              childrenPadding: const EdgeInsets.only(right: 16),
              children: [
                VisibilityControlled(
                  controlName: 'settings_screen',
                  child: _buildFooterItem(
                    icon: Icons.settings_outlined,
                    text: 'الإعدادات العامة',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed('/settings');
                    },
                  ),
                ),
                VisibilityControlled(
                  controlName: 'api_settings_screen',
                  child: _buildFooterItem(
                    icon: Icons.key_outlined,
                    text: 'إعدادات المفاتيح (API)',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed('/api-settings');
                    },
                  ),
                ),
                VisibilityControlled(
                  controlName: 'admin_dashboard_screen',
                  child: _buildFooterItem(
                    icon: Icons.admin_panel_settings_outlined,
                    text: 'لوحة التحكم (Admin)',
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed('/admin');
                    },
                  ),
                ),
                VisibilityControlled(
                  controlName: 'creator_profile_screen',
                  child: _buildFooterItem(
                    icon: Icons.psychology_outlined,
                    text: 'ملف المبدع 🧠',
                    onTap: () {
                      Navigator.pop(context);
                      Get.to(() => const CreatorProfileScreen());
                    },
                  ),
                ),
                _buildFooterItem(
                  icon: Icons.merge_type_rounded,
                  text: '🎬 دمج المنتج',
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => const MediaMergeScreen());
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          _buildFooterItem(
            icon: Icons.logout,
            text: 'تسجيل خروج',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem(
      {required IconData icon,
      required String text,
      required VoidCallback onTap,
      Color? color}) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: color ?? Colors.white.withValues(alpha: 0.7), size: 20),
      title: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'IBMPlexSansArabic',
        ),
      ),
      onTap: onTap,
    );
  }

  // Helpers (Keep existing logic but refine visuals if needed)
  void _showRenameDialog(BuildContext context, ChatHistoryController controller,
      int id, String? currentTitle) {
    final textCtrl = TextEditingController(text: currentTitle ?? "");
    Get.defaultDialog(
      title: "إعادة تسمية",
      titleStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: textCtrl,
          decoration: const InputDecoration(hintText: "عنوان المحادثة الجديد"),
          autofocus: true,
        ),
      ),
      textConfirm: "حفظ",
      textCancel: "إلغاء",
      confirmTextColor: Colors.white,
      onConfirm: () {
        if (textCtrl.text.trim().isNotEmpty) {
          controller.renameSession(id, textCtrl.text.trim());
        }
        Get.back();
      },
    );
  }

  void _confirmDelete(ChatHistoryController controller, int id) {
    Get.defaultDialog(
        title: "حذف المحادثة",
        titleStyle: const TextStyle(
            fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
        middleText: "هل أنت متأكد من حذف هذه المحادثة نهائياً؟",
        textConfirm: "حذف",
        textCancel: "إلغاء",
        confirmTextColor: Colors.white,
        buttonColor: Colors.red,
        onConfirm: () {
          controller.deleteSession(id);
          Get.back();
        });
  }

  void _confirmDeleteAll(ChatHistoryController controller) {
    Get.defaultDialog(
        title: "مسح جميع الدردشة",
        titleStyle: const TextStyle(
            fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
        middleText: "هل أنت متأكد من مسح جميع المحادثات نهائياً؟ هذا الإجراء لا يمكن التراجع عنه.",
        textConfirm: "مسح الكل",
        textCancel: "إلغاء",
        confirmTextColor: Colors.white,
        buttonColor: Colors.red,
        onConfirm: () {
          controller.deleteAllSessions();
          if (Get.isRegistered<ChatSmartAgent>()) {
            Get.find<ChatSmartAgent>().forceClearHistory();
          }
          Get.back();
        });
  }

  void _confirmLogout(BuildContext context) {
    Get.defaultDialog(
        title: "تسجيل الخروج",
        titleStyle: const TextStyle(
            fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
        middleText: "هل أنت متأكد أنك تريد تسجيل الخروج؟",
        textConfirm: "نعم، خروج",
        textCancel: "إلغاء",
        confirmTextColor: Colors.white,
        buttonColor: Colors.red,
        onConfirm: () {
          Get.find<AuthController>().logout();
          Get.back();
        });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) {
        return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} أيام';
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (e) {
      return '';
    }
  }
}
