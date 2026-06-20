import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/draft_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/scorecard_providers.dart';
import '../providers/leaderboard_providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../utils/score_utils.dart';
import 'card.dart';

/// Interactive scorecard cell displaying a golfer's score, with a realtime green pulse animation.
class ScorecardCell extends ConsumerStatefulWidget {
  final String golferId;
  final int hole;
  final int? score;
  final String? scoreType;
  final int par;
  final bool isLowScore;
  final bool isInactive;

  const ScorecardCell({
    super.key,
    required this.golferId,
    required this.hole,
    required this.score,
    required this.scoreType,
    required this.par,
    this.isLowScore = false,
    this.isInactive = false,
  });

  @override
  ConsumerState<ScorecardCell> createState() => _ScorecardCellState();
}

class _ScorecardCellState extends ConsumerState<ScorecardCell>
    with SingleTickerProviderStateMixin {
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
    if (!widget.isInactive) {
      ref.listen<ScoreUpdateEvent?>(lastRealtimeScoreUpdateProvider, (
        previous,
        next,
      ) {
        if (next != null &&
            next.tournamentGolferId == widget.golferId &&
            next.hole == widget.hole) {
          if (next.scoreType == 'BIRDIE' || next.scoreType == 'EAGLE') {
            _pulseController.forward(from: 0.0);
          }
        }
      });
    }

    final colors = widget.isInactive
        ? const ColorPair(AppColors.alternateRow, AppColors.textMuted)
        : getScoreColors(widget.score, widget.par, widget.scoreType);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseVal = widget.isInactive ? 0.0 : _pulseAnimation.value;
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
              color: !widget.isInactive && pulseVal > 0
                  ? AppColors.primaryHover.withValues(alpha: pulseVal)
                  : (!widget.isInactive && widget.isLowScore
                        ? Colors.amber.shade700
                        : Colors.transparent),
              width: !widget.isInactive && widget.isLowScore ? 2.0 : 1,
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

/// The reusable Team Scorecard widget.
class TeamScorecard extends ConsumerStatefulWidget {
  final String? teamId;
  final bool showHeader;
  final bool showBanners;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const TeamScorecard({
    super.key,
    this.teamId,
    this.showHeader = true,
    this.showBanners = true,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  ConsumerState<TeamScorecard> createState() => _TeamScorecardState();
}

class _TeamScorecardState extends ConsumerState<TeamScorecard> {
  late final ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  bool _isLowScore(
    String golferId,
    int hole,
    List<HoleScore> allScores,
    List<TeamHoleScore> teamScores,
  ) {
    // 1. Get golfer's score for this hole
    final golferScoreMatches = allScores.where(
      (s) => s.tournamentGolferId == golferId && s.hole == hole,
    );
    if (golferScoreMatches.isEmpty) return false;
    final golferScore = golferScoreMatches.first.score;

    // 2. Find the team best ball score for this hole
    final teamScoreMatches = teamScores.where((s) => s.hole == hole);
    if (teamScoreMatches.isEmpty) return false;
    final teamBestBall = teamScoreMatches.first.bestBallScore;

    return golferScore == teamBestBall;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tournamentAsync = ref.watch(activeTournamentProvider);
    final golferListAsync = ref.watch(golferListProvider);
    final sessionAsync = ref.watch(authSessionProvider);
    final currentUserId = sessionAsync.value?.user.id;

    final isCompetitor = widget.teamId != null;
    final AsyncValue<UserTeam?> teamAsync = isCompetitor
        ? ref.watch(competitorTeamDetailsProvider(widget.teamId!))
        : ref.watch(userTeamProvider);

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                isCompetitor
                    ? 'Competitor team not found.'
                    : 'No active team found. Please save a roster first.',
              ),
            ),
          );
        }

        final selectedRound = ref.watch(selectedRoundProvider);

        // Activate the Supabase Realtime subscription for this round
        if (isCompetitor) {
          ref.watch(
            competitorScorecardSubscriptionProvider((
              teamId: widget.teamId!,
              round: selectedRound,
            )),
          );
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
          final allScoresAsync = ref.watch(
            competitorTeamProvider(widget.teamId!),
          );
          teamScoresAsync = allScoresAsync.whenData(
            (allScores) =>
                allScores.where((s) => s.round == selectedRound).toList(),
          );
          golferScoresAsync = ref.watch(
            competitorGolfersHoleScoresProvider((
              teamId: widget.teamId!,
              round: selectedRound,
            )),
          );
          teeTimesAsync = ref.watch(
            competitorGolfersTeeTimesProvider((
              teamId: widget.teamId!,
              round: selectedRound,
            )),
          );
        } else {
          teamScoresAsync = ref.watch(userTeamScoreProvider(selectedRound));
          golferScoresAsync = ref.watch(
            teamGolfersHoleScoresProvider(selectedRound),
          );
          teeTimesAsync = ref.watch(teamGolfersTeeTimesProvider(selectedRound));
        }

        final golfers = golferListAsync.value ?? [];
        final teamGolfers = golfers
            .where((g) => team.golferIds.contains(g.id))
            .toList();

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banners
            if (widget.showBanners) ...[
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
                  text:
                      'TEAM DISQUALIFIED: Your team has been disqualified for failing to draft a legal roster (incomplete roster or over budget) before the tournament lock time.',
                  bgColor: AppColors.statusDqBg,
                  textColor: AppColors.statusDqText,
                  icon: Icons.gavel_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],

            // Team Info Card
            if (widget.showHeader) ...[
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
            ],

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.grid_on_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
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

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Locked Columns (Golfer Name & Total)
                            SizedBox(
                              width: 180.0, // 120.0 Name + 60.0 Total
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildLeftHeader(theme),
                                    ...List.generate(
                                      (!isCompetitor ||
                                              team.userId == currentUserId)
                                          ? teamGolfers.length
                                          : 4,
                                      (index) {
                                        if (index < teamGolfers.length) {
                                          final golfer = teamGolfers[index];
                                          final golferScores = scores
                                              .where(
                                                (s) =>
                                                    s.tournamentGolferId ==
                                                    golfer.id,
                                              )
                                              .toList();
                                          final golferTeeTimes = teeTimes
                                              .where((t) => t.tournamentGolferId == golfer.id)
                                              .toList();
                                          final golferTeeTime = golferTeeTimes.isNotEmpty
                                              ? golferTeeTimes.first
                                              : null;
                                           final isInactive = golfer.status == 'WD' ||
                                               (golfer.status == 'MC' && selectedRound >= 3) ||
                                               (golferTeeTime != null &&
                                                   (golferTeeTime.status == 'MC' ||
                                                       golferTeeTime.status == 'WD'));

                                          return _buildLeftGolferRow(
                                            golfer: golfer,
                                            scores: golferScores,
                                            teeTimes: teeTimes,
                                            theme: theme,
                                            backgroundColor: index % 2 == 1
                                                ? AppColors.alternateRow
                                                : Colors.transparent,
                                            isInactive: isInactive,
                                          );
                                        } else {
                                          return _buildLeftConcealedRow(
                                            theme: theme,
                                            backgroundColor: index % 2 == 1
                                                ? AppColors.alternateRow
                                                : Colors.transparent,
                                          );
                                        }
                                      },
                                    ),
                                    Container(
                                      height: 2.0,
                                      color: AppColors.textMuted,
                                    ),
                                    _buildLeftTeamRow(
                                      teamScores: teamScores,
                                      theme: theme,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.05),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Vertical Separator boundary line & shadow
                            IntrinsicHeight(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 1.5,
                                    color: AppColors.border,
                                  ),
                                  Positioned(
                                    left: 1.5,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 4.0,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            Colors.transparent,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 2. Horizontally Scrollable Columns (Holes 1 to 18)
                            Expanded(
                              child: Scrollbar(
                                controller: _horizontalScrollController,
                                thumbVisibility: true,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: SizedBox(
                                      width:
                                          18 *
                                          40.0, // 18 holes * 40.0 width = 720.0
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildRightHeader(theme),
                                          ...List.generate(
                                            (!isCompetitor ||
                                                    team.userId ==
                                                        currentUserId)
                                                ? teamGolfers.length
                                                : 4,
                                            (index) {
                                              if (index < teamGolfers.length) {
                                                final golfer =
                                                    teamGolfers[index];
                                                final golferScores = scores
                                                    .where(
                                                      (s) =>
                                                          s.tournamentGolferId ==
                                                          golfer.id,
                                                    )
                                                    .toList();
                                                final golferTeeTimes = teeTimes
                                                    .where((t) => t.tournamentGolferId == golfer.id)
                                                    .toList();
                                                final golferTeeTime = golferTeeTimes.isNotEmpty
                                                    ? golferTeeTimes.first
                                                    : null;
                                                final isInactive = golfer.status == 'WD' ||
                                                    (golfer.status == 'MC' && selectedRound >= 3) ||
                                                    (golferTeeTime != null &&
                                                        (golferTeeTime.status == 'MC' ||
                                                            golferTeeTime.status == 'WD'));

                                                return _buildRightGolferRow(
                                                  golfer: golfer,
                                                  scores: golferScores,
                                                  teamScores: teamScores,
                                                  allScores: scores,
                                                  theme: theme,
                                                  backgroundColor:
                                                      index % 2 == 1
                                                      ? AppColors.alternateRow
                                                      : Colors.transparent,
                                                  isInactive: isInactive,
                                                );
                                              } else {
                                                return _buildRightConcealedRow(
                                                  theme: theme,
                                                  backgroundColor:
                                                      index % 2 == 1
                                                      ? AppColors.alternateRow
                                                      : Colors.transparent,
                                                );
                                              }
                                            },
                                          ),
                                          Container(
                                            height: 2.0,
                                            color: AppColors.textMuted,
                                          ),
                                          _buildRightTeamRow(
                                            teamScores: teamScores,
                                            allScores: scores,
                                            theme: theme,
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.05),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'Error loading scorecard: $err',
                            style: const TextStyle(
                              color: AppColors.scoreBogeyBg,
                            ),
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
        );

        if (widget.shrinkWrap) {
          return content;
        }

        return SingleChildScrollView(
          physics: widget.physics,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: content,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, stack) => Center(child: Text('Error loading team: $err')),
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
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
                    color: isSelected
                        ? AppColors.primaryHover
                        : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  'R$roundNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLeftHeader(ThemeData theme) {
    return Container(
      height: 44.0,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120.0,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Text(
                'GOLFER',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60.0,
            child: Center(
              child: Text(
                'TOT',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightHeader(ThemeData theme) {
    return Container(
      height: 44.0,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: List.generate(
          18,
          (i) => SizedBox(
            width: 40.0,
            child: Center(
              child: Text(
                '${i + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
          color: AppColors.textMuted,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );
    }
    if (golfer.status == 'MC') {
      return Text(
        'MISSED CUT',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
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
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        );
      }
      if (teeTime.status == 'MC') {
        return Text(
          'MC',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textMuted,
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
      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary),
    );
  }

  Widget _buildLeftGolferRow({
    required TournamentGolfer golfer,
    required List<HoleScore> scores,
    required List<TeeTime> teeTimes,
    required ThemeData theme,
    required Color backgroundColor,
    bool isInactive = false,
  }) {
    int roundTotal = 0;
    bool hasScores = false;
    for (var s in scores) {
      roundTotal += s.score;
      hasScores = true;
    }

    return Container(
      height: 68.0,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120.0,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      String displayName = golfer.profile.name;
                      final parts = displayName.split(' ');
                      if (parts.length > 1) {
                        displayName =
                            "${parts.sublist(0, parts.length - 1).join(' ')}\n${parts.last}";
                      }
                      return Text(
                        displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          color: isInactive ? AppColors.textMuted : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  _buildGolferStatusSubtitle(golfer, teeTimes, scores, theme),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 60.0,
            child: Center(
              child: Text(
                hasScores ? '$roundTotal' : '-',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isInactive ? AppColors.textMuted : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightGolferRow({
    required TournamentGolfer golfer,
    required List<HoleScore> scores,
    required List<TeamHoleScore> teamScores,
    required List<HoleScore> allScores,
    required ThemeData theme,
    required Color backgroundColor,
    bool isInactive = false,
  }) {
    return Container(
      height: 68.0,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(18, (index) {
          final holeNum = index + 1;
          final scoreMatches = scores.where((s) => s.hole == holeNum);
          final holeScore = scoreMatches.isNotEmpty ? scoreMatches.first : null;

          final par = _getParForHole(holeNum, allScores, teamScores);
          final isLow = _isLowScore(golfer.id, holeNum, allScores, teamScores);

          return SizedBox(
            width: 40.0,
            child: ScorecardCell(
              golferId: golfer.id,
              hole: holeNum,
              score: holeScore?.score,
              scoreType: holeScore?.scoreType,
              par: par,
              isLowScore: isLow,
              isInactive: isInactive,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeftConcealedRow({
    required ThemeData theme,
    required Color backgroundColor,
  }) {
    return Container(
      height: 68.0,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120.0,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '🔒 Slot Hidden',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Concealed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 60.0,
            child: Center(
              child: Text('-', style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightConcealedRow({
    required ThemeData theme,
    required Color backgroundColor,
  }) {
    return Container(
      height: 68.0,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(18, (index) {
          return SizedBox(
            width: 40.0,
            child: Container(
              margin: const EdgeInsets.all(2.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.alternateRow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                '-',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeftTeamRow({
    required List<TeamHoleScore> teamScores,
    required ThemeData theme,
    required Color backgroundColor,
  }) {
    int teamRoundTotal = 0;
    bool teamHasScores = false;

    for (var ts in teamScores) {
      teamRoundTotal += ts.bestBallScore;
      teamHasScores = true;
    }

    return Container(
      height: 68.0,
      color: backgroundColor,
      child: Row(
        children: [
          SizedBox(
            width: 120.0,
            child: Padding(
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
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'COMBINED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 60.0,
            child: Center(
              child: Text(
                teamHasScores ? '$teamRoundTotal' : '-',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightTeamRow({
    required List<TeamHoleScore> teamScores,
    required List<HoleScore> allScores,
    required ThemeData theme,
    required Color backgroundColor,
  }) {
    return Container(
      height: 68.0,
      color: backgroundColor,
      child: Row(
        children: List.generate(18, (index) {
          final holeNum = index + 1;
          final teamScoreMatches = teamScores.where((s) => s.hole == holeNum);
          final teamHoleScore = teamScoreMatches.isNotEmpty
              ? teamScoreMatches.first
              : null;

          final par = _getParForHole(holeNum, allScores, teamScores);
          final colors = getScoreColors(teamHoleScore?.bestBallScore, par);

          return SizedBox(
            width: 40.0,
            child: Container(
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
            ),
          );
        }),
      ),
    );
  }

  int _getParForHole(
    int hole,
    List<HoleScore> allScores,
    List<TeamHoleScore> teamScores,
  ) {
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
              _buildLegendItem(
                '-2',
                'Eagle or Better',
                AppColors.scoreEagleOrBetterBg,
                AppColors.scoreEagleOrBetterText,
                theme,
              ),
              _buildLegendItem(
                '-1',
                'Birdie',
                AppColors.scoreBirdieBg,
                AppColors.scoreBirdieText,
                theme,
              ),
              _buildLegendItem(
                'E',
                'Par',
                AppColors.scoreParBg,
                AppColors.scoreParText,
                theme,
              ),
              _buildLegendItem(
                '+1',
                'Bogey',
                AppColors.scoreBogeyBg,
                AppColors.scoreBogeyText,
                theme,
              ),
              _buildLegendItem(
                '+2',
                'Double+',
                AppColors.scoreDoubleWorseBg,
                AppColors.scoreDoubleWorseText,
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String value,
    String label,
    Color bg,
    Color text,
    ThemeData theme,
  ) {
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
            value,
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
