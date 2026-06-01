import 'package:flutter/material.dart';

import '../services/xp_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'glitch_text.dart';
import 'strobe_flash.dart';

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
    _controller
      ..duration = Duration(
        milliseconds: (560 * (to - from).abs()).clamp(260, 600).round(),
      )
      ..reset();
    await _controller.forward();
  }

  Widget _bar() => StrobeFlash(
    trigger: _barFlash,
    color: kAmber,
    opacity: 0.55,
    toggles: 2,
    toggleMs: 70,
    borderRadius: BorderRadius.circular(4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: kBorder),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _fill.clamp(0.0, 1.0),
              child: const ColoredBox(color: kNeon),
            ),
          ],
        ),
      ),
    ),
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
                GlitchText(
                  key: ValueKey('level_$_level'),
                  text: 'LEVEL $_level',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 18,
                    color: kAmber,
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
            Text(
              'LV $_level',
              style: AppFonts.shareTechMono(
                color: kAmber,
                fontSize: 14,
                fontWeight: FontWeight.w700,
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
