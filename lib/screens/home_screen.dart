import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:smart_content_creator/screens/ai_chat_screen.dart';
import 'package:smart_content_creator/controllers/chat_history_controller.dart';
import 'package:smart_content_creator/controllers/auth_controller.dart';
import 'package:smart_content_creator/controllers/theme_controller.dart';
import 'package:smart_content_creator/controllers/navigation_controller.dart';
import 'package:smart_content_creator/core/theme/animations/galactic_background_unified.dart';
import 'package:smart_content_creator/controllers/home_dashboard_controller.dart';
import 'package:smart_content_creator/widgets/permission_controlled_widget.dart';
import 'package:smart_content_creator/core/theme/ui_kit/smart_neon_button.dart';
import 'package:smart_content_creator/core/theme/ui_kit/smart_fluid_panel.dart';
import 'package:smart_content_creator/core/theme/ui_kit/smart_soft_icon.dart';
import 'package:smart_content_creator/core/theme/ui_kit/smart_bouncy_wrapper.dart';
import 'package:smart_content_creator/core/theme/ui_kit/smart_stat_box.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:smart_content_creator/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000), // Black base
        extendBodyBehindAppBar: true,
        drawer: const _VipDrawer(),
        appBar: _buildVipAppBar(context),
        body: Stack(
          children: [
            // 🌌 Animated Galactic Background
            const GalacticBackgroundUnified(),

            // 💎 Content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveBreakpoints.of(context).isMobile
                        ? 20.w
                        : 40.w,
                    vertical: 20.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌟 Welcome & Profile Summary
                      _buildWelcomeHeader(context),
                      SizedBox(height: 24.h),

                      // 🚀 Smart Actions Banner
                      const _VipSmartBanner(),
                      SizedBox(height: 24.h),

                      // 🤖 AI Smart Panel
                      const _AiSmartPanel(),
                      SizedBox(height: 24.h),

                      // 🛠️ Quick Tools Grid
                      const _QuickTools(),
                      SizedBox(height: 24.h),

                      // 📊 Stats Cards
                      const _Stats(),
                      SizedBox(height: 24.h),

                      // 🔥 Trending Now (New Phase 4)
                      const _TrendingNowSection(),
                      SizedBox(height: 24.h),

                      // 📰 Latest in AI & Tech (New Phase 4)
                      const _AIStackNewsSection(),
                      SizedBox(height: 24.h),

                      // 💬 Recent Temporal Chunks (Chats)
                      const _RecentChatsSection(),
                      SizedBox(height: 48.h),
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
      preferredSize: Size.fromHeight(70.h),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.1),
            elevation: 0,
            centerTitle: true,
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00FF88), Color(0xFF00FFEE)],
              ).createShader(bounds),
              child: Text(
                "صانع المحتوى الذكي",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18.sp,
                  fontFamily: 'IBMPlexSansArabic',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            leading: Builder(
              builder: (context) => IconButton(
                icon:
                    const Icon(Icons.menu_open_rounded, color: Colors.white70),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              Obx(() {
                final themeController = Get.find<ThemeController>();
                return IconButton(
                  icon: Icon(
                    themeController.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: themeController.isDarkMode
                        ? Colors.amber
                        : Colors.blueGrey,
                  ),
                  onPressed: () => themeController.toggleTheme(),
                );
              }),
              SizedBox(width: 8.w),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    final auth = Get.find<AuthController>();
    // 🛡️ التعديل هنا: استخدام دالة آمنة لاستخراج الاسم
    final userName = _safeExtractString(auth.user?['name']) ?? 
                     _safeExtractString(auth.user?['username']) ?? 
                     'المبدع الذكي';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "مرحباً بك، $userName ✨",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.w900,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          "لديك اليوم إمكانيات غير محدودة للإبداع.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14.sp,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
      ],
    );
  }
  
  // 🛡️ دالة مساعدة لاستخراج النصوص بأمان وتجنب خطأ Map
  String? _safeExtractString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      // إذا كانت القيمة خريطة، حاول استخراج النص
      return value['content']?.toString() ?? value['text']?.toString();
    }
    return value.toString();
  }
}

class _QuickTools extends StatelessWidget {
  const _QuickTools();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> models = [
      {
        'id': 'image_edit_auto',
        'title': 'تعديل الصور',
        'subtitle': 'AI Enhancement',
        'icon': LucideIcons.wand2,
        'color': const Color(0xFFFF9D00)
      },
      {
        'id': 'audio_spark',
        'title': 'أوديو سبارك',
        'subtitle': 'Voice Agents',
        'icon': LucideIcons.mic,
        'color': const Color(0xFF00D2FF)
      },
      {
        'id': 'movie',
        'title': 'تحريك الصور',
        'subtitle': 'Motion Veo',
        'icon': LucideIcons.video,
        'color': const Color(0xFFA64DFF)
      },
      {
        'id': 'image',
        'title': 'توليد الصور',
        'subtitle': 'Elite Generation',
        'icon': LucideIcons.image,
        'color': const Color(0xFFFF4D94)
      },
      {
        'id': 'video_spark',
        'title': 'فيديو سبارك',
        'subtitle': 'Prompt to Video',
        'icon': LucideIcons.playCircle,
        'color': const Color(0xFFFF3333)
      },
      {
        'id': 'bolt',
        'title': 'بيلت (Bolt)',
        'subtitle': 'Ultra Fast AI',
        'icon': LucideIcons.zap,
        'color': const Color(0xFFFFEE00)
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أدوات سريعة ⚡',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        SizedBox(height: 16.h),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: models.map((model) {
            final color = model['color'] as Color;
            return SmartBouncyWrapper(
              onTap: () => Get.to(() => AiChatScreen(initialMode: model['id'])),
              child: SmartFluidPanel(
                padding: EdgeInsets.all(12.r),
                borderRadius: 25.r,
                borderColor: color.withValues(alpha: 0.1),
                useGlow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SmartSoftIcon(
                      icon: model['icon'] as IconData,
                      color: color,
                      size: 24.r,
                      padding: 12.r,
                    ),
                    const Spacer(),
                    Text(
                      model['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      model['subtitle']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10.sp,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإحصائيات 📊',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: SmartStatBox(
                label: 'المشاريع النشطة',
                value: '12',
                icon: LucideIcons.folder,
                color: const Color(0xFF00FF88),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: SmartStatBox(
                label: 'الاستهلاك الشهري',
                value: '84%',
                icon: LucideIcons.activity,
                color: const Color(0xFF00FFEE),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentChatsSection extends StatelessWidget {
  const _RecentChatsSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatHistoryController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'النشاطات الأخيرة 🕒',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        const SizedBox(height: 20),
        Obx(() {
          if (controller.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF88)));
          }

          if (controller.sessions.isEmpty) {
            return _buildEmptyActivity(context);
          }

          final recentSessions = controller.sessions.take(3).toList();

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentSessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final session = recentSessions[index];
              // 🛡️ التعديل هنا: استخدام toString لتجنب خطأ Map في اسم الجلسة
              final title = session['title']?.toString() ?? 'محادثة ذكية';
              final dateStr = session['last_message_at']?.toString();
              final date =
                  dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.03),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  onTap: () {
                    controller.selectSession(session['id']);
                    Get.to(() => const AiChatScreen());
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_rounded,
                        color: Color(0xFF00FF88), size: 20),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${date.day}/${date.month} - ${date.hour}:${date.minute}",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white24, size: 14),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildEmptyActivity(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded,
              color: Colors.white.withValues(alpha: 0.1), size: 40),
          const SizedBox(height: 10),
          Text(
            "لا توجد محادثات سابقة.",
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
          ),
        ],
      ),
    );
  }
}



class _VipDrawer extends StatelessWidget {
  const _VipDrawer();

  // 🛡️ دالة مساعدة لاستخراج النصوص بأمان
  String _safeExtractString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      return value['url']?.toString() ?? value['path']?.toString() ?? value.toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final user = auth.user;
    final bool isAdmin = auth.isAdmin;
    final String roleLabel = isAdmin ? "مسؤول النظام 👑" : "مبدع محتوى VIP ✨";
    
    // 🛡️ التعديل هنا: استخدام الدالة الآمنة لاستخراج الروابط
    final String coverUrl = _safeExtractString(user?['cover_url']);
    final String photoUrl = _safeExtractString(user?['photo_url']);
    final String userName = _safeExtractString(user?['name']).isEmpty 
        ? (_safeExtractString(user?['username']).isEmpty ? 'المبدع VIP' : _safeExtractString(user?['username']))
        : _safeExtractString(user?['name']);

    return Drawer(
      backgroundColor: const Color(0xFF0D0D10),
      child: Column(
        children: [
          // 💎 Tier-1 VIP Drawer Header
          _buildVipDrawerHeader(context, userName, roleLabel, coverUrl, photoUrl),

          const SizedBox(height: 15),

          // 🛠️ Navigation Items
          _buildDrawerItem(
            Icons.psychology_rounded,
            "ملف ذكاء المبدع",
            () {
              Get.back(); // close drawer
              Get.find<NavigationController>().changePage(1);
            },
          ),
          _buildDrawerItem(
            Icons.settings_rounded,
            "الإعدادات العامة",
            () {
              Get.back();
              Get.find<NavigationController>().changePage(2);
            },
          ),

          VisibilityControlled(
            controlName: 'admin_dashboard_screen',
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Divider(color: Colors.white10),
                ),
                _buildDrawerItem(
                  Icons.admin_panel_settings_rounded,
                  "لوحة المسؤول",
                  () => Get.toNamed('/admin'),
                  color: const Color(0xFF00E5FF),
                ),
              ],
            ),
          ),

          const Spacer(),
          const Divider(color: Colors.white10),

          // 🚪 Logout
          _buildDrawerItem(
            Icons.logout_rounded,
            "تسجيل الخروج",
            () => auth.logout(),
            color: Colors.redAccent.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildVipDrawerHeader(BuildContext context, String userName,
      String role, String coverUrl, String photoUrl) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        children: [
          // 🖼️ Ground/Cover Image
          Positioned.fill(
            child: coverUrl.isNotEmpty
                ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildFallbackCover())
                : _buildFallbackCover(),
          ),

          // 🌫️ Premium Blur & Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0D0D10).withValues(alpha: 0.5),
                    const Color(0xFF0D0D10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 👤 User Branding Section
          Positioned(
            left: 20,
            right: 20,
            bottom: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🧔 VIP Avatar with Orbit Glow
                Container(
                  padding: const EdgeInsets.all(2.5),
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
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF0A0A0E),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    onBackgroundImageError: photoUrl.isNotEmpty ? (e, s) {} : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person_rounded,
                            size: 42, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // 📝 Identity
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
                const SizedBox(height: 6),

                // 🏷️ Role Neon Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD486).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2DD486).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Color(0xFF2DD486),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IBMPlexSansArabic',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E26), Color(0xFF0D0D10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_rounded,
          size: 100,
          color: Colors.white.withValues(alpha: 0.03),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? Colors.white70, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Colors.white10),
        onTap: onTap,
      ),
    );
  }
}

class _TrendingNowSection extends StatelessWidget {
  const _TrendingNowSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeDashboardController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'تريندات اليوم 🔥',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
            TextButton(
              onPressed: () => controller.refreshDashboard(),
              child: const Text("تحديث", style: TextStyle(color: Color(0xFF00FF88))),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 60,
          child: Obx(() {
            if (controller.isLoading.value && controller.trendingItems.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2));
            }
            if (controller.trendingItems.isEmpty) return const Text("لا توجد تريندات حالياً", style: TextStyle(color: Colors.white24));

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.trendingItems.length,
              itemBuilder: (context, index) {
                final item = controller.trendingItems[index];
                return _buildTrendCard(item);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTrendCard(Map<String, dynamic> item) {
    // 🛡️ التعديل هنا: استخدام toString لتجنب خطأ Map
    final title = item['query']?.toString() ?? 'تريند';
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, color: Color(0xFF00FF88), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🤖 _AiSmartPanel - A dedicated panel for AI interactions.
class _AiSmartPanel extends StatelessWidget {
  const _AiSmartPanel();

  @override
  Widget build(BuildContext context) {
    return SmartFluidPanel(
      padding: EdgeInsets.all(24.r),
      borderRadius: 32.r,
      useBlur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SmartSoftIcon(
                icon: LucideIcons.sparkles,
                color: Color(0xFF00FF88),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  "الذكاء الإصطناعي ✨",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            "حوّل أفكارك إلى واقع ترفيهي رقمي من الطراز الرفيع باستخدام محركات الجيل القادم.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              height: 1.6,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
          SizedBox(height: 20.h),
          SmartNeonButton(
            text: "ابدأ المحادثة الآن",
            onPressed: () => Get.find<NavigationController>().changePage(1),
            gradientColors: const [Color(0xFF00FF88), Color(0xFF00FFEE)],
            shadowColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
            borderRadius: 50.r,
          ),
        ],
      ),
    );
  }
}

/// 🚀 _VipSmartBanner - A premium promotional banner following the Soft UI system.
class _VipSmartBanner extends StatelessWidget {
  const _VipSmartBanner();

  @override
  Widget build(BuildContext context) {
    return SmartFluidPanel(
      padding: EdgeInsets.zero,
      borderRadius: 30.r,
      useBlur: true,
      child: Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.r),
          gradient: AppTheme.cardGradient,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ترقية الحساب إلى VIP Pro 🚀",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "احصل على وصول غير محدود لجميع أدوات الذكاء الاصطناعي المتطورة.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.sp,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: 140.w,
                    child: SmartNeonButton(
                      text: "اشترك الآن",
                      height: 42.h,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SmartSoftIcon(
              icon: LucideIcons.crown,
              color: Color(0xFFFFD700),
              size: 32,
              padding: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _AIStackNewsSection extends StatelessWidget {
  const _AIStackNewsSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeDashboardController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أخبار الذكاء الاصطناعي 📰',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        const SizedBox(height: 20),
        Obx(() {
          if (controller.isLoading.value && controller.newsItems.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFEE), strokeWidth: 2));
          }
          if (controller.newsItems.isEmpty) return const Text("لا توجد أخبار حالياً", style: TextStyle(color: Colors.white24));

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.newsItems.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              final item = controller.newsItems[index];
              return _buildNewsCard(item);
            },
          );
        }),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> item) {
    // 🛡️ التعديل هنا: استخدام toString لتجنب خطأ Map
    final source = item['source']?.toString() ?? 'AI News';
    final date = item['date']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFEE).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF00FFEE), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
