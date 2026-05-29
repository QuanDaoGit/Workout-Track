import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/body_goal_models.dart';
import '../../models/calibration_quiz_models.dart';
import '../../models/character_class.dart';
import '../../models/character_draft.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/class_sprite.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';
import 'avatar_select_screen.dart';

typedef ClassConfirmedCallback =
    Future<void> Function(CalibrationResult result, DateTime classConfirmedAt);

class ClassRevealScreen extends StatefulWidget {
  const ClassRevealScreen({
    super.key,
    required this.result,
    required this.onClassConfirmed,
  });

  final CalibrationResult result;
  final ClassConfirmedCallback onClassConfirmed;

  @override
  State<ClassRevealScreen> createState() => _ClassRevealScreenState();
}

class _ClassRevealScreenState extends State<ClassRevealScreen>
    with SingleTickerProviderStateMixin {
  static const _headerText = 'ANALYZING RECRUIT';
  static const _charMs = 30;

  late final _RevealCopy _copy;
  late final _RevealTimeline _timeline;
  late final AnimationController _controller;

  final List<Timer> _timers = [];
  bool _started = false;
  bool _complete = false;
  bool _committed = false;
  DateTime? _classConfirmedAt;
  String? _pendingAvatarId;
  int _shakeTrigger = 0;
  int _strobeTrigger = 0;

  bool get _validResult =>
      widget.result.clazz == deriveClass(widget.result.goal);

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _copy = _RevealCopy.forResult(widget.result);
    _timeline = _RevealTimeline(copy: _copy);
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
    if (!_validResult || _reduceMotion) {
      _complete = true;
      _controller.value = 1;
      if (!_validResult) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return;
    }

    _controller.forward(from: 0);
    _schedule(Duration(milliseconds: _timeline.strobeStart), () {
      setState(() => _strobeTrigger++);
    });
    _schedule(Duration(milliseconds: _timeline.shakeStart), () {
      setState(() => _shakeTrigger++);
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
    if (_complete || _currentMs >= _timeline.beat4Start) return;
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

  Future<void> _commit() async {
    if (_committed || !_buttonReady) return;
    setState(() => _committed = true);
    final classConfirmedAt = _classConfirmedAt ?? DateTime.now();
    _classConfirmedAt = classConfirmedAt;
    await widget.onClassConfirmed(widget.result, classConfirmedAt);
    if (!mounted) return;
    final draft = CharacterDraft(
      calibration: widget.result,
      classConfirmedAt: classConfirmedAt,
    );
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => AvatarSelectScreen(
          draft: draft,
          initialSelectedAvatarId: _pendingAvatarId,
          onPreviewChanged: (avatarId) => _pendingAvatarId = avatarId,
          onAvatarSelected: (_) async {},
        ),
      ),
    );
    if (mounted) setState(() => _committed = false);
  }

  bool get _buttonReady {
    if (_complete) return true;
    return _currentMs >= _timeline.buttonStart;
  }

  @override
  Widget build(BuildContext context) {
    if (!_validResult) return const Scaffold(backgroundColor: kBg);

    return AnimatedBuilder(
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
                  child: Column(
                    children: [
                      _TopBar(onBack: () => Navigator.of(context).pop()),
                      Expanded(child: _buildBody(ms)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(int ms) {
    final copy = _copy;
    final timeline = _timeline;
    final header = _typed(_headerText, ms, _RevealTimeline.beat1Start);
    final echoLine1 = _typed(copy.echoLine1, ms, timeline.echo1Start);
    final echoLine2 = copy.echoLine2 == null
        ? ''
        : _typed(copy.echoLine2!, ms, timeline.echo2Start);
    final analysisColor = Color.lerp(
      kNeon,
      kDim,
      _progress(ms, timeline.beat2Start, 200),
    )!;
    final echoColor = Color.lerp(
      kMutedText,
      kDim,
      _progress(ms, timeline.beat2Start, 200),
    )!;
    final classColor = _classNameColor(ms, copy.classColor);
    final flavor = _typed(copy.flavor, ms, timeline.flavorStart);
    final buttonOpacity = _progress(ms, timeline.buttonStart, 200);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Semantics(
            header: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  header,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    height: 1.4,
                  ).copyWith(color: analysisColor),
                ),
                if (!_complete && ms < timeline.beat2Start && header.isNotEmpty)
                  _BlinkingColon(color: analysisColor),
              ],
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            echoLine1,
            style: AppFonts.shareTechMono(
              color: echoColor,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (copy.echoLine2 != null)
            Text(
              echoLine2,
              style: AppFonts.shareTechMono(
                color: echoColor,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          const SizedBox(height: kSpace5),
          if (ms >= timeline.beat2Start) ...[
            const Divider(color: kBorder, height: 1, thickness: 1),
            const SizedBox(height: kSpace5),
            _BeatFlashText(visible: true, text: copy.pathLine, color: kNeon),
          ],
          const SizedBox(height: kSpace5),
          if (ms >= timeline.beat3Start)
            const Text(
              'CLASS:',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: kNeon,
                height: 1.35,
              ),
            ),
          if (ms >= timeline.classNameStart) ...[
            const SizedBox(height: kSpace3),
            Semantics(
              header: true,
              child: Text(
                copy.className,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 28,
                  color: classColor,
                  height: 1.2,
                ),
              ),
            ),
          ],
          Expanded(
            child: Center(
              child: Opacity(
                opacity: _complete
                    ? 1
                    : _progress(ms, _timeline.beat4Start, 120),
                child: _buildIdentity(ms, copy, flavor),
              ),
            ),
          ),
          if (buttonOpacity > 0 || _complete) ...[
            Opacity(
              opacity: _complete ? 1 : buttonOpacity,
              child: PixelButton(
                label: copy.buttonLabel,
                color: copy.classColor,
                minHeight: 56,
                fontSize: 14,
                onPressed: _buttonReady && !_committed ? _commit : null,
              ),
            ),
            const SizedBox(height: kSpace5),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentity(int ms, _RevealCopy copy, String flavor) {
    final iconProgress = _complete
        ? 1.0
        : _progress(ms, _timeline.beat4Start, 300);
    final focusOpacity = _complete
        ? 1.0
        : _progress(ms, _timeline.focusStart, 200);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScanlineReveal(
          progress: iconProgress,
          child: ClassSprite(
            assetPath: 'assets/classes/icons/${widget.result.clazz.name}.png',
            placeholderTint: copy.classColor,
            size: 64,
            placeholderLabel: copy.className,
          ),
        ),
        const SizedBox(height: kSpace4),
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
        Text(
          flavor,
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _typed(String text, int ms, int startMs) {
    if (_complete || _reduceMotion) return text;
    final count = ((ms - startMs) / _charMs).floor().clamp(0, text.length);
    return text.substring(0, count);
  }

  Color _classNameColor(int ms, Color identityColor) {
    if (_complete || _reduceMotion) return identityColor;
    if (ms < _timeline.classSettleStart) return kAmber;
    return Color.lerp(
      kAmber,
      identityColor,
      _progress(ms, _timeline.classSettleStart, 400),
    )!;
  }

  double _progress(int ms, int start, int duration) {
    if (_complete || _reduceMotion) return 1;
    return ((ms - start) / duration).clamp(0.0, 1.0).toDouble();
  }
}

class _RevealTimeline {
  _RevealTimeline({required _RevealCopy copy})
    : echo1Start = beat1Start + _headerText.length * charMs + inputLineGap,
      echo2Start =
          beat1Start +
          _headerText.length * charMs +
          inputLineGap +
          copy.echoLine1.length * charMs +
          inputLineGap,
      analysisDone = copy.echoLine2 == null
          ? beat1Start +
                _headerText.length * charMs +
                inputLineGap +
                copy.echoLine1.length * charMs
          : beat1Start +
                _headerText.length * charMs +
                inputLineGap +
                copy.echoLine1.length * charMs +
                inputLineGap +
                copy.echoLine2!.length * charMs {
    beat2Start = analysisDone + analysisSettle;
    beat3Start = beat2Start + 800;
    strobeStart = beat3Start + 200;
    shakeStart = beat3Start + 280;
    classNameStart = beat3Start + 320;
    classSettleStart = beat3Start + 800;
    beat4Start = beat3Start + 1200;
    focusStart = beat4Start + 150;
    flavorStart = beat4Start + 400;
    buttonStart = flavorStart + copy.flavor.length * charMs;
    totalMs = buttonStart + 220;
  }

  static const beat1Start = 450;
  static const charMs = _ClassRevealScreenState._charMs;
  static const inputLineGap = 150;
  static const analysisSettle = 200;
  static const _headerText = _ClassRevealScreenState._headerText;

  final int echo1Start;
  final int echo2Start;
  final int analysisDone;

  late final int beat2Start;
  late final int beat3Start;
  late final int strobeStart;
  late final int shakeStart;
  late final int classNameStart;
  late final int classSettleStart;
  late final int beat4Start;
  late final int focusStart;
  late final int flavorStart;
  late final int buttonStart;
  late final int totalMs;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Semantics(
            button: true,
            label: 'Back',
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.chevron_left_sharp,
                color: kNeon,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingColon extends StatefulWidget {
  const _BlinkingColon({required this.color});

  final Color color;

  @override
  State<_BlinkingColon> createState() => _BlinkingColonState();
}

class _BlinkingColonState extends State<_BlinkingColon> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 320), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _visible ? 1 : 0,
      child: Text(
        ':',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: widget.color,
          height: 1.4,
        ),
      ),
    );
  }
}

class _BeatFlashText extends StatelessWidget {
  const _BeatFlashText({
    required this.visible,
    required this.text,
    required this.color,
  });

  final bool visible;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return StrobeFlash(
      trigger: text,
      fireOnMount: true,
      color: color,
      opacity: 0.2,
      toggles: 1,
      toggleMs: 80,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: color,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ScanlineReveal extends StatelessWidget {
  const _ScanlineReveal({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 64,
      height: 64,
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
    required this.pathLine,
    required this.className,
    required this.classColor,
    required this.focusTag,
    required this.flavor,
    required this.buttonLabel,
    required this.echoLine1,
    required this.echoLine2,
  });

  final String pathLine;
  final String className;
  final Color classColor;
  final String focusTag;
  final String flavor;
  final String buttonLabel;
  final String echoLine1;
  final String? echoLine2;

  factory _RevealCopy.forResult(CalibrationResult result) {
    final className = result.clazz.displayName;
    final color = switch (result.clazz) {
      CharacterClass.assassin => kCyan,
      CharacterClass.bruiser => kAmber,
      CharacterClass.tank => kDanger,
      CharacterClass.vanguard => const Color(0xFFB14DFF),
    };
    final focus = switch (result.clazz) {
      CharacterClass.assassin => 'SHOULDERS + CORE',
      CharacterClass.bruiser => 'CHEST + BACK + ARMS',
      CharacterClass.tank => 'LEGS',
      CharacterClass.vanguard => 'ALL-ROUND',
    };
    final flavor = switch (result.clazz) {
      CharacterClass.assassin => 'speed. precision. low body fat.',
      CharacterClass.bruiser => 'balanced. relentless. iron build.',
      CharacterClass.tank => 'mass. force. immovable.',
      CharacterClass.vanguard => 'every front. no weakness.',
    };
    final bodyweight = result.bodyWeightKg;
    return _RevealCopy(
      pathLine: 'PATH OF THE ${_pathLabel(result.goal)}',
      className: className,
      classColor: color,
      focusTag: focus,
      flavor: flavor,
      buttonLabel: 'I AM $className',
      echoLine1:
          'goal ${_goalLabel(result.goal)} \u00B7 days ${_freqLabel(result.freq)} \u00B7 level ${result.exp.name}',
      echoLine2: bodyweight == null
          ? null
          : 'weight ${_weightLabel(bodyweight)}kg',
    );
  }

  static String _freqLabel(TrainingFreq freq) => switch (freq) {
    TrainingFreq.low => '2-3',
    TrainingFreq.mid => '4-5',
    TrainingFreq.high => '6+',
  };

  static String _goalLabel(BodyGoal goal) => switch (goal) {
    BodyGoal.cut => 'leaner',
    BodyGoal.recomp => 'recomp',
    BodyGoal.bulk => 'bigger',
  };

  static String _pathLabel(BodyGoal goal) => switch (goal) {
    BodyGoal.cut => 'CUT',
    BodyGoal.recomp => 'RECOMP',
    BodyGoal.bulk => 'BULK',
  };

  static String _weightLabel(double weight) {
    if (weight == weight.roundToDouble()) return weight.round().toString();
    return weight.toStringAsFixed(1);
  }
}
