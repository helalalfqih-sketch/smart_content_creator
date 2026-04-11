import 'package:flutter/material.dart';

class ContextPreviewBar extends StatelessWidget {
  final String? productName;
  final VoidCallback onClose;

  const ContextPreviewBar({
    super.key,
    required this.productName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (productName == null || productName!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            right: BorderSide(color: Color(0xFF00FF88), width: 3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_rounded,
                color: Color(0xFF00FF88), size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: "تحدث معي عن: ",
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    TextSpan(
                      text: productName!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
