import 'dart:math' as math;

/// The Charge Ritual's phases. `preroll` is the cinematic entry (screen power-on
/// → held frame → ease-in) during which the charge is held at 0; `beginReel()`
/// (or the watchdog) starts the fill. Then reel → hold → pouring ⇄ hold → ignited.
enum ChargeRitualPhase { preroll, reel, hold, pouring, ignited }

/// Pure, deterministic charge state machine for the Charge Ritual onboarding
/// screen — ported from `assets/design_handoff_charge_ritual`, hardened against
/// soft-locks. The widget advances it each frame with [tick] (dt in ms) off a
/// `Ticker`; all timing is injected so it runs with **no real timers** in tests.
///
/// **Soft-lock fixes:** the reel fill is driven by this INDEPENDENT clock, never
/// by video position. Two watchdogs guarantee progress: (1) [finishReel]
/// (video-end / video-error) advances the entry or reel to the hold gate; (2) a
/// clock-driven **preroll watchdog** ([prerollMs]) force-starts the reel if the
/// entry cinematic never calls [beginReel] (interrupted / backgrounded / stalled).
class ChargeRitualEngine {
  ChargeRitualEngine({
    this.reelMs = 15000,
    this.fillMs = 1400,
    this.drainMs = 2600,
    this.autoFillMs = 1000,
    this.prerollMs = 2000,
  });

  /// Reel auto-charge duration (0 → 0.9). Set from the real video duration when
  /// known. Reduced motion skips the reel entirely (straight to hold).
  double reelMs;

  /// Held-pour duration for the final 0.9 → 1.0 (evidence-trimmed).
  final double fillMs;

  /// Release-drain duration back toward 0.9 (forgiving; never below).
  final double drainMs;

  /// The accessible tap path: BIT auto-pours 0.9 → 1.0 over this long.
  final double autoFillMs;

  /// Preroll watchdog cap — the longest the entry cinematic may run before the
  /// reel is force-started, so an interrupted/stalled entry can't soft-lock.
  final double prerollMs;

  /// Clamp a single frame's dt so a backgrounded/janky frame can't skip states.
  static const double _maxDtMs = 64;
  static const double _holdThreshold = 0.9;

  ChargeRitualPhase _phase = ChargeRitualPhase.preroll;
  double _charge = 0;
  double _prerollElapsed = 0;
  bool _holding = false;
  bool _autoFilling = false;
  bool _paused = false;

  ChargeRitualPhase get phase => _phase;
  double get charge => _charge;
  bool get isIgnited => _phase == ChargeRitualPhase.ignited;
  bool get isPaused => _paused;

  /// Advance the clock by [dtMs] (clamped to [_maxDtMs]). A no-op while paused
  /// (tap-to-pause) or ignited (terminal).
  void tick(double dtMs) {
    if (_phase == ChargeRitualPhase.ignited || _paused) return;
    final dt = math.min(_maxDtMs, math.max(0.0, dtMs));
    switch (_phase) {
      case ChargeRitualPhase.preroll:
        // Clock-driven watchdog: if the entry cinematic hasn't called beginReel()
        // within the cap (interrupt / background / stall), start the reel anyway.
        _prerollElapsed += dt;
        if (_prerollElapsed >= prerollMs) beginReel();
      case ChargeRitualPhase.reel:
        _charge = math.min(_holdThreshold, _charge + (dt / reelMs) * 0.9);
        if (_charge >= _holdThreshold) _phase = ChargeRitualPhase.hold;
      case ChargeRitualPhase.hold:
      case ChargeRitualPhase.pouring:
        if (_holding || _autoFilling) {
          _phase = ChargeRitualPhase.pouring;
          final rate = _autoFilling ? autoFillMs : fillMs;
          _charge = math.min(1.0, _charge + (dt / rate) * 0.1);
          if (_charge >= 1.0) {
            _phase = ChargeRitualPhase.ignited;
            _holding = false;
            _autoFilling = false;
          }
        } else if (_phase == ChargeRitualPhase.pouring) {
          _charge = math.max(_holdThreshold, _charge - (dt / drainMs) * 0.1);
          if (_charge <= _holdThreshold) _phase = ChargeRitualPhase.hold;
        }
      case ChargeRitualPhase.ignited:
        break;
    }
  }

  /// The entry cinematic finished (Beat C started playback) — start the reel
  /// fill. **Idempotent**: only advances out of preroll, so a late watchdog +
  /// a real beginReel can't double-fire or reset the reel.
  void beginReel() {
    if (_phase == ChargeRitualPhase.preroll) _phase = ChargeRitualPhase.reel;
  }

  /// Pointer down on the keycap — begin pouring (only once the gate is reached).
  void startHold() {
    if (_phase == ChargeRitualPhase.hold ||
        _phase == ChargeRitualPhase.pouring) {
      _holding = true;
    }
  }

  /// Pointer up / cancel — stop pouring (charge will drain back to 0.9).
  void endHold() => _holding = false;

  /// The always-available accessible path: a single tap → BIT auto-pours to
  /// 100%. Ignored before the gate is open.
  void tapComplete() {
    if (_phase == ChargeRitualPhase.hold ||
        _phase == ChargeRitualPhase.pouring) {
      _autoFilling = true;
    }
  }

  /// Tap-to-pause: freeze/resume the whole reel moment. The screen pauses the
  /// video + the delayed-skip timer in lockstep so nothing desyncs.
  void pause() => _paused = true;
  void resume() => _paused = false;

  /// Video-end / video-error / preroll-or-reel watchdog: advance to the hold gate
  /// from the entry OR the reel so a degraded reel can never soft-lock. Reduced
  /// motion also uses this to skip straight to the hold state.
  void finishReel() {
    if (_phase == ChargeRitualPhase.preroll ||
        _phase == ChargeRitualPhase.reel) {
      _charge = _holdThreshold;
      _phase = ChargeRitualPhase.hold;
    }
  }
}
