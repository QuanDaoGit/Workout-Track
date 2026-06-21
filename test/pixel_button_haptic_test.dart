import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/widgets/pixel_button.dart';

/// P1 keystone: every [PixelButton] press fires a haptic via the central
/// service, with a per-button [HapticIntent] override (and a global mute).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  void mockPlatform() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    });
  }

  setUp(() {
    calls.clear();
    HapticService.enabled = true;
    mockPlatform();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    HapticService.enabled = true;
  });

  List<Object?> hapticArgs() => calls.map((c) => c.arguments).toList();

  Future<void> pumpButton(
    WidgetTester tester, {
    HapticIntent? haptic,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: haptic == null
                ? PixelButton(label: 'GO', onPressed: onPressed ?? () {})
                : PixelButton(
                    label: 'GO',
                    haptic: haptic,
                    onPressed: onPressed ?? () {},
                  ),
          ),
        ),
      ),
    );
  }

  testWidgets('default press fires a light tap haptic', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.byType(PixelButton));
    await tester.pump();
    expect(hapticArgs(), <Object?>['HapticFeedbackType.lightImpact']);
  });

  testWidgets('haptic: none opts out (no buzz — for handler-owned haptics)', (
    tester,
  ) async {
    await pumpButton(tester, haptic: HapticIntent.none);
    await tester.tap(find.byType(PixelButton));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('haptic: reward fires a medium impact', (tester) async {
    await pumpButton(tester, haptic: HapticIntent.reward);
    await tester.tap(find.byType(PixelButton));
    await tester.pump();
    expect(hapticArgs(), <Object?>['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('a disabled button (null onPressed) never buzzes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PixelButton(label: 'GO', onPressed: null)),
        ),
      ),
    );
    await tester.tap(find.byType(PixelButton));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('global mute silences the press haptic', (tester) async {
    HapticService.enabled = false;
    await pumpButton(tester);
    await tester.tap(find.byType(PixelButton));
    await tester.pump();
    expect(calls, isEmpty);
  });
}
