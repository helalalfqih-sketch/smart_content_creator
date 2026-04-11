import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ui_kit/smart_card.dart';
import '../core/utils/snackbar_utils.dart';
import '../widgets/permission_controlled_widget.dart';
import '../controllers/theme_controller.dart';
import '../controllers/settings_controller.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading:
              false, // 🛡️ منع زر الرجوع في سياق التنقل الموحد
          title: const Text('الإعدادات العامة ⚙️'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌙 Theme Settings Section
                GetBuilder<ThemeController>(
                  builder: (themeController) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المظهر 🎨',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        SmartCard(
                          child: SwitchListTile(
                            value: themeController.isDarkMode,
                            onChanged: (value) => themeController.toggleTheme(),
                            title: const Text(
                              'الوضع الليلي',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              themeController.isDarkMode
                                  ? 'مفعّل - راحة للعين في الإضاءة المنخفضة'
                                  : 'غير مفعّل - مظهر نهاري مشرق',
                            ),
                            secondary: Icon(
                              themeController.isDarkMode
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                              color: themeController.isDarkMode
                                  ? Colors.deepPurple
                                  : Colors.amber,
                            ),
                            activeThumbColor: Colors.deepPurple,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 🔑 API Keys Settings Link (Dynamic Permission)
                VisibilityControlled(
                  controlName: 'api_settings_screen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المطورين والمفاتيح 🗝️',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      SmartCard(
                        child: ListTile(
                          leading: const Icon(Icons.vpn_key_outlined,
                              color: Colors.orange),
                          title: const Text('إدارة مفاتيح API',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              const Text('Google Gemini, OpenAI, TikTok...'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Get.toNamed('/api-settings'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ⚖️ About & Legal
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'عن التطبيق والقانون ⚖️',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SmartCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.support_agent,
                              color: Colors.green),
                          title: const Text('الدعم الفني (WhatsApp) واتساب ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('تواصل معنا مباشرة للمساعدة'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () async {
                            final url = Uri.parse('https://wa.me/967771370740');
                            if (!await launchUrl(url,
                                mode: LaunchMode.externalApplication)) {
                              if (context.mounted) {
                                SnackBarUtils.showError(
                                    'خطأ', 'لا يمكن فتح تطبيق WhatsApp');
                              }
                            }
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined,
                              color: Colors.blue),
                          title: const Text('سياسة الخصوصية',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('كيفية حماية بياناتك ومعالجتها'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Get.toNamed('/privacy'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.description_outlined,
                              color: Colors.orange),
                          title: const Text('شروط الاستخدام',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              const Text('القواعد المنظمة لاستخدام التطبيق'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Get.toNamed('/terms'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.email_outlined,
                              color: Colors.red),
                          title: const Text('الدعم الفني عبر البريد',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('support@smartcc.ai'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () async {
                            final url = Uri.parse(
                                'mailto:support@smartcc.ai?subject=Support Request');
                            if (!await launchUrl(url)) {
                              SnackBarUtils.showError(
                                  'خطأ', 'لا يمكن فتح تطبيق البريد');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // 🚀 Updates & Sharing
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التحديثات والمشاركة 🚀',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SmartCard(
                      child: GetBuilder<SettingsController>(
                          init: Get.find<SettingsController>(),
                          builder: (settingsController) {
                            return Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.share,
                                      color: Colors.blue),
                                  title: const Text('مشاركة التطبيق',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle:
                                      const Text('أرسل رابط التحميل لأصدقائك'),
                                  trailing:
                                      const Icon(Icons.ios_share, size: 18),
                                  onTap: () => settingsController.shareApp(),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.update,
                                      color: Colors.purple),
                                  title: const Text('تحديث التطبيق الآن',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle:
                                      const Text('تحقق من وجود إصدار جديد'),
                                  trailing: const Icon(Icons.refresh, size: 18),
                                  onTap: () => settingsController
                                      .checkForUpdate(manual: true),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.info_outline,
                                      color: Colors.grey),
                                  title: const Text('الإصدار الحالي'),
                                  trailing: const Text(
                                      SettingsController.currentVersion,
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          }),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
