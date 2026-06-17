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
  final bool isAmateur;
  final double? scoringAvg;
  final int? wins;
  final int? top10s;
  final int? cutsMade;
  final int? eventsPlayed;
  final int? roundsPlayed;

  final double? priorScoringAvg;
  final int? priorWins;
  final int? priorTop10s;
  final int? priorCutsMade;
  final int? priorEventsPlayed;
  final int? priorRoundsPlayed;

  GolferProfile({
    required this.id,
    required this.espnId,
    required this.name,
    this.worldRank,
    this.isAmateur = false,
    this.scoringAvg,
    this.wins,
    this.top10s,
    this.cutsMade,
    this.eventsPlayed,
    this.roundsPlayed,
    this.priorScoringAvg,
    this.priorWins,
    this.priorTop10s,
    this.priorCutsMade,
    this.priorEventsPlayed,
    this.priorRoundsPlayed,
  });

  factory GolferProfile.fromJson(Map<String, dynamic> json) {
    return GolferProfile(
      id: json['id'] as String,
      espnId: json['espn_id'] as String,
      name: json['name'] as String,
      worldRank: json['world_rank'] as int?,
      isAmateur: json['is_amateur'] as bool? ?? false,
      scoringAvg: json['scoring_avg'] != null
          ? (json['scoring_avg'] as num).toDouble()
          : null,
      wins: json['wins'] as int?,
      top10s: json['top_10s'] as int?,
      cutsMade: json['cuts_made'] as int?,
      eventsPlayed: json['events_played'] as int?,
      roundsPlayed: json['rounds_played'] as int?,
      priorScoringAvg: json['prior_scoring_avg'] != null
          ? (json['prior_scoring_avg'] as num).toDouble()
          : null,
      priorWins: json['prior_wins'] as int?,
      priorTop10s: json['prior_top_10s'] as int?,
      priorCutsMade: json['prior_cuts_made'] as int?,
      priorEventsPlayed: json['prior_events_played'] as int?,
      priorRoundsPlayed: json['prior_rounds_played'] as int?,
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
  final String? teamName;

  UserTeam({
    required this.id,
    required this.userId,
    required this.tournamentId,
    required this.status,
    required this.golferIds,
    this.teamName,
  });

  factory UserTeam.fromJson(Map<String, dynamic> json, List<String> golferIds) {
    String? teamName;
    if (json['users'] != null && json['users'] is Map) {
      teamName = json['users']['team_name'] as String?;
    }
    return UserTeam(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tournamentId: json['tournament_id'] as String,
      status: json['status'] as String,
      golferIds: golferIds,
      teamName: teamName,
    );
  }
}
