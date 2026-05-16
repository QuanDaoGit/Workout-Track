import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/loot_registry.dart';
import 'package:workout_track/models/enemy_data.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/services/battle_engine.dart';
import 'package:workout_track/services/battle_scheduler.dart';
import 'package:workout_track/services/loot_service.dart';
import 'package:workout_track/services/stat_engine.dart';

void main() {
  late DateTime fixedNow;

  setUp(() {
    fixedNow = DateTime(2026, 5, 15, 12);
    SharedPreferences.setMockInitialValues({});
  });

  LootService service({bool unlockAllLoot = false}) =>
      LootService(nowProvider: () => fixedNow, unlockAllLoot: unlockAllLoot);

  BattleResult battleResult({int floor = 1, bool won = true}) {
    return BattleResult(
      playerWon: won,
      isDraw: false,
      rounds: const [],
      playerHpRemaining: won ? 100 : 0,
      enemyHpRemaining: won ? 0 : 100,
      playerHpMax: 100,
      enemyHpMax: 100,
      floor: floor,
      enemy: const EnemyData(
        id: 'test',
        name: 'Test Enemy',
        tier: 1,
        baseSTR: 10,
        baseDEF: 10,
        baseVIT: 10,
        baseAGI: 10,
      ),
      timestamp: fixedNow,
    );
  }

  test('default owned items load correctly', () async {
    final inventory = await service().getInventory();
    final ids = inventory.map((item) => item.id).toSet();

    expect(
      ids,
      containsAll(['title_recruit', 'theme_default', 'effect_default']),
    );
    expect(inventory.length, 3);
  });

  test('test build can unlock every loot item by default', () async {
    final inventory = await LootService(
      nowProvider: () => fixedNow,
    ).getInventory();
    final ids = inventory.map((item) => item.id).toSet();

    expect(ids, lootRegistry.map((item) => item.id).toSet());
    expect(inventory.length, lootRegistry.length);
  });

  test('normal drop is deterministic for floor and day', () {
    final first = service().rollNormalDrop(7);
    final second = service().rollNormalDrop(7);

    expect(second.id, first.id);
  });

  test('rarity weighting selects items from matching rarity pools', () {
    for (final rarity in LootRarity.values) {
      LootItem? found;
      for (var floor = 1; floor < 500; floor++) {
        final item = service().rollNormalDrop(floor);
        if (item.rarity == rarity) {
          found = item;
          break;
        }
      }

      expect(found, isNotNull);
      expect(found!.rarity, rarity);
      expect(found.bossExclusive, isFalse);
      expect(found.isDefault, isFalse);
    }
  });

  test('boss floors return guaranteed boss-exclusive drops', () {
    expect(service().getBossDrop(10).id, 'frame_gold');
    expect(service().getBossDrop(20).id, 'title_golem_breaker');
    expect(service().getBossDrop(30).id, 'title_wraith_hunter');
    expect(service().getBossDrop(40).id, 'frame_inferno');
    expect(service().getBossDrop(50).id, 'title_floor_master');
    expect(service().getBossDrop(10).bossExclusive, isTrue);
  });

  test('duplicates award scrap', () async {
    final item = lootItemById('title_recruit')!;
    final result = await service().claimLoot(item);

    expect(result.isDuplicate, isTrue);
    expect(result.scrapAwarded, item.rarity.scrapValue);
    expect(await service().getScrapBalance(), item.rarity.scrapValue);
  });

  test(
    'purchases spend scrap and reject insufficient scrap or boss items',
    () async {
      SharedPreferences.setMockInitialValues({'loot_scrap_balance': 120});
      final richService = service();

      final bought = await richService.purchaseWithScrap('frame_neon');
      expect(bought.item.id, 'frame_neon');
      expect(await richService.getScrapBalance(), 0);

      expect(richService.purchaseWithScrap('effect_solar'), throwsStateError);
      expect(richService.purchaseWithScrap('frame_gold'), throwsStateError);
    },
  );

  test('equipped loot persists by category', () async {
    SharedPreferences.setMockInitialValues({
      'loot_inventory': [...defaultLootIds, 'frame_neon'],
    });
    final first = service();
    await first.equipItem('frame_neon');

    final second = service();
    final equipped = await second.getEquippedLoot();
    expect(equipped[LootCategory.avatarFrame]?.id, 'frame_neon');
  });

  test('unclaimed loot survives reload and claims once', () async {
    final first = service();
    final prepared = await first.prepareLootForBattle(battleResult(floor: 1));

    final second = service();
    final reloaded = await second.getUnclaimedLoot();
    expect(reloaded?.item.id, prepared.item.id);

    final claimed = await second.claimUnclaimedLoot();
    expect(claimed?.item.id, prepared.item.id);
    expect(await second.getUnclaimedLoot(), isNull);
    expect(await second.claimUnclaimedLoot(), isNull);
  });

  test('battle win prepares unclaimed loot but loss does not', () async {
    final weakEnemy = const EnemyData(
      id: 'weak',
      name: 'Weak',
      tier: 1,
      baseSTR: 1,
      baseDEF: 1,
      baseVIT: 1,
      baseAGI: 1,
    );
    final pending = PendingBattle(
      enemy: weakEnemy,
      floor: 1,
      scheduledTime: fixedNow.subtract(const Duration(hours: 1)),
    );
    SharedPreferences.setMockInitialValues({
      'pending_battle': jsonEncode(pending.toJson()),
      StatEngine.combatStatsKey: jsonEncode({
        'STR': 1000,
        'DEF': 1000,
        'VIT': 1000,
        'AGI': 1000,
        'LCK': 40,
      }),
    });

    final win = await BattleScheduler().resolveBattle();
    expect(win.playerWon, isTrue);
    expect(await service().getUnclaimedLoot(), isNotNull);

    final strongEnemy = const EnemyData(
      id: 'strong',
      name: 'Strong',
      tier: 3,
      baseSTR: 1000,
      baseDEF: 1000,
      baseVIT: 1000,
      baseAGI: 1000,
    );
    final losingPending = PendingBattle(
      enemy: strongEnemy,
      floor: 1,
      scheduledTime: fixedNow.subtract(const Duration(hours: 1)),
    );
    SharedPreferences.setMockInitialValues({
      'pending_battle': jsonEncode(losingPending.toJson()),
      StatEngine.combatStatsKey: jsonEncode({
        'STR': 0,
        'DEF': 0,
        'VIT': 0,
        'AGI': 0,
        'LCK': 0,
      }),
    });

    final loss = await BattleScheduler().resolveBattle();
    expect(loss.playerWon, isFalse);
    expect(await service().getUnclaimedLoot(), isNull);
  });
}
