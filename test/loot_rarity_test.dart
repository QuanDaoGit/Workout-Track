import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/loot_registry.dart';
import 'package:workout_track/models/loot_drop.dart';
import 'package:workout_track/models/loot_item.dart';

void main() {
  test('loot rarity labels and colors use the unified RPG palette', () {
    expect(LootRarity.common.label, 'COMMON');
    expect(LootRarity.uncommon.label, 'UNCOMMON');
    expect(LootRarity.rare.label, 'RARE');
    expect(LootRarity.epic.label, 'EPIC');
    expect(LootRarity.legendary.label, 'LEGENDARY');

    expect(LootRarity.common.color, Colors.white);
    expect(LootRarity.uncommon.color, const Color(0xFF00FF9C));
    expect(LootRarity.rare.color, const Color(0xFF00BFFF));
    expect(LootRarity.epic.color, const Color(0xFFA66BFF));
    expect(LootRarity.legendary.color, const Color(0xFFFFD700));
  });

  test('program completion titles are deterministic legendary rewards', () {
    expect(
      lootItemById('title_foundation_forged')?.rarity,
      LootRarity.legendary,
    );
    expect(lootItemById('title_iron_rhythm')?.rarity, LootRarity.legendary);
    expect(
      lootItemById('title_split_discipline')?.rarity,
      LootRarity.legendary,
    );
  });

  test('bonus cache drop tiers still max at epic', () {
    expect(LootDropTier.values.map((tier) => tier.name), [
      'common',
      'uncommon',
      'rare',
      'epic',
    ]);
  });
}
