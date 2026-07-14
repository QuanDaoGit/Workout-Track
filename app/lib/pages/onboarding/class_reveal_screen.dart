import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/calibration_quiz_models.dart';
import '../../models/character_class.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/class_sprite.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';

/// The class reveal — the single climactic moment. The calibration/analysis
/// (and the real persistence) happen earlier on `CalibrationLoadingPage`; this
/// screen does only the reveal: the class name slams in with a punch, the emblem
/// scans up, and the `I AM <CLASS>` CTA commits into the program flow.
class ClassRevealScreen extends StatefulWidget {
  const ClassRevealScreen({
    super.key,
    required this.answers,
    required this.onConfirmed,
  });

  /// The pre-class answers — the goal derives the class; body metrics are
  /// context. Frequency/experience are asked after this screen.
  final PreClassAnswers answers;

  /// Fired when the user commits (`I AM <CLASS>`). The flow then asks the
  /// remaining questions and builds the program.
  final VoidCallback onConfirmed;

  @override
  State<ClassRevealScreen> createState() => _ClassRevealScreenState();
}

class _ClassRevealScreenState extends State<ClassRevealScreen>
    with SingleTickerProviderStateMixin {
  late final _RevealCopy _copy;
  late final _RevealTimeline _timeline;
  late final AnimationController _controller;

  final List<Timer> _timers = [];
  bool _started = false;
  bool _complete = false;
  bool _committed = false;
  int _shakeTrigger = 0;
  int _strobeTrigger = 0;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _copy = _RevealCopy.forAnswers(widget.answers);
    _timeline = const _RevealTimeline();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _timeline.totalMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _complete = true;
      _controller.value = 1;
      return;
    }

    _controller.forward(from: 0);
    _schedule(Duration(milliseconds: _timeline.heroStart), () {
      setState(() {
        _strobeTrigger++;
        _shakeTrigger++;
      });
    });
  }

  void _schedule(Duration delay, VoidCallback callback) {
    _timers.add(
      Timer(delay, () {
        if (mounted && !_complete) callback();
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  void _jumpToFinal() {
    if (_complete) return;
    for (final timer in _timers) {
      timer.cancel();
    }
    _controller.stop();
    setState(() {
      _complete = true;
      _controller.value = 1;
    });
  }

  int get _currentMs => _complete
      ? _timeline.totalMs
      : (_controller.value * _timeline.totalMs).round();

  bool get _buttonReady => _complete || _currentMs >= _timeline.buttonStart;

  void _commit() {
    if (_committed || !_buttonReady) return;
    setState(() => _committed = true);
    widget.onConfirmed();
  }

  double _progress(int ms, int start, int duration) {
    if (_complete || _reduceMotion) return 1;
    return ((ms - start) / duration).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // One-way reveal: the class is already persisted (calibration loader). The
    // system back button must not pop back past this point of no return.
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final ms = _currentMs;
          return StrobeFlash(
            trigger: _strobeTrigger,
            color: kAmber,
            opacity: 0.18,
            toggles: 1,
            toggleMs: 120,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _jumpToFinal,
              child: Scaffold(
                backgroundColor: kBg,
                body: SafeArea(
                  child: ScreenShake(
                    trigger: _reduceMotion ? 0 : _shakeTrigger,
                    magnitude: 2,
                    frames: 4,
                    frameMs: 50,
                    child: _buildHeroBody(ms),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroBody(int ms) {
    final copy = _copy;
    final heroProgress = _complete
        ? 1.0
        : _progress(ms, _timeline.heroStart, 320);
    final focusOpacity = _progress(ms, _timeline.focusStart, 200);
    final flavorOpacity = _progress(ms, _timeline.flavorStart, 200);
    final buttonOpacity = _progress(ms, _timeline.buttonStart, 200);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Opacity(
                      opacity: heroProgress,
                      child: Text(
                        copy.className,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 34,
                          color: copy.classColor,
                          height: 1.08,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace5),
                  Opacity(
                    opacity: heroProgress,
                    child: _HeroEmblem(
                      assetPath:
                          'assets/classes/sigils/${widget.answers.clazz.name}.png',
                      color: copy.classColor,
                      label: copy.className,
                      progress: heroProgress,
                    ),
                  ),
                  const SizedBox(height: kSpace5),
                  Opacity(
                    opacity: focusOpacity,
                    child: Text(
                      copy.focusTag,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: copy.classColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace3),
                  Opacity(
                    opacity: flavorOpacity,
                    child: Text(
                      copy.flavor,
                      textAlign: TextAlign.center,
                      style: AppFonts.shareTechMono(
                        color: kText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Opacity(
                opacity: _complete ? 1 : buttonOpacity,
                child: PixelButton(
                  label: copy.buttonLabel,
                  color: copy.classColor,
                  minHeight: 52,
                  fontSize: 13,
                  onPressed: _buttonReady && !_committed ? _commit : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: kSpace5),
        ],
      ),
    );
  }
}

class _RevealTimeline {
  const _RevealTimeline();

  int get heroStart => 120;
  int get focusStart => 560;
  int get flavorStart => 800;
  int get buttonStart => 1120;
  int get totalMs => 1400;
}

class _HeroEmblem extends StatelessWidget {
  const _HeroEmblem({
    required this.assetPath,
    required this.color,
    required this.label,
    required this.progress,
  });

  final String assetPath;
  final Color color;
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HeroEmblemFramePainter(color: color),
      child: SizedBox(
        width: 164,
        height: 164,
        child: Center(
          child: _ScanlineReveal(
            progress: progress,
            size: 132,
            child: ClassSprite(
              assetPath: assetPath,
              placeholderTint: color,
              size: 132,
              placeholderLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroEmblemFramePainter extends CustomPainter {
  const _HeroEmblemFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const corner = 24.0;
    final rect = Offset.zero & size;

    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, corner),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, corner),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -corner),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-corner, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -corner),
      paint,
    );

    final softPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect.deflate(14), softPaint);
  }

  @override
  bool shouldRepaint(covariant _HeroEmblemFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ScanlineReveal extends StatelessWidget {
  const _ScanlineReveal({
    required this.progress,
    required this.child,
    this.size = 64,
  });

  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: t.clamp(0.0001, 1.0),
              child: child,
            ),
          ),
          if (t > 0 && t < 1)
            CustomPaint(
              painter: _ScanlineRevealPainter(progress: t),
              child: const SizedBox.expand(),
            ),
        ],
      ),
    );
  }
}

class _ScanlineRevealPainter extends CustomPainter {
  const _ScanlineRevealPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..color = kNeon.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    final scanPaint = Paint()
      ..color = kText.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (double lineY = 0; lineY < y; lineY += 4) {
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), scanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlineRevealPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RevealCopy {
  const _RevealCopy({
    required this.className,
    required this.classColor,
    required this.focusTag,
    required this.flavor,
    required this.buttonLabel,
  });

  final String className;
  final Color classColor;
  final String focusTag;
  final String flavor;
  final String buttonLabel;

  factory _RevealCopy.forAnswers(PreClassAnswers answers) {
    final clazz = answers.clazz;
    final className = clazz.displayName;
    final focus = switch (clazz) {
      CharacterClass.assassin => 'SHOULDERS + CORE',
      CharacterClass.bruiser => 'CHEST + BACK + ARMS',
      CharacterClass.tank => 'WEIGHT AND STRENGTH',
    };
    final flavor = switch (clazz) {
      CharacterClass.assassin => 'speed. precision. low body fat.',
      CharacterClass.bruiser => 'balanced. relentless. iron build.',
      CharacterClass.tank => 'mass. force. immovable.',
    };
    return _RevealCopy(
      className: className,
      classColor: clazz.themeColor,
      focusTag: focus,
      flavor: flavor,
      buttonLabel: 'I AM $className',
    );
  }
}
