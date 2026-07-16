import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin_controller.dart';
import '../../theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/snackbar_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/animations/galactic_background_unified.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen>
    with SingleTickerProviderStateMixin {
  final AuthController _auth = Get.find<AuthController>();
  final AdminController _admin = Get.isRegistered<AdminController>()
      ? Get.find<AdminController>()
      : Get.put(AdminController());
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  late final AnimationController _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _loadUsers();
  }

  @override
  void dispose() {
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _auth.fetchAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _handleDelete(dynamic userId) {
    Get.dialog(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          title: Text('حذف المستخدم',
              style: GoogleFonts.tajawal(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
              'هل أنت متأكد من حذف هذا المستخدم؟ لا يمكن التراجع عن هذا الإجراء.',
              style: GoogleFonts.tajawal(color: AppTheme.textGrey)),
          actions: [
            TextButton(
                onPressed: () => Get.back(),
                child: Text('إلغاء',
                    style: GoogleFonts.tajawal(color: AppTheme.textGrey))),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                final success = await _auth.removeUser(userId);
                if (success) {
                  SnackBarUtils.showSuccess('نجاح', 'تم حذف المستخدم بنجاح');
                  _loadUsers();
                } else {
                  SnackBarUtils.showError('خطأ', 'فشل في حذف المستخدم');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('حذف',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePromote(dynamic userId, String currentRole) {
    if (currentRole == 'admin') {
      SnackBarUtils.showSuccess('تنبيه', 'المستخدم أدمن بالفعل');
      return;
    }

    Get.dialog(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          title: Text('ترقية المستخدم',
              style: GoogleFonts.tajawal(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من منح صلاحيات الأدمن لهذا المستخدم؟',
              style: GoogleFonts.tajawal(color: AppTheme.textGrey)),
          actions: [
            TextButton(
                onPressed: () => Get.back(),
                child: Text('إلغاء',
                    style: GoogleFonts.tajawal(color: AppTheme.textGrey))),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                final success = await _auth.promoteToAdmin(userId);
                if (success) {
                  SnackBarUtils.showSuccess(
                      'نجاح', 'تمت ترقية المستخدم إلى أدمن');
                  _loadUsers();
                } else {
                  SnackBarUtils.showError('خطأ', 'فشل في ترقية المستخدم');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('ترقية',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionManager(Map<String, dynamic> user) {
    final userId = user['id'].toString();
    final isPremium = user['isPremium'] == true;

    Get.dialog(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          title: Text('إدارة اشتراك ${user['username'] ?? 'المستخدم'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          content: Column(
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
                        color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFFFD700)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذا المستخدم لديه اشتراك نشط حالياً',
                          style: GoogleFonts.tajawal(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildPlanOption(
                title: "Premium شهري (30 يوم)",
                subtitle: "مثالي للتجربة القصيرة",
                icon: Icons.calendar_month_rounded,
                color: AppTheme.primary,
                onTap: () async {
                  Get.back();
                  await _admin.grantUserSubscription(
                    userId: userId,
                    planId: "premium_monthly",
                    durationDays: 30,
                  );
                  _loadUsers();
                },
              ),
              const SizedBox(height: 10),
              _buildPlanOption(
                title: "Premium ربع سنوي (90 يوم)",
                subtitle: "الخيار الأكثر شعبية",
                icon: Icons.auto_awesome_motion_rounded,
                color: Colors.blueAccent,
                onTap: () async {
                  Get.back();
                  await _admin.grantUserSubscription(
                    userId: userId,
                    planId: "premium_quarterly",
                    durationDays: 90,
                  );
                  _loadUsers();
                },
              ),
              const SizedBox(height: 10),
              _buildPlanOption(
                title: "VIP سنوي (365 يوم)",
                subtitle: "كامل الصلاحيات بلا قيود",
                icon: Icons.workspace_premium_rounded,
                color: const Color(0xFFFFD700),
                onTap: () async {
                  Get.back();
                  await _admin.grantUserSubscription(
                    userId: userId,
                    planId: "premium_yearly",
                    durationDays: 365,
                  );
                  _loadUsers();
                },
              ),
              if (isPremium) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white10),
                ),
                _buildPlanOption(
                  title: "إلغاء الاشتراك الحالي",
                  subtitle: "سحب الصلاحيات فوراً",
                  icon: Icons.no_accounts_rounded,
                  color: Colors.redAccent,
                  onTap: () async {
                    Get.back();
                    await _admin.revokeUserSubscription(userId);
                    _loadUsers();
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('إغاق',
                  style: GoogleFonts.tajawal(color: AppTheme.textGrey)),
            ),
          ],
        ),
      ),
    );
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
                      style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(subtitle,
                      style: GoogleFonts.tajawal(
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

  Future<void> _openPermissionsEditor(Map<String, dynamic> user) async {
    final userId = (user['id'] ?? '').toString();
    if (userId.isEmpty) {
      SnackBarUtils.showError('خطأ', 'لا يمكن تحديد معرف المستخدم');
      return;
    }

    await _admin.selectUser({'id': userId, ...user});

    Get.bottomSheet(
      Container(
        height: Get.height * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Obx(() {
          final controls = _admin.uiControls;
          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'تعديل صلاحيات ${user['username'] ?? user['email']}',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: controls.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد عناصر صلاحيات مسجلة',
                          style: GoogleFonts.tajawal(color: AppTheme.textGrey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: controls.length,
                        itemBuilder: (context, index) {
                          final control = controls[index];
                          final controlName =
                              control['control_name']?.toString() ?? '';
                          final status =
                              _admin.getPermissionStatus(userId, controlName);
                          final enabled = status['enabled'] ?? false;
                          final visible = status['visible'] ?? false;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? AppTheme.primary.withValues(alpha: 0.05)
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: enabled
                                    ? AppTheme.primary.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              title: Text(
                                control['description']?.toString().isNotEmpty ==
                                        true
                                    ? control['description'].toString()
                                    : controlName,
                                style: GoogleFonts.tajawal(
                                  color: enabled
                                      ? Colors.white
                                      : AppTheme.textGrey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                              subtitle: Text(
                                controlName,
                                style: GoogleFonts.tajawal(
                                    color: Colors.white24, fontSize: 11.sp),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildVipToggle(
                                    label: 'تفعيل',
                                    value: enabled,
                                    activeThumbColor: AppTheme.primary,
                                    onChanged: (val) =>
                                        _admin.toggleControlEnabled(
                                      userId: userId,
                                      controlName: controlName,
                                      enabled: val,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildVipToggle(
                                    label: 'رؤية',
                                    value: visible,
                                    activeThumbColor: Colors.blueAccent,
                                    onChanged: (val) =>
                                        _admin.toggleControlVisibility(
                                      userId: userId,
                                      controlName: controlName,
                                      visible: val,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        }),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildVipToggle({
    required String label,
    required bool value,
    required Color activeThumbColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: GoogleFonts.tajawal(
                color: AppTheme.textGrey,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold)),
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: value,
            activeThumbColor: activeThumbColor,
            activeTrackColor: activeThumbColor.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('إدارة المستخدمين',
              style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            GalacticBackgroundUnified(
                animation: _bgAnimation, starOpacity: 0.15),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _users.isEmpty
                    ? Center(
                        child: Text('لا يوجد مستخدمين مسجلين',
                            style:
                                GoogleFonts.tajawal(color: AppTheme.textGrey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isMe = user['id'] == _auth.user?['id'];
                          final role = (user['role'] ?? 'user').toString();
                          final roleColor = role == 'admin'
                              ? Colors.redAccent
                              : (role == 'creator'
                                  ? Colors.orangeAccent
                                  : AppTheme.accent);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: roleColor.withValues(alpha: 0.5),
                                      width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundColor:
                                      roleColor.withValues(alpha: 0.1),
                                  backgroundImage: (user['photo_url'] != null &&
                                          user['photo_url']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(
                                          user['photo_url'].toString())
                                      : null,
                                  child: (user['photo_url'] == null ||
                                          user['photo_url'].toString().isEmpty)
                                      ? Icon(
                                          role == 'admin'
                                              ? Icons.admin_panel_settings
                                              : Icons.person,
                                          color: roleColor,
                                        )
                                      : null,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (user['username']?.toString() ?? '')
                                              .isNotEmpty
                                          ? user['username'].toString()
                                          : user['email']
                                              .toString()
                                              .split('@')[0],
                                      style: GoogleFonts.tajawal(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.sp),
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
                                  Text(
                                    user['email'].toString(),
                                    style: GoogleFonts.tajawal(
                                        color: AppTheme.textGrey,
                                        fontSize: 12.sp),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              roleColor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          role == 'admin'
                                              ? 'مدير النظام'
                                              : (role == 'creator'
                                                  ? 'منشئ محتوى'
                                                  : 'مستخدم'),
                                          style: GoogleFonts.tajawal(
                                              color: roleColor,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (user['isPremium'] == true) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFD700)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFFFFD700)
                                                    .withValues(alpha: 0.2)),
                                          ),
                                          child: Text(
                                            'VIP',
                                            style: GoogleFonts.tajawal(
                                                color: const Color(0xFFFFD700),
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: isMe
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('أنت',
                                          style: GoogleFonts.tajawal(
                                              color: AppTheme.primary,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold)),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            user['isPremium'] == true
                                                ? Icons.card_membership_rounded
                                                : Icons
                                                    .card_membership_outlined,
                                            color: user['isPremium'] == true
                                                ? const Color(0xFFFFD700)
                                                : AppTheme.textGrey,
                                          ),
                                          onPressed: () =>
                                              _showSubscriptionManager(user),
                                          tooltip: user['isPremium'] == true
                                              ? 'إدارة الاشتراك'
                                              : 'منح اشتراك VIP',
                                        ),
                                        if (role != 'admin')
                                          IconButton(
                                            icon: const Icon(
                                                Icons.upgrade_rounded,
                                                color: Colors.blueAccent),
                                            onPressed: () => _handlePromote(
                                                user['id'], role),
                                            tooltip: 'ترقية لأدمن',
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.tune_rounded,
                                              color: AppTheme.primary),
                                          onPressed: () =>
                                              _openPermissionsEditor(user),
                                          tooltip: 'تعديل الصلاحيات',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent),
                                          onPressed: () =>
                                              _handleDelete(user['id']),
                                          tooltip: 'حذف المستخدم',
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
