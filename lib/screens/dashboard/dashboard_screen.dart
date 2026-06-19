import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/draft_providers.dart';
import '../../providers/leaderboard_providers.dart';
import '../../providers/scorecard_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/card.dart';
import '../../widgets/draft_panel.dart';
import '../../widgets/golfer_table.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/tournament_header.dart';
import '../../widgets/team_scorecard.dart';
import '../../widgets/leaderboard_preview.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'available_golfers_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoggingOut = false;
  bool _hasInitializedRoster = false;

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider);
    final tournamentAsync = ref.watch(activeTournamentProvider);
    final golferListAsync = ref.watch(golferListProvider);
    final userTeamAsync = ref.watch(userTeamProvider);
    final selectedRound = ref.watch(selectedRoundProvider);
    final golferScoresAsync = ref.watch(
      teamGolfersHoleScoresProvider(selectedRound),
    );
    final teeTimesAsync = ref.watch(teamGolfersTeeTimesProvider(selectedRound));

    // Sync saved team to local draft selection state on first load
    if (!_hasInitializedRoster) {
      if (golferListAsync.hasValue && userTeamAsync.hasValue) {
        final golfers = golferListAsync.value ?? [];
        final userTeam = userTeamAsync.value;
        if (userTeam != null) {
          final savedGolfers = golfers
              .where((g) => userTeam.golferIds.contains(g.id))
              .toList();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(draftStateNotifierProvider.notifier)
                .setSelection(savedGolfers);
          });
        }
        _hasInitializedRoster = true;
      }
    }

    final activeTournament = tournamentAsync.value;
    final golfers = golferListAsync.value ?? [];
    final userTeam = userTeamAsync.value;
    final isRosterSaved = userTeam != null && userTeam.golferIds.isNotEmpty;

    // Roster editing is locked when tournament is completed or lock time has passed
    final isTeamLocked =
        activeTournament == null ||
        activeTournament.status == 'COMPLETED' ||
        (activeTournament.lockTimeUtc != null &&
            DateTime.now().toUtc().isAfter(activeTournament.lockTimeUtc!));

    // Watch standings for team score
    final standingsAsync = ref.watch(leaderboardProvider);
    int? userTeamScore;
    if (userTeam != null && standingsAsync.hasValue) {
      final matches = standingsAsync.value!.where(
        (s) => s.teamId == userTeam.id,
      );
      if (matches.isNotEmpty) {
        userTeamScore = matches.first.totalToPar;
      }
    }

    // Check if any golfer on user's SAVED roster is WD pre-lock
    final showWdBanner =
        !isTeamLocked &&
        userTeam != null &&
        golfers.any(
          (g) => userTeam.golferIds.contains(g.id) && g.status == 'WD',
        );

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('BBM DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoggingOut ? null : _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              profileAsync.when(
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WELCOME BACK,',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        profile.teamName.toUpperCase(),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, stack) => Text('Error loading profile: $err'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Active Tournament Header
              const TournamentHeader(),
              const SizedBox(height: AppSpacing.md),

              // Weather Delay Banner
              if (activeTournament?.status == 'SUSPENDED') ...[
                _buildBanner(
                  text: 'WEATHER DELAY: Play is currently suspended.',
                  bgColor: AppColors.statusSuspendedBg,
                  textColor: AppColors.statusSuspendedText,
                  icon: Icons.thunderstorm_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Lock Info Banner (informational post-lock/during draft)
              if (activeTournament != null &&
                  !isTeamLocked &&
                  activeTournament.status != 'COMPLETED') ...[
                _buildBanner(
                  text:
                      'Drafting is open! Golfers lock individually 15 minutes prior to their tee times.',
                  bgColor: AppColors.primary,
                  textColor: AppColors.primary,
                  icon: Icons.lock_clock_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // WD Warning Banner (Pre-lock only)
              if (showWdBanner) ...[
                _buildBanner(
                  text:
                      'WARNING: A golfer on your team has withdrawn (WD). Please update your roster before lock time!',
                  bgColor: Colors.amber,
                  textColor: Colors.amber,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Roster Draft Flow (only if there is an active tournament)
              if (activeTournament != null) ...[
                golferListAsync.when(
                  data: (golfersList) {
                    final teamGolfers = golfersList
                        .where(
                          (g) => userTeam?.golferIds.contains(g.id) ?? false,
                        )
                        .toList();
                    final golferScores = golferScoresAsync.value ?? [];
                    final teeTimes = teeTimesAsync.value ?? [];
                    final activeGolfersCount = teamGolfers.where((g) {
                      final hasScores = golferScores.any(
                        (s) => s.tournamentGolferId == g.id,
                      );
                      if (hasScores) return true;

                      final golferTeeTimeMatches = teeTimes.where(
                        (t) => t.tournamentGolferId == g.id,
                      );
                      if (golferTeeTimeMatches.isNotEmpty) {
                        final teeTime = golferTeeTimeMatches.first;
                        if (teeTime.status == 'WD' || teeTime.status == 'MC') {
                          return false;
                        }
                        return DateTime.now().toUtc().isAfter(
                          teeTime.teeTimeUtc,
                        );
                      }
                      return false;
                    }).length;

                    if (isTeamLocked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatsArea(
                            theme,
                            activeGolfersCount,
                            userTeamScore,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const TeamScorecard(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            showHeader: false,
                            showBanners: false,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const LeaderboardPreview(showButton: false),
                          const SizedBox(height: AppSpacing.md),
                          _buildLeaderboardCard(context, theme),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DraftPanel(isLocked: isTeamLocked),
                          const SizedBox(height: AppSpacing.md),
                          if (!isRosterSaved) ...[
                            _buildAvailableGolfersPreview(
                              theme,
                              golfersList,
                              isTeamLocked,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ] else ...[
                            const LeaderboardPreview(),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ],
                      );
                    }
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (err, stack) => Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: AppColors.scoreBogeyBg.withValues(alpha: 0.1),
                    child: Text('Error loading golfers: $err'),
                  ),
                ),
              ],

              // Team Info Details
              profileAsync.when(
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  return BbmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.shield,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Team Details',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildDetailRow('Team Name', profile.teamName, theme),
                        const Divider(
                          color: AppColors.border,
                          height: AppSpacing.lg,
                        ),
                        _buildDetailRow('Email Address', profile.email, theme),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

  String _formatScoreToPar(int? score) {
    if (score == null) return '-';
    if (score == 0) return 'E';
    if (score > 0) return '+$score';
    return '$score';
  }

  Widget _buildStatsArea(ThemeData theme, int activeGolfers, int? teamScore) {
    return Row(
      children: [
        Expanded(
          child: BbmCard(
            child: Column(
              children: [
                const Icon(
                  Icons.sports_golf_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$activeGolfers / 4',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'ACTIVE GOLFERS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: BbmCard(
            child: Column(
              children: [
                Icon(
                  teamScore == null
                      ? Icons.trending_flat
                      : (teamScore < 0
                            ? Icons.trending_down
                            : (teamScore > 0
                                  ? Icons.trending_up
                                  : Icons.trending_flat)),
                  color: teamScore == null
                      ? AppColors.textSecondary
                      : (teamScore < 0
                            ? AppColors.accent
                            : (teamScore > 0
                                  ? AppColors.scoreBogeyBg
                                  : AppColors.textSecondary)),
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatScoreToPar(teamScore),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: teamScore == null
                        ? AppColors.textPrimary
                        : (teamScore < 0
                              ? AppColors.accent
                              : (teamScore > 0
                                    ? AppColors.scoreBogeyBg
                                    : AppColors.textPrimary)),
                  ),
                ),
                Text(
                  'TEAM SCORE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, ThemeData theme) {
    return BbmCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
        );
      },
      child: Row(
        children: [
          const Icon(
            Icons.leaderboard_outlined,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIEW LEADERBOARD',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'See overall standings and compare with other teams.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableGolfersPreview(
    ThemeData theme,
    List<TournamentGolfer> golfers,
    bool isLocked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AVAILABLE GOLFERS PREVIEW',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GolferTable(golfers: golfers, isLocked: isLocked, limit: 5),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AvailableGolfersScreen(
                      golfers: golfers,
                      isLocked: isLocked,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
              ),
              child: const Text(
                'SEE ALL AVAILABLE GOLFERS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
