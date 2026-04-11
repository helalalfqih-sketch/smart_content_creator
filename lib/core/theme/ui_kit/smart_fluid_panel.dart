import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 🌊 SmartFluidPanel - A premium floating panel using the Soft UI design system.
/// Implements the "Web App Premium" feel with card gradients and soft depth.
class SmartFluidPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool useBlur;
  final bool useGlow;
  final Color? borderColor;

  const SmartFluidPanel({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(20.0),
    this.useBlur = false,
    this.useGlow = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // 🧱 Layer 1: Ambient Depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          // ✨ Layer 2: Subtle Glow (Optional)
          if (useGlow)
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: Offset.zero,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: useBlur ? 20 : 0,
            sigmaY: useBlur ? 20 : 0,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
