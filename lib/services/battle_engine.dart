import 'dart:math';

import '../models/class_battle_carryover.dart';
import '../models/enemy_data.dart';
import 'class_battle_modifier.dart';

/// Minimum value for any player stat fed into the battle engine.
const _minStat = 50;

enum BattleEventType {
  playerAttack,
  playerCrit,
  playerDodge,
  enemyAttack,
  enemyDodge,
  playerHpChange,
  enemyHpChange,
  abilityTrigger,
}

class BattleEvent {
  const BattleEvent({
    required this.type,
    required this.value,
    required this.message,
  });

  final BattleEventType type;
  final int value;
  final String message;

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'value': value,
    'message': message,
  };

  factory BattleEvent.fromJson(Map<String, dynamic> json) => BattleEvent(
    type: BattleEventType.values[json['type'] as int],
    value: json['value'] as int,
    message: json['message'] as String,
  );
}

class BattleRound {
  const BattleRound({required this.roundNumber, required this.events});

  final int roundNumber;
  final List<BattleEvent> events;

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory BattleRound.fromJson(Map<String, dynamic> json) => BattleRound(
    roundNumber: json['roundNumber'] as int,
    events: [
      for (final e in json['events'] as List<dynamic>)
        BattleEvent.fromJson(e as Map<String, dynamic>),
    ],
  );
}

class BattleResult {
  const BattleResult({
    required this.playerWon,
    required this.isDraw,
    required this.rounds,
    required this.playerHpRemaining,
    required this.enemyHpRemaining,
    required this.playerHpMax,
    required this.enemyHpMax,
    required this.floor,
    required this.enemy,
    required this.timestamp,
    this.updatedCarryover,
  });

  final bool playerWon;
  final bool isDraw;
  final List<BattleRound> rounds;
  final int playerHpRemaining;
  final int enemyHpRemaining;
  final int playerHpMax;
  final int enemyHpMax;
  final int floor;
  final EnemyData enemy;
  final DateTime timestamp;
  final ClassBattleCarryover? updatedCarryover;

  Map<String, dynamic> toJson() => {
    'playerWon': playerWon,
    'isDraw': isDraw,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'playerHpRemaining': playerHpRemaining,
    'enemyHpRemaining': enemyHpRemaining,
    'playerHpMax': playerHpMax,
    'enemyHpMax': enemyHpMax,
    'floor': floor,
    'enemy': enemy.toJson(),
    'timestamp': timestamp.toIso8601String(),
    if (updatedCarryover != null)
      'updatedCarryover': updatedCarryover!.toJson(),
  };

  factory BattleResult.fromJson(Map<String, dynamic> json) => BattleResult(
    playerWon: json['playerWon'] as bool,
    isDraw: json['isDraw'] as bool,
    rounds: [
      for (final r in json['rounds'] as List<dynamic>)
        BattleRound.fromJson(r as Map<String, dynamic>),
    ],
    playerHpRemaining: json['playerHpRemaining'] as int,
    enemyHpRemaining: json['enemyHpRemaining'] as int,
    playerHpMax: json['playerHpMax'] as int,
    enemyHpMax: json['enemyHpMax'] as int,
    floor: json['floor'] as int,
    enemy: EnemyData.fromJson(json['enemy'] as Map<String, dynamic>),
    timestamp: DateTime.parse(json['timestamp'] as String),
    updatedCarryover: json['updatedCarryover'] != null
        ? ClassBattleCarryover.fromJson(
            json['updatedCarryover'] as Map<String, dynamic>)
        : null,
  );
}

class BattleInput {
  const BattleInput({
    required this.playerStats,
    required this.enemy,
    required this.floor,
    this.classContext,
  });

  final Map<String, int> playerStats;
  final EnemyData enemy;
  final int floor;
  final ClassBattleContext? classContext;
}

/// Pure-logic battle engine. No UI, no side effects.
/// Uses seeded random so the same floor+day always produces the same result.
class BattleEngine {
  static const maxRounds = 20;
  static const _mod = ClassBattleModifier();

  /// Runs a complete battle and returns the result.
  BattleResult resolve(BattleInput input) {
    final seed = input.floor * 1000 + _dayOfYear(DateTime.now());
    final rng = Random(seed);

    final ctx = input.classContext;

    final pSTR = max(_minStat, input.playerStats['STR'] ?? 0);
    final pDEF = max(_minStat, input.playerStats['DEF'] ?? 0);
    final pVIT = max(_minStat, input.playerStats['VIT'] ?? 0);
    final pAGI = max(_minStat, input.playerStats['AGI'] ?? 0);
    final pLCK = max(0, input.playerStats['LCK'] ?? 0);

    final effectiveLCK = _mod.effectiveCritChance(pLCK, ctx);

    final enemy = input.enemy;

    final playerHpMax = pVIT * 3;
    final enemyHpMax = enemy.hp;
    var playerHp = playerHpMax;
    var enemyHp = enemyHpMax;

    final rounds = <BattleRound>[];
    var playerWon = false;
    var isDraw = false;
    var playerHitCount = 0;
    var ironWillTurnsActive = 0;
    var lastStandUsed = false;
    var isFirstHit = true;

    for (var round = 1; round <= maxRounds; round++) {
      final events = <BattleEvent>[];

      // ── Player attacks (may loop for extra turn via Shadow Strike) ──
      var extraTurn = true; // start with one attack guaranteed
      while (extraTurn) {
        extraTurn = false;

        final enemyDodgeRoll = rng.nextInt(100);
        if (enemyDodgeRoll < enemy.baseAGI ~/ 10) {
          events.add(const BattleEvent(
            type: BattleEventType.enemyDodge,
            value: 0,
            message: 'Enemy dodged!',
          ));
        } else {
          playerHitCount++;
          var damage = (pSTR * (100 / (100 + enemy.baseDEF))).floor();

          // Apply Overpower / Iron Tide multiplier
          final mult = _mod.damageMultiplier(playerHitCount, isFirstHit, ctx);
          if (mult > 1.0) {
            damage = (damage * mult).floor();
            if (isFirstHit && ctx != null && ctx.carryover.nextBattleDamageMult > 1.0) {
              events.add(const BattleEvent(
                type: BattleEventType.abilityTrigger,
                value: 0,
                message: 'IRON TIDE: EMPOWERED STRIKE!',
              ));
            }
            if (playerHitCount % 3 == 0 && ctx != null &&
                ctx.unlockedAbilities.contains('bruiser_overpower')) {
              events.add(const BattleEvent(
                type: BattleEventType.abilityTrigger,
                value: 0,
                message: 'OVERPOWER: DOUBLE DAMAGE!',
              ));
            }
          }
          isFirstHit = false;

          final critRoll = rng.nextInt(100);
          final isCrit = critRoll < effectiveLCK;
          if (isCrit) {
            damage *= 2;
            events.add(BattleEvent(
              type: BattleEventType.playerCrit,
              value: damage,
              message: 'CRITICAL HIT! You deal $damage damage!',
            ));
            // Shadow Strike: extra turn on crit
            if (_mod.grantsExtraTurn(true, ctx)) {
              extraTurn = true;
              events.add(const BattleEvent(
                type: BattleEventType.abilityTrigger,
                value: 0,
                message: 'SHADOW STRIKE: EXTRA TURN!',
              ));
            }
          } else {
            events.add(BattleEvent(
              type: BattleEventType.playerAttack,
              value: damage,
              message: 'You attack for $damage damage.',
            ));
          }
          enemyHp -= damage;
          events.add(BattleEvent(
            type: BattleEventType.enemyHpChange,
            value: max(0, enemyHp),
            message: 'Enemy HP: ${max(0, enemyHp)}/$enemyHpMax',
          ));
        }

        if (enemyHp <= 0) break; // enemy dead, stop extra turns
      }

      if (enemyHp <= 0) {
        // Phantom Edge: restore HP on kill
        final hpRestore = _mod.hpRestoredOnKill(playerHpMax, ctx);
        if (hpRestore > 0) {
          playerHp = min(playerHpMax, playerHp + hpRestore);
          events.add(BattleEvent(
            type: BattleEventType.abilityTrigger,
            value: hpRestore,
            message: 'PHANTOM EDGE: +$hpRestore HP RESTORED!',
          ));
        }
        rounds.add(BattleRound(roundNumber: round, events: events));
        playerWon = true;
        break;
      }

      // ── Enemy attacks ──
      final playerDodgeRoll = rng.nextInt(100);
      if (playerDodgeRoll < pAGI ~/ 10) {
        events.add(const BattleEvent(
          type: BattleEventType.playerDodge,
          value: 0,
          message: 'You dodged!',
        ));
      } else {
        var damage = (enemy.baseSTR * (100 / (100 + pDEF))).floor();

        // Iron Will: damage reduction when HP < 30%
        final dr = _mod.damageReduction(playerHp, playerHpMax, ironWillTurnsActive, ctx);
        if (dr < 1.0) {
          damage = (damage * dr).floor();
          ironWillTurnsActive++;
          if (ironWillTurnsActive == 1) {
            events.add(const BattleEvent(
              type: BattleEventType.abilityTrigger,
              value: 0,
              message: 'IRON WILL: DAMAGE REDUCED!',
            ));
          }
        }

        events.add(BattleEvent(
          type: BattleEventType.enemyAttack,
          value: damage,
          message: 'Enemy attacks for $damage damage!',
        ));
        playerHp -= damage;

        // Last Stand: survive at 1 HP
        if (playerHp <= 0 && _mod.survivesKillingBlow(lastStandUsed, ctx)) {
          playerHp = 1;
          lastStandUsed = true;
          events.add(const BattleEvent(
            type: BattleEventType.abilityTrigger,
            value: 1,
            message: 'LAST STAND: SURVIVED AT 1 HP!',
          ));
        }

        events.add(BattleEvent(
          type: BattleEventType.playerHpChange,
          value: max(0, playerHp),
          message: 'Your HP: ${max(0, playerHp)}/$playerHpMax',
        ));
      }

      rounds.add(BattleRound(roundNumber: round, events: events));

      if (playerHp <= 0) break;
    }

    if (playerHp > 0 && enemyHp > 0) isDraw = true;

    // Compute post-battle carryover
    final updatedCarryover = _mod.postBattleCarryover(
      playerWon,
      enemyHp <= 0,
      ctx,
    );

    return BattleResult(
      playerWon: playerWon,
      isDraw: isDraw,
      rounds: rounds,
      playerHpRemaining: max(0, playerHp),
      enemyHpRemaining: max(0, enemyHp),
      playerHpMax: playerHpMax,
      enemyHpMax: enemyHpMax,
      floor: input.floor,
      enemy: input.enemy,
      timestamp: DateTime.now(),
      updatedCarryover: updatedCarryover,
    );
  }

  int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }
}
