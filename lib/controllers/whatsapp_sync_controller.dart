import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/whatsapp_sync_models.dart';
import '../services/whatsapp_sync_service.dart';
import 'catalog_controller.dart';

/// 📱 WhatsAppSyncController
/// متحكم إدارة مزامنة وسائط الواتساب وحسابات WABA ومسودات الموردين
class WhatsAppSyncController extends GetxController {
  WhatsAppSyncService get _service =>
      Get.isRegistered<WhatsAppSyncService>()
          ? Get.find<WhatsAppSyncService>()
          : Get.put(WhatsAppSyncService());

  final config = Rx<WhatsAppSyncConfig>(WhatsAppSyncConfig.fromMap({}));
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isSimulating = false.obs;
  final isApproving = false.obs;
  final pendingDrafts = <WhatsAppDraftModel>[].obs;
  final lastSimResult = Rx<Map<String, dynamic>?>(null);

  // حقول محاكاة الاختبار Sandbox
  final simFileUrl = 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&auto=format&fit=crop'.obs;
  final simCaption = 'ساعة ابل واش الترا سوداء فاخرة'.obs;
  final simPhone = '+967771370740'.obs;
  final simFileType = 'image'.obs;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchConfig(),
        fetchDrafts(),
      ]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchConfig() async {
    final res = await _service.getConfig();
    config.value = res;
  }

  Future<void> fetchDrafts() async {
    final list = await _service.getPendingDrafts();
    pendingDrafts.value = list;
  }

  Future<void> saveSettings() async {
    isSaving.value = true;
    try {
      final ok = await _service.saveConfig(config.value);
      if (ok) {
        Get.snackbar(
          '✅ تم الحفظ',
          'تم حفظ إعدادات الربط مع WhatsApp Cloud API بنجاح ✨',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          '❌ فشل الحفظ',
          'تعذر حفظ الإعدادات، يرجى المحاولة ثانية',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> runSimulation() async {
    if (simFileUrl.value.trim().isEmpty) {
      Get.snackbar('⚠️ تنبيه', 'يرجى إدخال رابط الصورة/الفيديو');
      return;
    }

    isSimulating.value = true;
    try {
      final res = await _service.simulateInbound(
        fileUrl: simFileUrl.value.trim(),
        caption: simCaption.value.trim(),
        senderPhone: simPhone.value.trim(),
        fileType: simFileType.value,
      );

      if (res != null) {
        lastSimResult.value = res;
        Get.snackbar(
          '✨ تمت المحاكاة بنجاح',
          'تمت محاكاة استقبال رسالة الواتساب واستخلاص بيانات الذكاء الاصطناعي بنجاح',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        );
        fetchDrafts();
      } else {
        Get.snackbar(
          '❌ فشل',
          'فشلت محاكاة الرسالة',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
        );
      }
    } finally {
      isSimulating.value = false;
    }
  }

  Future<void> approveDraft(WhatsAppDraftModel draft) async {
    isApproving.value = true;
    try {
      final ok = await _service.approveDraft(
        draft.id,
        title: draft.title,
        price: draft.price,
        description: draft.description,
        categoryName: draft.categoryName,
      );

      if (ok) {
        pendingDrafts.removeWhere((d) => d.id == draft.id);
        if (Get.isRegistered<CatalogController>()) {
          Get.find<CatalogController>().loadProducts();
        }

        Get.snackbar(
          '🛍️ تم اعتماد المنتج',
          'تم اعتماد المنتج ونشره مباشرة في الكتالوج الأساسي بنجاح! ✨',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          '❌ خطأ',
          'فشل اعتماد المسودة، يرجى التحقق من الاتصال والمحاولة ثانية',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
        );
      }
    } finally {
      isApproving.value = false;
    }
  }
}
