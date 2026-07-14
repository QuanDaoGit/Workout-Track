import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/unit_models.dart';
import 'package:workout_track/services/warmup_calculator.dart';

/// Helper: a working weight expressed in the display unit, converted to the
/// canonical kg anchor the calculator consumes.
double _anchor(double displayValue, WeightUnit unit) =>
    displayToKg(displayValue, unit);

void main() {
  group('barbell', () {
    test('100 kg work → 50 kg, settable, 8 reps', () {
      final s = WarmupCalculator.suggest(
        equipment: 'barbell',
        anchorKg: _anchor(100, WeightUnit.kg),
        unit: WeightUnit.kg,
      )!;
      expect(s.displayWeight, 50);
      expect(s.reps, 8);
      expect(s.emptyBar, isFalse);
      // bar + a real pair of plates.
      expect((s.displayWeight - 20) % 2.5, 0);
    });

    test('too-light work (half ≤ bar) is suppressed', () {
      expect(
        WarmupCalculator.suggest(
          equipment: 'barbell',
          anchorKg: _anchor(22.5, WeightUnit.kg),
          unit: WeightUnit.kg,
        ),
        isNull,
      );
    });

    test('no anchor → empty bar × 8', () {
      final kg = WarmupCalculator.suggest(
        equipment: 'barbell',
        anchorKg: null,
        unit: WeightUnit.kg,
      )!;
      expect(kg.displayWeight, 20);
      expect(kg.emptyBar, isTrue);

      final lb = WarmupCalculator.suggest(
        equipment: 'barbell',
        anchorKg: null,
        unit: WeightUnit.lbs,
      )!;
      expect(lb.displayWeight, 45);
      expect(lb.emptyBar, isTrue);
    });

    test('lbs result is plate-loadable (bar + 5 lb pairs), below work', () {
      final s = WarmupCalculator.suggest(
        equipment: 'barbell',
        anchorKg: _anchor(225, WeightUnit.lbs),
        unit: WeightUnit.lbs,
      )!;
      expect(s.displayWeight, lessThan(225));
      expect((s.displayWeight - 45) % 5, 0);
    });
  });

  group('e-z curl bar', () {
    test('floors at the lighter EZ bar, not the Olympic bar', () {
      final empty = WarmupCalculator.suggest(
        equipment: 'e-z curl bar',
        anchorKg: null,
        unit: WeightUnit.kg,
      )!;
      expect(empty.displayWeight, 10);
      expect(empty.emptyBar, isTrue);

      final loaded = WarmupCalculator.suggest(
        equipment: 'e-z curl bar',
        anchorKg: _anchor(30, WeightUnit.kg),
        unit: WeightUnit.kg,
      )!;
      expect(loaded.displayWeight, 15); // 10 + pair(2.5) rounding of (15-10)
      expect(loaded.displayWeight, lessThan(30));
    });
  });

  group('fixed free weight (dumbbell / kettlebells)', () {
    test('dumbbell 30 kg → 15 kg × 8', () {
      final s = WarmupCalculator.suggest(
        equipment: 'dumbbell',
        anchorKg: _anchor(30, WeightUnit.kg),
        unit: WeightUnit.kg,
      )!;
      expect(s.displayWeight, 15);
      expect(s.reps, 8);
    });

    test('kettlebells round to a real bell step', () {
      final s = WarmupCalculator.suggest(
        equipment: 'kettlebells',
        anchorKg: _anchor(50, WeightUnit.lbs),
        unit: WeightUnit.lbs,
      )!;
      expect(s.displayWeight % 5, 0);
      expect(s.displayWeight, lessThan(50));
    });

    test('no anchor → no card (no empty-bar concept)', () {
      expect(
        WarmupCalculator.suggest(
          equipment: 'dumbbell',
          anchorKg: null,
          unit: WeightUnit.kg,
        ),
        isNull,
      );
    });
  });

  group('stack (cable / machine)', () {
    test('200 lb work → 110 lb (55%, plate-rounded), not 170', () {
      final s = WarmupCalculator.suggest(
        equipment: 'cable',
        anchorKg: _anchor(200, WeightUnit.lbs),
        unit: WeightUnit.lbs,
      )!;
      expect(s.displayWeight, 110);
      expect(s.displayWeight % 10, 0); // lands on a real pin
      expect(s.displayWeight, lessThan(200));
    });

    test('machine result is always strictly below the work set', () {
      final s = WarmupCalculator.suggest(
        equipment: 'machine',
        anchorKg: _anchor(60, WeightUnit.kg),
        unit: WeightUnit.kg,
      )!;
      expect(s.displayWeight, lessThan(60));
      expect(s.displayWeight % 5, 0);
    });

    test('a 1-plate stack is too light to warm up → null', () {
      expect(
        WarmupCalculator.suggest(
          equipment: 'cable',
          anchorKg: _anchor(10, WeightUnit.lbs),
          unit: WeightUnit.lbs,
        ),
        isNull,
      );
    });
  });

  group('unloaded equipment → no card', () {
    for (final eq in const [
      'body only',
      'bands',
      'medicine ball',
      'exercise ball',
      'foam roll',
      'other',
      null,
    ]) {
      test('equipment "$eq" → null', () {
        expect(
          WarmupCalculator.suggest(
            equipment: eq,
            anchorKg: _anchor(80, WeightUnit.kg),
            unit: WeightUnit.kg,
          ),
          isNull,
        );
      });
    }
  });

  test('unit parity: same kg anchor yields a settable number in both units', () {
    final anchorKg = _anchor(100, WeightUnit.kg);
    final kg = WarmupCalculator.suggest(
      equipment: 'barbell',
      anchorKg: anchorKg,
      unit: WeightUnit.kg,
    )!;
    final lb = WarmupCalculator.suggest(
      equipment: 'barbell',
      anchorKg: anchorKg,
      unit: WeightUnit.lbs,
    )!;
    expect((kg.displayWeight - 20) % 2.5, 0);
    expect((lb.displayWeight - 45) % 5, 0);
  });
}
