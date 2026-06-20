import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:best_ball_madness/main.dart';
import 'package:best_ball_madness/providers/auth_providers.dart';
import 'package:best_ball_madness/providers/draft_providers.dart';
import 'package:best_ball_madness/screens/auth/auth_screen.dart';
import 'package:best_ball_madness/screens/auth/setup_team_screen.dart';
import 'package:best_ball_madness/screens/dashboard/dashboard_screen.dart';
import 'package:best_ball_madness/widgets/button.dart';
import 'package:best_ball_madness/widgets/draft_panel.dart';
import 'package:best_ball_madness/widgets/golfer_table.dart';
import 'package:best_ball_madness/widgets/team_scorecard.dart';
import 'helpers/fake_supabase.dart';

void main() {
  group('Best Ball Madness — Complete Integration Flow Tests', () {
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
        currentRound: 1,
        lockTimeUtc: DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc(), // Not locked yet
      );

      mockGolfers = [
        TournamentGolfer(
          id: 'tg-1',
          tournamentId: 't-1',
          golferProfileId: 'gp-1',
          price: 25.0,
          status: 'ACTIVE',
          profile: GolferProfile(
            id: 'gp-1',
            espnId: '1',
            name: 'Scottie Scheffler',
            worldRank: 1,
            scoringAvg: 68.2,
          ),
        ),
        TournamentGolfer(
          id: 'tg-2',
          tournamentId: 't-1',
          golferProfileId: 'gp-2',
          price: 25.0,
          status: 'ACTIVE',
          profile: GolferProfile(
            id: 'gp-2',
            espnId: '2',
            name: 'Rory McIlroy',
            worldRank: 2,
            scoringAvg: 69.0,
          ),
        ),
        TournamentGolfer(
          id: 'tg-3',
          tournamentId: 't-1',
          golferProfileId: 'gp-3',
          price: 25.0,
          status: 'ACTIVE',
          profile: GolferProfile(
            id: 'gp-3',
            espnId: '3',
            name: 'Jon Rahm',
            worldRank: 3,
            scoringAvg: 69.5,
          ),
        ),
        TournamentGolfer(
          id: 'tg-4',
          tournamentId: 't-1',
          golferProfileId: 'gp-4',
          price: 25.0,
          status: 'ACTIVE',
          profile: GolferProfile(
            id: 'gp-4',
            espnId: '4',
            name: 'Cameron Young',
            worldRank: 10,
            scoringAvg: 70.0,
          ),
        ),
      ];

      fakeSupabase = FakeSupabaseClient(
        onInsert: (table, row) {
          if (table == 'users') {
            row['created_at'] = DateTime.now().toIso8601String();
          }
          if (table == 'teams') {
            row['id'] ??= 'team-mock-id';
            row['status'] ??= 'ACTIVE';
          }
          fakeSupabase.mockData[table]?.add(row);
        },
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
              'current_round': 1,
              'lock_time_utc': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
            },
          ],
          'tournament_golfers': [
            {
              'id': 'tg-1',
              'tournament_id': 't-1',
              'golfer_profile_id': 'gp-1',
              'price': 25.0,
              'status': 'ACTIVE',
              'golfer_profiles': {
                'id': 'gp-1',
                'espn_id': '1',
                'name': 'Scottie Scheffler',
                'world_rank': 1,
                'scoring_avg': 68.2,
              },
            },
            {
              'id': 'tg-2',
              'tournament_id': 't-1',
              'golfer_profile_id': 'gp-2',
              'price': 25.0,
              'status': 'ACTIVE',
              'golfer_profiles': {
                'id': 'gp-2',
                'espn_id': '2',
                'name': 'Rory McIlroy',
                'world_rank': 2,
                'scoring_avg': 69.0,
              },
            },
            {
              'id': 'tg-3',
              'tournament_id': 't-1',
              'golfer_profile_id': 'gp-3',
              'price': 25.0,
              'status': 'ACTIVE',
              'golfer_profiles': {
                'id': 'gp-3',
                'espn_id': '3',
                'name': 'Jon Rahm',
                'world_rank': 3,
                'scoring_avg': 69.5,
              },
            },
            {
              'id': 'tg-4',
              'tournament_id': 't-1',
              'golfer_profile_id': 'gp-4',
              'price': 25.0,
              'status': 'ACTIVE',
              'golfer_profiles': {
                'id': 'gp-4',
                'espn_id': '4',
                'name': 'Cameron Young',
                'world_rank': 10,
                'scoring_avg': 70.0,
              },
            },
          ],
          'users': [],
          'teams': [],
          'team_golfers': [],
        },
      );
    });

    Widget buildTestApp() {
      return ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(fakeSupabase),
          activeTournamentProvider.overrideWith((ref) => mockTournament),
          golferListProvider.overrideWith((ref) => mockGolfers),
        ],
        child: const MyApp(),
      );
    }

    testWidgets(
      'Complete user flow: Sign Up -> Setup Team -> Draft -> Save Team -> Logout',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. App starts on AuthScreen (since no auth session exists)
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(AuthScreen), findsOneWidget);
        expect(find.text('LOGIN'), findsOneWidget);

        // Tap Sign Up link to toggle to register mode
        await tester.tap(find.text('Sign Up').last);
        await tester.pumpAndSettle();
        expect(find.text('REGISTER'), findsOneWidget);

        // Enters email and password
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'testuser@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'password123',
        );
        await tester.pumpAndSettle();

        // Tap the action button to submit sign up
        await tester.tap(find.widgetWithText(BbmButton, 'Sign Up'));
        // Wait for async auth actions to complete
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 2. Since User profile is empty, NavigationSwitcher routes to SetupTeamScreen
        expect(find.byType(SetupTeamScreen), findsOneWidget);

        // Type team name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Team Name'),
          'Birde Masters',
        );
        await tester.pumpAndSettle();

        // Tap Create Team
        await tester.tap(find.widgetWithText(BbmButton, 'Create Team'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 3. User profile exists now, routes to DashboardScreen
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.text('BIRDE MASTERS'), findsOneWidget);

        // 4. Draft Roster Flow
        // Open DraftPanel should show empty roster slots initially
        expect(find.byType(DraftPanel), findsOneWidget);
        expect(find.text('Empty Slot'), findsNWidgets(4));

        // Select golfers in GolferTable
        // We will tap the add button for Scottie Scheffler, Rory McIlroy, Jon Rahm, and Cameron Young
        final addButtons = find.descendant(
          of: find.byType(GolferTable),
          matching: find.byIcon(Icons.add_circle_outline),
        );
        expect(addButtons, findsNWidgets(4)); // all 4 are available

        // Tap add for all 4 golfers
        for (int i = 0; i < 4; i++) {
          final firstAddBtn = find
              .descendant(
                of: find.byType(GolferTable),
                matching: find.byIcon(Icons.add_circle_outline),
              )
              .first;
          await tester.ensureVisible(firstAddBtn);
          await tester.pumpAndSettle();
          await tester.tap(firstAddBtn);
          await tester.pumpAndSettle();
        }

        // Draft panel should now show no empty slots and have the Save Team button active
        expect(find.text('Empty Slot'), findsNothing);
        final saveBtn = find.widgetWithText(BbmButton, 'Save Team');
        expect(saveBtn, findsOneWidget);

        // Save the team
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 5. Logout Flow
        // Tap logout icon in Dashboard screen AppBar
        await tester.tap(find.byIcon(Icons.logout));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Verify returned back to AuthScreen
        expect(find.byType(AuthScreen), findsOneWidget);
      },
    );

    testWidgets('Post-Lock behavior: Roster modifications are blocked', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Set active tournament to COMPLETED (representing locked roster post-tournament)
      mockTournament = Tournament(
        id: 't-1',
        espnEventId: 'espn-1',
        name: 'The Masters',
        course: 'Augusta National',
        location: 'Augusta, GA',
        par: 72,
        yards: 7400,
        startDate: DateTime.now().subtract(const Duration(days: 4)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        status: 'COMPLETED',
        currentRound: 4,
        lockTimeUtc: DateTime.now().subtract(const Duration(days: 4)).toUtc(),
      );

      // Set user profile as already created
      fakeSupabase.mockData['users'] = [
        {
          'id': 'mock-user-id',
          'email': 'testuser@example.com',
          'team_name': 'Locked Masters',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      // Emit active session in fake GoTrue client
      final mockUser = User(
        id: 'mock-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'testuser@example.com',
      );
      fakeSupabase.fakeAuth.emitSession(
        Session(
          accessToken: 'mock-access-token',
          tokenType: 'bearer',
          user: mockUser,
        ),
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Screen should directly load Dashboard Screen
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Verify that TeamScorecard is visible instead of DraftPanel
      expect(find.byType(TeamScorecard), findsOneWidget);
      expect(find.byType(DraftPanel), findsNothing);
      expect(find.text('ACTIVE GOLFERS'), findsOneWidget);
      expect(find.text('TEAM SCORE'), findsOneWidget);
    });

    testWidgets(
      'Dashboard stats area shows correct active/remaining golfers count when some miss the cut',
      (WidgetTester tester) async {
        // Set active tournament to IN_PROGRESS and locked
        mockTournament = Tournament(
          id: 't-1',
          espnEventId: 'espn-1',
          name: 'The Masters',
          course: 'Augusta National',
          location: 'Augusta, GA',
          par: 72,
          yards: 7400,
          startDate: DateTime.now().subtract(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 1)),
          status: 'IN_PROGRESS',
          currentRound: 3,
          lockTimeUtc: DateTime.now()
              .subtract(const Duration(hours: 5))
              .toUtc(), // Locked
        );

        // 2 golfers missed the cut (status MC)
        // 2 golfers are active (status ACTIVE)
        mockGolfers = [
          TournamentGolfer(
            id: 'tg-1',
            tournamentId: 't-1',
            golferProfileId: 'gp-1',
            price: 25.0,
            status: 'MC', // Missed Cut
            profile: GolferProfile(
              id: 'gp-1',
              espnId: '1',
              name: 'Scottie Scheffler',
            ),
          ),
          TournamentGolfer(
            id: 'tg-2',
            tournamentId: 't-1',
            golferProfileId: 'gp-2',
            price: 24.0,
            status: 'MC', // Missed Cut
            profile: GolferProfile(
              id: 'gp-2',
              espnId: '2',
              name: 'Rory McIlroy',
            ),
          ),
          TournamentGolfer(
            id: 'tg-3',
            tournamentId: 't-1',
            golferProfileId: 'gp-3',
            price: 23.0,
            status: 'ACTIVE',
            profile: GolferProfile(id: 'gp-3', espnId: '3', name: 'Jon Rahm'),
          ),
          TournamentGolfer(
            id: 'tg-4',
            tournamentId: 't-1',
            golferProfileId: 'gp-4',
            price: 22.0,
            status: 'ACTIVE',
            profile: GolferProfile(
              id: 'gp-4',
              espnId: '4',
              name: 'Cameron Young',
            ),
          ),
        ];

        // Roster is saved with these 4 golfers
        fakeSupabase.mockData['teams'] = [
          {
            'id': 'team-1',
            'user_id': 'mock-user-id',
            'tournament_id': 't-1',
            'status': 'ACTIVE',
          },
        ];
        fakeSupabase.mockData['team_golfers'] = [
          {'tournament_golfer_id': 'tg-1'},
          {'tournament_golfer_id': 'tg-2'},
          {'tournament_golfer_id': 'tg-3'},
          {'tournament_golfer_id': 'tg-4'},
        ];

        // Initially load Round 3 mock data
        fakeSupabase.mockData['hole_scores'] = [
          {
            'id': 'hs-1',
            'tournament_golfer_id': 'tg-3', // Jon Rahm
            'round': 3,
            'hole': 1,
            'par': 4,
            'score': 4,
            'score_type': 'PAR',
          },
        ];

        fakeSupabase.mockData['tee_times'] = [
          {
            'id': 'tt-1',
            'tournament_golfer_id': 'tg-1',
            'round': 3,
            'tee_time_utc': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'MC',
          },
          {
            'id': 'tt-2',
            'tournament_golfer_id': 'tg-2',
            'round': 3,
            'tee_time_utc': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'MC',
          },
          {
            'id': 'tt-3',
            'tournament_golfer_id': 'tg-3',
            'round': 3,
            'tee_time_utc': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'ACTIVE',
          },
          {
            'id': 'tt-4',
            'tournament_golfer_id': 'tg-4',
            'round': 3,
            'tee_time_utc': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(), // In the future
            'start_tee': 1,
            'status': 'ACTIVE',
          },
        ];

        fakeSupabase.mockData['users'] = [
          {
            'id': 'mock-user-id',
            'email': 'testuser@example.com',
            'team_name': 'Locked Masters',
            'created_at': DateTime.now().toIso8601String(),
          },
        ];

        final mockUser = User(
          id: 'mock-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'testuser@example.com',
        );
        fakeSupabase.fakeAuth.emitSession(
          Session(
            accessToken: 'mock-access-token',
            tokenType: 'bearer',
            user: mockUser,
          ),
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.text('ACTIVE GOLFERS'), findsOneWidget);

        // Numerator should be 1 (Jon Rahm teed off), Denominator should be 2 (Jon Rahm & Cameron Young remaining)
        expect(find.text('1 / 2'), findsOneWidget);

        // Update the mock data to switch to Round 2 values before tapping tab
        fakeSupabase.mockData['hole_scores'] = [
          {
            'id': 'hs-2',
            'tournament_golfer_id': 'tg-1', // Scottie Scheffler teed off
            'round': 2,
            'hole': 1,
            'par': 4,
            'score': 4,
            'score_type': 'PAR',
          },
        ];

        fakeSupabase.mockData['tee_times'] = [
          {
            'id': 'tt-2-1',
            'tournament_golfer_id': 'tg-1',
            'round': 2,
            'tee_time_utc': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'ACTIVE',
          },
          {
            'id': 'tt-2-2',
            'tournament_golfer_id': 'tg-2',
            'round': 2,
            'tee_time_utc': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'ACTIVE',
          },
          {
            'id': 'tt-2-3',
            'tournament_golfer_id': 'tg-3',
            'round': 2,
            'tee_time_utc': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'ACTIVE',
          },
          {
            'id': 'tt-2-4',
            'tournament_golfer_id': 'tg-4',
            'round': 2,
            'tee_time_utc': DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'start_tee': 1,
            'status': 'ACTIVE',
          },
        ];

        // Tap the R2 tab on the scorecard to switch to Round 2
        final r2Tab = find.text('R2');
        expect(r2Tab, findsOneWidget);
        await tester.tap(r2Tab);
        await tester.pumpAndSettle();

        // Numerator should be 1 (Scottie Scheffler teed off), Denominator should be 4 (all golfers remaining in Round 2)
        expect(find.text('1 / 4'), findsOneWidget);
      },
    );
  });
}
