import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/error_handler.dart';
import '../../widgets/ui_kit/smart_loading_overlay.dart';
import '../../core/theme/ui_kit/smart_glass_card.dart';
import '../../core/theme/ui_kit/smart_neon_button.dart';
import '../../core/theme/ui_kit/smart_neon_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = Get.find<AuthController>();
  bool _obscurePassword = true;
  late AnimationController _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى إدخال البريد الإلكتروني وكلمة المرور',
        backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
        colorText: Colors.white,
        margin: const EdgeInsets.all(20),
      );
      return;
    }

    if (!await ErrorHandler.hasInternetConnection()) return;

    final success = await _auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success) {
      Get.snackbar(
        'خطأ في الدخول',
        'يرجى التأكد من صحة البيانات أو تفعيل الحساب',
        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
        colorText: Colors.white,
        margin: const EdgeInsets.all(20),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Stack(
        children: [
          // 🌌 Galactic Animated Background
          GalacticBackgroundUnified(animation: _bgAnimation, starOpacity: 0.3),

          // 🪐 Glassmorphism Login Container
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 450.w),
                    child: _buildGlassLoginCard(),
                  ),
                ),
              ),
            ),
          ),

          // 🔄 Global Loading Overlay
          Obx(() => SmartLoadingOverlay(
                isLoading: _auth.isLoading.value,
              )),
        ],
      ),
    );
  }

  Widget _buildGlassLoginCard() {
    return SmartGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🚀 Logo & Title
          _buildHeader(),
          const SizedBox(height: 40),

          // 📝 Input Fields
          AutofillGroup(
            child: Column(
              children: [
                _buildNeonTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  hints: [AutofillHints.email],
                ),
                const SizedBox(height: 20),
                _buildNeonTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  icon: Icons.lock_open_rounded,
                  isPassword: true,
                  hints: [AutofillHints.password],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showForgotPasswordDialog(context),
              child: Text(
                'نسيت كلمة المرور؟',
                style: GoogleFonts.cairo(
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ⚡ Login Button
          _buildSubmitButton(),

          const SizedBox(height: 25),

          // 🌍 Social Login
          if (Platform.isAndroid || Platform.isIOS) ...[
            _buildSocialDivider(),
            const SizedBox(height: 20),
            _buildGoogleButton(),
          ],

          const SizedBox(height: 30),

          // 🔗 Signup Link
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.cyanAccent,
                Colors.purpleAccent.withValues(alpha: 0.5)
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Icon(Icons.rocket_launch_rounded,
              size: 40, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'VIP ACCESS 2026',
          style: GoogleFonts.oswald(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [Colors.white, Colors.cyanAccent],
              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
          ),
        ),
        Text(
          'نظام صناعة المحتوى الذكي المحترف',
          style: GoogleFonts.cairo(
            color: Colors.white54,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNeonTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    Iterable<String>? hints,
  }) {
    return SmartNeonTextField(
      controller: controller,
      label: label,
      icon: icon,
      isPassword: isPassword,
      isObscured: _obscurePassword,
      onToggleVisibility: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      keyboardType: keyboardType,
      hints: hints,
      accentColor: Colors.cyanAccent,
      onSubmitted: (_) {
        if (isPassword) {
          TextInput.finishAutofillContext();
          _login();
        }
      },
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() => SmartNeonButton(
          text: 'دخول النظام الآمن',
          isLoading: _auth.isLoading.value,
          onPressed: _login,
          gradientColors: const [Colors.cyanAccent, Color(0xFF00E5FF)],
          shadowColor: Colors.cyanAccent.withValues(alpha: 0.3),
        ));
  }

  Widget _buildGoogleButton() {
    return Obx(() => Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: TextButton.icon(
            onPressed:
                _auth.isLoading.value ? null : () => _auth.signInWithGoogle(),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                height: 20,
                width: 20,
              ),
            ),
            label: Text(
              'الدخول السريع عبر Google',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ));
  }

  Widget _buildSocialDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'أو المواصلة باستخدام',
            style: GoogleFonts.cairo(color: Colors.white24, fontSize: 11),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white10)),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك وصول؟',
          style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13),
        ),
        TextButton(
          onPressed: () => Get.toNamed('/signup'),
          child: Text(
            'أنشئ حسابك الآن',
            style: GoogleFonts.cairo(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController =
        TextEditingController(text: _emailController.text);
    Get.bottomSheet(
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A).withValues(alpha: 0.9),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 30),
                const Icon(Icons.lock_reset_rounded,
                    color: Colors.cyanAccent, size: 50),
                const SizedBox(height: 20),
                Text('استعادة الوصول',
                    style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 10),
                Text('أدخل بريدك لتلقي رابط إعادة التعيين الآمن',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.cairo(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 30),
                _buildNeonTextField(
                  controller: resetEmailController,
                  label: 'البريد الإلكتروني',
                  icon: Icons.email_rounded,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (resetEmailController.text.isNotEmpty) {
                        _auth.sendPasswordReset(
                            resetEmailController.text.trim());
                        Get.back();
                        Get.snackbar(
                            'تم الإرسال', 'تحقق من بريدك الإلكتروني قريباً',
                            colorText: Colors.white);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text('إرسال الرابط',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

