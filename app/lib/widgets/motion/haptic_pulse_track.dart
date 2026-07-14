import 'package:flutter/animation.dart';

import '../../services/haptic_service.dart';

/// Couples a short **pulse-train** of one-shot haptics to an [Animation] so the
/// felt rhythm tracks the seen motion exactly — the evidence-backed way to fake
/// "continuous" haptics on Flutter's built-in (one-shot-only) `HapticFeedback`.
///
/// Why not a `Timer.periodic`? A free timer drifts against the animation and the
/// user feels the drift (and a service-owned timer leaks as a flutter_test
/// pending timer). Instead this rides the controller's own ticker: it fires
/// [intent] at each evenly-spaced interior threshold `(i+1)/(pulses+1)`, then an
/// optional [finalIntent] once when the animation **completes** — so the train
/// starts, stays in sync, and dies with the animation.
///
/// Lifecycle is hardened (per the Codex review of the haptics design):
/// - **forward-only** — a decreasing value (reverse / `repeat()` reset) never
///   fires and never rewinds the cursor, so a repeating controller can't
///   machine-gun;
/// - **skipped frames** still fire every threshold they jumped (a `while` loop,
///   not an `if`);
/// - **completion** flushes any unfired ticks + the [finalIntent] exactly once,
///   so a frame that skips the last threshold can't swallow the payoff;
/// - **idempotent + disposable** — one listener pair per controller, removed in
///   [dispose]; calls after dispose are inert.
///
/// Reduced motion is the *owner's* call, not this helper's: when the animation
/// is frozen/removed, don't attach a train — fire a single representative pulse
/// only if it's tied to an explicit user action or a visible state change, and
/// suppress purely-ambient trains entirely.
class HapticPulseTrack {
  HapticPulseTrack({
    required this.animation,
    required this.pulses,
    this.intent = HapticIntent.selection,
    this.finalIntent,
    HapticService? service,
  })  : assert(pulses >= 0),
        _service = service ?? HapticService.instance {
    animation.addListener(_onTick);
    animation.addStatusListener(_onStatus);
  }

  final Animation<double> animation;

  /// Number of subtle interior ticks across the run (placed at `(i+1)/(pulses+1)`).
  final int pulses;

  /// The intent for each interior tick (the subtle workhorse — `selection`).
  final HapticIntent intent;

  /// Optional terminal payoff fired once on completion (e.g. `reward` at settle).
  final HapticIntent? finalIntent;

  final HapticService _service;

  int _fired = 0;
  double _last = 0;
  bool _finalFired = false;
  bool _disposed = false;

  void _onTick() {
    if (_disposed) return;
    final v = animation.value;
    // Forward-only: ignore reverse / repeat-reset, never rewind the cursor.
    if (v < _last) {
      _last = v;
      return;
    }
    _last = v;
    while (_fired < pulses && v >= (_fired + 1) / (pulses + 1)) {
      _fired++;
      _service.fire(intent);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (_disposed || status != AnimationStatus.completed) return;
    // Flush any threshold a stuttered frame skipped, then the terminal payoff.
    while (_fired < pulses) {
      _fired++;
      _service.fire(intent);
    }
    if (!_finalFired && finalIntent != null) {
      _finalFired = true;
      _service.fire(finalIntent!);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    animation.removeListener(_onTick);
    animation.removeStatusListener(_onStatus);
  }
}
