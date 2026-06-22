import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/services/xp_boost_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('grantPotion', () {
    test('grants and retrieves a potion', () async {
      final now = DateTime(2026, 5, 16, 10, 0);
      final service = XpBoostService(nowProvider: () => now);
      final potion = await service.grantPotion();

      expect(potion.multiplier, 2.0);
      expect(potion.isDirectionBonus, false);
      expect(potion.expiresAt, now.add(const Duration(days: 21)));
      expect(potion.chargesRemaining, 3);

      final active = await service.getActivePotions();
      expect(active.length, 1);
      expect(active.first.id, potion.id);
    });

    test('grants direction bonus potion', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      final potion = await service.grantPotion(directionBonus: true);
      expect(potion.isDirectionBonus, true);
    });
  });

  group('getActivePotions', () {
    test('filters out expired potions', () async {
      var now = DateTime(2026, 5, 16, 10, 0);
      final grantService = XpBoostService(nowProvider: () => now);
      await grantService.grantPotion();

      // 22 days later - potion expired (3-week backstop)
      now = now.add(const Duration(days: 22));
      final laterService = XpBoostService(nowProvider: () => now);
      final active = await laterService.getActivePotions();
      expect(active, isEmpty);
    });
  });

  group('getEffectiveMultiplier', () {
    test('returns 1.0 with no potions', () async {
      final service = XpBoostService(nowProvider: () => DateTime(2026, 5, 16));
      expect(await service.getEffectiveMultiplier(), 1.0);
    });

    test('returns 2.0 with one 2x potion', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion();
      expect(await service.getEffectiveMultiplier(), 2.0);
    });

    test('stacking: two 2x potions = 3.0 effective', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion();
      await service.grantPotion();
      expect(await service.getEffectiveMultiplier(), 3.0);
    });

    test('hard cap at 5.0', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      // Grant 6 potions (would be 7.0 without cap)
      for (var i = 0; i < 6; i++) {
        await service.grantPotion();
      }
      expect(await service.getEffectiveMultiplier(), 5.0);
    });
  });

  group('recordBonusXp', () {
    test('accumulates the lifetime total, ignoring non-positive amounts', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.recordBonusXp(100);
      await service.recordBonusXp(50);
      await service.recordBonusXp(0); // no-op
      await service.recordBonusXp(-10); // no-op
      expect(await service.getTotalBonusXP(), 150);
    });
  });

  group('consumeActivePotions', () {
    test('returns multiplier and does not add legacy bonus XP', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion();

      expect(await service.consumeActivePotions(), 2.0);
      expect(await service.getTotalBonusXP(), 0);
    });

    test('spends one charge per workout, keeping the potion until depleted',
        () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion(); // 3 charges

      // Workout 1: still boosted, 2 charges left.
      expect(await service.consumeActivePotions(), 2.0);
      var active = await service.getActivePotions();
      expect(active.length, 1);
      expect(active.first.chargesRemaining, 2);

      // Workout 2: still boosted, 1 charge left.
      expect(await service.consumeActivePotions(), 2.0);
      active = await service.getActivePotions();
      expect(active.first.chargesRemaining, 1);

      // Workout 3: last charge spent, potion gone.
      expect(await service.consumeActivePotions(), 2.0);
      expect(await service.getActivePotions(), isEmpty);

      // Workout 4: no boost.
      expect(await service.consumeActivePotions(), 1.0);
    });
  });

  group('previewConsume / commitConsume (#11 save ordering)', () {
    test('previewConsume returns the multiplier but does NOT write', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion(); // 3 charges

      final preview = await service.previewConsume();
      expect(preview.multiplier, 2.0);
      // Peek only — a re-read still shows all 3 charges (nothing spent yet), so
      // the session can be saved durably before the charge is committed.
      expect((await service.getActivePotions()).first.chargesRemaining, 3);
    });

    test('commitConsume persists exactly the previewed spend', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion();

      final preview = await service.previewConsume();
      await service.commitConsume(preview.survivors);
      // One charge spent — and the multiplier we stored matches the spend.
      expect(preview.multiplier, 2.0);
      expect((await service.getActivePotions()).first.chargesRemaining, 2);
    });
  });

  group('getTotalBonusXP', () {
    test('starts at 0', () async {
      final service = XpBoostService(nowProvider: () => DateTime(2026, 5, 16));
      expect(await service.getTotalBonusXP(), 0);
    });
  });

  group('getActiveBoostLabel', () {
    test('returns null with no potions', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      expect(await service.getActiveBoostLabel(), isNull);
    });

    test('returns charge-based label with active potion', () async {
      final now = DateTime(2026, 5, 16, 10, 0);
      final service = XpBoostService(nowProvider: () => now);
      await service.grantPotion();

      final label = await service.getActiveBoostLabel();
      expect(label, contains('2x'));
      expect(label, contains('3 WORKOUTS'));
    });

    test('label reflects remaining charges after a workout', () async {
      final now = DateTime(2026, 5, 16, 10, 0);
      final service = XpBoostService(nowProvider: () => now);
      await service.grantPotion();
      await service.consumeActivePotions();

      final label = await service.getActiveBoostLabel();
      expect(label, contains('2 WORKOUTS'));
    });
  });
}
