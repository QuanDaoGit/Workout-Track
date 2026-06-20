import 'package:flutter/material.dart';

// Palette — single source of truth for arcade theme colors.
const kBg = Color(0xFF11111F);
const kBgGradientTop = Color(0xFF15152C);
const kBgGradientBottom = Color(0xFF0E0E1B);
const kCard = Color(0xFF1C1C34);
const kSurface2 = Color(0xFF232342);
const kSurface3 = Color(0xFF2A2A4E);
const kBorder = Color(0xFF36365E);
const kBorderVariant = Color(0xFF45437A);
const kBorderDark = Color(0xFF2A2A3E);
const kNeon = Color(0xFF00FF9C);
const kNeonDark = Color(0xFF009955);
const kText = Color(0xFFE8E8FF);
const kMutedText = Color(0xFF9494B8);
const kDim = Color(0xFF555577);

/// Pure white / black — the only sanctioned use of these absolutes (the
/// Material palette white/black are banned). For button text on bright fills,
/// letterbox/video backdrops, scrims, and effect flashes.
const kWhite = Color(0xFFFFFFFF);
const kBlack = Color(0xFF000000);

// Accent colors — officially part of the palette as of this UI polish pass.
/// Level-up / reward signal. Used wherever the app celebrates progression:
/// bench scene "+1 LV", Screen 3 "LEVELS YOU UP" slam, RANK UP! callouts,
/// the onboarding handoff iris. kNeon is the brand / tap-target color; kAmber
/// is reserved for "you just leveled up."
const kAmber = Color(0xFFFFD700);
const kAmberDark = Color(0xFFFFA500);
const kCyan = Color(0xFF00BFFF);
const kDanger = Color(0xFFFF2D55);

/// Gem / haul magenta — the currency colour (sampled from the gem-art ramp
/// core). Use for UI text/accents that reference gems or a haul (e.g. BIT's
/// "loots" prompt). Contrast on [kCard] ≈ 5.7:1 (passes 4.5:1). The dithered
/// procedural haul ramp (`_magentaTiers`) stays separate art, not this token.
const kGemMagenta = Color(0xFFFF4DCD);

// ── Semantic / functional roles ──────────────────────────────────────────────
// These encode MEANING (quality ladders), not brand. They hold their own fixed
// values so a brand recolor of the accents above never silently scrambles the
// rank or rarity ladders. UI consumes these; only the brand accents re-theme.

/// Muted neutral slate — lowest rank tier + a muted calendar marker.
const kSlate = Color(0xFF6B6B8A);

/// Rank tiers (`StatEngine.getRankColor`) — a stable S→D quality gradient.
const kRankS = Color(0xFF00FF9C);
const kRankA = Color(0xFFFFD700);
const kRankB = Color(0xFF00BFFF);
const kRankC = Color(0xFFFFFFFF);
const kRankD = kSlate;

/// Loot rarity (`LootRarity.color`) — follows the cross-game convention
/// (common white · uncommon green · rare blue · epic purple · legendary gold)
/// so players read quality the way they do in every other RPG. Brand-independent.
const kRarityCommon = Color(0xFFFFFFFF);
const kRarityUncommon = Color(0xFF00FF9C);
const kRarityRare = Color(0xFF00BFFF);
const kRarityEpic = Color(0xFFA66BFF);
const kRarityLegendary = Color(0xFFFFD700);

/// Canonical color per muscle-group bucket (see data/muscle_groups.dart).
/// Single source of truth for calendars, charts, and balance bars.
const Map<String, Color> kMuscleGroupColors = {
  'Chest': kNeon,
  'Back': kAmber,
  'Shoulders': Color(0xFF9B59B6),
  'Arms': kDanger,
  'Legs': kCyan,
  'Core': Color(0xFFFF6B1A),
  'Full Body': kText,
};

// Spacing scale (4/8/12/16/24).
const kSpace1 = 4.0;
const kSpace2 = 8.0;
const kSpace3 = 12.0;
const kSpace4 = 16.0;
const kSpace5 = 24.0;

// Shared layout rules for primary mobile surfaces.
const kHomeHorizontalPadding = 16.0;
const kCardPadding = 16.0;
const kCardRadius = 4.0;
const kSectionGap = 16.0;
const kButtonHeight = 48.0;
const kPrimaryCardBorderWidth = 1.2;

// Motion — shared durations + easing for arcade interactions.
const kMotionFast = Duration(milliseconds: 120);
const kMotionBase = Duration(milliseconds: 180);
const kMotionPop = Duration(milliseconds: 220);
const Curve kMotionCurve = Curves.easeOutCubic;

// Focused neon bloom for emissive depth on dark surfaces.
List<BoxShadow> neonGlow({
  Color color = kNeon,
  double opacity = 0.22,
  double blur = 16,
}) => [
  BoxShadow(
    color: color.withValues(alpha: opacity),
    blurRadius: blur,
    spreadRadius: -2,
  ),
];
