import 'package:flutter/material.dart';

import 'loot_unlock_rule.dart';

enum LootRarity { common, uncommon, rare, epic }

enum LootCategory { avatarFrame, titleBadge, homeTheme }

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
  final bool isDefault;
  final LootUnlockRule? unlockRule;

  const LootItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.assetPath,
    this.colorValue,
    this.isDefault = false,
    this.unlockRule,
  });

  Color get color => colorValue == null ? rarity.color : Color(colorValue!);
}
