import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/animations/galactic_background_unified.dart';
import '../core/theme/ui_kit/smart_stat_box.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/responsive_helper.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Get.put as a safety fallback if the controller isn't registered globally
    final adminController = Get.isRegistered<AdminController>()
        ? Get.find<AdminController>()
        : Get.put(AdminController());
    final authController = Get.find<AuthController>();

    // Check if user is admin
    if (!authController.isAdmin) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded,
                    color: Colors.redAccent, size: 80),
                const SizedBox(height: 16),
                Text(
                  'غير مصرح لك بالدخول',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ليس لديك صلاحيات للوصول إلى هذه الشاشة',
                  style: GoogleFonts.cairo(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        extendBodyBehindAppBar: true,
        appBar: _buildVipAppBar(context, adminController),
        body: Stack(
          children: [
            // 🌌 Animated Galactic Background
            const Positioned.fill(child: GalacticBackgroundUnified()),

            // 💎 Content
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isDesktop = constraints.maxWidth > 900;

                    return Obx(() {
                      if (adminController.isLoading.value) {
                        return const Center(
                          child:
                              CircularProgressIndicator(color: AppTheme.primary),
                        );
                      }

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildAdminHeader(context, authController),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.list_alt_rounded,
                                    color: Colors.white30, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'قائمة المستخدمين',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white30,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (adminController.hasNewUsers.value)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "مستخدمين جدد!",
                                      style: GoogleFonts.cairo(
                                          color: Colors.greenAccent,
                                          fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // 📊 Stats Dashboard (Mobile only, Desktop has it in the panel)
                        if (!isDesktop)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: _buildStatsRow(adminController),
                            ),
                          ),

                        // 🧔 Users List
                        isDesktop
                            ? SliverFillRemaining(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildUsersPanel(
                                          context, adminController,
                                          isMobile: false),
                                    ),
                                    const VerticalDivider(
                                      width: 1,
                                      color: Colors.white10,
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: _buildPermissionsPanel(
                                          context, adminController),
                                    ),
                                  ],
                                ),
                              )
                            : SliverPadding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 40),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final user = adminController.users[index];
                                      return _buildUserTile(context,
                                          adminController, user, false, true);
                                    },
                                    childCount: adminController.users.length,
                                  ),
                                ),
                              ),
                        ],
                      );
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildVipAppBar(
      BuildContext context, AdminController adminController) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.2),
            elevation: 0,
            centerTitle: true,
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00FF88), Color(0xFF00FFEE)],
              ).createShader(bounds),
              child: Text(
                'لوحة التحكم العليا 👑',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            foregroundColor: Colors.white,
            actions: [
              Obx(() => adminController.hasNewUsers.value
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.fiber_new,
                          color: Colors.greenAccent, size: 30),
                    )
                  : const SizedBox.shrink()),
              Obx(() => !adminController.isConfigValid.value
                  ? IconButton(
                      icon: const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent),
                      onPressed: () => _confirmAction(
                        title: 'تهيئة الإعدادات؟',
                        message:
                            'يبدو أن إعدادات النظام مفقودة من Firestore. هل تريد إنشاء القيم الافتراضية؟',
                        onConfirm: () =>
                            adminController.initializeGlobalConfig(),
                      ),
                      tooltip: 'إعدادات النظام مفقودة',
                    )
                  : const SizedBox.shrink()),
              IconButton(
                icon: const Icon(Icons.psychology_alt_rounded,
                    color: Colors.purpleAccent),
                onPressed: () =>
                    _showGlobalAiSettings(context, adminController),
                tooltip: 'إعدادات AI العالمية',
              ),
              IconButton(
                icon: const Icon(Icons.cloud_sync_rounded,
                    color: Colors.cyanAccent),
                onPressed: () => adminController.syncModifiedPermissions(),
                tooltip: 'مزامنة مع السحابة',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: () => adminController.loadData(),
                tooltip: 'تحديث البيانات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminHeader(BuildContext context, AuthController auth) {
    final user = auth.user;
    final String photoUrl = (user?['photo_url'] ?? '').toString();
    final String coverUrl = (user?['cover_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.all(16),
      height: context.isSmallDevice ? 120 : 140, // 📏 Responsive height
      width: double.infinity,
      child: Stack(
        children: [
          // 🖼️ Cover Glass Card
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: [
                  coverUrl.isNotEmpty
                      ? Image.network(coverUrl,
                          fit: BoxFit.cover, width: double.infinity)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            ),
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            ),
          ),

          // 👤 Admin Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF2DD486), Color(0xFF00E5FF)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.black,
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.admin_panel_settings_rounded,
                            size: 40, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                          user?['name'] ?? user?['username'] ?? 'مدير النظام',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: context.responsiveFontSize(18),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      Text(
                        user?['email'] ?? 'admin@system.io',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF00FF88)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          "VIP AUTHENTICATED",
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF00FF88),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersPanel(BuildContext context, AdminController controller,
      {required bool isMobile}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildStatsRow(controller),
        ),
        
        const SizedBox(height: 8),

        Expanded(
          child: Obx(() {
            if (controller.users.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_off_rounded, color: Colors.white10, size: 60),
                    const SizedBox(height: 10),
                    Text('لا يوجد مستخدمون حالياً', style: GoogleFonts.cairo(color: Colors.white24)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              itemCount: controller.users.length,
              itemBuilder: (context, index) {
                final user = controller.users[index];
                final isSelected = !isMobile && controller.selectedUser.value?['id'] == user['id'];
                return _buildUserTile(context, controller, user, isSelected, isMobile);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AdminController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Obx(() {
        final stats = controller.getUsersCountByRole();
        return Row(
          children: [
            _buildStatCard('المجموع', stats['total'].toString(), Icons.people_rounded, Colors.blue),
            _buildStatCard('مدراء', stats['admin'].toString(), Icons.stars_rounded, Colors.redAccent),
            _buildStatCard('مبدعين', stats['creator'].toString(), Icons.psychology_rounded, Colors.orangeAccent),
            _buildStatCard('مستخدمين', stats['user'].toString(), Icons.person_outline_rounded, Colors.greenAccent),
          ],
        );
      }),
    );
  }

  Widget _buildUserTile(BuildContext context, AdminController controller,
      Map<String, dynamic> user, bool isSelected, bool isMobile) {
    final role = (user['role'] ?? 'user').toString();
    final roleColor = _getRoleColor(role);
    final photoUrl = (user['photo_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? roleColor.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? roleColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: roleColor.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: ListTile(
        onTap: () {
          if (user['newUserNotification'] == true) {
            controller.acknowledgeUser(user['id'].toString());
          }
          controller.selectUser(user);
          if (isMobile) {
            Get.to(() => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    title: Text('إدارة: ${user['username'] ?? user['email']}',
                        style: GoogleFonts.cairo(fontSize: 16)),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  body: Stack(
                    children: [
                      const GalacticBackgroundUnified(),
                      _buildPermissionsPanel(context, controller),
                    ],
                  ),
                ));
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: roleColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: CircleAvatar(
            backgroundColor: roleColor.withValues(alpha: 0.1),
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    (user['email']?.toString() ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                        color: roleColor, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        title: Text(
          (user['username']?.toString() ?? '').isNotEmpty
              ? user['username'].toString()
              : (user['email']?.toString() ?? 'Unknown User'),
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((user['username']?.toString() ?? '').isNotEmpty)
              Text(
                (user['email'] ?? '').toString(),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            if ((user['bio']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  user['bio'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getRoleLabel(role),
                    style: GoogleFonts.cairo(
                      color: roleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (user['isPremium'] == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                if (user['newUserNotification'] == true)
                  const Icon(Icons.new_releases_rounded,
                      color: Colors.greenAccent, size: 14),
                if (user['is_ai_blocked'] == true)
                  const Icon(Icons.block_flipped,
                      color: Colors.redAccent, size: 14),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user['permissions_count'] != null &&
                user['permissions_count'] > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${user['permissions_count']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsPanel(
      BuildContext context, AdminController controller) {
    return Obx(() {
      final selectedUser = controller.selectedUser.value;

      if (selectedUser == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 100, color: Colors.white.withValues(alpha: 0.05)),
              const SizedBox(height: 16),
              Text(
                'اختر مستخدماً لبدء الإدارة',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }

      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                   // 👤 User VIP Card
                  _buildSelectedUserCard(context, controller, selectedUser),
                  const SizedBox(height: 12),
                  // 📊 Creative Performance Stats
                  _buildUserCreativeStats(selectedUser),
                  const SizedBox(height: 12),
                  // ⚡ Quick Settings
                  _buildVipQuickSettings(context, controller, selectedUser),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // 🔐 Detailed Permissions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildVipPermissionsListSliver(context, controller, selectedUser),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      );
    });
  }

  Widget _buildUserCreativeStats(Map<String, dynamic> user) {
    final stats = user['creator_stats'] as Map? ?? {};
    final uploads = stats['uploads_count'] ?? 0;
    final score = stats['avg_viral_score'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _smallStatBox(
            'الفيديوهات المنشأة',
            uploads.toString(),
            Icons.video_collection_rounded,
            Colors.cyanAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallStatBox(
            'متوسط التقييم',
            '${score.toStringAsFixed(1)}%',
            Icons.trending_up_rounded,
            Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  Widget _smallStatBox(String label, String value, IconData icon, Color color) {
    return SmartStatBox(
      label: label,
      value: value,
      icon: icon,
      color: color,
      isSmall: true,
    );
  }

  Widget _buildSelectedUserCard(BuildContext context,
      AdminController controller, Map<String, dynamic> user) {
    final role = (user['role'] ?? 'user').toString();
    final roleColor = _getRoleColor(role);
    final photoUrl = (user['photo_url'] ?? '').toString();
    final coverUrl = (user['cover_url'] ?? '').toString();

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        children: [
          // 🖼️ Mini Cover
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Opacity(
                opacity: 0.3,
                child: coverUrl.isNotEmpty
                    ? Image.network(coverUrl, fit: BoxFit.cover)
                    : Container(color: roleColor.withValues(alpha: 0.1)),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: roleColor.withValues(alpha: 0.2),
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          (user['email']?.toString() ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                              color: roleColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user['username']?.toString() ?? '').isNotEmpty
                            ? user['username'].toString()
                            : (user['email']?.toString() ?? 'User'),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user['email']?.toString() ?? '',
                        style: GoogleFonts.cairo(
                            color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((user['bio']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user['bio'].toString(),
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white38, fontSize: 10),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMiniInfo(
                            Icons.calendar_month_rounded,
                            _formatDate(user['createdAt']),
                            'عضو منذ',
                          ),
                          _buildMiniInfo(
                            Icons.visibility_rounded,
                            _formatDate(user['lastSeen']),
                            'آخر ظهور',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Role Picker
                _buildRolePicker(context, controller, user, roleColor),

                const SizedBox(width: 8),

                _buildUserActionsMenu(context, controller, user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePicker(BuildContext context, AdminController controller,
      Map<String, dynamic> user, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: DropdownButton<String>(
        value: (user['role'] ?? 'user').toString(),
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1E2E),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 20),
        items: [
          _buildRoleItem('user', 'مستخدم', Colors.greenAccent),
          _buildRoleItem('creator', 'منشئ محتوى', Colors.orangeAccent),
          _buildRoleItem('admin', 'مدير', Colors.redAccent),
        ],
        onChanged: (newRole) {
          if (newRole != null) {
            controller.changeUserRole(user['id'].toString(), newRole);
          }
        },
      ),
    );
  }

  DropdownMenuItem<String> _buildRoleItem(
      String value, String label, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Text(
        label,
        style: GoogleFonts.cairo(
            color: color, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUserActionsMenu(BuildContext context, AdminController controller,
      Map<String, dynamic> user) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.restart_alt_rounded,
                  color: Colors.blueAccent, size: 20),
              const SizedBox(width: 10),
              Text('إعادة تعيين الصلاحيات',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 13)),
            ],
          ),
          onTap: () => _confirmAction(
            title: 'إعادة تعيين؟',
            message: 'هل أنت متأكد من إعادة ضبط جميع صلاحيات هذا المستخدم؟',
            onConfirm: () =>
                controller.resetUserPermissions(user['id'].toString()),
          ),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete_forever_rounded,
                  color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Text('حذف المستخدم نهائياً',
                  style:
                      GoogleFonts.cairo(color: Colors.redAccent, fontSize: 13)),
            ],
          ),
          onTap: () => _confirmAction(
            title: 'تأكيد الحذف!',
            message: 'لا يمكن التراجع عن حذف المستخدم. هل تريد المتابعة؟',
            onConfirm: () => controller.deleteUser(user['id'].toString()),
            isDangerous: true,
          ),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                user['is_ai_blocked'] == true 
                  ? Icons.link_rounded 
                  : Icons.link_off_rounded,
                color: user['is_ai_blocked'] == true 
                  ? Colors.greenAccent 
                  : Colors.orangeAccent, 
                size: 20
              ),
              const SizedBox(width: 10),
              Text(
                user['is_ai_blocked'] == true 
                  ? 'إعادة اتصال الذكاء الاصطناعي' 
                  : 'قطع اتصال الذكاء الاصطناعي',
                style: GoogleFonts.cairo(
                  color: user['is_ai_blocked'] == true 
                    ? Colors.greenAccent 
                    : Colors.orangeAccent, 
                  fontSize: 13,
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
          onTap: () => controller.toggleUserAiBlock(
            user['id'].toString(), 
            user['is_ai_blocked'] != true
          ),
        ),
      ],
    );
  }

  void _confirmAction({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDangerous = false,
  }) {
    Future.delayed(Duration.zero, () {
      Get.dialog(
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content:
                Text(message, style: GoogleFonts.cairo(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo(color: Colors.white24)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDangerous ? Colors.redAccent : AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Get.back();
                  onConfirm();
                },
                child: Text('تأكيد',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildVipQuickSettings(BuildContext context,
      AdminController controller, Map<String, dynamic> user) {
    final importantControls = [
      {
        'id': 'settings_screen',
        'label': 'الإعدادات',
        'icon': Icons.settings_rounded
      },
      {
        'id': 'api_settings_screen',
        'label': 'المفاتيح 🗝️',
        'icon': Icons.vpn_key_rounded
      },
      {
        'id': 'creator_profile_screen',
        'label': 'المبدع ✨',
        'icon': Icons.psychology_rounded
      },
      {
        'id': 'ai_studio_screen',
        'label': 'استوديو AI 🎨',
        'icon': Icons.auto_awesome_rounded
      },
      {
        'id': 'upload_screen',
        'label': 'الرفع ☁️',
        'icon': Icons.cloud_upload_rounded
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded,
                  color: Colors.amberAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'الوصول السريع للميزات',
                style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: importantControls.map((ctrl) {
                final status = controller.getPermissionStatus(
                    user['id'].toString(), ctrl['id']?.toString() ?? '');
                final isVisible = status['visible'] ?? true;

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(ctrl['label']?.toString() ?? ''),
                    avatar: Icon((ctrl['icon'] is IconData) ? ctrl['icon'] as IconData : Icons.settings_rounded,
                        size: 14,
                        color: isVisible ? Colors.black : Colors.white38),
                    selected: isVisible,
                    onSelected: (val) => controller.toggleControlVisibility(
                      userId: user['id'].toString(),
                      controlName: ctrl['id']?.toString() ?? '',
                      visible: val,
                    ),
                    selectedColor: AppTheme.primary,
                    checkmarkColor: Colors.black,
                    labelStyle: GoogleFonts.cairo(
                      color: isVisible ? Colors.black : Colors.white38,
                      fontSize: 11,
                      fontWeight:
                          isVisible ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                        color: isVisible ? AppTheme.primary : Colors.white12),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipPermissionsListSliver(BuildContext context,
      AdminController controller, Map<String, dynamic> user) {
    final uiControls = controller.uiControls;
    if (uiControls.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('لا توجد عناصر واجهة برمجية',
                style: TextStyle(color: Colors.white24)),
          ),
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var control in uiControls) {
      final category = control['category'] as String? ?? 'button';
      grouped.putIfAbsent(category, () => []).add(control);
    }
    final categories = grouped.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, catIndex) {
          final catKey = categories[catIndex];
          final controls = grouped[catKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  _getCategoryLabel(catKey),
                  style: GoogleFonts.cairo(
                    color: AppTheme.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              ...controls.map((control) =>
                  _buildPermissionRow(context, controller, user, control)),
              const SizedBox(height: 10),
            ],
          );
        },
        childCount: categories.length,
      ),
    );
  }

  Widget _buildPermissionRow(BuildContext context, AdminController controller,
      Map<String, dynamic> user, Map<String, dynamic> control) {
    final controlName = control['control_name']?.toString() ?? '';
    final permission =
        controller.getPermissionStatus(user['id'].toString(), controlName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.settings_input_component_rounded,
                size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  control['description']?.toString() ?? '',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                Text(controlName,
                    style:
                        const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          _buildVipToggle(
            label: 'تفعيل',
            value: permission['enabled']!,
            activeColor: AppTheme.primary,
            onChanged: (val) => controller.toggleControlEnabled(
              userId: user['id'].toString(),
              controlName: controlName,
              enabled: val,
            ),
          ),
          const SizedBox(width: 10),
          _buildVipToggle(
            label: 'رؤية',
            value: permission['visible']!,
            activeColor: Colors.blueAccent,
            onChanged: (val) => controller.toggleControlVisibility(
              userId: user['id'].toString(),
              controlName: controlName,
              visible: val,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipToggle({
    required String label,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.cairo(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: value,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return SmartStatBox(
      label: label,
      value: value,
      icon: icon,
      color: color,
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.redAccent;
      case 'creator':
        return Colors.orangeAccent;
      default:
        return Colors.greenAccent;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مسؤول عام';
      case 'creator':
        return 'منشئ محتوى';
      default:
        return 'مستخدم عادي';
    }
  }

  void _showGlobalAiSettings(
      BuildContext context, AdminController controller) {
    // Load fresh data
    controller.checkConfigStatus();

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: Stack(
            children: [
              const GalacticBackgroundUnified(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إعدادات AI العالمية 🏛️',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'المفاتيح المشتركة لكافة المستخدمين',
                              style: GoogleFonts.cairo(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.close, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // 📥 Quick Actions Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => controller.importPersonalKeys(),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.download_rounded, color: Colors.amberAccent, size: 18),
                                  label: Text('استيراد مفاتيحي الشخصية 📥', 
                                      style: GoogleFonts.cairo(
                                          color: Colors.amberAccent, 
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // 🛰️ Provider Managed Keys
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'serpapi',
                              label: 'Google Lens & Search (SerpApi)',
                              icon: Icons.language_rounded,
                              color: Colors.blueAccent,
                            ),
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'gemini',
                              label: 'Google Gemini Pro',
                              icon: Icons.auto_awesome,
                              color: Colors.greenAccent,
                            ),
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'kling',
                              label: 'Kling AI (Video Generation)',
                              icon: Icons.movie_creation_rounded,
                              color: Colors.orangeAccent,
                            ),
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'stability',
                              label: 'Stability AI (Images)',
                              icon: Icons.palette_rounded,
                              color: Colors.purpleAccent,
                            ),
                            
                            // 🗝️ GitHub GPT-4o Managed Keys
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'github_hexa',
                              label: 'GitHub GPT-4o (6 Keys Rotation)',
                              icon: Icons.code_rounded,
                              color: Colors.cyanAccent,
                              hint: '["key1", "key2", ...]',
                            ),

                            const SizedBox(height: 10),
                            const Text(
                              'محركات الذكاء الاصطناعي الإضافية 🧠',
                              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'openai',
                              label: 'ChatGPT (OpenAI)',
                              icon: Icons.bolt_rounded,
                              color: Colors.green,
                            ),
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'deepseek',
                              label: 'DeepSeek AI',
                              icon: Icons.search_rounded,
                              color: Colors.blue,
                            ),
                            _buildManagedKeyTile(
                              controller: controller,
                              provider: 'anthropic',
                              label: 'Claude (Anthropic)',
                              icon: Icons.bubble_chart_rounded,
                              color: Colors.orange,
                            ),
                            
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 10),
                            
                            // 🔄 Sync System Controls Button
                            TextButton.icon(
                              onPressed: () => controller.syncSystemControls(),
                              icon: const Icon(Icons.sync_lock_rounded, 
                                  color: Colors.cyanAccent, size: 16),
                              label: Text('تحديث سجل الصلاحيات في السحابة ☁️', 
                                  style: GoogleFonts.cairo(
                                      color: Colors.cyanAccent, 
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                            
                            const SizedBox(height: 16),
                            // 🎁 Free Daily Limit Setting
                            Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  children: [
                                     Row(
                                      children: [
                                        const Icon(Icons.card_giftcard, color: Colors.amberAccent, size: 18),
                                        const SizedBox(width: 10),
                                        Text('رصيد الاستخدام اليومي المجاني', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Obx(() => Row(
                                      children: [
                                        Expanded(
                                          child: Slider(
                                            value: controller.freeDailyLimitEditing.value.toDouble(),
                                            min: 0,
                                            max: 200,
                                            divisions: 20,
                                            label: controller.freeDailyLimitEditing.value.toString(),
                                            activeColor: AppTheme.primary,
                                            onChanged: (v) => controller.freeDailyLimitEditing.value = v.toInt(),
                                          ),
                                        ),
                                        Text('${controller.freeDailyLimitEditing.value}', style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    )),
                                  ],
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () async {
                          await controller.updateGlobalAiSettings();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Text('حفظ التغييرات العالمية 💾', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  Widget _buildManagedKeyTile({
    required AdminController controller,
    required String provider,
    required String label,
    required IconData icon,
    required Color color,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final currentKey = controller.managedKeysEditing[provider] ?? '';
            return TextField(
              controller: TextEditingController(text: currentKey)
                ..selection = TextSelection.fromPosition(TextPosition(offset: currentKey.length)),
              onChanged: (v) => controller.managedKeysEditing[provider] = v.trim(),
              style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint ?? 'أدخل مفتاح $provider هنا...',
                hintStyle: GoogleFonts.cairo(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'Home':
        return '🏠 الواجهة الرئيسية';
      case 'Studio':
        return '🎨 استوديو الإبداع';
      case 'Chat':
        return '💬 أنظمة الدردشة';
      case 'Admin':
        return '🔐 أدوات المسؤول';
      case 'System':
        return '⚙️ إعدادات النظام';
      case 'button':
        return '🔘 الأزرار والتفاعل';
      case 'screen':
        return '📱 الشاشات المتوفرة';
      default:
        return '📂 $category';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'غير متوفر';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    if (date is String) {
      try {
        final dt = DateTime.parse(date);
        return '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {
        return date;
      }
    }
    return date.toString();
  }

  Widget _buildMiniInfo(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white24, size: 10),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.cairo(color: Colors.white24, fontSize: 8)),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

