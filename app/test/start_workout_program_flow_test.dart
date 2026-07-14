import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/pages/Workout session/start_workout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final day = programById(
    'full_body_3x',
  )!.weekSchedule.firstWhere((d) => d.isWorkout);

  test('programDayStarter builds a program-mode page with the full loadout', () {
    final page = programDayStarter(day);

    expect(page.isProgramWorkout, isTrue);
    expect(page.initialMuscleGroups, programDayTargetMuscleGroups(day));
    expect(page.programCuratedExerciseIds, day.suggestedExerciseIds);
    expect(page.programDayLabel, day.label);
    expect(page.programFocusSummary, programDayFocusSummary(day));
  });

  testWidgets('start confirm: CANCEL returns false, START returns true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showStartWorkoutConfirmDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('START THIS WORKOUT?'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
