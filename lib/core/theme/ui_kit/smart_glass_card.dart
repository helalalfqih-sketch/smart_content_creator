import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 💎 SmartGlassCard - A premium glassmorphism container with blur and border effects.
class SmartGlassCard extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final double? blurSigma;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final double? borderWidth;

  const SmartGlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurSigma,
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.boxShadow,
    this.padding,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? 35.r;
    final double sigma = blurSigma ?? 25.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding ?? EdgeInsets.all(32.w),
          decoration: BoxDecoration(
            color: backgroundColor ?? (gradient == null ? Colors.white.withValues(alpha: 0.05) : null),
            gradient: gradient,
            boxShadow: boxShadow,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.1),
              width: borderWidth ?? 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
