import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../services/secure_storage_service.dart';

class GeminiSmartAuthCard extends StatelessWidget {
  const GeminiSmartAuthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GeminiAuthConfig());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1A237E),
                  const Color(0xFF311B92)
                ] // Dark Blue/Purple
              : [AppTheme.primary, const Color(0xFF673AB7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "تفعيل Gemini AI الذكي 🚀",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'Cairo'),
                    ),
                    Text(
                      "الربط السحري (Magic UX) بنقرة واحدة",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "تجاوز التعقيدات! اربط حساب Google الآن للحصول على أفضل تجربة ذكاء اصطناعي بدون إدخال مفاتيح يدوية.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
          const SizedBox(height: 24),
          Obx(() {
            if (controller.isLinked.value) {
              return _buildConnectedState(controller, isDark);
            }
            return _buildConnectButton(controller, context, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildConnectButton(
      GeminiAuthConfig controller, BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton.icon(
        onPressed:
            controller.isLoading.value ? null : controller.connectWithGoogle,
        icon: controller.isLoading.value
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.indigo))
            : const Icon(Icons.login_rounded, size: 22),
        label: Text(
          controller.isLoading.value
              ? "جاري الاتصال بالسحابة..."
              : "ربط حساب Google الآن",
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.indigo[900],
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildConnectedState(GeminiAuthConfig controller, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "متصل وجاهز للعمل",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14),
                    ),
                    Text(
                      controller.connectedEmail.value,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black45),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.disconnect,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child:
                    const Text("قطع الاتصال", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: controller.connectWithGoogle,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(
            "تحديث صلاحيات الوصول (في حال حدوث خطأ 403)",
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

class GeminiAuthConfig extends GetxController {
  final AuthController _authController = Get.find<AuthController>();
  final SecureStorageService _secureStorage = Get.find<SecureStorageService>();

  var isLoading = false.obs;

  RxBool get isLinked => (_authController.geminiAccessToken.isNotEmpty).obs;
  RxString get connectedEmail => _authController.geminiAccessToken.isNotEmpty
      ? "نشط (عبر Google)".obs
      : "".obs;

  @override
  void onInit() {
    super.onInit();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final token = await _secureStorage.getGeminiToken();
    if (token.isNotEmpty && _authController.geminiAccessToken.isEmpty) {
      _authController.geminiAccessToken.value = token;
    }
  }

  Future<void> connectWithGoogle() async {
    try {
      isLoading.value = true;
      // 🚀 استخدام الميثود المخصصة لربط Gemini فقط
      await _authController.linkGeminiWithGoogle();
    } catch (error) {
      Get.snackbar(
        "خطأ في التفعيل",
        "حدث خطأ أثناء محاولة الاتصال: $error",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void disconnect() async {
    await _secureStorage.deleteGeminiToken();
    _authController.geminiAccessToken.value = "";
    // Note: We don't sign out of Google here as it might be their main app account
  }
}
