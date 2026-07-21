import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/last_session_tag.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: child,
      ),
    ),
  );

  testWidgets('shows only visible capability gains (not DEF/VIT/LCK)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const LastSessionTag(
          delta: {'STR': 49, 'END': 8, 'DEF': 30, 'VIT': 5, 'LCK': 1},
          stats: {'STR': 59, 'END': 18, 'DEF': 200, 'VIT': 90},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('LAST SESSION'), findsOneWidget);
    expect(find.textContaining('STR'), findsWidgets);
    expect(find.textContaining('END'), findsWidgets);
    // Hidden / non-capability stats never appear in the tag.
    expect(find.textContaining('DEF'), findsNothing);
    expect(find.textContaining('VIT'), findsNothing);
    expect(find.textContaining('LCK'), findsNothing);
  });

  testWidgets('annotates a rank-up on a gain that crossed a threshold', (
    tester,
  ) async {
    // STR 990 -> 1000 crosses D -> C.
    await tester.pumpWidget(
      host(const LastSessionTag(delta: {'STR': 10}, stats: {'STR': 1000})),
    );
    await tester.pump();

    expect(find.textContaining('D'), findsWidgets);
    expect(find.textContaining('C'), findsWidgets);
  });

  testWidgets('renders nothing when there are no visible gains', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const LastSessionTag(delta: {'DEF': 12, 'LCK': 1}, stats: {'DEF': 100}),
      ),
    );
    await tester.pump();

    expect(find.text('LAST SESSION'), findsNothing);
  });
}
