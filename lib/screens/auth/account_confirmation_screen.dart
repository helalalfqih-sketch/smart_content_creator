import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/animations/galactic_background_unified.dart';
import '../../widgets/ui_kit/custom_widgets.dart';
import '../../core/strings/app_strings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit/smart_loading_overlay.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AccountConfirmationScreen extends StatefulWidget {
  const AccountConfirmationScreen({super.key});

  @override
  State<AccountConfirmationScreen> createState() => _AccountConfirmationScreenState();
}

class _AccountConfirmationScreenState extends State<AccountConfirmationScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _auth = Get.find<AuthController>();
  late AnimationController _bgAnimation;

  late String email;
  late String password;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    // Get arguments passed from signup
    final args = Get.arguments as Map<String, dynamic>?;
    email = args?['email'] ?? '';
    password = args?['password'] ?? '';
  }

  @override
  void dispose() {
    _otpController.dispose();
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _confirmAccount() async {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال رمز التحقق المكون من 6 أرقام');
      return;
    }

    final success = await _auth.confirmRegistrationOtp(
      email: email,
      otp: otp,
      password: password,
    );

    if (success) {
      Get.snackbar(
        'تم بنجاح',
        AppStrings.confirmAccountSuccess,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
        colorText: Colors.white,
      );
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
                          AppStrings.confirmAccountTitle,
                          style: GoogleFonts.tajawal(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${AppStrings.confirmAccountOtpHint}\n$email',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            color: AppTheme.textGrey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 35),
                        SmartTextField(
                          controller: _otpController,
                          label: 'رمز التحقق',
                          hint: "000000",
                          prefixIcon: Icons.security_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 32),
                        Obx(() => SmartButton(
                              text: "تأكيد الحساب",
                              isLoading: _auth.isLoading.value,
                              onPressed: _confirmAccount,
                            )),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => _auth.requestRegistrationOtp(email),
                          child: Text(
                            'إرسال الرمز مرة أخرى',
                            style: GoogleFonts.tajawal(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
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

