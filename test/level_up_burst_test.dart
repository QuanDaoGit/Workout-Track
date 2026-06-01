import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/level_up_burst.dart';

void main() {
  testWidgets('idle renders nothing; triggering plays without error', (
    tester,
  ) async {
    var trigger = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                Positioned.fill(child: LevelUpBurst(trigger: trigger)),
                Center(
                  child: ElevatedButton(
                    onPressed: () => setState(() => trigger++),
                    child: const Text('GO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stays inert on trigger', (tester) async {
    var trigger = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) => Stack(
                children: [
                  Positioned.fill(child: LevelUpBurst(trigger: trigger)),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => setState(() => trigger++),
                      child: const Text('GO'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('GO'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
