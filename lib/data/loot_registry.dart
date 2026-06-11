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
    description: 'Grey cobblestone border. 4 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$unlockFramePath/frame_stone.png',
    colorValue: 0xFF9A9AAA,
    gemPrice: 150,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 4),
  ),
  LootItem(
    id: 'frame_bronze',
    name: 'Bronze Frame',
    description: 'Warm bronze metallic border. 8 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockFramePath/frame_bronze.png',
    colorValue: 0xFFB77A3A,
    gemPrice: 300,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 8),
  ),
  LootItem(
    id: 'frame_silver',
    name: 'Silver Frame',
    description: 'Polished silver pixel border. 1,000 lifetime reps.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockFramePath/frame_silver.png',
    colorValue: 0xFFC8D0E0,
    gemPrice: 600,
    unlockRule: LootUnlockRule(kind: UnlockKind.lifetimeReps, threshold: 1000),
  ),
  LootItem(
    id: 'frame_gold',
    name: 'Gold Frame',
    description: 'Ornate gold border. 500 lifetime reps.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$unlockFramePath/frame_gold.png',
    colorValue: 0xFFFFD700,
    gemPrice: 1200,
    unlockRule: LootUnlockRule(kind: UnlockKind.lifetimeReps, threshold: 500),
  ),
  LootItem(
    id: 'frame_neon',
    name: 'Neon Frame',
    description: 'Glowing green pixel border. 16 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$unlockFramePath/frame_neon.png',
    colorValue: 0xFF00FF9C,
    gemPrice: 2000,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 16),
  ),
  LootItem(
    id: 'frame_inferno',
    name: 'Inferno Frame',
    description: 'Flame border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$unlockFramePath/frame_inferno.png',
    colorValue: 0xFFFF6B1A,
    gemPrice: 3500,
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 120000,
    ),
  ),
  LootItem(
    id: 'frame_void',
    name: 'Void Frame',
    description:
        'Dark purple border with pixel particles. 42 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$unlockFramePath/frame_void.png',
    colorValue: 0xFF9B59B6,
    gemPrice: 6000,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 42),
  ),
  LootItem(
    id: 'frame_spectral',
    name: 'Spectral Frame',
    description: 'Ghost-light border left behind by a bested Shadow.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    // Asset deferred — LootAvatarFrame's errorBuilder renders the colorValue
    // placeholder until real art lands. Granted only by ShadowService
    // (no unlockRule, no gemPrice).
    assetPath: '$unlockFramePath/frame_spectral.png',
    colorValue: 0xFF7FD4E8,
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
    id: 'title_shadowbane',
    name: 'Shadowbane',
    description: 'Outpaced your own Shadow at full strength.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    // Granted only by ShadowService on the first genuine defeat.
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
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 55000,
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
    description: '',
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
    description: '',
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
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 200000,
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
  // Program-completion titles. Ruleless (no unlockRule) — granted imperatively
  // by ProgramService.evaluateCompletion when a program arc reaches its target,
  // never by LootService.evaluateUnlocks. See programTitleId in programs_library.
  LootItem(
    id: 'title_foundation_forged',
    name: 'FOUNDATION FORGED',
    description: 'Completed the Full Body 3X program.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.legendary,
    assetPath: '',
  ),
  LootItem(
    id: 'title_iron_rhythm',
    name: 'IRON RHYTHM',
    description: 'Completed the Upper Lower program.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.legendary,
    assetPath: '',
  ),
  LootItem(
    id: 'title_split_discipline',
    name: 'SPLIT DISCIPLINE',
    description: 'Completed the Push Pull Legs program.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.legendary,
    assetPath: '',
  ),
  // Side-quest reward titles. Ruleless: granted imperatively by
  // QuestService.claimReward (and equipped the first time), never by
  // LootService.evaluateUnlocks. See sideQuestTitleLootId below.
  LootItem(
    id: 'title_iron_novice',
    name: 'Iron Novice',
    description: 'Completed your first workout.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
  ),
  LootItem(
    id: 'title_set_smith',
    name: 'Set Smith',
    description: 'Logged 25 total sets.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
  ),
  LootItem(
    id: 'title_time_keeper',
    name: 'Time Keeper',
    description: 'Trained 300 total minutes.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
  ),
  LootItem(
    id: 'title_guild_walker',
    name: 'Guild Walker',
    description: 'Trained Chest, Back, Arms, and Legs.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
  ),
  LootItem(
    id: 'title_volume_knight',
    name: 'Volume Knight',
    description: 'Reached 10,000 kg total volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
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
    description: 'Dark grey stone card tint. 12 completed sessions.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockThemePath/theme_stone.png',
    colorValue: 0xFF2A2A3E,
    gemPrice: 300,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 12),
  ),
  LootItem(
    id: 'theme_forest',
    name: 'Dark Forest',
    description: 'Deep green card tint. 32 completed sessions.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.rare,
    assetPath: '$unlockThemePath/theme_forest.png',
    colorValue: 0xFF123A2A,
    gemPrice: 1200,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 32),
  ),
  LootItem(
    id: 'theme_inferno',
    name: 'Inferno Depths',
    description: 'Dark ember card tint.',
    category: LootCategory.homeTheme,
    rarity: LootRarity.epic,
    assetPath: '$unlockThemePath/theme_inferno.png',
    colorValue: 0xFF3A1717,
    gemPrice: 3500,
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 180000,
    ),
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

/// Side-quest reward titles, granted as loot when the quest is claimed (and
/// equipped the first time it's earned). Quest template id → loot titleBadge id.
const Map<String, String> sideQuestTitleLootId = {
  'side_first_workout': 'title_iron_novice',
  'side_sets_25': 'title_set_smith',
  'side_minutes_300': 'title_time_keeper',
  'side_all_muscles': 'title_guild_walker',
  'side_volume_10000': 'title_volume_knight',
};

/// Reverse lookup keyed by the historical reward-title display string, used by
/// the one-time title-unification migration to backfill existing claims.
const Map<String, String> questTitleNameToLootId = {
  'Iron Novice': 'title_iron_novice',
  'Set Smith': 'title_set_smith',
  'Time Keeper': 'title_time_keeper',
  'Guild Walker': 'title_guild_walker',
  'Volume Knight': 'title_volume_knight',
  // Legacy alias: the time quest's title was renamed Oath Keeper → Time Keeper.
  'Oath Keeper': 'title_time_keeper',
};
