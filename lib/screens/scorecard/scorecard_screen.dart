import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
import '../../providers/draft_providers.dart';
import '../../providers/scorecard_providers.dart';
import '../../providers/leaderboard_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/table.dart';

import '../../utils/score_utils.dart';

/// Interactive scorecard cell displaying a golfer's score, with a realtime green pulse animation.
class ScorecardCell extends ConsumerStatefulWidget {
  final String golferId;
  final int hole;
  final int? score;
  final String? scoreType;
  final int par;

  const ScorecardCell({
    super.key,
    required this.golferId,
    required this.hole,
    required this.score,
    required this.scoreType,
    required this.par,
  });

  @override
  ConsumerState<ScorecardCell> createState() => _ScorecardCellState();
}

class _ScorecardCellState extends ConsumerState<ScorecardCell> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for realtime score events matching this golfer and hole to trigger the pulse
    ref.listen<ScoreUpdateEvent?>(lastRealtimeScoreUpdateProvider, (previous, next) {
      if (next != null &&
          next.tournamentGolferId == widget.golferId &&
          next.hole == widget.hole) {
        if (next.scoreType == 'BIRDIE' || next.scoreType == 'EAGLE') {
          _pulseController.forward(from: 0.0);
        }
      }
    });

    final colors = getScoreColors(widget.score, widget.par, widget.scoreType);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        final cellColor = pulseVal > 0
            ? Color.lerp(colors.bg, AppColors.primary, pulseVal)
            : colors.bg;

        return Container(
          margin: const EdgeInsets.all(2.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: pulseVal > 0
                  ? AppColors.primaryHover.withValues(alpha: pulseVal)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            widget.score != null ? '${widget.score}' : '-',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

/// The Scorecard Screen displaying live score tracker for the drafted team.
class ScorecardScreen extends ConsumerWidget {
  final String? teamId;
  const ScorecardScreen({super.key, this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tournamentAsync = ref.watch(activeTournamentProvider);
    final golferListAsync = ref.watch(golferListProvider);

    final isCompetitor = teamId != null;
    final AsyncValue<UserTeam?> teamAsync = isCompetitor
        ? ref.watch(competitorTeamDetailsProvider(teamId!))
        : ref.watch(userTeamProvider);

    return ResponsiveLayout(
      appBar: AppBar(
        title: Text(isCompetitor
            ? (teamAsync.value?.teamName != null
                ? '${teamAsync.value!.teamName!.toUpperCase()} SCORECARD'
                : 'COMPETITOR SCORECARD')
            : 'LIVE SCORECARD'),
      ),
      child: SafeArea(
        child: teamAsync.when(
          data: (team) {
            if (team == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(isCompetitor
                      ? 'Competitor team not found.'
                      : 'No active team found. Please save a roster first.'),
                ),
              );
            }

            final selectedRound = ref.watch(selectedRoundProvider);
            
            // Activate the Supabase Realtime subscription for this round
            if (isCompetitor) {
              ref.watch(competitorScorecardSubscriptionProvider((teamId: teamId!, round: selectedRound)));
            } else {
              ref.watch(scorecardSubscriptionProvider(selectedRound));
            }

            // Watch live statuses
            final String teamStatus;
            if (isCompetitor) {
              teamStatus = team.status;
            } else {
              final teamStatusAsync = ref.watch(teamStatusProvider);
              teamStatus = teamStatusAsync.value ?? team.status;
            }

            final tournament = tournamentAsync.value;
            final weatherSuspended = tournament?.status == 'SUSPENDED';

            // Fetch scores and tee times
            final AsyncValue<List<TeamHoleScore>> teamScoresAsync;
            final AsyncValue<List<HoleScore>> golferScoresAsync;
            final AsyncValue<List<TeeTime>> teeTimesAsync;

            if (isCompetitor) {
              final allScoresAsync = ref.watch(competitorTeamProvider(teamId!));
              teamScoresAsync = allScoresAsync.whenData((allScores) =>
                  allScores.where((s) => s.round == selectedRound).toList());
              golferScoresAsync = ref.watch(competitorGolfersHoleScoresProvider((teamId: teamId!, round: selectedRound)));
              teeTimesAsync = ref.watch(competitorGolfersTeeTimesProvider((teamId: teamId!, round: selectedRound)));
            } else {
              teamScoresAsync = ref.watch(userTeamScoreProvider(selectedRound));
              golferScoresAsync = ref.watch(teamGolfersHoleScoresProvider(selectedRound));
              teeTimesAsync = ref.watch(teamGolfersTeeTimesProvider(selectedRound));
            }

            final golfers = golferListAsync.value ?? [];
            final teamGolfers = golfers.where((g) => team.golferIds.contains(g.id)).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banners
                  if (weatherSuspended) ...[
                    _buildBanner(
                      text: 'WEATHER DELAY: Play is currently suspended.',
                      bgColor: AppColors.statusSuspendedBg,
                      textColor: AppColors.statusSuspendedText,
                      icon: Icons.thunderstorm_outlined,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  if (teamStatus == 'CUT') ...[
                    _buildBanner(
                      text: 'TEAM ELIMINATED: Your team missed the cut.',
                      bgColor: AppColors.statusCutBg,
                      textColor: AppColors.statusCutText,
                      icon: Icons.cancel_outlined,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ] else if (teamStatus == 'DQ') ...[
                    _buildBanner(
                      text: 'TEAM DISQUALIFIED: Your team has been disqualified for failing to draft a legal roster (incomplete roster or over budget) before the tournament lock time.',
                      bgColor: AppColors.statusDqBg,
                      textColor: AppColors.statusDqText,
                      icon: Icons.gavel_outlined,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Team Info Card
                  BbmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament?.name.toUpperCase() ?? 'ACTIVE TOURNAMENT',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'TEAM RESULTS',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Round Selector
                  _buildRoundSelector(ref, selectedRound),
                  const SizedBox(height: AppSpacing.md),

                  // Scorecard Grid Card
                  BbmCard(
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
                                const Icon(Icons.grid_on_outlined, color: AppColors.primary, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'ROUND $selectedRound SCORECARD',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Scores loading state check
                          golferScoresAsync.when(
                            data: (scores) {
                              final teamScores = teamScoresAsync.value ?? [];
                              final teeTimes = teeTimesAsync.value ?? [];

                              return BbmTable(
                                minWidth: 1000.0,
                                columnWidths: [
                                  3.0, // Golfer Name & Status
                                  ...List.generate(18, (_) => 1.0), // 18 Holes
                                  1.5, // Total
                                ],
                                headers: _buildTableHeaders(theme),
                                rows: [
                                  // Golfer rows
                                  ...teamGolfers.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final golfer = entry.value;
                                    final golferScores = scores
                                        .where((s) => s.tournamentGolferId == golfer.id)
                                        .toList();
                                    return _buildGolferRow(
                                      golfer: golfer,
                                      scores: golferScores,
                                      teeTimes: teeTimes,
                                      teamScores: teamScores,
                                      allScores: scores,
                                      theme: theme,
                                      backgroundColor: index % 2 == 1
                                          ? AppColors.alternateRow
                                          : Colors.transparent,
                                    );
                                  }),

                                  // Team Best Ball row divider
                                  const Divider(color: AppColors.border, height: 1),

                                  // Team row
                                  _buildTeamRow(
                                    teamScores: teamScores,
                                    allScores: scores,
                                    theme: theme,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                                  ),
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
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'Error loading scorecard: $err',
                                  style: const TextStyle(color: AppColors.scoreBogeyBg),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Score Legend Card
                  _buildLegendCard(theme),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Text('Error loading team: $err'),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner({
    required String text,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        border: Border.all(color: bgColor, width: 1.5),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: bgColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSelector(WidgetRef ref, int selectedRound) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final roundNum = index + 1;
        final isSelected = selectedRound == roundNum;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : AppSpacing.xs,
              right: index == 3 ? 0 : AppSpacing.xs,
            ),
            child: InkWell(
              onTap: () {
                ref.read(selectedRoundProvider.notifier).setRound(roundNum);
              },
              borderRadius: AppSpacing.borderRadiusMd,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.cardBg,
                  borderRadius: AppSpacing.borderRadiusMd,
                  border: Border.all(
                    color: isSelected ? AppColors.primaryHover : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  'R$roundNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildTableHeaders(ThemeData theme) {
    return [
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Text(
          'GOLFER',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      ...List.generate(18, (i) => Center(
        child: Text(
          '${i + 1}',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      )),
      Center(
        child: Text(
          'TOT',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ];
  }

  Widget _buildGolferStatusSubtitle(
    TournamentGolfer golfer,
    List<TeeTime> teeTimes,
    List<HoleScore> golferHoleScores,
    ThemeData theme,
  ) {
    if (golfer.status == 'WD') {
      return Text(
        'WITHDRAWN',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.scoreBogeyBg,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );
    }
    if (golfer.status == 'MC') {
      return Text(
        'MISSED CUT',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );
    }

    final matches = teeTimes.where((t) => t.tournamentGolferId == golfer.id);
    final teeTime = matches.isNotEmpty ? matches.first : null;

    if (teeTime != null) {
      if (teeTime.status == 'WD') {
        return Text(
          'WD',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.scoreBogeyBg,
            fontWeight: FontWeight.bold,
          ),
        );
      }
      if (teeTime.status == 'MC') {
        return Text(
          'MC',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        );
      }

      // Check if player has started scoring
      if (golferHoleScores.isNotEmpty) {
        final finished = golferHoleScores.length == 18;
        return Text(
          finished ? 'FINISHED' : 'PLAYING (Hole ${golferHoleScores.length})',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        );
      }

      return Text(
        'TEE: ${formatTeeTime(teeTime.teeTimeUtc)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    if (golferHoleScores.isNotEmpty) {
      final finished = golferHoleScores.length == 18;
      return Text(
        finished ? 'FINISHED' : 'PLAYING (Hole ${golferHoleScores.length})',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(
      'ACTIVE',
      style: theme.textTheme.labelSmall?.copyWith(
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildGolferRow({
    required TournamentGolfer golfer,
    required List<HoleScore> scores,
    required List<TeeTime> teeTimes,
    required List<TeamHoleScore> teamScores,
    required List<HoleScore> allScores,
    required ThemeData theme,
    required Color backgroundColor,
  }) {
    int roundTotal = 0;
    bool hasScores = false;
    for (var s in scores) {
      roundTotal += s.score;
      hasScores = true;
    }

    return BbmTableRow(
      columnWidths: [
        3.0,
        ...List.generate(18, (_) => 1.0),
        1.5,
      ],
      backgroundColor: backgroundColor,
      cells: [
        // Name & Status
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                golfer.profile.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              _buildGolferStatusSubtitle(golfer, teeTimes, scores, theme),
            ],
          ),
        ),

        // 18 hole cells
        ...List.generate(18, (index) {
          final holeNum = index + 1;
          final scoreMatches = scores.where((s) => s.hole == holeNum);
          final holeScore = scoreMatches.isNotEmpty ? scoreMatches.first : null;

          final par = _getParForHole(holeNum, allScores, teamScores);

          return ScorecardCell(
            golferId: golfer.id,
            hole: holeNum,
            score: holeScore?.score,
            scoreType: holeScore?.scoreType,
            par: par,
          );
        }),

        // Total
        Center(
          child: Text(
            hasScores ? '$roundTotal' : '-',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamRow({
    required List<TeamHoleScore> teamScores,
    required List<HoleScore> allScores,
    required ThemeData theme,
    required Color backgroundColor,
  }) {
    int teamRoundTotal = 0;
    bool teamHasScores = false;

    for (var ts in teamScores) {
      teamRoundTotal += ts.bestBallScore;
      teamHasScores = true;
    }

    return BbmTableRow(
      columnWidths: [
        3.0,
        ...List.generate(18, (_) => 1.0),
        1.5,
      ],
      backgroundColor: backgroundColor,
      cells: [
        // Team Row Title
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'TEAM BEST BALL',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'COMBINED SCORE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        // 18 hole cells
        ...List.generate(18, (index) {
          final holeNum = index + 1;
          final teamScoreMatches = teamScores.where((s) => s.hole == holeNum);
          final teamHoleScore = teamScoreMatches.isNotEmpty ? teamScoreMatches.first : null;

          final par = _getParForHole(holeNum, allScores, teamScores);

          final colors = getScoreColors(
            teamHoleScore?.bestBallScore,
            par,
          );

          return Container(
            margin: const EdgeInsets.all(2.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              teamHoleScore != null ? '${teamHoleScore.bestBallScore}' : '-',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),

        // Total
        Center(
          child: Text(
            teamHasScores ? '$teamRoundTotal' : '-',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  int _getParForHole(int hole, List<HoleScore> allScores, List<TeamHoleScore> teamScores) {
    final scoreMatches = allScores.where((s) => s.hole == hole);
    if (scoreMatches.isNotEmpty) return scoreMatches.first.par;

    final teamMatches = teamScores.where((s) => s.hole == hole);
    if (teamMatches.isNotEmpty) return teamMatches.first.par;

    return 4; // Standard fallback
  }

  Widget _buildLegendCard(ThemeData theme) {
    return BbmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCORE KEY',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _buildLegendItem('Eagle or Better', AppColors.scoreEagleOrBetterBg, AppColors.scoreEagleOrBetterText, theme),
              _buildLegendItem('Birdie', AppColors.scoreBirdieBg, AppColors.scoreBirdieText, theme),
              _buildLegendItem('Par', AppColors.scoreParBg, AppColors.scoreParText, theme),
              _buildLegendItem('Bogey', AppColors.scoreBogeyBg, AppColors.scoreBogeyText, theme),
              _buildLegendItem('Double+', AppColors.scoreDoubleWorseBg, AppColors.scoreDoubleWorseText, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color bg, Color text, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            '-1', // placeholder to show text color
            style: theme.textTheme.labelSmall?.copyWith(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
