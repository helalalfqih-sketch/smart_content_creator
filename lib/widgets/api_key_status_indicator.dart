import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/api_controller.dart'; 

class ApiKeyStatusIndicator extends StatelessWidget {
  const ApiKeyStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final apiController = Get.find<ApiController>();
    
    return Obx(() {
      final status = apiController.geminiStatus;
      Color color;
      String tooltip;
      
      switch (status) {
        case ApiStatus.active:
          color = Colors.green;
          tooltip = 'Gemini 1.5 Flash: متصل (سريع) ⚡';
          break;
        case ApiStatus.limited:
          color = Colors.orange;
          tooltip = 'Gemini 1.5 Flash: محدود الاستخدام ⚠️';
          break;
        case ApiStatus.error:
          color = Colors.red;
          tooltip = 'Gemini: خطأ في الاتصال ❌';
          break;
        default:
          color = Colors.grey;
          tooltip = 'جاري التحقق...';
      }

      return Tooltip(
        message: tooltip,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
            ],
          ),
        ),
      );
    });
  }
}
