import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit/smart_card.dart';
import '../widgets/ui_kit/smart_badge.dart';

class YoutubeSettingsForm extends StatelessWidget {
  const YoutubeSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return Column(
      children: [
        // 1. YouTube Account Status Card
        Obx(() {
          final isConnected = controller.youtubeHandle.value.isNotEmpty;

          return SmartCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_circle_fill, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "حساب يوتيوب 🎬",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            isConnected
                                ? "مرتبط كـ ${controller.youtubeHandle.value}"
                                : "غير مرتبط حالياً",
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                const Divider(height: 30, color: Colors.white10),
                const Text(
                  "ربط القناة (Handle) ✨",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                ),
                const SizedBox(height: 12),
                _buildHandleSyncField(controller),
                const SizedBox(height: 10),
                const Text(
                  "💡 أدخل المعرف الخاص بقناتك (مثل @username) لمتابعة فيديوهاتك.",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (isConnected) ...[
                  const SizedBox(height: 20),
                  _buildDisconnectButton(controller),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHandleSyncField(SettingsController controller) {
    final textController = TextEditingController(text: controller.youtubeHandle.value);
    
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: textController,
            decoration: InputDecoration(
              hintText: "@handle",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: const Icon(Icons.alternate_email, color: Colors.redAccent, size: 18),
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
            onChanged: (val) => controller.youtubeHandle.value = val.trim(),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            final handle = textController.text.trim();
            if (handle.isNotEmpty) {
              controller.updateYoutubeAccount(handle, "https://youtube.com/$handle");
              Get.snackbar("تم التحديث", "تم ربط قناة يوتيوب بنجاح ✅", 
                backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withValues(alpha: 0.2),
            foregroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text("حسناً"),
        ),
      ],
    );
  }

  Widget _buildDisconnectButton(SettingsController controller) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.white12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () => Get.defaultDialog(
        title: "فصل القناة",
        middleText: "هل أنت متأكد من فصل ربط قناة يوتيوب؟",
        textConfirm: "فصل",
        textCancel: "إلغاء",
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          controller.updateYoutubeAccount("", "");
        },
      ),
      icon: const Icon(Icons.link_off),
      label: const Text("فصل القناة"),
    );
  }
}
