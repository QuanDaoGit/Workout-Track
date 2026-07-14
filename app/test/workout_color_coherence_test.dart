import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/pages/program_detail_page.dart';
import 'package:workout_track/services/program_service.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/level_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('workout color coherence', () {
    testWidgets('difficulty badges use neutral metadata styling', (
      tester,
    ) async {
      for (final level in const ['beginner', 'intermediate', 'expert']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: LevelBadge(exercise: _exercise(level))),
            ),
          ),
        );

        final badge = tester.widget<Container>(
          find.byKey(ValueKey('level_badge_$level')),
        );
        final decoration = badge.decoration! as BoxDecoration;
        final border = decoration.border! as Border;
        final label = tester.widget<Text>(find.text(level.toUpperCase()));

        expect(border.top.color, kBorderVariant);
        expect(border.top.color, isNot(kNeon));
        expect(border.top.color, isNot(kAmber));
        expect(border.top.color, isNot(kDanger));
        expect(label.style?.color, kMutedText);
      }
    });

    testWidgets('program detail tier and schedule metadata stay neutral', (
      tester,
    ) async {
      final program = programById('ppl')!;

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramDetailPage(program: program, activeProgramId: null),
        ),
      );
      await tester.pumpAndSettle();

      final badge = tester.widget<Container>(
        find.byKey(const ValueKey('program_detail_tier_badge_ADVANCED')),
      );
      final decoration = badge.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      final badgeLabel = tester.widget<Text>(find.text('ADVANCED'));
      final schedule = tester.widget<Text>(find.text('6 days/week - 8 weeks'));
      final dayLabel = tester.widget<Text>(find.text('DAY 1'));

      expect(border.top.color, kBorderVariant);
      expect(border.top.color, isNot(kCyan));
      expect(border.top.color, isNot(kAmber));
      expect(border.top.color, isNot(kDanger));
      expect(badgeLabel.style?.color, kMutedText);
      expect(schedule.style?.color, kMutedText);
      expect(dayLabel.style?.color, kMutedText);
      expect(find.text('PATH REWARD'), findsOneWidget);
      expect(find.text('SPLIT DISCIPLINE'), findsOneWidget);
      expect(find.text('CURRENT PATH'), findsNothing);
    });

    testWidgets('active program detail renders current path HUD', (
      tester,
    ) async {
      final program = programById('upper_lower')!;
      await ProgramService(
        nowProvider: () => DateTime(2026, 6, 5),
      ).startProgram(program.id);

      await tester.pumpWidget(
        MaterialApp(
          home: ProgramDetailPage(
            program: program,
            activeProgramId: program.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The section header is the sole "CURRENT PATH" — the HUD suppresses its
      // eyebrow here, showing a bare "0 / N" count for the just-started path.
      expect(find.text('CURRENT PATH'), findsOneWidget);
      expect(
        find.textContaining('0 / ${program.targetSessions}'),
        findsWidgets,
      );
      expect(find.text('PATH REWARD'), findsNothing);
      expect(
        find.text('Missed days slow the path. They do not reset it.'),
        findsOneWidget,
      );
    });
  });
}

Exercise _exercise(String level) {
  return Exercise(
    id: 'test_$level',
    name: 'Test ${level.toUpperCase()}',
    level: level,
    images: const [],
  );
}
