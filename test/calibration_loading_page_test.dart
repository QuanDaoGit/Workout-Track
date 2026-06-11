import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/body_goal_models.dart';
import 'package:workout_track/models/calibration_quiz_models.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/pages/onboarding/calibration_loading_page.dart';

const _pre = PreClassAnswers(
  goal: BodyGoal.recomp,
  bodyWeightKg: 72,
  sex: UserProfileSex.preferNotToSay,
);

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function(DateTime) onCalibrated,
  required void Function(DateTime) onReveal,
  bool reducedMotion = false,
}) async {
  Widget page = CalibrationLoadingPage(
    answers: _pre,
    onCalibrated: onCalibrated,
    onReveal: onReveal,
  );
  if (reducedMotion) {
    page = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: page,
    );
  }
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders header, telemetry and the operation log', (
    tester,
  ) async {
    await _pump(tester, onCalibrated: (_) async {}, onReveal: (_) {});

    expect(find.text('CALIBRATING PROFILE'), findsOneWidget);
    expect(find.byKey(const ValueKey('calibration_telemetry')), findsOneWidget);
    expect(find.text('READING GOAL VECTOR'), findsOneWidget);
    expect(find.text('RESOLVING CLASS'), findsOneWidget);
    expect(find.text('CALIBRATING…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('is unskippable, then completes and reveals on tap', (
    tester,
  ) async {
    var calibrated = 0;
    DateTime? calibratedAt;
    var revealed = 0;
    DateTime? revealedAt;

    await _pump(
      tester,
      onCalibrated: (at) async {
        calibrated++;
        calibratedAt = at;
      },
      onReveal: (at) {
        revealed++;
        revealedAt = at;
      },
    );

    // Before complete: the loading is unskippable — a tap does nothing.
    await tester.tap(find.byType(CalibrationLoadingPage));
    await tester.pump();
    expect(revealed, 0);
    expect(find.text('CALIBRATION COMPLETE'), findsNothing);

    // Past the minimum display time + the (instant) real work → COMPLETE holds.
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.text('CALIBRATION COMPLETE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calibration_tap_prompt')),
      findsOneWidget,
    );
    expect(calibrated, 1);

    // The tap now fires the reveal exactly once, with the stamped time.
    await tester.tap(find.byType(CalibrationLoadingPage));
    await tester.pump();
    expect(revealed, 1);
    expect(revealedAt, calibratedAt);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion completes immediately and still reveals on tap', (
    tester,
  ) async {
    var revealed = 0;
    await _pump(
      tester,
      reducedMotion: true,
      onCalibrated: (_) async {},
      onReveal: (_) => revealed++,
    );
    await tester.pump();

    expect(find.text('CALIBRATION COMPLETE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calibration_tap_prompt')),
      findsOneWidget,
    );

    await tester.tap(find.byType(CalibrationLoadingPage));
    await tester.pump();
    expect(revealed, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('runs the real calibration work exactly once', (tester) async {
    var calls = 0;
    await _pump(tester, onCalibrated: (_) async => calls++, onReveal: (_) {});
    await tester.pump(const Duration(milliseconds: 4200));
    expect(calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
