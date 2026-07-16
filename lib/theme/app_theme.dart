import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ⚡ VIP Premium Neon / Futuristic Minimalist 2026
  static const Color background = Color(0xFF000000); // 🌑 Pure Black
  static const Color darkBackground = background;
  static const Color primary =
      Color(0xFF3B59FF); // 🔵 Royal Cyber Blue (Logo Inspired)
  static const Color secondary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF00D2FF); // 💎 Electric Cyan
  static const Color glow = Color(0xFF8A2BE2); // 🔮 Neon Purple
  static const Color surfaceColor =
      Color(0xFF0A0A12); // 🧱 Deep Space Surface
  static const Color surfaceSoft = Color(0xFF12121F); // ✨ Layer depth
  static const Color textGrey = Color(0xFFA0A0B0);

  // 🎯 Premium UI Specs
  static const double borderRadius = 20.0;
  static const double inputBorderRadius = 16.0;

  // 🎯 Premium SaaS Gradients
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF121225),
      Color(0xFF0A0A12),
    ],
  );

  // 🌈 Premium Cyber Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  // 🧠 Text Colors
  static const Color textHeader = Color(0xFFFFFFFF);
  static const Color textSub = Color(0xFFB0B0B0);
  static const Color textMain = Color(0xFF1F2937);

  // Defaults
  static const Color bgMain = Color(0xFFF7F9FF);
  static const Color glassDark = Color(0xFFFFFFFF);

  // 🧠 Psychology Mapping (VIP Version)
  static const Color colorCreative = primary;
  static const Color colorExcitement = Color(0xFFFF2D55); // Neon Red
  static const Color colorTrust = Color(0xFF2962FF); // Laser Blue
  static const Color colorFriendly = accent;
  static const Color colorOptimism = Color(0xFFFBBF24);
  static const Color colorGrowth = primary;

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    fontFamily: GoogleFonts.tajawal().fontFamily,
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
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        inherit: true,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: textMain,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        inherit: true,
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: textMain,
      ),
      headlineLarge: TextStyle(
        inherit: true,
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: textMain,
      ),
      titleMedium: TextStyle(
        inherit: true,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textMain,
      ),
      bodyLarge: TextStyle(
        inherit: true,
        fontSize: 16,
        color: textMain,
      ),
      bodyMedium: TextStyle(
        inherit: true,
        fontSize: 14,
        color: textSub,
      ),
      labelLarge: TextStyle(
        inherit: true,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textMain,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgMain,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textMain),
      titleTextStyle: TextStyle(
        inherit: true,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textMain,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          inherit: true,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          inherit: true,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: const TextStyle(
        inherit: true,
        color: textSub,
        fontSize: 16,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: Colors.black12, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: primary.withValues(alpha: 0.1),
      labelStyle: const TextStyle(
        inherit: true,
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    fontFamily: GoogleFonts.tajawal().fontFamily,
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
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        inherit: true,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          inherit: true,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          inherit: true,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: const TextStyle(
        inherit: true,
        color: textSub,
        fontSize: 16,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        inherit: true,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: textHeader,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        inherit: true,
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: textHeader,
      ),
      headlineLarge: TextStyle(
        inherit: true,
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: textHeader,
      ),
      titleMedium: TextStyle(
        inherit: true,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textHeader,
      ),
      bodyLarge: TextStyle(
        inherit: true,
        fontSize: 16,
        color: textHeader,
      ),
      bodyMedium: TextStyle(
        inherit: true,
        fontSize: 14,
        color: textSub,
      ),
      labelLarge: TextStyle(
        inherit: true,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textHeader,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: primary.withValues(alpha: 0.1),
      labelStyle: const TextStyle(
        inherit: true,
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );

  static const fluentPurple = primary;
  static const fluentPurpleLight = Color(0xFF2ECC71); // Soft Emerald
  static const fluentBlue = Color(0xFF00D4FF);
  static const fluentGrey = Color(0xFF8D8D8D);
}
