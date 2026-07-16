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
import '../services/activity_tracking_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Get.put as a safety fallback if the controller isn't registered globally
    final adminController = Get.isRegistered<AdminController>()
        ? Get.find<AdminController>()
        : Get.put(AdminController());
    final authController = Get.find<AuthController>();

    // Trigger subscription to users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adminController.subscribeToUsers(force: false);
    });

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
                          child: CircularProgressIndicator(
                              color: AppTheme.primary),
                        );
                      }

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildAdminHeader(context, authController),
                          ),
                          // 📊 إحصاءات النظام - للموبايل
                          if (!isDesktop)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: _buildSystemStatsPanel(adminController),
                              ),
                            ),

                          // 🔍 شريط البحث والفلاتر - للموبايل
                          if (!isDesktop)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child:
                                    _buildSearchAndFiltersBar(adminController),
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
                                  sliver: Obx(() {
                                    final filtered =
                                        adminController.filteredUsers;
                                    if (filtered.isEmpty) {
                                      return SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 40),
                                          child: Center(
                                            child: Column(
                                              children: [
                                                const Icon(
                                                    Icons.search_off_rounded,
                                                    color: Colors.white12,
                                                    size: 60),
                                                const SizedBox(height: 12),
                                                Text('لا توجد نتائج',
                                                    style: GoogleFonts.cairo(
                                                        color: Colors.white24,
                                                        fontSize: 14)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final user = filtered[index];
                                          return _buildUserTile(
                                              context,
                                              adminController,
                                              user,
                                              false,
                                              true);
                                        },
                                        childCount: filtered.length,
                                      ),
                                    );
                                  }),
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
              Obx(() => !adminController.isConfigValid
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
                icon: const Icon(Icons.cleaning_services_rounded,
                    color: Colors.amberAccent),
                onPressed: () => _confirmAction(
                  title: 'تنظيف الحسابات الوهمية؟',
                  message:
                      'سيتم حذف جميع الحسابات التي لا تملك إيميل أو إيميلها غير صالح أو بدون اسم بشكل نهائي من Firestore. هل تريد الاستمرار؟',
                  onConfirm: () => adminController.cleanFakeUsers(),
                  isDangerous: true,
                ),
                tooltip: 'تنظيف الحسابات الوهمية 🧹',
              ),
              IconButton(
                icon: const Icon(Icons.insights_rounded,
                    color: Colors.purpleAccent),
                onPressed: () => _showAllActivityFeed(context, adminController),
                tooltip: 'سجل النشاط الشامل',
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
                if (user?['isPremium'] == true) ...[
                  Builder(builder: (context) {
                    final sub = user?['subscription'] as Map?;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: Text(
                            sub?['planId']
                                    ?.toString()
                                    .split('_')
                                    .last
                                    .toUpperCase() ??
                                'VIP',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (sub?['endDate'] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '⌛ ${_formatExpiryDate(sub!['endDate'])}',
                              style: GoogleFonts.cairo(
                                  color: Colors.white30, fontSize: 8),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
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
        // 📊 إحصاءات النظام
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildSystemStatsPanel(controller),
        ),

        const SizedBox(height: 10),

        // 🔍 شريط البحث والفلاتر
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSearchAndFiltersBar(controller),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: Obx(() {
            final filtered = controller.filteredUsers;
            if (controller.users.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_off_rounded,
                        color: Colors.white10, size: 60),
                    const SizedBox(height: 10),
                    Text('لا يوجد مستخدمون حالياً',
                        style: GoogleFonts.cairo(color: Colors.white24)),
                  ],
                ),
              );
            }
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        color: Colors.white10, size: 60),
                    const SizedBox(height: 10),
                    Text('لا توجد نتائج مطابقة',
                        style: GoogleFonts.cairo(color: Colors.white24)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final user = filtered[index];
                final isSelected = !isMobile &&
                    controller.selectedUser.value?['id'] == user['id'];
                return _buildUserTile(
                    context, controller, user, isSelected, isMobile);
              },
            );
          }),
        ),
      ],
    );
  }

  /// 🔍 شريط البحث + الفلاتر السريعة + الترتيب
  Widget _buildSearchAndFiltersBar(AdminController controller) {
    final filters = [
      ('all', 'الكل 👥'),
      ('admin', 'مدراء 👑'),
      ('creator', 'مبدعين 🎨'),
      ('user', 'مستخدمين 👤'),
      ('premium', 'بريميوم 💎'),
      ('blocked', 'محظورين 🚫'),
      ('new', 'جدد 🆕'),
    ];
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 حقل البحث
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                onChanged: (v) => controller.searchQuery.value = v,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو الإيميل...',
                  hintStyle:
                      GoogleFonts.cairo(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white30, size: 20),
                  suffixIcon: controller.searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Colors.white30, size: 18),
                          onPressed: () => controller.searchQuery.value = '',
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 🏷️ فلاتر سريعة + ترتيب
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((f) {
                        final isActive = controller.filterRole.value == f.$1;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => controller.filterRole.value = f.$1,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.primary.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.primary.withValues(alpha: 0.6)
                                      : Colors.white12,
                                ),
                              ),
                              child: Text(
                                f.$2,
                                style: GoogleFonts.cairo(
                                  color: isActive
                                      ? AppTheme.primary
                                      : Colors.white38,
                                  fontSize: 11,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ترتيب
                PopupMenuButton<String>(
                  initialValue: controller.filterSort.value,
                  onSelected: (v) => controller.filterSort.value = v,
                  color: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'newest',
                        child: Text('الأحدث أولاً',
                            style: GoogleFonts.cairo(
                                color: Colors.white70, fontSize: 13))),
                    PopupMenuItem(
                        value: 'most_active',
                        child: Text('الأكثر استهلاكاً',
                            style: GoogleFonts.cairo(
                                color: Colors.white70, fontSize: 13))),
                    PopupMenuItem(
                        value: 'name_az',
                        child: Text('الاسم أبجدياً',
                            style: GoogleFonts.cairo(
                                color: Colors.white70, fontSize: 13))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.sort_rounded,
                        color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // عداد النتائج
            Obx(() => Text(
                  '${controller.filteredUsers.length} من ${controller.users.length} مستخدم',
                  style: GoogleFonts.cairo(color: Colors.white24, fontSize: 11),
                )),
          ],
        ));
  }

  /// 📊 لوحة إحصاءات النظام الشاملة
  Widget _buildSystemStatsPanel(AdminController controller) {
    return Obx(() {
      final stats = controller.systemStats;
      final roleStats = controller.getUsersCountByRole();
      return Column(
        children: [
          // الصف الأول: الكلي + البريميوم + المحظورون + رصيد AI
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('الإجمالي', '${stats['total']}',
                      Icons.people_rounded, Colors.blueAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('بريميوم 💎', '${stats['premium']}',
                      Icons.stars_rounded, const Color(0xFFFFD700))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('محظورون', '${stats['blocked']}',
                      Icons.block_rounded, Colors.redAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard(
                      'AI Credits',
                      '${stats['totalCredits']}',
                      Icons.auto_awesome_rounded,
                      Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 8),
          // الصف الثاني: التوزيع حسب الدور
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('مدراء', '${roleStats['admin']}',
                      Icons.admin_panel_settings_rounded, Colors.redAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('مبدعين', '${roleStats['creator']}',
                      Icons.psychology_rounded, Colors.orangeAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('مستخدمون', '${roleStats['user']}',
                      Icons.person_outline_rounded, Colors.greenAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard('جدد 🆕', '${stats['new']}',
                      Icons.fiber_new_rounded, Colors.cyanAccent)),
            ],
          ),
        ],
      );
    });
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
          final userData = user;
          if (isMobile) {
            Get.to(() => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    title: Text(
                        'إدارة: ${userData['username'] ?? userData['email']}',
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
                    (() {
                      final email = user['email']?.toString() ?? '';
                      return email.isNotEmpty
                          ? email.substring(0, 1).toUpperCase()
                          : 'U';
                    })(),
                    style: TextStyle(
                        color: roleColor, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                (user['username']?.toString() ?? '').isNotEmpty
                    ? user['username'].toString()
                    : (user['email']?.toString() ?? 'Unknown User'),
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user['isPremium'] == true) ...[
              const SizedBox(width: 6),
              const Icon(Icons.stars_rounded,
                  color: Color(0xFFFFD700), size: 16),
            ],
          ],
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
                if (user['isPremium'] == true) ...[
                  Builder(builder: (context) {
                    final sub = user['subscription'] as Map?;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: Text(
                            sub?['planId']
                                    ?.toString()
                                    .split('_')
                                    .last
                                    .toUpperCase() ??
                                'VIP',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (sub?['endDate'] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '⌛ ${_formatExpiryDate(sub!['endDate'])}',
                              style: GoogleFonts.cairo(
                                  color: Colors.white30, fontSize: 8),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
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
            // 📊 رصيد AI المستهلك
            if ((user['ai_total_credits'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.purpleAccent, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      '${user['ai_total_credits']}',
                      style: GoogleFonts.cairo(
                          color: Colors.purpleAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 4),
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
            IconButton(
              icon: Icon(
                user['isPremium'] == true
                    ? Icons.stars_rounded
                    : Icons.add_moderator_rounded,
                color: user['isPremium'] == true
                    ? const Color(0xFFFFD700)
                    : Colors.white24,
                size: 20,
              ),
              onPressed: (user['email'] ?? '').toString().toLowerCase().trim() == 'helalalfqih@gmail.com'
                  ? () => Get.snackbar('تنبيه 🛡️', 'لا يمكن تعديل اشتراك المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white)
                  : () => _showSubscriptionSaaSDialog(context, controller, user),
              tooltip: 'إدارة الاشتراك',
            ),
            const SizedBox(width: 4),
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
                  // 📊 Creative Performance Stats + AI Usage
                  _buildUserCreativeStats(selectedUser),
                  const SizedBox(height: 12),
                  // ⚡ Quick Settings
                  _buildVipQuickSettings(context, controller, selectedUser),
                  const SizedBox(height: 16),
                  // 📋 سجل النشاط
                  _buildActivityLogSection(controller),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 🔐 Detailed Permissions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildVipPermissionsListSliver(
                context, controller, selectedUser),
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
    final aiCredits = user['ai_total_credits'] ?? 0;
    final lastAction =
        ActivityTrackingService.getActionLabel(user['ai_last_action'] ?? '');

    return Column(
      children: [
        Row(
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
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _smallStatBox(
                'رصيد AI المستهلك',
                aiCredits.toString(),
                Icons.auto_awesome_rounded,
                Colors.purpleAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _smallStatBox(
                'آخر إجراء',
                lastAction.isNotEmpty ? lastAction : '—',
                Icons.history_rounded,
                Colors.tealAccent,
              ),
            ),
          ],
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

  /// 📋 قسم سجل نشاط المستخدم المحدد — تصميم Timeline احترافي
  Widget _buildActivityLogSection(AdminController controller) {
    return Obx(() {
      final isLoading = controller.isLoadingActivity.value;
      final logs = controller.selectedUserActivityLogs;

      // 📊 حساب ملخص الاستهلاك
      int totalCredits = 0;
      int paidActions = 0;
      int freeActions = 0;
      for (final log in logs) {
        final c = (log['creditsUsed'] as num?)?.toInt() ?? 0;
        totalCredits += c;
        if (c > 0) {
          paidActions++;
        } else {
          freeActions++;
        }
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════ Header ═══════════
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purpleAccent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.purpleAccent.withValues(alpha: 0.2),
                            Colors.deepPurple.withValues(alpha: 0.15),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.timeline_rounded,
                            color: Colors.purpleAccent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سجل النشاط والاستهلاك',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (!isLoading && logs.isNotEmpty)
                              Text(
                                '${logs.length} حدث مسجل',
                                style: GoogleFonts.cairo(
                                    color: Colors.white30, fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.purpleAccent),
                        ),
                    ],
                  ),

                  // ═══════════ شريط ملخص الاستهلاك ═══════════
                  if (!isLoading && logs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _activitySummaryChip(
                          Icons.auto_awesome_rounded,
                          '$totalCredits',
                          'رصيد مستهلك',
                          Colors.purpleAccent,
                        ),
                        const SizedBox(width: 8),
                        _activitySummaryChip(
                          Icons.paid_rounded,
                          '$paidActions',
                          'مدفوع',
                          Colors.orangeAccent,
                        ),
                        const SizedBox(width: 8),
                        _activitySummaryChip(
                          Icons.volunteer_activism_rounded,
                          '$freeActions',
                          'مجاني',
                          Colors.greenAccent,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ═══════════ محتوى السجل ═══════════
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                    child: CircularProgressIndicator(
                        color: Colors.purpleAccent, strokeWidth: 2)),
              )
            else if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded,
                          color: Colors.white.withValues(alpha: 0.06),
                          size: 48),
                      const SizedBox(height: 10),
                      Text(
                        'لا يوجد نشاط مسجل بعد',
                        style: GoogleFonts.cairo(
                            color: Colors.white24, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'سيظهر النشاط هنا عند استخدام أدوات AI',
                        style: GoogleFonts.cairo(
                            color: Colors.white12, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildActivityTimeline(logs),
          ],
        ),
      );
    });
  }

  /// 📊 شريحة ملخص صغيرة
  Widget _activitySummaryChip(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                        color: color.withValues(alpha: 0.6), fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🕐 قائمة Timeline مع خط ربط جانبي
  Widget _buildActivityTimeline(List<Map<String, dynamic>> logs) {
    final displayLogs = logs.length > 25 ? logs.sublist(0, 25) : logs;
    final hasMore = logs.length > 25;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        children: [
          ...List.generate(displayLogs.length, (index) {
            final log = displayLogs[index];
            final isLast = index == displayLogs.length - 1;

            // تجميع حسب اليوم
            final timestamp = log['timestamp'] as DateTime?;
            final prevTimestamp = index > 0
                ? displayLogs[index - 1]['timestamp'] as DateTime?
                : null;
            final showDateHeader =
                _shouldShowDateHeader(timestamp, prevTimestamp);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📅 فاصل التاريخ
                if (showDateHeader && timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6, right: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateHeader(timestamp),
                          style: GoogleFonts.cairo(
                            color: Colors.purpleAccent.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.purpleAccent.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 🧩 عنصر Timeline
                _buildTimelineItem(log, isFirst: index == 0, isLast: isLast),
              ],
            );
          }),

          // 📥 عرض المزيد
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '+ ${logs.length - 25} حدث آخر',
                    style: GoogleFonts.cairo(
                      color: Colors.purpleAccent.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 🧩 عنصر واحد في Timeline مع خط ربط جانبي
  Widget _buildTimelineItem(Map<String, dynamic> log,
      {required bool isFirst, required bool isLast}) {
    final action = log['action']?.toString() ?? '';
    final label = log['actionLabel']?.toString() ??
        ActivityTrackingService.getActionLabel(action);
    final credits = (log['creditsUsed'] as num?)?.toInt() ?? 0;
    final timestamp = log['timestamp'] as DateTime?;
    final details = log['details'] as Map? ?? {};
    final product = details['product']?.toString() ?? '';
    final provider = details['provider']?.toString() ?? '';

    final Color accentColor = credits == 0
        ? Colors.blueGrey
        : credits <= 1
            ? Colors.greenAccent
            : credits <= 3
                ? Colors.orangeAccent
                : Colors.redAccent;

    final IconData actionIcon = _getActionIcon(action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ خط Timeline الجانبي ═══
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // الخط الرأسي المتصل بين العناصر
                Positioned(
                  top: isFirst ? 28 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 28 : null,
                  child: Container(
                    width: 2,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                // النقطة (Dot) محاذية تماماً لمركز الأيقونة في الكارد
                Positioned(
                  top:
                      23, // 12 (padding) + 32/2 (half icon height) - 10/2 (half dot height) = 12 + 16 - 5 = 23
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ═══ بطاقة الحدث ═══
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.01),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // أيقونة الإجراء
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(actionIcon, color: accentColor, size: 16),
                  ),
                  const SizedBox(width: 12),

                  // تفاصيل الحدث
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  color: Colors.white38, size: 10),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  product,
                                  style: GoogleFonts.cairo(
                                      color: Colors.white54, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (timestamp != null)
                              Text(
                                _formatActivityDate(timestamp),
                                style: GoogleFonts.cairo(
                                    color: Colors.white30, fontSize: 9),
                              ),
                            if (provider.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  provider,
                                  style: GoogleFonts.cairo(
                                      color: Colors.white54,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // شارة الرصيد
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: credits > 0
                          ? accentColor.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: credits > 0
                          ? Border.all(
                              color: accentColor.withValues(alpha: 0.2))
                          : null,
                    ),
                    child: credits > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: accentColor, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                '-$credits',
                                style: GoogleFonts.cairo(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'مجاني',
                            style: GoogleFonts.cairo(
                                color: Colors.white24, fontSize: 10),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateHeader(DateTime? current, DateTime? previous) {
    if (current == null) return false;
    if (previous == null) return true;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff < 7) return 'قبل $diff أيام';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static IconData _getActionIcon(String action) {
    switch (action) {
      case 'generate_ad':
        return Icons.campaign_rounded;
      case 'generate_creative_image':
      case 'image_generation':
        return Icons.image_rounded;
      case 'generate_video':
      case 'generate_kling_video':
        return Icons.videocam_rounded;
      case 'visual_search':
        return Icons.visibility_rounded;
      case 'remove_background':
        return Icons.auto_fix_high_rounded;
      case 'google_images':
        return Icons.photo_library_rounded;
      case 'bing_copilot':
        return Icons.psychology_rounded;
      case 'trend_search':
        return Icons.trending_up_rounded;
      case 'google_news':
        return Icons.newspaper_rounded;
      case 'similar_videos':
        return Icons.video_library_rounded;
      case 'send_message':
        return Icons.chat_bubble_rounded;
      case 'tiktok_link':
        return Icons.music_note_rounded;
      case 'tiktok_hashtag':
        return Icons.tag_rounded;
      case 'douyin_link':
        return Icons.music_video_rounded;
      case 'rednote_link':
        return Icons.book_rounded;
      case 'bilibili_link':
        return Icons.smart_display_rounded;
      case 'kuaishou_link':
        return Icons.flash_on_rounded;
      case 'taobao_live_link':
        return Icons.live_tv_rounded;
      case 'jd_link':
        return Icons.precision_manufacturing_rounded;
      case 'instagram_link':
        return Icons.camera_alt_rounded;
      case 'youtube_link':
      case 'youtube_shorts_link':
        return Icons.play_circle_rounded;
      case 'copy_text':
        return Icons.copy_rounded;
      case 'telegram_publish':
        return Icons.send_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  static String _formatActivityDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildSelectedUserCard(BuildContext context,
      AdminController controller, Map<String, dynamic> user) {
    final role = (user['role'] ?? 'user').toString();
    final roleColor = _getRoleColor(role);
    final photoUrl = (user['photo_url'] ?? '').toString();
    final coverUrl = (user['cover_url'] ?? '').toString();

    return Container(
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
                      ? Text((() {
                          final email = user['email']?.toString() ?? '';
                          return email.isNotEmpty
                              ? email.substring(0, 1).toUpperCase()
                              : 'U';
                        })(),
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

                if ((user['email'] ?? '').toString().toLowerCase().trim() != 'helalalfqih@gmail.com')
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
    final email = (user['email'] ?? '').toString().toLowerCase().trim();
    final isOriginalAdmin = email == 'helalalfqih@gmail.com';

    if (isOriginalAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          _getRoleLabel((user['role'] ?? 'admin').toString()),
          style: GoogleFonts.cairo(
              color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

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
                  size: 20),
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
                      fontWeight: FontWeight.bold)),
            ],
          ),
          onTap: () => controller.toggleUserAiBlock(
              user['id'].toString(), user['is_ai_blocked'] != true),
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

    final email = (user['email'] ?? '').toString().toLowerCase().trim();
    final isOriginalAdmin = email == 'helalalfqih@gmail.com';

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
                    avatar: Icon(
                        (ctrl['icon'] is IconData)
                            ? ctrl['icon'] as IconData
                            : Icons.settings_rounded,
                        size: 14,
                        color: isVisible ? Colors.black : Colors.white38),
                    selected: isVisible,
                    onSelected: isOriginalAdmin
                        ? (val) => Get.snackbar('تنبيه 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white)
                        : (val) => controller.toggleControlVisibility(
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
    final email = (user['email'] ?? '').toString().toLowerCase().trim();
    final isOriginalAdmin = email == 'helalalfqih@gmail.com';

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
            onChanged: isOriginalAdmin
                ? (val) => Get.snackbar('تنبيه 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white)
                : (val) => controller.toggleControlEnabled(
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
            onChanged: isOriginalAdmin
                ? (val) => Get.snackbar('تنبيه 🛡️', 'لا يمكن تعديل صلاحيات المدير الأصلي للنظام.', backgroundColor: const Color(0xFF3A1A1A), colorText: Colors.white)
                : (val) => controller.toggleControlVisibility(
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

  void _showGlobalAiSettings(BuildContext context, AdminController controller) {
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
                                  onPressed: () =>
                                      controller.importPersonalKeys(),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.amberAccent
                                        .withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.download_rounded,
                                      color: Colors.amberAccent, size: 18),
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
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
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
                                      const Icon(Icons.card_giftcard,
                                          color: Colors.amberAccent, size: 18),
                                      const SizedBox(width: 10),
                                      Text('رصيد الاستخدام اليومي المجاني',
                                          style: GoogleFonts.cairo(
                                              color: Colors.white70,
                                              fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Obx(() => Row(
                                        children: [
                                          Expanded(
                                            child: Slider(
                                              value: controller
                                                  .freeDailyLimitEditing.value
                                                  .toDouble(),
                                              min: 0,
                                              max: 200,
                                              divisions: 20,
                                              label: controller
                                                  .freeDailyLimitEditing.value
                                                  .toString(),
                                              activeColor: AppTheme.primary,
                                              onChanged: (v) => controller
                                                  .freeDailyLimitEditing
                                                  .value = v.toInt(),
                                            ),
                                          ),
                                          Text(
                                              '${controller.freeDailyLimitEditing.value}',
                                              style: GoogleFonts.oswald(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () async {
                          await controller.updateGlobalAiSettings();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Text('حفظ التغييرات العالمية 💾',
                            style:
                                GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
              Text(label,
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final currentKey = controller.managedKeysEditing[provider] ?? '';
            return TextField(
              controller: TextEditingController(text: currentKey)
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: currentKey.length)),
              onChanged: (v) =>
                  controller.managedKeysEditing[provider] = v.trim(),
              style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint ?? 'أدخل مفتاح $provider هنا...',
                hintStyle:
                    GoogleFonts.cairo(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  String _formatExpiryDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return "${date.year}/${date.month}/${date.day}";
    } catch (e) {
      return '';
    }
  }

  void _showSubscriptionSaaSDialog(BuildContext context,
      AdminController controller, Map<String, dynamic> user) {
    final userId = user['id'].toString();
    final isPremium = user['isPremium'] == true;

    Future.delayed(Duration.zero, () {
      Get.dialog(
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            title: Text('إدارة اشتراك SaaS',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPremium)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFFFFD700).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded,
                              color: Color(0xFFFFD700)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'المستخدم لديه اشتراك نشط حالياً',
                              style: GoogleFonts.cairo(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildPlanOption(
                    title: "Premium شهري (30 يوم)",
                    subtitle: "منح صلاحيات كاملة لشهر",
                    icon: Icons.calendar_month_rounded,
                    color: AppTheme.primary,
                    onTap: () async {
                      Get.back();
                      await controller.grantUserSubscription(
                        userId: userId,
                        planId: "premium_monthly",
                        durationDays: 30,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPlanOption(
                    title: "VIP سنوي (365 يوم)",
                    subtitle: "منح صلاحيات سنوية كاملة",
                    icon: Icons.workspace_premium_rounded,
                    color: const Color(0xFFFFD700),
                    onTap: () async {
                      Get.back();
                      await controller.grantUserSubscription(
                        userId: userId,
                        planId: "premium_yearly",
                        durationDays: 365,
                      );
                    },
                  ),
                  if (isPremium) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.white10),
                    ),
                    _buildPlanOption(
                      title: "إلغاء الاشتراك",
                      subtitle: "سحب كافة الصلاحيات المميزة",
                      icon: Icons.no_accounts_rounded,
                      color: Colors.redAccent,
                      onTap: () async {
                        Get.back();
                        await controller.revokeUserSubscription(userId);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('إغلاق',
                    style: GoogleFonts.cairo(color: AppTheme.textGrey)),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPlanOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(subtitle,
                      style: GoogleFonts.cairo(
                          color: AppTheme.textGrey, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
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

  /// 🌐 عرض سجل النشاط الشامل لجميع المستخدمين
  static void _showAllActivityFeed(
      BuildContext context, AdminController controller) {
    // تحميل البيانات دون انتظار
    controller.loadAllRecentActivity();

    Get.bottomSheet(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // 🏷️ Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.insights_rounded,
                          color: Colors.purpleAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل النشاط الشامل',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Obx(() => Text(
                              '${controller.allRecentActivityLogs.length} حدث حديث',
                              style: GoogleFonts.cairo(
                                  color: Colors.white38, fontSize: 11),
                            )),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.purpleAccent),
                      onPressed: () => controller.loadAllRecentActivity(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 24),

              // 📋 قائمة الأحداث
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingActivity.value) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.purpleAccent),
                    );
                  }
                  final logs = controller.allRecentActivityLogs;
                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timeline_rounded,
                              color: Colors.white12, size: 60),
                          const SizedBox(height: 12),
                          Text('لا يوجد نشاط مسجل بعد',
                              style: GoogleFonts.cairo(
                                  color: Colors.white24, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                              'سيظهر النشاط هنا عند استخدام المستخدمين للميزات',
                              style: GoogleFonts.cairo(
                                  color: Colors.white12, fontSize: 11)),
                        ],
                      ),
                    );
                  }

                  // احسب إجمالي الرصيد
                  final totalCredits = logs.fold<int>(
                      0,
                      (acc, log) =>
                          acc + ((log['creditsUsed'] as num?)?.toInt() ?? 0));

                  return Column(
                    children: [
                      // 💰 ملخص إجمالي
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    Colors.purpleAccent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.purpleAccent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'إجمالي الرصيد المستهلك:',
                                style: GoogleFonts.cairo(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                totalCredits.toString(),
                                style: GoogleFonts.cairo(
                                  color: Colors.purpleAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 📊 توزيع استهلاك المزودات بالوقت الفعلي
                      _buildProviderBreakdownWidget(logs),
                      const SizedBox(height: 12),

                      // 📋 سجل الأحداث
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withValues(alpha: 0.04),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final action = log['action']?.toString() ?? '';
                            final label = log['actionLabel']?.toString() ??
                                ActivityTrackingService.getActionLabel(action);
                            final credits =
                                (log['creditsUsed'] as num?)?.toInt() ?? 0;
                            final timestamp = log['timestamp'] as DateTime?;
                            final userId =
                                log['userId']?.toString() ?? 'unknown';
                            // محاولة إيجاد اسم المستخدم من القائمة
                            final userMap = controller.users
                                .firstWhereOrNull((u) => u['id'] == userId);
                            final userName = userMap?['username']?.toString() ??
                                userMap?['email']?.toString() ??
                                userId.substring(
                                    0, userId.length > 8 ? 8 : userId.length);

                            final Color accentColor = credits == 0
                                ? Colors.blueGrey
                                : credits <= 1
                                    ? Colors.greenAccent
                                    : credits <= 3
                                        ? Colors.orangeAccent
                                        : Colors.redAccent;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  // أيقونة
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      AdminDashboardScreen._getActionIcon(
                                          action),
                                      color: accentColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // تفاصيل
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.person_outline_rounded,
                                                color: Colors.white24,
                                                size: 11),
                                            const SizedBox(width: 3),
                                            Text(
                                              userName,
                                              style: GoogleFonts.cairo(
                                                  color: Colors.white38,
                                                  fontSize: 10),
                                            ),
                                            if (timestamp != null) ...[
                                              const SizedBox(width: 8),
                                              const Icon(
                                                  Icons.access_time_rounded,
                                                  color: Colors.white12,
                                                  size: 10),
                                              const SizedBox(width: 3),
                                              Text(
                                                AdminDashboardScreen
                                                    ._formatActivityDate(
                                                        timestamp),
                                                style: GoogleFonts.cairo(
                                                    color: Colors.white24,
                                                    fontSize: 9),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // رصيد
                                  if (credits > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-$credits ✨',
                                        style: GoogleFonts.cairo(
                                          color: accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // 📊 توزيع استهلاك المزودات بالوقت الفعلي بناءً على السجلات الأخيرة للمشرفين
  static Widget _buildProviderBreakdownWidget(List<Map<String, dynamic>> logs) {
    final providerCounts = <String, int>{};
    int totalWithProvider = 0;

    for (final log in logs) {
      final details = log['details'];
      if (details is Map && details.containsKey('provider')) {
        final prov = details['provider']?.toString() ?? '';
        if (prov.isNotEmpty) {
          String normalized = prov;
          if (prov.contains('Vertex')) {
            normalized = 'Vertex AI ☁️';
          } else if (prov.contains('Back4App') || prov.contains('Pool')) {
            normalized = 'Gemini Pool 🤖';
          } else {
            normalized = 'Local / Client Key 🔑 ($prov)';
          }
          providerCounts[normalized] = (providerCounts[normalized] ?? 0) + 1;
          totalWithProvider++;
        }
      }
    }

    if (totalWithProvider == 0) return const SizedBox.shrink();

    // Sort by count descending
    final sortedProviders = providerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16162A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded,
                    color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'توزيع استهلاك المزودات بالوقت الفعلي:',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sortedProviders.map((entry) {
              final ratio = entry.value / totalWithProvider;
              final percent = (ratio * 100).toStringAsFixed(0);

              Color barColor = Colors.cyanAccent;
              if (entry.key.contains('Vertex')) {
                barColor = Colors.blueAccent;
              } else if (entry.key.contains('Pool')) {
                barColor = Colors.purpleAccent;
              } else {
                barColor = Colors.tealAccent;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '${entry.value} طلب ($percent%)',
                          style: GoogleFonts.cairo(
                            color: barColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
