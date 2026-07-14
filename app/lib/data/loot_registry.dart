import '../models/loot_item.dart';
import '../models/loot_unlock_rule.dart';

const String unlockFramePath = 'assets/unlocks/avatar_frames';

const List<LootItem> lootRegistry = [
  LootItem(
    id: 'frame_iron',
    name: 'Iron Frame',
    description: 'Simple dark iron pixel border.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$unlockFramePath/iron/iron.png',
    colorValue: 0xFF6B6B8A,
    isDefault: true,
  ),
  LootItem(
    id: 'frame_stone',
    name: 'Stone Frame',
    description: 'Grey cobblestone border. 4 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.common,
    assetPath: '$unlockFramePath/stone/stone.png',
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
    assetPath: '$unlockFramePath/bronze/bronze.png',
    colorValue: 0xFFB77A3A,
    gemPrice: 300,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 8),
  ),
  LootItem(
    id: 'frame_silver',
    name: 'Silver Frame',
    description: 'Polished silver pixel border. 14 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.uncommon,
    assetPath: '$unlockFramePath/silver/silver.png',
    colorValue: 0xFFC8D0E0,
    gemPrice: 600,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 14),
  ),
  LootItem(
    id: 'frame_gold',
    name: 'Gold Frame',
    description: 'Ornate gold border. 22 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$unlockFramePath/gold/gold.png',
    colorValue: 0xFFFFD700,
    gemPrice: 1200,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 22),
  ),
  LootItem(
    id: 'frame_neon',
    name: 'Neon Frame',
    description: 'Glowing green pixel border. 30 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.rare,
    assetPath: '$unlockFramePath/neon/neon.png',
    colorValue: 0xFF00FF9C,
    gemPrice: 2000,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 30),
  ),
  LootItem(
    id: 'frame_inferno',
    name: 'Inferno Frame',
    description: 'Flame border. 40 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$unlockFramePath/inferno/inferno_0.png',
    colorValue: 0xFFFF6B1A,
    gemPrice: 3500,
    frameCount: 10,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 40),
  ),
  LootItem(
    id: 'frame_void',
    name: 'Void Frame',
    description:
        'Dark purple border with pixel particles. 52 completed sessions.',
    category: LootCategory.avatarFrame,
    rarity: LootRarity.epic,
    assetPath: '$unlockFramePath/void/void_0.png',
    colorValue: 0xFF9B59B6,
    gemPrice: 6000,
    frameCount: 10,
    unlockRule: LootUnlockRule(kind: UnlockKind.sessions, threshold: 52),
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
  // Frozen (grandfathered): the chest-sessions outlier was retired when the
  // per-muscle ladder unified onto muscleVolume (Chest now = Golem Breaker).
  // Ruleless so it's never newly granted, but the item is kept so existing
  // owners keep it owned + equipped — no destructive migration, no cleared card.
  LootItem(
    id: 'title_shadow_slayer',
    name: 'Shadow Slayer',
    description: 'Completed 10 chest sessions.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
  ),
  LootItem(
    id: 'title_grinder',
    name: 'The Grinder',
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.lifetimeVolume,
      threshold: 100000,
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
  // Per-muscle ladder: one rare title per trainable group on a uniform
  // 8,000 kg muscleVolume threshold (symmetric collection — Chest/Back/
  // Shoulders/Arms/Legs/Core). Legs accrue volume faster than Core, so they
  // arrive in training order; that's fine for a collectible.
  LootItem(
    id: 'title_golem_breaker',
    name: 'Golem Breaker',
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 8000,
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
      threshold: 8000,
      muscleGroup: 'Back',
    ),
  ),
  LootItem(
    id: 'title_skybreaker',
    name: 'Skybreaker',
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 8000,
      muscleGroup: 'Shoulders',
    ),
  ),
  LootItem(
    id: 'title_gauntlet',
    name: 'Gauntlet',
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 8000,
      muscleGroup: 'Arms',
    ),
  ),
  LootItem(
    id: 'title_colossus',
    name: 'Colossus',
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 8000,
      muscleGroup: 'Legs',
    ),
  ),
  LootItem(
    id: 'title_keystone',
    name: 'Keystone',
    description: '',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
    unlockRule: LootUnlockRule(
      kind: UnlockKind.muscleVolume,
      threshold: 8000,
      muscleGroup: 'Core',
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
  // Side-quest title display names were renamed 2026-06; the loot IDs are kept
  // stable so already-earned/equipped titles survive (they show the new name).
  LootItem(
    id: 'title_iron_novice',
    name: 'A New Dawn',
    description: 'Completed your first workout.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.common,
    assetPath: '',
  ),
  LootItem(
    id: 'title_set_smith',
    name: 'Set Smith',
    description: 'Saved 25 total sets.',
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
    name: 'Juggler',
    description: 'Trained Chest, Back, Arms, and Legs.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.uncommon,
    assetPath: '',
  ),
  LootItem(
    id: 'title_volume_knight',
    name: 'Elephant Lifter',
    description: 'Reached 10,000 kg total volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
  ),
  LootItem(
    id: 'title_centurion',
    name: 'Centurion',
    description: 'Completed 100 total workouts.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
  ),
  LootItem(
    id: 'title_long_live',
    name: 'Long Live',
    description: 'Trained 3,000 total minutes.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
  ),
  LootItem(
    id: 'title_whale_lifter',
    name: 'Whale Lifter',
    description: 'Reached 50,000 kg total volume.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
  ),
  LootItem(
    id: 'title_guildmaster',
    name: 'Guildmaster',
    description: 'Trained all 7 muscle groups.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.rare,
    assetPath: '',
  ),
  LootItem(
    id: 'title_apex_1000',
    name: 'Apex 1000',
    description: 'Saved 1,000 total sets.',
    category: LootCategory.titleBadge,
    rarity: LootRarity.epic,
    assetPath: '',
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
  'side_workouts_100': 'title_centurion',
  'side_minutes_3000': 'title_long_live',
  'side_volume_50000': 'title_whale_lifter',
  'side_all_seven': 'title_guildmaster',
  'side_sets_1000': 'title_apex_1000',
};

/// Reverse lookup keyed by the historical reward-title display string, used by
/// the one-time title-unification migration to backfill existing claims.
const Map<String, String> questTitleNameToLootId = {
  // Current display names.
  'A New Dawn': 'title_iron_novice',
  'Set Smith': 'title_set_smith',
  'Time Keeper': 'title_time_keeper',
  'Juggler': 'title_guild_walker',
  'Elephant Lifter': 'title_volume_knight',
  'Centurion': 'title_centurion',
  'Long Live': 'title_long_live',
  'Whale Lifter': 'title_whale_lifter',
  'Guildmaster': 'title_guildmaster',
  'Apex 1000': 'title_apex_1000',
  // Legacy aliases: keep historical reward-title strings resolving after renames.
  'Iron Novice': 'title_iron_novice',
  'Guild Walker': 'title_guild_walker',
  'Volume Knight': 'title_volume_knight',
  // The time quest's title was renamed Oath Keeper → Time Keeper.
  'Oath Keeper': 'title_time_keeper',
};
