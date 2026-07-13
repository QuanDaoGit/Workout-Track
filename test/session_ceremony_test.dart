import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/services/haptic_service.dart';
import 'package:workout_track/services/sfx_service.dart';
import 'package:workout_track/widgets/companion/session_ceremony.dart';

/// The Session-Complete ceremony's control flow: the one-clock threshold
/// pipeline, tap-to-skip idempotency, the seat-measurement fallback, and the
/// reduced-motion guard. (The visuals — flight curve, particles — are motion
/// and need on-device eyeballing; these tests pin the *behavioral* contract.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SfxService.enabled = false; // no audio plugin in the test env
    HapticService.enabled = false;
  });
  tearDown(() {
    SfxService.enabled = true;
    HapticService.enabled = true;
  });

  /// Advance the ceremony clock by [ms]. The ceremony clamps a single tick to
  /// 60ms (the prototype's rAF hiccup guard), so pump in small steps.
  Future<void> pumpFor(WidgetTester tester, int ms) async {
    var left = ms;
    while (left > 0) {
      final step = left < 50 ? left : 50;
      await tester.pump(Duration(milliseconds: step));
      left -= step;
    }
  }

  Widget host({
    required GlobalKey seatKey,
    required ValueChanged<String> onEvent,
    bool withSeat = true,
    bool reducedMotion = false,
  }) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            if (withSeat)
              Positioned(
                top: 40,
                left: 100,
                child: SizedBox(key: seatKey, width: 72, height: 72),
              ),
            Positioned.fill(
              child: SessionCeremony(
                seatKey: seatKey,
                onSurge: () => onEvent('surge'),
                onSettled: () => onEvent('settled'),
                onFinished: () => onEvent('finished'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('full timeline: surge once, settle once, then finish', (
    tester,
  ) async {
    final events = <String>[];
    final seatKey = GlobalKey();
    await tester.pumpWidget(host(seatKey: seatKey, onEvent: events.add));

    // Pre-surge: nothing fired.
    await pumpFor(tester, 400);
    expect(events, isEmpty);

    // Past the release: surge exactly once, no settle yet.
    await pumpFor(tester, 300);
    expect(events, ['surge']);

    // Past touchdown: settled exactly once.
    await pumpFor(tester, 2000);
    expect(events, ['surge', 'settled']);

    // Particles drain; the overlay reports itself finished.
    await pumpFor(tester, 1500);
    expect(events, ['surge', 'settled', 'finished']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tap before the surge skips silently to the settled state', (
    tester,
  ) async {
    final events = <String>[];
    final seatKey = GlobalKey();
    await tester.pumpWidget(host(seatKey: seatKey, onEvent: events.add));

    await pumpFor(tester, 200);
    await tester.tap(find.byKey(const ValueKey('ceremony_skip')));
    await tester.pump();

    // The pending surge is marked fired WITHOUT firing (no shake after the
    // user opted out); the touchdown beat still lands, exactly once.
    expect(events, ['settled']);

    // A second tap does nothing (idempotent), and the overlay drains.
    await tester.tap(
      find.byKey(const ValueKey('ceremony_skip')),
      warnIfMissed: false,
    );
    await pumpFor(tester, 1200);
    expect(events, ['settled', 'finished']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tap mid-flight keeps the already-fired surge single', (
    tester,
  ) async {
    final events = <String>[];
    final seatKey = GlobalKey();
    await tester.pumpWidget(host(seatKey: seatKey, onEvent: events.add));

    await pumpFor(tester, 1300); // surge + liftoff both fired
    expect(events, ['surge']);

    await tester.tap(find.byKey(const ValueKey('ceremony_skip')));
    await tester.pump();
    expect(events, ['surge', 'settled']);

    await pumpFor(tester, 1200);
    expect(events, ['surge', 'settled', 'finished']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing seat: liftoff falls back to a clean settle', (
    tester,
  ) async {
    final events = <String>[];
    final seatKey = GlobalKey();
    await tester.pumpWidget(
      host(seatKey: seatKey, onEvent: events.add, withSeat: false),
    );

    // Reaches liftoff (1050ms); the target cannot be measured, so the
    // ceremony settles instead of flying to a guessed coordinate.
    await pumpFor(tester, 1100);
    expect(events, ['surge', 'settled']);

    await pumpFor(tester, 1200);
    expect(events, ['surge', 'settled', 'finished']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion (built anyway): settles immediately', (
    tester,
  ) async {
    final events = <String>[];
    final seatKey = GlobalKey();
    await tester.pumpWidget(
      host(seatKey: seatKey, onEvent: events.add, reducedMotion: true),
    );

    await tester.pump(); // the post-frame guard
    expect(events, ['settled']);
    expect(events.where((e) => e == 'surge'), isEmpty);

    await pumpFor(tester, 1200);
    expect(events, ['settled', 'finished']);

    await tester.pumpWidget(const SizedBox());
  });
}
