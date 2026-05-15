import '../models/loot_item.dart';

const String lootPlaceholderPath = 'assets/loot/placeholders';

const List<LootItem> lootRegistry = [
  LootItem(
    id: 'frame_iron',
    name: 'Iron Frame',
    description: 'Simple dark iron pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$lootPlaceholderPath/frame_iron.png',
    colorValue: 0xFF6B6B8A,
  ),
  LootItem(
    id: 'frame_stone',
    name: 'Stone Frame',
    description: 'Grey cobblestone border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$lootPlaceholderPath/frame_stone.png',
    colorValue: 0xFF9A9AAA,
  ),
  LootItem(
    id: 'frame_bronze',
    name: 'Bronze Frame',
    description: 'Warm bronze metallic border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$lootPlaceholderPath/frame_bronze.png',
    colorValue: 0xFFB77A3A,
  ),
  LootItem(
    id: 'frame_silver',
    name: 'Silver Frame',
    description: 'Polished silver pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$lootPlaceholderPath/frame_silver.png',
    colorValue: 0xFFC8D0E0,
  ),
  LootItem(
    id: 'frame_gold',
    name: 'Gold Frame',
    description: 'Ornate gold border with corner studs.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$lootPlaceholderPath/frame_gold.png',
    colorValue: 0xFFFFD700,
    bossFloor: 10,
    bossExclusive: true,
  ),
  LootItem(
    id: 'frame_neon',
    name: 'Neon Frame',
    description: 'Glowing green pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$lootPlaceholderPath/frame_neon.png',
    colorValue: 0xFF00FF9C,
  ),
  LootItem(
    id: 'frame_inferno',
    name: 'Inferno Frame',
    description: 'Flame border with red-orange pixels.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$lootPlaceholderPath/frame_inferno.png',
    colorValue: 0xFFFF6B1A,
    bossFloor: 40,
    bossExclusive: true,
  ),
  LootItem(
    id: 'frame_void',
    name: 'Void Frame',
    description: 'Dark purple border with pixel particles.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$lootPlaceholderPath/frame_void.png',
    colorValue: 0xFF9B59B6,
  ),
  LootItem(
    id: 'title_recruit',
    name: 'Recruit',
    description: 'Default starting title.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
    isDefault: true,
  ),
  LootItem(
    id: 'title_iron_will',
    name: 'Iron Will',
    description: 'Completed 5 dungeon floors.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
  ),
  LootItem(
    id: 'title_shadow_slayer',
    name: 'Shadow Slayer',
    description: 'Defeated 10 Shadow Rats.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
  ),
  LootItem(
    id: 'title_grinder',
    name: 'The Grinder',
    description: 'Reached floor 15.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
  ),
  LootItem(
    id: 'title_iron_warden',
    name: 'Iron Warden',
    description: 'STR reached 400.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
  ),
  LootItem(
    id: 'title_dungeon_crawler',
    name: 'Dungeon Crawler',
    description: 'Reached floor 25.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
  ),
  LootItem(
    id: 'title_golem_breaker',
    name: 'Golem Breaker',
    description: 'Defeated Boss Iron Golem.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    bossFloor: 20,
    bossExclusive: true,
  ),
  LootItem(
    id: 'title_wraith_hunter',
    name: 'Wraith Hunter',
    description: 'Defeated Boss Wraith Knight.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    bossFloor: 30,
    bossExclusive: true,
  ),
  LootItem(
    id: 'title_legend',
    name: 'Living Legend',
    description: 'Any stat reached 700.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
  ),
  LootItem(
    id: 'title_s_rank',
    name: 'S-Rank Warrior',
    description: 'Any stat reached 800.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
  ),
  LootItem(
    id: 'title_floor_master',
    name: 'Floor Master',
    description: 'Reached floor 50.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    bossFloor: 50,
    bossExclusive: true,
  ),
  LootItem(
    id: 'title_ironbit',
    name: 'IRONBIT',
    description: 'All 4 stats above 600.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
  ),
  LootItem(
    id: 'theme_default',
    name: 'Default Dungeon',
    description: 'Current dark dungeon cards.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.common,
    assetPath: '$lootPlaceholderPath/theme_default.png',
    colorValue: 0xFF1A1A2E,
    isDefault: true,
  ),
  LootItem(
    id: 'theme_stone',
    name: 'Stone Crypt',
    description: 'Dark grey stone card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.uncommon,
    assetPath: '$lootPlaceholderPath/theme_stone.png',
    colorValue: 0xFF2A2A3E,
  ),
  LootItem(
    id: 'theme_forest',
    name: 'Dark Forest',
    description: 'Deep green card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.rare,
    assetPath: '$lootPlaceholderPath/theme_forest.png',
    colorValue: 0xFF123A2A,
  ),
  LootItem(
    id: 'theme_inferno',
    name: 'Inferno Depths',
    description: 'Dark ember card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.epic,
    assetPath: '$lootPlaceholderPath/theme_inferno.png',
    colorValue: 0xFF3A1717,
  ),
  LootItem(
    id: 'effect_default',
    name: 'Neon Strike',
    description: 'Default green hit flash.',
    category: LootCategory.battleEffect,
    rarity: LootRarity.common,
    assetPath: '$lootPlaceholderPath/effect_default.png',
    colorValue: 0xFF00FF9C,
    isDefault: true,
  ),
  LootItem(
    id: 'effect_frost',
    name: 'Frost Strike',
    description: 'Cyan hit flash.',
    category: LootCategory.battleEffect,
    rarity: LootRarity.uncommon,
    assetPath: '$lootPlaceholderPath/effect_frost.png',
    colorValue: 0xFF00BFFF,
  ),
  LootItem(
    id: 'effect_solar',
    name: 'Solar Strike',
    description: 'Gold hit flash.',
    category: LootCategory.battleEffect,
    rarity: LootRarity.rare,
    assetPath: '$lootPlaceholderPath/effect_solar.png',
    colorValue: 0xFFFFD700,
  ),
  LootItem(
    id: 'effect_void',
    name: 'Void Strike',
    description: 'Purple hit flash.',
    category: LootCategory.battleEffect,
    rarity: LootRarity.epic,
    assetPath: '$lootPlaceholderPath/effect_void.png',
    colorValue: 0xFF9B59B6,
  ),
];

const String commonChestAsset = '$lootPlaceholderPath/chest_common.png';
const String bossChestAsset = '$lootPlaceholderPath/chest_boss.png';

LootItem? lootItemById(String id) {
  for (final item in lootRegistry) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

List<String> get defaultLootIds {
  return lootRegistry
      .where((item) => item.isDefault)
      .map((item) => item.id)
      .toList();
}

List<LootItem> get normalLootPool {
  return lootRegistry
      .where((item) => !item.isDefault && !item.bossExclusive)
      .toList(growable: false);
}

LootItem bossLootForFloor(int floor) {
  final exact = lootRegistry.where((item) => item.bossFloor == floor).toList();
  if (exact.isNotEmpty) {
    return exact.first;
  }

  final bossDrops = lootRegistry
      .where((item) => item.bossExclusive)
      .toList(growable: false);
  final bossIndex = ((floor ~/ 10) - 1) % bossDrops.length;
  return bossDrops[bossIndex];
}
