import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/strings/app_strings.dart';

class VipNavItem {
  final IconData icon;
  final String label;
  final int index;
  final VoidCallback? onTap;

  VipNavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.onTap,
  });
}

class NavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxBool showBottomBar = true.obs;
  final RxBool isBarCollapsed = false.obs; // 🗜️ حالة التصغير

  void toggleBarCollapse() {
    isBarCollapsed.value = !isBarCollapsed.value;
  }

  // 📋 العناصر الافتراضية
  final List<VipNavItem> _defaultItems = [
    VipNavItem(icon: Icons.auto_awesome_rounded, label: AppStrings.navHome, index: 0),
    VipNavItem(icon: Icons.account_circle_rounded, label: AppStrings.navProfile, index: 1),
    VipNavItem(icon: Icons.settings_rounded, label: AppStrings.navSettings, index: 2),
  ];

  // 📋 القائمة الحالية المعروضة
  final RxList<VipNavItem> barItems = <VipNavItem>[].obs;
  final RxList<VipNavItem> customItems = <VipNavItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    barItems.assignAll(_defaultItems);
  }

  void setBarVisibility(bool visible) {
    showBottomBar.value = visible;
  }

  void changePage(int index) {
    currentIndex.value = index;
    _autoUpdateItems(index);
  }

  // 🔄 تحديث العناصر تلقائياً بناءً على الشاشة للحصول على تجربة "ديناميكية"
  void _autoUpdateItems(int index) {
    // 🛡️ تم تعطيل التغيير التلقائي لضمان ثبات الشريط الجانبي وسهولة الوصول لجميع الأقسام
    barItems.assignAll(_defaultItems);
    showBottomBar.value = true;
  }

  void updateBarItems(List<VipNavItem> newItems) {
    barItems.assignAll(newItems);
  }

  void goToHome() {
    changePage(0);
  }
}
