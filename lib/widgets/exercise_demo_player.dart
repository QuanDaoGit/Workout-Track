import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/exercise_demos.dart';
import '../services/haptic_service.dart';
import '../theme/tokens.dart';

/// Plays an exercise's form-demo clip: muted, looping, tap toggles pause/play.
///
/// Chrome is play/pause only — paused shows a dim scrim + a pixel play glyph,
/// playing is chromeless. Renders the poster still until the controller is
/// initialized so there is never a black flash. Pauses when the app is
/// backgrounded and resumes (if it was playing) on return. Reduced-motion
/// users start paused regardless of [autoPlay].
///
/// Pass [controller] when the caller needs to share playback with another
/// surface (the cabinet hands its controller to the fullscreen viewer); the
/// caller then owns disposal. With no [controller] the player creates and
/// disposes its own.
class ExerciseDemoPlayer extends StatefulWidget {
  const ExerciseDemoPlayer({
    super.key,
    required this.demo,
    this.controller,
    this.fit = BoxFit.contain,
    this.autoPlay = true,
    this.startAt = Duration.zero,
  });

  final ExerciseDemo demo;
  final VideoPlayerController? controller;
  final BoxFit fit;
  final bool autoPlay;

  /// Initial playback position, applied once on first initialization (the
  /// fullscreen viewer resumes from where the inline player was).
  final Duration startAt;

  @override
  State<ExerciseDemoPlayer> createState() => _ExerciseDemoPlayerState();
}

class _ExerciseDemoPlayerState extends State<ExerciseDemoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _ownController;
  bool _initStarted = false;
  bool _wasPlayingBeforeBackground = false;

  VideoPlayerController get _controller =>
      widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller == null) {
      _ownController = VideoPlayerController.asset(widget.demo.video);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initStarted) return;
    _initStarted = true;
    // Resolved here, not initState: reduced-motion needs MediaQuery.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Deferred: with an already-initialized external controller, _init would
    // otherwise call play() synchronously during build, notifying listeners
    // mid-build ("setState during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _init(autoPlay: widget.autoPlay && !reduceMotion);
    });
  }

  Future<void> _init({required bool autoPlay}) async {
    final controller = _controller;
    try {
      if (!controller.value.isInitialized) {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        if (widget.startAt > Duration.zero) {
          await controller.seekTo(widget.startAt);
        }
      }
      if (!mounted) return;
      if (autoPlay) await controller.play();
    } catch (e) {
      // Playback unavailable (stale build without the plugin, bad asset,
      // missing platform in tests) — the poster keeps rendering, which is the
      // correct degraded state. Log so a real device failure is diagnosable.
      debugPrint('ExerciseDemoPlayer: init failed for ${widget.demo.video}: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (!controller.value.isInitialized) return;
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforeBackground = controller.value.isPlaying;
      controller.pause();
    } else if (state == AppLifecycleState.resumed &&
        _wasPlayingBeforeBackground) {
      _wasPlayingBeforeBackground = false;
      controller.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ownController?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    final v = controller.value;
    debugPrint(
      'ExerciseDemoPlayer: tap — initialized=${v.isInitialized} '
      'playing=${v.isPlaying} completed=${v.isCompleted} '
      'looping=${v.isLooping} pos=${v.position}/${v.duration} '
      'error=${v.errorDescription}',
    );
    if (!v.isInitialized) return;
    // Coalesced so rapid play/pause taps can't machine-gun the motor.
    HapticService.instance.fireCoalesced(HapticIntent.selection);
    if (v.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          if (!value.isInitialized) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  widget.demo.poster,
                  fit: widget.fit,
                  errorBuilder: (_, _, _) => const ColoredBox(color: kBg),
                ),
                if (!widget.autoPlay) const _PlayGlyph(),
              ],
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: value.size.width,
                  height: value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
              // The native video surface consumes touches before Flutter's
              // gesture system sees them; this transparent layer reclaims
              // taps landing on the picture for the enclosing detector.
              const ColoredBox(color: Colors.transparent),
              if (!value.isPlaying) ...[
                ColoredBox(color: kBg.withValues(alpha: 0.45)),
                const _PlayGlyph(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kBg.withValues(alpha: 0.6),
          border: Border.all(color: kNeon, width: 1.4),
          borderRadius: BorderRadius.circular(4),
          boxShadow: neonGlow(opacity: 0.18),
        ),
        child: const Icon(Icons.play_arrow_sharp, color: kNeon, size: 26),
      ),
    );
  }
}
