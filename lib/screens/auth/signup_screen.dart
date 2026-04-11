import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/error_handler.dart';
import '../../widgets/ui_kit/smart_loading_overlay.dart';
import '../../core/theme/ui_kit/smart_glass_card.dart';
import '../../core/theme/ui_kit/smart_neon_button.dart';
import '../../core/theme/ui_kit/smart_neon_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = Get.find<AuthController>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar('تنبيه', 'الرجاء إدخال جميع البيانات',
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
          colorText: Colors.white);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      Get.snackbar('خطأ', 'كلمة المرور غير متطابقة',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
          colorText: Colors.white);
      return;
    }

    if (!await ErrorHandler.hasInternetConnection()) return;

    setState(() => _isLoading = true);
    final success = await _auth.signUp(
      _emailController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (success) {
      Get.snackbar('نجاح', 'تم إنشاء هويتك الرقمية بنجاح 🚀',
          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
          colorText: Colors.white);
    } else {
      Get.snackbar('فشل', 'خطأ في إنشاء الحساب، يرجى المحاولة لاحقاً',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
          colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Stack(
        children: [
          // 🌌 Galactic Animated Background
          GalacticBackgroundUnified(animation: _bgAnimation),

          // 🪐 Glassmorphism Signup Container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: _buildGlassSignupCard(),
              ),
            ),
          ),

          // 🔄 Global Loading Overlay
          if (_isLoading) const SmartLoadingOverlay(isLoading: true),
        ],
      ),
    );
  }

  Widget _buildGlassSignupCard() {
    return SmartGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🚀 Header
          _buildHeader(),
          const SizedBox(height: 35),

          // 📝 Inputs
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
                const SizedBox(height: 16),
                _buildNeonTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور الجديدة',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  isObscured: _obscurePassword,
                  onToggleVisibility: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  hints: [AutofillHints.newPassword],
                ),
                const SizedBox(height: 16),
                _buildNeonTextField(
                  controller: _confirmPasswordController,
                  label: 'تأكيد كلمة المرور',
                  icon: Icons.verified_user_rounded,
                  isPassword: true,
                  isObscured: _obscureConfirmPassword,
                  onToggleVisibility: () => setState(() =>
                      _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          // ⚡ Action Button
          _buildSubmitButton(),

          const SizedBox(height: 30),

          // 🔗 Login Link
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
                Colors.purpleAccent,
                Colors.cyanAccent.withValues(alpha: 0.5)
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withValues(alpha: 0.3),
                blurRadius: 20,
              )
            ],
          ),
          child: const Icon(Icons.person_add_alt_1_rounded,
              size: 35, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'إصدار الهوية الرقمية',
          style: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          'انضم لعالم صناعة المحتوى الذكي 2026',
          style: GoogleFonts.cairo(
            color: Colors.white54,
            fontSize: 12,
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
    bool isObscured = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    Iterable<String>? hints,
  }) {
    return SmartNeonTextField(
      controller: controller,
      label: label,
      icon: icon,
      isPassword: isPassword,
      isObscured: isObscured,
      onToggleVisibility: onToggleVisibility,
      keyboardType: keyboardType,
      hints: hints,
      accentColor: Colors.purpleAccent,
    );
  }

  Widget _buildSubmitButton() {
    return SmartNeonButton(
      text: 'بدء الرحلة الإبداعية',
      isLoading: _isLoading,
      onPressed: _signup,
      gradientColors: const [Colors.purpleAccent, Color(0xFF7C4DFF)],
      shadowColor: Colors.purpleAccent.withValues(alpha: 0.2),
      textColor: Colors.white,
      borderRadius: 15.0,
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'عضو مسجل بالفعل؟',
          style: GoogleFonts.cairo(color: Colors.white38, fontSize: 13),
        ),
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'تسجيل الدخول',
            style: GoogleFonts.cairo(
              color: Colors.purpleAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

