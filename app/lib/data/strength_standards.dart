import '../models/user_profile_sex.dart';

/// Strength tiers used only for workout-derived calibration runs. Ordered
/// weakest -> strongest.
enum StrengthTier { untrained, beginner, intermediate, advanced, elite }

/// Relative-strength + tier model for onboarding calibration.
///
/// Thresholds are ratios of estimated 1RM to bodyweight on a primary compound
/// lift. They are intentionally coarse and tunable. Assumptions:
///  - Male thresholds anchored on upper-body push (intermediate ≈ 1.25× BW,
///    matching the onboarding plan's reference point).
///  - Female thresholds ≈ 0.65× the male thresholds.
///  - "Prefer not to say" blends male/female (midpoint multiplier).
/// The same table is applied per combat stat; per-lift refinement can come
/// later without changing call sites.
class StrengthStandards {
  /// Male relative-strength lower bounds (1RM / bodyweight) per tier.
  /// A ratio at or above a bound qualifies for that tier.
  static const Map<StrengthTier, double> _maleLowerBounds = {
    StrengthTier.beginner: 0.5,
    StrengthTier.intermediate: 0.75,
    StrengthTier.advanced: 1.25,
    StrengthTier.elite: 1.75,
  };

  static const double _femaleMultiplier = 0.65;
  static const double _blendMultiplier = 0.825; // midpoint of 1.0 and 0.65

  /// Target combat stat (on the engine's 10–1000 scale) for each tier. Drives
  /// the seed volume via [StatEngine.volumeForStat]. Tuned to land clean ranks
  /// on the widening ladder (C=100, B=300, A=600, S=900) so calibration tiers
  /// read as distinct grades up to a felt S for elite.
  static int targetStatForTier(StrengthTier tier) => switch (tier) {
    StrengthTier.untrained => 50, // D
    StrengthTier.beginner => 120, // C
    StrengthTier.intermediate => 420, // B
    StrengthTier.advanced => 650, // A
    StrengthTier.elite => 950, // S
  };

  static double _multiplierForSex(UserProfileSex sex) => switch (sex) {
    UserProfileSex.male => 1.0,
    UserProfileSex.female => _femaleMultiplier,
    UserProfileSex.preferNotToSay => _blendMultiplier,
  };

  /// Classifies a relative-strength ratio (1RM / bodyweight) into a tier,
  /// adjusting thresholds for sex.
  static StrengthTier tierForRelativeStrength(
    double ratio,
    UserProfileSex sex,
  ) {
    final m = _multiplierForSex(sex);
    if (ratio >= _maleLowerBounds[StrengthTier.elite]! * m) {
      return StrengthTier.elite;
    }
    if (ratio >= _maleLowerBounds[StrengthTier.advanced]! * m) {
      return StrengthTier.advanced;
    }
    if (ratio >= _maleLowerBounds[StrengthTier.intermediate]! * m) {
      return StrengthTier.intermediate;
    }
    if (ratio >= _maleLowerBounds[StrengthTier.beginner]! * m) {
      return StrengthTier.beginner;
    }
    return StrengthTier.untrained;
  }

  /// Fallback when bodyweight is unknown: classify by absolute estimated 1RM
  /// (kg) and cap conservatively at [StrengthTier.intermediate] — without
  /// bodyweight we cannot honestly award advanced/elite. The character can
  /// still climb during the 3-session calibration window as real volume lands.
  static StrengthTier tierForAbsolute1RM(double oneRmKg) {
    if (oneRmKg >= 60) return StrengthTier.intermediate;
    if (oneRmKg >= 40) return StrengthTier.beginner;
    return StrengthTier.untrained;
  }
}
