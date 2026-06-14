import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/warmup_reward_service.dart';

/// A warmed-up real session shows the calm warm-up bonus on the summary AND the
/// gems actually land (settled in saveSession). One full on-mount save per file
/// — a second hangs on the calibration asset load (pre-existing infra limit).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('warmed-up session reveals the bonus and credits the gems', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: const WorkoutSummaryPage(
          muscleGroup: 'Chest',
          targetMuscleGroups: ['Chest'],
          durationMinutes: 20,
          elapsedSeconds: 600,
          exerciseLogs: [
            ExerciseLog(
              exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
              exerciseName: 'Barbell Bench Press',
              sets: [SetEntry(weight: 40, reps: 8)],
              // A logged warm-up set is what makes the session "warmed up" now.
              warmupSets: [SetEntry(weight: 20, reps: 10, isWarmup: true)],
            ),
          ],
          selectedExerciseIds: ['Barbell_Bench_Press_-_Medium_Grip'],
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('WARM-UP BONUS'), findsOneWidget);
    expect(await GemService().balance(), WarmupRewardService.gemReward);
  });
}
