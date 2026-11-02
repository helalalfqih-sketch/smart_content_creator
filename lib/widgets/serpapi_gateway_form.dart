import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/utils/ai_request_exception.dart';
import '../services/ai_backend_router.dart';
import '../services/serpapi_gateway_service.dart';
import '../controllers/settings_controller.dart';
import '../core/models/api_provider.dart';

class SerpApiGatewayForm extends StatefulWidget {
  const SerpApiGatewayForm({super.key});
  @override
  State<SerpApiGatewayForm> createState() => _SerpApiGatewayFormState();
}

class _SerpApiGatewayFormState extends State<SerpApiGatewayForm> {
  bool _testing = false;
  String? _result;

  Future<void> _testSearch() async {
    setState(() { _testing = true; _result = null; });
    try {
      final response = await Get.find<SerpApiGatewayService>().search('ما هي القهوة؟');
      if (!mounted) return;
      final answer = response['reconstructed_markdown']?.toString();
      setState(() { _result = answer?.trim().isNotEmpty == true ? answer : 'وصلت نتيجة بحث فعلية. افتح المحادثة لعرض تفاصيلها.'; });
    } on AiRequestException catch (error) {
      if (mounted) setState(() { _result = error.message; });
    } catch (_) {
      if (mounted) setState(() { _result = 'تعذر إتمام البحث.'; });
    } finally { if (mounted) setState(() { _testing = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final service = Get.find<SerpApiGatewayService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Google AI Mode وGoogle Lens', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          const SizedBox(height: 12),
          const Text('بحث مدعوم بالمصادر باستخدام حسابك في التطبيق. مفتاح الخدمة محفوظ على الخادم.'),
          const SizedBox(height: 8),
          const Text('للبحث عن صورة: افتح الأدوات الذكية واختر Google Lens. تُرسل الصورة إلى SerpApi لإيجاد الصور والمنتجات المشابهة، دون الحاجة لإدخال مفتاح هنا.'),
          const SizedBox(height: 12),
          Text(service.statusMessage.value),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: service.checking.value || _testing ? null : () async {
              if (await Get.find<AIBackendRouter>().switchBackend('serpapi')) {
                await Get.find<SettingsController>().setActiveTextProvider(ProviderType.serpapi);
              }
            },
            child: Text(service.checking.value ? 'جارٍ التحقق…' : service.connected.value ? 'استخدام SerpApi في المحادثة' : 'ربط SerpApi'),
          ),
          if (service.connected.value) ...[
            const SizedBox(height: 12),
            Text('حد الاستخدام: ${service.hourlyLimit.value} بحث/ساعة، ${service.dailyLimit.value} بحث/يوم.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _testing ? null : _testSearch, child: Text(_testing ? 'جارٍ البحث…' : 'اختبار بحث فعلي')),
            const Text('الاختبار قد يستهلك من رصيد SerpApi.', style: TextStyle(fontSize: 12)),
          ],
          if (_result != null) ...[const SizedBox(height: 16), SelectableText(_result!)],
        ])),
      ),
    );
  }
}
