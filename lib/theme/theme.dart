import 'package:flutter/material.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      cardColor: AppColors.cardBg,
      dividerColor: AppColors.border,
      textTheme: AppTypography.textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.border, width: 1),
          borderRadius: AppSpacing.borderRadiusLg,
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: AppColors.primary,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 1),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 1),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.scoreBogeyBg, width: 1),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        labelStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
