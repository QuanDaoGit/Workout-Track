import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/unit_models.dart';

void main() {
  group('weight conversions', () {
    test('kg <-> lbs round-trips', () {
      expect(kgToLbs(0), 0);
      expect(lbsToKg(0), 0);
      // 100 kg ~= 220.46 lbs
      expect(kgToLbs(100), closeTo(220.462, 0.01));
      // 165 lbs ~= 74.84 kg
      expect(lbsToKg(165), closeTo(74.843, 0.01));
      // round-trip stays put
      expect(lbsToKg(kgToLbs(82.5)), closeTo(82.5, 1e-9));
    });

    test('kgToDisplay / displayToKg respect the unit', () {
      expect(kgToDisplay(75, WeightUnit.kg), 75);
      expect(kgToDisplay(75, WeightUnit.lbs), closeTo(165.347, 0.01));
      expect(displayToKg(75, WeightUnit.kg), 75);
      expect(displayToKg(165, WeightUnit.lbs), closeTo(74.843, 0.01));
    });

    test('parseWeightToKg parses in the active unit', () {
      expect(parseWeightToKg('75', WeightUnit.kg), 75);
      expect(parseWeightToKg('165', WeightUnit.lbs), closeTo(74.843, 0.01));
      expect(parseWeightToKg('74,5', WeightUnit.kg), 74.5); // comma decimal
      expect(parseWeightToKg('', WeightUnit.kg), isNull);
      expect(parseWeightToKg('abc', WeightUnit.lbs), isNull);
    });
  });

  group('formatting', () {
    test('fmtNum trims a trailing zero', () {
      expect(fmtNum(75), '75');
      expect(fmtNum(74.5), '74.5');
      expect(fmtNum(74.50), '74.5');
      expect(fmtNum(74.0), '74');
    });

    test('formatWeight appends the unit label', () {
      expect(formatWeight(75, WeightUnit.kg), '75 kg');
      expect(formatWeight(75, WeightUnit.lbs), '165.3 lbs');
      expect(formatWeight(1000, WeightUnit.kg, decimals: 0), '1000 kg');
      expect(formatWeight(1000, WeightUnit.lbs, decimals: 0), '2205 lbs');
    });

    test('weightValue is the bare number in the active unit', () {
      expect(weightValue(100, WeightUnit.kg), '100');
      expect(weightValue(100, WeightUnit.lbs), '220.5');
    });

    test('roundToStep snaps to the nearest multiple of the step', () {
      // Manual entry: nearest 0.5.
      expect(roundToStep(154.3, 0.5), 154.5);
      expect(roundToStep(154.2, 0.5), 154.0);
      expect(roundToStep(154.5, 0.5), 154.5);
      // Suggested loads: nearest 2.5.
      expect(roundToStep(159.8, 2.5), 160.0);
      expect(roundToStep(161.2, 2.5), 160.0);
      expect(roundToStep(161.3, 2.5), 162.5);
      expect(roundToStep(162.5, 2.5), 162.5);
      expect(roundToStep(0, 2.5), 0.0);
    });
  });

  group('height conversions', () {
    test('cmToFeetInches splits correctly', () {
      final h = cmToFeetInches(180);
      expect(h.feet, 5);
      expect(h.inches, 11);
    });

    test('feetInchesToCm round-trips through formatHeight', () {
      final cm = feetInchesToCm(5, 11);
      expect(cm, closeTo(180.34, 0.01));
      expect(formatHeight(cm, LengthUnit.ftIn), '5 ft 11 in');
    });

    test('formatHeight in cm', () {
      expect(formatHeight(180, LengthUnit.cm), '180 cm');
      expect(formatHeight(175.6, LengthUnit.cm), '176 cm');
    });

    test('inch carry rolls into feet (e.g. 12 in -> +1 ft)', () {
      // 152.4 cm == exactly 60 in == 5 ft 0 in
      final h = cmToFeetInches(152.4);
      expect(h.feet, 5);
      expect(h.inches, 0);
    });
  });

  group('plate sets', () {
    test('plateSetFor / defaultBarFor select by unit', () {
      expect(plateSetFor(WeightUnit.kg), kgPlates);
      expect(plateSetFor(WeightUnit.lbs), lbPlates);
      expect(defaultBarFor(WeightUnit.kg), defaultBarKg);
      expect(defaultBarFor(WeightUnit.lbs), defaultBarLbs);
    });
  });

  group('volume tonnage', () {
    test('fmtVol inserts thousands separators', () {
      expect(fmtVol(999), '999');
      expect(fmtVol(1000), '1,000');
      expect(fmtVol(12345), '12,345');
      expect(fmtVol(264555), '264,555');
    });

    test('volumeThresholdLabel converts + rounds for readable copy', () {
      // kg thresholds are already round.
      expect(volumeThresholdLabel(120000, WeightUnit.kg), '120,000 kg');
      expect(volumeThresholdLabel(5000, WeightUnit.kg), '5,000 kg');
      // lbs: convert then round to 3 significant figures.
      expect(volumeThresholdLabel(120000, WeightUnit.lbs), '265,000 lbs');
      expect(volumeThresholdLabel(5000, WeightUnit.lbs), '11,000 lbs');
    });
  });

  group('isPlausibleWeightKg', () {
    test('accepts the human range and rejects fat-finger values', () {
      expect(isPlausibleWeightKg(75), isTrue);
      expect(isPlausibleWeightKg(20), isTrue);
      expect(isPlausibleWeightKg(500), isTrue);
      expect(isPlausibleWeightKg(19.9), isFalse);
      expect(isPlausibleWeightKg(500.1), isFalse);
      expect(isPlausibleWeightKg(9999), isFalse);
    });
  });
}
