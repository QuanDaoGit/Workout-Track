import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/pages/onboarding/charge_ritual_engine.dart';

void main() {
  // Advance the engine by [ms] in small [step]-ms ticks, like a real Ticker.
  void run(ChargeRitualEngine e, double ms, {double step = 16}) {
    var t = 0.0;
    while (t < ms) {
      final dt = (ms - t) < step ? (ms - t) : step;
      e.tick(dt);
      t += dt;
    }
  }

  test('starts in preroll with charge held at 0', () {
    final e = ChargeRitualEngine(reelMs: 1000);
    expect(e.phase, ChargeRitualPhase.preroll);
    expect(e.charge, 0);
    run(e, 400); // entry cinematic playing — no fill yet
    expect(e.phase, ChargeRitualPhase.preroll);
    expect(e.charge, 0);
  });

  test('beginReel starts the reel fill (0 -> 0.9 then gates at hold)', () {
    final e = ChargeRitualEngine(reelMs: 1000);
    e.beginReel();
    expect(e.phase, ChargeRitualPhase.reel);
    run(e, 500);
    expect(e.charge, closeTo(0.45, 0.05));
    expect(e.phase, ChargeRitualPhase.reel);
    run(e, 600); // past reelMs
    expect(e.charge, closeTo(0.9, 1e-6));
    expect(e.phase, ChargeRitualPhase.hold);
  });

  test('preroll watchdog force-starts the reel after the cap (no soft-lock)', () {
    final e = ChargeRitualEngine(reelMs: 5000, prerollMs: 500);
    run(e, 400); // below cap — still waiting for the entry
    expect(e.phase, ChargeRitualPhase.preroll);
    run(e, 300); // now past the 500ms cap without any beginReel() call
    expect(e.phase, ChargeRitualPhase.reel);
    expect(e.charge, greaterThan(0)); // reel is now filling
  });

  test('beginReel is idempotent (only advances out of preroll)', () {
    final e = ChargeRitualEngine(reelMs: 100, fillMs: 500);
    e.beginReel();
    run(e, 150); // reach the hold gate
    expect(e.phase, ChargeRitualPhase.hold);
    e.beginReel(); // late/duplicate — must NOT reset back to reel
    expect(e.phase, ChargeRitualPhase.hold);
    expect(e.charge, closeTo(0.9, 1e-6));
  });

  test('hold + pour fills 0.9 -> 1.0 and ignites', () {
    final e = ChargeRitualEngine(reelMs: 100, fillMs: 500);
    e.beginReel();
    run(e, 150); // reach the hold gate
    expect(e.phase, ChargeRitualPhase.hold);
    e.startHold();
    run(e, 600); // > fillMs
    expect(e.charge, closeTo(1.0, 1e-6));
    expect(e.phase, ChargeRitualPhase.ignited);
    expect(e.isIgnited, isTrue);
  });

  test('release mid-pour drains toward 0.9, never below, returns to hold', () {
    final e = ChargeRitualEngine(reelMs: 100, fillMs: 500, drainMs: 500);
    e.beginReel();
    run(e, 150);
    e.startHold();
    run(e, 250); // partway up
    expect(e.phase, ChargeRitualPhase.pouring);
    expect(e.charge, greaterThan(0.9));
    e.endHold();
    run(e, 1000); // drain fully
    expect(e.charge, closeTo(0.9, 1e-6));
    expect(e.charge, greaterThanOrEqualTo(0.9));
    expect(e.phase, ChargeRitualPhase.hold);
  });

  test('pause freezes the fill; resume continues', () {
    final e = ChargeRitualEngine(reelMs: 2000);
    e.beginReel();
    run(e, 400);
    final frozen = e.charge;
    expect(frozen, greaterThan(0));
    e.pause();
    expect(e.isPaused, isTrue);
    run(e, 1000); // time passes while paused — no fill
    expect(e.charge, frozen);
    e.resume();
    run(e, 400);
    expect(e.charge, greaterThan(frozen)); // filling again
  });

  test('finishReel from preroll skips straight to hold (reduced-motion / fail)', () {
    final e = ChargeRitualEngine();
    expect(e.phase, ChargeRitualPhase.preroll);
    e.finishReel();
    expect(e.charge, closeTo(0.9, 1e-6));
    expect(e.phase, ChargeRitualPhase.hold);
  });

  test('finishReel during reel snaps to hold (no soft-lock)', () {
    final e = ChargeRitualEngine(reelMs: 15000);
    e.beginReel();
    run(e, 2000); // only partway
    expect(e.phase, ChargeRitualPhase.reel);
    e.finishReel(); // video ended / errored
    expect(e.charge, closeTo(0.9, 1e-6));
    expect(e.phase, ChargeRitualPhase.hold);
  });

  test('tapComplete auto-pours to ignite without holding', () {
    final e = ChargeRitualEngine(reelMs: 100, autoFillMs: 1000);
    e.beginReel();
    run(e, 150);
    expect(e.phase, ChargeRitualPhase.hold);
    e.tapComplete();
    run(e, 1100); // > autoFillMs
    expect(e.phase, ChargeRitualPhase.ignited);
  });

  test('cannot tap-complete before the gate', () {
    final e = ChargeRitualEngine(reelMs: 1000);
    e.beginReel();
    e.tapComplete(); // ignored — gate not open
    run(e, 100);
    expect(e.phase, ChargeRitualPhase.reel);
    expect(e.charge, lessThan(0.9));
  });

  test('dt is clamped so a long stalled frame cannot skip states', () {
    final e = ChargeRitualEngine(reelMs: 1000);
    e.beginReel();
    e.tick(100000); // huge dt (backgrounded)
    expect(e.phase, ChargeRitualPhase.reel);
    expect(e.charge, lessThan(0.2));
  });

  test('ignited is terminal', () {
    final e = ChargeRitualEngine(reelMs: 50, fillMs: 100);
    e.beginReel();
    run(e, 100);
    e.startHold();
    run(e, 200);
    expect(e.isIgnited, isTrue);
    final c = e.charge;
    run(e, 1000);
    expect(e.charge, c); // frozen
    expect(e.phase, ChargeRitualPhase.ignited);
  });
}
