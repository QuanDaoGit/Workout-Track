import 'dart:ui';

import '../models/battle_animation_state.dart';
import 'battle_engine.dart';

/// Parses a [BattleResult] into a sequence of [SpriteAnimEvent]s for the
/// sprite scene. HP change and ability trigger events are merged into the
/// preceding attack/dodge event rather than producing standalone animations.
List<SpriteAnimEvent> parseBattleEvents(BattleResult result) {
  final output = <SpriteAnimEvent>[];

  for (final round in result.rounds) {
    for (final event in round.events) {
      switch (event.type) {
        case BattleEventType.playerAttack:
          output.add(SpriteAnimEvent(
            playerState: SpriteAnimState.attacking,
            enemyState: SpriteAnimState.hurt,
            durationMs: 700,
          ));

        case BattleEventType.playerCrit:
          output.add(SpriteAnimEvent(
            playerState: SpriteAnimState.attacking,
            enemyState: SpriteAnimState.hurt,
            isCrit: true,
            durationMs: 700,
          ));

        case BattleEventType.playerDodge:
          output.add(SpriteAnimEvent(
            playerState: SpriteAnimState.dodging,
            enemyState: SpriteAnimState.idle,
            durationMs: 400,
          ));

        case BattleEventType.enemyAttack:
          output.add(SpriteAnimEvent(
            playerState: SpriteAnimState.hurt,
            enemyState: SpriteAnimState.attacking,
            durationMs: 700,
          ));

        case BattleEventType.enemyDodge:
          output.add(SpriteAnimEvent(
            playerState: SpriteAnimState.idle,
            enemyState: SpriteAnimState.dodging,
            durationMs: 400,
          ));

        case BattleEventType.playerHpChange:
          _mergeHp(output, playerHp: event.value);

        case BattleEventType.enemyHpChange:
          _mergeHp(output, enemyHp: event.value);

        case BattleEventType.abilityTrigger:
          _mergeAbility(output, event.message);
      }
    }
  }

  // Append terminal state.
  if (result.playerWon) {
    output.add(const SpriteAnimEvent(
      playerState: SpriteAnimState.victory,
      enemyState: SpriteAnimState.defeat,
      durationMs: 1000,
    ));
  } else if (result.isDraw) {
    output.add(const SpriteAnimEvent(
      playerState: SpriteAnimState.idle,
      enemyState: SpriteAnimState.idle,
      durationMs: 500,
    ));
  } else {
    output.add(const SpriteAnimEvent(
      playerState: SpriteAnimState.defeat,
      enemyState: SpriteAnimState.victory,
      durationMs: 1000,
    ));
  }

  return output;
}

/// Merge HP update into the last emitted event.
void _mergeHp(List<SpriteAnimEvent> output, {int? playerHp, int? enemyHp}) {
  if (output.isEmpty) return;
  final last = output.removeLast();
  output.add(SpriteAnimEvent(
    playerState: last.playerState,
    enemyState: last.enemyState,
    isCrit: last.isCrit,
    abilityId: last.abilityId,
    abilityColor: last.abilityColor,
    abilityOnPlayer: last.abilityOnPlayer,
    playerHp: playerHp ?? last.playerHp,
    enemyHp: enemyHp ?? last.enemyHp,
    durationMs: last.durationMs,
  ));
}

/// Merge ability trigger into the last emitted event.
void _mergeAbility(List<SpriteAnimEvent> output, String message) {
  if (output.isEmpty) return;

  String? abilityId;
  Color? abilityColor;
  bool onPlayer = true;

  if (message.contains('SHADOW STRIKE')) {
    abilityId = 'SS';
    abilityColor = const Color(0xFF4DE5FF);
  } else if (message.contains('PHANTOM EDGE')) {
    abilityId = 'PE';
    abilityColor = const Color(0xFF4DE5FF);
  } else if (message.contains('OVERPOWER')) {
    abilityId = 'OP';
    abilityColor = const Color(0xFFFFD700);
  } else if (message.contains('IRON TIDE')) {
    abilityId = 'IT';
    abilityColor = const Color(0xFFFFD700);
  } else if (message.contains('IRON WILL')) {
    abilityId = 'IW';
    abilityColor = const Color(0xFFFF2D55);
    onPlayer = true; // defensive ability on player
  } else if (message.contains('LAST STAND')) {
    abilityId = 'LS';
    abilityColor = const Color(0xFFFF2D55);
    onPlayer = true;
  }

  if (abilityId == null) return;

  final last = output.removeLast();
  output.add(SpriteAnimEvent(
    playerState: last.playerState,
    enemyState: last.enemyState,
    isCrit: last.isCrit,
    abilityId: abilityId,
    abilityColor: abilityColor,
    abilityOnPlayer: onPlayer,
    playerHp: last.playerHp,
    enemyHp: last.enemyHp,
    durationMs: last.durationMs,
  ));
}
