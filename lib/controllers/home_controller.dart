import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/ai/model_capability_service.dart';

import '../controllers/settings_controller.dart';
import 'chat_history_controller.dart';
import 'auth_controller.dart';
import '../services/ai_provider.dart';
import '../services/db_service.dart';
import '../core/utils/snackbar_utils.dart';

class HomeController extends GetxController {
  final isLoading = false.obs;
  final conversationHistory = <Map<String, dynamic>>[].obs;
  final errorMessage = RxnString();
  final isSendingMessage = false.obs;

  SettingsController get _settingsController => Get.find<SettingsController>();
  DBService get _dbService => Get.find<DBService>();

  @override
  void onInit() {
    super.onInit();

    // 🚀 بدء فحص قدرات الموديلات استباقياً
    if (Get.isRegistered<ModelCapabilityService>()) {
      Get.find<ModelCapabilityService>().checkAllCapabilities();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadHistory();
    });
  }

  /// ==============================
  /// تحميل السجل من قاعدة البيانات
  /// ==============================
  Future<void> loadHistory() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final history = await _dbService.getRecords('chat_history', orderBy: 'created_at DESC', limit: 50);
      conversationHistory.value = history;
      conversationHistory.refresh();
    } catch (e) {
      errorMessage.value = '❌ فشل تحميل السجل: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  /// ==============================
  /// إرسال رسالة دردشة
  /// ==============================
  Future<void> sendMessage(String prompt) async {
    if (prompt.trim().isEmpty) {
      errorMessage.value = 'يرجى كتابة رسالة أولاً';
      return;
    }

    isSendingMessage.value = true;
    errorMessage.value = null;

    try {
      // ✅ توليد رد باستخدام Smart Fallback
      final result = await AIProviderFactory.generateWithSmartFallback(prompt);
      final response = result.description;

      // ✅ الحصول على اسم المزود المستخدم
      final activeProvider = _settingsController.getActiveProvider();

      String? userId;
      if (Get.isRegistered<AuthController>()) {
        userId = Get.find<AuthController>().user?['id']?.toString();
      }

      // ✅ حفظ المحادثة في قاعدة البيانات
      await _dbService.logChatMessage(
        activeProvider.displayName,
        prompt,
        response,
        userId: userId,
      );

      // ✅ تتبع استخدام المزود
      await _dbService.insertRecord('activity_logs', {
        'action': 'provider_usage',
        'details': activeProvider.displayName,
        'created_at': DateTime.now().toIso8601String(),
      });

      final newConversation = {
        'provider': activeProvider.displayName,
        'user_message': prompt,
        'ai_response': response,
        'created_at': DateTime.now().toIso8601String(),
      };

      // ✅ إضافة النتيجة للقائمة (في الأعلى)
      conversationHistory.insert(0, newConversation);
    } catch (e) {
      errorMessage.value = '❌ فشل الإرسال: ${e.toString()}';
    } finally {
      isSendingMessage.value = false;
    }
  }

  Future<void> refreshApp() async {
    try {
      isLoading.value = true;
      // Refresh History
      await loadHistory();

      // Refresh Sessions if controller is registered
      if (Get.isRegistered<ChatHistoryController>()) {
        await Get.find<ChatHistoryController>().loadSessions();
      }

      SnackBarUtils.showSmartSnackBar(
        title: 'تحديث',
        message: 'تم تحديث بيانات التطبيق بنجاح ✅',
        isError: false,
      );
    } catch (e) {
      SnackBarUtils.showSmartSnackBar(
          title: 'خطأ', message: 'فشل التحديث: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }
}
