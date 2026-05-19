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
      expect(potion.expiresAt, now.add(const Duration(hours: 24)));

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

      // 25 hours later - potion expired
      now = now.add(const Duration(hours: 25));
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

  group('consumeForSession', () {
    test('returns correct bonus XP', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion(); // 2x

      final bonusXP = await service.consumeForSession(100);
      expect(bonusXP, 100); // 100 * 2.0 - 100 = 100
    });

    test('returns 0 with no active potions', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      final bonusXP = await service.consumeForSession(100);
      expect(bonusXP, 0);
    });

    test('removes consumed potions after use', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion();
      await service.consumeForSession(100);

      final active = await service.getActivePotions();
      expect(active, isEmpty);
    });

    test('running total accumulates across sessions', () async {
      final service = XpBoostService(
        nowProvider: () => DateTime(2026, 5, 16, 10, 0),
      );
      await service.grantPotion();
      await service.consumeForSession(100); // bonus: 100

      // Grant another potion and consume again
      await service.grantPotion();
      await service.consumeForSession(50); // bonus: 50

      expect(await service.getTotalBonusXP(), 150);
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

    test('returns formatted label with active potion', () async {
      final now = DateTime(2026, 5, 16, 10, 0);
      final service = XpBoostService(nowProvider: () => now);
      await service.grantPotion();

      // Check 6 hours later
      final laterService = XpBoostService(
        nowProvider: () => now.add(const Duration(hours: 6)),
      );
      final label = await laterService.getActiveBoostLabel();
      expect(label, contains('2x'));
      expect(label, contains('18h LEFT'));
    });
  });
}
