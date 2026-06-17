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

      // Set active tournament to LOCKED
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
            .subtract(const Duration(minutes: 10))
            .toUtc(), // Lock time passed 10 minutes ago
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

      // Verify that lock time banner is displayed on the dashboard
      expect(
        find.textContaining('Drafting has closed. Roster locked on'),
        findsOneWidget,
      );

      // Verify that DraftPanel shows "ROSTER LOCKED" instead of "Save Team"
      expect(find.text('ROSTER LOCKED'), findsOneWidget);
      expect(find.widgetWithText(BbmButton, 'Save Team'), findsNothing);

      // Verify that GolferTable has no active add buttons
      expect(
        find.descendant(
          of: find.byType(GolferTable),
          matching: find.byIcon(Icons.add_circle_outline),
        ),
        findsNothing,
      );
    });
  });
}
