import '../services/battle_engine.dart';
import 'loot_item.dart';

/// Result of simulating offline battles when the app was backgrounded.
class OfflineSimResult {
  const OfflineSimResult({
    required this.startFloor,
    required this.endFloor,
    required this.highestFloor,
    required this.wins,
    required this.losses,
    required this.skippedRestSlots,
    required this.lootGained,
    required this.wasEntirelyRest,
    required this.offlineDuration,
  });

  final int startFloor;
  final int endFloor;
  final int highestFloor;
  final int wins;
  final int losses;
  final int skippedRestSlots;
  final List<LootResult> lootGained;

  /// True if every offline slot fell on a rest day (zero battles fought).
  final bool wasEntirelyRest;
  final Duration offlineDuration;

  int get totalBattles => wins + losses;
  bool get hasBattles => totalBattles > 0;
  int get floorDelta => endFloor - startFloor;
}

enum IdleBattleUpdateType {
  battleStarting,
  battleComplete,
}

/// Emitted by [IdleBattleService] on the live-battle stream.
class IdleBattleUpdate {
  const IdleBattleUpdate({
    required this.type,
    this.battleResult,
    required this.currentFloor,
    required this.highestFloor,
    this.loot,
  });

  final IdleBattleUpdateType type;

  /// Non-null when [type] is [IdleBattleUpdateType.battleComplete].
  final BattleResult? battleResult;
  final int currentFloor;
  final int highestFloor;
  final LootResult? loot;
}
