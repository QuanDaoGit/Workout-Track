import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// Quest-claim "reward homecoming" — the port of the `Quest Claim Flow` handoff
/// (`assets/quests/design_handoff_quest_claim`). On CLAIM, gems arc from the
/// tapped button up to the pinned [GemWallet], which counts up as they land.
///
/// Faithful values are pinned to the handoff's runnable source (`fly`/`spawn`/
/// `loop`/`pulseWallet`); the per-gem DOM imgs + rAF loop are adapted to one
/// [Ticker] driving positioned [Image]s, and `getBoundingClientRect` to
/// `RenderBox.localToGlobal`. The currency is the app's real magenta gem
/// (`kGemMagenta` / `icon_gem.png`), not the handoff's bundled `gem.png`.

const String _kGemAsset = 'assets/icons/economy/icon_gem.png';

/// Flight easing — `cubic-bezier(.45,0,.4,1)`: slow-in to a mid-flight hang,
/// then accelerate into the wallet.
const Cubic _kFlightEase = Cubic(0.45, 0, 0.4, 1);

/// A reward is "big" (side-quest scale) at or above this — denser/longer stream,
/// stronger pulse, longer BIT hold.
const int kBigRewardThreshold = 50;

/// The gem sprite with a painted magenta-diamond fallback (asset-dependent
/// surfaces need a per-image errorBuilder; also keeps goldens deterministic).
Widget _gemImage(double size) => Image.asset(
      _kGemAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => _GemFallback(size: size),
    );

class _GemFallback extends StatelessWidget {
  const _GemFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: size * 0.66,
          height: size * 0.66,
          decoration: const BoxDecoration(color: kGemMagenta),
        ),
      ),
    );
  }
}

/// The pinned gem wallet — the flight destination and the count-up readout. The
/// number rises as gems land (not on tap), pulses magenta on each arrival, and
/// floats a single "+N" reveal per claim. Drive it imperatively via a
/// `GlobalKey<GemWalletState>`: [setInitial], [land], [showDelta].
class GemWallet extends StatefulWidget {
  const GemWallet({super.key, this.showDeltaFloat = true});

  /// The opt-out for the post-claim "+N" reveal (kept legible/quiet; a single
  /// toggle so it can be killed if it reads saccharine on device).
  final bool showDeltaFloat;

  @override
  State<GemWallet> createState() => GemWalletState();
}

class GemWalletState extends State<GemWallet>
    with TickerProviderStateMixin {
  double _display = 0;
  int _target = 0;
  Ticker? _countTicker;

  // Built in initState (not lazily): under reduced motion / a never-landed
  // wallet the build path may never touch them, so a `late final = …`
  // initializer would otherwise fire during dispose() → an unsafe ancestor
  // lookup (the createTicker-in-dispose trap).
  late final AnimationController _pulse;
  double _pulsePeak = 1.20; // 1.30 for big payouts

  // The "+N" reveal — a transient magenta float above the pill.
  int _delta = 0;
  late final AnimationController _deltaCtl;

  bool get _reduce => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _deltaCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Drop the "+N" from the tree once it has faded (keep it transient).
    _deltaCtl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _delta = 0);
      }
    });
  }

  /// Seed the displayed balance with no animation (initial load / settle).
  void setInitial(int value) {
    _countTicker?.stop();
    _target = value;
    _display = value.toDouble();
    if (mounted) setState(() {});
  }

  /// A gem (worth [amt]) has landed: raise the target and ease toward it; pulse
  /// + (under motion) animate. [snap] jumps the counter (reduced motion).
  void land(int amt, {bool snap = false, bool big = false}) {
    _target += amt;
    _pulsePeak = big ? 1.30 : 1.20;
    _pulse.duration = Duration(milliseconds: big ? 360 : 300);
    if (snap || _reduce) {
      _display = _target.toDouble();
      if (mounted) setState(() {});
      return;
    }
    if (!_pulse.isAnimating) _pulse.forward(from: 0);
    _countTicker ??= createTicker(_step)..start();
    if (!_countTicker!.isActive) _countTicker!.start();
  }

  /// The single per-claim "+N" reveal (decision: a modest, fading magenta float;
  /// off under reduced motion / when disabled).
  void showDelta(int n) {
    if (!widget.showDeltaFloat || _reduce || n <= 0) return;
    setState(() => _delta = n);
    _deltaCtl.forward(from: 0);
  }

  // Eased approach mirroring the handoff `loop()`: display += d*0.16 ± 0.6/frame.
  void _step(Duration _) {
    final d = _target - _display;
    if (d.abs() < 0.5) {
      _display = _target.toDouble();
      _countTicker?.stop();
      if (mounted) setState(() {});
      return;
    }
    _display += d * 0.16 + (d > 0 ? 0.6 : -0.6);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countTicker?.dispose();
    _pulse.dispose();
    _deltaCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _display.round();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The "+N" reveal, floating above the pill.
        if (_delta > 0)
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _deltaCtl,
                builder: (context, child) {
                  final t = _deltaCtl.value;
                  final fade = t < 0.2 ? t / 0.2 : (1 - (t - 0.2) / 0.8);
                  return Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -22 * t),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '+$_delta',
                  style: AppFonts.shareTechMono(
                    color: kGemMagenta,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final p = math.sin(math.pi * _pulse.value);
            return Transform.scale(
              scale: 1 + (_pulsePeak - 1) * p,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kCardRadius),
                  boxShadow: p > 0
                      ? [
                          BoxShadow(
                            color: kGemMagenta.withValues(alpha: 0.30 * p),
                            blurRadius: 16 * p,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(kCardRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _gemImage(16),
                const SizedBox(width: 7),
                Semantics(
                  liveRegion: true,
                  label: 'gem balance $value',
                  child: Text(
                    '$value',
                    style: AppFonts.shareTechMono(
                      color: kGemMagenta,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single in-flight gem.
class _Gem {
  _Gem({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.startMs,
    required this.durMs,
    required this.spinDeg,
    required this.size,
    required this.amt,
    required this.isLast,
  });

  final Offset p0, p1, p2;
  final double startMs, durMs, spinDeg, size;
  final int amt;
  final bool isLast;
}

/// The full-screen flight overlay. Drop it as a `Positioned.fill` sibling above
/// the page content; call [fly] (via a `GlobalKey<GemFlightLayerState>`) on each
/// claim. It paints nothing while idle. Reduced motion is handled by the caller
/// (it snaps the wallet directly and never calls [fly]).
class GemFlightLayer extends StatefulWidget {
  const GemFlightLayer({super.key, required this.onLand});

  /// Fired per gem arrival: its [amt], whether it is the last of the burst, and
  /// whether the claim was a big payout.
  final void Function(int amt, bool isLast, bool big) onLand;

  @override
  State<GemFlightLayer> createState() => GemFlightLayerState();
}

class GemFlightLayerState extends State<GemFlightLayer>
    with SingleTickerProviderStateMixin {
  final List<_Gem> _gems = [];
  // Built in initState, never lazily — a lazy `createTicker` would fire during
  // dispose() (if no gem ever flew) and do an unsafe ancestor lookup.
  late final Ticker _ticker;
  double _nowMs = 0;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  /// Launch a burst for [reward] gems from [originGlobal] (the CLAIM button) to
  /// [walletGlobal] (the wallet pill). Rects are global; converted to this
  /// layer's local space. Honesty: at most 8 particles — the counter conveys the
  /// real amount.
  void fly({
    required Rect originGlobal,
    required Rect walletGlobal,
    required int reward,
    required bool big,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || reward <= 0) return;
    final s = box.globalToLocal(originGlobal.center);
    final e = box.globalToLocal(walletGlobal.center);

    final n = reward <= 8 ? reward : 8;
    final per = reward ~/ n;
    final rem = reward - per * n;
    final stagger = big ? 46.0 : 58.0;
    final midRaise = 26 + _rng.nextDouble() * 8;
    final size = big ? 22.0 : 18.0;

    // The ticker's elapsed restarts at 0 each time it (re)starts, so a fresh
    // burst is timed from 0; a burst added while gems are still flying rides the
    // current monotonic `_nowMs` (rapid claims pool onto one running clock).
    final base = _ticker.isActive ? _nowMs : 0.0;

    for (var i = 0; i < n; i++) {
      final amt = per + (i >= n - rem ? 1 : 0);
      final jx = (i - n / 2) * 7;
      final p0 = Offset(s.dx + jx, s.dy);
      final p1 = Offset((s.dx + e.dx) / 2 + jx * 0.4, math.min(s.dy, e.dy) - midRaise);
      final dur = (big ? 760.0 : 670.0) + _rng.nextDouble() * 90;
      final spin = (i.isOdd ? 1 : -1) * (260 + _rng.nextDouble() * 160);
      _gems.add(_Gem(
        p0: p0, p1: p1, p2: e,
        startMs: base + i * stagger,
        durMs: dur,
        spinDeg: spin.toDouble(),
        size: size,
        amt: amt,
        isLast: i == n - 1,
      ));
    }
    if (!_ticker.isActive) {
      _nowMs = 0;
      _ticker.start();
    }
    setState(() {});
  }

  void _tick(Duration elapsed) {
    _nowMs = elapsed.inMicroseconds / 1000.0;
    final landed = <_Gem>[];
    for (final g in _gems) {
      if (_nowMs - g.startMs >= g.durMs) landed.add(g);
    }
    for (final g in landed) {
      _gems.remove(g);
      final big = g.size >= 22;
      widget.onLand(g.amt, g.isLast, big);
    }
    if (_gems.isEmpty) {
      _ticker.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final g in _gems) _paintGem(g),
        ],
      ),
    );
  }

  Widget _paintGem(_Gem g) {
    final lin = ((_nowMs - g.startMs) / g.durMs).clamp(0.0, 1.0);
    if (lin <= 0) return const SizedBox.shrink();
    final t = _kFlightEase.transform(lin);
    final it = 1 - t;
    final x = it * it * g.p0.dx + 2 * it * t * g.p1.dx + t * t * g.p2.dx;
    final y = it * it * g.p0.dy + 2 * it * t * g.p1.dy + t * t * g.p2.dy;
    final sc = 1 - 0.42 * t;
    return Positioned(
      left: x - g.size / 2,
      top: y - g.size / 2,
      child: Transform.rotate(
        angle: g.spinDeg * t * math.pi / 180,
        child: Transform.scale(
          scale: sc,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: kGemMagenta.withValues(alpha: 0.6),
                  blurRadius: 5,
                ),
              ],
            ),
            child: _gemImage(g.size),
          ),
        ),
      ),
    );
  }
}
