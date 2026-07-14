import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/boot_service.dart';
import '../theme/tokens.dart';
import 'onboarding/onboarding_flow_page.dart';
import 'root_page.dart';

/// The app-open boot splash. Runs the real launch work ([BootService]) while a
/// short, on-brand CRT "assemble & lock" animation plays, then reveals the
/// destination (RootPage / OnboardingFlowPage) the instant work finishes — with
/// a minimum so the lock beat lands and a hard cap as a backstop.
///
/// Honest by design: the animation occupies genuine load time rather than faking
/// a processing hold. Reduced motion paints the locked emblem statically and
/// reveals as soon as boot resolves.
class BootSplashPage extends StatefulWidget {
  const BootSplashPage({
    super.key,
    this.bootOverride,
    this.destinationBuilder,
    this.minDisplay = const Duration(milliseconds: 1000),
    this.maxDisplay = const Duration(milliseconds: 1800),
  });

  /// Test seam — supplies the boot future instead of [BootService.run].
  final Future<bool> Function()? bootOverride;

  /// Test seam — builds the revealed destination instead of the real pages.
  final Widget Function(bool isComplete)? destinationBuilder;

  /// Shortest the splash stays up (so the lock beat plays). Compressed under
  /// reduced motion.
  final Duration minDisplay;

  /// Hard cap — reveal even if boot work never resolves.
  final Duration maxDisplay;

  @override
  State<BootSplashPage> createState() => _BootSplashPageState();
}

class _BootSplashPageState extends State<BootSplashPage>
    with SingleTickerProviderStateMixin {
  static const _assemblyMs = 950;
  static const _revealMs = 500;
  static const _reducedMinMs = 300;

  late final AnimationController _assembly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _assemblyMs),
  );

  bool _started = false;
  bool _reduced = false;

  bool _bootDone = false;
  bool _minElapsed = false;
  bool? _isComplete;
  bool _revealed = false;
  bool _splashGone = false;

  Timer? _minTimer;
  Timer? _capTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final media = MediaQuery.of(context);
    _reduced = media.disableAnimations || media.accessibleNavigation;
    if (_reduced) {
      _assembly.value = 1; // paint the locked emblem, no assembly
    } else {
      _assembly.forward();
    }

    final min = _reduced
        ? const Duration(milliseconds: _reducedMinMs)
        : widget.minDisplay;
    _minTimer = Timer(min, () {
      _minElapsed = true;
      _maybeReveal();
    });
    _capTimer = Timer(widget.maxDisplay, _forceReveal);

    (widget.bootOverride ?? const BootService().run)().then((isComplete) {
      if (!mounted) return;
      setState(() {
        _isComplete = isComplete;
        _bootDone = true;
      });
      _maybeReveal();
    });
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _capTimer?.cancel();
    _assembly.dispose();
    super.dispose();
  }

  void _maybeReveal() {
    if (_revealed || !_bootDone || !_minElapsed) return;
    _reveal();
  }

  // Backstop: boot work hung past the cap. Route to onboarding (the safe default
  // for an undetermined gate) rather than leaving the splash up forever.
  void _forceReveal() {
    if (_revealed) return;
    _isComplete ??= false;
    _bootDone = true;
    _reveal();
  }

  void _reveal() {
    _minTimer?.cancel();
    _capTimer?.cancel();
    setState(() {
      _revealed = true;
      if (_reduced) _splashGone = true; // no fade under reduced motion
    });
  }

  Widget _buildDestination(bool isComplete) {
    if (widget.destinationBuilder != null) {
      return widget.destinationBuilder!(isComplete);
    }
    return isComplete ? const RootPage() : const OnboardingFlowPage();
  }

  @override
  Widget build(BuildContext context) {
    final revealDur = _reduced
        ? Duration.zero
        : const Duration(milliseconds: _revealMs);
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Destination warms up behind the splash, then fades + settles in.
          if (_isComplete != null)
            AnimatedScale(
              scale: _revealed ? 1.0 : 1.03,
              duration: revealDur,
              curve: _kMech,
              child: AnimatedOpacity(
                opacity: _revealed ? 1.0 : 0.0,
                duration: revealDur,
                child: _buildDestination(_isComplete!),
              ),
            ),
          // Boot splash overlay.
          if (!_splashGone)
            AnimatedOpacity(
              key: const ValueKey('boot_splash_overlay'),
              opacity: _revealed ? 0.0 : 1.0,
              duration: revealDur,
              curve: _kMech,
              onEnd: () {
                if (_revealed && mounted) setState(() => _splashGone = true);
              },
              child: _BootSplashOverlay(assembly: _assembly),
            ),
        ],
      ),
    );
  }
}

// Mechanical easing — heavy in/out, no overshoot (mirrors the mock).
const Cubic _kMech = Cubic(0.85, 0, 0.15, 1);

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

class _BootSplashOverlay extends StatelessWidget {
  const _BootSplashOverlay({required this.assembly});

  final Animation<double> assembly;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.16),
          radius: 1.1,
          colors: [Color(0xFF13132A), kBg, Color(0xFF07070D)],
          stops: [0, 0.6, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _CrtPainter())),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: assembly,
                builder: (context, _) =>
                    CustomPaint(painter: _PowerOnPainter(assembly.value)),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: assembly,
                  builder: (context, _) =>
                      CustomPaint(painter: _BootEmblemPainter(assembly.value)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet, steady CRT scanlines + vignette (no busy flicker).
class _CrtPainter extends CustomPainter {
  const _CrtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scan = Paint()
      ..color = const Color(0x38000000)
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y + 2), Offset(size.width, y + 2), scan);
    }
    final vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.04),
        radius: 0.95,
        colors: [Colors.transparent, Colors.transparent, kBlack.withValues(alpha: 0.6)],
        stops: const [0, 0.5, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _CrtPainter oldDelegate) => false;
}

/// Cold power-on: a hard bright line snaps to full height, then clears.
class _PowerOnPainter extends CustomPainter {
  const _PowerOnPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Maps to the mock's power-on window over the first ~third of the assembly.
    final p = _seg(t, 0.0, 0.34);
    if (p <= 0 || p >= 1) return;
    final cy = size.height / 2;
    double opacity;
    double halfH;
    if (p < 0.28) {
      // line scales in across the screen at center
      opacity = 0.9 * (p / 0.28);
      halfH = 1.5;
    } else if (p < 0.7) {
      opacity = 0.9;
      halfH = 1.5;
    } else {
      // expands to full height, then fades
      final e = _kMech.transform(_seg(p, 0.7, 1.0));
      opacity = 0.9 * (1 - e);
      halfH = 1.5 + e * (size.height / 2);
    }
    final glow = Paint()
      ..color = const Color(0xFFDFF7EC).withValues(alpha: opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final core = Paint()..color = const Color(0xFFDFF7EC).withValues(alpha: opacity);
    final rect = Rect.fromLTRB(0, cy - halfH, size.width, cy + halfH);
    canvas.drawRect(rect, glow);
    canvas.drawRect(rect, core);
  }

  @override
  bool shouldRepaint(covariant _PowerOnPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// The emblem: dashed scanner ring + 4 tick marks + the barbell "H" (two plates
/// drive in, the bar links them) + a single scanner pass, locking at t→1.
class _BootEmblemPainter extends CustomPainter {
  const _BootEmblemPainter(this.t);

  final double t;

  // Mock geometry is authored in a 176px box; scale to the painter size.
  static const _box = 176.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _box;
    final c = Offset(size.width / 2, size.height / 2);
    final lockT = _seg(t, 0.85, 1.0);

    _paintRing(canvas, c, s, lockT);
    _paintTicks(canvas, c, s, lockT);
    _paintMark(canvas, size, s, lockT);
    _paintScan(canvas, size, s);
  }

  void _paintRing(Canvas canvas, Offset c, double s, double lockT) {
    final opacity = _seg(t, 0.32, 0.73) * (0.55 + 0.4 * lockT);
    if (opacity <= 0) return;
    final r = 84.0 * s;
    // Subtle scanner rotation that halts on lock.
    final rot = (1 - lockT) * _seg(t, 0.32, 1.0) * -0.6;
    const dash = 2.0, gap = 7.0;
    final dashA = dash / 84.0;
    final gapA = gap / 84.0;
    final period = dashA + gapA;
    final count = (2 * math.pi / period).floor();
    final width = (1.4 + 0.6 * lockT) * s;

    void stroke(Paint p) {
      for (var i = 0; i < count; i++) {
        final a0 = rot + i * period;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          a0,
          dashA,
          false,
          p,
        );
      }
    }

    if (lockT > 0) {
      stroke(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = kNeon.withValues(alpha: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 4 * lockT),
      );
    }
    stroke(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = kNeon.withValues(alpha: opacity),
    );
  }

  void _paintTicks(Canvas canvas, Offset c, double s, double lockT) {
    final op = _seg(t, 0.48, 0.52) * (0.4 + 0.45 * lockT);
    if (op <= 0) return;
    final paint = Paint()..color = kNeon.withValues(alpha: op);
    final long = 9.0 * s, short = 2.0 * s;
    final reach = 85.0 * s;
    // N / S (vertical), W / E (horizontal)
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, -reach), width: short, height: long),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, reach), width: short, height: long),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(-reach, 0), width: long, height: short),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(reach, 0), width: long, height: short),
      paint,
    );
  }

  void _paintMark(Canvas canvas, Size size, double s, double lockT) {
    // Mark box (mock): 96x88 centered; plates 28x88 at the ends, bar 40x12.
    final cx = size.width / 2, cy = size.height / 2;
    final markLeft = cx - 48 * s;
    final markTop = cy - 44 * s;
    final plateW = 28.0 * s, plateH = 88.0 * s;

    final glow = Paint()
      ..color = kNeon.withValues(alpha: 0.4 + 0.5 * lockT)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 8 * lockT);
    final fill = Paint()..color = kNeon;

    // Plates drive in from the sides.
    final driveL = _kMech.transform(_seg(t, 0.09, 0.59));
    final driveR = _kMech.transform(_seg(t, 0.09, 0.59));
    final lOpacity = _seg(t, 0.09, 0.16);
    final rOpacity = _seg(t, 0.09, 0.16);

    void plate(double x, double drive, double opacity, bool fromLeft) {
      if (opacity <= 0) return;
      final dx = (fromLeft ? -52.0 : 52.0) * s * (1 - drive);
      final rect = Rect.fromLTWH(x + dx, markTop, plateW, plateH);
      final p = Paint()..color = kNeon.withValues(alpha: opacity);
      canvas.drawRect(rect.inflate(2 * s), glow);
      canvas.drawRect(rect, opacity >= 1 ? fill : p);
    }

    plate(markLeft, driveL, lOpacity, true);
    plate(markLeft + 96 * s - plateW, driveR, rOpacity, false);

    // Bar links the plates: scaleX 0→1 from center.
    final barScale = _kMech.transform(_seg(t, 0.45, 0.69));
    if (barScale > 0) {
      final barFullW = 40.0 * s, barH = 12.0 * s;
      final barCx = markLeft + 28 * s + barFullW / 2;
      final barCy = markTop + 38 * s + barH / 2;
      final w = barFullW * barScale;
      final rect = Rect.fromCenter(center: Offset(barCx, barCy), width: w, height: barH);
      canvas.drawRect(rect.inflate(2 * s), glow);
      canvas.drawRect(rect, fill);
    }
  }

  void _paintScan(Canvas canvas, Size size, double s) {
    // Single beam pass; suppressed once the mark locks.
    final p = _seg(t, 0.545, 0.909);
    if (p <= 0 || p >= 1 || t >= 0.86) return;
    final beamH = 30.0 * s;
    final y = -beamH + p * (size.height + beamH);
    final rect = Rect.fromLTWH(0, y, size.width, beamH);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          kNeon.withValues(alpha: 0),
          kNeon.withValues(alpha: 0.5),
          kNeon.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _BootEmblemPainter oldDelegate) =>
      oldDelegate.t != t;
}
