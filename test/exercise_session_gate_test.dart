import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/exercise_session.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';

/// The sequential-logging gate, the rest-start notice, and the removed plate
/// hint on the set-logging screen.
Exercise _exercise(String id, {String equipment = ''}) => Exercise(
  id: id,
  name: id,
  level: 'beginner',
  images: const [],
  equipment: equipment,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RestTimerService.instance.cancel();
    ExerciseKindCache.instance.resetForTest();
  });
  tearDown(() => RestTimerService.instance.cancel());

  Future<void> pumpPage(WidgetTester tester, {String equipment = ''}) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ExerciseSessionPage(exercise: _exercise('a', equipment: equipment))),
    );
    await tester.pumpAndSettle();
  }

  TextField fieldAt(WidgetTester tester, int i) =>
      tester.widget<TextField>(find.byType(TextField).at(i));

  testWidgets('a later set is gated until the previous one is logged', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('+ ADD SET'));
    await tester.pumpAndSettle();

    // Row 0 (frontier) editable; row 1 (gated) disabled.
    expect(fieldAt(tester, 0).enabled, isTrue); // row 0 weight
    expect(fieldAt(tester, 2).enabled, isFalse); // row 1 weight (gated)

    // Tapping the gated row warns instead of accepting input.
    await tester.tapAt(tester.getCenter(find.byType(TextField).at(2)));
    await tester.pump();
    expect(find.text('Log your previous set first'), findsOneWidget);
  });

  testWidgets('logging the frontier promotes the next row to editable', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('+ ADD SET'));
    await tester.pumpAndSettle();
    expect(fieldAt(tester, 2).enabled, isFalse); // row 1 gated

    // Log row 0.
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_sharp).first);
    await tester.pump();

    // Row 1 is now the frontier → editable.
    expect(fieldAt(tester, 2).enabled, isTrue);
  });

  testWidgets('logging a set shows the "Rest timer started" notice', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_sharp));
    await tester.pump();
    expect(find.text('Rest timer started'), findsOneWidget);
    expect(RestTimerService.instance.current.value?.isActive, isTrue);
  });

  testWidgets('the plate-calc hint line is gone (even for a barbell)', (
    tester,
  ) async {
    await pumpPage(tester, equipment: 'barbell');
    expect(find.textContaining('plate calc'), findsNothing);
  });
}
