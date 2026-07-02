import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/theme/tokens.dart';

/// When Set 1 is logged it auto-copies its load into the empty rows below and
/// marks them "prefilled" (muted). The bug: logging such a prefilled row left it
/// muted because `_logSet` never cleared the prefilled flag — even though the
/// set is fully committed. These tests pin (a) a logged prefilled row renders
/// bright, and (b) the prefilled value is actually persisted (it counts).
Exercise _exercise(String id) => Exercise(
  id: id,
  name: id,
  level: 'beginner',
  images: const [],
  equipment: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  TextField fieldAt(WidgetTester tester, int i) =>
      tester.widget<TextField>(find.byType(TextField).at(i));

  testWidgets(
    'logging an auto-prefilled row brightens it AND records the set',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      List<SetEntry> committed = const [];
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseSessionPage(
            exercise: _exercise('a'),
            onSetsCommitted: (sets) => committed = sets,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Three working rows, mirroring the screenshot.
      await tester.tap(find.text('+ ADD SET'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ ADD SET'));
      await tester.pumpAndSettle();

      // Type Set 1 by hand, then log it → rows 2 & 3 auto-fill (muted/prefilled).
      await tester.enterText(find.byType(TextField).at(0), '55');
      await tester.enterText(find.byType(TextField).at(1), '8');
      await tester.tap(find.widgetWithText(FilledButton, 'SAVE').first);
      await tester.pumpAndSettle();

      // Row 2 (frontier now) is prefilled "55"/"8" — log it directly via its
      // check button, WITHOUT tapping the field (the screenshot's path).
      await tester.tap(find.widgetWithText(FilledButton, 'SAVE').first);
      await tester.pumpAndSettle();

      // UI: the just-logged prefilled row is no longer muted (bright like Set 1).
      expect(
        fieldAt(tester, 2).style?.color,
        isNot(kMutedText),
        reason: 'logged row 2 weight should be bright, not the prefilled grey',
      );
      expect(
        fieldAt(tester, 3).style?.color,
        isNot(kMutedText),
        reason: 'logged row 2 reps should be bright, not the prefilled grey',
      );

      // Data: both sets persisted, and the prefilled set carries Set 1's values.
      expect(committed.length, 2, reason: 'both logged sets count');
      expect(committed[1].reps, 8, reason: 'prefilled reps recorded');
      expect(
        committed[1].weight,
        committed[0].weight,
        reason: 'prefilled weight equals the typed Set 1 weight (it counts)',
      );
      expect(committed[1].weight, greaterThan(0));
    },
  );
}
