import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/loot_item.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/pages/Workout session/program_completion_reveal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'reveal shows program, earned title, sessions, and next-path CTAs',
    (tester) async {
      final completion = ProgramCompletion(
        programId: 'full_body_3x',
        titleId: 'title_foundation_forged',
        sessions: 24,
        completedAt: DateTime(2026, 6, 5),
      );

      await tester.pumpWidget(
        MediaQuery(
          // Reduced motion skips the timeline so all beats render immediately.
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: ProgramCompletionRevealScreen(completion: completion),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PATH COMPLETE'), findsOneWidget);
      expect(find.text('FULL BODY 3X'), findsOneWidget);
      expect(find.text('FOUNDATION FORGED'), findsOneWidget);
      expect(find.textContaining('24 / 24'), findsOneWidget);
      expect(find.text('NEXT PATH: UPPER LOWER - 32 SESSIONS'), findsOneWidget);
      expect(find.text('BEGIN NEXT PATH'), findsOneWidget);
      expect(find.text('STAY WITH THIS PROGRAM'), findsOneWidget);

      final titleText = tester.widget<Text>(find.text('FOUNDATION FORGED'));
      expect((titleText.style as TextStyle).color, LootRarity.legendary.color);
    },
  );

  testWidgets('tap during cinematic skips to final reveal state', (
    tester,
  ) async {
    final completion = ProgramCompletion(
      programId: 'upper_lower',
      titleId: 'title_iron_rhythm',
      sessions: 32,
      completedAt: DateTime(2026, 6, 5),
    );

    await tester.pumpWidget(
      MaterialApp(home: ProgramCompletionRevealScreen(completion: completion)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('IRON RHYTHM'), findsNothing);

    await tester.tap(find.byType(ProgramCompletionRevealScreen));
    await tester.pump();

    expect(find.text('IRON RHYTHM'), findsOneWidget);
    expect(
      find.text('NEXT PATH: PUSH PULL LEGS - 48 SESSIONS'),
      findsOneWidget,
    );
    expect(find.text('BEGIN NEXT PATH'), findsOneWidget);
    expect(find.text('STAY WITH THIS PROGRAM'), findsOneWidget);
  });
}
