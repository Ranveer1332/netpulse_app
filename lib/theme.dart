import 'package:flutter/material.dart';

/// NetPulse design tokens — Signal Green palette.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B1220);
  static const Color card = Color(0xFF111B2E);
  static const Color cardHover = Color(0xFF162035);
  static const Color teal = Color(0xFF34D3A8);
  static const Color blue = Color(0xFF5B8DEF);
  static const Color muted = Color(0xFF8792A8);
  static const Color text = Color(0xFFE8ECF4);
  static const Color textDim = Color(0xFF6B7790);
  static const Color danger = Color(0xFFEF5B5B);
  static const Color warn = Color(0xFFF0B840);
  static const Color border = Color(0x0FFFFFFF); // ~6% white
  static const Color surfaceBright = Color(0xFF323949);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.teal,
          secondary: AppColors.blue,
          surface: AppColors.card,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            letterSpacing: -0.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.text,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textDim,
            letterSpacing: 1.2,
          ),
        ),
      );
}
