import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/storage/app_storage_service.dart';
import '../core/storage/storage_keys.dart';

class ThemeController extends GetxController {
  final _isDarkMode = false.obs;
  
  bool get isDarkMode => _isDarkMode.value;
  ThemeMode get themeMode => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  final AppStorageService _storage = Get.find<AppStorageService>();

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromStorage();
  }

  void _loadThemeFromStorage() {
    _isDarkMode.value = _storage.read<bool>(StorageKeys.isDarkMode) ?? false;
    Get.changeThemeMode(themeMode);
  }

  Future<void> toggleTheme() async {
    _isDarkMode.value = !_isDarkMode.value;
    Get.changeThemeMode(themeMode);
    await _storage.write(StorageKeys.isDarkMode, _isDarkMode.value);
    debugPrint('🌙 Theme changed to: ${_isDarkMode.value ? "Dark" : "Light"}');
  }

  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode.value == isDark) return;
    _isDarkMode.value = isDark;
    Get.changeThemeMode(themeMode);
    await _storage.write(StorageKeys.isDarkMode, isDark);
  }
}
