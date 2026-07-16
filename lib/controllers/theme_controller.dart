import 'package:flutter/material.dart';
import 'package:get/get.dart';
class ThemeController extends GetxController {
  final _isDarkMode = true.obs;
  
  bool get isDarkMode => true;
  ThemeMode get themeMode => ThemeMode.dark;

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromStorage();
  }

  void _loadThemeFromStorage() {
    // 🛡️ Forcing Dark Mode in this version
    _isDarkMode.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.changeThemeMode(ThemeMode.dark);
    });
  }

  Future<void> toggleTheme() async {
    // 🛡️ Disabled for now to ensure UI stability in Dark Mode
    Get.snackbar('معلومة', 'وضع الإضاءة الفاتح قيد التطوير، التطبيق يعمل حالياً بالوضع المظلم الفاخر.');
  }

  Future<void> setTheme(bool isDark) async {
    // 🛡️ Disabled
  }
}
