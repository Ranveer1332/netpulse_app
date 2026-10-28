import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF4EFE6);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardHover = Color(0xFFF0F0F0);
  static const Color teal = Color(0xFFFFC107); // Yellow
  static const Color blue = Color(0xFF2563EB); // Blue
  static const Color muted = Color(0xFF737373);
  static const Color text = Color(0xFF111111);
  static const Color textDim = Color(0xFF525252);
  static const Color danger = Color(0xFFEA4335);
  static const Color warn = Color(0xFFF59E0B);
  static const Color border = Color(0xFF000000); // Solid black
  static const Color surfaceBright = Color(0xFFFFFFFF);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.teal,
          secondary: AppColors.blue,
          surface: AppColors.card,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.text),
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          const TextTheme(
            headlineLarge: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: -0.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textDim,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
}
