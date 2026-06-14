import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/draft_providers.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/draft_panel.dart';
import '../../widgets/golfer_table.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/tournament_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onViewDesignSystem;

  const DashboardScreen({super.key, required this.onViewDesignSystem});

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

    // Check lock status
    final isLocked =
        activeTournament?.lockTimeUtc != null &&
        DateTime.now().toUtc().isAfter(activeTournament!.lockTimeUtc!);

    // Check if any golfer on user's SAVED roster is WD pre-lock
    final userTeam = userTeamAsync.value;
    final showWdBanner =
        !isLocked &&
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

              // WD Warning Banner (Pre-lock only)
              if (showWdBanner) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber, width: 1),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'WARNING: A golfer on your team has withdrawn (WD). Please update your roster before lock time!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Roster Draft Flow (only if there is an active tournament)
              if (activeTournament != null) ...[
                // Draft Panel
                DraftPanel(isLocked: isLocked),
                const SizedBox(height: AppSpacing.md),

                // Golfer Table
                Text(
                  'AVAILABLE GOLFERS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                golferListAsync.when(
                  data: (list) =>
                      GolferTable(golfers: list, isLocked: isLocked),
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
                const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.md),

              // Developer Actions / Design System
              BbmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BbmButton.outlined(
                      text: 'View Design System Gallery',
                      icon: Icons.palette_outlined,
                      onPressed: widget.onViewDesignSystem,
                    ),
                  ],
                ),
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
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
