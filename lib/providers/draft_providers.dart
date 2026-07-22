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

  Future<void> addGolfer(TournamentGolfer golfer) async {
    if (state.length >= 4) {
      throw Exception('Roster is already full');
    }
    if (golfer.status == 'WD') {
      throw Exception('Golfer has withdrawn and is unavailable');
    }
    if (state.any((g) => g.id == golfer.id)) {
      throw Exception('Golfer is already on your roster');
    }

    final client = ref.read(supabaseClientProvider);
    final activeTournament = ref.read(activeTournamentProvider).value;
    final session = ref.read(authSessionProvider).value;

    if (activeTournament == null || session == null) {
      throw Exception('Missing active tournament or user session');
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
    } else {
      teamId = existingTeam.id;
    }

    await client.from('team_golfers').insert({
      'team_id': teamId,
      'tournament_golfer_id': golfer.id,
    });

    state = [...state, golfer];

    // Reset status to ACTIVE if the roster is now complete and under budget
    final totalSpend = double.parse(
      state.fold<double>(0, (sum, g) => sum + g.price).toStringAsFixed(2),
    );
    if (state.length == 4 && totalSpend <= 100.0) {
      await client.from('teams').update({'status': 'ACTIVE'}).eq('id', teamId);
    }

    ref.invalidate(userTeamProvider);
  }

  Future<void> removeGolfer(TournamentGolfer golfer) async {
    final client = ref.read(supabaseClientProvider);
    final existingTeam = ref.read(userTeamProvider).value;

    if (existingTeam == null) {
      throw Exception('Team not found');
    }

    await client
        .from('team_golfers')
        .delete()
        .eq('team_id', existingTeam.id)
        .eq('tournament_golfer_id', golfer.id);

    state = state.where((g) => g.id != golfer.id).toList();
    ref.invalidate(userTeamProvider);
  }

  Future<void> replaceGolfer(
    TournamentGolfer oldGolfer,
    TournamentGolfer newGolfer,
  ) async {
    if (newGolfer.status == 'WD') {
      throw Exception('Golfer has withdrawn and is unavailable');
    }
    if (state.any((g) => g.id == newGolfer.id)) {
      throw Exception('Golfer is already on your roster');
    }

    final client = ref.read(supabaseClientProvider);
    final existingTeam = ref.read(userTeamProvider).value;

    if (existingTeam == null) {
      throw Exception('Team not found');
    }

    // Delete old golfer
    await client
        .from('team_golfers')
        .delete()
        .eq('team_id', existingTeam.id)
        .eq('tournament_golfer_id', oldGolfer.id);

    // Insert new golfer
    try {
      await client.from('team_golfers').insert({
        'team_id': existingTeam.id,
        'tournament_golfer_id': newGolfer.id,
      });
    } catch (e) {
      // Rollback if insert fails (e.g. over budget or golfer teed off/locked)
      await client.from('team_golfers').insert({
        'team_id': existingTeam.id,
        'tournament_golfer_id': oldGolfer.id,
      });
      rethrow;
    }

    state = state.map((g) => g.id == oldGolfer.id ? newGolfer : g).toList();

    // Reset status to ACTIVE if the roster is now complete and under budget
    final totalSpend = double.parse(
      state.fold<double>(0, (sum, g) => sum + g.price).toStringAsFixed(2),
    );
    if (state.length == 4 && totalSpend <= 100.0) {
      await client
          .from('teams')
          .update({'status': 'ACTIVE'})
          .eq('id', existingTeam.id);
    }

    ref.invalidate(userTeamProvider);
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
