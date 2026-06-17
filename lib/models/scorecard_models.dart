/// Model representing a team's best ball score for a single hole/round/team.
class TeamHoleScore {
  final String teamId;
  final int round;
  final int hole;
  final int par;
  final int bestBallScore;
  final int holeToPar;

  TeamHoleScore({
    required this.teamId,
    required this.round,
    required this.hole,
    required this.par,
    required this.bestBallScore,
    required this.holeToPar,
  });

  factory TeamHoleScore.fromJson(Map<String, dynamic> json) {
    return TeamHoleScore(
      teamId: json['team_id'] as String,
      round: json['round'] as int,
      hole: json['hole'] as int,
      par: json['par'] as int,
      bestBallScore: json['best_ball_score'] as int,
      holeToPar: json['hole_to_par'] as int,
    );
  }
}

/// Model representing a single hole score for a golfer.
class HoleScore {
  final String id;
  final String tournamentGolferId;
  final int round;
  final int hole;
  final int par;
  final int score;
  final String scoreType;

  HoleScore({
    required this.id,
    required this.tournamentGolferId,
    required this.round,
    required this.hole,
    required this.par,
    required this.score,
    required this.scoreType,
  });

  factory HoleScore.fromJson(Map<String, dynamic> json) {
    return HoleScore(
      id: json['id'] as String,
      tournamentGolferId: json['tournament_golfer_id'] as String,
      round: json['round'] as int,
      hole: json['hole'] as int,
      par: json['par'] as int,
      score: json['score'] as int,
      scoreType: json['score_type'] as String,
    );
  }
}

/// Model representing a tee time for a golfer.
class TeeTime {
  final String id;
  final String tournamentGolferId;
  final int round;
  final DateTime teeTimeUtc;
  final int startTee;
  final String status;

  TeeTime({
    required this.id,
    required this.tournamentGolferId,
    required this.round,
    required this.teeTimeUtc,
    required this.startTee,
    required this.status,
  });

  factory TeeTime.fromJson(Map<String, dynamic> json) {
    return TeeTime(
      id: json['id'] as String,
      tournamentGolferId: json['tournament_golfer_id'] as String,
      round: json['round'] as int,
      teeTimeUtc: DateTime.parse(json['tee_time_utc'] as String),
      startTee: json['start_tee'] as int,
      status: json['status'] as String,
    );
  }
}

/// Event model representing a live hole score update.
class ScoreUpdateEvent {
  final String tournamentGolferId;
  final int hole;
  final String scoreType;
  final DateTime timestamp;

  ScoreUpdateEvent({
    required this.tournamentGolferId,
    required this.hole,
    required this.scoreType,
    required this.timestamp,
  });
}
