import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 📝 SmartNeonTextField - A premium, styled text field for user input.
class SmartNeonTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool isObscured;
  final VoidCallback? onToggleVisibility;
  final TextInputType? keyboardType;
  final Iterable<String>? hints;
  final Color accentColor;
  final Function(String)? onSubmitted;
  final TextAlign textAlign;

  const SmartNeonTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.isObscured = false,
    this.onToggleVisibility,
    this.keyboardType,
    this.hints,
    this.accentColor = const Color(0xFF00FF88),
    this.onSubmitted,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(50), // 🔥 Pill Shape
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscured : false,
        keyboardType: keyboardType,
        autofillHints: hints,
        onSubmitted: onSubmitted,
        textAlign: textAlign,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(icon, color: accentColor, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isObscured
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
