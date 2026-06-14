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
}
