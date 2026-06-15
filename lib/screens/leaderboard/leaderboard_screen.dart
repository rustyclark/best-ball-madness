import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leaderboard_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/table.dart';
import '../scorecard/scorecard_screen.dart';

/// Leaderboard screen displaying current tournament standings.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  String _formatScoreToPar(int? score) {
    if (score == null) return '-';
    if (score == 0) return 'E';
    if (score > 0) return '+$score';
    return '$score';
  }

  bool _isTied(LeaderboardStanding standing, List<LeaderboardStanding> activeStandings) {
    if (standing.status != 'ACTIVE' || standing.rank == null) return false;
    return activeStandings.where((s) => s.rank == standing.rank).length > 1;
  }

  Widget _buildSectionHeader(String title, Color textColor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      color: textColor.withValues(alpha: 0.08),
      width: double.infinity,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final standingsAsync = ref.watch(leaderboardProvider);

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('TOURNAMENT LEADERBOARD'),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(leaderboardProvider.future),
          color: AppColors.primary,
          child: standingsAsync.when(
            data: (standings) {
              if (standings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text('No standings data available yet.'),
                  ),
                );
              }

              final activeStandings = standings.where((s) => s.status == 'ACTIVE').toList();
              final cutStandings = standings.where((s) => s.status == 'CUT').toList();
              final dqStandings = standings.where((s) => s.status == 'DQ').toList();

              final tableRows = <Widget>[];

              // Column ratios: Rank, Team Name, R1, R2, R3, R4, To Par
              const columnWidths = [1.0, 3.0, 1.0, 1.0, 1.0, 1.0, 1.2];

              // Build ACTIVE section
              if (activeStandings.isNotEmpty) {
                tableRows.add(_buildSectionHeader('ACTIVE COMPETITORS', AppColors.primary, theme));
                for (final standing in activeStandings) {
                  final tied = _isTied(standing, activeStandings);
                  final rankText = standing.rank != null
                      ? (tied ? 'T-${standing.rank}' : '${standing.rank}')
                      : '-';

                  tableRows.add(
                    _buildStandingRow(
                      context: context,
                      standing: standing,
                      rankText: rankText,
                      columnWidths: columnWidths,
                      theme: theme,
                    ),
                  );
                }
              }

              // Build CUT section
              if (cutStandings.isNotEmpty) {
                tableRows.add(_buildSectionHeader('CUT / ELIMINATED', AppColors.statusCutBg, theme));
                for (final standing in cutStandings) {
                  tableRows.add(
                    _buildStandingRow(
                      context: context,
                      standing: standing,
                      rankText: '-',
                      columnWidths: columnWidths,
                      theme: theme,
                    ),
                  );
                }
              }

              // Build DQ section
              if (dqStandings.isNotEmpty) {
                tableRows.add(_buildSectionHeader('DISQUALIFIED', AppColors.statusDqBg, theme));
                for (final standing in dqStandings) {
                  tableRows.add(
                    _buildStandingRow(
                      context: context,
                      standing: standing,
                      rankText: '-',
                      columnWidths: columnWidths,
                      theme: theme,
                    ),
                  );
                }
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: BbmCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_outlined, color: AppColors.primary, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'OVERALL STANDINGS',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          BbmTable(
                            minWidth: 600.0,
                            columnWidths: columnWidths,
                            headers: [
                              Text('Rank', style: theme.textTheme.labelLarge),
                              Text('Team Name', style: theme.textTheme.labelLarge),
                              Text('R1', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                              Text('R2', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                              Text('R3', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                              Text('R4', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                              Text('To Par', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                            ],
                            rows: tableRows,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Error loading leaderboard: $err',
                  style: const TextStyle(color: AppColors.scoreBogeyBg),
                ),
              ),
            ),
          ),
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
  }) {
    return BbmTableRow(
      columnWidths: columnWidths,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScorecardScreen(teamId: standing.teamId),
          ),
        );
      },
      cells: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Text(
            rankText,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          standing.teamName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          _formatScoreToPar(standing.r1),
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        Text(
          _formatScoreToPar(standing.r2),
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        Text(
          _formatScoreToPar(standing.r3),
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        Text(
          _formatScoreToPar(standing.r4),
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        Text(
          _formatScoreToPar(standing.totalToPar),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: standing.totalToPar < 0
                ? AppColors.primaryHover
                : standing.totalToPar > 0
                    ? AppColors.scoreBogeyBg
                    : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
