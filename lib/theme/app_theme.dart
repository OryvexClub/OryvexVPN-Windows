import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF00E5FF);
  static const background = Color(0xFF09090B);
  static const surface = Color(0xFF18181B);
  static const error = Color(0xFFFF3B30);
  static const warning = Color(0xFFFF9800);
  static const success = Color(0xFF34C759);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: primary,
        fontFamily: 'Vazirmatn',
        colorScheme: const ColorScheme.dark(
          primary: primary,
          surface: surface,
          error: error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
      );
}
