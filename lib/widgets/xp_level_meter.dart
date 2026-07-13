import 'package:flutter/material.dart';

import '../services/xp_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_bar.dart';
import 'glitch_text.dart';
import 'strobe_flash.dart';

/// Duration of a single bar-fill *climb*. Deliberately **fixed** (not scaled by
/// distance) and kept equal to the riser SFX length (`ops/gen_xp_riser.py` DUR,
/// 0.80s) so the "bar running up" sound rises and lands together with the fill.
const Duration kXpBarFillDuration = Duration(milliseconds: 800);

/// The finish arc's XP / level beat. Fills the bar from the old XP fraction
/// toward the next level; on each level crossed it flashes the bar, punch-scales
/// the `LV n` number as it increments, resets to empty, and refills into the new
/// level. Reduced motion renders the final level + fraction instantly.
///
/// [onLevelUp] fires once per level boundary crossed (the parent uses it to
/// shake / flash the whole screen).
class XpLevelMeter extends StatefulWidget {
  const XpLevelMeter({
    super.key,
    required this.oldTotalXP,
    required this.newTotalXP,
    this.play = true,
    this.prominent = true,
    this.onLevelUp,
    this.onClimbStart,
  });

  final int oldTotalXP;
  final int newTotalXP;
  final bool play;

  /// When true (default) a level-up makes the meter the prominent celebration —
  /// a big `LEVEL N` headline + local "+1 LV" float. When false (the level-up
  /// lost the hero ladder to a rank/diamond), the meter climbs quietly as the
  /// small inline `LV n` instead, so only the actual hero owns the big beat.
  final bool prominent;
  final VoidCallback? onLevelUp;

  /// Fires at the start of **each** bar-fill segment (not under reduced motion —
  /// the bar snaps then). The parent plays the rising "bar running up" SFX, whose
  /// length is matched to the fill ([kXpBarFillDuration]) so they land together.
  /// Kept as a callback so this widget stays sound-free/testable.
  final VoidCallback? onClimbStart;

  @override
  State<XpLevelMeter> createState() => _XpLevelMeterState();
}

class _Segment {
  const _Segment({
    required this.level,
    required this.from,
    required this.to,
    this.levelUpTo,
  });

  final int level;
  final double from;
  final double to;
  final int? levelUpTo; // non-null => a level-up fires at the end of this fill
}

class _XpLevelMeterState extends State<XpLevelMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Tween<double> _fillTween = Tween<double>(begin: 0, end: 0);

  late int _level = XpService.progressForTotalXP(widget.oldTotalXP).level;
  double _fill = 0;
  int _barFlash = 0;
  int _floatTrigger = 0;
  bool _started = false;

  /// True when this session actually crosses a level boundary — then the meter
  /// becomes the prominent level-up display (big LEVEL headline + local float).
  bool get _leveledUp =>
      XpService.progressForTotalXP(widget.newTotalXP).level >
      XpService.progressForTotalXP(widget.oldTotalXP).level;

  @override
  void initState() {
    super.initState();
    _fill = XpService.progressForTotalXP(widget.oldTotalXP).fraction;
    _controller.addListener(() {
      if (!mounted) return;
      setState(() => _fill = _fillTween.evaluate(_controller));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(covariant XpLevelMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) _maybeStart();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeStart() {
    if (_started || !widget.play || !mounted) return;
    _started = true;
    final reduced = MediaQuery.of(context).disableAnimations;
    final target = XpService.progressForTotalXP(widget.newTotalXP);
    if (reduced) {
      setState(() {
        _level = target.level;
        _fill = target.fraction;
      });
      return;
    }
    _play();
  }

  List<_Segment> _segments() {
    final start = XpService.progressForTotalXP(widget.oldTotalXP);
    final end = XpService.progressForTotalXP(widget.newTotalXP);
    if (end.level <= start.level) {
      return [
        _Segment(level: start.level, from: start.fraction, to: end.fraction),
      ];
    }
    final segments = <_Segment>[];
    var level = start.level;
    var from = start.fraction;
    while (level < end.level) {
      final nextLevel = XpService.getLevel(XpService.xpForNextLevel(level));
      segments.add(
        _Segment(level: level, from: from, to: 1.0, levelUpTo: nextLevel),
      );
      level = nextLevel;
      from = 0.0;
    }
    segments.add(_Segment(level: end.level, from: 0.0, to: end.fraction));
    return segments;
  }

  Future<void> _play() async {
    // Hold on the starting level + fraction first (driven by the controller so
    // it stays in the animation system) so the climb reads clearly.
    final start = XpService.progressForTotalXP(widget.oldTotalXP);
    await _animateFill(start.fraction, start.fraction);
    if (!mounted) return;
    for (final segment in _segments()) {
      if (!mounted) return;
      setState(() => _level = segment.level);
      // Sound the rising "bar running up" SFX for this fill segment — the riser
      // and the climb share [kXpBarFillDuration], so they rise and land together.
      if (segment.to > segment.from) widget.onClimbStart?.call();
      await _animateFill(segment.from, segment.to);
      if (!mounted) return;
      if (segment.levelUpTo != null) {
        widget.onLevelUp?.call();
        setState(() {
          _level = segment.levelUpTo!;
          _barFlash++;
          _floatTrigger++;
          _fill = 0;
        });
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
    }
  }

  Future<void> _animateFill(double from, double to) async {
    _fillTween = Tween<double>(begin: from, end: to);
    // A climb runs for the FIXED [kXpBarFillDuration] (matched to the riser SFX)
    // so sound and fill land together, regardless of how far the bar travels; the
    // zero-distance opening hold stays brief.
    final climbing = (to - from).abs() > 0.0001;
    _controller
      ..duration = climbing
          ? kXpBarFillDuration
          : const Duration(milliseconds: 220)
      ..reset();
    await _controller.forward();
  }

  Widget _bar() => Stack(
    children: [
      StrobeFlash(
        trigger: _barFlash,
        color: kAmber,
        opacity: 0.55,
        toggles: 2,
        toggleMs: 70,
        borderRadius: BorderRadius.circular(4),
        // The meter's own controller drives `_fill` (segment climb + level-up
        // reset); ArcadeBar with flashOnIncrease:false renders that fill each
        // frame (beveled, no second ease). Amber = the XP/reward read, matching
        // the home XP strip.
        child: ArcadeBar(
          value: _fill,
          accent: kAmber,
          height: 12,
          flashOnIncrease: false,
        ),
      ),
      // A one-shot white-hot light band sweeps across the bar on each level
      // crossing (driven by the same `_barFlash` counter as the strobe). Purely
      // additive juice — omitted under reduced motion (the strobe still reads).
      Positioned.fill(
        child: IgnorePointer(child: _BarSurge(trigger: _barFlash)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final label = XpService.progressForTotalXP(widget.newTotalXP).label;

    // Level-up: the meter IS the celebration — a big LEVEL headline that climbs
    // and glitches per increment, with the bar moved up directly under it and a
    // single "+1 LV" floating locally per level. Only when `prominent` (level-up
    // is the session hero); otherwise the level climbs quietly as `LV n` below.
    if (_leveledUp && widget.prominent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _LevelPunch(
                  trigger: _level,
                  child: GlitchText(
                    key: ValueKey('level_$_level'),
                    text: 'LEVEL $_level',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 18,
                      color: kAmber,
                    ),
                  ),
                ),
                Positioned(top: -6, child: _LevelFloat(trigger: _floatTrigger)),
              ],
            ),
          ),
          const SizedBox(height: kSpace2),
          _bar(),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
        ],
      );
    }

    // No level-up: small inline level + bar (XP-gain-only).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LevelPunch(
              trigger: _level,
              child: Text(
                'LV $_level',
                style: AppFonts.shareTechMono(
                  color: kAmber,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              label,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: kSpace2),
        _bar(),
      ],
    );
  }
}

/// A single "+1 LV" that rises locally from the level/bar and fades, once per
/// level-up (driven by [trigger]). Inert under reduced motion.
class _LevelFloat extends StatefulWidget {
  const _LevelFloat({required this.trigger});

  final int trigger;

  @override
  State<_LevelFloat> createState() => _LevelFloatState();
}

class _LevelFloatState extends State<_LevelFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didUpdateWidget(covariant _LevelFloat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (!MediaQuery.of(context).disableAnimations) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        if (v <= 0 || v >= 1) return const SizedBox.shrink();
        final t = Curves.easeOut.transform(v);
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -t * 26),
            child: const Text(
              '+1 LV',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kAmber,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A quick scale "punch" (1.18 → 1.0, easeOutCubic over [kMotionPop]) fired each
/// time [trigger] changes — the level number popping as it ticks up. Rests at
/// 1.0 (so it doesn't sit enlarged before the first punch). Static under reduced
/// motion.
class _LevelPunch extends StatefulWidget {
  const _LevelPunch({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_LevelPunch> createState() => _LevelPunchState();
}

class _LevelPunchState extends State<_LevelPunch>
    with SingleTickerProviderStateMixin {
  // Created in initState (not lazily) so it's always initialized while the
  // element is active — a lazy `late` field first touched in dispose() (when the
  // reduced-motion build never reads it) does an unsafe deactivated-ancestor
  // TickerMode lookup.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kMotionPop)
      ..value = 1;
  }

  @override
  void didUpdateWidget(covariant _LevelPunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        !MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final scale = 1.0 + 0.18 * (1 - t);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

/// A one-shot white-hot light band that sweeps left→right across the bar once
/// per level crossing (driven by [trigger]). Additive glint over the fill —
/// omitted entirely under reduced motion.
class _BarSurge extends StatefulWidget {
  const _BarSurge({required this.trigger});

  final int trigger;

  @override
  State<_BarSurge> createState() => _BarSurgeState();
}

class _BarSurgeState extends State<_BarSurge>
    with SingleTickerProviderStateMixin {
  // Created in initState (not lazily) — see _LevelPunchState for why.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kMotionPop);
  }

  @override
  void didUpdateWidget(covariant _BarSurge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        widget.trigger > 0 &&
        !MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        if (v <= 0 || v >= 1) return const SizedBox.shrink();
        return CustomPaint(
          painter: _BarSurgePainter(progress: Curves.easeOut.transform(v)),
        );
      },
    );
  }
}

class _BarSurgePainter extends CustomPainter {
  _BarSurgePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Triangle fade (0 → 1 → 0) so the glint rises and falls across the pass.
    final fade = (progress < 0.5 ? progress * 2 : (1 - progress) * 2)
        .clamp(0.0, 1.0);
    final alpha = fade * 0.9;
    if (alpha <= 0) return;
    final hot = Color.lerp(kAmber, kText, 0.85)!;
    final band = w * 0.16;
    final headX = -band + progress * (w + band);
    final p = Paint()..isAntiAlias = false;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Dim trailing wash + a bright leading head.
    canvas.drawRect(
      Rect.fromLTWH(headX - band, 0, band, h),
      p..color = hot.withValues(alpha: alpha * 0.4),
    );
    canvas.drawRect(
      Rect.fromLTWH(headX, 0, band * 0.5, h),
      p..color = hot.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarSurgePainter old) =>
      old.progress != progress;
}
