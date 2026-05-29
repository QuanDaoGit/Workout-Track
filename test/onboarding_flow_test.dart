import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/user_profile_sex.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/workout_summary.dart';
import 'package:workout_track/pages/onboarding/calibration_data_page.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/pages/onboarding/onboarding_flow_page.dart';
import 'package:workout_track/pages/onboarding/problem_question_page.dart';
import 'package:workout_track/pages/onboarding/solution_page.dart';
import 'package:workout_track/pages/onboarding/rank_assessed_page.dart';
import 'package:workout_track/services/onboarding_service.dart';
import 'package:workout_track/widgets/welcome_bench_press_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'OnboardingService defaults to incomplete and flips on markComplete',
    () async {
      final svc = OnboardingService();
      expect(await svc.isComplete(), isFalse);
      await svc.markComplete();
      expect(await svc.isComplete(), isTrue);
    },
  );

  testWidgets(
    'Cold open renders welcome boot screen and fires onContinue on tap',
    (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColdOpenView(onContinue: () => continued = true),
          ),
        ),
      );
      expect(find.text('IRONBIT'), findsOneWidget);
      expect(find.text('WELCOME, RECRUIT'), findsOneWidget);
      expect(find.text('YOUR TRAINING BUILDS YOUR CHARACTER'), findsOneWidget);
      expect(find.text('STR'), findsOneWidget);
      expect(find.text('PRESS START'), findsOneWidget);
      await tester.tap(find.byType(ColdOpenView));
      expect(continued, isTrue);
    },
  );

  testWidgets('Onboarding flow shows problem screen after cold open', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));

    expect(find.byType(ColdOpenView), findsOneWidget);
    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();

    expect(find.byType(ProblemQuestionView), findsOneWidget);
  });

  testWidgets('Welcome to Problem uses the onboarding CRT wipe', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));

    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const ValueKey('onboarding_transition_layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding_crt_wipe_line')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    expect(find.byType(ProblemQuestionView), findsOneWidget);
  });

  testWidgets('Problem to Solution uses the amber ripple transition', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));

    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const ValueKey('onboarding_amber_ripple')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();
    expect(find.byType(SolutionView), findsOneWidget);
  });

  testWidgets('Solution CTA starts the onboarding amber handoff', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlowPage()));

    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.tap(find.byType(ProblemQuestionView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();
    await tester.tap(find.byType(SolutionView));
    await tester.pump();
    await tester.tap(find.text('BUILD MY CHARACTER'));
    await tester.pump(const Duration(milliseconds: 140));

    expect(
      find.byKey(const ValueKey('onboarding_handoff_iris')),
      findsOneWidget,
    );
  });

  testWidgets('Calibration summary returns to caller after rank reveal', (
    tester,
  ) async {
    var summaryReturned = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => WorkoutSummaryPage(
                      muscleGroup: 'Full Body',
                      targetMuscleGroups: const ['Full Body'],
                      durationMinutes: 20,
                      elapsedSeconds: 600,
                      exerciseLogs: const [
                        ExerciseLog(
                          exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
                          exerciseName: 'Barbell Bench Press',
                          sets: [SetEntry(weight: 40, reps: 8)],
                        ),
                      ],
                      selectedExerciseIds: const [
                        'Barbell_Bench_Press_-_Medium_Grip',
                      ],
                      isCalibration: true,
                    ),
                  ),
                );
                summaryReturned = true;
              },
              child: const Text('OPEN SUMMARY'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN SUMMARY'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await _pumpUntilFound(tester, find.byType(RankAssessedPage));

    expect(find.text('RANK ASSESSED'), findsOneWidget);
    expect(summaryReturned, isFalse);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('OPEN SUMMARY'));

    expect(summaryReturned, isTrue);
  });

  testWidgets('Problem screen reduced motion renders final static copy', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ProblemQuestionView(onContinue: (_) => continued = true),
          ),
        ),
      ),
    );

    expect(_findProblemQuestion(), findsOneWidget);
    expect(
      find.text(
        "You're not alone. The work never feels like it adds up — so it fades before it shows.",
      ),
      findsOneWidget,
    );
    expect(find.text('tap to continue ›'), findsOneWidget);
    expect(find.byKey(const ValueKey('problem_failed_lifter')), findsOneWidget);
    expect(_usesFontFamily(tester, 'PressStart2P'), isFalse);

    await tester.tap(find.byType(ProblemQuestionView));
    expect(continued, isTrue);
  });

  testWidgets(
    'Problem screen first tap completes intro, second tap continues',
    (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProblemQuestionView(onContinue: (_) => continued = true),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ProblemQuestionView));
      await tester.pump();

      expect(continued, isFalse);
      expect(_findProblemQuestion(), findsOneWidget);

      await tester.tap(find.byType(ProblemQuestionView));
      expect(continued, isTrue);
    },
  );

  testWidgets('Welcome bench press scene renders with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: WelcomeBenchPressScene())),
        ),
      ),
    );

    expect(find.byType(WelcomeBenchPressScene), findsOneWidget);
  });

  testWidgets('Welcome bench press scene survives payoff and full loop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: WelcomeBenchPressScene())),
      ),
    );

    await tester.pump(const Duration(milliseconds: 8200));
    expect(find.byType(WelcomeBenchPressScene), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(WelcomeBenchPressScene), findsOneWidget);
  });

  testWidgets('Calibration data submits parsed bodyweight and selected sex', (
    tester,
  ) async {
    double? submittedBw;
    UserProfileSex? submittedSex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationDataView(
            onSubmit: (bw, sex) {
              submittedBw = bw;
              submittedSex = sex;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '75');
    await tester.tap(find.text('Male'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(submittedBw, 75.0);
    expect(submittedSex, UserProfileSex.male);
  });

  testWidgets('Calibration data treats blank bodyweight as skipped (null)', (
    tester,
  ) async {
    double? submittedBw = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationDataView(onSubmit: (bw, _) => submittedBw = bw),
        ),
      ),
    );
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(submittedBw, isNull);
  });
}

bool _usesFontFamily(WidgetTester tester, String family) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_spanUsesFontFamily(richText.text, family)) return true;
  }
  return false;
}

Finder _findProblemQuestion() => find.text(
  'Ever start strong —\nthen quit by week two?',
  findRichText: true,
);

bool _spanUsesFontFamily(InlineSpan span, String family) {
  if (span.style?.fontFamily == family) return true;
  if (span is TextSpan) {
    final children = span.children;
    if (children == null) return false;
    return children.any((child) => _spanUsesFontFamily(child, family));
  }
  return false;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
