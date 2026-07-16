import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import '../../widgets/ui_kit/custom_widgets.dart';
import '../../core/utils/auth_validation.dart';
import '../../widgets/ui_kit/smart_loading_overlay.dart';
import '../../theme/app_theme.dart';
import '../../core/strings/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PasswordResetOtpScreen extends StatefulWidget {
  final String email;

  const PasswordResetOtpScreen({super.key, required this.email});

  @override
  State<PasswordResetOtpScreen> createState() => _PasswordResetOtpScreenState();
}

class _PasswordResetOtpScreenState extends State<PasswordResetOtpScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _auth = Get.find<AuthController>();

  late AnimationController _bgAnimation;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

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
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (otp.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال رمز التحقق.');
      return;
    }

    final passError = AuthValidation.validatePassword(newPass) ??
        AuthValidation.validateConfirmPassword(newPass, confirm);
    if (passError != null) {
      Get.snackbar('تنبيه', passError);
      return;
    }

    final success = await _auth.confirmPasswordResetWithOtp(
      email: widget.email,
      otp: otp,
      newPassword: newPass,
    );

    if (success) {
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          GalacticBackgroundUnified(animation: _bgAnimation, starOpacity: 0.3),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandAnchor(size: 60),
                          const SizedBox(height: 24),
                          Text(
                            AppStrings.resetPasswordTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'أدخل رمز التحقق المرسل لبريدك ثم عيّن كلمة مرور جديدة.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              color: AppTheme.textGrey,
                            ),
                          ),
                          const SizedBox(height: 32),
                          SmartTextField(
                            controller: _otpController,
                            label: 'رمز التحقق',
                            hint: "000000",
                            prefixIcon: Icons.password_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SmartTextField(
                            controller: _newPasswordController,
                            label: AppStrings.passwordLabel,
                            hint: "••••••••",
                            isPassword: _obscureNewPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.textGrey,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SmartTextField(
                            controller: _confirmPasswordController,
                            label: AppStrings.confirmPasswordLabel,
                            hint: "••••••••",
                            isPassword: _obscureConfirmPassword,
                            prefixIcon: Icons.verified_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.textGrey,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Obx(() => SmartButton(
                                text: 'تأكيد',
                                isLoading: _auth.isLoading.value,
                                onPressed: _confirmReset,
                              )),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Obx(() => SmartLoadingOverlay(isLoading: _auth.isLoading.value)),
        ],
      ),
    );
  }
}

