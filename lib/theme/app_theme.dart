import 'package:flutter/material.dart';

/// Centralized design system for OryvexVPN.
/// All colors, gradients, shadows, and text styles are defined here.
class AppTheme {
  AppTheme._();

  // ── Color Tokens ──────────────────────────────────────────────────────
  static const primary = Color(0xFF00E676);
  static const accent = Color(0xFF00E5FF);
  static const background = Color(0xFF000000);
  static const backgroundEnd = Color(0xFF080D18);
  static const surface = Color(0xFF0A0A0A);
  static const surfaceLight = Color(0xFF0C0C0C);
  static const surfaceElevated = Color(0xFF080808);
  static const surfaceOverlay = Color(0xFF111111);
  static const border = Color(0xFF1A1A1A);
  static const borderLight = Color(0xFF222222);
  static const borderActive = Color(0xFF2A2A2E);
  static const error = Color(0xFFFF3366);
  static const errorLight = Color(0xFFFF6B8A);
  static const warning = Color(0xFFFFB800);
  static const success = Color(0xFF00C853);
  static const purple = Color(0xFF8B5CF6);
  static const neonCyan = Color(0xFF00E5FF);

  // Text colors
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF888891);
  static const textTertiary = Color(0xFF555555);
  static const textMuted = Colors.white54;
  static const textDim = Colors.white70;

  // ── Gradients ─────────────────────────────────────────────────────────
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Color(0xFF060A14), backgroundEnd],
    stops: [0.0, 0.5, 1.0],
  );

  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceElevated],
  );

  static const accentGradient = LinearGradient(
    colors: [accent, primary],
  );

  // ── Shadows & Glows ──────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double blurRadius = 20, double opacity = 0.15}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blurRadius,
        spreadRadius: blurRadius * 0.15,
      ),
    ];
  }

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  // ── Text Styles ───────────────────────────────────────────────────────
  static const TextStyle headingStyle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -1.0,
    fontFamily: 'Inter',
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 1,
  );

  static const TextStyle valueStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle monoStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textDim,
    fontFamily: 'Consolas',
    height: 1.5,
  );

  static const TextStyle statusStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 1,
  );

  static const TextStyle buttonLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // ── Decorations ───────────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surfaceElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surfaceElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
    boxShadow: subtleShadow,
  );

  static BoxDecoration containerDecoration({Color? borderColor}) => BoxDecoration(
    color: surfaceLight,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: borderColor ?? border),
  );

  static BoxDecoration glassDecoration({double borderRadius = 16}) => BoxDecoration(
    color: Colors.white.withOpacity(0.03),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: Colors.white.withOpacity(0.06)),
    boxShadow: subtleShadow,
  );

  // ── Animated Dialog Helper ────────────────────────────────────────────
  static Future<T?> showAnimatedDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool slideUp = false,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: slideUp ? Curves.easeOutCubic : Curves.easeOutBack,
        );
        if (slideUp) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        }
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // ── ThemeData ─────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: headingStyle,
      bodyMedium: subheadingStyle,
      labelSmall: labelStyle,
      bodyLarge: valueStyle,
      bodySmall: captionStyle,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceOverlay,
      contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight),
      ),
    ),
  );
}
