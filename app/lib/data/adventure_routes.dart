import 'dart:ui';

import '../models/character_class.dart';
import '../models/loot_item.dart';
import '../theme/tokens.dart';

/// Static registry for Adventure: the three stat-keyed routes and the
/// finds (lore-junk flavor items). Routes are all open from day one — the
/// rank on a route's stat sets the pay tier; nothing here grants power.
class AdventureRouteDef {
  const AdventureRouteDef({
    required this.id,
    required this.name,
    required this.statKey,
    required this.accent,
    required this.emblemAsset,
    required this.skyAsset,
    required this.farAsset,
    required this.groundAsset,
    required this.scrollSpeed,
    required this.walkLineNative,
    required this.flavorLines,
  });

  final String id;
  final String name;

  /// Which visible stat (STR/AGI/END) sets this route's pay tier.
  final String statKey;

  /// Route accent — mirrors the class colors so the world map teaches the
  /// stat system (STR=Bruiser red-family ember, AGI=Assassin violet,
  /// END=Tank cyan).
  final Color accent;

  final String emblemAsset;
  final String skyAsset;
  final String farAsset;
  final String groundAsset;

  /// Ground-layer scroll speed in native (480-wide) pixels per second;
  /// matches the standalone HTML demo's per-route tuning.
  final double scrollSpeed;

  /// The route's walk-line Y in native (270-tall) scene pixels — where a
  /// traveller's contact point lands. BIT's native y29 anchors here so he
  /// hovers with his body above the line. Mirrors the BIT-Walk handoff.
  final double walkLineNative;

  /// Report flavor lines; one is picked (seeded) at dispatch.
  final List<String> flavorLines;
}

const String _routeAssetBase = 'assets/adventure';

const List<AdventureRouteDef> adventureRoutes = [
  AdventureRouteDef(
    id: 'iron_vault',
    name: 'IRON VAULT',
    statKey: 'STR',
    accent: Color(0xFFFF6A3D), // ember — kDanger family
    emblemAsset: '$_routeAssetBase/emblem_iron_vault.png',
    skyAsset: '$_routeAssetBase/iron_vault_sky.png',
    farAsset: '$_routeAssetBase/iron_vault_far.png',
    groundAsset: '$_routeAssetBase/iron_vault_ground.png',
    scrollSpeed: 36,
    walkLineNative: 182,
    flavorLines: [
      'The vault gate did not open. It nodded.',
      'Ember seams glowed brighter where you walked.',
      'Something heavy was lifted here, long ago. It remembers.',
      'The furnaces slept. Your footsteps kept the heat.',
      'A chain swung once as you passed. No wind.',
    ],
  ),
  AdventureRouteDef(
    id: 'sky_tracer',
    name: 'SKY TRACER',
    statKey: 'AGI',
    accent: Color(0xFFB14DFF), // Assassin violet
    emblemAsset: '$_routeAssetBase/emblem_sky_tracer.png',
    skyAsset: '$_routeAssetBase/sky_tracer_sky.png',
    farAsset: '$_routeAssetBase/sky_tracer_far.png',
    groundAsset: '$_routeAssetBase/sky_tracer_ground.png',
    scrollSpeed: 48,
    walkLineNative: 180,
    flavorLines: [
      'The rail hummed under a sure step.',
      'One gap was wider than it looked. You were faster.',
      'The antenna lights blinked in sequence behind you.',
      'Above the clouds, nothing argues with momentum.',
      'A jetstream carried your trace a little further.',
    ],
  ),
  AdventureRouteDef(
    id: 'infini_maze',
    name: 'INFINI MAZE',
    statKey: 'END',
    accent: kCyan, // Tank cyan
    emblemAsset: '$_routeAssetBase/emblem_infini_maze.png',
    skyAsset: '$_routeAssetBase/infini_maze_sky.png',
    farAsset: '$_routeAssetBase/infini_maze_far.png',
    groundAsset: '$_routeAssetBase/infini_maze_ground.png',
    scrollSpeed: 28,
    walkLineNative: 180,
    flavorLines: [
      'The maze added a corridor. You added a mile.',
      'Every archway looked the same. You did not stop to check.',
      'The rune-seams pulsed once per step. Steady.',
      'No exit found. None needed.',
      'The walls keep count. The count is in your favor.',
    ],
  ),
];

AdventureRouteDef adventureRouteById(String? id) {
  for (final route in adventureRoutes) {
    if (route.id == id) return route;
  }
  return adventureRoutes.first;
}

/// Silent default orders — the class-matched route (Bruiser→Iron Vault,
/// Assassin→Sky Tracer, Tank→Infini Maze). The first report explains this
/// and offers CHANGE ORDERS (legibility rule).
AdventureRouteDef defaultRouteForClass(CharacterClass cls) => switch (cls) {
  CharacterClass.bruiser => adventureRoutes[0],
  CharacterClass.assassin => adventureRoutes[1],
  CharacterClass.tank => adventureRoutes[2],
};

/// A find: lore-junk the character brings back. Pure collection charm —
/// no power, no gem value, not part of the loot/equip system.
class AdventureFindDef {
  const AdventureFindDef({
    required this.id,
    required this.name,
    required this.rarity,
    required this.iconAsset,
  });

  final String id;
  final String name;
  final LootRarity rarity;
  final String iconAsset;
}

const String _findAssetBase = 'assets/adventure/loot';

const List<AdventureFindDef> adventureFinds = [
  AdventureFindDef(
    id: 'rusted_key',
    name: 'Rusted Key',
    rarity: LootRarity.common,
    iconAsset: '$_findAssetBase/loot_rusted_key.png',
  ),
  AdventureFindDef(
    id: 'chain_coil',
    name: 'Coil of Chain',
    rarity: LootRarity.common,
    iconAsset: '$_findAssetBase/loot_chain_coil.png',
  ),
  AdventureFindDef(
    id: 'forge_rivet',
    name: 'Forge Rivet',
    rarity: LootRarity.common,
    iconAsset: '$_findAssetBase/loot_forge_rivet.png',
  ),
  AdventureFindDef(
    id: 'waterskin',
    name: 'Old Waterskin',
    rarity: LootRarity.common,
    iconAsset: '$_findAssetBase/loot_waterskin.png',
  ),
  AdventureFindDef(
    id: 'road_token',
    name: 'Road Token',
    rarity: LootRarity.uncommon,
    iconAsset: '$_findAssetBase/loot_road_token.png',
  ),
  AdventureFindDef(
    id: 'banner_scrap',
    name: 'Banner Scrap',
    rarity: LootRarity.uncommon,
    iconAsset: '$_findAssetBase/loot_banner_scrap.png',
  ),
  AdventureFindDef(
    id: 'folded_map',
    name: 'Folded Map',
    rarity: LootRarity.uncommon,
    iconAsset: '$_findAssetBase/loot_folded_map.png',
  ),
  AdventureFindDef(
    id: 'ember_stone',
    name: 'Cracked Ember Stone',
    rarity: LootRarity.rare,
    iconAsset: '$_findAssetBase/loot_ember_stone.png',
  ),
  AdventureFindDef(
    id: 'spire_shard',
    name: 'Spire Shard',
    rarity: LootRarity.rare,
    iconAsset: '$_findAssetBase/loot_spire_shard.png',
  ),
  AdventureFindDef(
    id: 'beacon_lens',
    name: 'Beacon Lens',
    rarity: LootRarity.epic,
    iconAsset: '$_findAssetBase/loot_beacon_lens.png',
  ),
  AdventureFindDef(
    id: 'hollow_compass',
    name: 'Compass Without a Needle',
    rarity: LootRarity.epic,
    iconAsset: '$_findAssetBase/loot_hollow_compass.png',
  ),
  AdventureFindDef(
    id: 'phosphor_moth',
    name: 'Phosphor Moth',
    rarity: LootRarity.legendary,
    iconAsset: '$_findAssetBase/loot_phosphor_moth.png',
  ),
];

AdventureFindDef? adventureFindById(String? id) {
  if (id == null) return null;
  for (final find in adventureFinds) {
    if (find.id == id) return find;
  }
  return null;
}
