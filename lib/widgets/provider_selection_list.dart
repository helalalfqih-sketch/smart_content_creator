import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';

class ProviderSelectionList extends StatelessWidget {
  const ProviderSelectionList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── قسم المحادثة (Text Models) ───
          _buildSectionHeader("نماذج المحادثة الذكية 💬"),

          _buildProviderItem(
            controller,
            label: "Claude (Anthropic)",
            icon: Icons.explore_outlined,
            providerKey: 'anthropic',
            role: 'text',
            activeColor: Colors.greenAccent,
          ),
          _divider(),

          _buildProviderItem(
            controller,
            label: "OpenRouter (Gemini/Video)",
            icon: Icons.traffic_outlined,
            providerKey: 'openrouter',
            role: 'text',
            activeColor: Colors.blueAccent,
          ),
          _divider(),

          _buildProviderItem(
            controller,
            label: "OpenAI (GPT-4)",
            icon: Icons.psychology_outlined,
            providerKey: 'openai',
            role: 'text',
            activeColor: Colors.greenAccent,
          ),
          _divider(),

          _buildProviderItem(
            controller,
            label: "Microsoft Azure (OpenAI)",
            icon: Icons.cloud_queue_outlined,
            providerKey: 'azure',
            role: 'text',
            activeColor: Colors.blueAccent,
          ),
          _divider(),
          
          _buildProviderItem(
            controller,
            label: "Google AI Mode (SerpApi)",
            icon: Icons.travel_explore_rounded,
            providerKey: 'serpapi',
            role: 'text',
            activeColor: Colors.tealAccent,
          ),

          // ─── قسم الفيديو والصور (Media Models) ───
          const SizedBox(height: 10),
          _buildSectionHeader("استوديو الوسائط 🎬"),

          _buildProviderItem(
            controller,
            label: "Kling AI (Video)",
            icon: Icons.movie_filter_outlined,
            providerKey: 'kling',
            role: 'video',
            activeColor: Colors.purpleAccent,
          ),
          _divider(),

          _buildProviderItem(
            controller,
            label: "Higgsfield AI (Video)",
            icon: Icons.video_camera_back_outlined,
            providerKey: 'higgsfield',
            role: 'video',
            activeColor: Colors.deepPurpleAccent,
          ),
          _divider(),

          _buildProviderItem(
            controller,
            label: "Stability AI (Image)",
            icon: Icons.palette_outlined,
            providerKey: 'stability',
            role: 'image',
            activeColor: Colors.orangeAccent,
          ),

          // ─── قسم الأدوات (Tools) ───
          const SizedBox(height: 10),
          _buildSectionHeader("أدوات مساعدة 🛠️"),

          _buildProviderItem(
            controller,
            label: "Remove.bg (Background)",
            icon: Icons.content_cut_rounded,
            providerKey: 'removebg',
            role: 'tool',
            activeColor: Colors.redAccent,
          ),

          // ─── قسم التواصل الاجتماعي (Social) ───
          const SizedBox(height: 10),
          _buildSectionHeader("منصات التواصل 📱"),

          _buildProviderItem(
            controller,
            label: "YouTube Integration",
            icon: Icons.play_circle_fill,
            providerKey: 'youtube',
            role: 'social',
            activeColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 15, top: 10, bottom: 5),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
        color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 50);
  }

  Widget _buildProviderItem(
    SettingsController controller, {
    required String label,
    required IconData icon,
    required String providerKey,
    required String role, // 'text', 'video', 'image', 'tool', 'social'
    required Color activeColor,
  }) {
    return Obx(() {
      bool isActive = false;
      String statusText = "";

      // 👇 المنطق الذكي لتحديد الحالة بناءً على نوع الخدمة
      bool isConfigured = controller.hasKey(providerKey);

      if (role == 'text') {
        // للنصوص: يجب أن يكون هو المختار في activeTextProvider
        try {
          final type =
              ProviderType.values.firstWhere((e) => e.name == providerKey);
          bool isConnected = controller.getConnectionStatus(type);

          if (controller.activeTextProvider.value == type) {
            isActive = true;
            statusText =
                isConnected ? "نشط حالياً (نصوص) ✅" : "نشط مع وجود عطل ⚠️";
          } else if (isConfigured) {
            statusText = isConnected ? "جاهز للاستخدام ✅" : "فشل في الربط ❌";
          }
        } catch (_) {}
      } else if (role == 'video') {
        try {
          final type = ProviderType.values.firstWhere(
              (e) => e.name == providerKey,
              orElse: () => ProviderType.custom);
          bool isConnected = controller.getConnectionStatus(type);
          if (isConfigured) {
            isActive = true;
            statusText = isConnected ? "جاهز للتوليد 🎥" : "خطأ في الاتصال ⚠️";
          }
        } catch (_) {}
      } else if (role == 'tool' || role == 'image' || role == 'social') {
        if (isConfigured) {
          isActive = true;
          if (providerKey == 'tiktok') {
            if (controller.isTikTokConnected) {
              isActive = true;
              statusText = "متصل ✅";
            } else {
              isActive = false;
              statusText = controller.tiktokError.value.isNotEmpty
                  ? "فشل الاتصال ❌"
                  : "غير متصل ⚠️";
            }
          } else {
            // 🛡️ فحص حالة الاتصال الفعلية للأدوات والصور
            try {
              final type =
                  ProviderType.values.firstWhere((e) => e.name == providerKey);
              bool isConnected = controller.getConnectionStatus(type);

              if (isConnected) {
                statusText = "متصل ✅";
              } else {
                statusText = "غير متصل ❌";
                isActive = false; // Force inactive UI
              }
            } catch (_) {
              statusText = "غير معروف ❓";
              isActive = false;
            }
          }
        }
      }

      if (!isConfigured && statusText.isEmpty) {
        statusText = "غير مهيأ - مفقود 🔑";
      }

      // هل العنصر مضغوط عليه حالياً للتعديل؟
      bool isSelected = controller.selectedProvider.value == providerKey;

      return ListTile(
        onTap: () => controller.changeProvider(providerKey),
        tileColor: isSelected ? activeColor.withValues(alpha: 0.1) : null,
        dense: true,
        leading: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: activeColor.withValues(alpha: 0.5))
                    : null,
              ),
              child: Icon(icon,
                  color:
                      (isActive || isConfigured) ? activeColor : Colors.white54,
                  size: 20),
            ),
            // 🟢🔴 "لمبة" الحالة الذكية
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isConfigured
                      ? (providerKey == 'tiktok'
                          ? (controller.isTikTokConnected
                              ? Colors.green
                              : Colors.orange)
                          : (controller.getConnectionStatus(ProviderType.values
                                  .firstWhere((e) => e.name == providerKey,
                                      orElse: () => ProviderType.custom))
                              ? Colors.green
                              : Colors.orange))
                      : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          label,
          style: TextStyle(
            color: (isActive || isConfigured) ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(
              color: isConfigured
                  ? activeColor.withValues(alpha: 0.7)
                  : Colors.red.withValues(alpha: 0.7),
              fontSize: 11),
        ),
        trailing: isSelected
            ? Icon(Icons.edit, color: activeColor, size: 18)
            : const Icon(Icons.arrow_forward_ios,
                color: Colors.white10, size: 14),
      );
    });
  }
}
