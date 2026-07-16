import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SnackBarUtils {
  static void showError(String title, String message) {
    showSmartSnackBar(title: title, message: message, isError: true);
  }

  static void showSuccess(String title, String message) {
    showSmartSnackBar(title: title, message: message, isError: false);
  }

  static void showWarning(String title, String message) {
    showSmartSnackBar(title: title, message: message, isWarning: true);
  }

  // New Ultra-VIP SnackBar using Get.rawSnackbar for custom styling
  static void showSmartSnackBar({
    required String title,
    required String message,
    bool isError = false,
    bool isWarning = false,
    int durationSeconds = 4,
  }) {
    final Color primaryColor = isError 
        ? const Color(0xFFFF5252) 
        : (isWarning ? const Color(0xFFFFB300) : const Color(0xFF2DD486));

    Get.rawSnackbar(
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: durationSeconds),
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: EdgeInsets.zero,
      isDismissible: true,
      messageText: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.15),
              blurRadius: 25,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 40,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle glowing background decoration
            Positioned(
              left: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
              child: Row(
                children: [
                  // Icon Part
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isError ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text Content
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'IBMPlexSansArabic',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontFamily: 'IBMPlexSansArabic',
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Copy Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: "$title\n$message"));
                        Get.back(); // Close existing
                        showSuccess("تم النسخ ✅", "تم حفظ النص للذاكرة الذكية");
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.copy_rounded,
                            color: Colors.white54, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
