import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit/smart_card.dart';
import '../widgets/ui_kit/smart_badge.dart';

class FacebookSettingsForm extends StatelessWidget {
  const FacebookSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return Column(
      children: [
        Obx(() {
          final isConnected = controller.fbPageId.value.isNotEmpty;

          return SmartCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "صفحة فيسبوك للنشر 📢",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'IBMPlexSansArabic'),
                          ),
                          Text(
                            isConnected
                                ? "متصل بالصفحة: ${controller.fbPageName.value}"
                                : "غير متصل حالياً",
                            style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'IBMPlexSansArabic'),
                          ),
                        ],
                      ),
                    ),
                    SmartBadge(
                      connected: isConnected,
                      label: isConnected ? "متصل" : "غير متصل",
                    ),
                  ],
                ),
                const Divider(height: 30, color: Colors.white10),
                
                const Text(
                  "ربط حساب فيسبوك وجلب الصفحات 🔑",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1877F2), fontFamily: 'IBMPlexSansArabic'),
                ),
                const SizedBox(height: 12),
                _buildTokenField(controller),
                const SizedBox(height: 10),
                const Text(
                  "💡 أدخل رمز الوصول للمستخدم (User Access Token) المستخرج من Graph API Explorer لجلب صفحاتك.",
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'IBMPlexSansArabic'),
                ),
                const SizedBox(height: 20),
                
                _buildPagesSelector(controller),

                if (isConnected) ...[
                  const Divider(height: 40, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "معلومات الصفحة المرتبطة:",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'IBMPlexSansArabic'),
                      ),
                      Text(
                        "معرف الصفحة: ${controller.fbPageId.value}",
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'IBMPlexSansArabic'),
                      ),
                    ],
                  ),
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

  Widget _buildTokenField(SettingsController controller) {
    final textController = TextEditingController(text: controller.fbUserToken.value);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: textController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "EAAb962q...",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF1877F2), size: 18),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            onChanged: (val) => controller.fbUserToken.value = val.trim(),
          ),
        ),
        const SizedBox(width: 10),
        Obx(() => ElevatedButton(
              onPressed: controller.isFetchingFbPages.value
                  ? null
                  : () {
                      final token = textController.text.trim();
                      if (token.isNotEmpty) {
                        controller.saveFacebookUserToken(token);
                      } else {
                        Get.snackbar("تنبيه", "الرجاء إدخال الرمز أولاً");
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2),
                foregroundColor: const Color(0xFF1877F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              child: controller.isFetchingFbPages.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Color(0xFF1877F2), strokeWidth: 2),
                    )
                  : Text(
                      controller.fbUserToken.value.isNotEmpty ? "تحديث 🔄" : "ربط ⚡",
                      style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
                    ),
            )),
      ],
    );
  }

  Widget _buildPagesSelector(SettingsController controller) {
    return Obx(() {
      if (controller.fbPagesList.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "اختر الصفحة المطلوبة للنشر:",
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'IBMPlexSansArabic'),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.fbPagesList.length,
              itemBuilder: (context, index) {
                final page = controller.fbPagesList[index];
                final pageId = page['id'] ?? '';
                final pageName = page['name'] ?? '';
                final pageToken = page['access_token'] ?? '';
                final category = page['category'] ?? '';
                final isSelected = pageId == controller.fbPageId.value;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  title: Text(
                    pageName,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF1877F2) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                  subtitle: Text(category, style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'IBMPlexSansArabic')),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1877F2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Color(0xFF1877F2), size: 14),
                              SizedBox(width: 4),
                              Text(
                                "نشطة",
                                style: TextStyle(
                                  color: Color(0xFF1877F2),
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            controller.saveSelectedFacebookPage(pageId, pageName, pageToken);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1877F2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text(
                            "تحديد ونشر عليها 🔌",
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      );
    });
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
        title: "إلغاء ربط الصفحة",
        middleText: "هل أنت متأكد من فصل ربط صفحة فيسبوك؟ لن تتمكن من النشر التلقائي عليها حتى تعيد ربطها.",
        textConfirm: "فصل الربط",
        textCancel: "إلغاء",
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          controller.disconnectFacebook();
        },
      ),
      icon: const Icon(Icons.link_off),
      label: const Text("فصل ربط صفحة فيسبوك", style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
