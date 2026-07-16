import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/ui_kit/smart_card.dart';
import '../core/utils/snackbar_utils.dart';
import '../widgets/permission_controlled_widget.dart';
import '../controllers/settings_controller.dart';
import '../theme/app_theme.dart';
import '../core/theme/animations/galactic_background_unified.dart';
import '../services/secure_storage_service.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _bgAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'الإعدادات العامة ⚙️',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            GalacticBackgroundUnified(animation: _bgAnimation, starOpacity: 0.1),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('المظهر 🎨'),
                    // 🛡️ المظهر مخصص للوضع المظلم حالياً
                    SizedBox(height: 16.h),

                    // 🏪 بيانات متجري
                    _buildSectionHeader('بيانات متجري 🏪'),
                    SmartCard(
                      onTap: () => _showStoreDialog(context),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _buildIcon(Icons.store_rounded, Colors.purpleAccent),
                        title: Text('توقيع المتجر',
                            style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp)),
                        subtitle: Text('اسم المتجر، رقم واتساب، العنوان — يُضاف تلقائياً في كل وصف',
                            style: GoogleFonts.tajawal(
                                color: AppTheme.textGrey, fontSize: 11.sp)),
                        trailing: const Icon(Icons.edit_rounded,
                            size: 18, color: Colors.purpleAccent),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // 🔑 API Keys Settings Link (Dynamic Permission)
                    VisibilityControlled(
                      controlName: 'api_settings_screen',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('المطورين والمفاتيح 🗝️'),
                          SmartCard(
                            onTap: () => Get.toNamed('/api-settings'),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _buildIcon(Icons.vpn_key_outlined, Colors.orangeAccent),
                              title: Text('إدارة مفاتيح API',
                                  style: GoogleFonts.tajawal(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp)),
                              subtitle: Text('Google Gemini, OpenAI, TikTok...',
                                  style: GoogleFonts.tajawal(
                                      color: AppTheme.textGrey, fontSize: 11.sp)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14, color: Colors.white24),
                            ),
                          ),
                          SizedBox(height: 32.h),
                        ],
                      ),
                    ),

                    // ⚖️ About & Legal
                    _buildSectionHeader('عن التطبيق والقانون ⚖️'),
                    SmartCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildListTile(
                            icon: Icons.support_agent_rounded,
                            iconColor: Colors.greenAccent,
                            title: 'الدعم الفني (WhatsApp)',
                            subtitle: 'تواصل معنا مباشرة للمساعدة',
                            onTap: () async {
                              final url = Uri.parse('https://wa.me/967771370740');
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (context.mounted) {
                                  SnackBarUtils.showError('خطأ', 'لا يمكن فتح تطبيق WhatsApp');
                                }
                              }
                            },
                          ),
                          _buildDivider(),
                          _buildListTile(
                            icon: Icons.privacy_tip_outlined,
                            iconColor: Colors.blueAccent,
                            title: 'سياسة الخصوصية',
                            subtitle: 'كيفية حماية بياناتك ومعالجتها',
                            onTap: () => Get.toNamed('/privacy'),
                          ),
                          _buildDivider(),
                          _buildListTile(
                            icon: Icons.description_outlined,
                            iconColor: Colors.orangeAccent,
                            title: 'شروط الاستخدام',
                            subtitle: 'القواعد المنظمة لاستخدام التطبيق',
                            onTap: () => Get.toNamed('/terms'),
                          ),
                          _buildDivider(),
                          _buildListTile(
                            icon: Icons.email_outlined,
                            iconColor: Colors.redAccent,
                            title: 'الدعم الفني عبر البريد',
                            subtitle: 'support@smartcc.ai',
                            onTap: () async {
                              final url = Uri.parse('mailto:support@smartcc.ai?subject=Support Request');
                              if (!await launchUrl(url)) {
                                SnackBarUtils.showError('خطأ', 'لا يمكن فتح تطبيق البريد');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // 🚀 Updates & Sharing
                    _buildSectionHeader('التحديثات والمشاركة 🚀'),
                    SmartCard(
                      padding: EdgeInsets.zero,
                      child: GetBuilder<SettingsController>(
                        init: Get.find<SettingsController>(),
                        builder: (settingsController) {
                          return Column(
                            children: [
                              _buildListTile(
                                icon: Icons.share_rounded,
                                iconColor: Colors.blueAccent,
                                title: 'مشاركة التطبيق',
                                subtitle: 'أرسل رابط التحميل لأصدقائك',
                                onTap: () => settingsController.shareApp(),
                                trailing: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white24),
                              ),
                              _buildDivider(),
                              _buildListTile(
                                icon: Icons.update_rounded,
                                iconColor: Colors.purpleAccent,
                                title: 'تحديث التطبيق الآن',
                                subtitle: 'تحقق من وجود إصدار جديد',
                                onTap: () => settingsController.checkForUpdate(manual: true),
                                trailing: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white24),
                              ),
                              _buildDivider(),
                              ListTile(
                                leading: _buildIcon(Icons.info_outline_rounded, Colors.grey),
                                title: Text('الإصدار الحالي',
                                    style: GoogleFonts.tajawal(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp)),
                                trailing: Text(SettingsController.currentVersion,
                                    style: GoogleFonts.tajawal(
                                        color: AppTheme.textGrey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h, right: 8.w),
      child: Text(
        title,
        style: GoogleFonts.tajawal(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20.sp),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: _buildIcon(icon, iconColor),
      title: Text(title,
          style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp)),
      subtitle: Text(subtitle,
          style: GoogleFonts.tajawal(color: AppTheme.textGrey, fontSize: 11.sp)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 60,
      color: Colors.white.withValues(alpha: 0.05),
    );
  }

  // -----------------------------------------------------------------------
  // 🏪 Store Signature Dialog
  // -----------------------------------------------------------------------
  Future<void> _showStoreDialog(BuildContext context) async {
    final SecureStorageService storage = Get.find<SecureStorageService>();
    final Map<String, String> saved = await storage.getStoreSignature();

    final storeNameCtrl = TextEditingController(text: saved['storeName']);
    final phoneCtrl     = TextEditingController(text: saved['phone']);
    final addressCtrl   = TextEditingController(text: saved['address']);
    final deliveryCtrl  = TextEditingController(
      text: saved['delivery']?.isNotEmpty == true
          ? saved['delivery']
          : '🚚 متوفر لدينا خدمة التوصيل لجميع المحافظات 🇾🇪',
    );

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                )
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFB388FF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.store_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بيانات متجرك',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'ستُضاف تلقائياً في كل الأوصاف',
                              style: GoogleFonts.tajawal(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Fields ──────────────────────────────────────────
                  _buildStoreField(
                    controller: storeNameCtrl,
                    label: 'اسم المتجر',
                    hint: '🛍️ مثال: اندكس ستور',
                    icon: Icons.storefront_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildStoreField(
                    controller: phoneCtrl,
                    label: 'رقم الواتساب',
                    hint: '📲 مثال: 771370740',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _buildStoreField(
                    controller: addressCtrl,
                    label: 'العنوان',
                    hint: '📍 مثال: صنعاء - شارع بينون',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildStoreField(
                    controller: deliveryCtrl,
                    label: 'نص خدمة التوصيل',
                    hint: '🚚 مثال: متوفر لدينا خدمة التوصيل...',
                    icon: Icons.local_shipping_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // ── Buttons ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white38,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('إلغاء',
                              style: GoogleFonts.tajawal()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await storage.saveStoreSignature(
                              storeName: storeNameCtrl.text.trim(),
                              phone:     phoneCtrl.text.trim(),
                              address:   addressCtrl.text.trim(),
                              delivery:  deliveryCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            SnackBarUtils.showSuccess(
                              'تم الحفظ ✅',
                              'تم حفظ بيانات المتجر بنجاح',
                            );
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            'حفظ البيانات',
                            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            prefixIcon: Icon(icon,
                color: Colors.purpleAccent.withValues(alpha: 0.7), size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.purpleAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
