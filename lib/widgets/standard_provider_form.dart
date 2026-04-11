import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';
import '../theme/app_theme.dart';
import 'settings/gemini_smart_auth_card.dart';

class StandardProviderForm extends StatefulWidget {
  final ProviderType providerType;

  const StandardProviderForm({super.key, required this.providerType});

  @override
  State<StandardProviderForm> createState() => _StandardProviderFormState();
}

class _StandardProviderFormState extends State<StandardProviderForm> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return Obx(() {
      final hasKey = controller.getApiKey(widget.providerType).isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(controller),
            const SizedBox(height: 16),
            if (widget.providerType == ProviderType.gemini) ...[
              const GeminiSmartAuthCard(),
              const SizedBox(height: 16),
            ],
            if (!hasKey)
              _buildConnectOptions(controller)
            else
              _buildActiveConfig(controller),
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  Widget _buildHeader(SettingsController controller) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome,
              color: Colors.blueAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "خدمة ${widget.providerType.displayName}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text(
                "ربط المحرك السحابي للذكاء الاصطناعي",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        if (controller.getApiKey(widget.providerType).isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.white38),
            onPressed: () =>
                controller.testProviderConnection(widget.providerType),
            tooltip: "تحديث الحالة",
          ),
      ],
    );
  }

  Widget _buildConnectOptions(SettingsController controller) {
    return Column(
      children: [
        if (widget.providerType != ProviderType.gemini &&
            widget.providerType != ProviderType.serpapi)
          _buildChoiceCard(
            title: "ربط تلقائي ذكي ⚡",
            subtitle: "تسجيل دخول عبر Google والحصول على إمكانية الوصول الفوري",
            icon: Icons.account_circle_outlined,
            color: Colors.white,
            isPremium: true,
            onTap: () => controller.linkWithGoogle(widget.providerType),
          ),
        if (widget.providerType != ProviderType.gemini &&
            widget.providerType != ProviderType.serpapi)
          const SizedBox(height: 12),
        _buildChoiceCard(
          title: "إدخال مفتاح يدوي 🔑",
          subtitle:
              "إذا كان لديك مفتاح API خاص بك من ${widget.providerType.displayName}",
          icon: Icons.edit_note_rounded,
          color: Colors.blueAccent,
          onTap: () => _showManualInputDialog(controller),
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isPremium ? Colors.white.withValues(alpha: 0.03) : Colors.black12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium
                ? Colors.blueAccent.withValues(alpha: 0.3)
                : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveConfig(SettingsController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildManualKeyField(controller),
        const SizedBox(height: 16),
        _buildConnectionStatus(controller),
        if (widget.providerType == ProviderType.azure) ...[
          const SizedBox(height: 12),
          _buildEndpointDisplay(controller),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync_alt, size: 18),
                label: const Text("تغيير المفتاح"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                onPressed: () => _showManualInputDialog(controller),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _launchKeyURL(widget.providerType),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text("مساعدة"),
                style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
              ),
            ),
          ],
        )
      ],
    );
  }

  void _showManualInputDialog(SettingsController controller) {
    final textController =
        TextEditingController(text: controller.getApiKey(widget.providerType));
    final secretController = TextEditingController(
        text: widget.providerType == ProviderType.kling
            ? controller.providerSecrets[ProviderType.kling] ?? ''
            : '');
    final endpointController = TextEditingController(
        text: controller.providerEndpoints[widget.providerType] ?? '');

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("إعداد مفتاح الـ API يدوياً",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("المزود: ${widget.providerType.displayName}",
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 20),
                Text(
                    widget.providerType == ProviderType.kling
                        ? "Access Key"
                        : "API Key",
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: textController,
                  obscureText: _isObscured,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: "أدخل الكود هنا...",
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                            color: Color(0xFF2D2D2D), width: 1)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                            color: Color(0xFF2D2D2D), width: 1)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 2)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isObscured ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white38),
                      onPressed: () =>
                          setModalState(() => _isObscured = !_isObscured),
                    ),
                  ),
                ),
                if (widget.providerType == ProviderType.kling) ...[
                  const SizedBox(height: 20),
                  const Text("Secret Key",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: secretController,
                    obscureText: _isObscured,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "أدخل مفتاح السر هنا...",
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D2D2D), width: 1)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D2D2D), width: 1)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: AppTheme.primary, width: 2)),
                    ),
                  ),
                ],
                if (widget.providerType == ProviderType.azure) ...[
                  const SizedBox(height: 20),
                  const Text("Azure Endpoint URL",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endpointController,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "https://RESOURCE.openai.azure.com/...",
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D2D2D), width: 1)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D2D2D), width: 1)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                              color: AppTheme.primary, width: 2)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (widget.providerType == ProviderType.kling) {
                        await controller.saveSecretKey(
                            widget.providerType, secretController.text);
                      }
                      if (widget.providerType == ProviderType.azure) {
                        await controller.saveCustomEndpoint(
                            widget.providerType, endpointController.text);
                      }
                      await controller.saveApiKey(
                          widget.providerType, textController.text);
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: const Text("حفظ وتأكيد",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (widget.providerType.apiKeyUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _launchKeyURL(widget.providerType),
                        icon: const Icon(Icons.open_in_new,
                            size: 16, color: Colors.blueAccent),
                        label: Text("ليس لديك مفتاح؟ احصل عليه من هنا 🔗",
                            style: TextStyle(
                                color: Colors.blueAccent.withValues(alpha: 0.8),
                                fontSize: 13)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildConnectionStatus(SettingsController controller) {
    final isConnected = controller.getConnectionStatus(widget.providerType);
    final error = controller.providerErrors[widget.providerType];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isConnected
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(isConnected ? Icons.check_circle : Icons.error,
              color: isConnected ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isConnected ? "متصل وشغال ✅" : "يوجد مشكلة في الربط ⚠️",
                    style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                if (!isConnected && error != null)
                  Text(error,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualKeyField(SettingsController controller) {
    final key = controller.getApiKey(widget.providerType);
    final maskedKey = key.length > 8
        ? "${key.substring(0, 4)}...${key.substring(key.length - 4)}"
        : key;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.key, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(maskedKey,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 12))),
          const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
        ],
      ),
    );
  }

  Widget _buildEndpointDisplay(SettingsController controller) {
    final endpoint = controller.getCustomEndpoint(widget.providerType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.link, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              endpoint.isNotEmpty ? endpoint : "لم يتم تحديد Endpoint",
              style: TextStyle(
                  color: endpoint.isNotEmpty ? Colors.white70 : Colors.white24,
                  fontSize: 11,
                  fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _launchKeyURL(ProviderType type) async {
    final url = type.apiKeyUrl;
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
