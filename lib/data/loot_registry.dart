import '../models/loot_item.dart';
import '../models/loot_unlock_rule.dart';

const String unlockFramePath = 'assets/unlocks/frames';
const String unlockThemePath = 'assets/unlocks/themes';

const List<LootItem> lootRegistry = [
  LootItem(
    id: 'frame_iron',
    name: 'Iron Frame',
    description: 'Simple dark iron pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$unlockFramePath/frame_iron.png',
    colorValue: 0xFF6B6B8A,
    isDefault: true,
  ),
  LootItem(
    id: 'frame_stone',
    name: 'Stone Frame',
    description: 'Grey cobblestone border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$unlockFramePath/frame_stone.png',
    colorValue: 0xFF9A9AAA,
  ),
  LootItem(
    id: 'frame_bronze',
    name: 'Bronze Frame',
    description: 'Warm bronze metallic border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockFramePath/frame_bronze.png',
    colorValue: 0xFFB77A3A,
  ),
  LootItem(
    id: 'frame_silver',
    name: 'Silver Frame',
    description: 'Polished silver pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockFramePath/frame_silver.png',
    colorValue: 0xFFC8D0E0,
  ),
  LootItem(
    id: 'frame_gold',
    name: 'Gold Frame',
    description: 'Ornate gold border. 500 lifetime reps.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$unlockFramePath/frame_gold.png',
    colorValue: 0xFFFFD700,
    unlockRule: LootUnlockRule(kind: UnlockKind.lifetimeReps, threshold: 500),
  ),
  LootItem(
    id: 'frame_neon',
    name: 'Neon Frame',
    description: 'Glowing green pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$unlockFramePath/frame_neon.png',
    colorValue: 0xFF00FF9C,
  ),
  LootItem(
    id: 'frame_inferno',
    name: 'Inferno Frame',
    description: 'Flame border. 25,000 kg lifetime volume.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$unlockFramePath/frame_inferno.png',
    colorValue: 0xFFFF6B1A,
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 25000,
    ),
  ),
  LootItem(
    id: 'frame_void',
    name: 'Void Frame',
    description: 'Dark purple border with pixel particles.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$unlockFramePath/frame_void.png',
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
    description: 'Completed 25 workout sessions.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 25),
  ),
  LootItem(
    id: 'title_shadow_slayer',
    name: 'Shadow Slayer',
    description: 'Completed 10 chest sessions.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleSessions,
      threshold: 10,
      muscleGroup: 'Chest',
    ),
  ),
  LootItem(
    id: 'title_grinder',
    name: 'The Grinder',
    description: '10,000 kg lifetime volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 10000,
    ),
  ),
  LootItem(
    id: 'title_iron_warden',
    name: 'Iron Warden',
    description: 'STR reached 400.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.statThreshold,
      threshold: 400,
      statKey: 'STR',
    ),
  ),
  LootItem(
    id: 'title_dungeon_crawler',
    name: 'Gym Veteran',
    description: 'Completed 50 workout sessions.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 50),
  ),
  LootItem(
    id: 'title_golem_breaker',
    name: 'Golem Breaker',
    description: '5,000 kg chest volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 5000,
      muscleGroup: 'Chest',
    ),
  ),
  LootItem(
    id: 'title_wraith_hunter',
    name: 'Wraith Hunter',
    description: '10,000 kg back volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 10000,
      muscleGroup: 'Back',
    ),
  ),
  LootItem(
    id: 'title_legend',
    name: 'Living Legend',
    description: 'Any stat reached 700.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.anyStatThreshold,
      threshold: 700,
    ),
  ),
  LootItem(
    id: 'title_s_rank',
    name: 'S-Rank Warrior',
    description: 'Any stat reached 800.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.anyStatThreshold,
      threshold: 800,
    ),
  ),
  LootItem(
    id: 'title_floor_master',
    name: 'Floor Master',
    description: '100,000 kg lifetime volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 100000,
    ),
  ),
  LootItem(
    id: 'title_ironbit',
    name: 'IRONBIT',
    description: 'All 4 stats above 600.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    unlockRule: LootUnlockRule(kind: UnlockKind.allStatsAbove, threshold: 600),
  ),
  LootItem(
    id: 'theme_default',
    name: 'Default Arcade',
    description: 'Current dark arcade cards.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.common,
    assetPath: '$unlockThemePath/theme_default.png',
    colorValue: 0xFF1A1A2E,
    isDefault: true,
  ),
  LootItem(
    id: 'theme_stone',
    name: 'Stone Crypt',
    description: 'Dark grey stone card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockThemePath/theme_stone.png',
    colorValue: 0xFF2A2A3E,
  ),
  LootItem(
    id: 'theme_forest',
    name: 'Dark Forest',
    description: 'Deep green card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.rare,
    assetPath: '$unlockThemePath/theme_forest.png',
    colorValue: 0xFF123A2A,
  ),
  LootItem(
    id: 'theme_inferno',
    name: 'Inferno Depths',
    description: 'Dark ember card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.epic,
    assetPath: '$unlockThemePath/theme_inferno.png',
    colorValue: 0xFF3A1717,
  ),
];

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
