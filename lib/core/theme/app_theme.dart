import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          onSurface: AppColors.onSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.lexend(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02 * 48,
            color: AppColors.onSurface,
          ),
          headlineLarge: GoogleFonts.lexend(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.01 * 32,
            color: AppColors.onSurface,
          ),
          headlineMedium: GoogleFonts.lexend(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurface,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurface,
          ),
          labelMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.05 * 14,
            color: AppColors.onSurfaceVariant,
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08 * 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
}
