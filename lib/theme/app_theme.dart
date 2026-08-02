import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF00E676);
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const error = Color(0xFFFF3366);
  static const warning = Color(0xFFFFB800);
  static const success = Color(0xFF00C853);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: primary,
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
