/// Model representing a team's row in the leaderboard standings.
class LeaderboardStanding {
  final String teamId;
  final String tournamentId;
  final String status; // ACTIVE, CUT, DQ
  final int? rank;
  final int totalToPar;
  final int? r1;
  final int? r2;
  final int? r3;
  final int? r4;
  final double budgetUsed;
  final String teamName;

  LeaderboardStanding({
    required this.teamId,
    required this.tournamentId,
    required this.status,
    required this.rank,
    required this.totalToPar,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.budgetUsed,
    required this.teamName,
  });

  factory LeaderboardStanding.fromJson(Map<String, dynamic> json) {
    String name = 'Unknown Team';
    final teamsMap = json['teams'] as Map<String, dynamic>?;
    if (teamsMap != null) {
      final usersMap = teamsMap['users'] as Map<String, dynamic>?;
      if (usersMap != null) {
        name = (usersMap['team_name'] as String?) ?? 'Unknown Team';
      }
    }

    return LeaderboardStanding(
      teamId: json['team_id'] as String,
      tournamentId: json['tournament_id'] as String,
      status: json['status'] as String,
      rank: json['rank'] as int?,
      totalToPar: json['total_to_par'] as int,
      r1: json['r1'] as int?,
      r2: json['r2'] as int?,
      r3: json['r3'] as int?,
      r4: json['r4'] as int?,
      budgetUsed: (json['budget_used'] as num).toDouble(),
      teamName: name,
    );
  }
}
