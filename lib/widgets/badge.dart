import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class BbmBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const BbmBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  // Factory constructor for Tournament status
  factory BbmBadge.tournamentStatus(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return const BbmBadge(
          label: 'SCHEDULED',
          backgroundColor: AppColors.statusScheduledBg,
          textColor: AppColors.statusScheduledText,
          icon: Icons.calendar_today,
        );
      case 'IN_PROGRESS':
      case 'LIVE':
        return const BbmBadge(
          label: 'LIVE',
          backgroundColor: AppColors.statusLiveBg,
          textColor: AppColors.statusLiveText,
          icon: Icons.play_arrow,
        );
      case 'SUSPENDED':
        return const BbmBadge(
          label: 'SUSPENDED',
          backgroundColor: AppColors.statusSuspendedBg,
          textColor: AppColors.statusSuspendedText,
          icon: Icons.cloud_queue,
        );
      case 'COMPLETED':
        return const BbmBadge(
          label: 'COMPLETED',
          backgroundColor: AppColors.statusCompletedBg,
          textColor: AppColors.statusCompletedText,
          icon: Icons.emoji_events,
        );
      default:
        return BbmBadge(
          label: status,
          backgroundColor: AppColors.cardBg,
          textColor: AppColors.textSecondary,
        );
    }
  }

  // Factory constructor for Team status
  factory BbmBadge.teamStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const BbmBadge(
          label: 'ACTIVE',
          backgroundColor: AppColors.scoreBirdieBg,
          textColor: AppColors.scoreBirdieText,
        );
      case 'CUT':
        return const BbmBadge(
          label: 'CUT',
          backgroundColor: AppColors.statusCutBg,
          textColor: AppColors.statusCutText,
        );
      case 'DQ':
        return const BbmBadge(
          label: 'DQ',
          backgroundColor: AppColors.statusDqBg,
          textColor: AppColors.statusDqText,
        );
      default:
        return BbmBadge(
          label: status,
          backgroundColor: AppColors.cardBg,
          textColor: AppColors.textSecondary,
        );
    }
  }

  // Factory constructor for Golfer status (MC / WD)
  factory BbmBadge.golferStatus(String status) {
    switch (status.toUpperCase()) {
      case 'WD':
        return const BbmBadge(
          label: 'WD',
          backgroundColor: AppColors.scoreDoubleWorseBg,
          textColor: AppColors.scoreDoubleWorseText,
        );
      case 'MC':
        return const BbmBadge(
          label: 'MC',
          backgroundColor: AppColors.scoreBogeyBg,
          textColor: AppColors.scoreBogeyText,
        );
      default:
        return const BbmBadge(
          label: 'ACTIVE',
          backgroundColor: AppColors.scoreBirdieBg,
          textColor: AppColors.scoreBirdieText,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.borderRadiusRound,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
