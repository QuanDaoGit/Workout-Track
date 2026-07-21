import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/Workout session/active_workout.dart';
import 'package:workout_track/services/exercise_kind_cache.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';

/// The session hub's frontier BIT: a small faced BitMoodCore rides the first
/// un-cleared exercise card (one source of truth with the rest panel's NEXT),
/// cleared cards keep a quiet neon warmth, and at all-clear BIT docks in cheer
/// above the enabled Finish button. Spec:
/// docs/superpowers/specs/2026-07-21-session-hub-bit-frontier-design.md
const _frontierKey = ValueKey('frontier_bit');
const _dockKey = ValueKey('session_bit_dock');

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

  // Bounded pumps throughout — the hub now hosts a perpetual-ticker BIT, so
  // pumpAndSettle would never settle while this page is mounted (Codex F1).
  Future<void> pumpHub(
    WidgetTester tester, {
    WorkoutSession? resume,
    double textScale = 1.0,
    bool reduceMotion = false,
    Size surface = const Size(1080, 3000),
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: ActiveWorkoutPage(
          muscleGroup: 'Chest',
          durationMinutes: 30,
          exercises: [_exercise('a', 'alpha'), _exercise('b', 'bravo')],
          resumeFromSession: resume,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The exercise card = the nearest DecoratedBox above the name text.
  Finder card(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(DecoratedBox)).first;

  BoxDecoration decoOf(WidgetTester tester, String name) =>
      tester.widget<DecoratedBox>(card(name)).decoration as BoxDecoration;

  testWidgets('fresh session: one neutral frontier BIT on the first card', (
    tester,
  ) async {
    await pumpHub(tester);
    expect(find.byKey(_frontierKey), findsOneWidget);
    expect(find.byKey(_dockKey), findsNothing);
    final bit = tester.widget<BitMoodCore>(find.byKey(_frontierKey));
    expect(bit.reveal, 1); // faceless-default trap — must be faced
    expect(bit.pose, BitPose.neutral);
    expect(bit.size, 44);
    expect(bit.idleAmp, 0.55);
    // Structurally inside alpha's card, and NOT inside bravo's (Codex F3).
    expect(
      find.descendant(of: card('alpha'), matching: find.byKey(_frontierKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card('bravo'), matching: find.byKey(_frontierKey)),
      findsNothing,
    );
  });

  testWidgets('frontier advances past cleared exercises on resume', (
    tester,
  ) async {
    await pumpHub(tester, resume: _resume({'a': 'alpha'}));
    expect(find.byKey(_frontierKey), findsOneWidget);
    expect(
      find.descendant(of: card('bravo'), matching: find.byKey(_frontierKey)),
      findsOneWidget,
    );
  });

  testWidgets('cleared card carries the quiet neon warmth', (tester) async {
    await pumpHub(tester, resume: _resume({'a': 'alpha'}));
    // The cleared card: warm border + wash, field-by-field (Codex F2).
    final warm = decoOf(tester, 'alpha');
    final warmBorder = warm.border! as Border;
    expect(warmBorder.top.color, kNeon.withValues(alpha: 0.38));
    expect(warmBorder.top.width, 1.0);
    expect(
      warm.color,
      Color.alphaBlend(kNeon.withValues(alpha: 0.05), kCard),
    );
    // The frontier card keeps today's resting look.
    final fresh = decoOf(tester, 'bravo');
    expect((fresh.border! as Border).top.color, kBorder);
    expect(fresh.color, kCard);
  });

  testWidgets('all-clear: no frontier BIT, cheer dock above Finish', (
    tester,
  ) async {
    await pumpHub(tester, resume: _resume({'a': 'alpha', 'b': 'bravo'}));
    expect(find.byKey(_frontierKey), findsNothing);
    expect(find.byKey(_dockKey), findsOneWidget);
    final bit = tester.widget<BitMoodCore>(find.byKey(_dockKey));
    expect(bit.reveal, 1);
    expect(bit.pose, BitPose.cheer);
    expect(bit.size, 56);
    expect(find.text('Finish Workout'), findsOneWidget);
  });

  testWidgets('large text hides the frontier BIT, card layout intact', (
    tester,
  ) async {
    await pumpHub(tester, textScale: 1.3, surface: const Size(320, 800));
    expect(find.byKey(_frontierKey), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps the all-clear dock', (tester) async {
    await pumpHub(
      tester,
      resume: _resume({'a': 'alpha', 'b': 'bravo'}),
      textScale: 1.3,
    );
    expect(find.byKey(_dockKey), findsOneWidget);
  });

  testWidgets('reduced motion: BIT still present and still', (tester) async {
    await pumpHub(tester, reduceMotion: true);
    expect(find.byKey(_frontierKey), findsOneWidget);
    // Static under reduced motion — a further pump must not throw; the
    // status texts remain the assistive-tech carrier.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('READY'), findsNWidgets(2));
  });
}
