import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leaderboard_providers.dart';
import '../../providers/draft_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/table.dart';
import '../scorecard/scorecard_screen.dart';

/// Leaderboard screen displaying current tournament standings.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final Set<String> _expandedTeamIds = {};

  String _formatScoreToPar(int? score) {
    if (score == null) return '-';
    if (score == 0) return 'E';
    if (score > 0) return '+$score';
    return '$score';
  }

  int? _getCurrentRoundScore(LeaderboardStanding standing, int currentRound) {
    switch (currentRound) {
      case 1:
        return standing.r1;
      case 2:
        return standing.r2;
      case 3:
        return standing.r3;
      case 4:
        return standing.r4;
      default:
        return standing.r1;
    }
  }

  bool _isTied(
    LeaderboardStanding standing,
    List<LeaderboardStanding> activeStandings,
  ) {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standingsAsync = ref.watch(leaderboardProvider);
    final tournamentAsync = ref.watch(activeTournamentProvider);

    return ResponsiveLayout(
      appBar: AppBar(title: const Text('TOURNAMENT LEADERBOARD')),
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

              final tournament = tournamentAsync.value;
              final currentRound = tournament?.currentRound ?? 1;

              final activeStandings = standings
                  .where((s) => s.status == 'ACTIVE')
                  .toList();
              final cutStandings = standings
                  .where((s) => s.status == 'CUT')
                  .toList();
              final dqStandings = standings
                  .where((s) => s.status == 'DQ')
                  .toList();

              final tableRows = <Widget>[];

              // Column ratios: Rank, Team Name, R[Current Round], To Par
              const columnWidths = [1.0, 2.8, 1.2, 1.5];

              // Build ACTIVE section
              if (activeStandings.isNotEmpty) {
                // ACTIVE COMPETITORS line is removed!
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
                      currentRound: currentRound,
                      isExpanded: _expandedTeamIds.contains(standing.teamId),
                      onTap: () {
                        setState(() {
                          if (_expandedTeamIds.contains(standing.teamId)) {
                            _expandedTeamIds.remove(standing.teamId);
                          } else {
                            _expandedTeamIds.add(standing.teamId);
                          }
                        });
                      },
                    ),
                  );

                  if (_expandedTeamIds.contains(standing.teamId)) {
                    tableRows.add(
                      _buildExpandedRoundsRow(
                        context: context,
                        standing: standing,
                        theme: theme,
                      ),
                    );
                  }
                }
              }

              // Build CUT section
              if (cutStandings.isNotEmpty) {
                tableRows.add(
                  _buildSectionHeader(
                    'CUT / ELIMINATED',
                    AppColors.statusCutBg,
                    theme,
                  ),
                );
                for (final standing in cutStandings) {
                  tableRows.add(
                    _buildStandingRow(
                      context: context,
                      standing: standing,
                      rankText: '-',
                      columnWidths: columnWidths,
                      theme: theme,
                      currentRound: currentRound,
                      isExpanded: _expandedTeamIds.contains(standing.teamId),
                      onTap: () {
                        setState(() {
                          if (_expandedTeamIds.contains(standing.teamId)) {
                            _expandedTeamIds.remove(standing.teamId);
                          } else {
                            _expandedTeamIds.add(standing.teamId);
                          }
                        });
                      },
                    ),
                  );

                  if (_expandedTeamIds.contains(standing.teamId)) {
                    tableRows.add(
                      _buildExpandedRoundsRow(
                        context: context,
                        standing: standing,
                        theme: theme,
                      ),
                    );
                  }
                }
              }

              // Build DQ section
              if (dqStandings.isNotEmpty) {
                tableRows.add(
                  _buildSectionHeader(
                    'DISQUALIFIED',
                    AppColors.statusDqBg,
                    theme,
                  ),
                );
                for (final standing in dqStandings) {
                  tableRows.add(
                    _buildStandingRow(
                      context: context,
                      standing: standing,
                      rankText: '-',
                      columnWidths: columnWidths,
                      theme: theme,
                      currentRound: currentRound,
                      isExpanded: _expandedTeamIds.contains(standing.teamId),
                      onTap: () {
                        setState(() {
                          if (_expandedTeamIds.contains(standing.teamId)) {
                            _expandedTeamIds.remove(standing.teamId);
                          } else {
                            _expandedTeamIds.add(standing.teamId);
                          }
                        });
                      },
                    ),
                  );

                  if (_expandedTeamIds.contains(standing.teamId)) {
                    tableRows.add(
                      _buildExpandedRoundsRow(
                        context: context,
                        standing: standing,
                        theme: theme,
                      ),
                    );
                  }
                }
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  child: BbmCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
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
                            minWidth: 360.0,
                            columnWidths: columnWidths,
                            headers: [
                              Center(
                                child: Text(
                                  'POS',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Text('Team', style: theme.textTheme.labelLarge),
                              Center(
                                child: Text(
                                  'RND $currentRound',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Center(
                                child: Text(
                                  'TOT',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
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
    required int currentRound,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return BbmTableRow(
      columnWidths: columnWidths,
      backgroundColor: isExpanded
          ? AppColors.primary.withValues(alpha: 0.05)
          : null,
      onTap: onTap,
      cells: [
        Center(
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
        Center(
          child: Text(
            _formatScoreToPar(_getCurrentRoundScore(standing, currentRound)),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Center(
          child: Text(
            _formatScoreToPar(standing.totalToPar),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: standing.totalToPar < 0
                  ? AppColors.primaryHover
                  : standing.totalToPar > 0
                  ? AppColors.scoreBogeyBg
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedRoundsRow({
    required BuildContext context,
    required LeaderboardStanding standing,
    required ThemeData theme,
  }) {
    return Container(
      color: AppColors.alternateRow.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          const SizedBox(width: 40), // Spacer matching Rank column
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildExpandedRoundCell(theme, 'R1', standing.r1),
                _buildExpandedRoundCell(theme, 'R2', standing.r2),
                _buildExpandedRoundCell(theme, 'R3', standing.r3),
                _buildExpandedRoundCell(theme, 'R4', standing.r4),
                // Scorecard shortcut button
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ScorecardScreen(teamId: standing.teamId),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.analytics_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: 'View scorecard',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedRoundCell(ThemeData theme, String label, int? score) {
    final hasScore = score != null;
    final isUnderPar = hasScore && score < 0;
    final isOverPar = hasScore && score > 0;

    Color scoreColor = AppColors.textPrimary;
    Color bgScoreColor = Colors.transparent;

    if (isUnderPar) {
      scoreColor = AppColors.primaryHover;
      bgScoreColor = AppColors.primary.withValues(alpha: 0.08);
    } else if (isOverPar) {
      scoreColor = AppColors.scoreBogeyBg;
      bgScoreColor = AppColors.scoreBogeyBg.withValues(alpha: 0.08);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: bgScoreColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: bgScoreColor != Colors.transparent
                  ? scoreColor.withValues(alpha: 0.2)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            _formatScoreToPar(score),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
        ),
      ],
    );
  }
}
