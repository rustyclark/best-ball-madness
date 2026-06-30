import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';
import '../models/draft_models.dart';
export '../models/draft_models.dart';

/// Checks if the current time is before the weekly transition (Tuesday 6:00 AM EST).
/// Returns true if we are before Tuesday 6:00 AM EST of the current week.
bool isBeforeWeeklyTransition([DateTime? mockTime]) {
  final nowUtc = (mockTime ?? DateTime.now()).toUtc();
  // weekday is 1 (Monday) to 7 (Sunday).
  final daysToTuesday = 2 - nowUtc.weekday;

  // US Daylight Saving Time (Eastern Time) details:
  // Starts second Sunday of March, ends first Sunday of November.
  // In EDT, 6:00 AM ET is 10:00 AM UTC.
  // In EST, 6:00 AM ET is 11:00 AM UTC.
  final isDst = _isUSDaylightSaving(nowUtc);
  final transitionHour = isDst ? 10 : 11;

  final transitionTuesday = DateTime.utc(
    nowUtc.year,
    nowUtc.month,
    nowUtc.day,
    transitionHour,
    0,
  ).add(Duration(days: daysToTuesday));

  return nowUtc.isBefore(transitionTuesday);
}

bool _isUSDaylightSaving(DateTime time) {
  if (time.month < 3 || time.month > 11) return false;
  if (time.month > 3 && time.month < 11) return true;

  if (time.month == 3) {
    final firstWeekday = DateTime.utc(time.year, 3, 1).weekday;
    final secondSunday = 1 + (7 - firstWeekday + 7) % 7 + 7;
    return time.day >= secondSunday;
  }

  if (time.month == 11) {
    final firstWeekday = DateTime.utc(time.year, 11, 1).weekday;
    final firstSunday = 1 + (7 - firstWeekday) % 7;
    return time.day < firstSunday;
  }

  return false;
}

/// Fetches the active tournament, taking weekly transition into account.
final activeTournamentProvider = FutureProvider.autoDispose<Tournament?>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('tournaments')
      .select()
      .order('start_date', ascending: false)
      .limit(2);

  final list = (response as List)
      .map((json) => Tournament.fromJson(json as Map<String, dynamic>))
      .toList();

  if (list.isEmpty) {
    return null;
  }

  final Tournament activeTournament;
  if (isBeforeWeeklyTransition()) {
    // Before Tuesday 6am EST, show the completed/in-progress tournament from last week (not scheduled yet)
    Tournament? found;
    try {
      found = list.firstWhere((t) => t.status != 'SCHEDULED');
    } catch (_) {
      found = list.first;
    }
    activeTournament = found;
  } else {
    // After Tuesday 6am EST, show the latest tournament (scheduled or in-progress)
    activeTournament = list.first;
  }

  // Set up realtime channel subscription to listen for updates to this active tournament
  final channel = client.channel('active-tournament-${activeTournament.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tournaments',
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          if (record.isNotEmpty && record['id'] == activeTournament.id) {
            ref.invalidateSelf();
          }
        },
      )
      .subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
  });

  return activeTournament;
});

/// Fetches the next scheduled tournament (status = SCHEDULED).
final nextTournamentProvider = FutureProvider.autoDispose<Tournament?>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('tournaments')
      .select()
      .eq('status', 'SCHEDULED')
      .order('start_date', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) {
    return null;
  }
  return Tournament.fromJson(response);
});

/// Fetches the golfer list for the active tournament.
final golferListProvider = FutureProvider.autoDispose<List<TournamentGolfer>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final activeTournament = await ref.watch(activeTournamentProvider.future);

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
  final activeTournament = await ref.watch(activeTournamentProvider.future);
  final session = await ref.watch(authSessionProvider.future);

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
      .select('tournament_golfer_id, price_at_draft')
      .eq('team_id', teamId);

  final list = golfersResponse as List;
  final golferIds = list
      .map((row) => row['tournament_golfer_id'] as String)
      .toList();

  final pricesAtDraft = <String, double>{};
  for (final row in list) {
    final id = row['tournament_golfer_id'] as String;
    final priceVal = row['price_at_draft'];
    if (priceVal != null) {
      pricesAtDraft[id] = (priceVal as num).toDouble();
    }
  }

  return UserTeam.fromJson(teamResponse, golferIds, pricesAtDraft);
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

  bool replaceGolfer(TournamentGolfer oldGolfer, TournamentGolfer newGolfer) {
    if (state.any((g) => g.id == newGolfer.id)) return false;
    state = state.map((g) => g.id == oldGolfer.id ? newGolfer : g).toList();
    return true;
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

      final toRemove = currentGolferIds
          .where((id) => !newGolferIds.contains(id))
          .toList();
      final toAdd = newGolferIds
          .where((id) => !currentGolferIds.contains(id))
          .toList();

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
