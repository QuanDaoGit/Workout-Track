import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/widgets/arcade_chip.dart';
import 'package:workout_track/widgets/arcade_tap.dart';
import 'package:workout_track/widgets/motion/hold_depress.dart';
import 'package:workout_track/widgets/motion/phosphor_tap.dart';
import 'package:workout_track/widgets/train_nav_button.dart';

/// The shared tap wrappers default SILENT and only fire when a meaningful tap
/// opts in (Codex F1/F5). `ArcadeChip` is the one exception — a chip is always a
/// committing selection, so it ticks by default. `TrainNavButton` (the hero CTA)
/// fires a light tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    HapticService.enabled = true;
    HapticService.coalesceWindow = Duration.zero; // isolate opt-in wiring
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    HapticService.enabled = true;
    HapticService.coalesceWindow = const Duration(milliseconds: 30);
  });

  const sel = 'HapticFeedbackType.selectionClick';
  const light = 'HapticFeedbackType.lightImpact';

  testWidgets('PhosphorTap is silent by default, ticks when opted in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          PhosphorTap(onTap: () {}, child: const Text('silent')),
          PhosphorTap(
            onTap: () {},
            haptic: HapticIntent.selection,
            child: const Text('loud'),
          ),
        ]),
      ),
    ));

    await tester.tap(find.text('silent'));
    await tester.pump();
    expect(calls, isEmpty, reason: 'default wrapper is silent');

    await tester.tap(find.text('loud'));
    await tester.pump();
    expect(calls, <Object?>[sel]);
  });

  testWidgets('HoldDepress opted-in ticks on tap', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HoldDepress(
          onTap: () {},
          haptic: HapticIntent.selection,
          child: const Text('row'),
        ),
      ),
    ));
    await tester.tap(find.text('row'));
    await tester.pump();
    expect(calls, <Object?>[sel]);
  });

  testWidgets('ArcadeTap opted-in ticks on tap', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArcadeTap(
          onTap: () {},
          haptic: HapticIntent.selection,
          child: const Text('card'),
        ),
      ),
    ));
    await tester.tap(find.text('card'));
    await tester.pump();
    expect(calls, <Object?>[sel]);
  });

  testWidgets('ArcadeChip ticks by default (selection)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArcadeChip(label: 'CHEST', selected: false, onTap: () {}),
      ),
    ));
    await tester.tap(find.text('CHEST'));
    await tester.pump();
    expect(calls, <Object?>[sel]);
  });

  testWidgets('ArcadeChip with haptic:none is silent (handler-owned)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArcadeChip(
          label: 'CHEST',
          selected: false,
          onTap: () {},
          haptic: HapticIntent.none,
        ),
      ),
    ));
    await tester.tap(find.text('CHEST'));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('TrainNavButton fires a light tap on press', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TrainNavButton(mode: TrainButtonMode.idle, onTap: () {}),
      ),
    ));
    await tester.tap(find.byType(TrainNavButton));
    await tester.pump();
    expect(calls, <Object?>[light]);
  });
}
