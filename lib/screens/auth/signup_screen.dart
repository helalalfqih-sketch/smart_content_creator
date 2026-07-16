import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/error_handler.dart';
import '../../widgets/ui_kit/smart_loading_overlay.dart';
import '../../widgets/ui_kit/custom_widgets.dart';
import '../../core/strings/app_strings.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = Get.find<AuthController>();
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    _auth.clearError();

    if (!await ErrorHandler.hasInternetConnection()) {
      _auth.authError.value = 'لا يوجد اتصال بالإنترنت';
      return;
    }

    await _auth.signUpWithValidation(
      _emailController.text,
      _passwordController.text,
      _confirmPasswordController.text,
      _nameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 🌌 Galactic Animated Background
          GalacticBackgroundUnified(animation: _bgAnimation),

          // 🪐 Signup Container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: _buildSignupCard(),
              ),
            ),
          ),

          // 🔄 Global Loading Overlay
          Obx(() => SmartLoadingOverlay(isLoading: _auth.isLoading.value)),
        ],
      ),
    );
  }

  Widget _buildSignupCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🚀 Header
          const BrandAnchor(size: 60),
          const SizedBox(height: 24),
          Text(
            AppStrings.signupTitle,
            style: GoogleFonts.tajawal(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.signupSubtitle,
            style: GoogleFonts.tajawal(
              color: AppTheme.textGrey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),

          // 📝 Inputs
          AutofillGroup(
            child: Column(
              children: [
                SmartTextField(
                  controller: _nameController,
                  label: AppStrings.nameLabel,
                  hint: "الاسم الكامل",
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 16),
                SmartTextField(
                  controller: _emailController,
                  label: AppStrings.emailLabel,
                  hint: "your@email.com",
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                SmartTextField(
                  controller: _passwordController,
                  label: AppStrings.passwordLabel,
                  hint: "••••••••",
                  isPassword: _obscurePassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textGrey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),
                SmartTextField(
                  controller: _confirmPasswordController,
                  label: AppStrings.confirmPasswordLabel,
                  hint: "••••••••",
                  isPassword: _obscureConfirmPassword,
                  prefixIcon: Icons.verified_user_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textGrey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final error = _auth.authError.value;
                  if (error == null || error.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error,
                      style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ⚡ Action Button
          SmartButton(
            text: AppStrings.signupButton,
            onPressed: _signup,
          ),

          const SizedBox(height: 24),

          // 🔗 Login Link
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.alreadyHaveAccount,
          style: GoogleFonts.tajawal(color: AppTheme.textGrey, fontSize: 14),
        ),
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            AppStrings.goToLogin,
            style: GoogleFonts.tajawal(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}


