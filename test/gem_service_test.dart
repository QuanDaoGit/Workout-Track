import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/gem_ledger_entry.dart';
import 'package:workout_track/services/gem_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('balance starts at zero and derives from ledger', () async {
    final service = GemService();

    expect(await service.balance(), 0);
    expect(await service.ledger(), isEmpty);
  });

  test('quest awards are idempotent by claim key', () async {
    final service = GemService();

    final first = await service.awardQuestGems(
      claimKey: 'daily:2026-06-03:show_up',
      amount: 5,
      label: 'Show Up',
      now: DateTime(2026, 6, 3),
    );
    final second = await service.awardQuestGems(
      claimKey: 'daily:2026-06-03:show_up',
      amount: 5,
      label: 'Show Up',
      now: DateTime(2026, 6, 3),
    );

    expect(first, 5);
    expect(second, 0);
    expect(await service.balance(), 5);
    expect(await service.ledger(), hasLength(1));
  });

  test('warm-up awards are idempotent by day key (one per calendar day)', () async {
    final service = GemService();

    final first = await service.awardWarmupGems(
      dayKey: '2026-06-13',
      amount: 10,
      label: 'Warm-up bonus',
      now: DateTime(2026, 6, 13, 8),
    );
    final secondSameDay = await service.awardWarmupGems(
      dayKey: '2026-06-13',
      amount: 10,
      label: 'Warm-up bonus',
      now: DateTime(2026, 6, 13, 20),
    );
    final nextDay = await service.awardWarmupGems(
      dayKey: '2026-06-14',
      amount: 10,
      label: 'Warm-up bonus',
      now: DateTime(2026, 6, 14, 8),
    );

    expect(first, 10);
    expect(secondSameDay, 0);
    expect(nextDay, 10);
    expect(await service.balance(), 20);
    final ledger = await service.ledger();
    expect(ledger.first.sourceKind, GemLedgerSourceKind.warmup);
  });

  test(
    'spending reduces balance and records a negative ledger entry',
    () async {
      final service = GemService();
      await service.awardQuestGems(
        claimKey: 'side:side_first_workout',
        amount: 100,
        label: 'First Forge',
        now: DateTime(2026, 6, 3),
      );

      await service.spendGems(
        sourceId: 'frame_stone',
        amount: 50,
        label: 'Stone Frame',
        now: DateTime(2026, 6, 3, 1),
      );

      final ledger = await service.ledger();
      expect(await service.balance(), 50);
      expect(ledger.last.amount, -50);
      expect(ledger.last.sourceKind, GemLedgerSourceKind.cosmeticPurchase);
    },
  );

  test('demo top-up increases balance and persists source kind', () async {
    final service = GemService();

    final awarded = await service.awardDemoGems(
      packId: 'demo_500',
      amount: 500,
      label: '500 demo gems',
      now: DateTime(2026, 6, 3),
    );

    final ledger = await service.ledger();
    expect(awarded, 500);
    expect(await service.balance(), 500);
    expect(ledger, hasLength(1));
    expect(ledger.single.sourceKind, GemLedgerSourceKind.demoTopUp);
    expect(ledger.single.sourceId, 'demo_500');
  });

  test('spending can use combined quest and demo balance', () async {
    final service = GemService();
    await service.awardQuestGems(
      claimKey: 'daily:show_up',
      amount: 5,
      label: 'Show Up',
    );
    await service.awardDemoGems(
      packId: 'demo_80',
      amount: 80,
      label: '80 demo gems',
    );

    await service.spendGems(
      sourceId: 'frame_stone',
      amount: 50,
      label: 'Stone Frame',
    );

    expect(await service.balance(), 35);
  });

  test('overspend throws and does not mutate ledger', () async {
    final service = GemService();
    await service.awardQuestGems(
      claimKey: 'daily:2026-06-03:show_up',
      amount: 5,
      label: 'Show Up',
    );

    expect(
      () => service.spendGems(
        sourceId: 'frame_gold',
        amount: 1200,
        label: 'Gold Frame',
      ),
      throwsStateError,
    );
    expect(await service.balance(), 5);
    expect(await service.ledger(), hasLength(1));
  });
}
