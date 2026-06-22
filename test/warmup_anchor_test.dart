import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/overload_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';

void main() {
  group('resolveWarmupAnchor (#10)', () {
    const prev = [
      SetEntry(weight: 100, reps: 5),
      SetEntry(weight: 90, reps: 8),
    ];

    test('uses the suggestion load when a suggestion is shown', () {
      const s = OverloadSuggestion(
        weight: 95,
        reps: 8,
        reason: OverloadReason.deload,
      );
      expect(resolveWarmupAnchor(s, prev), 95);
    });

    test('falls back to the last top working set when the suggestion is null '
        '(progression off → ignore the hidden deload)', () {
      // Passing null mimics suggestions being disabled: the deloaded 95 must NOT
      // drive the warm-up — it anchors to the real last top working set (100).
      expect(resolveWarmupAnchor(null, prev), 100);
    });

    test('null when neither a suggestion nor a positive previous set exists', () {
      expect(resolveWarmupAnchor(null, const []), isNull);
      expect(
        resolveWarmupAnchor(null, const [SetEntry(weight: 0, reps: 10)]),
        isNull,
      );
    });
  });
}
