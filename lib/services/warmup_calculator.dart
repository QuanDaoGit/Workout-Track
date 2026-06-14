import '../models/unit_models.dart';

/// A single, advisory warm-up suggestion for an exercise. Display-only — it is
/// **never logged** and feeds no volume/stat/XP path. [displayWeight] is already
/// expressed and sanitized in [unit]'s own numbers, so it is always a load the
/// user can actually set (bar + plate pairs, a real dumbbell, a real stack pin).
class WarmupSuggestion {
  const WarmupSuggestion({
    required this.displayWeight,
    required this.reps,
    required this.unit,
    this.emptyBar = false,
  });

  /// Settable load in [unit]'s numbers (e.g. `50` meaning 50 kg or 50 lbs).
  final double displayWeight;
  final int reps;
  final WeightUnit unit;

  /// True only for the anchorless barbell case — "warm up with the empty bar".
  final bool emptyBar;
}

/// Computes the equipment-aware warm-up suggestion. Pure: no I/O, no stored
/// state. All math runs in the **display unit** (like the plate calculator) so
/// the result lands on that unit's real increments and never needs a kg→display
/// round-trip that could re-expose an off-grid number.
///
/// Returns `null` when no warm-up should be shown (unloaded equipment, no anchor
/// for a non-barbell lift, or a working weight so light a warm-up is pointless).
class WarmupCalculator {
  WarmupCalculator._();

  /// Reps for every loaded warm-up — a single low-fatigue prep set.
  static const int warmupReps = 8;

  /// E-Z curl bars are lighter than an Olympic bar; floor the barbell rule there
  /// so a light-curl warm-up isn't overstated.
  static const double _ezBarKg = 10;
  static const double _ezBarLbs = 25;

  /// Representative selectorized-stack single-plate value (cable/machine).
  static double _stackPlate(WeightUnit unit) => unit == WeightUnit.kg ? 5 : 10;

  /// Dumbbell/kettlebell rounding step (a real bell increment).
  static double _fixedStep(WeightUnit unit) => unit == WeightUnit.kg ? 2.5 : 5;

  /// The smallest loadable barbell jump = a pair of the smallest plates.
  static double _smallestPair(WeightUnit unit) => 2 * plateSetFor(unit).last;

  static double _ezBar(WeightUnit unit) =>
      unit == WeightUnit.kg ? _ezBarKg : _ezBarLbs;

  /// [anchorKg] is the working weight this warm-up derives from (canonical kg),
  /// or null when no working weight is known yet.
  static WarmupSuggestion? suggest({
    required String? equipment,
    required double? anchorKg,
    required WeightUnit unit,
  }) {
    final eq = (equipment ?? '').trim().toLowerCase();

    switch (eq) {
      case 'barbell':
      case 'e-z curl bar':
        return _barbell(eq, anchorKg, unit);
      case 'dumbbell':
      case 'kettlebells':
        return _fixedFreeWeight(anchorKg, unit);
      case 'cable':
      case 'machine':
        return _stack(anchorKg, unit);
      default:
        // body only / bands / balls / foam roll / other → no warm-up card.
        return null;
    }
  }

  static WarmupSuggestion? _barbell(
    String eq,
    double? anchorKg,
    WeightUnit unit,
  ) {
    final bar = eq == 'e-z curl bar' ? _ezBar(unit) : defaultBarFor(unit);

    // No known working weight → the always-valid advice: warm up with the bar.
    if (anchorKg == null) {
      return WarmupSuggestion(
        displayWeight: bar,
        reps: warmupReps,
        unit: unit,
        emptyBar: true,
      );
    }

    final work = kgToDisplay(anchorKg, unit);
    final half = 0.5 * work;
    // Too light to warrant a warm-up: half the work doesn't even clear the bar.
    if (half <= bar) return null;

    final raw = bar + roundToStep(half - bar, _smallestPair(unit));
    if (raw >= work) return null; // safety: never suggest >= the work set
    return WarmupSuggestion(displayWeight: raw, reps: warmupReps, unit: unit);
  }

  static WarmupSuggestion? _fixedFreeWeight(double? anchorKg, WeightUnit unit) {
    if (anchorKg == null) return null;
    final work = kgToDisplay(anchorKg, unit);
    final step = _fixedStep(unit);
    var raw = roundToStep(0.5 * work, step);
    if (raw < step) raw = step;
    if (raw >= work) return null;
    return WarmupSuggestion(displayWeight: raw, reps: warmupReps, unit: unit);
  }

  static WarmupSuggestion? _stack(double? anchorKg, WeightUnit unit) {
    if (anchorKg == null) return null;
    final work = kgToDisplay(anchorKg, unit);
    final plate = _stackPlate(unit);
    var raw = roundToStep(0.55 * work, plate);
    if (raw < plate) raw = plate;
    if (raw >= work) {
      // One pin lighter than the work set, if that's still a real load.
      raw = roundToStep(work - plate, plate);
      if (raw < plate || raw >= work) return null;
    }
    return WarmupSuggestion(displayWeight: raw, reps: warmupReps, unit: unit);
  }
}
