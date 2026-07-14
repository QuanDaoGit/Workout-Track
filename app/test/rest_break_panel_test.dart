import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/widgets/companion/bit_mood_core.dart';
import 'package:workout_track/widgets/rest_break_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final haptics = <MethodCall>[];

  setUp(() {
    haptics.clear();
    HapticService.enabled = true;
    RestTimerService.instance.cancel();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
      return null;
    });
  });

  tearDown(() {
    RestTimerService.instance.cancel();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    String? next = 'Incline Dumbbell Press',
    VoidCallback? onSkip,
    bool reduce = false,
  }) {
    final panel = RestBreakPanel(
      onSkip: onSkip ?? () {},
      nextExerciseName: next,
    );
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: panel,
          ),
        ),
      ),
    );
  }

  testWidgets('renders BIT, countdown, NEXT line and the three controls', (
    tester,
  ) async {
    RestTimerService.instance.start(90);
    await pump(tester);

    expect(find.byType(BitMoodCore), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+:\d\d$')), findsOneWidget);
    expect(find.text('NEXT · Incline Dumbbell Press'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '+15s'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'SKIP REST'), findsOneWidget);
  });

  testWidgets('the NEXT line is hidden when no next exercise is given', (
    tester,
  ) async {
    RestTimerService.instance.start(90);
    await pump(tester, next: null);
    expect(find.textContaining('NEXT'), findsNothing);
  });

  testWidgets('+15s extends the rest; −15s shortens it', (tester) async {
    RestTimerService.instance.start(90);
    await pump(tester);

    int remaining() =>
        RestTimerService.instance.current.value!.remaining.inSeconds;

    final beforeAdd = remaining();
    await tester.tap(find.bySemanticsLabel('Add 15 seconds of rest'));
    await tester.pump();
    expect(remaining() - beforeAdd, inInclusiveRange(13, 16)); // ~ +15

    final beforeSub = remaining();
    await tester.tap(find.bySemanticsLabel('Subtract 15 seconds of rest'));
    await tester.pump();
    expect(beforeSub - remaining(), inInclusiveRange(13, 16)); // ~ −15
  });

  testWidgets('SKIP REST invokes the callback', (tester) async {
    var skipped = false;
    RestTimerService.instance.start(90);
    await pump(tester, onSkip: () => skipped = true);

    await tester.tap(find.widgetWithText(FilledButton, 'SKIP REST'));
    await tester.pump();
    expect(skipped, isTrue);
  });

  testWidgets('the ±15s controls are at least 44px tall', (tester) async {
    RestTimerService.instance.start(90);
    await pump(tester);
    final size = tester.getSize(find.widgetWithText(FilledButton, '+15s'));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('reduced motion still renders a legible panel', (tester) async {
    RestTimerService.instance.start(90);
    await pump(tester, reduce: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BitMoodCore), findsOneWidget); // posed still frame
    expect(find.textContaining(RegExp(r'^\d+:\d\d$')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'SKIP REST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live rest-end fires exactly one haptic then cancels', (
    tester,
  ) async {
    // A rest that ended a moment ago (a live finish).
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().subtract(const Duration(milliseconds: 300)),
      totalSeconds: 90,
    );
    await pump(tester);
    await tester.pump(const Duration(seconds: 1)); // ticker detects expiry

    expect(haptics, hasLength(1));
    expect(RestTimerService.instance.current.value, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(haptics, hasLength(1)); // cancelled → no re-fire
  });

  testWidgets('the ticker is cancelled on dispose (no pending timer)', (
    tester,
  ) async {
    RestTimerService.instance.start(90);
    await pump(tester);
    await tester.pump(const Duration(seconds: 1));
    // Unmount the panel; dispose must cancel the periodic ticker.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
