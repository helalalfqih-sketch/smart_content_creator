import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ⚡ Cyberpunk Luxury / Futuristic Minimalist 2026
  static const Color background = Color(0xFF000000); // 🌑 Pure Black
  static const Color darkBackground = background;
  static const Color primary = Color(0xFF26C97A); // 🔋 Softer Premium Green
  static const Color secondary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF00D4FF); // 💎 Softer Liquid Cyan
  static const Color surfaceColor = Color(0xFF111115); // 🧱 Refined Soft Surface
  static const Color surfaceSoft = Color(0xFF18181C); // ✨ Second layer depth
  static const Color textGrey = Color(0xFFA0A0A0);

  // 🎯 Premium SaaS Gradients
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A1F),
      Color(0xFF111115),
    ],
  );

  // 🌈 Premium Cyber Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF00CC6A)],
  );

  // 🧠 Text Colors
  static const Color textHeader = Color(0xFFFFFFFF);
  static const Color textSub = Color(0xFFB0B0B0);
  static const Color textMain = Color(0xFF1F2937);

  // Defaults
  static const Color bgMain = Color(0xFFF7F9FF);
  static const Color glassDark = Color(0xFFFFFFFF);

  // 🧠 Psychology Mapping (Cyberpunk Version)
  static const Color colorCreative = primary;
  static const Color colorExcitement = Color(0xFFFF2D55); // Neon Red
  static const Color colorTrust = Color(0xFF2962FF); // Laser Blue
  static const Color colorFriendly = Color(0xFF00FF88);
  static const Color colorOptimism = Color(0xFFFBBF24);
  static const Color colorGrowth = primary;

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    fontFamily: 'IBMPlexSansArabic',
    useMaterial3: true,
    scaffoldBackgroundColor: bgMain,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: glassDark,
      onSurface: textMain,
      outline: Color(0xFFE5E7EB),
      surfaceContainerHighest: Color(0xFFF3F4F6),
      onSurfaceVariant: Color(0xFF6B7280),
      error: Color(0xFFEF4444),
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.oswald(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textMain,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    fontFamily: 'IBMPlexSansArabic',
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: surfaceColor,
      onSurface: textHeader,
      outline: Color(0xFF1E1E2E),
      surfaceContainerHighest: Color(0xFF1A1A1A),
      onSurfaceVariant: textSub,
      error: Color(0xFFF87171),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontFamily: 'IBMPlexSansArabic',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        textStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: GoogleFonts.inter(
        color: textSub,
        fontSize: 16,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.oswald(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: textHeader,
        letterSpacing: 1.5,
      ),
      displayMedium: GoogleFonts.oswald(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textHeader,
      ),
      headlineLarge: GoogleFonts.oswald(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textHeader,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textHeader,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: textHeader,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: textSub,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: primary.withValues(alpha: 0.1),
      labelStyle: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );

  static const fluentPurple = primary;
  static const fluentPurpleLight = Color(0xFF00CC6A);
  static const fluentBlue = accent;
  static const fluentGrey = Color(0xFF8D8D8D);
}
