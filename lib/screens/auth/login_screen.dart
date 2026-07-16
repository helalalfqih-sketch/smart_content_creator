import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/auth_controller.dart';
import '../../core/utils/error_handler.dart';
import '../../widgets/ui_kit/smart_loading_overlay.dart';
import '../../widgets/ui_kit/custom_widgets.dart';
import '../../core/strings/app_strings.dart';
import '../../theme/app_theme.dart';

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
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();
    _auth.clearError();

    if (!await ErrorHandler.hasInternetConnection()) {
      _auth.authError.value = 'لا يوجد اتصال بالإنترنت';
      return;
    }

    await _auth.loginWithValidation(
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 🌌 Galactic Animated Background
          GalacticBackgroundUnified(animation: _bgAnimation, starOpacity: 0.3),

          // 🪐 Login Container
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 450.w),
                    child: _buildLoginCard(),
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

  Widget _buildLoginCard() {
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
          // 🚀 Logo & Title
          const BrandAnchor(size: 60),
          const SizedBox(height: 24),
          Text(
            AppStrings.loginTitle,
            style: GoogleFonts.tajawal(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.appSubtitle,
            style: GoogleFonts.tajawal(
              color: AppTheme.textGrey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),

          // 📝 Input Fields
          AutofillGroup(
            child: Column(
              children: [
                SmartTextField(
                  controller: _emailController,
                  label: AppStrings.emailLabel,
                  hint: "example@mail.com",
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
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

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showForgotPasswordBottomSheet(),
              child: Text(
                AppStrings.forgotPassword,
                style: GoogleFonts.tajawal(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ⚡ Login Button
          SmartButton(
            text: AppStrings.loginButton,
            onPressed: _login,
          ),

          if (!kIsWeb) ...[
            const SizedBox(height: 24),
            _buildSocialDivider(),
            const SizedBox(height: 24),
            _buildGoogleButton(),
          ],

          const SizedBox(height: 32),

          // 🔗 Signup Link
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: TextButton(
        onPressed: () => _auth.signInWithGoogle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.login_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                AppStrings.loginWithGoogle,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'أو عبر',
            style: GoogleFonts.tajawal(color: AppTheme.textGrey, fontSize: 12),
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
          AppStrings.noAccount,
          style: GoogleFonts.tajawal(color: AppTheme.textGrey, fontSize: 14),
        ),
        TextButton(
          onPressed: () => Get.toNamed('/signup'),
          child: Text(
            AppStrings.createAccountNow,
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

  void _showForgotPasswordBottomSheet() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandAnchor(size: 40),
            const SizedBox(height: 24),
            Text(
              AppStrings.resetPasswordTitle,
              style: GoogleFonts.tajawal(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.resetPasswordHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(color: AppTheme.textGrey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SmartTextField(
              controller: resetEmailController,
              label: AppStrings.emailLabel,
              hint: "your@email.com",
              prefixIcon: Icons.email_rounded,
            ),
            const SizedBox(height: 32),
            SmartButton(
              text: 'إرسال رابط التعيين',
              onPressed: () {
                final resetEmail = resetEmailController.text.trim();
                if (resetEmail.isEmpty) return;
                _auth.requestPasswordResetOtp(resetEmail).then((ok) {
                  if (ok) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (Get.isOverlaysOpen) Get.back();
                    });
                  }
                });
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}


