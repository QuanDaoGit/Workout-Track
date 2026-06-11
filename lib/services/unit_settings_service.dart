import 'package:shared_preferences/shared_preferences.dart';

import '../models/unit_models.dart';

/// Persists the app-wide unit preference (Profile → Settings → Units, and the
/// inline toggles on the onboarding bodyweight question).
///
/// Defaults to **lbs** + **ft-in** — the app ships imperial-first. Mirrors
/// [SoundSettingsService]: the store is the source of truth on disk, and the
/// runtime [Units] holder caches the values for synchronous display formatting.
class UnitSettingsService {
  static const String _weightKey = 'weight_unit_v1';
  static const String _heightKey = 'height_unit_v1';

  Future<WeightUnit> weightUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_weightKey);
    return WeightUnit.values.firstWhere(
      (u) => u.name == raw,
      orElse: () => WeightUnit.lbs,
    );
  }

  Future<LengthUnit> heightUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_heightKey);
    return LengthUnit.values.firstWhere(
      (u) => u.name == raw,
      orElse: () => LengthUnit.ftIn,
    );
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weightKey, unit.name);
  }

  Future<void> setHeightUnit(LengthUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_heightKey, unit.name);
  }
}

/// Runtime holder for the active units, read synchronously by display code at
/// build time (same pattern as `SfxService.enabled`). `main()` calls [load] at
/// boot; the settings sheet and onboarding toggles call [setWeight]/[setHeight]
/// to persist and update the cache in one step.
class Units {
  Units._();

  static WeightUnit weight = WeightUnit.lbs;
  static LengthUnit height = LengthUnit.ftIn;

  static final UnitSettingsService _service = UnitSettingsService();

  static Future<void> load() async {
    weight = await _service.weightUnit();
    height = await _service.heightUnit();
  }

  static Future<void> setWeight(WeightUnit unit) async {
    weight = unit;
    await _service.setWeightUnit(unit);
  }

  static Future<void> setHeight(LengthUnit unit) async {
    height = unit;
    await _service.setHeightUnit(unit);
  }
}
