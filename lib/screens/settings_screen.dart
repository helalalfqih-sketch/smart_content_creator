import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/settings_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/admin_controller.dart';
import '../services/activity_tracking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit/smart_card.dart';
import '../widgets/ui_kit/smart_badge.dart';
import '../services/gatekeeper_service.dart';
import '../core/models/api_provider.dart';

// Widgets المستوردة
import '../widgets/provider_selection_list.dart';
import '../widgets/standard_provider_form.dart';
import '../widgets/tiktok_settings_form.dart';
import '../widgets/youtube_settings_form.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text('إعدادات الخدمات'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ManagedAiCreditsWidget(
                  settingsController: settingsController,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // 🆕 New Last Used Providers Card!
                _LastUsedProvidersCard(
                  controller: settingsController,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // 💳 SerpApi Quota Monitoring Widget
                Obx(() {
                  if (settingsController.selectedProvider.value ==
                      ProviderType.serpapi.name) {
                    return _SerpApiQuotaWidget(
                      settingsController: settingsController,
                      isDark: isDark,
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 20),
                Obx(() {
                  final auth = Get.find<AuthController>();
                  final gatekeeper = Get.find<GatekeeperService>();

                  // التحقق من الصلاحيات
                  final bool showCustomKeys = auth.isAdmin ||
                      auth.isPremium ||
                      gatekeeper.checkPermission('api_settings_screen');

                  if (!showCustomKeys) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AiGatewayControlCenterCard(
                        controller: settingsController,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      // 🆕 Primary AI Keys Section (Gemini & GitHub)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مركز التحكم في الخدمات',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'قم بتفعيل وإدارة مفاتيح API لكل خدمة بناءً على دورها.',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 🆕 Primary AI Keys Section (Gemini & GitHub)
                      Column(
                        children: [
                          _buildApiSettingsTile(
                            context: context,
                            title: "خدمة Google AI (Gemini)",
                            icon: Icons.auto_awesome,
                            type: ProviderType.gemini,
                            settingsController: settingsController,
                          ),
                          const SizedBox(height: 12),
                          _buildApiSettingsTile(
                            context: context,
                            title: "خدمة GitHub AI (GPT-4o)",
                            icon: Icons.code,
                            type: ProviderType.github,
                            settingsController: settingsController,
                            hintText: "ghp_...",
                          ),
                          const SizedBox(height: 12),
                          _buildApiSettingsTile(
                            context: context,
                            title: "خدمة OpenRouter (Veo/Gemini)",
                            icon: Icons.traffic_outlined,
                            type: ProviderType.openrouter,
                            settingsController: settingsController,
                            hintText: "sk-or-v1-...",
                          ),
                          const SizedBox(height: 12),
                          _buildApiSettingsTile(
                            context: context,
                            title: "بوت تيليجرام (نشر تلقائي)",
                            icon: Icons.telegram,
                            type: ProviderType.telegram,
                            settingsController: settingsController,
                            hintText: "7xxx:xxxx...",
                            subtitle: "احصل على التوكن من @BotFather 🤖",
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        'باقي المزودين',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      // 1. القائمة العلوية للاختيار (للمزودين الإضافيين)
                      const ProviderSelectionList(),

                      const SizedBox(height: 24),

                      // 🆕 Jina AI Reader Toggle
                      _JinaSettingsWidget(
                          settingsController: settingsController,
                          isDark: isDark),

                      const SizedBox(height: 24),

                      // 2. النموذج الديناميكي المتغير
                      Obx(() {
                        final selected =
                            settingsController.selectedProvider.value;
                        if (selected.isEmpty) return const SizedBox.shrink();

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: KeyedSubtree(
                            key: ValueKey(selected),
                            child: _buildDynamicForm(selected),
                          ),
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 32),

                // ℹ️ Hidden Models & Smart Routing Info
                const _HiddenModelsInfoWidget(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🛠️ دالة المصنع التي تقرر أي نموذج يتم عرضه
  Widget _buildDynamicForm(String selected) {
    // حالة خاصة لتيك توك
    if (selected == 'tiktok') {
      return const TikTokSettingsForm();
    }
    if (selected == 'youtube') {
      return const YoutubeSettingsForm();
    }

    // الحالة الافتراضية لباقي المزودين (Gemini, Kling, etc)
    try {
      // نحاول تحويل النص إلى Enum، إذا فشل نعيد فراغ
      final type = ProviderType.values.firstWhere(
        (e) => e.name == selected,
        orElse: () => ProviderType.gemini,
      );

      return StandardProviderForm(providerType: type);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildApiSettingsTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required ProviderType type,
    required SettingsController settingsController,
    String? hintText,
    String? subtitle,
  }) {
    return Obx(() {
      final key = settingsController.getApiKey(type);
      final isConnected = settingsController.getConnectionStatus(type);

      return SmartCard(
        onTap: () => _showKeyInputDialog(
          context: context,
          providerName: title,
          type: type,
          settingsController: settingsController,
          hintText: hintText,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (subtitle != null && key.isEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  Text(
                    key.isEmpty
                        ? 'لم يتم إعداد المفتاح'
                        : '••••••••${key.length > 4 ? key.substring(key.length - 4) : ""}',
                    style: TextStyle(
                      color: key.isEmpty
                          ? Colors.grey
                          : Colors.green.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  if (!isConnected && settingsController.providerErrors[type] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: InkWell(
                        onTap: () {
                          final url = type.dashboardUrl ?? type.apiKeyUrl;
                          launchUrl(Uri.parse(url));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline, color: Colors.redAccent, size: 10),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${settingsController.providerErrors[type]!} (اضغط للإصلاح 🛠️)",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.redAccent, 
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SmartBadge(
              connected: isConnected,
              label: isConnected ? 'متصل' : 'غير متصل',
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      );
    });
  }

  void _showKeyInputDialog({
    required BuildContext context,
    required String providerName,
    required ProviderType type,
    required SettingsController settingsController,
    String? hintText,
  }) {
    // 🗝️ Hexa-Key Logic (6 keys for GitHub)
    final bool isHexaKey = type == ProviderType.github;
    final bool isDualKey = type.requiresSecretKey;

    // Create controllers for all possible keys (up to 6)
    final List<TextEditingController> controllers = List.generate(
      isHexaKey ? 6 : (isDualKey ? 2 : 1),
      (index) {
        if (isHexaKey) {
          return TextEditingController(
              text: index < settingsController.githubKeys.length
                  ? settingsController.githubKeys[index]
                  : "");
        }
        if (index == 0) {
          return TextEditingController(text: settingsController.getApiKey(type));
        } else {
          return TextEditingController(
              text: settingsController.providerSecrets[type] ?? "");
        }
      },
    );

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 5,
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isHexaKey
                          ? "نظام المفاتيح السداسي (Hexa-Key)"
                          : "إعداد مفتاح الـ API يدوياً",
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                "المزود: $providerName",
                style: const TextStyle(color: Colors.grey),
              ),
              if (isHexaKey)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "💡 أدخل حتى 6 مفاتيح للتبديل التلقائي عند استنفاد الرصيد.",
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),

              if (type.dashboardUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: () => launchUrl(Uri.parse(type.dashboardUrl!)),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "للحصول على مفتاح جديد لـ ${type.displayName}، اضغط هنا.",
                              style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 📋 Render Inputs
              ...List.generate(controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: controllers[index],
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: isHexaKey
                          ? "GitHub Key ${index + 1}"
                          : (index == 0
                              ? (type == ProviderType.higgsfield
                                  ? "API Key ID"
                                  : (type == ProviderType.kling
                                      ? "Access Key"
                                      : (type == ProviderType.telegram
                                          ? "Bot Token"
                                          : "API Key")))
                              : (type == ProviderType.higgsfield
                                  ? "Access Token (Secret)"
                                  : (type == ProviderType.telegram
                                      ? "Chat ID / Channel ID"
                                      : "Secret Key"))),
                      labelStyle:
                          const TextStyle(color: Colors.white30, fontSize: 13),
                      hintText: hintText ?? "أدخل المفتاح هنا...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: Icon(
                          isHexaKey ? Icons.numbers : Icons.vpn_key,
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          size: 20),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                            color: Color(0xFF2D2D2D), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                            color: Color(0xFF2D2D2D), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    if (isHexaKey) {
                      final keys = controllers.map((c) => c.text).toList();
                      await settingsController.saveGithubKeys(keys);
                    } else {
                      final key = controllers.first.text.trim();
                      String? secret;
                      if (controllers.length > 1) {
                        secret = controllers[1].text.trim();
                      }

                      if (key.isEmpty) {
                        Get.snackbar("تنبيه", "الرجاء إدخال المفتاح أولاً");
                        return;
                      }

                      await settingsController.saveApiKey(type, key);
                      if (secret != null && secret.isNotEmpty) {
                        await settingsController.saveSecretKey(type, secret);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "حفظ",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 🆕 تعيين كافتراضي لكل مزود
              Obx(() {
                final currentKey = settingsController.getApiKey(type);
                if (currentKey.isEmpty && !isHexaKey) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Get.back();
                      await settingsController.makeDefault(type);
                    },
                    icon: const Icon(Icons.star_border, color: Colors.amber),
                    label: const Text(
                      "تعيين كافتراضي",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.amber.withValues(alpha: 0.5),
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text(
                "سيتم تشفير المفتاح وحفظه محلياً على جهازك فقط لضمان الخصوصية.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
    );
  }
}

class _ManagedAiCreditsWidget extends StatelessWidget {
  final SettingsController settingsController;
  final bool isDark;

  const _ManagedAiCreditsWidget({
    required this.settingsController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final credits = settingsController.remainingCredits.value;
      final isTrial = settingsController.isTrialActive.value;
      const maxCredits = 50.0;
      final progress = (credits / maxCredits).clamp(0.0, 1.0);

      return SmartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.psychology, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النظام المدار',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        isTrial ? 'فترة تجريبية' : 'الباقة النشطة',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SmartBadge(
                  connected: credits > 0,
                  label: credits > 0 ? 'نشط' : 'استنفذ',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar Logic...
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('أرصدة الاستخدام المتبقية',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                Text(
                  '$credits / ${maxCredits.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: credits < 10 ? Colors.red : AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  credits < 10 ? Colors.red : AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SerpApiQuotaWidget extends StatelessWidget {
  final SettingsController settingsController;
  final bool isDark;

  const _SerpApiQuotaWidget({
    required this.settingsController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final searchesLeft = settingsController.serpApiSearchesLeft.value;
      final monthlyLimit = settingsController.serpApiMonthlyLimit.value;
      final usage = settingsController.serpApiUsage.value;
      final isChecking = settingsController.isCheckingSerpApi.value;

      // Calculate progress (Searches Left / Total Limit)
      double progress = 0;
      if (monthlyLimit > 0) {
        progress = (searchesLeft / monthlyLimit).clamp(0.0, 1.0);
      }

      return SmartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رصيد SerpApi',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'مراقبة الحساب المباشرة',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isChecking
                      ? null
                      : () => settingsController.checkSerpApiStatus(),
                  icon: isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('عمليات البحث المتبقية',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13)),
                ),
                Text(
                  '$searchesLeft / $monthlyLimit',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تم استهلاك $usage طلب بحث هذا الشهر',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      );
    });
  }
}

class _JinaSettingsWidget extends StatelessWidget {
  final SettingsController settingsController;
  final bool isDark;

  const _JinaSettingsWidget({
    required this.settingsController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SmartCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_fix_high, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قارئ الروابط الذكي (Jina AI)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'استخراج بيانات المنتج تلقائياً عند مشاركة الروابط',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Obx(() => Switch(
                value: settingsController.isJinaEnabled.value,
                onChanged: (val) => settingsController.toggleJina(val),
                activeThumbColor: Colors.orange,
                activeTrackColor: Colors.orange.withValues(alpha: 0.3),
              )),
        ],
      ),
    );
  }
}

class _HiddenModelsInfoWidget extends StatelessWidget {
  const _HiddenModelsInfoWidget();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.blue.withValues(alpha: 0.05)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'ما الذي "لا يظهر" (الموديلات المخفية)؟ 🔍',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            'فئات Gemini الفرعية:',
            'موديلات (flash-8b, 1.5-flash, 2.0-flash) تعمل تلقائياً "خلف الكواليس" كأنظمة بديلة (Fallback) عند فشل الموديل الأساسي لضمان استمرار الخدمة.',
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            'نظام التوجيه الذكي (Smart Routing):',
            'عند إدخال مفتاح يبدأ بـ (sk-or-) أو (ghp-) في حقل Gemini، سيقوم التطبيق تلقائياً بتوجيه الطلب للمزود الصحيح (OpenRouter أو GitHub) وإتاحة موديلات GPT-4o و Gemini 2.0 دون الحاجة لتبويب مستقل.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ☁️ AI Gateway Control Center Card Widget
class _AiGatewayControlCenterCard extends StatelessWidget {
  final SettingsController controller;
  final bool isDark;

  const _AiGatewayControlCenterCard({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    if (!auth.isAdmin) return const SizedBox.shrink();

    // Auto-fetch diagnostic data if health is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.serverHealth.isEmpty && !controller.isLoadingHealth.value) {
        controller.refreshAllDiagnostics();
      }
    });

    return Obx(() {
      final health = controller.serverHealth;
      final keys = controller.serverKeys;
      
      final activeCount = keys.where((k) => k['code'] == 200).length;
      final totalCount = keys.length;

      final isHealthy = health['status'] == 'healthy' || health['status'] == 'operational';
      final statusText = isHealthy ? 'مستقر 🟢' : 'فحص... ⏳';
      final latency = controller.gatewayLatency.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [
                    Colors.blue.withValues(alpha: 0.12),
                    Colors.purple.withValues(alpha: 0.12),
                  ]
                : [
                    Colors.blue.withValues(alpha: 0.04),
                    Colors.purple.withValues(alpha: 0.04),
                  ],
          ),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.speed_rounded, color: Colors.blueAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Cloud Gateway Control Center',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                          ),
                          const Text(
                            'لوحة تشخيص ومراقبة البوابة السحابية الفنية',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (controller.isLoadingHealth.value || controller.isLoadingKeys.value)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent, size: 20),
                      onPressed: () => controller.refreshAllDiagnostics(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Metrics Grid/Row
              Row(
                children: [
                  _buildMetricItem(
                    title: 'حالة الخادم',
                    value: statusText,
                    color: isHealthy ? Colors.green : Colors.orange,
                  ),
                  _buildDivider(),
                  _buildMetricItem(
                    title: 'سرعة الاستجابة',
                    value: latency == 0 ? '---' : '${latency}ms ⚡',
                    color: latency == 0 
                        ? Colors.grey 
                        : (latency < 400 
                            ? Colors.greenAccent 
                            : (latency < 1200 ? Colors.orangeAccent : Colors.redAccent)),
                  ),
                  _buildDivider(),
                  _buildMetricItem(
                    title: 'نشط / كلي',
                    value: totalCount == 0 ? '---' : '$activeCount / $totalCount',
                    color: activeCount > 0 ? Colors.greenAccent : Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Button to open Full Control Sheet
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _openControlCenterBottomSheet(context, controller, isDark),
                  icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.white),
                  label: const Text(
                    'فتح لوحة المراقبة الفنية والتشخيصات 📊',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 📊 Open detailed sheet
void _openControlCenterBottomSheet(BuildContext context, SettingsController controller, bool isDark) {
  Get.bottomSheet(
    Container(
      height: Get.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            // Pill header handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            
            // Title and Sync Indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'لوحة المراقبة الفنية للبوابة',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
                    onPressed: () => controller.refreshAllDiagnostics(),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: "حالة السيرفر"),
                Tab(text: "حوض المفاتيح"),
                Tab(text: "سجل الأخطاء"),
                Tab(text: "📊 تحليلات"),
              ],
            ),

            // Tab view body
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: SERVER HEALTH
                  _buildServerHealthTab(controller, isDark),

                  // TAB 2: KEYS POOL
                  _buildKeysPoolTab(context, controller, isDark),

                  // TAB 3: OBSERVABILITY ERROR LOGS
                  _buildErrorLogsTab(controller, isDark),

                  // TAB 4: USER ANALYTICS
                  _buildUserAnalyticsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
    ignoreSafeArea: false,
  );
}

// 1️⃣ SERVER HEALTH TAB
Widget _buildServerHealthTab(SettingsController controller, bool isDark) {
  return Obx(() {
    if (controller.isLoadingHealth.value) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final health = controller.serverHealth;
    if (health.isEmpty) {
      return const Center(child: Text('لا توجد بيانات متاحة حالياً.', style: TextStyle(color: Colors.grey)));
    }

    final uptimeSeconds = health['uptime'] != null ? (health['uptime'] as num).toDouble() : 0.0;
    final uptimeText = _formatUptime(uptimeSeconds);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildDetailCard(
            icon: Icons.info_outline,
            title: 'إصدار البوابة',
            value: health['version'] ?? 'غير معروف',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.timer_outlined,
            title: 'مدة تشغيل السيرفر (Uptime)',
            value: uptimeText,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.vpn_key_outlined,
            title: 'المفاتيح المهيأة في البيئة',
            value: '${health['keysConfigured'] ?? 0} مفاتيح تدوير',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.hourglass_empty,
            title: 'فترات تبريد المفاتيح النشطة',
            value: '${health['activeCooldowns'] ?? 0} مفتاح قيد الانتظار',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.bar_chart_outlined,
            title: 'إجمالي استهلاك طلباتك اليوم',
            value: '${controller.dailyUsageCount.value} طلبات تدوير ناجحة',
            isDark: isDark,
          ),
        ],
      ),
    );
  });
}

// 2️⃣ KEYS POOL TAB WITH GROUPING AND CLICK ACTION
Widget _buildKeysPoolTab(BuildContext context, SettingsController controller, bool isDark) {
  return Obx(() {
    if (controller.isLoadingKeys.value) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final keys = controller.serverKeys;
    if (keys.isEmpty) {
      return const Center(child: Text('لا توجد مفاتيح مسجلة في البوابة.', style: TextStyle(color: Colors.grey)));
    }

    // Classify keys
    final activeKeys = keys.where((k) => k['code'] == 200).toList();
    final quotaKeys = keys.where((k) => k['code'] == 429).toList();
    final errorKeys = keys.where((k) => k['code'] != 200 && k['code'] != 429).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Total stats header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSmallBadge(label: 'عاملة', count: activeKeys.length, color: Colors.green),
              _buildSmallBadge(label: 'منتهية', count: quotaKeys.length, color: Colors.orange),
              _buildSmallBadge(label: 'معطلة', count: errorKeys.length, color: Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (activeKeys.isNotEmpty) ...[
          _buildGroupHeader('🟢 المفاتيح النشطة والعاملة (${activeKeys.length})'),
          ...activeKeys.map((k) => _buildKeyItem(context, k, isDark)),
        ],
        
        if (quotaKeys.isNotEmpty) ...[
          _buildGroupHeader('🟡 مفاتيح قيد التبريد/انتهت الحصة (${quotaKeys.length})'),
          ...quotaKeys.map((k) => _buildKeyItem(context, k, isDark)),
        ],

        if (errorKeys.isNotEmpty) ...[
          _buildGroupHeader('❌ مفاتيح تحتوي على أخطاء / غير صالحة (${errorKeys.length})'),
          ...errorKeys.map((k) => _buildKeyItem(context, k, isDark)),
        ],
      ],
    );
  });
}

// 3️⃣ OBSERVABILITY ERROR LOGS TAB
Widget _buildErrorLogsTab(SettingsController controller, bool isDark) {
  return Obx(() {
    if (controller.isLoadingErrors.value) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final errors = controller.gatewayErrors;
    if (errors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'لا توجد أخطاء مسجلة مؤخراً في البوابة السحابية. كل شيء يعمل بسلاسة! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: errors.length,
      itemBuilder: (ctx, idx) {
        final err = errors[idx];
        final model = err['model'] ?? 'غير معروف';
        final keyMask = err['key'] ?? err['keyMask'] ?? '---';
        final code = err['code'] ?? err['statusCode'] ?? '---';
        final message = _sanitizeErrorMessage(err['message'] ?? err['errorMessage'] ?? 'Unknown Error');
        
        String timeStr = '---';
        if (err['time'] != null) {
          try {
            final date = DateTime.parse(err['time'].toString());
            timeStr = "${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
          } catch (_) {}
        } else if (err['createdAt'] != null) {
          try {
            final date = DateTime.parse(err['createdAt'].toString());
            timeStr = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'خطأ $code',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('النموذج: ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(model, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  const Text('المفتاح: ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(keyMask, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  });
}


// 4️⃣ USER ANALYTICS TAB
Widget _buildUserAnalyticsTab(bool isDark) {
  final adminController = Get.isRegistered<AdminController>() ? Get.find<AdminController>() : null;
  const int maxUserCapacity = 500; // الحد الأقصى للطاقة الاستيعابية

  if (adminController == null) {
    return const Center(child: Text('لوحة الإدارة غير مفعلة.', style: TextStyle(color: Colors.grey)));
  }

  // تحميل البيانات عند أول فتح
  WidgetsBinding.instance.addPostFrameCallback((_) {
    adminController.loadAllRecentActivity();
  });

  return Obx(() {
    final users = adminController.users;
    final logs = adminController.allRecentActivityLogs;
    final isLoading = adminController.isLoadingActivity.value;

    final totalUsers = users.length;
    final premiumUsers = users.where((u) => u['isPremium'] == true).length;
    final freeUsers = totalUsers - premiumUsers;
    final capacityPercent = (totalUsers / maxUserCapacity).clamp(0.0, 1.0);

    // احتساب إجمالي رصيد AI المستهلك
    final totalCreditsUsed = users.fold<int>(0, (sum, u) => sum + ((u['ai_total_credits'] as num?)?.toInt() ?? 0));

    // احتساب أكثر الإجراءات استخداماً من السجلات
    final actionCounts = <String, int>{};
    for (final log in logs) {
      final action = log['action']?.toString() ?? '';
      if (action.isNotEmpty) {
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
      }
    }
    final sortedActions = actionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ─── 1️⃣ إحصائيات المستخدمين ───
        _buildAnalyticsSectionHeader('👥 إحصائيات المستخدمين', isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildAnalyticsStatCard('إجمالي المستخدمين', '$totalUsers', Icons.people_rounded, Colors.cyanAccent, isDark),
            const SizedBox(width: 10),
            _buildAnalyticsStatCard('مشتركون بريميوم', '$premiumUsers', Icons.star_rounded, Colors.amberAccent, isDark),
            const SizedBox(width: 10),
            _buildAnalyticsStatCard('مستخدمون مجانيون', '$freeUsers', Icons.person_rounded, Colors.white54, isDark),
          ],
        ),
        const SizedBox(height: 16),

        // ─── 2️⃣ الطاقة الاستيعابية ───
        _buildAnalyticsSectionHeader('⚡ الطاقة الاستيعابية', isDark),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$totalUsers / $maxUserCapacity مستخدم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: capacityPercent > 0.8 ? Colors.redAccent.withValues(alpha: 0.15) : Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      capacityPercent > 0.8 ? '⚠️ قريب من الحد' : '✅ متاح',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: capacityPercent > 0.8 ? Colors.redAccent : Colors.greenAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: capacityPercent,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    capacityPercent > 0.8 ? Colors.redAccent : capacityPercent > 0.5 ? Colors.orangeAccent : Colors.greenAccent,
                  ),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'المتبقي: ${maxUserCapacity - totalUsers} مستخدم إضافي',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── 3️⃣ رصيد AI المستهلك ───
        _buildAnalyticsSectionHeader('💎 رصيد AI المستهلك', isDark),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.withValues(alpha: 0.15), Colors.blue.withValues(alpha: 0.08)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalCreditsUsed', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                  const Text('إجمالي رصيد AI المستهلك من جميع المستخدمين', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── 3.5 📡 تقرير حالة مفاتيح AI ───
        _buildLiveTestCard(isDark),
        const SizedBox(height: 12),
        _buildApiKeysStatusSection(isDark),
        const SizedBox(height: 16),

        // ─── 4️⃣ أكثر الإجراءات استخداماً ───
        _buildAnalyticsSectionHeader('🔥 أكثر الإجراءات استخداماً', isDark),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)))
        else if (sortedActions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('لا توجد بيانات استخدام بعد.', style: TextStyle(color: Colors.grey.withValues(alpha: 0.6)))),
          )
        else
          ...sortedActions.take(10).map((entry) {
            final maxCount = sortedActions.first.value;
            final ratio = entry.value / maxCount;
            final label = ActivityTrackingService.getActionLabel(entry.key);
            final color = _getAnalyticsActionColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${entry.value} مرة', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),

        // ─── 5️⃣ آخر النشاطات ───
        _buildAnalyticsSectionHeader('🕐 آخر نشاطات المستخدمين', isDark),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)))
        else if (logs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('لا توجد نشاطات مسجلة.', style: TextStyle(color: Colors.grey.withValues(alpha: 0.6)))),
          )
        else
          ...logs.take(15).map((log) {
            final action = log['action']?.toString() ?? '';
            final label = log['actionLabel']?.toString() ?? ActivityTrackingService.getActionLabel(action);
            final credits = (log['creditsUsed'] as num?)?.toInt() ?? 0;
            final product = (log['details'] as Map?)?['product']?.toString() ?? '';
            final timestamp = log['timestamp'] as DateTime?;
            final color = _getAnalyticsActionColor(action);

            String timeStr = '';
            if (timestamp != null) {
              final diff = DateTime.now().difference(timestamp);
              if (diff.inMinutes < 1) { timeStr = 'الآن'; }
              else if (diff.inMinutes < 60) { timeStr = 'منذ ${diff.inMinutes}د'; }
              else if (diff.inHours < 24) { timeStr = 'منذ ${diff.inHours}س'; }
              else { timeStr = 'منذ ${diff.inDays}ي'; }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.flash_on_rounded, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (product.isNotEmpty)
                          Text(product, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeStr.isNotEmpty) Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      if (credits > 0)
                        Text('-$credits 💎', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),

        // زر تحديث البيانات
        TextButton.icon(
          onPressed: () => adminController.loadAllRecentActivity(),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('تحديث البيانات', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent, backgroundColor: Colors.cyanAccent.withValues(alpha: 0.08)),
        ),
        const SizedBox(height: 20),
      ],
    );
  });
}

Widget _buildAnalyticsSectionHeader(String title, bool isDark) {
  return Row(
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
    ],
  );
}

Widget _buildAnalyticsStatCard(String label, String value, IconData icon, Color color, bool isDark) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 2),
        ],
      ),
    ),
  );
}

Color _getAnalyticsActionColor(String action) {
  switch (action) {
    case 'tiktok_link': case 'tiktok_hashtag': return Colors.pinkAccent;
    case 'instagram_link': return Colors.purpleAccent;
    case 'douyin_link': return Colors.tealAccent;
    case 'rednote_link': return Colors.redAccent;
    case 'bilibili_link': return const Color(0xFF00A1D6);
    case 'kuaishou_link': return const Color(0xFFFF6B35);
    case 'taobao_live_link': return const Color(0xFFFF4400);
    case 'jd_link': return const Color(0xFFE02424);
    case 'youtube_shorts_link': case 'youtube_link': return Colors.redAccent;
    case 'generate_ad': return const Color(0xFF00FF88);
    case 'generate_kling_video': case 'generate_video': return Colors.orangeAccent;
    case 'generate_creative_image': case 'image_generation': return Colors.cyanAccent;
    case 'similar_videos': return Colors.deepOrangeAccent;
    case 'google_images': return Colors.lightBlueAccent;
    case 'remove_background': return Colors.blueAccent;
    case 'send_message': return Colors.white54;
    case 'visual_search': case 'google_lens': return Colors.yellowAccent;
    case 'trend_search': return Colors.blueAccent;
    case 'bing_copilot': return Colors.lightGreenAccent;
    default: return Colors.white38;
  }
}

// 🛠️ Sub-widgets & helper methods
Widget _buildGroupHeader(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
    ),
  );
}

Widget _buildKeyItem(BuildContext context, Map<String, dynamic> keyData, bool isDark) {
  final mask = keyData['key'] ?? keyData['keyName'] ?? '---';
  final provider = keyData['provider'] ?? 'gemini';
  final code = keyData['code'] ?? 200;
  final status = keyData['status'] ?? 'يعمل';

  Color statusColor = Colors.green;
  IconData statusIcon = Icons.check_circle_rounded;

  if (code == 429) {
    statusColor = Colors.orange;
    statusIcon = Icons.hourglass_top_rounded;
  } else if (code != 200) {
    statusColor = Colors.red;
    statusIcon = Icons.error_rounded;
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
    ),
    child: ListTile(
      onTap: () => _showKeyDiagnosticsDialog(context, keyData),
      leading: Icon(statusIcon, color: statusColor, size: 22),
      title: Text(
        mask,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        'المزود: $provider',
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          status.toString(),
          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}

Widget _buildSmallBadge({required String label, required int count, required Color color}) {
  return Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ],
  );
}

Widget _buildDetailCard({
  required IconData icon,
  required String title,
  required String value,
  required bool isDark,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    ),
  );
}

// 🚨 Key diagnostics dialog popup on click
void _showKeyDiagnosticsDialog(BuildContext context, Map<String, dynamic> keyData) {
  final mask = keyData['key'] ?? keyData['keyName'] ?? '---';
  final provider = keyData['provider'] ?? 'gemini';
  final code = keyData['code'] ?? 200;
  final status = keyData['status'] ?? 'يعمل';

  String report = '';
  String suggestion = '';

  if (code == 200) {
    report = 'المفتاح يعمل بشكل سليم ومستقر في بوابة التدوير (Active) ويستقبل طلبات المستخدمين حالياً دون أي معوقات.';
    suggestion = 'لا يوجد إجراء مطلوب. المفتاح يؤدي وظيفته بالشكل الصحيح.';
  } else if (code == 429) {
    report = 'حصة الاستخدام للمفتاح منتهية مؤقتاً (Quota Exceeded) بسبب كثرة طلبات المستخدمين المتتالية (تجاوز الحد الأقصى للمعدل المجاني: 15 طلب بالدقيقة).';
    suggestion = 'يقوم النظام تلقائياً بتوجيه هذا المفتاح إلى فترات التبريد (Cooldown Period) وتدوير الطلبات لباقي المفاتيح المتاحة. سيعود للخدمة تلقائياً بعد زوال التبريد.';
  } else if (code == 400) {
    report = 'المفتاح البرمجي غير صالح أو منتهي الصلاحية (Invalid API Key). يرجى التحقق من المفتاح في كونسول Google AI Studio.';
    suggestion = 'يجب على مسؤول النظام إزالة هذا المفتاح من بيئة البوابة السحابية واستبداله بمفتاح صالح لضمان عدم توقف عمليات الفيلوفر.';
  } else if (code == 403) {
    report = 'تم رفض الوصول للمفتاح (Permission Denied). قد يكون هذا بسبب عدم تفعيل الـ Generative Language API أو عدم تمكين الفوترة على حساب خدمة Vertex AI.';
    suggestion = 'يرجى مراجعة تمكين Generative Language API وصلاحيات الوصول لحساب الخدمة في لوحة GCP الخاصة بك.';
  } else {
    report = 'المفتاح واجه استجابة غير متوقعة أو خطأ من خادم المزود ($status). رمز الاستجابة الفني: $code.';
    suggestion = 'افحص سجل أخطاء البوابة الرئيسي لمعرفة طبيعة الاستجابة الخاطئة وتأكد من اتصال الخادم بالمزود.';
  }

  Get.dialog(
    AlertDialog(
      title: Row(
        children: [
          Icon(
            code == 200 
                ? Icons.check_circle_outline_rounded 
                : (code == 429 ? Icons.hourglass_empty_rounded : Icons.error_outline_rounded), 
            color: code == 200 ? Colors.green : (code == 429 ? Colors.orange : Colors.red),
          ),
          const SizedBox(width: 10),
          const Text('تقرير تشخيص المفتاح البرمجي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInfoRow('معرف المفتاح:', mask),
            _buildDialogInfoRow('نوع المزود:', provider),
            _buildDialogInfoRow('كود الاستجابة:', code.toString()),
            _buildDialogInfoRow('الحالة الحالية:', status.toString()),
            const Divider(height: 20),
            const Text('تحليل المشكلة البرمجي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(report, style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('الإجراء البرمجي المقترح للحل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
            const SizedBox(height: 6),
            Text(suggestion, style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Widget _buildDialogInfoRow(String label, String val) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 8),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    ),
  );
}

// 🧹 Clean and sanitize raw errors to secure API keys
String _sanitizeErrorMessage(String msg) {
  String result = msg.replaceAll(RegExp(r'AIzaSy[A-Za-z0-9_-]{33}'), '[GEMINI_API_KEY]');
  result = result.replaceAll(RegExp(r'ghp_[A-Za-z0-9]{36}'), '[GITHUB_API_KEY]');
  result = result.replaceAll(RegExp(r'sk-or-v1-[A-Za-z0-9]{48}'), '[OPENROUTER_API_KEY]');
  if (result.contains('at ')) {
    result = result.split('at ')[0];
  }
  return result;
}

// ⏱ Formatter helper for server uptime
String _formatUptime(double seconds) {
  final duration = Duration(seconds: seconds.toInt());
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  if (days > 0) {
    return '$days يوم و $hours ساعة و $minutes دقيقة';
  } else if (hours > 0) {
    return '$hours ساعة و $minutes دقيقة';
  } else {
    return '$minutes دقيقة';
  }
}

// 📡 قسم تقرير حالة مفاتيح AI
Widget _buildApiKeysStatusSection(bool isDark) {
  final settingsCtrl = Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>()
      : null;
  if (settingsCtrl == null) return const SizedBox.shrink();

  return Obx(() {
    final keys = settingsCtrl.serverKeys;
    final isLoadingKeys = settingsCtrl.isLoadingKeys.value;
    final latency = settingsCtrl.gatewayLatency.value;
    final health = settingsCtrl.serverHealth;
    final gatewayStatus = health['status']?.toString() ?? 'unknown';

    // تصنيف المفاتيح
    final activeKeys = keys.where((k) => k['status'] == 'active').toList();
    final cooldownKeys = keys.where((k) => k['status'] == 'cooldown' || k['status'] == 'rate_limited').toList();
    final failedKeys = keys.where((k) {
      final s = k['status']?.toString() ?? '';
      return s != 'active' && s != 'cooldown' && s != 'rate_limited' && s.isNotEmpty;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('📡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Text(
                  'تقرير حالة مفاتيح AI',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                // Gateway Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gatewayStatus == 'ok'
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: gatewayStatus == 'ok'
                          ? Colors.greenAccent.withValues(alpha: 0.4)
                          : Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    gatewayStatus == 'ok' ? '🟢 Gateway OK' : '🔴 Gateway Offline',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: gatewayStatus == 'ok' ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
            // Refresh Button + Latency
            Row(
              children: [
                if (latency > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${latency}ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: latency < 800
                            ? Colors.greenAccent
                            : latency < 2000
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => settingsCtrl.refreshAllDiagnostics(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyanAccent.withValues(alpha: 0.2), Colors.blueAccent.withValues(alpha: 0.1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: isLoadingKeys
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                        : const Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 14, color: Colors.cyanAccent),
                              SizedBox(width: 4),
                              Text('تحديث', style: TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ─── Summary Row ───
        if (keys.isNotEmpty) ...[
          Row(
            children: [
              _buildKeysSummaryBadge('🟢 نشطة', activeKeys.length, Colors.greenAccent),
              const SizedBox(width: 8),
              _buildKeysSummaryBadge('🟡 Cooldown', cooldownKeys.length, Colors.amberAccent),
              const SizedBox(width: 8),
              _buildKeysSummaryBadge('🔴 فاشلة', failedKeys.length, Colors.redAccent),
              const SizedBox(width: 8),
              _buildKeysSummaryBadge('المجموع', keys.length, Colors.white54),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // ─── Loading or Empty ───
        if (isLoadingKeys)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
          ))
        else if (keys.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                const Text('📭', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                const Text('لا توجد بيانات — اضغط تحديث', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => settingsCtrl.refreshAllDiagnostics(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('🔄 جلب البيانات', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          )
        else
          // ─── Keys Grid ───
          ...keys.asMap().entries.map((entry) {
            final idx = entry.key;
            final key = entry.value;
            final status = key['status']?.toString() ?? 'unknown';
            final keyName = key['key']?.toString() ?? key['keyName']?.toString() ?? 'مفتاح ${idx + 1}';
            final provider = key['provider']?.toString() ?? 'Gemini';
            final code = key['code']?.toString() ?? '';
            final isActive = status == 'active';
            final isCooldown = status == 'cooldown' || status == 'rate_limited';

            Color statusColor;
            String statusIcon;
            String statusLabel;
            if (isActive) {
              statusColor = Colors.greenAccent;
              statusIcon = '🟢';
              statusLabel = 'نشط';
            } else if (isCooldown) {
              statusColor = Colors.amberAccent;
              statusIcon = '🟡';
              statusLabel = code.isNotEmpty ? 'Cooldown ($code)' : 'Cooldown';
            } else {
              statusColor = Colors.redAccent;
              statusIcon = '🔴';
              statusLabel = code.isNotEmpty ? 'فاشل ($code)' : 'فاشل';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? statusColor.withValues(alpha: isActive ? 0.05 : 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withValues(alpha: isActive ? 0.35 : 0.2),
                  width: isActive ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  // Index + Icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        statusIcon,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Key Name + Provider
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          keyName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider,
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  });
}

// 🏷️ Badge ملخص المفاتيح
Widget _buildKeysSummaryBadge(String label, int count, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
      ],
    ),
  );
}

// 🧪 بطاقة الاختبار الحي للبوابات والمفاتيح بالتفصيل
Widget _buildLiveTestCard(bool isDark) {
  final settingsCtrl = Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>()
      : null;
  if (settingsCtrl == null) return const SizedBox.shrink();

  return Obx(() {
    final isRunning = settingsCtrl.isRunningLiveTest.value;
    final result = settingsCtrl.liveTestResult.value;

    final vertexData = result?['vertex'] as Map<String, dynamic>?;
    final poolData = result?['cloudPool'] as Map<String, dynamic>?;
    final localData = result?['localKey'] as Map<String, dynamic>?;

    final hasVertex = vertexData?['success'] == true;
    final hasPool = poolData?['success'] == true;
    final hasLocal = localData?['success'] == true;

    final overallSuccess = hasVertex || hasPool || hasLocal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withValues(alpha: 0.18),
            Colors.cyan.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: result == null
              ? Colors.indigoAccent.withValues(alpha: 0.3)
              : overallSuccess
                  ? Colors.greenAccent.withValues(alpha: 0.4)
                  : Colors.redAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Row: Title + Button ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🧪 فحص واختبار المزودات الحي',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'يتحقق من كافة خطوط الاتصال النشطة بالوقت الفعلي',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isRunning ? null : () => settingsCtrl.runLiveTest(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isRunning
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF3D5AFE)],
                          ),
                    color: isRunning ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isRunning
                        ? []
                        : [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1)],
                  ),
                  child: isRunning
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                            SizedBox(width: 8),
                            Text('جاري الفحص الموازي...', style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.science_rounded, size: 14, color: Colors.black),
                            SizedBox(width: 6),
                            Text('اختبار حي الآن', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ),

          // ─── Result Providers List ───
          if (result != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 4),

            // 1. Google Vertex AI
            if (vertexData != null)
              _buildDetailedProviderStatusCard(
                '1️⃣ Google Vertex AI (السحابي الأساسي)',
                vertexData,
                isDark,
              ),

            // 2. Gemini Key Pool
            if (poolData != null)
              _buildDetailedProviderStatusCard(
                '2️⃣ Gemini Key Pool (السحابي الاحتياطي)',
                poolData,
                isDark,
              ),

            // 3. Local API Key
            if (localData != null)
              _buildDetailedProviderStatusCard(
                '3️⃣ Google AI Studio (المفتاح المحلي)',
                localData,
                isDark,
              ),
          ],
        ],
      ),
    );
  });
}

// 📋 بطاقة تفصيلية لكل مزود داخل فحص البوابات
Widget _buildDetailedProviderStatusCard(String title, Map<String, dynamic> data, bool isDark) {
  final success = data['success'] == true;
  final latency = data['latencyMs'] as int? ?? 0;
  final model = data['model']?.toString() ?? '—';
  final keyName = data['keyName']?.toString() ?? '—';
  final response = data['response']?.toString() ?? '—';

  Color statusColor = success ? Colors.greenAccent : Colors.redAccent;
  if (!success && keyName == 'غير متوفر') {
    statusColor = Colors.grey;
  }

  return Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: statusColor.withValues(alpha: 0.25),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Row(
              children: [
                if (success && latency > 0) ...[
                  Text(
                    '${latency}ms',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: latency < 1000
                          ? Colors.greenAccent
                          : latency < 3000
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    success
                        ? '🟢 يعمل'
                        : (keyName == 'غير متوفر' ? '⚪ غير مفعل' : '🔴 معطل/فشل'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 8),

        _buildLiveTestRow('🤖 النموذج', model, Colors.blueAccent),
        const SizedBox(height: 4),
        _buildLiveTestRow('🔑 المفتاح', keyName, Colors.amberAccent),
        const SizedBox(height: 6),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Text(
            success ? '💬 الاستجابة: $response' : '⚠️ التشخيص/الخطأ: $response',
            style: TextStyle(
              color: success ? Colors.white70 : Colors.redAccent.shade100,
              fontSize: 10,
              fontStyle: success ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

// 📋 صف تفصيلي في بطاقة الاختبار الحي
Widget _buildLiveTestRow(String label, String value, Color accent) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 70,
        child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

// 📸 Last used vision/text providers card
class _LastUsedProvidersCard extends StatelessWidget {
  final SettingsController controller;
  final bool isDark;

  const _LastUsedProvidersCard({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final textProvider = controller.lastTextProvider.value;
      final imageProvider = controller.lastImageProvider.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [
                    Colors.indigo.withValues(alpha: 0.12),
                    Colors.purple.withValues(alpha: 0.12),
                  ]
                : [
                    Colors.indigo.withValues(alpha: 0.04),
                    Colors.purple.withValues(alpha: 0.04),
                  ],
          ),
          border: Border.all(
            color: Colors.indigo.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.indigoAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'آخر محرك معالجة تم استخدامه',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                      ),
                      const Text(
                        'آخر مزودات الخدمة التي عالجت طلباتك',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'آخر مزود للنصوص 📝',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          textProvider,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey.withValues(alpha: 0.15),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'آخر مزود للصور 📸',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          imageProvider,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
