import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/rest_timer_service.dart';
import 'package:workout_track/widgets/rest_timer_bar.dart';

/// P6: a rest that elapses while the bar is visible fires one "go" haptic;
/// a skip or a stale (backgrounded) expiry does not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    HapticService.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    });
  });

  tearDown(() {
    RestTimerService.instance.cancel();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    HapticService.enabled = true;
  });

  List<Object?> hapticArgs() => calls.map((c) => c.arguments).toList();

  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: RestTimerBar())),
  );

  testWidgets('a just-elapsed rest fires exactly one success haptic', (
    tester,
  ) async {
    // Inject a rest that ended a moment ago (a live finish).
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().subtract(const Duration(milliseconds: 300)),
      totalSeconds: 60,
    );
    await pumpBar(tester);
    await tester.pump(const Duration(seconds: 1)); // ticker detects expiry

    expect(hapticArgs(), <Object?>['HapticFeedbackType.mediumImpact']);

    // Cancelled after firing → further ticks do not re-fire.
    await tester.pump(const Duration(seconds: 1));
    expect(calls, hasLength(1));
  });

  testWidgets('a long-expired rest is suppressed (stale resume)', (
    tester,
  ) async {
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().subtract(const Duration(seconds: 30)),
      totalSeconds: 60,
    );
    await pumpBar(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(calls, isEmpty);
  });

  testWidgets('skipping a rest (cancel) fires no rest-done haptic', (
    tester,
  ) async {
    RestTimerService.instance.start(60); // active, far from done
    await pumpBar(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);

    RestTimerService.instance.cancel(); // user tapped SKIP
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);
  });

  testWidgets('global mute silences the rest-done haptic', (tester) async {
    HapticService.enabled = false;
    RestTimerService.instance.current.value = RestSnapshot(
      endsAt: DateTime.now().subtract(const Duration(milliseconds: 300)),
      totalSeconds: 60,
    );
    await pumpBar(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, isEmpty);
  });
}
