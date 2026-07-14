import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/rest_models.dart';
import 'package:workout_track/services/rest_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/session_projection.dart';
import 'package:workout_track/widgets/weekday_picker.dart';

/// Rendered-artifact + behaviour proof for the weekday-anchored schedule
/// surfaces (the Flutter web preview can't screenshot here). Goldens pin the
/// session-projection look; widget tests pin the picker's a11y + the immediate
/// onboarding apply. Regenerate goldens with `flutter test --update-goldens`.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double w = 320}) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(width: w, child: child),
            ),
          ),
        ),
      ),
    );
  }

  group('SessionProjection golden', () {
    testWidgets('3-day program maps one workout per training day', (t) async {
      await pump(
        t,
        SessionProjection(
          selected: const {1, 3, 5},
          program: programById('full_body_3x')!,
        ),
      );
      await t.pump();
      await expectLater(
        find.byType(SessionProjection),
        matchesGoldenFile('goldens/session_projection_full_body.png'),
      );
    });

    testWidgets('more days than workouts cycles the split', (t) async {
      // PPL has 6 workouts; 3 picks shows the first three in cycle order.
      await pump(
        t,
        SessionProjection(
          selected: const {2, 4, 6},
          program: programById('ppl')!,
        ),
      );
      await t.pump();
      await expectLater(
        find.byType(SessionProjection),
        matchesGoldenFile('goldens/session_projection_ppl.png'),
      );
    });
  });

  group('WeekdayPicker', () {
    testWidgets('exposes a labelled, selectable Semantics per day', (t) async {
      final selected = <int>{1, 3, 5};
      await pump(
        t,
        StatefulBuilder(
          builder: (context, setState) => WeekdayPicker(
            selected: selected,
            onToggle: (d) => setState(() =>
                selected.contains(d) ? selected.remove(d) : selected.add(d)),
          ),
        ),
      );

      expect(find.bySemanticsLabel('MON training day, on'), findsOneWidget);
      expect(find.bySemanticsLabel('TUE training day, off'), findsOneWidget);

      await t.tap(find.text('TUE'));
      await t.pump();
      expect(find.bySemanticsLabel('TUE training day, on'), findsOneWidget);
    });

    testWidgets('renders as a still, legible control under reduced motion',
        (t) async {
      await pump(
        t,
        WeekdayPicker(selected: const {1, 3, 5}, onToggle: (_) {}),
      );
      // All seven chips present and labelled even with animations disabled.
      for (final label in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('onboarding immediate weekday apply', () {
    test('saveTrainingWeekdays(immediate) takes effect this week', () async {
      SharedPreferences.setMockInitialValues({});
      // A Monday; choosing Tue/Thu/Sat must apply now, not next Monday.
      final rest = RestService(nowProvider: () => DateTime(2026, 6, 15));
      await rest.saveTrainingWeekdays(const {2, 4, 6}, immediate: true);

      final state = await rest.loadState(now: DateTime(2026, 6, 15));
      expect(state.trainingWeekdays, {2, 4, 6});
      expect(state.pendingTrainingWeekdays, isNull); // no next-Monday defer
    });

    test('default (non-immediate) still defers to next Monday', () async {
      SharedPreferences.setMockInitialValues({});
      final rest = RestService(nowProvider: () => DateTime(2026, 6, 15));
      await rest.saveTrainingWeekdays(const {2, 4, 6});

      final state = await rest.loadState(now: DateTime(2026, 6, 15));
      expect(state.trainingWeekdays, RestState.defaultTrainingWeekdays);
      expect(state.pendingTrainingWeekdays, {2, 4, 6});
    });
  });
}
