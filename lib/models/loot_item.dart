import 'package:flutter/material.dart';

enum LootRarity { common, uncommon, rare, epic }

enum LootCategory { avatarFrame, titleBadge, homeTheme, battleEffect }

extension LootRarityInfo on LootRarity {
  String get label {
    switch (this) {
      case LootRarity.common:
        return 'COMMON';
      case LootRarity.uncommon:
        return 'UNCOMMON';
      case LootRarity.rare:
        return 'RARE';
      case LootRarity.epic:
        return 'EPIC';
    }
  }

  Color get color {
    switch (this) {
      case LootRarity.common:
        return Colors.white;
      case LootRarity.uncommon:
        return const Color(0xFF00BFFF);
      case LootRarity.rare:
        return const Color(0xFFFFD700);
      case LootRarity.epic:
        return const Color(0xFF00FF9C);
    }
  }

  int get scrapValue {
    switch (this) {
      case LootRarity.common:
        return 5;
      case LootRarity.uncommon:
        return 15;
      case LootRarity.rare:
        return 40;
      case LootRarity.epic:
        return 100;
    }
  }

  int get shopPrice {
    switch (this) {
      case LootRarity.common:
        return 20;
      case LootRarity.uncommon:
        return 50;
      case LootRarity.rare:
        return 120;
      case LootRarity.epic:
        return 300;
    }
  }
}

extension LootCategoryInfo on LootCategory {
  String get label {
    switch (this) {
      case LootCategory.avatarFrame:
        return 'FRAMES';
      case LootCategory.titleBadge:
        return 'TITLES';
      case LootCategory.homeTheme:
        return 'THEMES';
      case LootCategory.battleEffect:
        return 'EFFECTS';
    }
  }

  String get storageKey {
    switch (this) {
      case LootCategory.avatarFrame:
        return 'frame';
      case LootCategory.titleBadge:
        return 'title';
      case LootCategory.homeTheme:
        return 'theme';
      case LootCategory.battleEffect:
        return 'effect';
    }
  }
}

LootCategory? lootCategoryFromStorageKey(String key) {
  for (final category in LootCategory.values) {
    if (category.storageKey == key) {
      return category;
    }
  }
  return null;
}

class LootItem {
  final String id;
  final String name;
  final String description;
  final LootCategory category;
  final LootRarity rarity;
  final String assetPath;
  final int? colorValue;
  final int? bossFloor;
  final bool bossExclusive;
  final bool isDefault;

  const LootItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.assetPath,
    this.colorValue,
    this.bossFloor,
    this.bossExclusive = false,
    this.isDefault = false,
  });

  Color get color => colorValue == null ? rarity.color : Color(colorValue!);
}

class LootResult {
  final LootItem item;
  final bool isDuplicate;
  final int scrapAwarded;
  final int? floor;
  final bool isBoss;
  final DateTime timestamp;

  const LootResult({
    required this.item,
    required this.isDuplicate,
    required this.scrapAwarded,
    this.floor,
    this.isBoss = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemId': item.id,
      'isDuplicate': isDuplicate,
      'scrapAwarded': scrapAwarded,
      'floor': floor,
      'isBoss': isBoss,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
