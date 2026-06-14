import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // Spacing values
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // EdgeInsets Helper constants
  static const EdgeInsets edgeInsetsXS = EdgeInsets.all(xs);
  static const EdgeInsets edgeInsetsSM = EdgeInsets.all(sm);
  static const EdgeInsets edgeInsetsMD = EdgeInsets.all(md);
  static const EdgeInsets edgeInsetsLG = EdgeInsets.all(lg);

  // Border Radius values
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusRound = 999.0;

  static const BorderRadius borderRadiusSm = BorderRadius.all(
    Radius.circular(radiusSm),
  );
  static const BorderRadius borderRadiusMd = BorderRadius.all(
    Radius.circular(radiusMd),
  );
  static const BorderRadius borderRadiusLg = BorderRadius.all(
    Radius.circular(radiusLg),
  );
  static const BorderRadius borderRadiusXl = BorderRadius.all(
    Radius.circular(radiusXl),
  );
  static const BorderRadius borderRadiusRound = BorderRadius.all(
    Radius.circular(radiusRound),
  );
}
