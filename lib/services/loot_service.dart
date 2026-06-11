import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/loot_registry.dart';
import '../data/muscle_groups.dart';
import '../models/loot_item.dart';
import '../models/loot_unlock_rule.dart';
import '../models/milestone_models.dart';
import '../models/workout_models.dart';
import 'exercise_catalog_service.dart';
import 'gem_service.dart';

class LootService {
  static const bool unlockAllLootForTestBuild = false;

  static const String _inventoryKey = 'loot_inventory';
  static const String _equippedKey = 'equipped_loot';

  final bool _unlockAllLoot;

  LootService({bool unlockAllLoot = unlockAllLootForTestBuild})
    : _unlockAllLoot = unlockAllLoot;

  Future<List<LootItem>> getInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    return lootRegistry.where((item) => owned.contains(item.id)).toList();
  }

  Future<int> getOwnedCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _ownedIds(prefs)).length;
  }

  Future<Map<LootCategory, LootItem>> getEquippedLoot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_equippedKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final owned = await _ownedIds(prefs);
    final equipped = <LootCategory, LootItem>{};
    for (final entry in decoded.entries) {
      final category = lootCategoryFromStorageKey(entry.key);
      final item = lootItemById(entry.value.toString());
      if (category != null &&
          item != null &&
          item.category == category &&
          owned.contains(item.id)) {
        equipped[category] = item;
      }
    }
    return equipped;
  }

  Future<LootItem?> getEquippedItem(LootCategory category) async {
    final equipped = await getEquippedLoot();
    return equipped[category];
  }

  Future<void> equipItem(String itemId) async {
    final item = lootItemById(itemId);
    if (item == null) {
      throw StateError('Unknown loot item: $itemId');
    }

    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    if (!owned.contains(item.id)) {
      throw StateError('Cannot equip locked item.');
    }

    final equipped = await getEquippedLoot();
    equipped[item.category] = item;
    final encoded = <String, String>{};
    for (final entry in equipped.entries) {
      encoded[entry.key.storageKey] = entry.value.id;
    }
    await prefs.setString(_equippedKey, jsonEncode(encoded));
  }

  /// Clear the equipped item in [category] (e.g. revert a title to "None").
  /// Non-destructive: ownership is untouched, only the equipped slot is removed.
  Future<void> unequipCategory(LootCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final equipped = await getEquippedLoot();
    if (equipped.remove(category) == null) return;
    final encoded = <String, String>{};
    for (final entry in equipped.entries) {
      encoded[entry.key.storageKey] = entry.value.id;
    }
    await prefs.setString(_equippedKey, jsonEncode(encoded));
  }

  /// Grant a specific item directly. Idempotent.
  Future<void> grantItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    if (owned.contains(itemId)) return;
    owned.add(itemId);
    await _saveOwnedIds(prefs, owned);
  }

  Future<void> purchaseItemWithGems(String itemId) async {
    final item = lootItemById(itemId);
    if (item == null) {
      throw StateError('Unknown loot item: $itemId');
    }
    final price = item.gemPrice;
    if (price == null ||
        (item.category != LootCategory.avatarFrame &&
            item.category != LootCategory.homeTheme)) {
      throw StateError('Item is not purchasable with gems.');
    }

    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    if (owned.contains(item.id)) return;

    await GemService().spendGems(
      sourceId: item.id,
      amount: price,
      label: item.name,
    );
    owned.add(item.id);
    await _saveOwnedIds(prefs, owned);
  }

  /// Walks every registry item with an [LootUnlockRule] and grants any that are
  /// newly eligible against the supplied stats + workout history.
  ///
  /// Returns the IDs of items granted in this call (for caller-side surfacing).
  Future<List<String>> evaluateUnlocks({
    required Map<String, int> stats,
    required List<WorkoutSession> sessions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    final newlyGranted = <String>[];

    final completed = sessions.where((s) => !s.isPartial).toList();
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final primaryMuscleById = {
      for (final exercise in catalog)
        if (exercise.primaryMuscle != null)
          exercise.id: exercise.primaryMuscle!,
    };
    final sessionCount = completed.length;
    final lifetimeVolume = completed.fold<double>(
      0,
      (sum, s) => sum + s.exercises.fold(0.0, (a, e) => a + e.totalVolume),
    );
    final lifetimeReps = completed.fold<int>(
      0,
      (sum, s) =>
          sum +
          s.exercises.fold(
            0,
            (a, e) => a + e.sets.fold(0, (b, set) => b + set.reps),
          ),
    );

    int sessionsForMuscle(String muscleGroup) {
      return completed
          .where((s) => hasTargetMuscle(s.targetMuscleGroups, muscleGroup))
          .length;
    }

    double volumeForMuscle(String muscleGroup) {
      final normalized = normalizeMuscleGroup(muscleGroup);
      if (normalized == null) return 0;
      var total = 0.0;
      for (final session in completed) {
        final targets = session.targetMuscleGroups;
        for (final log in session.exercises) {
          final primary = primaryMuscleById[log.exerciseId];
          final bucket = primary == null
              ? null
              : muscleGroupForDetailed(primary);
          if (bucket == normalized) {
            total += log.totalVolume;
          } else if (bucket == null &&
              targets.isNotEmpty &&
              targets.contains(normalized)) {
            total += log.totalVolume / targets.length;
          }
        }
      }
      return total;
    }

    bool meets(LootUnlockRule rule) {
      switch (rule.kind) {
        case UnlockKind.sessions:
          return sessionCount >= rule.threshold;
        case UnlockKind.lifetimeVolume:
          return lifetimeVolume >= rule.threshold;
        case UnlockKind.lifetimeReps:
          return lifetimeReps >= rule.threshold;
        case UnlockKind.muscleSessions:
          final group = rule.muscleGroup;
          if (group == null) return false;
          return sessionsForMuscle(group) >= rule.threshold;
        case UnlockKind.muscleVolume:
          final group = rule.muscleGroup;
          if (group == null) return false;
          return volumeForMuscle(group) >= rule.threshold;
        case UnlockKind.statThreshold:
          final key = rule.statKey;
          if (key == null) return false;
          return (stats[key] ?? 0) >= rule.threshold;
        case UnlockKind.anyStatThreshold:
          return MilestoneSnapshot.growthStats.any(
            (stat) => (stats[stat] ?? 0) >= rule.threshold,
          );
        case UnlockKind.allStatsAbove:
          return MilestoneSnapshot.growthStats.every(
            (stat) => (stats[stat] ?? 0) >= rule.threshold,
          );
      }
    }

    for (final item in lootRegistry) {
      final rule = item.unlockRule;
      if (rule == null) continue;
      if (owned.contains(item.id)) continue;
      if (meets(rule)) {
        owned.add(item.id);
        newlyGranted.add(item.id);
      }
    }

    if (newlyGranted.isNotEmpty) {
      await _saveOwnedIds(prefs, owned);
    }
    return newlyGranted;
  }

  Future<Set<String>> _ownedIds(SharedPreferences prefs) async {
    final ids = prefs.getStringList(_inventoryKey)?.toSet() ?? <String>{};
    ids.addAll(defaultLootIds);
    if (_unlockAllLoot) {
      ids.addAll(lootRegistry.map((item) => item.id));
    }
    final savedIds = prefs.getStringList(_inventoryKey);
    if (savedIds == null || (_unlockAllLoot && ids.length != savedIds.length)) {
      await _saveOwnedIds(prefs, ids);
    }
    return ids;
  }

  Future<void> _saveOwnedIds(SharedPreferences prefs, Set<String> ids) async {
    final sorted = ids.toList()..sort();
    await prefs.setStringList(_inventoryKey, sorted);
  }
}
