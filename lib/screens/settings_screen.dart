import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/auth_controller.dart';
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
          title: const Text('إعدادات المفاتيح 🗝️'),
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
                      // 🆕 Primary AI Keys Section (Gemini & GitHub)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مركز التحكم في الخدمات الذكية 🧠',
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
                          if (auth.isAdmin)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.cloud_download,
                                    color: Colors.blue),
                                tooltip: 'استعادة المفاتيح من السحابة',
                                onPressed: () =>
                                    settingsController.syncManagedKeysToLocal(),
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
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        'باقي المزودين والمحركات 🌐',
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

    // Create controllers for all possible keys (up to 6)
    final List<TextEditingController> controllers = List.generate(
      isHexaKey ? 6 : 1,
      (index) {
        if (isHexaKey) {
          return TextEditingController(
              text: index < settingsController.githubKeys.length
                  ? settingsController.githubKeys[index]
                  : "");
        }
        return TextEditingController(text: settingsController.getApiKey(type));
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

              // 📋 Render Inputs
              ...List.generate(controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: controllers[index],
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText:
                          isHexaKey ? "GitHub Key ${index + 1}" : "API Key",
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
                      if (key.isEmpty) {
                        Get.snackbar("تنبيه", "الرجاء إدخال المفتاح أولاً");
                        return;
                      }
                      await settingsController.saveApiKey(type, key);
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
                    "حفظ وتأكد ✅",
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
                      "تعيين كمزود افتراضي ⭐",
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
                        'النظام المدار (Zero-Config) 🧠',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        isTrial ? 'فترة تجريبية مجانية 🎁' : 'الباقة النشطة ✅',
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
                        'رصيد استهلاك SerpApi 💳',
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
                  'قارئ الروابط الذكي (Jina AI) ⛏️',
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
