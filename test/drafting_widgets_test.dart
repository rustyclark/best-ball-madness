import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:best_ball_madness/providers/draft_providers.dart';
import 'package:best_ball_madness/widgets/draft_panel.dart';
import 'package:best_ball_madness/widgets/golfer_table.dart';
import 'package:best_ball_madness/widgets/tournament_header.dart';
import 'package:best_ball_madness/widgets/empty_state.dart';

void main() {
  // Mock Tournament
  final mockTournament = Tournament(
    id: 't-1',
    espnEventId: 'espn-1',
    name: 'Masters Tournament',
    course: 'Augusta National GC',
    location: 'Augusta, GA',
    par: 72,
    yards: 7475,
    startDate: DateTime(2026, 4, 9),
    endDate: DateTime(2026, 4, 12),
    status: 'SCHEDULED',
    currentRound: 1,
    lockTimeUtc: DateTime.now().add(const Duration(hours: 2)).toUtc(),
  );

  // Mock Golfers
  final golfer1 = TournamentGolfer(
    id: 'tg-1',
    tournamentId: 't-1',
    golferProfileId: 'gp-1',
    price: 30.50,
    status: 'ACTIVE',
    profile: GolferProfile(
      id: 'gp-1',
      espnId: '1',
      name: 'Scottie Scheffler',
      worldRank: 1,
      scoringAvg: 68.2,
      wins: 4,
      top10s: 8,
      cutsMade: 10,
    ),
  );

  final golfer2 = TournamentGolfer(
    id: 'tg-2',
    tournamentId: 't-1',
    golferProfileId: 'gp-2',
    price: 29.00,
    status: 'ACTIVE',
    profile: GolferProfile(
      id: 'gp-2',
      espnId: '2',
      name: 'Rory McIlroy',
      worldRank: 2,
      scoringAvg: 69.1,
      wins: 1,
      top10s: 5,
      cutsMade: 8,
    ),
  );

  final golfer3 = TournamentGolfer(
    id: 'tg-3',
    tournamentId: 't-1',
    golferProfileId: 'gp-3',
    price: 28.00,
    status: 'ACTIVE',
    profile: GolferProfile(
      id: 'gp-3',
      espnId: '3',
      name: 'Jon Rahm',
      worldRank: 5,
      scoringAvg: 69.5,
      wins: 0,
      top10s: 3,
      cutsMade: 6,
    ),
  );

  final golfer4 = TournamentGolfer(
    id: 'tg-4',
    tournamentId: 't-1',
    golferProfileId: 'gp-4',
    price: 25.00,
    status: 'ACTIVE',
    profile: GolferProfile(
      id: 'gp-4',
      espnId: '4',
      name: 'Cameron Young',
      worldRank: 15,
      scoringAvg: 70.1,
      wins: 0,
      top10s: 2,
      cutsMade: 7,
    ),
  );

  final golfer5 = TournamentGolfer(
    id: 'tg-5',
    tournamentId: 't-1',
    golferProfileId: 'gp-5',
    price: 20.00,
    status: 'WD', // Withdrawn golfer
    profile: GolferProfile(
      id: 'gp-5',
      espnId: '5',
      name: 'Tiger Woods',
      worldRank: 120,
      scoringAvg: 72.8,
      wins: 0,
      top10s: 0,
      cutsMade: 1,
    ),
  );

  final mockGolfers = [golfer1, golfer2, golfer3, golfer4, golfer5];

  testWidgets('TournamentHeader renders tournament details when active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTournamentProvider.overrideWith((ref) => mockTournament),
          golferListProvider.overrideWith((ref) => mockGolfers),
        ],
        child: const MaterialApp(home: Scaffold(body: TournamentHeader())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('MASTERS TOURNAMENT'), findsOneWidget);
    expect(find.text('Augusta National GC, Augusta, GA'), findsOneWidget);
    expect(find.text('PAR'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('YARDS'), findsOneWidget);
    expect(find.text('7475'), findsOneWidget);
    expect(find.text('FIELD SIZE'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // 5 mock golfers
  });

  testWidgets(
    'TournamentHeader renders empty state when no active tournament',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeTournamentProvider.overrideWith((ref) => null)],
          child: const MaterialApp(home: Scaffold(body: TournamentHeader())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(BbmEmptyState), findsOneWidget);
      expect(find.text('No Active Tournament'), findsOneWidget);
    },
  );

  testWidgets('DraftPanel enforces count constraint (< 4 golfers)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStateNotifierProvider.overrideWith(
            () => TestDraftStateNotifier([golfer1, golfer2]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DraftPanel(isLocked: false)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify warning
    expect(
      find.text('Roster incomplete! Draft exactly 4 golfers.'),
      findsOneWidget,
    );

    // Save button should be disabled (onPressed is null)
    final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save Team');
    expect(saveButtonFinder, findsOneWidget);
    final ElevatedButton saveButton = tester.widget(saveButtonFinder);
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('DraftPanel enforces budget constraint (> \$100)', (
    WidgetTester tester,
  ) async {
    // Total: 30.50 + 29.00 + 28.00 + 25.00 = $112.50 (> 100)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStateNotifierProvider.overrideWith(
            () => TestDraftStateNotifier([golfer1, golfer2, golfer3, golfer4]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DraftPanel(isLocked: false)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify over-budget warning
    expect(
      find.text('Budget limit of \$100 exceeded! Remove a golfer.'),
      findsOneWidget,
    );

    // Save button should be disabled
    final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save Team');
    final ElevatedButton saveButton = tester.widget(saveButtonFinder);
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('DraftPanel enables save when exactly 4 golfers and <= \$100', (
    WidgetTester tester,
  ) async {
    // Total: 29.00 + 28.00 + 25.00 + 10.00 = 92.00 (<= 100)
    final cheapGolfer = TournamentGolfer(
      id: 'tg-cheap',
      tournamentId: 't-1',
      golferProfileId: 'gp-cheap',
      price: 10.00,
      status: 'ACTIVE',
      profile: GolferProfile(
        id: 'gp-cheap',
        espnId: 'cheap',
        name: 'Cheap Player',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStateNotifierProvider.overrideWith(
            () => TestDraftStateNotifier([
              golfer2,
              golfer3,
              golfer4,
              cheapGolfer,
            ]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DraftPanel(isLocked: false)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // No warning banners should be shown
    expect(
      find.text('Roster incomplete! Draft exactly 4 golfers.'),
      findsNothing,
    );
    expect(
      find.text('Budget limit of \$100 exceeded! Remove a golfer.'),
      findsNothing,
    );

    // Save button should be enabled
    final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save Team');
    final ElevatedButton saveButton = tester.widget(saveButtonFinder);
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('DraftPanel enforces read-only locking post-lock', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStateNotifierProvider.overrideWith(
            () => TestDraftStateNotifier([golfer1, golfer2, golfer3, golfer4]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DraftPanel(isLocked: true), // Locked is true
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should show ROSTER LOCKED container and not show Save Team button
    expect(find.text('ROSTER LOCKED'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Save Team'), findsNothing);

    // Remove buttons should be hidden (no icon button for removal)
    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
  });

  testWidgets('DraftPanel shows alert for pre-lock WD golfer', (
    WidgetTester tester,
  ) async {
    // If a selected golfer is WD, show warning
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStateNotifierProvider.overrideWith(
            () => TestDraftStateNotifier([golfer1, golfer2, golfer3, golfer5]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DraftPanel(isLocked: false)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('A selected golfer has withdrawn (WD)! Please replace them.'),
      findsOneWidget,
    );
  });

  testWidgets('GolferTable renders golfer details and allows adding/sorting', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStateNotifierProvider.overrideWith(
            () => TestDraftStateNotifier([golfer1]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: GolferTable(golfers: mockGolfers, isLocked: false),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Scottie is present and has check circle icon (since selected)
    expect(find.text('Scottie Scheffler'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Verify Rory is present and has add circle outline icon
    expect(find.text('Rory McIlroy'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsAtLeast(1));

    // Verify Tiger Woods is marked WD
    expect(find.text('Tiger Woods'), findsOneWidget);
    expect(find.text('WD'), findsOneWidget);
  });

  testWidgets(
    'GolferTable displays all golfers without pagination and filters by search query',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 5000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final manyGolfers = List.generate(55, (index) {
        return TournamentGolfer(
          id: 'tg-$index',
          tournamentId: 't-1',
          golferProfileId: 'gp-$index',
          price: 20.00,
          status: 'ACTIVE',
          profile: GolferProfile(
            id: 'gp-$index',
            espnId: '$index',
            name: index == 10 ? 'Rory Test' : 'Golfer Name $index',
          ),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 5000,
                child: GolferTable(golfers: manyGolfers, isLocked: false),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify page text (pagination) is NOT present
      expect(find.textContaining('PAGE 1'), findsNothing);

      // Verify first golfer is shown
      expect(find.text('Golfer Name 0'), findsOneWidget);

      // Verify 55th golfer (index 54) is shown since pagination is removed
      expect(find.text('Golfer Name 54'), findsOneWidget);

      // Test Search Filter: Search for 'Rory'
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Rory');
      await tester.pumpAndSettle();

      // 'Rory Test' should still be visible
      expect(find.text('Rory Test'), findsOneWidget);

      // 'Golfer Name 0' should now be hidden
      expect(find.text('Golfer Name 0'), findsNothing);
    },
  );
}

class TestDraftStateNotifier extends DraftStateNotifier {
  final List<TournamentGolfer> initialGolfers;
  TestDraftStateNotifier(this.initialGolfers);

  @override
  List<TournamentGolfer> build() {
    return initialGolfers;
  }
}
