import 'package:flutter/material.dart';

class AppTheme {
  // Color schemes - Professional Dark Theme (Creative Tool style)
  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFBB86FC),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF3700B3),
    onPrimaryContainer: Color(0xFFEADDFF),
    secondary: Color(0xFF03DAC6),
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFF018786),
    onSecondaryContainer: Color(0xFFDAFFF6),
    tertiary: Color(0xFFCF6679),
    onTertiary: Color(0xFF000000),
    error: Color(0xFFCF6679),
    onError: Color(0xFF000000),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFE1E1E1),
    surfaceContainerHighest: Color(0xFF1E1E1E),
    onSurfaceVariant: Color(0xFFB0B0B0),
    outline: Color(0xFF333333),
    outlineVariant: Color(0xFF444444),
    inverseSurface: Color(0xFFE1E1E1),
    onInverseSurface: Color(0xFF121212),
    inversePrimary: Color(0xFF6200EE),
  );

  /// Calculate responsive scale factor based on screen width
  /// Base width is 1200px (optimized for small-medium desktop windows)
  /// Minimum scale is 1.0 to ensure readability at small sizes
  static double _getScaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return (screenWidth / 1200).clamp(1.0, 1.6);
  }

  /// Get responsive theme based on current screen size
  static ThemeData responsiveTheme(BuildContext context) {
    final scale = _getScaleFactor(context);

    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34 * scale, // Increased from 32
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 26 * scale, // Increased from 24
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 22 * scale, // Increased from 20
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 18 * scale, // Increased from 16
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        titleSmall: TextStyle(
          fontSize: 16 * scale, // Increased from 14
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16 * scale, // Kept at 16
          color: const Color(0xFFE1E1E1),
        ),
        bodyMedium: TextStyle(
          fontSize: 15 * scale, // Increased from 14
          color: const Color(0xFFB0B0B0),
        ),
        bodySmall: TextStyle(
          fontSize: 13 * scale, // Increased from 12
          color: const Color(0xFFB0B0B0),
        ),
        labelLarge: TextStyle(
          fontSize: 15 * scale, // Increased from 14
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        labelMedium: TextStyle(
          fontSize: 13 * scale, // Increased from 12
          fontWeight: FontWeight.w500,
          color: const Color(0xFFB0B0B0),
        ),
        labelSmall: TextStyle(
          fontSize: 12 * scale, // Increased from 11
          fontWeight: FontWeight.w400,
          color: const Color(0xFFB0B0B0),
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * scale),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBB86FC),
          foregroundColor: Colors.black,
          minimumSize: Size(88 * scale, 48 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14 * scale,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 12 * scale,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF444444)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 12 * scale,
          ),
          textStyle: TextStyle(fontSize: 14 * scale),
        ),
      ),

      iconTheme: IconThemeData(size: 24 * scale),
    );
  }

  /// Non-responsive dark theme (fallback for initialization)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFE1E1E1)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBB86FC),
          foregroundColor: Colors.black,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF444444)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  /// Get responsive light theme based on current screen size
  static ThemeData responsiveLightTheme(BuildContext context) {
    final scale = _getScaleFactor(context);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF6200EE),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFBB86FC),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFF018786),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF03DAC6),
        onSecondaryContainer: Color(0xFF000000),
        tertiary: Color(0xFFB00020),
        onTertiary: Color(0xFFFFFFFF),
        error: Color(0xFFB00020),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFAFAFA),
        onSurface: Color(0xFF1A1A1A),
        surfaceContainerHighest: Color(0xFFEEEEEE),
        onSurfaceVariant: Color(0xFF424242),
        outline: Color(0xFFBDBDBD),
        outlineVariant: Color(0xFFE0E0E0),
        inverseSurface: Color(0xFF121212),
        onInverseSurface: Color(0xFFF5F5F5),
        inversePrimary: Color(0xFFBB86FC),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34 * scale, // Increased from 32
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1A1A),
        ),
        headlineMedium: TextStyle(
          fontSize: 26 * scale, // Increased from 24
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
        titleLarge: TextStyle(
          fontSize: 22 * scale, // Increased from 20
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
        titleMedium: TextStyle(
          fontSize: 18 * scale, // Increased from 16
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1A1A1A),
        ),
        titleSmall: TextStyle(
          fontSize: 16 * scale, // Increased from 14
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1A1A1A),
        ),
        bodyLarge: TextStyle(
          fontSize: 16 * scale, // Kept at 16
          color: const Color(0xFF424242),
        ),
        bodyMedium: TextStyle(
          fontSize: 15 * scale, // Increased from 14
          color: const Color(0xFF616161),
        ),
        bodySmall: TextStyle(
          fontSize: 13 * scale, // Increased from 12
          color: const Color(0xFF757575),
        ),
        labelLarge: TextStyle(
          fontSize: 15 * scale, // Increased from 14
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1A1A1A),
        ),
        labelMedium: TextStyle(
          fontSize: 13 * scale, // Increased from 12
          fontWeight: FontWeight.w500,
          color: const Color(0xFF616161),
        ),
        labelSmall: TextStyle(
          fontSize: 12 * scale, // Increased from 11
          fontWeight: FontWeight.w400,
          color: const Color(0xFF757575),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * scale),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6200EE),
          foregroundColor: Colors.white,
          minimumSize: Size(88 * scale, 48 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14 * scale,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 12 * scale,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6200EE),
          side: const BorderSide(color: Color(0xFFBDBDBD)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 12 * scale,
          ),
          textStyle: TextStyle(fontSize: 14 * scale),
        ),
      ),

      iconTheme: IconThemeData(size: 24 * scale),
    );
  }

  /// Non-responsive light theme (fallback for initialization)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF6200EE),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFBB86FC),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFF018786),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF03DAC6),
        onSecondaryContainer: Color(0xFF000000),
        tertiary: Color(0xFFB00020),
        onTertiary: Color(0xFFFFFFFF),
        error: Color(0xFFB00020),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFAFAFA),
        onSurface: Color(0xFF1A1A1A),
        surfaceContainerHighest: Color(0xFFEEEEEE),
        onSurfaceVariant: Color(0xFF424242),
        outline: Color(0xFFBDBDBD),
        outlineVariant: Color(0xFFE0E0E0),
        inverseSurface: Color(0xFF121212),
        onInverseSurface: Color(0xFFF5F5F5),
        inversePrimary: Color(0xFFBB86FC),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF424242)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF616161)),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6200EE),
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6200EE),
          side: const BorderSide(color: Color(0xFFBDBDBD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}
