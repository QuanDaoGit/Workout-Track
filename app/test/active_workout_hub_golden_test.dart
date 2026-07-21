import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/theme/tokens.dart';

/// Rendered-artifact proof for the session hub's frontier BIT (the web preview
/// can't screenshot here): mid-session (BIT riding the frontier card + one
/// cleared-warm card) and all-clear (cheer dock above the enabled Finish).
/// Deterministic under reduced motion (BIT is a posed still frame; env fonts
/// render as boxes, matching the repo's golden baseline). The behavioral gate
/// is active_workout_bit_frontier_test.dart — these are the visual net (Codex
/// F4: goldens supplement, never replace, the behavior assertions).
/// Regenerate with `flutter test --update-goldens`.
Exercise _exercise(String id, String name) =>
    Exercise(id: id, name: name, level: 'beginner', images: const []);

ExerciseLog _doneLog(String id, String name) => ExerciseLog(
  exerciseId: id,
  exerciseName: name,
  sets: const [SetEntry(weight: 40, reps: 8)],
);

WorkoutSession _resume(Map<String, String> doneByIdName) => WorkoutSession(
  id: 'r1',
  date: DateTime.now(),
  startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  muscleGroup: 'Chest',
  targetDurationMinutes: 30,
  actualDurationSeconds: 180,
  estimatedCalories: 20,
  isPartial: true,
  selectedExerciseIds: const ['a', 'b'],
  exercises: [
    for (final e in doneByIdName.entries) _doneLog(e.key, e.value),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  Future<void> pumpHub(WidgetTester tester, {WorkoutSession? resume}) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // A faithful-enough dark slice (the rest-panel golden's precedent) so
        // the page doesn't float on the default light theme.
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: kBg,
          cardTheme: const CardThemeData(color: kCard),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [
            _exercise('a', 'Barbell Bench Press'),
            _exercise('b', 'Incline Dumbbell Press'),
          ],
          resumeFromSession: resume,
        ),
      ),
    );
    await tester.pump();
    // The app-bar back glyph decodes on the real event loop — precache it so
    // the golden can't race the decode (it rendered in one variant and not
    // the other on the first generation).
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(ActiveWorkoutPage));
      await precacheImage(
        const AssetImage('assets/icons/control/icon_next.png'),
        ctx,
      );
    });
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('hub mid-session: frontier BIT + cleared warmth', (tester) async {
    await pumpHub(tester, resume: _resume({'a': 'Barbell Bench Press'}));
    await expectLater(
      find.byType(ActiveWorkoutPage),
      matchesGoldenFile('goldens/active_workout_hub_mid.png'),
    );
  });

  testWidgets('hub all-clear: cheer dock above enabled Finish', (tester) async {
    await pumpHub(
      tester,
      resume: _resume({
        'a': 'Barbell Bench Press',
        'b': 'Incline Dumbbell Press',
      }),
    );
    await expectLater(
      find.byType(ActiveWorkoutPage),
      matchesGoldenFile('goldens/active_workout_hub_all_clear.png'),
    );
  });
}
