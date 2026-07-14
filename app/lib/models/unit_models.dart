/// App-wide unit system. The entire app stores and calculates in **canonical
/// metric** (kilograms for load/volume, centimetres for height); these enums +
/// pure helpers convert and format only at UI input/display boundaries.
///
/// Defaults are **lbs** and **ft-in** (see [WeightUnit]/[LengthUnit] and the
/// runtime holder `Units` in `services/unit_settings_service.dart`).
library;

import 'dart:math' as math;

/// Weight/load display unit. Storage is always kilograms.
enum WeightUnit {
  kg,
  lbs;

  /// Lower-case unit suffix for inline display, e.g. `'75 kg'` / `'165 lbs'`.
  String get label => this == WeightUnit.kg ? 'kg' : 'lbs';

  /// Upper-case label for headers / toggles, e.g. `'KG'` / `'LBS'`.
  String get labelUpper => this == WeightUnit.kg ? 'KG' : 'LBS';
}

/// Height display unit. Storage is always centimetres.
enum LengthUnit {
  cm,
  ftIn;

  String get labelUpper => this == LengthUnit.cm ? 'CM' : 'FT-IN';
}

// --- Constants --------------------------------------------------------------

const double _kgPerLb = 0.45359237;
const double _cmPerInch = 2.54;

/// Standard ISO Olympic kg plate set (largest first) + 20 kg bar.
const List<double> kgPlates = [25, 20, 15, 10, 5, 2.5, 1.25];
const double defaultBarKg = 20;

/// Standard lb plate set (largest first) + 45 lb bar.
const List<double> lbPlates = [45, 35, 25, 10, 5, 2.5];
const double defaultBarLbs = 45;

/// Plate denominations for the active unit (used by the plate calculator,
/// which then computes natively in that unit's numbers).
List<double> plateSetFor(WeightUnit unit) =>
    unit == WeightUnit.kg ? kgPlates : lbPlates;

/// Default bar weight in the active unit's own numbers.
double defaultBarFor(WeightUnit unit) =>
    unit == WeightUnit.kg ? defaultBarKg : defaultBarLbs;

// --- Raw conversions --------------------------------------------------------

double kgToLbs(double kg) => kg / _kgPerLb;
double lbsToKg(double lbs) => lbs * _kgPerLb;
double cmToInches(double cm) => cm / _cmPerInch;
double inchesToCm(double inches) => inches * _cmPerInch;

/// The numeric value of [kg] expressed in [unit] (no label).
double kgToDisplay(double kg, WeightUnit unit) =>
    unit == WeightUnit.kg ? kg : kgToLbs(kg);

/// Convert a value already expressed in [unit] back to canonical kg.
double displayToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.kg ? value : lbsToKg(value);

// --- Number formatting ------------------------------------------------------

/// Trims a trailing `.0` and rounds to [decimals] otherwise.
String fmtNum(double v, {int decimals = 1}) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(decimals);
  // Drop trailing zeros / dot left after fixed formatting (e.g. 74.50 -> 74.5).
  return s.contains('.')
      ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : s;
}

/// Rounds a display-unit number to the nearest [step] (e.g. 0.5 for manual
/// weight entry, 2.5 for suggested loads). [step] must be > 0.
double roundToStep(double value, double step) => (value / step).round() * step;

/// Numeric load in the active unit, formatted (no unit label). Use for editable
/// text fields and bare numbers. Works for both single loads and volume
/// tonnage (volume is just summed kilograms).
String weightValue(double kg, WeightUnit unit, {int decimals = 1}) =>
    fmtNum(kgToDisplay(kg, unit), decimals: decimals);

/// Full load string with unit, e.g. `'165 lbs'`. [decimals] = 0 reads cleanest
/// for big tonnage totals.
String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) =>
    '${weightValue(kg, unit, decimals: decimals)} ${unit.label}';

/// Parse free text typed in [unit] into canonical kg. Returns null if unparseable.
double? parseWeightToKg(String raw, WeightUnit unit) {
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null) return null;
  return displayToKg(v, unit);
}

/// Bodyweight sanity bound (canonical kg). Guards weight-log / calibration /
/// goal-target inputs against fat-finger values that would wreck chart scaling.
/// ~20–500 kg covers every plausible human bodyweight in either unit.
bool isPlausibleWeightKg(double kg) => kg >= 20 && kg <= 500;

// --- Volume tonnage ---------------------------------------------------------

/// Thousands-separated integer string for volume tonnage, e.g. `12345 -> "12,345"`.
/// Unit-agnostic — feed it a value already converted via [kgToDisplay].
String fmtVol(double v) {
  final rounded = v.round();
  if (rounded < 1000) return rounded.toString();
  final s = rounded.toString();
  final buf = StringBuffer();
  final start = s.length % 3;
  if (start > 0) buf.write(s.substring(0, start));
  for (int i = start; i < s.length; i += 3) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(s.substring(i, i + 3));
  }
  return buf.toString();
}

/// Rounds [v] to [figs] significant figures (for readable threshold copy).
double _roundToSigFigs(double v, int figs) {
  if (v <= 0) return v;
  final digits = (math.log(v) / math.ln10).floor() + 1;
  final shift = digits - figs;
  if (shift <= 0) return v.roundToDouble();
  final factor = math.pow(10, shift).toDouble();
  return (v / factor).round() * factor;
}

/// A milestone volume threshold (stored kg) rendered in [unit], rounded to a
/// readable magnitude — e.g. 120000 kg -> `"120,000 kg"` / `"265,000 lbs"`.
/// Use for static achievement/loot copy, NOT live counters (those stay exact).
String volumeThresholdLabel(double kg, WeightUnit unit) =>
    '${fmtVol(_roundToSigFigs(kgToDisplay(kg, unit), 3))} ${unit.label}';

// --- Height formatting ------------------------------------------------------

/// Splits canonical [cm] into whole feet + inches (inches rounded).
({int feet, int inches}) cmToFeetInches(double cm) {
  final totalInches = cmToInches(cm).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

double feetInchesToCm(int feet, int inches) =>
    inchesToCm(feet * 12 + inches.toDouble());

/// Full height string, e.g. `'5 ft 11 in'` or `'180 cm'`.
String formatHeight(double cm, LengthUnit unit) {
  if (unit == LengthUnit.cm) return '${cm.round()} cm';
  final h = cmToFeetInches(cm);
  return '${h.feet} ft ${h.inches} in';
}
