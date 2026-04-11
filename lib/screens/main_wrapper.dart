import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';

import 'ai_chat_screen.dart';
import 'creator_profile_screen.dart';
import 'general_settings_screen.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // التأكد من وجود المتحكم
    final NavigationController navigationController = Get.find<NavigationController>();

    // قائمة الشاشات
    final List<Widget> screens = [
      const AiChatScreen(),
      const CreatorProfileScreen(),
      const GeneralSettingsScreen(),
    ];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Obx(() => IndexedStack(
              index: navigationController.currentIndex.value,
              children: screens,
            )),
      ),
    );
  }
}
