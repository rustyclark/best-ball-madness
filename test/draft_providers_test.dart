import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:best_ball_madness/providers/draft_providers.dart';

void main() {
  late ProviderContainer container;

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

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('DraftStateNotifier starts with an empty roster selection', () {
    final state = container.read(draftStateNotifierProvider);
    expect(state, isEmpty);
  });

  test('DraftStateNotifier allows adding a golfer to the roster selection', () {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    final success = notifier.addGolfer(golfer1);
    expect(success, isTrue);

    final state = container.read(draftStateNotifierProvider);
    expect(state, hasLength(1));
    expect(state.first.id, 'tg-1');
  });

  test('DraftStateNotifier prevents adding the same golfer twice', () {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    notifier.addGolfer(golfer1);
    final success = notifier.addGolfer(golfer1);
    expect(success, isFalse);

    final state = container.read(draftStateNotifierProvider);
    expect(state, hasLength(1));
  });

  test(
    'DraftStateNotifier allows removing a golfer from the roster selection',
    () {
      final notifier = container.read(draftStateNotifierProvider.notifier);

      notifier.addGolfer(golfer1);
      notifier.addGolfer(golfer2);
      expect(container.read(draftStateNotifierProvider), hasLength(2));

      notifier.removeGolfer(golfer1);
      final state = container.read(draftStateNotifierProvider);
      expect(state, hasLength(1));
      expect(state.first.id, 'tg-2');
    },
  );

  test('DraftStateNotifier enforces roster limit of 4 golfers', () {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    expect(notifier.addGolfer(golfer1), isTrue);
    expect(notifier.addGolfer(golfer2), isTrue);
    expect(notifier.addGolfer(golfer3), isTrue);
    expect(notifier.addGolfer(golfer4), isTrue);

    // 5th golfer should be rejected
    expect(notifier.addGolfer(golfer5), isFalse);

    final state = container.read(draftStateNotifierProvider);
    expect(state, hasLength(4));
    expect(state.any((g) => g.id == 'tg-5'), isFalse);
  });

  test(
    'DraftStateNotifier calculates budget correctly when adding/removing',
    () {
      final notifier = container.read(draftStateNotifierProvider.notifier);

      notifier.addGolfer(golfer1); // $30.50
      notifier.addGolfer(golfer2); // $29.00

      double totalSpend = container
          .read(draftStateNotifierProvider)
          .fold<double>(0, (sum, g) => sum + g.price);
      expect(totalSpend, 59.50);
      expect(100.0 - totalSpend, 40.50);

      notifier.removeGolfer(golfer1);

      totalSpend = container
          .read(draftStateNotifierProvider)
          .fold<double>(0, (sum, g) => sum + g.price);
      expect(totalSpend, 29.00);
      expect(100.0 - totalSpend, 71.00);
    },
  );

  test('DraftStateNotifier clear removes all golfers from selection', () {
    final notifier = container.read(draftStateNotifierProvider.notifier);

    notifier.addGolfer(golfer1);
    notifier.addGolfer(golfer2);
    expect(container.read(draftStateNotifierProvider), isNotEmpty);

    notifier.clear();
    expect(container.read(draftStateNotifierProvider), isEmpty);
  });

  test('GolferProfile parses isAmateur and prior season stats from json correctly', () {
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
  });
}
