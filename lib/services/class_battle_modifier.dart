import '../models/character_class.dart';
import '../models/class_battle_carryover.dart';

/// Pre-loaded context passed into the battle engine.
class ClassBattleContext {
  const ClassBattleContext({
    required this.characterClass,
    required this.unlockedAbilities,
    required this.carryover,
  });

  final CharacterClass characterClass;
  final Set<String> unlockedAbilities;
  final ClassBattleCarryover carryover;
}

/// Pure, stateless modifier helper queried by BattleEngine at decision points.
/// No async, no SharedPreferences. Receives all data via context.
class ClassBattleModifier {
  const ClassBattleModifier();

  /// Effective crit chance (base + Phantom Edge carryover bonus).
  int effectiveCritChance(int baseLCK, ClassBattleContext? ctx) {
    if (ctx == null) return baseLCK;
    return baseLCK + ctx.carryover.nextBattleCritBonus;
  }

  /// Damage multiplier for this hit.
  /// Overpower: 2x on every 3rd hit (hitCount is 1-based).
  /// Iron Tide carryover: applies once on first hit only.
  double damageMultiplier(int hitCount, bool firstHitInBattle, ClassBattleContext? ctx) {
    if (ctx == null) return 1.0;
    var mult = 1.0;

    // Bruiser primary: Overpower (every 3rd hit = 2x)
    if (ctx.unlockedAbilities.contains('bruiser_overpower') &&
        hitCount % 3 == 0) {
      mult *= 2.0;
    }

    // Bruiser ultimate carryover: Iron Tide (+50% on first hit)
    if (firstHitInBattle && ctx.carryover.nextBattleDamageMult > 1.0) {
      mult *= ctx.carryover.nextBattleDamageMult;
    }

    return mult;
  }

  /// Whether the player gets an extra turn (Shadow Strike: extra turn on crit).
  bool grantsExtraTurn(bool wasCrit, ClassBattleContext? ctx) {
    if (ctx == null) return false;
    return wasCrit &&
        ctx.unlockedAbilities.contains('assassin_shadow_strike');
  }

  /// Damage reduction factor when player is hit.
  /// Iron Will: 50% DR when HP < 30% for up to 3 turns.
  double damageReduction(
    int currentHp,
    int maxHp,
    int ironWillTurnsActive,
    ClassBattleContext? ctx,
  ) {
    if (ctx == null) return 1.0;
    if (!ctx.unlockedAbilities.contains('tank_iron_will')) return 1.0;
    if (ironWillTurnsActive >= 3) return 1.0;
    if (currentHp > (maxHp * 0.3).floor()) return 1.0;
    return 0.5; // 50% damage reduction
  }

  /// Whether the player survives a killing blow (Last Stand: once per battle).
  bool survivesKillingBlow(bool lastStandUsed, ClassBattleContext? ctx) {
    if (ctx == null) return false;
    if (lastStandUsed) return false;
    return ctx.unlockedAbilities.contains('tank_last_stand');
  }

  /// HP restored on killing blow (Phantom Edge: 25% of max HP).
  int hpRestoredOnKill(int maxHp, ClassBattleContext? ctx) {
    if (ctx == null) return 0;
    if (!ctx.unlockedAbilities.contains('assassin_phantom_edge')) return 0;
    return (maxHp * 0.25).floor();
  }

  /// Compute updated carryover after battle ends.
  ClassBattleCarryover postBattleCarryover(
    bool playerWon,
    bool enemyKilled,
    ClassBattleContext? ctx,
  ) {
    if (ctx == null) return const ClassBattleCarryover();

    var critBonus = 0;
    var damageMult = 1.0;
    var winCounter = ctx.carryover.bruiserBattleWinCounter;

    // Phantom Edge: if enemy killed, grant +10 crit next battle
    if (enemyKilled &&
        ctx.unlockedAbilities.contains('assassin_phantom_edge')) {
      critBonus = 10;
    }

    // Iron Tide: track wins, every 5th = +50% next battle
    if (playerWon &&
        ctx.unlockedAbilities.contains('bruiser_iron_tide')) {
      winCounter++;
      if (winCounter >= 5) {
        damageMult = 1.5;
        winCounter = 0;
      }
    } else if (!playerWon) {
      // Reset counter on loss/draw
      winCounter = ctx.carryover.bruiserBattleWinCounter;
    }

    return ClassBattleCarryover(
      nextBattleCritBonus: critBonus,
      nextBattleDamageMult: damageMult,
      bruiserBattleWinCounter: winCounter,
    );
  }
}
