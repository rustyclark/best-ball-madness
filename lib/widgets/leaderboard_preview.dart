import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/leaderboard_providers.dart';
import '../providers/draft_providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import 'button.dart';
import 'card.dart';
import 'table.dart';

class LeaderboardPreview extends ConsumerWidget {
  final bool showButton;

  const LeaderboardPreview({super.key, this.showButton = true});

  String _formatScoreToPar(int? score) {
    if (score == null) return '-';
    if (score == 0) return 'E';
    if (score > 0) return '+$score';
    return '$score';
  }

  bool _isTied(
    LeaderboardStanding standing,
    List<LeaderboardStanding> activeStandings,
  ) {
    if (standing.status != 'ACTIVE' || standing.rank == null) return false;
    return activeStandings.where((s) => s.rank == standing.rank).length > 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final standingsAsync = ref.watch(leaderboardProvider);
    final userTeamAsync = ref.watch(userTeamProvider);

    final userTeam = userTeamAsync.value;

    return BbmCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'LEADERBOARD STANDINGS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            standingsAsync.when(
              data: (standings) {
                if (standings.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('No standings available yet.'),
                    ),
                  );
                }

                final activeStandings = standings
                    .where((s) => s.status == 'ACTIVE')
                    .toList();

                // Get top 3
                final top3 = standings.take(3).toList();
                final bool userInTop3 =
                    userTeam != null &&
                    top3.any((s) => s.teamId == userTeam.id);

                LeaderboardStanding? userStanding;
                if (userTeam != null && !userInTop3) {
                  final matches = standings.where(
                    (s) => s.teamId == userTeam.id,
                  );
                  if (matches.isNotEmpty) {
                    userStanding = matches.first;
                  }
                }

                const columnWidths = [1.0, 4.0, 1.5];

                final rows = <Widget>[
                  ...List.generate(top3.length, (index) {
                    final standing = top3[index];
                    final isUserRow =
                        userTeam != null && standing.teamId == userTeam.id;
                    final tied = _isTied(standing, activeStandings);
                    final rankText = standing.rank != null
                        ? (tied ? 'T-${standing.rank}' : '${standing.rank}')
                        : '-';

                    return _buildStandingRow(
                      context: context,
                      standing: standing,
                      rankText: rankText,
                      columnWidths: columnWidths,
                      theme: theme,
                      isHighlighted: isUserRow,
                      backgroundColor: index % 2 == 1
                          ? AppColors.alternateRow
                          : Colors.transparent,
                    );
                  }),

                  if (userStanding != null) ...[
                    // Divider or Ellipsis to show gap
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.more_vert,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                    _buildStandingRow(
                      context: context,
                      standing: userStanding,
                      rankText: userStanding.rank != null
                          ? (_isTied(userStanding, activeStandings)
                                ? 'T-${userStanding.rank}'
                                : '${userStanding.rank}')
                          : '-',
                      columnWidths: columnWidths,
                      theme: theme,
                      isHighlighted: true,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ],
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BbmTable(
                      minWidth: 300.0,
                      columnWidths: columnWidths,
                      headers: [
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.md),
                          child: Text(
                            'Rank',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        Text('Team Name', style: theme.textTheme.labelMedium),
                        Center(
                          child: Text(
                            'Score',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ],
                      rows: rows,
                    ),
                    if (showButton) ...[
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: BbmButton(
                          text: 'View Leaderboard',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LeaderboardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Error loading standings: $err'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingRow({
    required BuildContext context,
    required LeaderboardStanding standing,
    required String rankText,
    required List<double> columnWidths,
    required ThemeData theme,
    required bool isHighlighted,
    required Color backgroundColor,
  }) {
    return BbmTableRow(
      columnWidths: columnWidths,
      backgroundColor: isHighlighted
          ? AppColors.primary.withValues(alpha: 0.1)
          : backgroundColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
        );
      },
      cells: [
        // Rank
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Text(
            rankText,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),

        // Team Name
        Text(
          isHighlighted
              ? '${standing.teamName.toUpperCase()} (YOU)'
              : standing.teamName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? AppColors.primary : AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // Score
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: standing.totalToPar < 0
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : (standing.totalToPar > 0
                        ? AppColors.scoreBogeyBg.withValues(alpha: 0.15)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              _formatScoreToPar(standing.totalToPar),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: standing.totalToPar < 0
                    ? AppColors.accent
                    : (standing.totalToPar > 0
                          ? AppColors.scoreBogeyBg
                          : AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
