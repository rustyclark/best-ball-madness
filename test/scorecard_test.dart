import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:best_ball_madness/providers/auth_providers.dart';
import 'package:best_ball_madness/providers/draft_providers.dart';
import 'package:best_ball_madness/providers/scorecard_providers.dart';
import 'package:best_ball_madness/screens/scorecard/scorecard_screen.dart';
import 'package:best_ball_madness/utils/score_utils.dart';
import 'package:best_ball_madness/theme/colors.dart';
import 'helpers/fake_supabase.dart';

void main() {
  group('Scorecard Color Mapping Unit Tests', () {
    test('getScoreColors returns correct colors based on math difference', () {
      // Eagle or better: diff <= -2
      final eagleColors = getScoreColors(3, 5);
      expect(eagleColors.bg, AppColors.scoreEagleOrBetterBg);
      expect(eagleColors.text, AppColors.scoreEagleOrBetterText);

      // Birdie: diff == -1
      final birdieColors = getScoreColors(3, 4);
      expect(birdieColors.bg, AppColors.scoreBirdieBg);
      expect(birdieColors.text, AppColors.scoreBirdieText);

      // Par: diff == 0
      final parColors = getScoreColors(4, 4);
      expect(parColors.bg, AppColors.scoreParBg);
      expect(parColors.text, AppColors.scoreParText);

      // Bogey: diff == 1
      final bogeyColors = getScoreColors(5, 4);
      expect(bogeyColors.bg, AppColors.scoreBogeyBg);
      expect(bogeyColors.text, AppColors.scoreBogeyText);

      // Double Bogey or worse: diff >= 2
      final doubleBogeyColors = getScoreColors(6, 4);
      expect(doubleBogeyColors.bg, AppColors.scoreDoubleWorseBg);
      expect(doubleBogeyColors.text, AppColors.scoreDoubleWorseText);
    });

    test('getScoreColors respects custom scoreType override', () {
      final eagleColors = getScoreColors(5, 5, 'EAGLE');
      expect(eagleColors.bg, AppColors.scoreEagleOrBetterBg);

      final doubleWorseColors = getScoreColors(5, 5, 'DOUBLE_BOGEY_OR_WORSE');
      expect(doubleWorseColors.bg, AppColors.scoreDoubleWorseBg);
    });

    test(
      'getScoreColors handles negative scores (e.g. relation to par directly)',
      () {
        // If score is -1 and par is 0 (relative score), it is Birdie
        final birdieRelative = getScoreColors(-1, 0);
        expect(birdieRelative.bg, AppColors.scoreBirdieBg);
        expect(birdieRelative.text, AppColors.scoreBirdieText);

        // If score is -2 and par is 0 (relative score), it is Eagle
        final eagleRelative = getScoreColors(-2, 0);
        expect(eagleRelative.bg, AppColors.scoreEagleOrBetterBg);
        expect(eagleRelative.text, AppColors.scoreEagleOrBetterText);

        // If score is -3 and par is 0, it is Eagle or better
        final albatrossRelative = getScoreColors(-3, 0);
        expect(albatrossRelative.bg, AppColors.scoreEagleOrBetterBg);
      },
    );
  });

  group('Scorecard Widgets Tests', () {
    late FakeSupabaseClient fakeSupabase;
    late Tournament mockTournament;
    late UserTeam mockTeam;
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

      mockTeam = UserTeam(
        id: 'team-1',
        userId: 'user-1',
        tournamentId: 't-1',
        status: 'ACTIVE',
        golferIds: ['tg-1', 'tg-2', 'tg-3', 'tg-4'],
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
          'teams': [
            {
              'id': 'team-1',
              'user_id': 'mock-user-id',
              'tournament_id': 't-1',
              'status': 'ACTIVE',
            },
          ],
          'team_golfers': [
            {'tournament_golfer_id': 'tg-1'},
            {'tournament_golfer_id': 'tg-2'},
            {'tournament_golfer_id': 'tg-3'},
            {'tournament_golfer_id': 'tg-4'},
          ],
          'team_hole_scores': [
            {
              'team_id': 'team-1',
              'round': 2,
              'hole': 1,
              'par': 4,
              'best_ball_score': 3,
              'hole_to_par': -1,
            },
          ],
          'hole_scores': [
            {
              'id': 'hs-1',
              'tournament_golfer_id': 'tg-1',
              'round': 2,
              'hole': 1,
              'par': 4,
              'score': 3,
              'score_type': 'BIRDIE',
            },
          ],
          'tee_times': [
            {
              'id': 'tt-1',
              'tournament_golfer_id': 'tg-1',
              'round': 2,
              'tee_time_utc': DateTime.now().toUtc().toIso8601String(),
              'start_tee': 1,
              'status': 'SCHEDULED',
            },
          ],
        },
      );
    });

    Widget createScorecardWidget() {
      return ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(fakeSupabase),
          activeTournamentProvider.overrideWith((ref) => mockTournament),
          userTeamProvider.overrideWith((ref) => mockTeam),
          golferListProvider.overrideWith((ref) => mockGolfers),
        ],
        child: const MaterialApp(home: ScorecardScreen()),
      );
    }

    testWidgets('Defaults to active tournament current_round tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createScorecardWidget());
      await tester.pumpAndSettle();

      // Verify that "ROUND 2 SCORECARD" header is shown initially (since currentRound is 2)
      expect(find.text('ROUND 2 SCORECARD'), findsOneWidget);

      // Verify selected tab highlights R2
      final r2Text = find.text('R2');
      expect(r2Text, findsOneWidget);
    });

    testWidgets('Tapping round tab updates round view selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createScorecardWidget());
      await tester.pumpAndSettle();

      expect(find.text('ROUND 2 SCORECARD'), findsOneWidget);

      // Tap Round 3 tab
      final r3Tab = find.text('R3');
      expect(r3Tab, findsOneWidget);
      await tester.tap(r3Tab);
      await tester.pumpAndSettle();

      // View should switch to Round 3
      expect(find.text('ROUND 3 SCORECARD'), findsOneWidget);
    });

    testWidgets(
      'Weather delay banner is visible when tournament is SUSPENDED',
      (WidgetTester tester) async {
        mockTournament = Tournament(
          id: 't-1',
          espnEventId: 'espn-1',
          name: 'The Masters',
          course: 'Augusta National',
          location: 'Augusta, GA',
          par: 72,
          yards: 7400,
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          status: 'SUSPENDED', // Suspended status!
          currentRound: 2,
        );

        await tester.pumpWidget(createScorecardWidget());
        await tester.pumpAndSettle();

        expect(
          find.text('WEATHER DELAY: Play is currently suspended.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Weather delay banner is hidden when tournament is IN_PROGRESS',
      (WidgetTester tester) async {
        await tester.pumpWidget(createScorecardWidget());
        await tester.pumpAndSettle();

        expect(
          find.text('WEATHER DELAY: Play is currently suspended.'),
          findsNothing,
        );
      },
    );

    testWidgets('CUT banner is visible when team status is CUT', (
      WidgetTester tester,
    ) async {
      mockTeam = UserTeam(
        id: 'team-1',
        userId: 'user-1',
        tournamentId: 't-1',
        status: 'CUT', // CUT status!
        golferIds: ['tg-1', 'tg-2', 'tg-3', 'tg-4'],
      );

      await tester.pumpWidget(createScorecardWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('TEAM ELIMINATED: Your team missed the cut.'),
        findsOneWidget,
      );
      expect(
        find.text('TEAM DISQUALIFIED: Your team has been DQ\'d.'),
        findsNothing,
      );
    });

    testWidgets('DQ banner is visible when team status is DQ', (
      WidgetTester tester,
    ) async {
      mockTeam = UserTeam(
        id: 'team-1',
        userId: 'user-1',
        tournamentId: 't-1',
        status: 'DQ', // DQ status!
        golferIds: ['tg-1', 'tg-2', 'tg-3', 'tg-4'],
      );

      await tester.pumpWidget(createScorecardWidget());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'TEAM DISQUALIFIED: Your team has been disqualified for failing to draft a legal roster (incomplete roster or over budget) before the tournament lock time.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('TEAM ELIMINATED: Your team missed the cut.'),
        findsNothing,
      );
    });

    testWidgets('Realtime event updates golfer score live', (
      WidgetTester tester,
    ) async {
      // Initially, mockData has score 3 for Golfer 1 on Hole 1
      await tester.pumpWidget(createScorecardWidget());
      await tester.pumpAndSettle();

      // Find the score cell (score '3')
      expect(find.text('3'), findsAtLeast(1));

      // Trigger a postgres change event simulating a scorecard update (update score to '2', i.e. EAGLE)
      // Retrieve the active realtime channel
      final channels = fakeSupabase.activeChannels;
      expect(channels, isNotEmpty);
      final scorecardChannel = channels.firstWhere(
        (c) => c.name.startsWith('scorecard-realtime'),
      );

      // Let's change the mock data return for next PostgREST fetch so that when invalidation occurs,
      // the new fetch gets the updated score record
      fakeSupabase.mockData['hole_scores'] = [
        {
          'id': 'hs-1',
          'tournament_golfer_id': 'tg-1',
          'round': 2,
          'hole': 1,
          'par': 4,
          'score': 2, // Updated to 2
          'score_type': 'EAGLE',
        },
      ];

      // Trigger change
      scorecardChannel.triggerPostgresChange(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'hole_scores',
        newRecord: {
          'id': 'hs-1',
          'tournament_golfer_id': 'tg-1',
          'round': 2,
          'hole': 1,
          'par': 4,
          'score': 2,
          'score_type': 'EAGLE',
        },
        oldRecord: {
          'id': 'hs-1',
          'tournament_golfer_id': 'tg-1',
          'round': 2,
          'hole': 1,
          'par': 4,
          'score': 3,
          'score_type': 'BIRDIE',
        },
      );

      // Re-pump widget to trigger riverpod invalidation rebuild
      await tester.pump();
      await tester.pumpAndSettle();

      // Score should now be updated to '2'
      expect(find.text('2'), findsAtLeast(1));
    });

    test(
      'SelectedRoundNotifier preserves manual round selection when dependencies update',
      () {
        final container = ProviderContainer(
          overrides: [
            activeTournamentProvider.overrideWith((ref) => mockTournament),
            userTeamProvider.overrideWith((ref) => mockTeam),
          ],
        );
        addTearDown(container.dispose);

        // Read selected round provider, should be 2 (active tournament currentRound is 2)
        expect(container.read(selectedRoundProvider), 2);

        // Manually set to round 1
        container.read(selectedRoundProvider.notifier).setRound(1);
        expect(container.read(selectedRoundProvider), 1);

        // Invalidate userTeamProvider dependency to trigger rebuild
        container.invalidate(userTeamProvider);

        // Read again, should still be 1 (not reset back to 2)
        expect(container.read(selectedRoundProvider), 1);
      },
    );
  });
}
