import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/onboarding/cold_open_page.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/widgets/onboarding/option_question.dart';

/// Onboarding batch: the BIT wake-tap acks with a light tap, advancing past the
/// cold open ticks, and a calibration/option choice ticks. Driven under reduced
/// motion so the boot is instant (no 3s train to pump) — that path also proves
/// the wake-ack still fires when the ambient train is suppressed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    HapticService.enabled = true;
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
  });

  const light = 'HapticFeedbackType.lightImpact';
  const sel = 'HapticFeedbackType.selectionClick';

  Widget reducedMotion(Widget child) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('cold open: wake-tap acks (light tap), continue ticks',
      (tester) async {
    var continued = false;
    await tester.pumpWidget(
      reducedMotion(ColdOpenView(onContinue: () => continued = true)),
    );
    await tester.pump();

    // First tap wakes BIT (instant under reduced motion) -> a light ack.
    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    expect(calls, <Object?>[light]);

    // Second tap (booted) advances -> a selection tick + onContinue.
    await tester.tap(find.byType(ColdOpenView));
    await tester.pump();
    expect(calls, <Object?>[light, sel]);
    expect(continued, isTrue);
  });

  testWidgets('an option choice ticks (selection)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(reducedMotion(
      OptionList(
        hasAnySelection: false,
        animate: false,
        options: [
          OptionDef(
            title: 'POWER',
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ],
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('POWER'));
    await tester.pump();
    expect(calls, <Object?>[sel]);
    expect(tapped, isTrue);
  });
}
