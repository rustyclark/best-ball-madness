import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';
import '../models/draft_models.dart';
export '../models/draft_models.dart';

/// Fetches the active tournament (not COMPLETED).
final activeTournamentProvider = FutureProvider.autoDispose<Tournament?>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('tournaments')
      .select()
      .neq('status', 'COMPLETED')
      .order('start_date', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) {
    return null;
  }
  final tournament = Tournament.fromJson(response);

  // Set up realtime channel subscription to listen for updates to this active tournament
  final channel = client.channel('active-tournament-${tournament.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tournaments',
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          if (record.isNotEmpty && record['id'] == tournament.id) {
            ref.invalidateSelf();
          }
        },
      )
      .subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
  });

  return tournament;
});

/// Fetches the golfer list for the active tournament.
final golferListProvider = FutureProvider.autoDispose<List<TournamentGolfer>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final activeTournamentAsync = ref.watch(activeTournamentProvider);
  final activeTournament = activeTournamentAsync.value;

  if (activeTournament == null) {
    return [];
  }

  final response = await client
      .from('tournament_golfers')
      .select('*, golfer_profiles(*), tee_times(*)')
      .eq('tournament_id', activeTournament.id);

  final list = (response as List)
      .map((json) => TournamentGolfer.fromJson(json as Map<String, dynamic>))
      .toList();

  // Default sort by price descending
  list.sort((a, b) => b.price.compareTo(a.price));
  return list;
});

/// Fetches the user's saved team for the active tournament.
final userTeamProvider = FutureProvider.autoDispose<UserTeam?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final activeTournamentAsync = ref.watch(activeTournamentProvider);
  final sessionAsync = ref.watch(authSessionProvider);

  final activeTournament = activeTournamentAsync.value;
  final session = sessionAsync.value;

  if (activeTournament == null || session == null) {
    return null;
  }

  final teamResponse = await client
      .from('teams')
      .select()
      .eq('user_id', session.user.id)
      .eq('tournament_id', activeTournament.id)
      .maybeSingle();

  if (teamResponse == null) {
    return null;
  }

  final teamId = teamResponse['id'] as String;

  final golfersResponse = await client
      .from('team_golfers')
      .select('tournament_golfer_id')
      .eq('team_id', teamId);

  final golferIds = (golfersResponse as List)
      .map((row) => row['tournament_golfer_id'] as String)
      .toList();

  return UserTeam.fromJson(teamResponse, golferIds);
});

/// Notifier managing the local client-side draft selection state.
class DraftStateNotifier extends Notifier<List<TournamentGolfer>> {
  @override
  List<TournamentGolfer> build() {
    return [];
  }

  void setSelection(List<TournamentGolfer> selection) {
    state = selection;
  }

  bool addGolfer(TournamentGolfer golfer) {
    if (state.length >= 4) return false;
    if (state.any((g) => g.id == golfer.id)) return false;
    state = [...state, golfer];
    return true;
  }

  void removeGolfer(TournamentGolfer golfer) {
    state = state.where((g) => g.id != golfer.id).toList();
  }

  void clear() {
    state = [];
  }
}

/// Provider for the local client-side draft selection state.
final draftStateNotifierProvider =
    NotifierProvider<DraftStateNotifier, List<TournamentGolfer>>(() {
      return DraftStateNotifier();
    });

/// Provider for the save team action.
final saveTeamAction = Provider<Future<void> Function(List<TournamentGolfer>)>((
  ref,
) {
  return (selectedGolfers) async {
    final client = ref.read(supabaseClientProvider);
    final activeTournament = ref.read(activeTournamentProvider).value;
    final session = ref.read(authSessionProvider).value;

    if (activeTournament == null || session == null) {
      throw Exception('Missing active tournament or user session');
    }

    if (selectedGolfers.length != 4) {
      throw Exception('Roster must contain exactly 4 golfers');
    }

    final totalBudget = selectedGolfers.fold<double>(
      0,
      (sum, g) => sum + g.price,
    );
    if (totalBudget > 100.0) {
      throw Exception('Budget of \$100 exceeded');
    }

    if (activeTournament.status == 'COMPLETED') {
      throw Exception('Tournament has completed. Cannot modify roster.');
    }

    final existingTeam = ref.read(userTeamProvider).value;
    String teamId;

    if (existingTeam == null) {
      final teamInsert = await client
          .from('teams')
          .insert({
            'user_id': session.user.id,
            'tournament_id': activeTournament.id,
            'status': 'ACTIVE',
          })
          .select()
          .single();
      teamId = teamInsert['id'] as String;

      final List<Map<String, dynamic>> teamGolfersRows = selectedGolfers.map((
        golfer,
      ) {
        return {'team_id': teamId, 'tournament_golfer_id': golfer.id};
      }).toList();

      await client.from('team_golfers').insert(teamGolfersRows);
    } else {
      teamId = existingTeam.id;
      final currentGolferIds = existingTeam.golferIds;
      final newGolferIds = selectedGolfers.map((g) => g.id).toList();

      final toRemove = currentGolferIds.where((id) => !newGolferIds.contains(id)).toList();
      final toAdd = newGolferIds.where((id) => !currentGolferIds.contains(id)).toList();

      if (toRemove.isNotEmpty) {
        await client
            .from('team_golfers')
            .delete()
            .eq('team_id', teamId)
            .inFilter('tournament_golfer_id', toRemove);
      }

      if (toAdd.isNotEmpty) {
        final List<Map<String, dynamic>> teamGolfersRows = toAdd.map((id) {
          return {'team_id': teamId, 'tournament_golfer_id': id};
        }).toList();
        await client.from('team_golfers').insert(teamGolfersRows);
      }
    }

    // Refresh userTeamProvider to update the UI status
    ref.invalidate(userTeamProvider);
  };
});
