import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';

/// Locks the end-early exit contract: ending a workout early must return to the
/// app shell (the first route), not strand the user on the workout page. This
/// is the mechanism (`popUntil((r) => r.isFirst)`) that the StartGate bug was
/// breaking by orphaning the root; here we verify the exit itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'END EARLY → SAVE & EXIT returns to the app shell, not the workout page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActiveWorkoutPage(
                        muscleGroup: 'Chest',
                        durationMinutes: 30,
                        exercises: [
                          Exercise(
                            id: 'bench',
                            name: 'Bench Press',
                            level: 'beginner',
                            images: [],
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('HOME PROBE'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('HOME PROBE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // We're in the live session now.
      expect(find.byType(ActiveWorkoutPage), findsOneWidget);

      // Open the end-early dialog (app-bar button) and choose SAVE & EXIT.
      await tester.tap(find.text('END EARLY'));
      await tester.pump();
      await tester.tap(find.text('SAVE & EXIT'));
      // _pauseAndQuit persists the paused session (async) then popUntil(isFirst).
      // Several bounded frames cover the save + route unwind.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Back on the shell — the workout page is gone.
      expect(find.byType(ActiveWorkoutPage), findsNothing);
      expect(find.text('HOME PROBE'), findsOneWidget);
    },
  );
}
