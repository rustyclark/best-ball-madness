import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/draft_providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'badge.dart';
import 'card.dart';
import 'empty_state.dart';
import 'skeleton.dart';

class TournamentHeader extends ConsumerWidget {
  const TournamentHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(activeTournamentProvider);
    final golfersAsync = ref.watch(golferListProvider);

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return const BbmCard(
            child: BbmEmptyState(
              title: 'No Active Tournament',
              message:
                  'Check back soon! The next PGA Tour event will lock on Thursday morning.',
            ),
          );
        }

        final fieldSize = golfersAsync.when(
          data: (list) => list.length,
          loading: () => 0,
          error: (err, stack) => 0,
        );

        final theme = Theme.of(context);

        return BbmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name.toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Expanded(
                              child: Text(
                                '${tournament.course}, ${tournament.location}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  BbmBadge.tournamentStatus(tournament.status),
                ],
              ),
              const Divider(color: AppColors.border, height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSpecItem(context, 'PAR', '${tournament.par}'),
                  _buildSpecItem(context, 'YARDS', '${tournament.yards}'),
                  _buildSpecItem(context, 'FIELD SIZE', '$fieldSize'),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const BbmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BbmSkeleton(width: 200, height: 24),
                BbmSkeleton(width: 80, height: 20),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            BbmSkeleton(width: 150, height: 16),
            Divider(color: AppColors.border, height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BbmSkeleton(width: 60, height: 30),
                BbmSkeleton(width: 60, height: 30),
                BbmSkeleton(width: 60, height: 30),
              ],
            ),
          ],
        ),
      ),
      error: (err, stack) => BbmCard(
        child: Text(
          'Error loading active tournament: $err',
          style: const TextStyle(color: AppColors.scoreBogeyBg),
        ),
      ),
    );
  }

  Widget _buildSpecItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
