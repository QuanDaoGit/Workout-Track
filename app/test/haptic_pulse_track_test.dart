import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/widgets/motion/haptic_pulse_track.dart';

/// [HapticPulseTrack] couples a one-shot pulse-train to an animation. These pin
/// the hardened lifecycle the Codex review demanded: forward-only, skipped-frame
/// flushing, completion payoff, no re-fire on reverse/repeat, dispose-safety.
///
/// Plain `test()` (not `testWidgets`): we drive the controller's value directly
/// and need real async so `pumpEventQueue` can flush the platform-channel haptic
/// calls (inside `testWidgets`' FakeAsync those zero-timers would never fire).
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

  AnimationController makeController() => AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );

  const sel = 'HapticFeedbackType.selectionClick';
  const reward = 'HapticFeedbackType.mediumImpact';

  test('interior ticks + terminal payoff fire in order', () async {
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(
      animation: c,
      pulses: 3,
      finalIntent: HapticIntent.reward,
    );
    addTearDown(track.dispose);

    c.value = 0.3; // crosses 0.25
    c.value = 0.6; // crosses 0.50
    c.value = 0.9; // crosses 0.75
    c.value = 1.0; // completed -> terminal reward
    await pumpEventQueue();

    expect(calls, <Object?>[sel, sel, sel, reward]);
  });

  test('a skipped frame straight to 1.0 still fires every threshold + payoff',
      () async {
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(
      animation: c,
      pulses: 3,
      finalIntent: HapticIntent.reward,
    );
    addTearDown(track.dispose);

    c.value = 1.0; // one jump: status completed + value listener at 1.0
    await pumpEventQueue();

    expect(calls, <Object?>[sel, sel, sel, reward],
        reason: 'a stuttered jump must not swallow ticks or the payoff');
  });

  test('reverse motion never fires and never rewinds the cursor', () async {
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(animation: c, pulses: 3);
    addTearDown(track.dispose);

    c.value = 0.6; // crosses 0.25 + 0.50 -> 2 ticks
    c.value = 0.3; // reverse: no fire
    c.value = 0.55; // forward again but no new threshold crossed
    await pumpEventQueue();

    expect(calls, <Object?>[sel, sel],
        reason: 'reverse must be inert; re-climbing must not re-fire');
  });

  test('a repeating controller does not re-fire on the second pass', () async {
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(
      animation: c,
      pulses: 2,
      finalIntent: HapticIntent.reward,
    );
    addTearDown(track.dispose);

    c.value = 1.0; // pass 1: 2 ticks + reward
    c.value = 0.0; // repeat reset (reverse) -> inert
    c.value = 1.0; // pass 2: nothing (forward-only, fire-once)
    await pumpEventQueue();

    expect(calls, <Object?>[sel, sel, reward]);
  });

  test('dispose before completion fires nothing further', () async {
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(
      animation: c,
      pulses: 3,
      finalIntent: HapticIntent.reward,
    );

    c.value = 0.3; // 1 tick
    await pumpEventQueue();
    track.dispose();
    c.value = 1.0; // disposed -> ignored
    await pumpEventQueue();

    expect(calls, <Object?>[sel],
        reason: 'no pulses after dispose, even on completion');
  });

  test('no finalIntent = ticks only (ambient train, e.g. BIT boot)', () async {
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(animation: c, pulses: 2); // 1/3, 2/3
    addTearDown(track.dispose);

    c.value = 1.0;
    await pumpEventQueue();

    expect(calls, <Object?>[sel, sel], reason: 'no terminal payoff when unset');
  });

  test('global mute silences the whole train', () async {
    HapticService.enabled = false;
    final c = makeController();
    addTearDown(c.dispose);
    final track = HapticPulseTrack(
      animation: c,
      pulses: 3,
      finalIntent: HapticIntent.reward,
    );
    addTearDown(track.dispose);

    c.value = 1.0;
    await pumpEventQueue();

    expect(calls, isEmpty);
  });
}
