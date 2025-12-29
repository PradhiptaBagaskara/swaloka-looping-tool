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
          side: const BorderSide(color: Color(0xFF333333), width: 1),
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

  // Fallback light theme (similar structure but light)
  static ThemeData get lightTheme =>
      darkTheme; // For now, keep it dark for "Looping Tool" feel
}
