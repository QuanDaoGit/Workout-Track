import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/feature_gate_service.dart';
import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../theme/tokens.dart';
import 'companion/bit_core_engine.dart' show bitGlow;
import 'companion/bit_mood_core.dart';
import 'companion/bit_speech_bubble.dart';
import 'pixel_button.dart';

/// The **feature unlock ceremony** — the standardized "NEW SYSTEM ONLINE"
/// takeover the shell plays when an earned meta feature (Quests, Shop, Guild,
/// Items, Expeditions) comes online. Session-ceremony grade: one clock drives
/// every beat, each side effect is threshold-gated and fired once so
/// **tap-to-skip is idempotent**.
///
/// Beat map (single gate, ms):
///   0–150   scrim + ambient dust fade in · ceremony tick
///   90–500  cyan arrival brackets frame the dark icon slot; a dim silhouette
///           of the icon flickers (CRT pre-power) — the anticipation coil
///   500     surge: chime + success haptic + a 12-spark amber ring; the
///           scanline wipe starts revealing the icon
///   620     "NEW SYSTEM ONLINE" kicker phosphor-blinks in (cyan)
///   780     the feature title slams (instant + one amber strobe frame)
///   900     BIT (faced, cheer) floats in with its line
///   1600    actions power on — settled; GO / LATER are live
///
/// Multiple gates coalesce into ONE catch-up card (staggered icon reveals,
/// stacked titles, a single CONTINUE) — a return after a long session never
/// plays a backlog of takeovers (Codex F6).
///
/// Reduced motion / accessible navigation: the settled card renders
/// immediately — still, legible, buttons live, announced via a live region.
///
/// Presentation only: the parent owns `markCelebrated` + analytics + the GO
/// navigation (commit → dismiss → refresh → navigate, Codex P6).
class FeatureUnlockCeremony extends StatefulWidget {
  const FeatureUnlockCeremony({
    super.key,
    required this.gates,
    required this.onGo,
    required this.onDismiss,
  });

  /// The unlocked gates to celebrate, oldest first. Length 1 = the standard
  /// single reveal (GO + LATER); >1 = the coalesced catch-up (CONTINUE).
  final List<FeatureGate> gates;

  /// Single-gate GO — the parent settles the queue then quick-navs.
  final ValueChanged<FeatureGate> onGo;

  /// LATER / CONTINUE — the parent settles the queue and removes the overlay.
  final VoidCallback onDismiss;

  @override
  State<FeatureUnlockCeremony> createState() => _FeatureUnlockCeremonyState();
}

// ── timeline (ms) ────────────────────────────────────────────────────────────
const double _kTickMs = 150;
const double _kSurgeMs = 500;
const double _kWipeMs = 280; // per-icon scanline duration
const double _kWipeStaggerMs = 120; // coalesced per-icon offset
const double _kKickerMs = 620;
const double _kTitleMs = 780;
const double _kBitMs = 900;
const double _kSettleMs = 1600;

// ── ceremony scene art (procedural, like the session ceremony's — the
//    documented raw-Color exception; brand accents stay tokens) ──────────────
const Color _scrimInner = Color(0xFF0B1220);
const Color _scrimOuter = Color(0xFF07070F);
const List<Color> _amberSparks = [
  Color(0xFFFFD21F),
  Color(0xFFFFEC8C),
  kAmberDark,
];
const List<Color> _dustColors = [
  Color(0xFF17D6CC),
  Color(0xFF3A5A78),
  kBorderVariant,
];

const double _kSlotPx = 88; // bracket-framed slot around each 64px icon
const double _kIconPx = 64; // 16×4 / 32×2 / 384÷6 — integer-scaled for all

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.color);
  double x, y;
  final double vx, vy;
  final double life;
  double age = 0;
  final Color color;
}

class _Dust {
  _Dust(this.x, this.y, this.v, this.tw, this.color);
  double x, y, tw;
  final double v;
  final Color color;
}

class _FeatureUnlockCeremonyState extends State<FeatureUnlockCeremony>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  final Set<String> _fired = {};
  bool _settled = false;
  bool _actionTaken = false;

  // Full-bleed ambient dust + the slot-local spark ring (slot units).
  final List<_Spark> _sparks = [];
  final List<_Dust> _dust = [];
  final math.Random _rand = math.Random(0x0B17);
  double _dustAlpha = 0;
  Size? _size;

  bool get _reduce =>
      MediaQuery.of(context).disableAnimations ||
      MediaQuery.of(context).accessibleNavigation;

  List<FeatureGateSpec> get _specs =>
      [for (final g in widget.gates) featureGateSpecs[g]!];

  bool get _single => widget.gates.length == 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion / accessible navigation: the settled card IS the
    // experience — no cinematic, no sounds, buttons live immediately.
    if (_reduce && !_settled) {
      _fired.addAll(const ['tick', 'surge', 'settle_haptic']);
      _sparks.clear();
      _ticker?.stop();
      _t.value = _kSettleMs;
      _settled = true;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _t.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = math.min(60.0, (elapsed - _lastTick).inMicroseconds / 1000.0);
    _lastTick = elapsed;
    if (dt <= 0) return;
    _t.value += dt;
    _evaluate(_t.value);
    _stepFx(dt);
    // Once settled and the last spark has drained, the clock can rest.
    if (_settled && _sparks.isEmpty && _ticker!.isActive) {
      _ticker?.stop();
    }
  }

  void _once(String key, VoidCallback fn) {
    if (_fired.contains(key)) return;
    _fired.add(key);
    fn();
  }

  void _evaluate(double t) {
    _dustAlpha = t < _kTickMs
        ? (t / _kTickMs) * 0.5
        : t < _kSettleMs
        ? 0.5
        : math.max(0.0, 0.5 * (1 - (t - _kSettleMs) / 500));
    if (t >= _kTickMs) _once('tick', SfxService.instance.playCeremonyTick);
    if (t >= _kSurgeMs) {
      _once('surge', () {
        _burst();
        SfxService.instance.playCeremonyChime();
        HapticService.instance.success();
      });
    }
    if (t >= _kSettleMs && !_settled) {
      // The buttons become actionable the SAME frame the settle lands — no
      // one-frame window where they look live but a tap is dropped.
      _settled = true;
      if (mounted) setState(() {});
    }
  }

  /// The surge burst: a 12-spark amber ring out of the (first) icon slot.
  void _burst() {
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * 6.283;
      final sp = 0.045 + _rand.nextDouble() * 0.04;
      _sparks.add(
        _Spark(
          _kSlotPx / 2,
          _kSlotPx / 2,
          math.cos(a) * sp,
          math.sin(a) * sp,
          340 + _rand.nextDouble() * 120,
          _amberSparks[i % 3],
        ),
      );
    }
  }

  void _initDust(Size size) {
    if (_dust.isNotEmpty) return;
    final uw = size.width / 2, uh = size.height / 2;
    for (var i = 0; i < 14; i++) {
      _dust.add(
        _Dust(
          _rand.nextDouble() * uw,
          _rand.nextDouble() * uh,
          0.004 + _rand.nextDouble() * 0.008,
          _rand.nextDouble() * 6.28,
          _dustColors[i % 3],
        ),
      );
    }
  }

  void _stepFx(double dt) {
    final size = _size;
    if (size != null && _dustAlpha > 0.01) {
      final uw = size.width / 2, uh = size.height / 2;
      for (final d in _dust) {
        d.y -= d.v * dt;
        d.tw += dt * 0.004;
        if (d.y < -2) {
          d.y = uh + 2;
          d.x = _rand.nextDouble() * uw;
        }
      }
    }
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final p = _sparks[i];
      p.age += dt;
      if (p.age >= p.life) {
        _sparks.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  /// Tap-to-skip: jump to the settled card. Idempotent — pending one-shots are
  /// marked fired silently; no sounds replay.
  void _skipToSettled() {
    if (_settled) return;
    _fired.addAll(const ['tick', 'surge']);
    _sparks.clear();
    _t.value = _kSettleMs;
    _settled = true;
    if (mounted) setState(() {});
  }

  void _go() {
    if (_actionTaken) return;
    _actionTaken = true;
    widget.onGo(widget.gates.first);
  }

  void _dismiss() {
    if (_actionTaken) return;
    _actionTaken = true;
    widget.onDismiss();
  }

  String _announcement(List<FeatureGateSpec> specs) {
    if (_single) {
      return 'New system online: ${specs.first.title}. '
          '${specs.first.ceremonyLine}';
    }
    final names = specs.map((s) => s.title).join(', ');
    return 'New systems online: $names.';
  }

  // ── per-beat curves ────────────────────────────────────────────────────────
  double _wipeProgress(double t, int index) {
    final start = _kSurgeMs + index * _kWipeStaggerMs;
    return ((t - start) / _kWipeMs).clamp(0.0, 1.0);
  }

  /// CRT pre-power flicker on the icon silhouette before the surge.
  double _silhouetteAlpha(double t) {
    if (t < 90 || t >= _kSurgeMs) return 0;
    final flicker = math.sin(t / 34) > 0.55 ? 0.14 : 0.06;
    return flicker;
  }

  /// Brackets blink in bright for the arrival, then recede to a faint
  /// persistent frame — the settled card keeps the "slot" identity (and the
  /// frames visually equalize icons of different pixel mass).
  double _bracketAlpha(double t) {
    if (t < 90) return 0;
    if (t < _kSurgeMs) return math.min(0.55, (t - 90) / 160 * 0.55);
    final fade = ((t - _kSurgeMs) / 220).clamp(0.0, 1.0);
    return 0.55 - (0.55 - 0.22) * fade;
  }

  /// Brackets tighten toward the slot as the reveal approaches — the coil.
  double _bracketInset(double t) {
    final coil = t < _kSurgeMs ? ((t - 90) / (_kSurgeMs - 90)).clamp(0.0, 1.0) : 1.0;
    return 8 - coil * 5;
  }

  double _kickerAlpha(double t) {
    if (t < _kKickerMs) return 0;
    // Phosphor blink-in: two dim frames, then lit.
    final dt = t - _kKickerMs;
    if (dt < 50) return 0.35;
    if (dt < 90) return 0.12;
    return 1;
  }

  double _titleAlpha(double t) => t >= _kTitleMs ? 1 : 0;

  /// One amber strobe frame on the title slam, then settle to kText.
  Color _titleColor(double t) {
    final dt = t - _kTitleMs;
    if (dt >= 0 && dt < 70) return kAmber;
    return kText;
  }

  double _titleScale(double t) {
    final dt = t - _kTitleMs;
    if (dt < 0) return 1;
    if (dt >= 90) return 1;
    return 1.06 - 0.06 * (dt / 90);
  }

  double _bitAlpha(double t) =>
      ((t - _kBitMs) / 240).clamp(0.0, 1.0).toDouble();

  double _buttonsAlpha(double t) =>
      ((t - (_kSettleMs - 150)) / 150).clamp(0.0, 1.0).toDouble();

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final specs = _specs;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _size = size;
        _initDust(size);
        // haptic-ok: full-screen skip catcher, fires selection() in-handler
        return GestureDetector(
          key: const ValueKey('unlock_ceremony_skip'),
          behavior: HitTestBehavior.opaque,
          onTap: _settled
              ? null
              : () {
                  HapticService.instance.selection();
                  _skipToSettled();
                },
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final t = _t.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Held scrim — the takeover surface itself.
                  CustomPaint(
                    painter: _UnlockBackdropPainter(
                      scrimOp: (t / _kTickMs).clamp(0.0, 1.0) * 0.97,
                    ),
                  ),
                  // Ambient pixel dust (full-bleed, half-res).
                  CustomPaint(
                    painter: _UnlockDustPainter(
                      dust: _dust,
                      dustAlpha: _dustAlpha,
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // One announced node for the reveal itself; the
                            // buttons stay separate, individually labelled.
                            Semantics(
                              liveRegion: true,
                              label: _announcement(specs),
                              excludeSemantics: true,
                              child: Column(
                                children: [
                                  _buildIconRow(t, specs),
                                  const SizedBox(height: kSpace4),
                                  _buildKicker(t),
                                  const SizedBox(height: kSpace3),
                                  _buildTitles(t, specs),
                                  const SizedBox(height: kSpace4),
                                  _buildBitRow(t, specs),
                                ],
                              ),
                            ),
                            const SizedBox(height: kSpace5),
                            _buildActions(t, specs),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_settled)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 26,
                      child: Text(
                        'TAP TO SKIP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 7,
                          letterSpacing: 0.5,
                          color: kDim,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIconRow(double t, List<FeatureGateSpec> specs) {
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < specs.length; i++)
          SizedBox(
            width: _kSlotPx,
            height: _kSlotPx,
            child: CustomPaint(
              // Slot-local FX: brackets, the scanline, and (slot 0) the spark
              // ring — no global coordinate measuring anywhere.
              foregroundPainter: _UnlockSlotPainter(
                wipe: _wipeProgress(t, i),
                bracketAlpha: _bracketAlpha(t),
                bracketInset: _bracketInset(t),
                sparks: i == 0 ? _sparks : const [],
              ),
              child: Center(
                child: _RevealedIcon(
                  iconPath: specs[i].iconPath,
                  wipe: _wipeProgress(t, i),
                  silhouetteAlpha: _silhouetteAlpha(t),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKicker(double t) {
    return Opacity(
      opacity: _kickerAlpha(t),
      child: Text(
        _single ? 'NEW SYSTEM ONLINE' : 'NEW SYSTEMS ONLINE',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          letterSpacing: 1,
          color: bitGlow,
        ),
      ),
    );
  }

  Widget _buildTitles(double t, List<FeatureGateSpec> specs) {
    return Opacity(
      opacity: _titleAlpha(t),
      child: Transform.scale(
        scale: _titleScale(t),
        child: Column(
          children: [
            for (final spec in specs)
              Padding(
                padding: EdgeInsets.only(top: specs.first == spec ? 0 : 8),
                child: Text(
                  spec.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: _single ? 14 : 11,
                    color: _titleColor(t),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitRow(double t, List<FeatureGateSpec> specs) {
    final line = _single
        ? specs.first.ceremonyLine
        : 'All this came online while you trained.';
    return Opacity(
      opacity: _bitAlpha(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BitMoodCore(
              pose: BitPose.cheer,
              reveal: 1,
              size: 56,
              idleAmp: _bitAlpha(t),
            ),
            const SizedBox(width: kSpace2),
            Flexible(
              child: BitSpeechBubble(
                text: line,
                tailDirection: BitTailDirection.left,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(double t, List<FeatureGateSpec> specs) {
    return Opacity(
      opacity: _buttonsAlpha(t),
      child: IgnorePointer(
        ignoring: !_settled,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace4),
          child: _single
              ? Column(
                  children: [
                    PixelButton(
                      label: 'OPEN ${specs.first.title}',
                      onPressed: _go,
                    ),
                    const SizedBox(height: kSpace2),
                    PixelButton(
                      label: 'LATER',
                      secondary: true,
                      onPressed: _dismiss,
                    ),
                  ],
                )
              : PixelButton(label: 'CONTINUE', onPressed: _dismiss),
        ),
      ),
    );
  }
}

/// The revealed pixel icon: a dim pre-power silhouette, then a hard top-down
/// scanline wipe. Recolored white via srcIn (single-silhouette assets),
/// nearest-neighbour, at an integer-scaled 64px.
class _RevealedIcon extends StatelessWidget {
  const _RevealedIcon({
    required this.iconPath,
    required this.wipe,
    required this.silhouetteAlpha,
  });

  final String iconPath;
  final double wipe;
  final double silhouetteAlpha;

  @override
  Widget build(BuildContext context) {
    Widget icon(Color color) => Image.asset(
      iconPath,
      width: _kIconPx,
      height: _kIconPx,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.help_outline_sharp, color: kMutedText, size: 40),
    );
    return SizedBox(
      width: _kIconPx,
      height: _kIconPx,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (silhouetteAlpha > 0 && wipe <= 0)
            icon(kText.withValues(alpha: silhouetteAlpha)),
          if (wipe > 0)
            ClipRect(
              clipper: _TopWipeClipper(wipe),
              child: icon(kText),
            ),
        ],
      ),
    );
  }
}

class _TopWipeClipper extends CustomClipper<Rect> {
  const _TopWipeClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * progress);

  @override
  bool shouldReclip(covariant _TopWipeClipper old) =>
      old.progress != progress;
}

/// Held dark radial scrim — the takeover surface (stays up until dismissed).
class _UnlockBackdropPainter extends CustomPainter {
  _UnlockBackdropPainter({required this.scrimOp});

  final double scrimOp;

  @override
  void paint(Canvas canvas, Size size) {
    if (scrimOp <= 0.004) return;
    canvas.clipRect(Offset.zero & size);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1, (size.height * 0.46) / (size.width * 0.7));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 4,
        height: size.width * 4,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _scrimInner.withValues(alpha: scrimOp),
            _scrimOuter.withValues(alpha: scrimOp),
          ],
          stops: const [0.0, 0.68],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: size.width * 0.7),
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UnlockBackdropPainter old) =>
      old.scrimOp != scrimOp;
}

/// Full-bleed ambient dust: 1-unit squares on a half-resolution grid.
class _UnlockDustPainter extends CustomPainter {
  _UnlockDustPainter({required this.dust, required this.dustAlpha});

  final List<_Dust> dust;
  final double dustAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (dustAlpha <= 0.01) return;
    canvas.clipRect(Offset.zero & size);
    canvas.scale(2, 2);
    final paint = Paint()..isAntiAlias = false;
    for (final d in dust) {
      final a = (dustAlpha * (0.35 + 0.3 * math.sin(d.tw))).clamp(0.0, 1.0);
      paint.color = d.color.withValues(alpha: a);
      canvas.drawRect(
        Rect.fromLTWH(d.x.roundToDouble(), d.y.roundToDouble(), 1, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UnlockDustPainter old) => true;
}

/// Slot-local FX: the four cyan arrival brackets, the scanline at the wipe
/// edge, and the amber spark ring — all in slot coordinates, pixel-crisp.
class _UnlockSlotPainter extends CustomPainter {
  _UnlockSlotPainter({
    required this.wipe,
    required this.bracketAlpha,
    required this.bracketInset,
    required this.sparks,
  });

  final double wipe;
  final double bracketAlpha;
  final double bracketInset;
  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..isAntiAlias = false;

    // Arrival brackets: 4-connected L corners tightening toward the icon.
    if (bracketAlpha > 0.01) {
      paint.color = bitGlow.withValues(alpha: bracketAlpha);
      final n = bracketInset.roundToDouble();
      const l = 10.0;
      for (final d in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
        final x = d.$1 < 0 ? n : size.width - n;
        final y = d.$2 < 0 ? n : size.height - n;
        canvas.drawRect(
          Rect.fromLTWH(d.$1 < 0 ? x : x - l, y - (d.$2 < 0 ? 0 : 2), l, 2),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(x - (d.$1 < 0 ? 0 : 2), d.$2 < 0 ? y : y - l, 2, l),
          paint,
        );
      }
    }

    // The scanline: a bright cyan 2px bar riding the wipe edge over the icon.
    if (wipe > 0 && wipe < 1) {
      final iconTop = (size.height - _kIconPx) / 2;
      final y = iconTop + _kIconPx * wipe;
      paint.color = bitGlow;
      canvas.drawRect(
        Rect.fromLTWH((size.width - _kIconPx) / 2, y, _kIconPx, 2),
        paint,
      );
      paint.color = bitGlow.withValues(alpha: 0.25);
      canvas.drawRect(
        Rect.fromLTWH((size.width - _kIconPx) / 2, y + 2, _kIconPx, 4),
        paint,
      );
    }

    // Surge spark ring (2px cells, aliased).
    for (final p in sparks) {
      paint.color = p.color.withValues(
        alpha: (1 - p.age / p.life).clamp(0.0, 1.0),
      );
      canvas.drawRect(
        Rect.fromLTWH(p.x.roundToDouble(), p.y.roundToDouble(), 2, 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UnlockSlotPainter old) => true;
}
