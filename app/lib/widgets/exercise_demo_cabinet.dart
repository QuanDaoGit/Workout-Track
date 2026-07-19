import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/exercise_demos.dart';
import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../services/ui_sound.dart';
import '../services/workout_defaults_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_filled.dart';
import 'arcade_route.dart';
import 'arcade_tap.dart';
import 'exercise_demo_player.dart';

/// A neon-framed "demo cabinet" that shows an exercise's looping form demo.
///
/// Opens PAUSED (the poster/first frame under a ▶ glyph) so the clip never
/// starts moving the instant you open a lift mid-workout — tap the stage or the
/// strip play button to start it. Used on the large surfaces (set-logging
/// screen). The strip's `LOOP ⤢`
/// opens a fullscreen viewer sharing this cabinet's controller; HIDE collapses
/// the cabinet to the strip (pausing playback) and the choice persists
/// app-wide. Exercises without a demo never build this — callers fall back to
/// the static catalog photo.
class ExerciseDemoCabinet extends StatefulWidget {
  const ExerciseDemoCabinet({
    super.key,
    required this.demo,
    required this.exerciseName,
    this.height = 200,
  });

  final ExerciseDemo demo;
  final String exerciseName;
  final double height;

  @override
  State<ExerciseDemoCabinet> createState() => _ExerciseDemoCabinetState();
}

class _ExerciseDemoCabinetState extends State<ExerciseDemoCabinet> {
  late final VideoPlayerController _controller;

  /// null until the persisted preference loads; the stage shows the static
  /// poster meanwhile so an unhide choice never flashes a playing clip.
  bool? _hidden;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.demo.video);
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    final hidden = await WorkoutDefaultsService().getExerciseDemoHidden();
    if (!mounted) return;
    setState(() => _hidden = hidden);
  }

  void _toggleHidden() {
    final next = !(_hidden ?? false);
    setState(() => _hidden = next);
    if (next) _controller.pause();
    WorkoutDefaultsService().setExerciseDemoHidden(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Hands playback to the fullscreen viewer (which owns its own controller —
  /// never two `VideoPlayer`s on one controller), then resumes on return.
  Future<void> _openFullscreen() async {
    final wasPlaying = _controller.value.isPlaying;
    final position = _controller.value.position;
    if (wasPlaying) await _controller.pause();
    if (!mounted) return;
    await openExerciseDemoFullscreen(
      context,
      demo: widget.demo,
      exerciseName: widget.exerciseName,
      startAt: position,
    );
    if (mounted && wasPlaying) await _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _hidden ?? false;
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kNeon, width: 1.4),
        boxShadow: neonGlow(opacity: 0.16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DemoLabelStrip(
              hidden: hidden,
              controller: _controller,
              onToggleHidden: _toggleHidden,
              onFullscreen: hidden ? null : _openFullscreen,
            ),
            AnimatedSize(
              duration: kMotionBase,
              curve: kMotionCurve,
              alignment: Alignment.topCenter,
              child: hidden
                  ? const SizedBox(width: double.infinity)
                  : SizedBox(
                      height: widget.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: kBg),
                          if (_hidden == null)
                            Image.asset(
                              widget.demo.poster,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: kBg),
                            )
                          else
                            ExerciseDemoPlayer(
                              demo: widget.demo,
                              controller: _controller,
                              // Opens PAUSED mid-workout: the clip is a glance-
                              // when-you-need-it reference, not something that
                              // should start moving the instant you open a lift.
                              // The poster/first frame shows with a ▶ glyph;
                              // tap the stage or the strip button to play.
                              autoPlay: false,
                            ),
                          const IgnorePointer(
                            child: CustomPaint(painter: _CornerTicksPainter()),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `▸ FORM DEMO … ⏸/▶ LOOP ⤢ | HIDE` strip across the top of the cabinet.
class _DemoLabelStrip extends StatelessWidget {
  const _DemoLabelStrip({
    required this.hidden,
    required this.controller,
    required this.onToggleHidden,
    this.onFullscreen,
  });

  final bool hidden;
  final VideoPlayerController controller;
  final VoidCallback onToggleHidden;
  final VoidCallback? onFullscreen;

  void _togglePlay() {
    final value = controller.value;
    if (!value.isInitialized) return;
    if (value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCard,
      padding: const EdgeInsets.only(left: 10, right: 4, top: 2, bottom: 2),
      child: Row(
        children: [
          const _BlinkingDot(),
          const SizedBox(width: 7),
          const Text(
            'FORM DEMO',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: kNeon,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (!hidden)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => _StripButton(
                onTap: _togglePlay,
                child: Icon(
                  value.isPlaying
                      ? Icons.pause_sharp
                      : Icons.play_arrow_sharp,
                  size: 15,
                  color: kMutedText,
                ),
              ),
            ),
          if (onFullscreen != null)
            _StripButton(
              onTap: onFullscreen!,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LOOP',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const ImageIcon(
                    AssetImage('assets/icons/control/icon_expand.png'),
                    color: kMutedText,
                    size: 13,
                  ),
                ],
              ),
            ),
          _StripButton(
            onTap: onToggleHidden,
            child: Text(
              hidden ? 'SHOW' : 'HIDE',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kMutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small padded tap target inside the strip.
class _StripButton extends StatelessWidget {
  const _StripButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ArcadeTap(
      onTap: onTap,
      haptic: HapticIntent.selection,
      sound: UiSound.tick,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: child,
      ),
    );
  }
}

/// A compact `● FORM DEMO` pill, overlaid on the detail-page hero.
class FormDemoTag extends StatelessWidget {
  const FormDemoTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kNeon, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkingDot(),
          SizedBox(width: 6),
          Text(
            'FORM DEMO',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kNeon,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: kNeon, shape: BoxShape.circle),
      ),
    );
  }
}

class _CornerTicksPainter extends CustomPainter {
  const _CornerTicksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 12.0;
    const inset = 5.0;
    final paint = Paint()
      ..color = kNeon.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), paint);
    }

    corner(inset, inset, 1, 1);
    corner(size.width - inset, inset, -1, 1);
    corner(inset, size.height - inset, 1, -1);
    corner(size.width - inset, size.height - inset, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _CornerTicksPainter oldDelegate) => false;
}

/// Pushes a fullscreen viewer for [demo]. The viewer creates and owns its own
/// controller (one `VideoPlayerController` ↔ one mounted `VideoPlayer` —
/// sharing across routes desyncs ExoPlayer when a surface goes offstage);
/// callers pause their own player first and resume when the returned future
/// completes. Tap the clip to pause/play; tap the backdrop or the ✕ to
/// dismiss.
Future<void> openExerciseDemoFullscreen(
  BuildContext context, {
  required ExerciseDemo demo,
  required String exerciseName,
  Duration startAt = Duration.zero,
}) {
  return Navigator.of(context).push(
    arcadeRoute(
      (_) => _ExerciseDemoFullscreen(
        demo: demo,
        exerciseName: exerciseName,
        startAt: startAt,
      ),
      motion: ArcadeRouteMotion.fade,
    ),
  );
}

class _ExerciseDemoFullscreen extends StatefulWidget {
  const _ExerciseDemoFullscreen({
    required this.demo,
    required this.exerciseName,
    required this.startAt,
  });

  final ExerciseDemo demo;
  final String exerciseName;
  final Duration startAt;

  @override
  State<_ExerciseDemoFullscreen> createState() =>
      _ExerciseDemoFullscreenState();
}

class _ExerciseDemoFullscreenState extends State<_ExerciseDemoFullscreen> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.asset(widget.demo.video);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      body: Stack(
        children: [
          // Backdrop: tapping anywhere outside the clip dismisses.
          // haptic-ok: full-bleed backdrop dismiss; feedback fired inline.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticService.instance.fireCoalesced(HapticIntent.selection);
                SfxService.instance.playUi(UiSound.tick);
                Navigator.of(context).maybePop();
              },
            ),
          ),
          // The clip, sized to its own aspect ratio so backdrop taps around it
          // still dismiss; tapping the clip itself toggles pause/play.
          Center(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) => AspectRatio(
                aspectRatio: value.isInitialized ? value.aspectRatio : 16 / 9,
                child: child,
              ),
              child: ExerciseDemoPlayer(
                demo: widget.demo,
                controller: controller,
                startAt: widget.startAt,
              ),
            ),
          ),
          Positioned(
            left: kSpace4,
            right: kSpace4,
            bottom: kSpace5,
            child: Row(
              children: [
                const FormDemoTag(),
                const SizedBox(width: kSpace2),
                Flexible(
                  child: Text(
                    widget.exerciseName,
                    style: AppFonts.shareTechMono(color: kText, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + kSpace2,
            right: kSpace3,
            child: ArcadeIconButton(
              icon: const Icon(Icons.close_sharp, color: kText, size: 28),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
