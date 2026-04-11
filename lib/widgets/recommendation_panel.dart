import 'package:flutter/material.dart';

class RecommendationPanel extends StatelessWidget {
  final List<Map<String, dynamic>> recommendations;
  final Function(Map<String, dynamic>) onItemTap;

  const RecommendationPanel({
    super.key,
    required this.recommendations,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      height: 44, // Compact height
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = recommendations[index];
          final type = item['type'] ?? 'unknown';
          final content = item['content'] ?? '';

          Color? color;
          IconData? icon;
          String labelPrefix = "";

          if (type == 'product') {
            color = Colors.orange;
            icon = Icons.shopping_bag_outlined;
            labelPrefix = "🛍️";
          } else if (type == 'chat') {
            color = Colors.blue;
            icon = Icons.chat_bubble_outline;
            labelPrefix = "📝";
            // Truncate chat content
            if (content.length > 20) {
              // content = content.substring(0, 20) + "...";
            }
          } else {
            color = Colors.grey;
            icon = Icons.lightbulb_outline;
          }

          // Format similarity as percentage if relevant
          // final score = (similarity * 100).toInt();

          return InkWell(
            onTap: () => onItemTap(item),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    "$labelPrefix ${(content as String).length > 25 ? "${content.substring(0, 25)}..." : content}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
