import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/ui_kit/smart_bouncy_wrapper.dart';

class ChatActionButton extends StatelessWidget {
  // ... (same fields)
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final RxBool? isLoading;

  const ChatActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading != null) {
      return Obx(() => _buildButton(isLoading!.value));
    }
    return _buildButton(false);
  }

  Widget _buildButton(bool loading) {
    final effectiveColor = loading ? Colors.grey : color;

    return SmartBouncyWrapper(
      onTap: loading ? () {} : onTap,
      scaleFactor: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10), // More padding for VIP feel
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1), // Subtle background
          borderRadius: BorderRadius.circular(24), // Pill shape
          border: Border.all(
            color: effectiveColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: effectiveColor.withValues(alpha: 0.05),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(effectiveColor),
                ),
              )
            else
              Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
