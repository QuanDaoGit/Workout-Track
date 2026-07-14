import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/warmup_routines.dart';

void main() {
  List<String> drillNames(List<String> targets) =>
      warmupPlanForTargets(targets).drills.map((d) => d.name).toList();

  test('every plan has a raise step and at least one drill', () {
    final plan = warmupPlanForTargets(['Legs']);
    expect(plan.raise, isNotEmpty);
    expect(plan.drills, isNotEmpty);
  });

  test('Legs tailors to lower-body mobility', () {
    final names = drillNames(['Legs']);
    expect(names, contains('Leg swings'));
    expect(names, contains('Hip circles'));
  });

  test('Chest tailors to push/upper drills', () {
    final names = drillNames(['Chest']);
    expect(names, contains('Band pull-aparts'));
    expect(names.any((n) => n.contains('Push-up') || n.contains('push-up')), isTrue);
  });

  test('multiple targets aggregate and dedupe shared drills', () {
    // Chest and Shoulders both include "Arm circles" / "Band pull-aparts" —
    // they appear once, not twice.
    final names = drillNames(['Chest', 'Shoulders']);
    expect(names.where((n) => n == 'Band pull-aparts').length, 1);
    expect(names.where((n) => n == 'Arm circles').length, 1);
  });

  test('the drill block is capped so the sheet stays short', () {
    // All groups at once must not produce an unbounded list.
    final names = drillNames(['Full Body', 'Legs', 'Chest', 'Back', 'Arms']);
    expect(names.length, lessThanOrEqualTo(6));
  });

  test('unknown/empty targets fall back to a full-body plan', () {
    expect(warmupPlanForTargets(const []).drills, isNotEmpty);
    expect(warmupPlanForTargets(['Nonsense']).drills, isNotEmpty);
  });
}
