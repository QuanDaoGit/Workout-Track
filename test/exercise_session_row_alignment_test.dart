import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/widgets/motion/arcade_text_field.dart';

/// The set-row bug: the weight field carries a plate-calculator `suffixIcon` and
/// the reps field does not. Both are the same [ArcadeTextField] in the same
/// fixed-height (48px) row, but a `suffixIcon` makes Flutter's `InputDecorator`
/// size the input row to the (taller) icon and baseline-align the text inside it,
/// so "55" sat a few px off "15". The fix gives the reps field a zero-width
/// height-spacer matching the calc button, so both decorations resolve the same
/// input-row height — without the reps field surrendering any horizontal space.
///
/// The oracle is geometric — the vertical center of each field's `EditableText` —
/// so it holds even though fonts render as boxes in the test env.

double _gap(WidgetTester tester) {
  // [0] = weight field (has the suffixIcon), [1] = reps field.
  final weightY = tester.getCenter(find.byType(EditableText).at(0)).dy;
  final repsY = tester.getCenter(find.byType(EditableText).at(1)).dy;
  return (weightY - repsY).abs();
}

void main() {
  // --- Mechanism: a red/green pair on ArcadeTextField in isolation ----------
  Widget twoFields({required Widget? repsSuffix}) {
    final weight = TextEditingController(text: '55');
    final reps = TextEditingController(text: '15');
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Row(
            children: [
              Expanded(
                child: ArcadeTextField(
                  controller: weight,
                  height: 48,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  // Mirrors the real plate-calc suffix (28px tall, pinned).
                  suffixIcon: const SizedBox(width: 28, height: 28),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ArcadeTextField(
                  controller: reps,
                  height: 48,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  suffixIcon: repsSuffix,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('mechanism (defect): a suffixIcon on the weight field alone shifts '
      'its text baseline off the reps field', (tester) async {
    await tester.pumpWidget(twoFields(repsSuffix: null));
    await tester.pump();
    expect(_gap(tester), greaterThan(1.0),
        reason: 'the icon-less reps field mis-aligns with the suffixed weight '
            'field — the InputDecorator tracks the taller suffix box');
  });

  testWidgets('mechanism (fix): a matching height-spacer on the reps field lines '
      'up the two baselines', (tester) async {
    // Zero width so the reps text keeps full width; height matches the weight
    // suffix so both decorations resolve the same input-row height.
    await tester.pumpWidget(
      twoFields(repsSuffix: const SizedBox(width: 0, height: 28)),
    );
    await tester.pump();
    expect(_gap(tester), lessThan(0.5),
        reason: 'matching the input-row height on both fields must put the '
            'baselines on the same line');
  });

  // --- Faithful: the real ExerciseSessionPage with a plate-loaded lift -------
  group('real screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      RestTimerService.instance.cancel();
      ExerciseKindCache.instance.resetForTest();
    });
    tearDown(() => RestTimerService.instance.cancel());

    testWidgets('the weight (with calc button) and reps numbers sit on one line',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseSessionPage(
            exercise: Exercise(
              id: 'a',
              name: 'a',
              level: 'beginner',
              images: const [],
              equipment: 'barbell', // → plate calc button on the weight field
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type into both fields so each EditableText has a glyph to place.
      await tester.enterText(find.byType(TextField).at(0), '55');
      await tester.enterText(find.byType(TextField).at(1), '15');
      await tester.pump();

      expect(_gap(tester), lessThan(0.5),
          reason: 'the weight and reps numbers must align on the actual screen');
    });
  });
}
