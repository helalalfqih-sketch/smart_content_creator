import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 🎨 SmartSoftIcon - A circular icon wrapper with a soft background.
/// Aligns with the "Soft + Floating" design philosophy.
class SmartSoftIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double padding;

  const SmartSoftIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 24.0,
    this.padding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = color ?? AppTheme.primary;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor.withValues(alpha: 0.1),
      ),
      child: Icon(
        icon,
        color: primaryColor.withValues(alpha: 0.9),
        size: size,
      ),
    );
  }
}
