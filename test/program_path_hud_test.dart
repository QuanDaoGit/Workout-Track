import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/programs_library.dart';
import 'package:workout_track/models/program_models.dart';
import 'package:workout_track/widgets/program_path_hud.dart';

void main() {
  Widget harness(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('new path shows honest zero progress with boot pips', (
    tester,
  ) async {
    final program = programById('upper_lower')!;
    final progress = ProgramProgress(
      programId: program.id,
      currentWeek: 1,
      currentDayIndex: 0,
      startedAt: DateTime(2026, 6, 5),
      completedSessions: 0,
    );

    await tester.pumpWidget(
      harness(ProgramPathHud(program: program, progress: progress)),
    );

    expect(find.text('PATH SET'), findsOneWidget);
    expect(find.textContaining('PATH SET'), findsWidgets);
    expect(
      find.textContaining('0 / ${program.targetSessions}'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('program_path_boot_pip')),
      findsNWidgets(2),
    );
  });

  testWidgets('path at seventy-five percent enters final stretch', (
    tester,
  ) async {
    final program = programById('upper_lower')!;
    final progress = ProgramProgress(
      programId: program.id,
      currentWeek: 6,
      currentDayIndex: 0,
      startedAt: DateTime(2026, 6, 5),
      completedSessions: (program.targetSessions * 0.75).round(),
    );

    await tester.pumpWidget(
      harness(ProgramPathHud(program: program, progress: progress)),
    );

    expect(find.text('FINAL STRETCH'), findsOneWidget);
    expect(find.textContaining('FINAL STRETCH'), findsWidgets);
  });

  testWidgets('completed path shows complete state and reward title', (
    tester,
  ) async {
    final program = programById('ppl')!;
    final progress = ProgramProgress(
      programId: program.id,
      currentWeek: 8,
      currentDayIndex: 6,
      startedAt: DateTime(2026, 6, 5),
      completedSessions: program.targetSessions,
      completedArc: true,
    );

    await tester.pumpWidget(
      harness(ProgramPathHud(program: program, progress: progress)),
    );

    expect(find.text('PATH COMPLETE'), findsOneWidget);
    expect(find.textContaining('PATH COMPLETE'), findsWidgets);
    expect(find.textContaining('SPLIT DISCIPLINE'), findsOneWidget);
  });

  testWidgets('in-progress path redacts the reward to a locked teaser', (
    tester,
  ) async {
    final program = programById('ppl')!;
    final progress = ProgramProgress(
      programId: program.id,
      currentWeek: 2,
      currentDayIndex: 0,
      startedAt: DateTime(2026, 6, 5),
      completedSessions: 4,
    );

    await tester.pumpWidget(
      harness(ProgramPathHud(program: program, progress: progress)),
    );

    // Reward exists but is hidden until 100% — concise locked teaser shows,
    // name/tier do not (the lock + panel context convey "locked until 100%").
    expect(find.text('REWARD'), findsOneWidget);
    expect(find.textContaining('SPLIT DISCIPLINE'), findsNothing);
    expect(find.text('LEGENDARY'), findsNothing);
  });

  testWidgets('reduced motion keeps content but disables spark overlay', (
    tester,
  ) async {
    final program = programById('upper_lower')!;
    final progress = ProgramProgress(
      programId: program.id,
      currentWeek: 2,
      currentDayIndex: 1,
      startedAt: DateTime(2026, 6, 5),
      completedSessions: 5,
    );

    await tester.pumpWidget(
      harness(
        ProgramPathHud(program: program, progress: progress),
        reduceMotion: true,
      ),
    );

    expect(
      find.textContaining('5 / ${program.targetSessions}'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('program_path_sparks')), findsNothing);
  });
}
