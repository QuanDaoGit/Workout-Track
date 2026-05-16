import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/enemies.dart';
import '../models/enemy_data.dart';
import 'battle_engine.dart';
import 'class_battle_modifier.dart';
import 'class_service.dart';
import 'loot_service.dart';
import 'stat_engine.dart';

enum BattleState { none, pending, ready, resolved }

class PendingBattle {
  const PendingBattle({
    required this.enemy,
    required this.floor,
    required this.scheduledTime,
  });

  final EnemyData enemy;
  final int floor;
  final DateTime scheduledTime;

  Map<String, dynamic> toJson() => {
    'enemy': enemy.toJson(),
    'floor': floor,
    'scheduledTime': scheduledTime.toIso8601String(),
  };

  factory PendingBattle.fromJson(Map<String, dynamic> json) => PendingBattle(
    enemy: EnemyData.fromJson(json['enemy'] as Map<String, dynamic>),
    floor: json['floor'] as int,
    scheduledTime: DateTime.parse(json['scheduledTime'] as String),
  );
}

class BattleScheduler {
  static const _pendingKey = 'pending_battle';
  static const _historyKey = 'battle_history';
  static const _floorKey = 'dungeon_floor';
  static const _lastBattleDateKey = 'last_battle_date';
  static const _resolvedTodayKey = 'battle_resolved_today';
  static const _maxHistory = 50;

  // ── Floor ──────────────────────────────────────────────────────────────────

  Future<int> getFloor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_floorKey) ?? 1;
  }

  // ── Schedule ───────────────────────────────────────────────────────────────

  /// Schedules a battle for midnight tonight if one isn't already pending.
  /// Called after a non-abandoned workout session is saved.
  Future<void> scheduleBattle() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't schedule if a battle is already pending.
    if (prefs.getString(_pendingKey) != null) return;

    // Don't schedule if a battle was already resolved today.
    final resolvedToday = prefs.getString(_resolvedTodayKey);
    final today = _dateStr(DateTime.now());
    if (resolvedToday == today) return;

    final floor = prefs.getInt(_floorKey) ?? 1;
    final enemy = scaledEnemyForFloor(floor);
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);

    final pending = PendingBattle(
      enemy: enemy,
      floor: floor,
      scheduledTime: midnight,
    );
    await prefs.setString(_pendingKey, jsonEncode(pending.toJson()));
  }

  // ── Check state ────────────────────────────────────────────────────────────

  /// Returns the current battle state for the home card.
  Future<BattleState> checkBattleState() async {
    final prefs = await SharedPreferences.getInstance();

    // Check for resolved-today state first.
    final resolvedToday = prefs.getString(_resolvedTodayKey);
    final today = _dateStr(DateTime.now());
    if (resolvedToday == today) return BattleState.resolved;

    final raw = prefs.getString(_pendingKey);
    if (raw == null) return BattleState.none;

    final pending = PendingBattle.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (DateTime.now().isAfter(pending.scheduledTime) ||
        DateTime.now().isAtSameMomentAs(pending.scheduledTime)) {
      return BattleState.ready;
    }
    return BattleState.pending;
  }

  /// Returns the pending battle data, if any.
  Future<PendingBattle?> getPendingBattle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;
    return PendingBattle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // ── Resolve ────────────────────────────────────────────────────────────────

  /// Runs the battle and returns the result. Updates floor and history.
  Future<BattleResult> resolveBattle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) throw StateError('No pending battle to resolve');

    final pending = PendingBattle.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    final stats = await StatEngine().getStoredStats();

    // Load class context for battle modifiers.
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
        enemy: pending.enemy,
        floor: pending.floor,
        classContext: classContext,
      ),
    );

    // Persist updated carryover after battle.
    if (result.updatedCarryover != null) {
      await classService.updateCarryover(result.updatedCarryover!);
    }

    // Update floor on win.
    if (result.playerWon) {
      await prefs.setInt(_floorKey, pending.floor + 1);
    }

    // Save result to history.
    await _appendHistory(prefs, result);
    if (result.playerWon) {
      await LootService().prepareLootForBattle(result);
    }

    // Clear pending and mark today as resolved.
    await prefs.remove(_pendingKey);
    await prefs.setString(_lastBattleDateKey, _dateStr(DateTime.now()));
    await prefs.setString(_resolvedTodayKey, _dateStr(DateTime.now()));

    return result;
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

  /// Returns the most recent battle result, if resolved today.
  Future<BattleResult?> getTodayResult() async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedToday = prefs.getString(_resolvedTodayKey);
    if (resolvedToday != _dateStr(DateTime.now())) return null;
    final history = await getHistory();
    if (history.isEmpty) return null;
    return history.last;
  }

  Future<void> _appendHistory(
    SharedPreferences prefs,
    BattleResult result,
  ) async {
    final history = await getHistory();
    history.add(result);
    // Prune to max history.
    final trimmed = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;
    await prefs.setString(
      _historyKey,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
