import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/enemies.dart';
import '../models/idle_battle_models.dart';
import '../models/loot_item.dart';
import 'battle_engine.dart';
import 'class_battle_modifier.dart';
import 'class_service.dart';
import 'loot_service.dart';
import 'rest_service.dart';
import 'stat_engine.dart';
import 'workout_storage_service.dart';

class IdleBattleService {
  IdleBattleService._();
  static final IdleBattleService _instance = IdleBattleService._();
  factory IdleBattleService() => _instance;

  static const _floorKey = 'idle_current_floor';
  static const _highestFloorKey = 'idle_highest_floor';
  static const _timestampKey = 'idle_last_session_timestamp';
  static const _historyKey = 'idle_battle_history';
  static const _migratedKey = 'idle_migrated';
  static const _maxHistory = 50;

  static const _battleIntervalMinutes = 10;
  static const _maxOfflineHours = 12;

  static const _lootBaseChance = 0.01;
  static const _lootFloorBonus = 0.001;
  static const _lootMaxChance = 0.12;

  Timer? _liveTimer;
  final _controller = StreamController<IdleBattleUpdate>.broadcast();

  /// Stream of live battle events for [LiveDungeonPage].
  Stream<IdleBattleUpdate> get updates => _controller.stream;

  // ── Migration ──────────────────────────────────────────────────────────────

  /// One-time migration from BattleScheduler storage keys.
  Future<void> migrate() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    final oldFloor = prefs.getInt('dungeon_floor') ?? 1;
    await prefs.setInt(_floorKey, oldFloor);
    await prefs.setInt(_highestFloorKey, oldFloor);

    // Migrate battle history if present.
    final oldHistory = prefs.getString('battle_history');
    if (oldHistory != null) {
      await prefs.setString(_historyKey, oldHistory);
    }

    // Set initial timestamp to now so first sim produces zero battles.
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);

    await prefs.setBool(_migratedKey, true);
  }

  // ── Floor management ───────────────────────────────────────────────────────

  Future<int> getCurrentFloor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_floorKey) ?? 1;
  }

  Future<int> getHighestFloor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highestFloorKey) ?? 1;
  }

  int _floorMinimum(int highestFloor) => max(1, (highestFloor * 0.9).floor());

  // ── Timestamp ──────────────────────────────────────────────────────────────

  Future<void> recordTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<List<BattleResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        BattleResult.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> _appendHistory(
    SharedPreferences prefs,
    BattleResult result,
  ) async {
    final history = await getHistory();
    history.add(result);
    final trimmed = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;
    await prefs.setString(
      _historyKey,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }

  // ── Offline simulation ─────────────────────────────────────────────────────

  Future<OfflineSimResult> simulateOfflineProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_timestampKey);

    // First launch — just set timestamp and return empty.
    if (lastTs == null) {
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      final floor = prefs.getInt(_floorKey) ?? 1;
      return OfflineSimResult(
        startFloor: floor,
        endFloor: floor,
        highestFloor: prefs.getInt(_highestFloorKey) ?? floor,
        wins: 0,
        losses: 0,
        skippedRestSlots: 0,
        lootGained: const [],
        wasEntirelyRest: false,
        offlineDuration: Duration.zero,
      );
    }

    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTs);
    final now = DateTime.now();
    var elapsed = now.difference(lastTime);
    if (elapsed.isNegative) elapsed = Duration.zero;
    final maxOffline = const Duration(hours: _maxOfflineHours);
    if (elapsed > maxOffline) elapsed = maxOffline;

    final totalSlots = elapsed.inMinutes ~/ _battleIntervalMinutes;
    if (totalSlots <= 0) {
      final floor = prefs.getInt(_floorKey) ?? 1;
      return OfflineSimResult(
        startFloor: floor,
        endFloor: floor,
        highestFloor: prefs.getInt(_highestFloorKey) ?? floor,
        wins: 0,
        losses: 0,
        skippedRestSlots: 0,
        lootGained: const [],
        wasEntirelyRest: false,
        offlineDuration: elapsed,
      );
    }

    // Load rest state and sessions once for rest-day checks.
    final restService = RestService();
    final sessions = await WorkoutStorageService().getSessions();
    final restState = await restService.loadState();
    final stats = await StatEngine().getStoredStats();

    var floor = prefs.getInt(_floorKey) ?? 1;
    var highestFloor = prefs.getInt(_highestFloorKey) ?? floor;
    final startFloor = floor;
    var wins = 0;
    var losses = 0;
    var skippedRest = 0;
    final lootGained = <LootResult>[];

    // Cache rest-day checks per date to avoid redundant lookups.
    final restDayCache = <String, bool>{};

    for (var i = 0; i < totalSlots; i++) {
      final slotTime = lastTime.add(
        Duration(minutes: (i + 1) * _battleIntervalMinutes),
      );
      final slotDate = DateTime(slotTime.year, slotTime.month, slotTime.day);
      final dateStr = _dateKey(slotDate);

      final isRest = restDayCache.putIfAbsent(dateStr, () {
        final info = restService.dayInfoForState(
          day: slotDate,
          sessions: sessions,
          state: restState,
          now: now,
        );
        return !info.isScheduledTrainingDay;
      });

      if (isRest) {
        skippedRest++;
        continue;
      }

      // Run lightweight win/loss.
      final daysSinceEpoch = slotDate.millisecondsSinceEpoch ~/ 86400000;
      final won = _simulateWinLoss(floor, daysSinceEpoch, i, stats);

      if (won) {
        wins++;
        floor++;
        if (floor > highestFloor) highestFloor = floor;

        // Roll loot.
        final loot = await _rollLootOffline(floor - 1, i, daysSinceEpoch);
        if (loot != null) lootGained.add(loot);
      } else {
        losses++;
        floor = max(_floorMinimum(highestFloor), floor - 1);
      }
    }

    // Persist updated state.
    await prefs.setInt(_floorKey, floor);
    await prefs.setInt(_highestFloorKey, highestFloor);
    await prefs.setInt(_timestampKey, now.millisecondsSinceEpoch);

    return OfflineSimResult(
      startFloor: startFloor,
      endFloor: floor,
      highestFloor: highestFloor,
      wins: wins,
      losses: losses,
      skippedRestSlots: skippedRest,
      lootGained: lootGained,
      wasEntirelyRest: wins == 0 && losses == 0 && skippedRest > 0,
      offlineDuration: elapsed,
    );
  }

  /// Lightweight deterministic win/loss for offline simulation.
  bool _simulateWinLoss(
    int floor,
    int daysSinceEpoch,
    int battleIndex,
    Map<String, int> stats,
  ) {
    final seed = floor + daysSinceEpoch * 1000 + battleIndex;
    final rng = Random(seed);
    final enemy = scaledEnemyForFloor(floor);

    final pSTR = max(50, stats['STR'] ?? 0);
    final pDEF = max(50, stats['DEF'] ?? 0);
    final pVIT = max(50, stats['VIT'] ?? 0);
    final pAGI = max(50, stats['AGI'] ?? 0);

    final playerPower = pSTR + pDEF + pVIT * 3 + pAGI;
    final enemyPower =
        enemy.baseSTR + enemy.baseDEF + enemy.hp + enemy.baseAGI;

    final ratio = playerPower / (playerPower + enemyPower);
    return rng.nextDouble() < ratio;
  }

  /// Roll loot for an offline win. Auto-claims via LootService.
  Future<LootResult?> _rollLootOffline(
    int floor,
    int battleIndex,
    int daysSinceEpoch,
  ) async {
    final isBoss = floor % 10 == 0;
    final chance = min(_lootMaxChance, _lootBaseChance + floor * _lootFloorBonus);
    final seed = floor * 777 + daysSinceEpoch * 100 + battleIndex;
    final rng = Random(seed);

    if (!isBoss && rng.nextDouble() >= chance) return null;

    final lootService = LootService();
    final item = isBoss
        ? lootService.getBossDrop(floor)
        : lootService.rollNormalDrop(floor);

    return lootService.claimLoot(item);
  }

  // ── Live loop ──────────────────────────────────────────────────────────────

  void startLiveLoop() {
    if (_liveTimer != null) return;
    _liveTimer = Timer.periodic(
      const Duration(minutes: _battleIntervalMinutes),
      (_) => _runLiveBattle(),
    );
  }

  void stopLiveLoop() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  /// Fire an immediate battle (e.g. when entering the dungeon page).
  Future<void> triggerImmediateBattle() => _runLiveBattle();

  Future<void> _runLiveBattle() async {
    final prefs = await SharedPreferences.getInstance();
    var floor = prefs.getInt(_floorKey) ?? 1;
    var highestFloor = prefs.getInt(_highestFloorKey) ?? floor;

    // Emit starting event.
    _controller.add(IdleBattleUpdate(
      type: IdleBattleUpdateType.battleStarting,
      currentFloor: floor,
      highestFloor: highestFloor,
    ));

    // Resolve a full battle via BattleEngine for animation data.
    final stats = await StatEngine().getStoredStats();
    final enemy = scaledEnemyForFloor(floor);

    final classService = ClassService();
    final classState = await classService.getState();
    ClassBattleContext? classContext;
    if (classState != null) {
      final carryover = await classService.getCarryover();
      classContext = ClassBattleContext(
        characterClass: classState.currentClass,
        unlockedAbilities: classState.unlockedAbilityIds,
        carryover: carryover,
      );
    }

    final result = BattleEngine().resolve(
      BattleInput(
        playerStats: stats,
        enemy: enemy,
        floor: floor,
        classContext: classContext,
      ),
    );

    // Persist carryover.
    if (result.updatedCarryover != null) {
      await classService.updateCarryover(result.updatedCarryover!);
    }

    // Update floor.
    LootResult? loot;
    if (result.playerWon) {
      floor++;
      if (floor > highestFloor) highestFloor = floor;

      // Loot roll.
      final isBoss = (floor - 1) % 10 == 0;
      final chance =
          min(_lootMaxChance, _lootBaseChance + (floor - 1) * _lootFloorBonus);
      final rng = Random((floor - 1) * 777 + _dayOfYear(DateTime.now()));
      if (isBoss || rng.nextDouble() < chance) {
        final lootService = LootService();
        final item = isBoss
            ? lootService.getBossDrop(floor - 1)
            : lootService.rollNormalDrop(floor - 1);
        loot = await lootService.claimLoot(item);
      }
    } else if (!result.isDraw) {
      floor = max(_floorMinimum(highestFloor), floor - 1);
    }

    await prefs.setInt(_floorKey, floor);
    await prefs.setInt(_highestFloorKey, highestFloor);
    await _appendHistory(prefs, result);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);

    // Emit complete event.
    _controller.add(IdleBattleUpdate(
      type: IdleBattleUpdateType.battleComplete,
      battleResult: result,
      currentFloor: floor,
      highestFloor: highestFloor,
      loot: loot,
    ));
  }

  int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void dispose() {
    stopLiveLoop();
    _controller.close();
  }
}
