import 'package:flutter_test/flutter_test.dart';

import 'package:workout_track/models/enemy_data.dart';
import 'package:workout_track/services/battle_engine.dart';

void main() {
  final weakEnemy = const EnemyData(
    id: 'shadow_rat',
    name: 'Shadow Rat',
    tier: 1,
    baseSTR: 20,
    baseDEF: 10,
    baseVIT: 15,
    baseAGI: 0,
  );

  final strongEnemy = const EnemyData(
    id: 'wraith_knight',
    name: 'Wraith Knight',
    tier: 3,
    baseSTR: 999,
    baseDEF: 999,
    baseVIT: 500,
    baseAGI: 0,
  );

  final tankEnemy = const EnemyData(
    id: 'iron_golem',
    name: 'Iron Golem',
    tier: 2,
    baseSTR: 1,
    baseDEF: 9999,
    baseVIT: 9999,
    baseAGI: 0,
  );

  test('player with high stats beats low-floor enemy', () {
    final result = BattleEngine().resolve(BattleInput(
      playerStats: {'STR': 500, 'DEF': 400, 'VIT': 400, 'AGI': 0, 'LCK': 0},
      enemy: weakEnemy,
      floor: 1,
    ));
    expect(result.playerWon, isTrue);
    expect(result.isDraw, isFalse);
    expect(result.enemyHpRemaining, 0);
    expect(result.playerHpRemaining, greaterThan(0));
  });

  test('player with low stats loses to high-floor enemy', () {
    final result = BattleEngine().resolve(BattleInput(
      playerStats: {'STR': 50, 'DEF': 50, 'VIT': 50, 'AGI': 0, 'LCK': 0},
      enemy: strongEnemy,
      floor: 50,
    ));
    expect(result.playerWon, isFalse);
    expect(result.playerHpRemaining, 0);
  });

  test('draw after 20 rounds when neither side can kill', () {
    // Both sides deal ~0 damage due to massive DEF.
    final result = BattleEngine().resolve(BattleInput(
      playerStats: {'STR': 50, 'DEF': 9999, 'VIT': 9999, 'AGI': 0, 'LCK': 0},
      enemy: tankEnemy,
      floor: 1,
    ));
    expect(result.isDraw, isTrue);
    expect(result.playerWon, isFalse);
    expect(result.rounds.length, BattleEngine.maxRounds);
    expect(result.playerHpRemaining, greaterThan(0));
    expect(result.enemyHpRemaining, greaterThan(0));
  });

  test('crit multiplier applies correctly', () {
    // 100 LCK = always crit. Verify damage is doubled.
    final withCrit = BattleEngine().resolve(BattleInput(
      playerStats: {'STR': 200, 'DEF': 9999, 'VIT': 200, 'AGI': 0, 'LCK': 100},
      enemy: weakEnemy,
      floor: 1,
    ));

    // Check that at least one crit event exists.
    final critEvents = withCrit.rounds
        .expand((r) => r.events)
        .where((e) => e.type == BattleEventType.playerCrit);
    expect(critEvents, isNotEmpty);

    // Crit damage should be at least 2× the non-crit formula.
    final baseDamage = (200 * (100 / (100 + weakEnemy.baseDEF))).floor();
    for (final crit in critEvents) {
      expect(crit.value, baseDamage * 2);
    }
  });

  test('dodge skips damage', () {
    // Enemy with very high AGI should dodge sometimes.
    final dodgyEnemy = const EnemyData(
      id: 'dodger',
      name: 'Dodger',
      tier: 1,
      baseSTR: 50,
      baseDEF: 50,
      baseVIT: 9999,
      baseAGI: 999, // AGI/10 = 99, nearly always dodges
    );

    final result = BattleEngine().resolve(BattleInput(
      playerStats: {'STR': 200, 'DEF': 200, 'VIT': 200, 'AGI': 0, 'LCK': 0},
      enemy: dodgyEnemy,
      floor: 1,
    ));

    final dodgeEvents = result.rounds
        .expand((r) => r.events)
        .where((e) => e.type == BattleEventType.enemyDodge);
    // With AGI/10 = 99, nearly every attack should be dodged.
    expect(dodgeEvents.length, greaterThan(10));
  });

  test('seeded random produces same result for same floor and day', () {
    final input = BattleInput(
      playerStats: {'STR': 300, 'DEF': 200, 'VIT': 250, 'AGI': 100, 'LCK': 10},
      enemy: weakEnemy,
      floor: 5,
    );

    final result1 = BattleEngine().resolve(input);
    final result2 = BattleEngine().resolve(input);

    expect(result1.playerWon, result2.playerWon);
    expect(result1.isDraw, result2.isDraw);
    expect(result1.rounds.length, result2.rounds.length);
    expect(result1.playerHpRemaining, result2.playerHpRemaining);
    expect(result1.enemyHpRemaining, result2.enemyHpRemaining);
  });

  test('minimum stat floor of 50 is applied', () {
    // Player with 0 stats should get min 50 for each.
    final result = BattleEngine().resolve(BattleInput(
      playerStats: {'STR': 0, 'DEF': 0, 'VIT': 0, 'AGI': 0, 'LCK': 0},
      enemy: weakEnemy,
      floor: 1,
    ));

    // VIT min 50 → HP = 150, so player can survive at least one round.
    expect(result.playerHpMax, 150);
  });
}
