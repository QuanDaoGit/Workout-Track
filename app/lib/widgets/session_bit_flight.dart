import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'companion/bit_mood_core.dart';

/// Which rest-end event launched the flight — the profiles differ only in the
/// lift-off beat: a natural expiry earns the full 90ms anticipation inhale,
/// while a SKIP (an explicit hurry-up tap) compresses it to a single frame so
/// the tap never reads as input lag (Codex).
enum FlightProfile { natural, skip }

/// The rest-end BIT flight: an [IgnorePointer] overlay that carries the rest
/// panel's BIT to the just-finished exercise card (the corner "seal" — the one
/// moment the card's StrobeFlash celebration fires) and then hops it into the
/// frontier card's riding slot. Spec:
/// docs/superpowers/specs/2026-07-21-rest-end-bit-flight-design.md
///
/// Contracts (all Codex-hardened):
/// - Purely additive: the wrapped [child] (the settled, interactive hub) is
///   never touched; the overlay ignores pointers and is excluded from
///   semantics. Input never waits.
/// - [begin] ACCEPTS only when the finished card resolves to an on-viewport
///   rect — it returns false otherwise so the host can route the celebration
///   through its fallback consumer instead (the seal is never silently lost).
/// - A generation token guards every delayed callback: [settleNow], a new
///   [begin], or dispose invalidates in-flight callbacks so a settled flight
///   can never stamp stale state or resurrect (Codex F3).
/// - [onStamp] fires exactly once per accepted flight, at the seal beat.
///   [onDone] fires exactly once, on landing OR settle.
class SessionBitFlight extends StatefulWidget {
  const SessionBitFlight({
    super.key,
    required this.child,
    required this.onStamp,
    required this.onDone,
  });

  final Widget child;

  /// The single celebration moment — the host bumps the finished card's
  /// StrobeFlash trigger here (and only here, for flight paths).
  final VoidCallback onStamp;

  /// Landing or settle — the host restores the in-card frontier BIT.
  final VoidCallback onDone;

  @override
  State<SessionBitFlight> createState() => SessionBitFlightState();
}

class SessionBitFlightState extends State<SessionBitFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _gen = 0; // generation token — bumped by settleNow/begin/dispose
  bool _active = false;
  bool _stamped = false;
  bool _doneNotified = false;

  Offset _origin = Offset.zero; // local coords
  Offset _seal = Offset.zero; // finished card's corner point, local
  GlobalKey? _slotKey; // frontier slot — re-resolved at hop entry
  Offset? _slot; // resolved at hop entry; null → fade-out ending

  // Phosphor afterimages: (controller t, center, size) samples from the flight
  // leg; two delayed ghosts render at ~40/80ms behind the live sprite.
  final List<(double, Offset, double)> _trail = [];

  // Beat boundaries as fractions of the total duration.
  late double _b0, _b1, _b2;
  late int _totalMs;

  bool get active => _active;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish(_gen);
    });
  }

  @override
  void dispose() {
    _gen++;
    _c.dispose();
    super.dispose();
  }

  Rect? _localRectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final self = context.findRenderObject() as RenderBox?;
    if (box == null ||
        self == null ||
        !box.attached ||
        !self.attached ||
        !box.hasSize ||
        !self.hasSize) {
      return null;
    }
    final topLeft = self.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  bool _onViewport(Offset p) {
    final self = context.findRenderObject() as RenderBox?;
    if (self == null || !self.hasSize) return false;
    return (Offset.zero & self.size).inflate(40).contains(p);
  }

  /// Starts the flight. Returns false (and stays inert) when the finished
  /// card can't provide a valid on-viewport seal target — the host keeps the
  /// celebration pending and its return-consumer fires the fallback strobe.
  bool begin({
    required Rect originGlobal,
    required GlobalKey finishedCardKey,
    required GlobalKey frontierSlotKey,
    required FlightProfile profile,
  }) {
    final cardRect = _localRectFor(finishedCardKey);
    if (cardRect == null) return false;
    final seal = Offset(cardRect.right - 16, cardRect.top + 2);
    if (!_onViewport(seal)) return false;
    final self = context.findRenderObject() as RenderBox?;
    if (self == null) return false;

    _gen++;
    _active = true;
    _stamped = false;
    _doneNotified = false;
    _origin = self.globalToLocal(originGlobal.center);
    _seal = seal;
    _slotKey = frontierSlotKey;
    _slot = null;
    _trail.clear();

    _totalMs = profile == FlightProfile.natural ? 770 : 690;
    final b0Ms = profile == FlightProfile.natural ? 90.0 : 16.0;
    _b0 = b0Ms / _totalMs;
    _b1 = (b0Ms + 380) / _totalMs;
    _b2 = (b0Ms + 380 + 120) / _totalMs;

    _c.duration = Duration(milliseconds: _totalMs);
    _c.forward(from: 0);
    setState(() {});
    return true;
  }

  /// Instantly resolves the overlay to the settled state. Idempotent; safe to
  /// call at any time (navigation, dialogs, lifecycle pause, dispose paths).
  void settleNow() {
    if (!_active) return;
    _gen++;
    _c.stop();
    _active = false;
    _finishNotify();
    setState(() {});
  }

  void _finish(int gen) {
    if (gen != _gen || !mounted || !_active) return;
    _active = false;
    _finishNotify();
    setState(() {});
  }

  void _finishNotify() {
    if (_doneNotified) return;
    _doneNotified = true;
    widget.onDone();
  }

  // The flight leg's path parameter: asymmetric ease — a cubic push-off over
  // the first 35% of the leg covering 45% of the path, then a cubic glide.
  double _pathS(double u) {
    if (u < 0.35) {
      return Curves.easeInCubic.transform(u / 0.35) * 0.45;
    }
    return 0.45 + Curves.easeOutCubic.transform((u - 0.35) / 0.65) * 0.55;
  }

  Offset _bezier(Offset a, Offset ctrl, Offset b, double s) {
    final inv = 1 - s;
    return a * (inv * inv) + ctrl * (2 * inv * s) + b * (s * s);
  }

  // Current sprite center + size + phase flags for controller value [t].
  (Offset, double, bool inFlightLeg, bool inSeal, double anticipation) _frame(
    double t,
    Size overlay,
  ) {
    if (t <= _b0) {
      // Lift-off inhale: sink 2px, anticipation ramps (skip: near-instant).
      final a = (t / _b0).clamp(0.0, 1.0);
      return (_origin + Offset(0, 2 * a), 96, false, false, a);
    }
    if (t <= _b1) {
      final u = ((t - _b0) / (_b1 - _b0)).clamp(0.0, 1.0);
      final s = _pathS(u);
      final mid = Offset.lerp(_origin, _seal, 0.5)!;
      final bow = (overlay.width - mid.dx - 28).clamp(0.0, 24.0);
      final pos = _bezier(_origin, mid + Offset(bow, 0), _seal, s);
      return (pos, lerpDouble(96, 40, s)!, true, false, 1 - u);
    }
    if (t <= _b2) {
      // The corner seal: a 2px overshoot-settle of BIT only.
      final v = ((t - _b1) / (_b2 - _b1)).clamp(0.0, 1.0);
      return (_seal + Offset(0, 2 * math.sin(math.pi * v)), 40, false, true, 0);
    }
    // Frontier hop (or fade-out when the slot is unresolvable).
    final w = Curves.easeOut.transform(
      ((t - _b2) / (1 - _b2)).clamp(0.0, 1.0),
    );
    if (_slot == null && _slotKey != null) {
      final r = _localRectFor(_slotKey!);
      if (r != null && _onViewport(r.center)) _slot = r.center;
      _slotKey = null; // resolve once at hop entry
    }
    final target = _slot;
    if (target == null) {
      return (_seal, 40, false, false, 0); // fade-out ending (opacity below)
    }
    final pos =
        Offset.lerp(_seal, target, w)! + Offset(0, -8 * math.sin(math.pi * w));
    return (pos, lerpDouble(40, 44, w)!, false, false, 0);
  }

  Widget _bit(double size, bool inSeal, double anticipation, BitPose pose) {
    return SizedBox(
      width: size,
      height: size,
      child: BitMoodCore(
        pose: pose,
        reveal: 1,
        size: size,
        freezeBob: true,
        blink: inSeal,
        anticipation: anticipation.clamp(0.0, 1.0),
        idleAmp: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_active)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) => AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final overlay = constraints.biggest;
                    final t = _c.value;
                    final (pos, size, inFlight, inSeal, anticipation) = _frame(
                      t,
                      overlay,
                    );
                    // Stamp exactly once, on CROSSING the seal threshold —
                    // never window-presence (a dropped/jumped frame past the
                    // 120ms seal window must still fire the celebration).
                    if (t > _b1 && !_stamped) {
                      _stamped = true;
                      final g = _gen; // a settle/new begin invalidates this
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _active && g == _gen) widget.onStamp();
                      });
                    }
                    if (inFlight) {
                      _trail.add((t, pos, size));
                      while (_trail.length > 12) {
                        _trail.removeAt(0);
                      }
                    }
                    // The rest pose holds through lift-off; the 900ms pose
                    // morph then eases the wake over the whole flight.
                    final pose = t <= _b0 ? BitPose.rest : BitPose.neutral;
                    // Fade-out ending when the frontier slot was unresolvable.
                    final fading = t > _b2 && _slot == null && _slotKey == null;
                    final alpha = fading
                        ? (1 - ((t - _b2) / (1 - _b2))).clamp(0.0, 1.0)
                        : 1.0;
                    Widget ghost(double delayMs, double a) {
                      final at = t - delayMs / _totalMs;
                      for (var i = _trail.length - 1; i >= 0; i--) {
                        if (_trail[i].$1 <= at) {
                          final (_, gp, gs) = _trail[i];
                          return Positioned(
                            left: gp.dx - gs / 2,
                            top: gp.dy - gs / 2,
                            child: Opacity(
                              opacity: a,
                              child: _bit(gs, false, 0, pose),
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    }

                    return Stack(
                      children: [
                        // Phosphor afterimages — the CRT decay trail, flight
                        // leg only.
                        if (inFlight) ghost(80, 0.10),
                        if (inFlight) ghost(40, 0.22),
                        Positioned(
                          left: pos.dx - size / 2,
                          top: pos.dy - size / 2,
                          child: Opacity(
                            opacity: alpha,
                            child: KeyedSubtree(
                              key: const ValueKey('flight_bit'),
                              child: _bit(size, inSeal, anticipation, pose),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
