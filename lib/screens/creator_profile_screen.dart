import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sqflite/sqflite.dart';
import '../services/db_service.dart';
import '../services/instagram_service.dart';
import '../services/tiktok_account_service.dart';
import '../theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../services/firestore_user_service.dart';
import '../services/referral_service.dart';
import '../controllers/settings_controller.dart';
import 'brand_settings_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({super.key});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final AuthController _auth = Get.find<AuthController>();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final db = Get.find<DBService>();
      final d = await db.db;
      // d is non-nullable from DBService.db getter

      // 1. Get Generated Content Count
      final uploads =
          await d.rawQuery('SELECT COUNT(*) as count FROM generated_content');
      final uploadsCount = Sqflite.firstIntValue(uploads) ?? 0;

      // 2. Get Viral Reports for scores
      final reports = await d.query('viral_booster_reports');
      double totalScore = 0;
      for (var r in reports) {
        totalScore += (r['viral_score'] as num? ?? 0).toDouble();
      }
      double avgScore = reports.isEmpty ? 0 : totalScore / reports.length;

      if (!mounted) return;
      setState(() {
        _profile = {
          'avg_viral_score': avgScore,
          'content_strengths': {
            'upload_count': uploadsCount,
            'primary_format': 'فيديو ذكي'
          },
          'top_niches': 'عام'
        };
        _isLoading = false;
      });

      // ☁️ مزامنة الإحصائيات مع Firestore لكي يراها المدير
      final uid = _auth.firebaseUid;
      if (uid != null) {
        final firestore = Get.find<FirestoreUserService>();
        firestore.updateCreatorStats(
          uid: uid,
          stats: {
            'avg_viral_score': avgScore,
            'uploads_count': uploadsCount,
            'last_sync': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false, // 🛡️ شريط التنقل يدير المسار
          centerTitle: true,
          title: const Text('ملف ذكاء المبدع 🧠',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'IBMPlexSansArabic')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [
                const Color(0xFF2DD486).withValues(alpha: 0.05),
                Colors.black,
              ],
            ),
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2DD486)))
              : _profile == null || _profile!.containsKey('message')
                  ? _buildEmptyState()
                  : SafeArea(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildUserHeader(),
                            const SizedBox(height: 24),
                            _buildCreditsCard(),
                            const SizedBox(height: 24),
                            _buildShareAppButton(),
                            const SizedBox(height: 24),
                            _buildConnectedAccounts(),
                            const SizedBox(height: 24),
                            _buildStatsGrid(),
                            const SizedBox(height: 24),
                            _buildContentStrengths(),
                            const SizedBox(height: 24),
                            _buildNicheCard(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined,
              size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('لا توجد بيانات كافية بعد.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16)),
          const SizedBox(height: 8),
          const Text('ابدأ برفع الملفات واستخدام الترندات لبناء ملفك!',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Obx(() => Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2DD486), Color(0xFF00E5FF)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF0D0D10),
                  child: const Icon(Icons.person_rounded,
                      size: 45, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_auth.user?['username'] ?? 'المبدع VIP',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'IBMPlexSansArabic')),
                    const SizedBox(height: 4),
                    Text(
                        _auth.user?['bio']?.toString().isNotEmpty == true
                            ? _auth.user!['bio']
                            : 'مبدع محتوى ذكي • Premium 2026',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                            fontFamily: 'IBMPlexSansArabic')),
                  ],
                ),
              ),
              // 🏷️ زر إعدادات البراند
              IconButton(
                onPressed: () => Get.to(() => const BrandSettingsScreen()),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD486).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2DD486)),
                ),
                tooltip: 'إعدادات البراند والهوية',
              ),
            ],
          )),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
            child: _statCard(
                'متوسط Viral Score',
                '${_profile!['avg_viral_score'].toStringAsFixed(1)}%',
                Colors.orange)),
        const SizedBox(width: 16),
        Expanded(
            child: _statCard(
                'إجمالي المحتوى',
                '${_profile!['content_strengths']['upload_count']}',
                Colors.blue)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildContentStrengths() {
    final strengths = _profile!['content_strengths'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تحليل نقاط القوة ✨',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white,
                  fontFamily: 'IBMPlexSansArabic')),
          const SizedBox(height: 20),
          _strengthRow('التنسيق الأكثر نجاحاً',
              strengths['primary_format'] ?? 'فيديو ذكي'),
          _strengthRow('مستوى التفاعل المتوقع', 'مرتفع جداً 🔥'),
        ],
      ),
    );
  }

  Widget _strengthRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNicheCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [AppTheme.primary, Colors.blue.shade700]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المجال المقترح (Niche) 🎯',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(_profile!['top_niches'] ?? 'عام',
              style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCreditsCard() {
    if (!Get.isRegistered<SettingsController>()) return const SizedBox.shrink();

    return Obx(() {
      final controller = Get.find<SettingsController>();
      final credits = controller.remainingCredits.value;
      const maxCredits = 50.0;
      final progress = (credits / maxCredits).clamp(0.0, 1.0);

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.offline_bolt, color: Colors.purpleAccent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رصيد الذكاء الاصطناعي 🧠',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'اشتراك Premium النشط',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '$credits وحدة',
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildConnectedAccounts() {
    final instagramService = Get.find<InstagramService>();
    final tiktokService = Get.find<TikTokAccountService>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD486).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.link_rounded,
                    color: Color(0xFF2DD486), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'الحسابات المرتبطة 🔗',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                    fontFamily: 'IBMPlexSansArabic'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 📸 بطاقة انستقرام
          Obx(() => _buildInstagramCard(instagramService)),

          const SizedBox(height: 12),

          // 🎵 بطاقة تيك توك
          Obx(() => _buildTikTokCard(tiktokService)),
        ],
      ),
    );
  }

  /// 📸 بطاقة انستقرام الاحترافية
  Widget _buildInstagramCard(InstagramService service) {
    final isConnected = service.isConnected.value;
    final profile = service.instagramProfile.value;
    final isLoading = service.isLoading.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [
                  const Color(0xFFC13584).withValues(alpha: 0.15),
                  const Color(0xFFE1306C).withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.02),
                ],
        ),
        border: Border.all(
          color: isConnected
              ? const Color(0xFFE1306C).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // أيقونة انستقرام
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF405DE6),
                      Color(0xFF5851DB),
                      Color(0xFF833AB4),
                      Color(0xFFC13584),
                      Color(0xFFE1306C),
                      Color(0xFFFD1D1D),
                      Color(0xFFF56040),
                      Color(0xFFF77737),
                      Color(0xFFFCAF45),
                      Color(0xFFFFDC80),
                    ],
                  ),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 22),
              ),

              const SizedBox(width: 14),

              // معلومات الحساب
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instagram',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isConnected && profile != null) ...[
                      Text(
                        '@${profile['username'] ?? ''}',
                        style: TextStyle(
                          color: const Color(0xFFE1306C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'غير مرتبط',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // زر الربط / الفصل
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE1306C),
                  ),
                )
              else
                GestureDetector(
                  onTap: isConnected
                      ? () => _showDisconnectDialog(service)
                      : () => service.connectInstagram(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isConnected
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE1306C).withValues(alpha: 0.2),
                      border: Border.all(
                        color: isConnected
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE1306C).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isConnected ? 'مرتبط ✓' : 'ربط الآن',
                      style: TextStyle(
                        color: isConnected
                            ? const Color(0xFF2DD486)
                            : const Color(0xFFE1306C),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // إحصائيات الحساب المربوط
          if (isConnected && profile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileStat(
                    _formatNumber(profile['followers_count'] ?? 0),
                    'متابع',
                  ),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.08)),
                  _buildProfileStat(
                    _formatNumber(profile['follows_count'] ?? 0),
                    'متابَع',
                  ),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.08)),
                  _buildProfileStat(
                    _formatNumber(profile['media_count'] ?? 0),
                    'منشور',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 📊 عنصر إحصائية صغير
  Widget _buildProfileStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
      ],
    );
  }

  /// 🔢 تنسيق الأرقام الكبيرة (1200 -> 1.2K)
  String _formatNumber(dynamic count) {
    final num n = count is num ? count : 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }

  /// 🎵 بطاقة تيك توك الاحترافية
  Widget _buildTikTokCard(TikTokAccountService service) {
    final connected = service.isConnected.value;
    final loading = service.isLoading.value;
    final profile = service.tiktokProfile.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected
              ? [
                  const Color(0xFF00F2EA).withValues(alpha: 0.12),
                  const Color(0xFFFF0050).withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.03),
                  Colors.white.withValues(alpha: 0.01),
                ],
        ),
        border: Border.all(
          color: connected
              ? const Color(0xFF00F2EA).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F2EA), Color(0xFFFF0050)],
                  ),
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TikTok',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            fontFamily: 'IBMPlexSansArabic')),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? '✅ مرتبط${profile?['display_name'] != null ? ' • @${profile!['display_name']}' : ''}'
                          : 'غير مرتبط',
                      style: TextStyle(
                        color: connected
                            ? const Color(0xFF00F2EA)
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00F2EA)))
                  : connected
                      ? GestureDetector(
                          onTap: () => _showTikTokDisconnectDialog(service),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Text('فصل',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => service.connectTikTok(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F2EA), Color(0xFFFF0050)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F2EA)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Text('ربط الآن',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                        ),
            ],
          ),

          // عرض الإحصائيات عند الاتصال
          if (connected && profile != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileStat(
                    _formatNumber(profile['follower_count'] ?? 0),
                    'متابع',
                  ),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.08)),
                  _buildProfileStat(
                    _formatNumber(profile['following_count'] ?? 0),
                    'متابَع',
                  ),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.08)),
                  _buildProfileStat(
                    _formatNumber(profile['likes_count'] ?? 0),
                    'إعجاب',
                  ),
                  Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.08)),
                  _buildProfileStat(
                    _formatNumber(profile['video_count'] ?? 0),
                    'فيديو',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ⚠️ حوار تأكيد فصل حساب انستقرام
  void _showDisconnectDialog(InstagramService service) {
    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('فصل حساب انستقرام؟',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic')),
          content: const Text(
            'سيتم إلغاء ربط حساب انستقرام. يمكنك إعادة الربط في أي وقت.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                service.disconnectInstagram();
              },
              child: const Text('فصل الحساب',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ حوار تأكيد فصل حساب تيك توك
  void _showTikTokDisconnectDialog(TikTokAccountService service) {
    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('فصل حساب تيك توك؟',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'IBMPlexSansArabic')),
          content: const Text(
            'سيتم إلغاء ربط حساب تيك توك. يمكنك إعادة الربط في أي وقت.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                service.disconnectTikTok();
              },
              child: const Text('فصل الحساب',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareAppButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2DD486).withValues(alpha: 0.15),
            const Color(0xFF00E5FF).withValues(alpha: 0.05),
          ],
        ),
        border:
            Border.all(color: const Color(0xFF2DD486).withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Get.find<ReferralService>().shareApp(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD486),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF2DD486).withValues(alpha: 0.3),
                          blurRadius: 10)
                    ],
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: Colors.black, size: 22),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'انشر الإبداع الذكي 🚀',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            fontFamily: 'IBMPlexSansArabic'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'شارك البرنامج مع المبدعين حول العالم',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
