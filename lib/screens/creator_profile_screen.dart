import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db_service.dart';
import '../controllers/auth_controller.dart';
import '../services/firestore_user_service.dart';
import '../services/referral_service.dart';
import '../controllers/settings_controller.dart';
import 'brand_settings_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'auth/edit_profile_screen.dart';
import '../widgets/account_picker_sheet.dart';

class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({super.key});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final AuthController _auth = Get.find<AuthController>();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  // 🎨 لوحة ألوان هادئة مستوحاة من Gemini/ChatGPT
  static const Color _bgColor = Color(0xFF0D0D0D);
  static const Color _cardColor = Color(0xFF1A1A1A);
  static const Color _dividerColor = Color(0xFF262626);
  static const Color _accent = Color(0xFF3B59FF);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF9E9E9E);
  static const Color _textTertiary = Color(0xFF616161);

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final db = Get.find<DBService>();
      final d = await db.db;
      final uid = _auth.firebaseUid;

      // 1. جلب البيانات المحلية (SQLite)
      // نجمع كل سطر في تاريخ الدردشة كنشاط
      final generatedRes = await d.rawQuery('SELECT COUNT(*) as count FROM generated_content');
      final chatRes = await d.rawQuery('SELECT COUNT(*) as count FROM chat_history');
      int localTotal = (Sqflite.firstIntValue(generatedRes) ?? 0) + (Sqflite.firstIntValue(chatRes) ?? 0);

      final reports = await d.query('viral_booster_reports');
      double localAvgScore = 0;
      if (reports.isNotEmpty) {
        double total = 0;
        for (var r in reports) {
          total += (r['viral_score'] as num? ?? 0).toDouble();
        }
        localAvgScore = total / reports.length;
      }

      final downloadsRes = await d.rawQuery('SELECT COUNT(*) as count FROM downloaded_videos');
      int localDownloads = Sqflite.firstIntValue(downloadsRes) ?? 0;

      if (kDebugMode) {
        debugPrint('📊 [Stats Debug]: Local Content: $localTotal, Local Score: $localAvgScore, Downloads: $localDownloads');
      }

      // 2. جلب البيانات من السحابة (Firestore)
      Map<String, dynamic>? cloudStats;
      if (uid != null) {
        try {
          cloudStats = await Get.find<FirestoreUserService>().getCreatorStats(uid);
        } catch (e) {
          debugPrint('⚠️ Firestore Stats Error: $e');
        }
      }

      // 3. دمج البيانات (نأخذ القيمة الأكبر لضمان عدم ضياع البيانات عند تبديل الأجهزة)
      int finalTotal = localTotal > (cloudStats?['total_content'] ?? 0) ? localTotal : (cloudStats?['total_content'] ?? 0);
      double finalAvg = localAvgScore > (cloudStats?['avg_viral_score'] ?? 0) ? localAvgScore : (cloudStats?['avg_viral_score'] ?? 0).toDouble();
      int finalDownloads = localDownloads > (cloudStats?['downloads_count'] ?? 0) ? localDownloads : (cloudStats?['downloads_count'] ?? 0);

      if (!mounted) return;
      setState(() {
        _profile = {
          'avg_viral_score': finalAvg,
          'total_content': finalTotal,
          'download_count': finalDownloads,
          'top_niche': _detectTopNiche(finalTotal),
        };
        _isLoading = false;
      });

      // تحديث السحابة بالقيم الأحدث
      if (uid != null && (localTotal > 0 || localDownloads > 0)) {
        Get.find<FirestoreUserService>().updateCreatorStats(
          uid: uid,
          stats: {
            'avg_viral_score': finalAvg,
            'total_content': finalTotal,
            'downloads_count': finalDownloads,
            'last_sync': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Profile Fetch Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _detectTopNiche(int total) {
    if (total > 50) return 'خبير محتوى';
    if (total > 10) return 'مبدع نشط';
    return 'مبدع صاعد';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'الملف الشخصي',
            style: GoogleFonts.tajawal(
              color: _textPrimary,
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: _textPrimary, size: 22),
              onPressed: () => Get.to(() => const EditProfileScreen()),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildUserHeader(),
                    const SizedBox(height: 28),
                    _buildCreditsCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('الإحصائيات'),
                    _buildSection([
                      _buildStatTile(
                        icon: Icons.trending_up_rounded,
                        title: 'متوسط Viral Score',
                        value:
                            '${_profile?['avg_viral_score']?.toStringAsFixed(1) ?? '0.0'}%',
                      ),
                      _buildDivider(),
                      _buildStatTile(
                        icon: Icons.auto_awesome_outlined,
                        title: 'إجمالي المحتوى المولد',
                        value: '${_profile?['total_content'] ?? 0}',
                      ),
                      _buildDivider(),
                      _buildStatTile(
                        icon: Icons.download_done_rounded,
                        title: 'الفيديوهات المحملة',
                        value: '${_profile?['download_count'] ?? 0}',
                      ),
                      _buildDivider(),
                      _buildStatTile(
                        icon: Icons.psychology_outlined,
                        title: 'المجال المقترح',
                        value: _profile?['top_niche'] ?? 'منوع',
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    _buildSectionTitle('عام'),
                    _buildSection([
                      if (_auth.isAdmin) ...[
                        _buildNavTile(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'لوحة التحكم الإدارية (الأدمن)',
                          subtitle: 'إدارة المستخدمين وصلاحياتهم ونشاطاتهم',
                          color: Colors.amber,
                          onTap: () => Get.toNamed('/admin'),
                        ),
                        _buildDivider(),
                      ],
                      _buildNavTile(
                        icon: Icons.tune_rounded,
                        title: 'إعدادات العلامة التجارية',
                        onTap: () => Get.to(() => const BrandSettingsScreen()),
                      ),
                      _buildDivider(),
                      _buildNavTile(
                        icon: Icons.share_outlined,
                        title: 'مشاركة التطبيق',
                        subtitle: 'ادعُ أصدقاءك لتجربة صانع المحتوى',
                        onTap: () => Get.find<ReferralService>().shareApp(),
                      ),
                      _buildDivider(),
                      _buildNavTile(
                        icon: Icons.info_outline_rounded,
                        title: 'حول التطبيق',
                        trailing: Text(
                          'v1.2.0',
                          style: GoogleFonts.tajawal(
                            color: _textTertiary,
                            fontSize: 13.sp,
                          ),
                        ),
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildNavTile(
                        icon: Icons.logout_rounded,
                        title: 'تسجيل الخروج',
                        color: Colors.redAccent,
                        onTap: () => _confirmLogout(),
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  // 👤 رأس المستخدم (أفاتار كبير + اسم + بريد) بنمط ChatGPT
  Widget _buildUserHeader() {
    return Obx(() {
      final name = _auth.user?['username'] ?? _auth.user?['name'] ?? 'المستخدم';
      final email = _auth.user?['email'] ?? _auth.user?['bio'] ?? '';

      return Column(
        children: [
          GestureDetector(
            onTap: () => Get.bottomSheet(
              const AccountPickerSheet(),
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _dividerColor, width: 1),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: _cardColor,
                backgroundImage: _getImageProvider(
                  (_auth.user?['photo_url'] ?? _auth.user?['profile_url'] ?? '')
                      .toString(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.tajawal(
              color: _textPrimary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (email.toString().isNotEmpty)
            Text(
              email,
              style: GoogleFonts.tajawal(
                color: _textSecondary,
                fontSize: 13.sp,
              ),
            ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Get.to(() => const EditProfileScreen()),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _dividerColor),
              ),
              child: Text(
                'تعديل الملف الشخصي',
                style: GoogleFonts.tajawal(
                  color: _textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  // ⚡ بطاقة الرصيد بنمط "Upgrade to Plus"
  Widget _buildCreditsCard() {
    if (!Get.isRegistered<SettingsController>()) return const SizedBox.shrink();

    return Obx(() {
      final controller = Get.find<SettingsController>();
      final credits = controller.remainingCredits.value;
      const maxCredits = 50.0;
      final progress = (credits / maxCredits).clamp(0.0, 1.0);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رصيد الذكاء الاصطناعي',
                        style: GoogleFonts.tajawal(
                          color: _textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$credits وحدة متبقية',
                        style: GoogleFonts.tajawal(
                          color: _textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: _dividerColor,
                valueColor: const AlwaysStoppedAnimation(_accent),
              ),
            ),
          ],
        ),
      );
    });
  }


  Widget _buildDivider() => Container(
        height: 1,
        margin: const EdgeInsets.only(right: 50),
        color: _dividerColor,
      );

  // 📋 عنوان قسم
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: GoogleFonts.tajawal(
            color: _textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // 📦 حاوية القسم (Grouped list)
  Widget _buildSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(children: children),
    );
  }

  // 📊 عنصر إحصائية (غير قابل للنقر)
  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.tajawal(
                color: _textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.tajawal(
              color: _textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ➡️ عنصر قابل للنقر
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? _textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: color ?? _textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.tajawal(
                        color: _textTertiary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(Icons.arrow_back_ios_rounded,
                    color: _textTertiary, size: 14),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    Get.defaultDialog(
      title: "تسجيل الخروج",
      titleStyle: GoogleFonts.tajawal(
        color: _textPrimary,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: _cardColor,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          "هل أنت متأكد من تسجيل الخروج؟",
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(color: _textSecondary),
        ),
      ),
      textConfirm: "خروج",
      textCancel: "إلغاء",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      cancelTextColor: _textSecondary,
      onConfirm: () => _auth.logout(),
    );
  }


  ImageProvider _getImageProvider(String path) {
    if (path.isEmpty) {
      return const AssetImage('assets/images/styles/logoapp.jpeg');
    }
    if (path.startsWith('http')) return NetworkImage(path);
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return const AssetImage('assets/images/styles/logoapp.jpeg');
  }
}

