import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'smart_bouncy_wrapper.dart';
import '../../../theme/app_theme.dart';

/// ⚡ SmartNeonButton - A premium neon-themed button with glass and shadow effects.
/// Implements the "Pill Shape" and "Soft UI" requested for a SaaS feel.
class SmartNeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color>? gradientColors;
  final Color? shadowColor;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final IconData? icon;

  const SmartNeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.gradientColors,
    this.shadowColor,
    this.textColor,
    this.height = 55.0,
    this.borderRadius = 80.0, // 🔥 Ultra Pill Shape
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Default colors if none provided
    final List<Color> colors = gradientColors ?? AppTheme.primaryGradient.colors;
    final Color shadow = shadowColor ?? colors[0].withValues(alpha: 0.2);
    final Color textCol = textColor ?? Colors.black;

    return SmartBouncyWrapper(
      onTap: (isLoading || onPressed == null) ? () {} : onPressed!,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(textCol),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: textCol, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: GoogleFonts.cairo(
                        color: textCol,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
