import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/settings_controller.dart';
import '../services/tiktok_account_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit/smart_card.dart';
import '../widgets/ui_kit/smart_badge.dart';

class TikTokSettingsForm extends StatelessWidget {
  const TikTokSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final accountService = Get.find<TikTokAccountService>();

    return Column(
      children: [
        // 1. Connection Status Card
        Obx(() {
          final isConnected = accountService.isConnected.value;
          final profile = accountService.tiktokProfile.value;

          return SmartCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.music_note,
                          color: Color(0xFFFE2C55)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "حساب تيك توك 🎵",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            isConnected
                                ? "مرتبط كـ @${profile?['display_name'] ?? profile?['username'] ?? 'مستخدم'}"
                                : "غير مرتبط حالياً",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    SmartBadge(
                      connected: isConnected,
                      label: isConnected ? "مرتبط" : "منقطع",
                    ),
                  ],
                ),
                if (isConnected && profile != null) ...[
                  const Divider(height: 30, color: Colors.white10),
                  _buildProfileStats(profile),
                  const SizedBox(height: 20),
                  _buildDisconnectButton(accountService),
                ] else ...[
                  const Text(
                    "الطريقة الأولى: ربط سريع (username) ✨",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF88)),
                  ),
                  const SizedBox(height: 12),
                  _buildUsernameSyncField(controller),
                  const SizedBox(height: 10),
                  const Text(
                    "💡 هذه الطريقة لا تتطلب حساب مطور وتعمل فوراً.",
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 20),

        // 2. Developer & Proxy Keys (Advaced)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(color: Colors.white10, height: 30),

              // 1. Developer API
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSectionTitle("TikTok Developer API", Icons.code)),
                  TextButton(
                    onPressed: () =>
                        _launchURL("https://developers.tiktok.com/"),
                    child: const Text("إنشاء حساب مطور",
                        style:
                            TextStyle(fontSize: 11, color: Colors.blueAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "Client Key",
                icon: Icons.vpn_key,
                controller: controller.tiktokClientKey,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "Client Secret",
                icon: Icons.security,
                isSecret: true,
                controller: controller.tiktokClientSecret,
              ),

              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white10)),

              // 2. Proxy API (Apify)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSectionTitle("TikTok Scraper (Apify)", Icons.analytics)),
                  TextButton(
                    onPressed: () => _launchURL(
                        "https://console.apify.com/account/integrations"),
                    child: const Text("احصل على Token",
                        style:
                            TextStyle(fontSize: 11, color: Colors.blueAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                label: "Apify API Token",
                icon: Icons.api,
                controller: controller.tiktokApifyToken,
              ),

              const SizedBox(height: 25),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  onPressed: () => controller.saveTikTokSettings(),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text("حفظ مفاتيح المطور",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),
              // Alternative Connect (Legacy/Official)
              _buildConnectButton(accountService, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStats(Map<String, dynamic> profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem("متابعين", profile['follower_count']?.toString() ?? '0'),
        _buildStatItem(
            "تسجيلات إعجاب", profile['likes_count']?.toString() ?? '0'),
        _buildStatItem("فيديوهات", profile['video_count']?.toString() ?? '0'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildConnectButton(
      TikTokAccountService service, SettingsController settings) {
    return Column(
      children: [
        const Text(
          "الطريقة الثانية: دخول رسمي (للمطورين فقط)",
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            onPressed:
                service.isLoading.value ? null : () => service.connectTikTok(),
            icon: service.isLoading.value
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.lock_outline, size: 16),
            label: const Text("دخول رسمي (قد لا يعمل)",
                style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildDisconnectButton(TikTokAccountService service) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => Get.defaultDialog(
        title: "فصل الحساب",
        middleText: "هل أنت متأكد من فصل حساب تيك توك؟",
        textConfirm: "فصل",
        textCancel: "إلغاء",
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          service.disconnectTikTok();
        },
      ),
      icon: const Icon(Icons.link_off),
      label: const Text("فصل الحساب"),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildHeader() {
    return Row(
      children: const [
        Icon(Icons.settings_applications, color: Colors.white70, size: 20),
        SizedBox(width: 10),
        Text(
          "إعدادات المطورين (Developer API)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTextField(
      {required String label,
      required IconData icon,
      RxString? controller,
      bool isSecret = false}) {
    final textController = TextEditingController(text: controller?.value ?? '');
    if (controller != null) {
      textController.addListener(() {
        controller.value = textController.text;
      });
    }

    return TextField(
      controller: textController,
      obscureText: isSecret,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white30, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildUsernameSyncField(SettingsController controller) {
    final textController = TextEditingController(text: controller.tiktokUsername.value);
    
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: textController,
            decoration: InputDecoration(
              hintText: "@username",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF00FF88), size: 18),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (val) => controller.tiktokUsername.value = val.trim(),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            controller.updateTikTokAccount(textController.text, "https://tiktok.com/${textController.text}");
            Get.snackbar("تم التحديث", "تم ربط الحساب بنجاح ✅", 
              backgroundColor: Colors.green, colorText: Colors.white);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88).withValues(alpha: 0.2),
            foregroundColor: const Color(0xFF00FF88),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text("حسناً"),
        ),
      ],
    );
  }
}
