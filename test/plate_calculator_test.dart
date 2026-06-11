import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/plate_calculator.dart';

void main() {
  group('PlateCalculator.platesPerSide', () {
    test('60 kg on a 20 kg bar = 20 kg per side', () {
      expect(PlateCalculator.platesPerSide(60), [20]);
    });

    test('100 kg on a 20 kg bar = [25, 15] per side (40 kg total)', () {
      // 40 kg per side — greedy picks 25 first (largest fit), leaving 15.
      expect(PlateCalculator.platesPerSide(100), [25, 15]);
    });

    test('22.5 kg on a 20 kg bar = [1.25] per side', () {
      expect(PlateCalculator.platesPerSide(22.5), [1.25]);
    });

    test('weight at or below bar weight returns empty', () {
      expect(PlateCalculator.platesPerSide(20), isEmpty);
      expect(PlateCalculator.platesPerSide(15), isEmpty);
    });

    test('weight that cannot be loaded exactly returns empty', () {
      // Smallest plate is 1.25 kg → 1.5 kg per side is not loadable.
      expect(PlateCalculator.platesPerSide(23), isEmpty);
    });

    test('custom bar weight', () {
      // 7 kg bar, target 17 kg → 5 kg per side.
      expect(PlateCalculator.platesPerSide(17, barKg: 7), [5]);
    });

    test('greedy uses largest plate first', () {
      // 90 kg on 20 kg bar = 35 kg per side = 25 + 10
      expect(PlateCalculator.platesPerSide(90), [25, 10]);
    });

    test('handles big lifts', () {
      // 200 kg on 20 kg bar = 90 kg per side = 25*3 + 15
      expect(PlateCalculator.platesPerSide(200), [25, 25, 25, 15]);
    });
  });

  group('PlateCalculator.platesPerSide - lb plate set', () {
    test('135 lb on a 45 lb bar = one 45 per side', () {
      expect(
        PlateCalculator.platesPerSide(
          135,
          barKg: defaultBarLbs,
          plates: lbPlates,
        ),
        [45],
      );
    });

    test('225 lb on a 45 lb bar = two 45s per side', () {
      expect(
        PlateCalculator.platesPerSide(
          225,
          barKg: defaultBarLbs,
          plates: lbPlates,
        ),
        [45, 45],
      );
    });

    test('non-loadable lb target returns empty (no asymmetric loads)', () {
      // (46 - 45) / 2 = 0.5 lb per side — smallest lb plate is 2.5.
      expect(
        PlateCalculator.platesPerSide(
          46,
          barKg: defaultBarLbs,
          plates: lbPlates,
        ),
        isEmpty,
      );
    });
  });

  group('PlateCalculator.totalWeight', () {
    test('empty stack is just the bar', () {
      expect(PlateCalculator.totalWeight(const []), 20);
      expect(PlateCalculator.totalWeight(const [], barKg: 15), 15);
    });

    test('mixed kg stack: bar + 2x per-side sum', () {
      // 20 + 2 * (20 + 10) = 80
      expect(PlateCalculator.totalWeight(const [20, 10]), 80);
      // 20 + 2 * (25 + 2.5 + 1.25) = 77.5
      expect(PlateCalculator.totalWeight(const [25, 2.5, 1.25]), 77.5);
    });

    test('lb numbers: two 45s per side on a 45 bar = 225', () {
      expect(
        PlateCalculator.totalWeight(const [45, 45], barKg: defaultBarLbs),
        225,
      );
    });

    test('round-trips with platesPerSide', () {
      final plates = PlateCalculator.platesPerSide(102.5);
      expect(PlateCalculator.totalWeight(plates), 102.5);
    });
  });
}
