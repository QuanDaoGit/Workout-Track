import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';

Exercise _exercise(String id) => Exercise(
  id: id,
  name: id,
  level: 'beginner',
  images: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'idle timeout fires the auto-save reveal after the inactivity window',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            muscleGroup: 'Chest',
            durationMinutes: 30,
            exercises: [_exercise('a'), _exercise('b')],
            idleTimeout: const Duration(seconds: 2),
          ),
        ),
      );

      // Not yet idle.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('STILL TRAINING?'), findsNothing);

      // Cross the idle window — the reveal appears. No sets were logged, so it
      // offers KEEP TRAINING / DISCARD only (no SAVE & FINISH).
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('STILL TRAINING?'), findsOneWidget);
      expect(find.text('KEEP TRAINING'), findsOneWidget);
      expect(find.text('DISCARD'), findsOneWidget);
      expect(find.text('SAVE & FINISH'), findsNothing);

      // KEEP TRAINING dismisses and re-arms (no reveal immediately after).
      await tester.tap(find.text('KEEP TRAINING'));
      await tester.pumpAndSettle();
      expect(find.text('STILL TRAINING?'), findsNothing);
    },
  );
}
