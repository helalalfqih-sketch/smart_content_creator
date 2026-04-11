import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResponsiveHelper {
  // Use ScreenUtil for sizes via its native extensions or static methods
  static double get h => 1.h; // Height scale
  static double get w => 1.w; // Width scale
  static double get sp => 1.sp; // Font size scale

  // Responsive values based on screen width
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    double width = MediaQuery.of(context).size.width;
    if (width >= 1200 && desktop != null) return desktop;
    if (width >= 600 && tablet != null) return tablet;
    return mobile;
  }

  // Check device type
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  // Extension-like helpers for static values (using underlying ScreenUtil)
  static double setHeight(double height) => height.h;
  static double setWidth(double width) => width.w;
  static double setFontSize(double fontSize) => fontSize.sp;
}

class FluidGridHelper {
  static int calculateColumns(
    BoxConstraints constraints,
    double itemWidth, {
    int min = 2,
    int max = 6,
  }) {
    int count = (constraints.maxWidth / itemWidth).floor();
    return count.clamp(min, max);
  }

  static double calculateAspectRatio(double width, double height) {
    return width / height;
  }
}

// 🌐 Extension on BuildContext for quick responsive access
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isSmallDevice => screenWidth < 380;
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  double responsiveFontSize(double fontSize) {
    if (isSmallDevice) return fontSize * 0.85;
    if (isTablet) return fontSize * 1.1;
    if (isDesktop) return fontSize * 1.25;
    return fontSize;
  }

  double responsiveValue<T>({
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}
