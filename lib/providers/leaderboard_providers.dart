import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';
import 'draft_providers.dart';
import 'scorecard_providers.dart';
import '../models/leaderboard_models.dart';
export '../models/leaderboard_models.dart';

/// Reads and subscribes to the leaderboard_standings table in real time.
/// Orders teams: ACTIVE sorted ascending by rank -> CUT -> DQ.
final leaderboardProvider = FutureProvider.autoDispose<List<LeaderboardStanding>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final activeTournament = await ref.watch(activeTournamentProvider.future);
  if (activeTournament == null) return [];

  final response = await client
      .from('leaderboard_standings')
      .select('*, teams(*, users(*))')
      .eq('tournament_id', activeTournament.id);

  final standings = (response as List)
      .map((json) => LeaderboardStanding.fromJson(json as Map<String, dynamic>))
      .toList();

  // Separate by status
  final activeTeams = standings.where((t) => t.status == 'ACTIVE').toList();
  final cutTeams = standings.where((t) => t.status == 'CUT').toList();
  final dqTeams = standings.where((t) => t.status == 'DQ').toList();

  // Sort active teams by rank ascending
  activeTeams.sort((a, b) {
    if (a.rank == null && b.rank == null) return 0;
    if (a.rank == null) return 1;
    if (b.rank == null) return -1;
    return a.rank!.compareTo(b.rank!);
  });

  // Sort cut teams by total_to_par ascending
  cutTeams.sort((a, b) => a.totalToPar.compareTo(b.totalToPar));

  // Sort dq teams by total_to_par ascending
  dqTeams.sort((a, b) => a.totalToPar.compareTo(b.totalToPar));

  // Setup Realtime subscription to leaderboard_standings table
  final channelName = 'leaderboard-realtime-${activeTournament.id}';
  final channel = client.channel(channelName);

  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'leaderboard_standings',
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
  });

  return [...activeTeams, ...cutTeams, ...dqTeams];
});

/// Fetches competitor team details (id, status, golferIds, teamName) for a given team ID.
final competitorTeamDetailsProvider = FutureProvider.autoDispose.family<UserTeam?, String>((ref, teamId) async {
  final client = ref.watch(supabaseClientProvider);
  final teamResponse = await client
      .from('teams')
      .select('*, users(team_name)')
      .eq('id', teamId)
      .maybeSingle();

  if (teamResponse == null) return null;

  final golfersResponse = await client
      .from('team_golfers')
      .select('tournament_golfer_id')
      .eq('team_id', teamId);

  final golferIds = (golfersResponse as List)
      .map((row) => row['tournament_golfer_id'] as String)
      .toList();

  return UserTeam.fromJson(teamResponse, golferIds);
});

/// Notifier managing a competitor's scorecard by reading the team_hole_scores view.
class CompetitorTeamNotifier extends AsyncNotifier<List<TeamHoleScore>> {
  final String teamId;

  CompetitorTeamNotifier(this.teamId);

  @override
  FutureOr<List<TeamHoleScore>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final response = await client
        .from('team_hole_scores')
        .select()
        .eq('team_id', teamId);

    return (response as List)
        .map((json) => TeamHoleScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void updateBestBall(int round, int hole, int par, List<HoleScore> golferScores) {
    if (!state.hasValue) return;
    final scoresForHole = golferScores.where((s) => s.hole == hole).map((s) => s.score).toList();
    if (scoresForHole.isEmpty) return;
    final newBestScore = scoresForHole.reduce((a, b) => a < b ? a : b);

    final currentData = state.value!;
    final index = currentData.indexWhere((s) => s.round == round && s.hole == hole);

    final updatedScore = TeamHoleScore(
      teamId: teamId,
      round: round,
      hole: hole,
      par: par,
      bestBallScore: newBestScore,
      holeToPar: newBestScore - par,
    );

    final List<TeamHoleScore> list;
    if (index != -1) {
      list = List<TeamHoleScore>.from(currentData);
      list[index] = updatedScore;
    } else {
      list = [...currentData, updatedScore];
    }
    state = AsyncValue.data(list);
  }
}

/// Provider for competitor scorecard scores.
final competitorTeamProvider = AsyncNotifierProvider.autoDispose.family<CompetitorTeamNotifier, List<TeamHoleScore>, String>((arg) {
  return CompetitorTeamNotifier(arg);
});

/// Notifier managing individual hole scores for the competitor team's golfers in a specific round.
class CompetitorGolfersHoleScoresNotifier extends AsyncNotifier<List<HoleScore>> {
  final String teamId;
  final int round;

  CompetitorGolfersHoleScoresNotifier(this.teamId, this.round);

  @override
  FutureOr<List<HoleScore>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final teamAsync = await ref.watch(competitorTeamDetailsProvider(teamId).future);
    if (teamAsync == null || teamAsync.golferIds.isEmpty) {
      return [];
    }

    final response = await client
        .from('hole_scores')
        .select()
        .inFilter('tournament_golfer_id', teamAsync.golferIds)
        .eq('round', round);

    return (response as List)
        .map((json) => HoleScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void updateScore(HoleScore newScore) {
    if (!state.hasValue) return;
    final currentData = state.value!;
    final index = currentData.indexWhere((s) =>
        s.tournamentGolferId == newScore.tournamentGolferId &&
        s.round == newScore.round &&
        s.hole == newScore.hole);

    final List<HoleScore> list;
    if (index != -1) {
      list = List<HoleScore>.from(currentData);
      list[index] = newScore;
    } else {
      list = [...currentData, newScore];
    }
    state = AsyncValue.data(list);
  }
}

/// Provider for competitor individual golfer hole scores.
final competitorGolfersHoleScoresProvider = AsyncNotifierProvider.autoDispose.family<CompetitorGolfersHoleScoresNotifier, List<HoleScore>, ({String teamId, int round})>((arg) {
  return CompetitorGolfersHoleScoresNotifier(arg.teamId, arg.round);
});

/// Fetches tee times for the competitor team's golfers in a specific round.
final competitorGolfersTeeTimesProvider = FutureProvider.autoDispose.family<List<TeeTime>, ({String teamId, int round})>((ref, arg) async {
  final client = ref.watch(supabaseClientProvider);
  final teamAsync = ref.watch(competitorTeamDetailsProvider(arg.teamId));
  final team = teamAsync.value;
  if (team == null || team.golferIds.isEmpty) return [];

  final response = await client
      .from('tee_times')
      .select()
      .inFilter('tournament_golfer_id', team.golferIds)
      .eq('round', arg.round);

  return (response as List)
      .map((json) => TeeTime.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Subscribes to Supabase Realtime changes on the `hole_scores` table for a competitor's golfers.
final competitorScorecardSubscriptionProvider = Provider.autoDispose.family<void, ({String teamId, int round})>((ref, arg) {
  final client = ref.watch(supabaseClientProvider);
  final teamAsync = ref.watch(competitorTeamDetailsProvider(arg.teamId));
  final team = teamAsync.value;
  if (team == null) return;

  final golferIds = team.golferIds;
  if (golferIds.isEmpty) return;

  final channelName = 'competitor-scorecard-realtime-${arg.round}-${team.id}';
  final channel = client.channel(channelName);

  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'hole_scores',
    callback: (payload) {
      final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (record.isNotEmpty) {
        final golferId = record['tournament_golfer_id'] as String?;
        final recRound = record['round'] as int?;
        if (golferId != null && golferIds.contains(golferId) && recRound == arg.round) {
          // Update last realtime score event for cell pulse animation
          ref.read(lastRealtimeScoreUpdateProvider.notifier).update(ScoreUpdateEvent(
            tournamentGolferId: golferId,
            hole: record['hole'] as int,
            scoreType: record['score_type'] as String,
            timestamp: DateTime.now(),
          ));

          final newScore = HoleScore.fromJson(record);

          // Update golfer score incrementally
          ref.read(competitorGolfersHoleScoresProvider(arg).notifier).updateScore(newScore);

          // Get the latest golfer scores to update team best ball
          final updatedGolferScores = ref.read(competitorGolfersHoleScoresProvider(arg)).value ?? [];
          ref.read(competitorTeamProvider(arg.teamId).notifier).updateBestBall(
            arg.round,
            newScore.hole,
            newScore.par,
            updatedGolferScores,
          );
        }
      }
    },
  ).subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
  });
});
