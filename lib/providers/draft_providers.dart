import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

/// Model representing a tournament.
class Tournament {
  final String id;
  final String espnEventId;
  final String? golfapiCourseId;
  final String name;
  final String course;
  final String location;
  final int par;
  final int yards;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final int? currentRound;
  final DateTime? lockTimeUtc;

  Tournament({
    required this.id,
    required this.espnEventId,
    this.golfapiCourseId,
    required this.name,
    required this.course,
    required this.location,
    required this.par,
    required this.yards,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.currentRound,
    this.lockTimeUtc,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      espnEventId: json['espn_event_id'] as String,
      golfapiCourseId: json['golfapi_course_id'] as String?,
      name: json['name'] as String,
      course: json['course'] as String,
      location: json['location'] as String,
      par: json['par'] as int,
      yards: json['yards'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String,
      currentRound: json['current_round'] as int?,
      lockTimeUtc: json['lock_time_utc'] != null
          ? DateTime.parse(json['lock_time_utc'] as String)
          : null,
    );
  }
}

/// Model representing a golfer's profile/stats.
class GolferProfile {
  final String id;
  final String espnId;
  final String name;
  final int? worldRank;
  final double? scoringAvg;
  final int? wins;
  final int? top10s;
  final int? cutsMade;
  final int? eventsPlayed;
  final int? roundsPlayed;

  GolferProfile({
    required this.id,
    required this.espnId,
    required this.name,
    this.worldRank,
    this.scoringAvg,
    this.wins,
    this.top10s,
    this.cutsMade,
    this.eventsPlayed,
    this.roundsPlayed,
  });

  factory GolferProfile.fromJson(Map<String, dynamic> json) {
    return GolferProfile(
      id: json['id'] as String,
      espnId: json['espn_id'] as String,
      name: json['name'] as String,
      worldRank: json['world_rank'] as int?,
      scoringAvg: json['scoring_avg'] != null
          ? (json['scoring_avg'] as num).toDouble()
          : null,
      wins: json['wins'] as int?,
      top10s: json['top_10s'] as int?,
      cutsMade: json['cuts_made'] as int?,
      eventsPlayed: json['events_played'] as int?,
      roundsPlayed: json['rounds_played'] as int?,
    );
  }
}

/// Model representing a golfer in a specific tournament.
class TournamentGolfer {
  final String id;
  final String tournamentId;
  final String golferProfileId;
  final double price;
  final String status;
  final GolferProfile profile;
  final DateTime? teeTime;

  TournamentGolfer({
    required this.id,
    required this.tournamentId,
    required this.golferProfileId,
    required this.price,
    required this.status,
    required this.profile,
    this.teeTime,
  });

  factory TournamentGolfer.fromJson(Map<String, dynamic> json) {
    DateTime? firstTeeTime;
    if (json['tee_times'] != null && json['tee_times'] is List) {
      final list = json['tee_times'] as List;
      if (list.isNotEmpty) {
        // Look for round 1 tee time, or fallback to the first available tee time
        final round1 = list.firstWhere(
          (t) => t['round'] == 1,
          orElse: () => list.first,
        );
        if (round1 != null && round1['tee_time_utc'] != null) {
          firstTeeTime = DateTime.parse(round1['tee_time_utc'] as String);
        }
      }
    }

    return TournamentGolfer(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      golferProfileId: json['golfer_profile_id'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      profile: GolferProfile.fromJson(
        json['golfer_profiles'] as Map<String, dynamic>,
      ),
      teeTime: firstTeeTime,
    );
  }
}

/// Model representing a user's drafted team.
class UserTeam {
  final String id;
  final String userId;
  final String tournamentId;
  final String status;
  final List<String> golferIds;

  UserTeam({
    required this.id,
    required this.userId,
    required this.tournamentId,
    required this.status,
    required this.golferIds,
  });

  factory UserTeam.fromJson(Map<String, dynamic> json, List<String> golferIds) {
    return UserTeam(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tournamentId: json['tournament_id'] as String,
      status: json['status'] as String,
      golferIds: golferIds,
    );
  }
}

/// Fetches the active tournament (not COMPLETED).
final activeTournamentProvider = FutureProvider<Tournament?>((ref) async {
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
  return Tournament.fromJson(response);
});

/// Fetches the golfer list for the active tournament.
final golferListProvider = FutureProvider<List<TournamentGolfer>>((ref) async {
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
final userTeamProvider = FutureProvider<UserTeam?>((ref) async {
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

    if (activeTournament.lockTimeUtc != null &&
        DateTime.now().toUtc().isAfter(activeTournament.lockTimeUtc!)) {
      throw Exception('Tournament has locked. Cannot modify roster.');
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
      // Clear current team_golfers first
      await client.from('team_golfers').delete().eq('team_id', teamId);
    }

    // Insert selected golfers
    final List<Map<String, dynamic>> teamGolfersRows = selectedGolfers.map((
      golfer,
    ) {
      return {'team_id': teamId, 'tournament_golfer_id': golfer.id};
    }).toList();

    await client.from('team_golfers').insert(teamGolfersRows);

    // Refresh userTeamProvider to update the UI status
    ref.invalidate(userTeamProvider);
  };
});
