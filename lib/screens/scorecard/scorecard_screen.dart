import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/draft_providers.dart';
import '../../providers/leaderboard_providers.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/team_scorecard.dart';

/// The Scorecard Screen displaying live score tracker for the drafted team.
class ScorecardScreen extends ConsumerWidget {
  final String? teamId;
  const ScorecardScreen({super.key, this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompetitor = teamId != null;
    final AsyncValue<UserTeam?> teamAsync = isCompetitor
        ? ref.watch(competitorTeamDetailsProvider(teamId!))
        : ref.watch(userTeamProvider);

    return ResponsiveLayout(
      appBar: AppBar(
        title: Text(
          isCompetitor
              ? (teamAsync.value?.teamName != null
                    ? '${teamAsync.value!.teamName!.toUpperCase()} SCORECARD'
                    : 'COMPETITOR SCORECARD')
              : 'LIVE SCORECARD',
        ),
      ),
      child: SafeArea(
        child: TeamScorecard(
          teamId: teamId,
          showBanners: true,
          showHeader: true,
        ),
      ),
    );
  }
}
