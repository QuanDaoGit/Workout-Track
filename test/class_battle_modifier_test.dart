import 'package:flutter_test/flutter_test.dart';

import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/models/class_battle_carryover.dart';
import 'package:workout_track/services/class_battle_modifier.dart';

void main() {
  const mod = ClassBattleModifier();

  ClassBattleContext makeCtx({
    CharacterClass cls = CharacterClass.bruiser,
    Set<String> abilities = const {},
    ClassBattleCarryover carryover = const ClassBattleCarryover(),
  }) {
    return ClassBattleContext(
      characterClass: cls,
      unlockedAbilities: abilities,
      carryover: carryover,
    );
  }

  group('effectiveCritChance', () {
    test('returns baseLCK when no context', () {
      expect(mod.effectiveCritChance(20, null), 20);
    });

    test('adds carryover crit bonus', () {
      final ctx = makeCtx(
        carryover: const ClassBattleCarryover(nextBattleCritBonus: 10),
      );
      expect(mod.effectiveCritChance(15, ctx), 25);
    });

    test('zero carryover adds nothing', () {
      final ctx = makeCtx();
      expect(mod.effectiveCritChance(30, ctx), 30);
    });
  });

  group('damageMultiplier - Overpower', () {
    test('1.0 when no overpower ability', () {
      final ctx = makeCtx(abilities: {});
      expect(mod.damageMultiplier(3, false, ctx), 1.0);
    });

    test('2.0 on 3rd hit with overpower', () {
      final ctx = makeCtx(abilities: {'bruiser_overpower'});
      expect(mod.damageMultiplier(3, false, ctx), 2.0);
    });

    test('2.0 on 6th hit with overpower', () {
      final ctx = makeCtx(abilities: {'bruiser_overpower'});
      expect(mod.damageMultiplier(6, false, ctx), 2.0);
    });

    test('2.0 on 9th hit with overpower', () {
      final ctx = makeCtx(abilities: {'bruiser_overpower'});
      expect(mod.damageMultiplier(9, false, ctx), 2.0);
    });

    test('1.0 on non-3rd hits', () {
      final ctx = makeCtx(abilities: {'bruiser_overpower'});
      expect(mod.damageMultiplier(1, false, ctx), 1.0);
      expect(mod.damageMultiplier(2, false, ctx), 1.0);
      expect(mod.damageMultiplier(4, false, ctx), 1.0);
    });
  });

  group('damageMultiplier - Iron Tide carryover', () {
    test('applies 1.5x on first hit', () {
      final ctx = makeCtx(
        carryover: const ClassBattleCarryover(nextBattleDamageMult: 1.5),
      );
      expect(mod.damageMultiplier(1, true, ctx), 1.5);
    });

    test('does not apply on non-first hit', () {
      final ctx = makeCtx(
        carryover: const ClassBattleCarryover(nextBattleDamageMult: 1.5),
      );
      expect(mod.damageMultiplier(2, false, ctx), 1.0);
    });

    test('stacks with overpower on 3rd hit if first', () {
      final ctx = makeCtx(
        abilities: {'bruiser_overpower'},
        carryover: const ClassBattleCarryover(nextBattleDamageMult: 1.5),
      );
      // 2.0 * 1.5 = 3.0
      expect(mod.damageMultiplier(3, true, ctx), 3.0);
    });
  });

  group('grantsExtraTurn - Shadow Strike', () {
    test('false when no context', () {
      expect(mod.grantsExtraTurn(true, null), false);
    });

    test('false without ability even on crit', () {
      final ctx = makeCtx(abilities: {});
      expect(mod.grantsExtraTurn(true, ctx), false);
    });

    test('true on crit with Shadow Strike', () {
      final ctx = makeCtx(abilities: {'assassin_shadow_strike'});
      expect(mod.grantsExtraTurn(true, ctx), true);
    });

    test('false on non-crit with Shadow Strike', () {
      final ctx = makeCtx(abilities: {'assassin_shadow_strike'});
      expect(mod.grantsExtraTurn(false, ctx), false);
    });
  });

  group('damageReduction - Iron Will', () {
    test('1.0 when no context', () {
      expect(mod.damageReduction(10, 100, 0, null), 1.0);
    });

    test('1.0 without ability', () {
      final ctx = makeCtx(abilities: {});
      expect(mod.damageReduction(10, 100, 0, ctx), 1.0);
    });

    test('0.5 when HP < 30% and turns < 3', () {
      final ctx = makeCtx(abilities: {'tank_iron_will'});
      // 29 < 30% of 100
      expect(mod.damageReduction(29, 100, 0, ctx), 0.5);
    });

    test('0.5 for turn 1 and 2', () {
      final ctx = makeCtx(abilities: {'tank_iron_will'});
      expect(mod.damageReduction(20, 100, 1, ctx), 0.5);
      expect(mod.damageReduction(20, 100, 2, ctx), 0.5);
    });

    test('1.0 after 3 turns active', () {
      final ctx = makeCtx(abilities: {'tank_iron_will'});
      expect(mod.damageReduction(20, 100, 3, ctx), 1.0);
    });

    test('1.0 when HP > 30%', () {
      final ctx = makeCtx(abilities: {'tank_iron_will'});
      // 31 > floor(100*0.3) = 30, so no DR
      expect(mod.damageReduction(31, 100, 0, ctx), 1.0);
      expect(mod.damageReduction(50, 100, 0, ctx), 1.0);
    });
  });

  group('survivesKillingBlow - Last Stand', () {
    test('false when no context', () {
      expect(mod.survivesKillingBlow(false, null), false);
    });

    test('false without ability', () {
      final ctx = makeCtx(abilities: {});
      expect(mod.survivesKillingBlow(false, ctx), false);
    });

    test('true with Last Stand and not used', () {
      final ctx = makeCtx(abilities: {'tank_last_stand'});
      expect(mod.survivesKillingBlow(false, ctx), true);
    });

    test('false when already used', () {
      final ctx = makeCtx(abilities: {'tank_last_stand'});
      expect(mod.survivesKillingBlow(true, ctx), false);
    });
  });

  group('hpRestoredOnKill - Phantom Edge', () {
    test('0 when no context', () {
      expect(mod.hpRestoredOnKill(200, null), 0);
    });

    test('0 without ability', () {
      final ctx = makeCtx(abilities: {});
      expect(mod.hpRestoredOnKill(200, ctx), 0);
    });

    test('25% of maxHp with Phantom Edge', () {
      final ctx = makeCtx(abilities: {'assassin_phantom_edge'});
      expect(mod.hpRestoredOnKill(200, ctx), 50);
      expect(mod.hpRestoredOnKill(100, ctx), 25);
    });
  });

  group('postBattleCarryover', () {
    test('empty when no context', () {
      final result = mod.postBattleCarryover(true, true, null);
      expect(result.nextBattleCritBonus, 0);
      expect(result.nextBattleDamageMult, 1.0);
      expect(result.bruiserBattleWinCounter, 0);
    });

    test('Phantom Edge grants +10 crit on kill', () {
      final ctx = makeCtx(abilities: {'assassin_phantom_edge'});
      final result = mod.postBattleCarryover(true, true, ctx);
      expect(result.nextBattleCritBonus, 10);
    });

    test('Phantom Edge no bonus if enemy not killed', () {
      final ctx = makeCtx(abilities: {'assassin_phantom_edge'});
      final result = mod.postBattleCarryover(true, false, ctx);
      expect(result.nextBattleCritBonus, 0);
    });

    test('Iron Tide increments win counter on win', () {
      final ctx = makeCtx(
        abilities: {'bruiser_iron_tide'},
        carryover: const ClassBattleCarryover(bruiserBattleWinCounter: 3),
      );
      final result = mod.postBattleCarryover(true, true, ctx);
      expect(result.bruiserBattleWinCounter, 4);
      expect(result.nextBattleDamageMult, 1.0);
    });

    test('Iron Tide triggers +50% on 5th win', () {
      final ctx = makeCtx(
        abilities: {'bruiser_iron_tide'},
        carryover: const ClassBattleCarryover(bruiserBattleWinCounter: 4),
      );
      final result = mod.postBattleCarryover(true, true, ctx);
      expect(result.bruiserBattleWinCounter, 0);
      expect(result.nextBattleDamageMult, 1.5);
    });

    test('Iron Tide preserves counter on loss', () {
      final ctx = makeCtx(
        abilities: {'bruiser_iron_tide'},
        carryover: const ClassBattleCarryover(bruiserBattleWinCounter: 3),
      );
      final result = mod.postBattleCarryover(false, false, ctx);
      expect(result.bruiserBattleWinCounter, 3);
    });
  });
}
