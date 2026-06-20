import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';
import 'draft_providers.dart';
import '../models/scorecard_models.dart';
export '../models/scorecard_models.dart';

/// Notifier managing individual hole scores for the user's team's golfers in a specific round.
class TeamGolfersHoleScoresNotifier extends AsyncNotifier<List<HoleScore>> {
  final int round;

  TeamGolfersHoleScoresNotifier(this.round);

  @override
  FutureOr<List<HoleScore>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final userTeam = ref.watch(userTeamProvider).value;
    if (userTeam == null || userTeam.golferIds.isEmpty) {
      return [];
    }

    final response = await client
        .from('hole_scores')
        .select()
        .inFilter('tournament_golfer_id', userTeam.golferIds)
        .eq('round', round);

    return (response as List)
        .map((json) => HoleScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void updateScore(HoleScore newScore) {
    if (!state.hasValue) return;
    final currentData = state.value!;
    final index = currentData.indexWhere(
      (s) =>
          s.tournamentGolferId == newScore.tournamentGolferId &&
          s.round == newScore.round &&
          s.hole == newScore.hole,
    );

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

/// Provider for individual hole scores of user team golfers.
final teamGolfersHoleScoresProvider = AsyncNotifierProvider.autoDispose
    .family<TeamGolfersHoleScoresNotifier, List<HoleScore>, int>((arg) {
      return TeamGolfersHoleScoresNotifier(arg);
    });

/// Notifier managing the user's team's best-ball hole scores for a specific round.
class UserTeamScoreNotifier extends AsyncNotifier<List<TeamHoleScore>> {
  final int round;

  UserTeamScoreNotifier(this.round);

  @override
  FutureOr<List<TeamHoleScore>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final userTeam = ref.watch(userTeamProvider).value;
    if (userTeam == null) {
      return [];
    }

    final response = await client
        .from('team_hole_scores')
        .select()
        .eq('team_id', userTeam.id)
        .eq('round', round);

    return (response as List)
        .map((json) => TeamHoleScore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void updateBestBall(int hole, int par, List<HoleScore> golferScores) {
    if (!state.hasValue) return;
    final scoresForHole = golferScores
        .where((s) => s.hole == hole)
        .map((s) => s.score)
        .toList();
    if (scoresForHole.isEmpty) return;
    final newBestScore = scoresForHole.reduce((a, b) => a < b ? a : b);

    final currentData = state.value!;
    final index = currentData.indexWhere((s) => s.hole == hole);

    final updatedScore = TeamHoleScore(
      teamId: currentData.isNotEmpty ? currentData.first.teamId : '',
      round: currentData.isNotEmpty ? currentData.first.round : round,
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

/// Provider for user team best ball scores.
final userTeamScoreProvider = AsyncNotifierProvider.autoDispose
    .family<UserTeamScoreNotifier, List<TeamHoleScore>, int>((arg) {
      return UserTeamScoreNotifier(arg);
    });

/// Fetches tee times for the user's team's golfers in a specific round.
final teamGolfersTeeTimesProvider = FutureProvider.autoDispose
    .family<List<TeeTime>, int>((ref, round) async {
      final client = ref.watch(supabaseClientProvider);
      final userTeam = ref.watch(userTeamProvider).value;
      if (userTeam == null || userTeam.golferIds.isEmpty) return [];

      final response = await client
          .from('tee_times')
          .select()
          .inFilter('tournament_golfer_id', userTeam.golferIds)
          .eq('round', round);

      return (response as List)
          .map((json) => TeeTime.fromJson(json as Map<String, dynamic>))
          .toList();
    });

/// Notifier managing the last realtime score update event.
class LastRealtimeScoreUpdateNotifier extends Notifier<ScoreUpdateEvent?> {
  @override
  ScoreUpdateEvent? build() => null;

  void update(ScoreUpdateEvent? event) {
    state = event;
  }
}

/// Stores the latest realtime score update event to drive micro-animations.
final lastRealtimeScoreUpdateProvider =
    NotifierProvider<LastRealtimeScoreUpdateNotifier, ScoreUpdateEvent?>(() {
      return LastRealtimeScoreUpdateNotifier();
    });

/// Subscribes to Supabase Realtime changes on the `hole_scores` table for the team's golfers.
final scorecardSubscriptionProvider = Provider.autoDispose.family<void, int>((
  ref,
  round,
) {
  final client = ref.watch(supabaseClientProvider);
  final userTeam = ref.watch(userTeamProvider).value;
  if (userTeam == null) return;

  final golferIds = userTeam.golferIds;
  if (golferIds.isEmpty) return;

  final channelName = 'scorecard-realtime-$round-${userTeam.id}';
  final channel = client.channel(channelName);

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'hole_scores',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'tournament_golfer_id',
          value: golferIds,
        ),
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          if (record.isNotEmpty) {
            final golferId = record['tournament_golfer_id'] as String?;
            final recRound = record['round'] as int?;
            if (golferId != null &&
                golferIds.contains(golferId) &&
                recRound == round) {
              // Update last realtime score event for cell pulse animation
              ref
                  .read(lastRealtimeScoreUpdateProvider.notifier)
                  .update(
                    ScoreUpdateEvent(
                      tournamentGolferId: golferId,
                      hole: record['hole'] as int,
                      scoreType: record['score_type'] as String,
                      timestamp: DateTime.now(),
                    ),
                  );

              final newScore = HoleScore.fromJson(record);

              // Update golfer score incrementally
              ref
                  .read(teamGolfersHoleScoresProvider(round).notifier)
                  .updateScore(newScore);

              // Get the latest golfer scores to update team best ball
              final updatedGolferScores =
                  ref.read(teamGolfersHoleScoresProvider(round)).value ?? [];
              ref
                  .read(userTeamScoreProvider(round).notifier)
                  .updateBestBall(
                    newScore.hole,
                    newScore.par,
                    updatedGolferScores,
                  );
            }
          }
        },
      )
      .subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
  });
});

/// Listens to Supabase Realtime changes in the `teams` table to detect CUT/DQ status.
final teamStatusProvider = StreamProvider.autoDispose<String>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userTeam = ref.watch(userTeamProvider).value;
  if (userTeam == null) return const Stream.empty();

  final controller = StreamController<String>();
  controller.add(userTeam.status);

  final channel = client.channel('team-status-${userTeam.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'teams',
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          if (record.isNotEmpty &&
              record['id'] == userTeam.id &&
              record['status'] != null) {
            controller.add(record['status'] as String);
          }
        },
      )
      .subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

/// Exposes the active tournament's current round.
final currentRoundProvider = Provider.autoDispose<int>((ref) {
  final tournament = ref.watch(activeTournamentProvider).value;
  return tournament?.currentRound ?? 1;
});

/// Notifier managing the selected round tab.
class SelectedRoundNotifier extends Notifier<int> {
  int? _manuallySelectedRound;
  String? _lastTournamentId;

  @override
  int build() {
    final current = ref.watch(currentRoundProvider);
    final tournament = ref.watch(activeTournamentProvider).value;


    if (tournament != null && tournament.id != _lastTournamentId) {
      _lastTournamentId = tournament.id;
      _manuallySelectedRound = null;
    }

    if (_manuallySelectedRound != null) {
      return _manuallySelectedRound!;
    }

    return current;
  }

  void setRound(int round) {
    _manuallySelectedRound = round;
    state = round;
  }
}

/// Manages the selected round tab in the scorecard UI.
final selectedRoundProvider =
    NotifierProvider.autoDispose<SelectedRoundNotifier, int>(() {
      return SelectedRoundNotifier();
    });
