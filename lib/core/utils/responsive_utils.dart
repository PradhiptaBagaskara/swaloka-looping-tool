import 'package:flutter/widgets.dart';

/// Responsive utility for dynamic sizing based on screen dimensions
class ResponsiveUtils {
  /// Get responsive font size based on screen width
  /// Base size is optimized for ~1200px width (typical small-medium desktop window size)
  static double fontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Scale factor based on width, with min/max bounds
    // Using 1200 as base instead of 1920 for better small window readability
    final scaleFactor = (screenWidth / 1200).clamp(1.0, 1.6);
    return baseSize * scaleFactor;
  }

  /// Get responsive spacing based on screen width
  static double spacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = (screenWidth / 1200).clamp(1.0, 1.6);
    return baseSpacing * scaleFactor;
  }

  /// Get responsive icon size based on screen width
  static double iconSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = (screenWidth / 1200).clamp(1.0, 1.6);
    return baseSize * scaleFactor;
  }

  /// Check if screen is considered large (desktop/fullscreen)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1440;
  }

  /// Check if screen is considered medium (tablet)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1440;
  }

  /// Check if screen is considered small (mobile)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }
}
