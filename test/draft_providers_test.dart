import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:best_ball_madness/providers/auth_providers.dart';
import 'package:best_ball_madness/providers/draft_providers.dart';
import 'helpers/fake_supabase.dart';

void main() {
  late ProviderContainer container;
  late FakeSupabaseClient fakeSupabase;

  // Mock Golfer data
  final golfer1 = TournamentGolfer(
    id: 'tg-1',
    tournamentId: 't-1',
    golferProfileId: 'gp-1',
    price: 30.50,
    status: 'ACTIVE',
    profile: GolferProfile(id: 'gp-1', espnId: '1', name: 'Scottie Scheffler'),
  );

  final golfer2 = TournamentGolfer(
    id: 'tg-2',
    tournamentId: 't-1',
    golferProfileId: 'gp-2',
    price: 29.00,
    status: 'ACTIVE',
    profile: GolferProfile(id: 'gp-2', espnId: '2', name: 'Rory McIlroy'),
  );

  final golfer3 = TournamentGolfer(
    id: 'tg-3',
    tournamentId: 't-1',
    golferProfileId: 'gp-3',
    price: 28.00,
    status: 'ACTIVE',
    profile: GolferProfile(id: 'gp-3', espnId: '3', name: 'Jon Rahm'),
  );

  final golfer4 = TournamentGolfer(
    id: 'tg-4',
    tournamentId: 't-1',
    golferProfileId: 'gp-4',
    price: 25.00,
    status: 'ACTIVE',
    profile: GolferProfile(id: 'gp-4', espnId: '4', name: 'Cameron Young'),
  );

  final golfer5 = TournamentGolfer(
    id: 'tg-5',
    tournamentId: 't-1',
    golferProfileId: 'gp-5',
    price: 20.00,
    status: 'ACTIVE',
    profile: GolferProfile(id: 'gp-5', espnId: '5', name: 'Tiger Woods'),
  );

  setUp(() async {
    final mockUser = User(
      id: 'mock-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'test@example.com',
    );
    final mockSession = Session(
      accessToken: 'mock',
      tokenType: 'bearer',
      user: mockUser,
    );

    fakeSupabase = FakeSupabaseClient(
      auth: FakeGoTrueClient(initialSession: mockSession),
      onInsert: (table, row) {
        if (table == 'teams') {
          row['id'] ??= 'team-mock-id';
          row['status'] ??= 'ACTIVE';
        }
        fakeSupabase.mockData[table]?.add(row);
      },
      mockData: {'tournaments': [], 'teams': [], 'team_golfers': []},
    );

    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(fakeSupabase),
        activeTournamentProvider.overrideWith(
          (ref) => Tournament(
            id: 't-1',
            espnEventId: 'espn-1',
            name: 'The Masters',
            course: 'Augusta National',
            location: 'Augusta, GA',
            par: 72,
            yards: 7400,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 3)),
            status: 'IN_PROGRESS',
            currentRound: 1,
          ),
        ),
        userTeamProvider.overrideWith((ref) {
          final teams = fakeSupabase.mockData['teams'] ?? [];
          if (teams.isEmpty) return null;
          final team = teams.first;
          final teamGolfers = fakeSupabase.mockData['team_golfers'] ?? [];
          final golferIds = teamGolfers
              .where((tg) => tg['team_id'] == team['id'])
              .map((tg) => tg['tournament_golfer_id'] as String)
              .toList();
          return UserTeam(
            id: team['id'] as String,
            userId: team['user_id'] as String,
            tournamentId: team['tournament_id'] as String,
            status: team['status'] as String,
            golferIds: golferIds,
            pricesAtDraft: {},
          );
        }),
      ],
    );

    // Warm up the providers so they are resolved to AsyncData before tests run
    container.listen(activeTournamentProvider, (_, _) {});
    container.listen(authSessionProvider, (_, _) {});
    await pumpEventQueue();
  });

  tearDown(() {
    container.dispose();
  });

  test('DraftStateNotifier starts with an empty roster selection', () {
    final state = container.read(draftStateNotifierProvider);
    expect(state, isEmpty);
  });

  test(
    'DraftStateNotifier allows adding a golfer to the roster selection',
    () async {
      final notifier = container.read(draftStateNotifierProvider.notifier);

      await notifier.addGolfer(golfer1);

      final state = container.read(draftStateNotifierProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 'tg-1');
    },
  );

  test('DraftStateNotifier prevents adding the same golfer twice', () async {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    await notifier.addGolfer(golfer1);
    expect(() => notifier.addGolfer(golfer1), throwsException);

    final state = container.read(draftStateNotifierProvider);
    expect(state, hasLength(1));
  });

  test(
    'DraftStateNotifier allows removing a golfer from the roster selection',
    () async {
      final notifier = container.read(draftStateNotifierProvider.notifier);

      await notifier.addGolfer(golfer1);
      await notifier.addGolfer(golfer2);
      expect(container.read(draftStateNotifierProvider), hasLength(2));

      await notifier.removeGolfer(golfer1);
      final state = container.read(draftStateNotifierProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 'tg-2');
    },
  );

  test('DraftStateNotifier enforces roster limit of 4 golfers', () async {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    await notifier.addGolfer(golfer1);
    await notifier.addGolfer(golfer2);
    await notifier.addGolfer(golfer3);
    await notifier.addGolfer(golfer4);

    // 5th golfer should be rejected
    expect(() => notifier.addGolfer(golfer5), throwsException);

    final state = container.read(draftStateNotifierProvider);
    expect(state, hasLength(4));
    expect(state.any((g) => g.id == 'tg-5'), isFalse);
  });

  test(
    'DraftStateNotifier calculates budget correctly when adding/removing',
    () async {
      final notifier = container.read(draftStateNotifierProvider.notifier);

      await notifier.addGolfer(golfer1); // $30.50
      await notifier.addGolfer(golfer2); // $29.00

      double totalSpend = container
          .read(draftStateNotifierProvider)
          .fold<double>(0, (sum, g) => sum + g.price);
      expect(totalSpend, 59.50);
      expect(100.0 - totalSpend, 40.50);

      await notifier.removeGolfer(golfer1);

      totalSpend = container
          .read(draftStateNotifierProvider)
          .fold<double>(0, (sum, g) => sum + g.price);
      expect(totalSpend, 29.00);
      expect(100.0 - totalSpend, 71.00);
    },
  );

  test('DraftStateNotifier clear removes all golfers from selection', () async {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    await notifier.addGolfer(golfer1);
    await notifier.addGolfer(golfer2);
    expect(container.read(draftStateNotifierProvider), isNotEmpty);

    notifier.clear();
    expect(container.read(draftStateNotifierProvider), isEmpty);
  });

  test(
    'GolferProfile parses isAmateur and prior season stats from json correctly',
    () {
      final json = {
        'id': 'gp-test',
        'espn_id': 'test-123',
        'name': 'Amateur Golfer',
        'world_rank': 150,
        'is_amateur': true,
        'scoring_avg': 71.5,
        'wins': 0,
        'top_10s': 1,
        'cuts_made': 2,
        'events_played': 3,
        'rounds_played': 12,
        'prior_scoring_avg': 70.8,
        'prior_wins': 1,
        'prior_top_10s': 2,
        'prior_cuts_made': 4,
        'prior_events_played': 5,
        'prior_rounds_played': 20,
      };

      final profile = GolferProfile.fromJson(json);

      expect(profile.id, 'gp-test');
      expect(profile.isAmateur, isTrue);
      expect(profile.scoringAvg, 71.5);
      expect(profile.priorScoringAvg, 70.8);
      expect(profile.priorWins, 1);
      expect(profile.priorTop10s, 2);
      expect(profile.priorCutsMade, 4);
      expect(profile.priorEventsPlayed, 5);
      expect(profile.priorRoundsPlayed, 20);
    },
  );

  test(
    'DraftStateNotifier throws exception when trying to add or replace with a Withdrawn (WD) golfer',
    () async {
      final notifier = container.read(draftStateNotifierProvider.notifier);

      final golferWd = TournamentGolfer(
        id: 'tg-wd',
        tournamentId: 't-1',
        golferProfileId: 'gp-wd',
        price: 20.00,
        status: 'WD',
        profile: GolferProfile(
          id: 'gp-wd',
          espnId: 'wd',
          name: 'Withdrawn Golfer',
        ),
      );

      // Verify addGolfer throws exception
      expect(() => notifier.addGolfer(golferWd), throwsException);

      // Verify replaceGolfer throws exception
      await notifier.addGolfer(golfer1);
      expect(() => notifier.replaceGolfer(golfer1, golferWd), throwsException);
    },
  );

  group('Weekly Transition Time Logic Tests', () {
    test('Monday is before transition', () {
      // Monday June 29, 2026 at 12:00 PM UTC
      final time = DateTime.utc(2026, 6, 29, 12, 0);
      expect(isBeforeWeeklyTransition(time), isTrue);
    });

    test(
      'Tuesday 5:00 AM EST (10:00 AM UTC in June DST) is before transition',
      () {
        // Tuesday June 30, 2026 at 9:59 AM UTC
        final time = DateTime.utc(2026, 6, 30, 9, 59);
        expect(isBeforeWeeklyTransition(time), isTrue);
      },
    );

    test(
      'Tuesday 7:00 AM EST (11:00 AM UTC in June DST) is after transition',
      () {
        // Tuesday June 30, 2026 at 11:01 AM UTC
        final time = DateTime.utc(2026, 6, 30, 11, 1);
        expect(isBeforeWeeklyTransition(time), isFalse);
      },
    );

    test('Wednesday is after transition', () {
      // Wednesday July 1, 2026 at 12:00 PM UTC
      final time = DateTime.utc(2026, 7, 1, 12, 0);
      expect(isBeforeWeeklyTransition(time), isFalse);
    });

    test('Sunday is after transition', () {
      // Sunday July 5, 2026 at 6:00 PM UTC
      final time = DateTime.utc(2026, 7, 5, 18, 0);
      expect(isBeforeWeeklyTransition(time), isFalse);
    });
  });
}
