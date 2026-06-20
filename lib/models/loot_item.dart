import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'loot_unlock_rule.dart';
import 'unit_models.dart';

enum LootRarity { common, uncommon, rare, epic, legendary }

enum LootCategory { avatarFrame, titleBadge }

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
      case LootRarity.legendary:
        return 'LEGENDARY';
    }
  }

  Color get color {
    switch (this) {
      case LootRarity.common:
        return kRarityCommon;
      case LootRarity.uncommon:
        return kRarityUncommon;
      case LootRarity.rare:
        return kRarityRare;
      case LootRarity.epic:
        return kRarityEpic;
      case LootRarity.legendary:
        return kRarityLegendary;
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
    }
  }

  String get storageKey {
    switch (this) {
      case LootCategory.avatarFrame:
        return 'frame';
      case LootCategory.titleBadge:
        return 'title';
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
  final int? gemPrice;
  final bool isDefault;
  final LootUnlockRule? unlockRule;

  /// Number of frames for an animated avatar-frame asset (1 = static). Animated
  /// frames live at `<dir>/<id>_<i>.png`; [assetPath] points at frame 0 — the
  /// poster shown in grids and as the reduced-motion still.
  final int frameCount;

  const LootItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.assetPath,
    this.colorValue,
    this.gemPrice,
    this.isDefault = false,
    this.unlockRule,
    this.frameCount = 1,
  });

  Color get color => colorValue == null ? rarity.color : Color(colorValue!);

  /// Asset path of animation frame [i] (0-based); static frames ignore [i] and
  /// always return [assetPath].
  String frameAt(int i) => frameCount <= 1
      ? assetPath
      : assetPath.replaceFirst(RegExp(r'_0\.png$'), '_$i.png');

  /// Description rendered in the active weight [unit]. For volume-gated loot the
  /// threshold clause is built from [unlockRule] (stored kg) so it converts;
  /// [description] holds only the flavor prefix for those items. All other loot
  /// returns [description] unchanged.
  String displayDescription(WeightUnit unit) {
    final rule = unlockRule;
    if (rule != null &&
        (rule.kind == UnlockKind.lifetimeVolume ||
            rule.kind == UnlockKind.muscleVolume)) {
      final scope = rule.kind == UnlockKind.lifetimeVolume
          ? 'lifetime'
          : (rule.muscleGroup?.toLowerCase() ?? 'focused');
      final clause =
          '${volumeThresholdLabel(rule.threshold.toDouble(), unit)} $scope volume.';
      return description.isEmpty ? clause : '$description $clause';
    }
    return description;
  }
}
