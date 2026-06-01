import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/loot_registry.dart';
import '../models/loot_drop.dart';
import '../models/loot_item.dart';
import '../models/workout_models.dart';
import 'loot_service.dart';
import 'xp_service.dart';

class LootDropService {
  static const String dropsKey = 'loot_drops_v1';
  static const String stateKey = 'loot_drop_state_v1';
  static const String fragmentsKey = 'frame_fragments_v1';
  static const String installIdKey = 'install_id_v1';

  Future<LootDrop?> rollForSession({
    required WorkoutSession session,
    required int lck,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final state = await _loadState(prefs);
    if (state.rolledSessionIds.contains(session.id)) return null;

    final rolledIds = {...state.rolledSessionIds, session.id};
    final reference = now ?? DateTime.now();
    final lastRollAt = state.lastRollAt;
    if (lastRollAt != null &&
        reference.difference(lastRollAt) < const Duration(hours: 2)) {
      await _saveState(prefs, state.copyWith(rolledSessionIds: rolledIds));
      return null;
    }

    final installId = await _installId(prefs);
    final seed = _hash('$installId:${session.id}');
    final tier = state.rollAttemptsSinceRare >= 9
        ? LootDropTier.rare
        : _tierFor(seed / 0x7fffffff, lck);

    if (tier == null) {
      await _saveState(
        prefs,
        LootDropState(
          rollAttemptsSinceRare: state.rollAttemptsSinceRare + 1,
          lastRollAt: reference,
          rolledSessionIds: rolledIds,
        ),
      );
      return null;
    }

    final drop = await _buildDrop(
      prefs,
      session: session,
      tier: tier,
      seed: seed,
      now: reference,
    );
    await _saveDrop(prefs, drop);
    await _saveState(
      prefs,
      LootDropState(
        rollAttemptsSinceRare: drop.isRareOrBetter
            ? 0
            : state.rollAttemptsSinceRare + 1,
        lastRollAt: reference,
        rolledSessionIds: rolledIds,
      ),
    );
    return drop;
  }

  Future<List<LootDrop>> recentDrops({int limit = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final drops = await _loadDrops(prefs);
    drops.sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
    return drops.take(limit).toList();
  }

  Future<bool> hasUnviewedDrops() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _loadDrops(prefs)).any((drop) => drop.viewedAt == null);
  }

  Future<void> markAllViewed({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final viewedAt = now ?? DateTime.now();
    final drops = [
      for (final drop in await _loadDrops(prefs))
        drop.viewedAt == null ? drop.copyWith(viewedAt: viewedAt) : drop,
    ];
    await _saveDrops(prefs, drops);
  }

  Future<Map<String, int>> fragmentCounts() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _loadFragments(prefs)).counts;
  }

  Future<LootDropState> debugStateForTest() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadState(prefs);
  }

  Future<LootDrop> _buildDrop(
    SharedPreferences prefs, {
    required WorkoutSession session,
    required LootDropTier tier,
    required int seed,
    required DateTime now,
  }) async {
    final roll = ((seed ~/ 97) % 1000) / 1000;
    final id = 'drop_${session.id}_${now.microsecondsSinceEpoch}';
    if (tier == LootDropTier.common && roll < 0.45) {
      return LootDrop(
        id: id,
        sessionId: session.id,
        tier: tier,
        contentKind: LootDropContentKind.xpBonus,
        xpBonus: 10 + (seed % 11),
        awardedAt: now,
      );
    }

    if (tier == LootDropTier.common || tier == LootDropTier.uncommon) {
      final fragmentDrop = await _fragmentDrop(
        prefs,
        id: id,
        sessionId: session.id,
        tier: tier,
        seed: seed,
        now: now,
      );
      if (fragmentDrop != null) return fragmentDrop;
    }

    final item = await _fullItemForTier(tier, seed);
    if (item != null) {
      await LootService().grantItem(item.id);
      return LootDrop(
        id: id,
        sessionId: session.id,
        tier: tier,
        contentKind: LootDropContentKind.fullItem,
        itemId: item.id,
        awardedAt: now,
      );
    }

    return LootDrop(
      id: id,
      sessionId: session.id,
      tier: tier,
      contentKind: LootDropContentKind.xpBonus,
      xpBonus: switch (tier) {
        LootDropTier.common => 15,
        LootDropTier.uncommon => 25,
        LootDropTier.rare => 40,
        LootDropTier.epic => 75,
      },
      awardedAt: now,
    );
  }

  Future<LootDrop?> _fragmentDrop(
    SharedPreferences prefs, {
    required String id,
    required String sessionId,
    required LootDropTier tier,
    required int seed,
    required DateTime now,
  }) async {
    final owned = (await LootService().getInventory()).map((i) => i.id).toSet();
    final frames = lootRegistry
        .where(
          (item) =>
              item.category == LootCategory.avatarFrame &&
              !item.isDefault &&
              !owned.contains(item.id),
        )
        .toList();
    if (frames.isEmpty) return null;
    frames.sort((a, b) => a.id.compareTo(b.id));
    final item = frames[seed % frames.length];
    final fragments = await _loadFragments(prefs);
    final updated = fragments.add(item.id, 1);
    await _saveFragments(prefs, updated);

    String? assembled;
    if (updated.countFor(item.id) >= 4 && !owned.contains(item.id)) {
      await LootService().grantItem(item.id);
      assembled = item.id;
    }

    return LootDrop(
      id: id,
      sessionId: sessionId,
      tier: tier,
      contentKind: LootDropContentKind.frameFragment,
      itemId: item.id,
      fragmentCount: 1,
      assembledItemId: assembled,
      awardedAt: now,
    );
  }

  Future<LootItem?> _fullItemForTier(LootDropTier tier, int seed) async {
    final owned = (await LootService().getInventory()).map((i) => i.id).toSet();
    final rarity = _rarityForTier(tier);
    final pool = lootRegistry
        .where(
          (item) =>
              item.rarity == rarity &&
              !item.isDefault &&
              !owned.contains(item.id),
        )
        .toList();
    if (pool.isEmpty) return null;
    pool.sort((a, b) => a.id.compareTo(b.id));
    return pool[seed % pool.length];
  }

  LootRarity _rarityForTier(LootDropTier tier) => switch (tier) {
    LootDropTier.common => LootRarity.common,
    LootDropTier.uncommon => LootRarity.uncommon,
    LootDropTier.rare => LootRarity.rare,
    LootDropTier.epic => LootRarity.epic,
  };

  LootDropTier? _tierFor(double roll, int lck) {
    final shift = XpService.lckDiamondCount(lck) * 1.25;
    final noDrop = 70.0;
    final common = max(0.0, 18.0 - shift);
    final uncommon = 9.0;
    final rare = 2.5 + shift;
    final epic = 0.5;
    final scaled = roll * 100;
    if (scaled < noDrop) return null;
    if (scaled < noDrop + common) return LootDropTier.common;
    if (scaled < noDrop + common + uncommon) return LootDropTier.uncommon;
    if (scaled < noDrop + common + uncommon + rare) {
      return LootDropTier.rare;
    }
    if (scaled < noDrop + common + uncommon + rare + epic) {
      return LootDropTier.epic;
    }
    return null;
  }

  int _hash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<String> _installId(SharedPreferences prefs) async {
    final existing = prefs.getString(installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(installIdKey, id);
    return id;
  }

  Future<List<LootDrop>> _loadDrops(SharedPreferences prefs) async {
    final raw = prefs.getString(dropsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list) LootDrop.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> _saveDrop(SharedPreferences prefs, LootDrop drop) async {
    final drops = await _loadDrops(prefs);
    drops.add(drop);
    await _saveDrops(prefs, drops);
  }

  Future<void> _saveDrops(SharedPreferences prefs, List<LootDrop> drops) async {
    await prefs.setString(
      dropsKey,
      jsonEncode(drops.map((drop) => drop.toJson()).toList()),
    );
  }

  Future<LootDropState> _loadState(SharedPreferences prefs) async {
    final raw = prefs.getString(stateKey);
    if (raw == null) return const LootDropState();
    return LootDropState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveState(SharedPreferences prefs, LootDropState state) async {
    await prefs.setString(stateKey, jsonEncode(state.toJson()));
  }

  Future<FrameFragmentState> _loadFragments(SharedPreferences prefs) async {
    final raw = prefs.getString(fragmentsKey);
    if (raw == null) return const FrameFragmentState();
    return FrameFragmentState.fromJson(jsonDecode(raw));
  }

  Future<void> _saveFragments(
    SharedPreferences prefs,
    FrameFragmentState fragments,
  ) async {
    await prefs.setString(fragmentsKey, jsonEncode(fragments.toJson()));
  }
}
