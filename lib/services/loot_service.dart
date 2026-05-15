import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/loot_registry.dart';
import '../models/loot_item.dart';
import 'battle_engine.dart';

class LootService {
  static const String _inventoryKey = 'loot_inventory';
  static const String _scrapKey = 'loot_scrap_balance';
  static const String _equippedKey = 'equipped_loot';
  static const String _unclaimedKey = 'unclaimed_loot';

  final DateTime Function() _now;

  LootService({DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  LootItem rollNormalDrop(int floor) {
    final random = Random(floor * 777 + _dayOfYear(_now()));
    final rarity = _rollRarity(random);
    final rarityPool = normalLootPool
        .where((item) => item.rarity == rarity)
        .toList(growable: false);
    final pool = rarityPool.isEmpty ? normalLootPool : rarityPool;
    return pool[random.nextInt(pool.length)];
  }

  LootItem getBossDrop(int floor) {
    return bossLootForFloor(floor);
  }

  Future<LootResult> claimLoot(LootItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    final isDuplicate = owned.contains(item.id);
    final scrapAwarded = isDuplicate ? item.rarity.scrapValue : 0;

    if (isDuplicate) {
      await _setScrapBalance(prefs, await getScrapBalance() + scrapAwarded);
    } else {
      owned.add(item.id);
      await _saveOwnedIds(prefs, owned);
    }

    return LootResult(
      item: item,
      isDuplicate: isDuplicate,
      scrapAwarded: scrapAwarded,
      timestamp: _now(),
    );
  }

  Future<List<LootItem>> getInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    return lootRegistry.where((item) => owned.contains(item.id)).toList();
  }

  Future<int> getOwnedCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _ownedIds(prefs)).length;
  }

  Future<int> getScrapBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scrapKey) ?? 0;
  }

  Future<LootResult> purchaseWithScrap(String itemId) async {
    final item = lootItemById(itemId);
    if (item == null) {
      throw StateError('Unknown loot item: $itemId');
    }
    if (item.bossExclusive) {
      throw StateError('Boss-exclusive items cannot be bought with scrap.');
    }

    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    if (owned.contains(item.id)) {
      throw StateError('Item already owned.');
    }

    final balance = prefs.getInt(_scrapKey) ?? 0;
    if (balance < item.rarity.shopPrice) {
      throw StateError('Not enough scrap.');
    }

    owned.add(item.id);
    await _saveOwnedIds(prefs, owned);
    await _setScrapBalance(prefs, balance - item.rarity.shopPrice);

    return LootResult(
      item: item,
      isDuplicate: false,
      scrapAwarded: 0,
      timestamp: _now(),
    );
  }

  Future<List<LootItem>> getShopItems() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    final items = lootRegistry
        .where((item) => !owned.contains(item.id) && !item.bossExclusive)
        .toList();
    items.sort((a, b) {
      final raritySort = b.rarity.index.compareTo(a.rarity.index);
      if (raritySort != 0) {
        return raritySort;
      }
      return a.name.compareTo(b.name);
    });
    return items;
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

  Future<LootResult> prepareLootForBattle(BattleResult result) async {
    final existing = await getUnclaimedLoot();
    if (existing != null) {
      return existing;
    }

    final isBoss = result.floor % 10 == 0;
    final item = isBoss
        ? getBossDrop(result.floor)
        : rollNormalDrop(result.floor);
    final prefs = await SharedPreferences.getInstance();
    final owned = await _ownedIds(prefs);
    final loot = LootResult(
      item: item,
      isDuplicate: owned.contains(item.id),
      scrapAwarded: owned.contains(item.id) ? item.rarity.scrapValue : 0,
      floor: result.floor,
      isBoss: isBoss,
      timestamp: _now(),
    );
    await prefs.setString(_unclaimedKey, jsonEncode(loot.toJson()));
    return loot;
  }

  Future<LootResult?> getUnclaimedLoot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unclaimedKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final item = lootItemById(decoded['itemId'].toString());
    if (item == null) {
      await prefs.remove(_unclaimedKey);
      return null;
    }

    return LootResult(
      item: item,
      isDuplicate: decoded['isDuplicate'] == true,
      scrapAwarded: (decoded['scrapAwarded'] as num?)?.toInt() ?? 0,
      floor: (decoded['floor'] as num?)?.toInt(),
      isBoss: decoded['isBoss'] == true,
      timestamp:
          DateTime.tryParse(decoded['timestamp']?.toString() ?? '') ?? _now(),
    );
  }

  Future<LootResult?> claimUnclaimedLoot() async {
    final prefs = await SharedPreferences.getInstance();
    final loot = await getUnclaimedLoot();
    if (loot == null) {
      return null;
    }

    final owned = await _ownedIds(prefs);
    final isDuplicate = owned.contains(loot.item.id);
    final scrapAwarded = isDuplicate ? loot.item.rarity.scrapValue : 0;
    if (isDuplicate) {
      await _setScrapBalance(
        prefs,
        (prefs.getInt(_scrapKey) ?? 0) + scrapAwarded,
      );
    } else {
      owned.add(loot.item.id);
      await _saveOwnedIds(prefs, owned);
    }

    await prefs.remove(_unclaimedKey);
    return LootResult(
      item: loot.item,
      isDuplicate: isDuplicate,
      scrapAwarded: scrapAwarded,
      floor: loot.floor,
      isBoss: loot.isBoss,
      timestamp: _now(),
    );
  }

  Future<void> clearUnclaimedLoot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unclaimedKey);
  }

  LootRarity _rollRarity(Random random) {
    final roll = random.nextInt(100);
    if (roll < 50) {
      return LootRarity.common;
    }
    if (roll < 80) {
      return LootRarity.uncommon;
    }
    if (roll < 95) {
      return LootRarity.rare;
    }
    return LootRarity.epic;
  }

  Future<Set<String>> _ownedIds(SharedPreferences prefs) async {
    final ids = prefs.getStringList(_inventoryKey)?.toSet() ?? <String>{};
    ids.addAll(defaultLootIds);
    if (prefs.getStringList(_inventoryKey) == null) {
      await _saveOwnedIds(prefs, ids);
    }
    return ids;
  }

  Future<void> _saveOwnedIds(SharedPreferences prefs, Set<String> ids) async {
    final sorted = ids.toList()..sort();
    await prefs.setStringList(_inventoryKey, sorted);
  }

  Future<void> _setScrapBalance(SharedPreferences prefs, int value) async {
    await prefs.setInt(_scrapKey, value);
  }

  int _dayOfYear(DateTime date) {
    final start = DateTime(date.year);
    return date.difference(start).inDays + 1;
  }
}
