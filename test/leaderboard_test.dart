import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:best_ball_madness/providers/auth_providers.dart';
import 'package:best_ball_madness/providers/draft_providers.dart';
import 'package:best_ball_madness/providers/leaderboard_providers.dart';
import 'package:best_ball_madness/screens/leaderboard/leaderboard_screen.dart';
import 'helpers/fake_supabase.dart';

void main() {
  group('Leaderboard Standings Sorting & Formatting Unit Tests', () {
    test(
      'LeaderboardStanding parses fromJson correctly with joined team name',
      () {
        final json = {
          'team_id': 'team-1',
          'tournament_id': 't-1',
          'status': 'ACTIVE',
          'rank': 1,
          'total_to_par': -4,
          'r1': -1,
          'r2': -3,
          'r3': 0,
          'r4': null,
          'budget_used': 95.0,
          'teams': {
            'id': 'team-1',
            'user_id': 'user-1',
            'users': {'team_name': 'My Super Team'},
          },
        };

        final standing = LeaderboardStanding.fromJson(json);
        expect(standing.teamId, 'team-1');
        expect(standing.teamName, 'My Super Team');
        expect(standing.totalToPar, -4);
        expect(standing.r1, -1);
        expect(standing.r4, isNull);
      },
    );

    test('LeaderboardStanding handles missing teams/users gracefully', () {
      final json = {
        'team_id': 'team-1',
        'tournament_id': 't-1',
        'status': 'CUT',
        'rank': null,
        'total_to_par': 2,
        'r1': 1,
        'r2': 1,
        'r3': null,
        'r4': null,
        'budget_used': 90.0,
      };

      final standing = LeaderboardStanding.fromJson(json);
      expect(standing.teamName, 'Unknown Team');
    });
  });

  group('Leaderboard Screen Widgets Tests', () {
    late FakeSupabaseClient fakeSupabase;
    late Tournament mockTournament;
    late List<TournamentGolfer> mockGolfers;

    setUp(() {
      mockTournament = Tournament(
        id: 't-1',
        espnEventId: 'espn-1',
        name: 'The Masters',
        course: 'Augusta National',
        location: 'Augusta, GA',
        par: 72,
        yards: 7400,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 2)),
        status: 'IN_PROGRESS',
        currentRound: 2,
      );

      mockGolfers = List.generate(4, (index) {
        final idNum = index + 1;
        return TournamentGolfer(
          id: 'tg-$idNum',
          tournamentId: 't-1',
          golferProfileId: 'gp-$idNum',
          price: 25.0,
          status: 'ACTIVE',
          profile: GolferProfile(
            id: 'gp-$idNum',
            espnId: 'espn-gp-$idNum',
            name: 'Golfer $idNum',
          ),
        );
      });

      fakeSupabase = FakeSupabaseClient(
        mockData: {
          'tournaments': [
            {
              'id': 't-1',
              'espn_event_id': 'espn-1',
              'name': 'The Masters',
              'course': 'Augusta National',
              'location': 'Augusta, GA',
              'par': 72,
              'yards': 7400,
              'start_date': DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'end_date': DateTime.now()
                  .add(const Duration(days: 2))
                  .toIso8601String(),
              'status': 'IN_PROGRESS',
              'current_round': 2,
            },
          ],
          'leaderboard_standings': [
            {
              'team_id': 'team-1',
              'tournament_id': 't-1',
              'status': 'ACTIVE',
              'rank': 2,
              'total_to_par': -2,
              'r1': -1,
              'r2': -1,
              'r3': null,
              'r4': null,
              'budget_used': 95.0,
              'teams': {
                'id': 'team-1',
                'user_id': 'user-1',
                'users': {'team_name': 'Team Active Two'},
              },
            },
            {
              'team_id': 'team-2',
              'tournament_id': 't-1',
              'status': 'ACTIVE',
              'rank': 1,
              'total_to_par': -5,
              'r1': -2,
              'r2': -3,
              'r3': null,
              'r4': null,
              'budget_used': 98.0,
              'teams': {
                'id': 'team-2',
                'user_id': 'user-2',
                'users': {'team_name': 'Team Active One'},
              },
            },
            {
              'team_id': 'team-3',
              'tournament_id': 't-1',
              'status': 'CUT',
              'rank': null,
              'total_to_par': 4,
              'r1': 2,
              'r2': 2,
              'r3': null,
              'r4': null,
              'budget_used': 85.0,
              'teams': {
                'id': 'team-3',
                'user_id': 'user-3',
                'users': {'team_name': 'Team Cut One'},
              },
            },
            {
              'team_id': 'team-4',
              'tournament_id': 't-1',
              'status': 'DQ',
              'rank': null,
              'total_to_par': 10,
              'r1': 5,
              'r2': 5,
              'r3': null,
              'r4': null,
              'budget_used': 75.0,
              'teams': {
                'id': 'team-4',
                'user_id': 'user-4',
                'users': {'team_name': 'Team DQ One'},
              },
            },
          ],
          'teams': [
            {
              'id': 'team-3',
              'user_id': 'user-3',
              'tournament_id': 't-1',
              'status': 'CUT',
              'users': {'team_name': 'Team Cut One'},
            },
          ],
          'team_golfers': [
            {'tournament_golfer_id': 'tg-1'},
            {'tournament_golfer_id': 'tg-2'},
          ],
          'team_hole_scores': [
            {
              'team_id': 'team-3',
              'round': 2,
              'hole': 1,
              'par': 4,
              'best_ball_score': 5,
              'hole_to_par': 1,
            },
          ],
          'hole_scores': [],
          'tee_times': [],
        },
      );
    });

    Widget createLeaderboardWidget() {
      return ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(fakeSupabase),
          activeTournamentProvider.overrideWith((ref) => mockTournament),
          golferListProvider.overrideWith((ref) => mockGolfers),
        ],
        child: const MaterialApp(home: LeaderboardScreen()),
      );
    }

    testWidgets(
      'Leaderboard groups and sorts correctly (ACTIVE -> CUT -> DQ)',
      (WidgetTester tester) async {
        await tester.pumpWidget(createLeaderboardWidget());
        await tester.pumpAndSettle();

        // Verify that all section headers exist
        expect(find.text('ACTIVE COMPETITORS'), findsOneWidget);
        expect(find.text('CUT / ELIMINATED'), findsOneWidget);
        expect(find.text('DISQUALIFIED'), findsOneWidget);

        // Verify team names render
        expect(find.text('Team Active One'), findsOneWidget);
        expect(find.text('Team Active Two'), findsOneWidget);
        expect(find.text('Team Cut One'), findsOneWidget);
        expect(find.text('Team DQ One'), findsOneWidget);

        // Verify scores format relative to par correctly
        expect(find.text('-5'), findsOneWidget);
        expect(find.text('-2'), findsNWidgets(2));
        expect(find.text('+4'), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);

        // Verify ranks render correctly
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets('Tied ACTIVE teams display the T- prefix correctly', (
      WidgetTester tester,
    ) async {
      // Set two active teams to rank 1
      fakeSupabase.mockData['leaderboard_standings'] = [
        {
          'team_id': 'team-1',
          'tournament_id': 't-1',
          'status': 'ACTIVE',
          'rank': 1,
          'total_to_par': -5,
          'r1': -2,
          'r2': -3,
          'budget_used': 95.0,
          'teams': {
            'id': 'team-1',
            'user_id': 'user-1',
            'users': {'team_name': 'Team A'},
          },
        },
        {
          'team_id': 'team-2',
          'tournament_id': 't-1',
          'status': 'ACTIVE',
          'rank': 1,
          'total_to_par': -5,
          'r1': -2,
          'r2': -3,
          'budget_used': 95.0,
          'teams': {
            'id': 'team-2',
            'user_id': 'user-2',
            'users': {'team_name': 'Team B'},
          },
        },
        {
          'team_id': 'team-3',
          'tournament_id': 't-1',
          'status': 'ACTIVE',
          'rank': 3,
          'total_to_par': -2,
          'r1': -1,
          'r2': -1,
          'budget_used': 90.0,
          'teams': {
            'id': 'team-3',
            'user_id': 'user-3',
            'users': {'team_name': 'Team C'},
          },
        },
      ];

      await tester.pumpWidget(createLeaderboardWidget());
      await tester.pumpAndSettle();

      // We expect Team A and Team B to show T-1, and Team C to show 3
      expect(find.text('T-1'), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
      'Clicking row successfully displays the competitor read-only scorecard',
      (WidgetTester tester) async {
        await tester.pumpWidget(createLeaderboardWidget());
        await tester.pumpAndSettle();

        // Tap on the row containing 'Team Cut One'
        await tester.tap(find.text('Team Cut One'));
        await tester.pumpAndSettle();

        // Verify navigation to ScorecardScreen and that the competitor's app bar title is shown
        expect(find.text('TEAM CUT ONE SCORECARD'), findsOneWidget);
      },
    );

    testWidgets(
      'Realtime updates to leaderboard_standings rebuild the leaderboard UI live',
      (WidgetTester tester) async {
        await tester.pumpWidget(createLeaderboardWidget());
        await tester.pumpAndSettle();

        // Verify original score -5 is displayed
        expect(find.text('-5'), findsOneWidget);
        expect(find.text('-9'), findsNothing);

        // Update mock data
        fakeSupabase.mockData['leaderboard_standings'] = [
          {
            'team_id': 'team-1',
            'tournament_id': 't-1',
            'status': 'ACTIVE',
            'rank': 2,
            'total_to_par': -2,
            'budget_used': 95.0,
            'teams': {
              'id': 'team-1',
              'user_id': 'user-1',
              'users': {'team_name': 'Team Active Two'},
            },
          },
          {
            'team_id': 'team-2',
            'tournament_id': 't-1',
            'status': 'ACTIVE',
            'rank': 1,
            'total_to_par': -9, // Changed from -5 to -9
            'budget_used': 98.0,
            'teams': {
              'id': 'team-2',
              'user_id': 'user-2',
              'users': {'team_name': 'Team Active One'},
            },
          },
        ];

        // Retrieve the active leaderboard realtime channel
        final channel = fakeSupabase.activeChannels.firstWhere(
          (c) => c.name.startsWith('leaderboard-realtime'),
        );

        // Trigger realtime update event
        channel.triggerPostgresChange(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'leaderboard_standings',
          newRecord: {},
          oldRecord: {},
        );

        // Let UI rebuild and resolve data
        await tester.pumpAndSettle();

        // Verify new score -9 is now displayed, and -5 is gone
        expect(find.text('-9'), findsOneWidget);
        expect(find.text('-5'), findsNothing);
      },
    );
  });
}
