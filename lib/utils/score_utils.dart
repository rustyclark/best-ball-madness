import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Helper mapping cell scores to global AppColors based on score_type or math.
class ColorPair {
  final Color bg;
  final Color text;
  const ColorPair(this.bg, this.text);
}

ColorPair getScoreColors(int? score, int par, [String? scoreType]) {
  if (score == null) {
    return const ColorPair(AppColors.cardBg, AppColors.textPrimary);
  }

  final diff = score - par;
  final type = scoreType ?? _getScoreTypeFromDiff(diff);

  switch (type.toUpperCase()) {
    case 'EAGLE':
    case 'DOUBLE_EAGLE':
    case 'ALBATROSS':
      return const ColorPair(
        AppColors.scoreEagleOrBetterBg,
        AppColors.scoreEagleOrBetterText,
      );
    case 'BIRDIE':
      return const ColorPair(
        AppColors.scoreBirdieBg,
        AppColors.scoreBirdieText,
      );
    case 'PAR':
      return const ColorPair(AppColors.scoreParBg, AppColors.scoreParText);
    case 'BOGEY':
      return const ColorPair(AppColors.scoreBogeyBg, AppColors.scoreBogeyText);
    case 'DOUBLE_BOGEY':
    case 'DOUBLE_BOGEY_OR_WORSE':
      return const ColorPair(
        AppColors.scoreDoubleWorseBg,
        AppColors.scoreDoubleWorseText,
      );
    default:
      if (diff <= -2) {
        return const ColorPair(
          AppColors.scoreEagleOrBetterBg,
          AppColors.scoreEagleOrBetterText,
        );
      } else if (diff == -1) {
        return const ColorPair(
          AppColors.scoreBirdieBg,
          AppColors.scoreBirdieText,
        );
      } else if (diff == 0) {
        return const ColorPair(AppColors.scoreParBg, AppColors.scoreParText);
      } else if (diff == 1) {
        return const ColorPair(
          AppColors.scoreBogeyBg,
          AppColors.scoreBogeyText,
        );
      } else {
        return const ColorPair(
          AppColors.scoreDoubleWorseBg,
          AppColors.scoreDoubleWorseText,
        );
      }
  }
}

String _getScoreTypeFromDiff(int diff) {
  if (diff <= -2) return 'EAGLE';
  if (diff == -1) return 'BIRDIE';
  if (diff == 0) return 'PAR';
  if (diff == 1) return 'BOGEY';
  return 'DOUBLE_BOGEY';
}

/// Helper function to format tee times into display local time (e.g. 10:30 AM)
String formatTeeTime(DateTime dateTime) {
  final localTime = dateTime.toLocal();
  final hour = localTime.hour;
  final minute = localTime.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:$minute $period';
}
