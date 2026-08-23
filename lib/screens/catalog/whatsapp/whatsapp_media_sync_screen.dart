import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/whatsapp_sync_controller.dart';
import '../../../models/whatsapp_sync_models.dart';
import '../widgets/catalog_product_image.dart';

/// 📱 WhatsAppMediaSyncScreen
/// لوحة إدارة ومزامنة وسائط الواتساب ومسودات الموردين التلقائية
class WhatsAppMediaSyncScreen extends StatelessWidget {
  const WhatsAppMediaSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(WhatsAppSyncController());

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111124),
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'WhatsApp Sync',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            tooltip: 'تحديث البيانات',
            onPressed: () => ctrl.loadAll(),
          ),
          Obx(() => TextButton.icon(
                onPressed: ctrl.isSaving.value ? null : () => ctrl.saveSettings(),
                icon: ctrl.isSaving.value
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, color: Color(0xFF25D366), size: 16),
                label: const Text('حفظ', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 13)),
              )),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
        }

        final cfg = ctrl.config.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1️⃣ بطاقات النظرة العامة (Overview Cards)
              _buildOverviewCards(cfg),
              const SizedBox(height: 20),

              // 2️⃣ مسار الأتمتة الكامل (5-Stage Pipeline Visualizer)
              _buildPipelineVisualizer(),
              const SizedBox(height: 20),

              // 3️⃣ حسابات Meta WABA المسجلة
              _buildWabaAccountsSection(cfg),
              const SizedBox(height: 20),

              // 4️⃣ محاكي استقبال الوسائط واختبار الذكاء الاصطناعي (Sandbox)
              _buildSandboxSection(ctrl),
              const SizedBox(height: 20),

              // 5️⃣ مسودات الموردين بانتظار المراجعة والاعتماد
              _buildPendingDraftsSection(ctrl),
              const SizedBox(height: 20),

              // 6️⃣ إعدادات الربط والويب هوك
              _buildCredentialsAndWebhookSection(ctrl, cfg),
              const SizedBox(height: 40),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOverviewCards(WhatsAppSyncConfig cfg) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      return GridView.count(
        crossAxisCount: isWide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isWide ? 1.6 : 1.3,
        children: [
          _buildStatCard(
            title: 'حالة الويب هوك',
            value: 'متصل ونشط',
            icon: Icons.check_circle,
            color: const Color(0xFF25D366),
            isPulse: true,
          ),
          _buildStatCard(
            title: 'رقم الواتساب المرتبط',
            value: cfg.phoneNumber,
            icon: Icons.phone_android,
            color: Colors.white,
            isLtr: true,
          ),
          _buildStatCard(
            title: 'الوسائط المستوردة',
            value: '${cfg.mediaCount} وسيلة إعلام',
            icon: Icons.perm_media,
            color: const Color(0xFF64B5F6),
          ),
          _buildStatCard(
            title: 'آخر مزامنة',
            value: cfg.lastSyncAt != null ? 'قبل قليل' : 'محدث الآن',
            icon: Icons.sync,
            color: Colors.amber,
          ),
        ],
      );
    });
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isPulse = false,
    bool isLtr = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold)),
              if (isPulse)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                ),
            ],
          ),
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                  textDirection: isLtr ? TextDirection.ltr : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineVisualizer() {
    final stages = [
      {'icon': '📲', 'title': '1. المورد يرسل', 'sub': '10 صور + فيديو + سعر'},
      {'icon': '⚡', 'title': '2. الويب هوك', 'sub': 'استقبال فوري آمن'},
      {'icon': '🤖', 'title': '3. الذكاء الاصطناعي', 'sub': 'توليد مسودة المنتج'},
      {'icon': '👁️', 'title': '4. المراجعة', 'sub': 'اعتماد بنقرة واحدة'},
      {'icon': '🚀', 'title': '5. الكتالوج', 'sub': 'تزامن Meta و Google'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101B18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF25D366), size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'مسار الأتمتة الكامل: من المورد إلى الكتالوجات',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Chip(
                label: Text('Auto-Sync ⚡', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF25D366))),
                backgroundColor: Color(0xFF1B382B),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 5 : 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: isWide ? 1.8 : 2.2,
              ),
              itemCount: stages.length,
              itemBuilder: (context, i) {
                final st = stages[i];
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141426),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(st['icon']!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(st['title']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                      Text(st['sub']!, style: const TextStyle(fontSize: 9, color: Colors.white54), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWabaAccountsSection(WhatsAppSyncConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business_center, color: Color(0xFF25D366), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حسابات واتساب للأعمال المسجلة في Meta',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cfg.accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final acc = cfg.accounts[i];
              final isVerified = acc.status.contains('مسجّل');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFF162B20) : const Color(0xFF201B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isVerified ? const Color(0xFF25D366).withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(acc.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? const Color(0xFF25D366).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVerified ? 'مسجّل ✅' : 'لم يتم التحقق ⚠️',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isVerified ? const Color(0xFF25D366) : Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('WABA ID: ${acc.wabaId}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70)),
                    Text('Phone: ${acc.phone}  |  Phone ID: ${acc.phoneNumberId}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white60)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxSection(WhatsAppSyncController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.science, color: Color(0xFF25D366), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مختبر محاكاة استقبال وسائط واتساب (AI Sandbox)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Chip(
                label: Text('AI Sandbox 🧪', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: Color(0xFF222244),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: ctrl.simFileUrl.value,
            onChanged: (v) => ctrl.simFileUrl.value = v,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              labelText: 'رابط صورة/فيديو المنتج التجريبي',
              labelStyle: const TextStyle(fontSize: 12, color: Colors.white60),
              filled: true,
              fillColor: const Color(0xFF0F0F1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: ctrl.simCaption.value,
                  onChanged: (v) => ctrl.simCaption.value = v,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'تعليق الرسالة (Caption / Hint)',
                    labelStyle: const TextStyle(fontSize: 12, color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: ctrl.simPhone.value,
                  onChanged: (v) => ctrl.simPhone.value = v,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رقم المرسل',
                    labelStyle: const TextStyle(fontSize: 12, color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ctrl.isSimulating.value ? null : () => ctrl.runSimulation(),
              icon: ctrl.isSimulating.value
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 16),
              label: const Text('إرسال المحاكاة وتشغيل الذكاء الاصطناعي', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (ctrl.lastSimResult.value != null) ...[
            const SizedBox(height: 14),
            _buildSimulationResultCard(ctrl.lastSimResult.value!),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulationResultCard(Map<String, dynamic> result) {
    final sug = result['aiSuggestion'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy, color: Color(0xFF25D366), size: 18),
              SizedBox(width: 6),
              Text('نتيجة التحليل الذكي المستخلص من الرسالة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF25D366))),
            ],
          ),
          const SizedBox(height: 8),
          Text('العنوان: ${sug['title'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('الفئة: ${sug['category'] ?? ''}  |  السعر المقترح: ${sug['price'] ?? 0} YER', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPendingDraftsSection(WhatsAppSyncController ctrl) {
    final drafts = ctrl.pendingDrafts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.inbox, color: Color(0xFF25D366), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مسودات الموردين بانتظار الاعتماد (${drafts.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white60),
                onPressed: () => ctrl.fetchDrafts(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (drafts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد مسودات واردة جديدة حالياً ✨', style: TextStyle(fontSize: 12, color: Colors.white54)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final draft = drafts[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // صورة المسودة
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CatalogProductImage(
                          imageUrl: draft.imageLink,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // تفاصيل المسودة
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(draft.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('المورد: ${draft.supplierPhone}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                            Text('${draft.price} ${draft.currency}  •  ${draft.categoryName ?? "متنوعات"}', style: const TextStyle(fontSize: 11, color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      // زر الاعتماد الفوري
                      ElevatedButton(
                        onPressed: ctrl.isApproving.value ? null : () => ctrl.approveDraft(draft),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('اعتماد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCredentialsAndWebhookSection(WhatsAppSyncController ctrl, WhatsAppSyncConfig cfg) {
    const webhookUrl = 'https://smartcontentcreator2.web.app/api/webhooks/whatsapp';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141426),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, color: Color(0xFF25D366), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'رابط الويب هوك وإعدادات Meta App',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCopyField('رابط الويب هوك (Callback URL):', webhookUrl),
          const SizedBox(height: 10),
          _buildCopyField('رمز التحقق (Verify Token):', cfg.verifyToken),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📋 خطوات تفعيل المزامنة في Meta Developer Portal:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 6),
                Text('1. افتح تطبيقك في Meta for Developers واختر WhatsApp -> Configuration.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                Text('2. الصق Callback URL و Verify Token الموضحين أعلاه في خانة Webhook.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                Text('3. اشترك في حدث messages لتلقي رسائل ووسائط الموردين تلقائياً.', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF25D366)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  Get.snackbar('📋 تم النسخ', 'تم نسخ $label إلى الحافظة');
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
