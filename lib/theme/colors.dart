import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Mode Core Palette
  static const Color background = Color(0xFF0D1117);
  static const Color cardBg = Color(0xFF161B22);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF2EA043); // Premium Golf Green
  static const Color primaryHover = Color(0xFF3FB950);
  static const Color accent = Color(0xFF58A6FF); // Premium Highlight Blue

  // Text Colors
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // Score Color Constants
  // Eagle or better: score - par <= -2
  static const Color scoreEagleOrBetterBg = Color(0xFF004D40); // Dark Teal/Green
  static const Color scoreEagleOrBetterText = Color(0xFFE0F2F1);

  // Birdie: score - par = -1
  static const Color scoreBirdieBg = Color(0xFF1B5E20); // Deep Green
  static const Color scoreBirdieText = Color(0xFFE8F5E9);

  // Par: score - par = 0
  static const Color scoreParBg = Color(0xFF2D3748); // Charcoal Grey
  static const Color scoreParText = Color(0xFFE2E8F0);

  // Bogey: score - par = 1
  static const Color scoreBogeyBg = Color(0xFFC62828); // Bright Crimson
  static const Color scoreBogeyText = Color(0xFFFFEBEE);

  // Double Bogey or worse: score - par >= 2
  static const Color scoreDoubleWorseBg = Color(0xFF7F0000); // Dark Crimson/Burgundy
  static const Color scoreDoubleWorseText = Color(0xFFFFEBEE);

  // Status Colors (Badges)
  static const Color statusScheduledBg = Color(0xFF1A237E);
  static const Color statusScheduledText = Color(0xFFE8EAF6);
  
  static const Color statusLiveBg = Color(0xFFE65100);
  static const Color statusLiveText = Color(0xFFFFF3E0);

  static const Color statusSuspendedBg = Color(0xFF3E2723);
  static const Color statusSuspendedText = Color(0xFFEFEBE9);

  static const Color statusCompletedBg = Color(0xFF1B5E20);
  static const Color statusCompletedText = Color(0xFFE8F5E9);

  static const Color statusCutBg = Color(0xFF4A148C);
  static const Color statusCutText = Color(0xFFF3E5F5);

  static const Color statusDqBg = Color(0xFF263238);
  static const Color statusDqText = Color(0xFFECEFF1);
}
