import 'dart:io';
import 'dart:ui'; // For ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/chat_history_controller.dart';
import '../theme/app_theme.dart';
import 'permission_controlled_widget.dart';

import '../controllers/auth_controller.dart';
import '../ai/chat_smart_agent.dart';

import 'package:flutter/services.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatHistoryController>();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // 💎 VIP Glassmorphism Design
    return Drawer(
      backgroundColor: Colors.transparent, // Important for blur
      elevation: 0,
      width: MediaQuery.of(context).size.width *
          (isLandscape ? 0.65 : 0.85), // Adaptive width
      child: Stack(
        children: [
          // 1. Blur Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      Colors.black.withValues(alpha: 0.85), // Deep dark glass
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 📏 التحقق من المساحة المتاحة (وضع Portrait غالباً ما يوفر مساحة > 600)
                final hasEnoughSpace = constraints.maxHeight > 600;

                // 🏗️ الجزء العلوي (Header + Action Button + Title)
                final topSection = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVipHeader(isLandscape),
                    if (!isLandscape) const SizedBox(height: 20),
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
                    SizedBox(height: isLandscape ? 10 : 20),
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
                                  onPressed: () =>
                                      _confirmDeleteAll(controller),
                                  icon: const Icon(Icons.delete_sweep_rounded,
                                      size: 18),
                                  color: Colors.redAccent.withValues(alpha: 0.8),
                                  padding: const EdgeInsets.only(left: 8),
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                )
                              : const SizedBox.shrink()),
                          Icon(Icons.history,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );

                // 📜 دالة بناء القائمة (لتجنب التكرار)
                Widget buildHistoryList({required bool scrollable}) {
                  return Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary));
                    }
                    if (controller.sessions.isEmpty) {
                      return _buildEmptyState(controller);
                    }
                    final itemCount = controller.sessions.length + (controller.canMigrate.value ? 1 : 0);
                    
                    return ListView.builder(
                      shrinkWrap: !scrollable,
                      physics: scrollable
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        // إذا وصلنا لآخر عنصر وكان هناك حاجة للاستعادة
                        if (index == controller.sessions.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 20),
                            child: _buildVipActionButton(
                              icon: Icons.auto_fix_high_rounded,
                              label: 'استعادة المحادثات القديمة',
                              color: Colors.amber,
                              onTap: () => controller.migrateLegacySessions(),
                            ),
                          );
                        }

                        final session = controller.sessions[index];
                        return _buildRichHistoryCard(context, controller, session);
                      },
                    );
                  });
                }

                // 🚀 الحالة 1: مساحة كافية (Portrait) -> Expanded للأداء العالي
                if (hasEnoughSpace) {
                  return Column(
                    children: [
                      topSection,
                      Expanded(child: buildHistoryList(scrollable: true)),
                      _buildCatalogButton(),
                      _buildAdminButton(),
                      // تم نقل الفوتر إلى الملف الشخصي
                    ],
                  );
                }

                // 🚀 الحالة 2: مساحة ضيقة (Landscape) -> الكل قابل للتمرير لتجنب Overflow
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      topSection,
                      buildHistoryList(scrollable: false),
                      _buildCatalogButton(),
                      _buildAdminButton(),
                      // تم نقل الفوتر إلى الملف الشخصي
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipHeader(bool isLandscape) {
    final auth = Get.find<AuthController>();
    final user = auth.user;
    final userName = user?['name'] ?? 'مبدع SMART';
    final userEmail = auth.userEmail ?? '';
    final userPhoto = user?['photo_url'] ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.toNamed('/creator-profile'),
        splashColor: AppTheme.primary.withValues(alpha: 0.1),
        highlightColor: AppTheme.primary.withValues(alpha: 0.05),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, isLandscape ? 20 : 60, 20, 20),
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
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black,
                  backgroundImage: userPhoto.isNotEmpty
                      ? (userPhoto.startsWith('http')
                          ? NetworkImage(userPhoto)
                          : FileImage(File(userPhoto)) as ImageProvider)
                      : const AssetImage('assets/images/styles/logoapp.jpeg'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          onTap: () {
            HapticFeedback.lightImpact();
            controller.selectSession(session['id']);
            // إغلاق القائمة الجانبية فوراً عند الضغط
            Get.back();
          },
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
      confirmTextColor: const Color.fromARGB(255, 8, 227, 19),
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

  // 🛍️ زر كتالوج المنتجات لـ Meta
  Widget _buildCatalogButton() {
    return PermissionControlledWidget(
      controlName: 'catalog_screen',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1877F2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF1877F2).withValues(alpha: 0.3), width: 1),
        ),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.shopping_bag_rounded,
              color: Color(0xFF1877F2), size: 22),
          title: const Text(
            'كتالوج Meta',
            style: TextStyle(
              color: Color(0xFF1877F2),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded,
              color: Color(0xFF1877F2), size: 12),
          onTap: () {
            Get.back();
            Get.toNamed('/catalog');
          },
        ),
      ),
    );
  }

  // 🛡️ زر لوحة التحكم للمسؤولين فقط
  Widget _buildAdminButton() {
    final auth = Get.find<AuthController>();
    // التحقق من الصلاحية
    if (auth.user?['role'] != 'admin' && auth.user?['firestore_role'] != 'admin') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent, size: 22),
        title: const Text(
          'لوحة الإدارة',
          style: TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amberAccent, size: 12),
        onTap: () {
          Get.back(); // إغلاق الدرج
          Get.toNamed('/admin');
        },
      ),
    );
  }
}
