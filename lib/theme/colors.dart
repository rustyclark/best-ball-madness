import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // PGA Tour / Golfer-Centric Core Palette
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBg = Color(
    0xFFF8FAFC,
  ); // Slate-50 for subtle container contrast
  static const Color border = Color(
    0xFFE2E8F0,
  ); // Slate-200 for thin premium dividers
  static const Color primary = Color(0xFF003C80); // PGA Tour Deep Navy Blue
  static const Color primaryHover = Color(0xFF0056B3); // Brighter Royal Blue
  static const Color accent = Color(
    0xFF047857,
  ); // Golf Emerald Green (accent highlight)
  static const Color alternateRow = Color(
    0xFFF1F5F9,
  ); // Slate-100 for alternating scorecard rows

  // Text Colors (High Contrast on White/Slate-50)
  static const Color textPrimary = Color(
    0xFF0F172A,
  ); // Slate-900 (main body text)
  static const Color textSecondary = Color(
    0xFF475569,
  ); // Slate-600 (subtitles and secondary text)
  static const Color textMuted = Color(
    0xFF94A3B8,
  ); // Slate-400 (hints and placeholders)

  // Score Color Constants (Softer and golfer-friendly, not neon)
  // Eagle or better: score - par <= -2
  static const Color scoreEagleOrBetterBg = Color(0xFF065F46); // Pine Green-800
  static const Color scoreEagleOrBetterText = Color(0xFFFFFFFF);

  // Birdie: score - par = -1
  static const Color scoreBirdieBg = Color(0xFF10B981); // Emerald Green-500
  static const Color scoreBirdieText = Color(0xFFFFFFFF);

  // Par: score - par = 0
  static const Color scoreParBg = Color(0xFFF1F5F9); // Light Slate-100
  static const Color scoreParText = Color(0xFF475569); // Slate-600

  // Bogey: score - par = 1
  static const Color scoreBogeyBg = Color(0xFFEF4444); // Soft Red-500
  static const Color scoreBogeyText = Color(0xFFFFFFFF);

  // Double Bogey or worse: score - par >= 2
  static const Color scoreDoubleWorseBg = Color(0xFF7F1D1D); // Deep Crimson-900
  static const Color scoreDoubleWorseText = Color(0xFFFFFFFF);

  // Status Colors (Premium Badges)
  static const Color statusScheduledBg = Color(0xFFDBEAFE); // Light Blue-100
  static const Color statusScheduledText = Color(0xFF1E40AF); // Blue-800

  static const Color statusLiveBg = Color(0xFFFEF3C7); // Light Amber-100
  static const Color statusLiveText = Color(0xFFB45309); // Amber-700

  static const Color statusSuspendedBg = Color(0xFFF3F4F6); // Grey-100
  static const Color statusSuspendedText = Color(0xFF374151); // Grey-800

  static const Color statusCompletedBg = Color(0xFFD1FAE5); // Emerald-100
  static const Color statusCompletedText = Color(0xFF065F46); // Emerald-800

  static const Color statusCutBg = Color(0xFFF3E8FF); // Purple-100
  static const Color statusCutText = Color(0xFF6B21A8); // Purple-800

  static const Color statusDqBg = Color(0xFFFEE2E2); // Red-100
  static const Color statusDqText = Color(0xFF991B1B); // Red-800
}
