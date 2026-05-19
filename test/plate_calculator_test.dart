import 'package:flutter_test/flutter_test.dart';
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
}
