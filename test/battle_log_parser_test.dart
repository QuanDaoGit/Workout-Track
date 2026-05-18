import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:workout_track/models/battle_animation_state.dart';
import 'package:workout_track/models/enemy_data.dart';
import 'package:workout_track/services/battle_engine.dart';
import 'package:workout_track/services/battle_log_parser.dart';

BattleResult _makeResult({
  required List<BattleRound> rounds,
  bool playerWon = true,
  bool isDraw = false,
}) {
  return BattleResult(
    playerWon: playerWon,
    isDraw: isDraw,
    rounds: rounds,
    playerHpRemaining: 100,
    enemyHpRemaining: 0,
    playerHpMax: 300,
    enemyHpMax: 200,
    floor: 1,
    enemy: const EnemyData(
      id: 'shadow_rat',
      name: 'Shadow Rat',
      tier: 1,
      baseSTR: 80,
      baseDEF: 40,
      baseVIT: 60,
      baseAGI: 30,
    ),
    timestamp: DateTime(2026, 1, 1),
  );
}

void main() {
  group('parseBattleEvents', () {
    test('playerAttack produces attacking/hurt states', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerAttack,
            value: 50,
            message: 'You attack for 50 damage.',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      // 1 attack + 1 terminal
      expect(events.length, 2);
      expect(events[0].playerState, SpriteAnimState.attacking);
      expect(events[0].enemyState, SpriteAnimState.hurt);
      expect(events[0].durationMs, 700);
    });

    test('playerCrit sets isCrit flag', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerCrit,
            value: 100,
            message: 'CRITICAL HIT! You deal 100 damage!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].isCrit, true);
      expect(events[0].playerState, SpriteAnimState.attacking);
      expect(events[0].enemyState, SpriteAnimState.hurt);
    });

    test('enemyAttack produces hurt/attacking states', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.enemyAttack,
            value: 30,
            message: 'Enemy attacks for 30 damage!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].playerState, SpriteAnimState.hurt);
      expect(events[0].enemyState, SpriteAnimState.attacking);
    });

    test('playerDodge produces dodging/idle', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerDodge,
            value: 0,
            message: 'You dodged!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].playerState, SpriteAnimState.dodging);
      expect(events[0].enemyState, SpriteAnimState.idle);
      expect(events[0].durationMs, 400);
    });

    test('enemyDodge produces idle/dodging', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.enemyDodge,
            value: 0,
            message: 'Enemy dodged!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].playerState, SpriteAnimState.idle);
      expect(events[0].enemyState, SpriteAnimState.dodging);
    });

    test('HP change events are merged into preceding event', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerAttack,
            value: 50,
            message: 'You attack for 50 damage.',
          ),
          BattleEvent(
            type: BattleEventType.enemyHpChange,
            value: 150,
            message: 'Enemy HP: 150/200',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      // 1 merged attack + 1 terminal = 2 events
      expect(events.length, 2);
      expect(events[0].enemyHp, 150);
      expect(events[0].playerState, SpriteAnimState.attacking);
    });

    test('ability trigger events merge with correct id and color', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerAttack,
            value: 100,
            message: 'You attack for 100 damage.',
          ),
          BattleEvent(
            type: BattleEventType.abilityTrigger,
            value: 0,
            message: 'OVERPOWER: DOUBLE DAMAGE!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].abilityId, 'OP');
      expect(events[0].abilityColor, const Color(0xFFFFD700));
    });

    test('SHADOW STRIKE ability detected', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerCrit,
            value: 80,
            message: 'CRITICAL HIT! You deal 80 damage!',
          ),
          BattleEvent(
            type: BattleEventType.abilityTrigger,
            value: 0,
            message: 'SHADOW STRIKE: EXTRA TURN!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].abilityId, 'SS');
      expect(events[0].abilityColor, const Color(0xFF4DE5FF));
      expect(events[0].isCrit, true);
    });

    test('IRON WILL ability detected', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.enemyAttack,
            value: 20,
            message: 'Enemy attacks for 20 damage!',
          ),
          BattleEvent(
            type: BattleEventType.abilityTrigger,
            value: 0,
            message: 'IRON WILL: DAMAGE REDUCED!',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      expect(events[0].abilityId, 'IW');
      expect(events[0].abilityColor, const Color(0xFFFF2D55));
    });

    test('terminal event is victory when playerWon', () {
      final result = _makeResult(
        rounds: const [],
        playerWon: true,
      );

      final events = parseBattleEvents(result);
      expect(events.last.playerState, SpriteAnimState.victory);
      expect(events.last.enemyState, SpriteAnimState.defeat);
    });

    test('terminal event is defeat when player lost', () {
      final result = _makeResult(
        rounds: const [],
        playerWon: false,
        isDraw: false,
      );

      final events = parseBattleEvents(result);
      expect(events.last.playerState, SpriteAnimState.defeat);
      expect(events.last.enemyState, SpriteAnimState.victory);
    });

    test('terminal event is idle/idle for draw', () {
      final result = _makeResult(
        rounds: const [],
        playerWon: false,
        isDraw: true,
      );

      final events = parseBattleEvents(result);
      expect(events.last.playerState, SpriteAnimState.idle);
      expect(events.last.enemyState, SpriteAnimState.idle);
    });

    test('multiple events in sequence produce correct count', () {
      final result = _makeResult(rounds: [
        const BattleRound(roundNumber: 1, events: [
          BattleEvent(
            type: BattleEventType.playerAttack,
            value: 50,
            message: 'You attack for 50 damage.',
          ),
          BattleEvent(
            type: BattleEventType.enemyHpChange,
            value: 150,
            message: 'Enemy HP: 150/200',
          ),
          BattleEvent(
            type: BattleEventType.enemyAttack,
            value: 30,
            message: 'Enemy attacks for 30 damage!',
          ),
          BattleEvent(
            type: BattleEventType.playerHpChange,
            value: 270,
            message: 'Your HP: 270/300',
          ),
        ]),
      ]);

      final events = parseBattleEvents(result);
      // 2 action events (attack + enemy attack) + 1 terminal = 3
      expect(events.length, 3);
      expect(events[0].enemyHp, 150);
      expect(events[1].playerHp, 270);
    });
  });
}
