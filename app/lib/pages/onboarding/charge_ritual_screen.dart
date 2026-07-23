import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../../models/avatar_spec.dart';
import '../../models/character.dart';
import '../../services/haptic_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_bar.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/arcade_tap.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';
import '../../widgets/motion/crt_overlay.dart';
import '../../widgets/pixel_button.dart';
import 'charge_ritual_engine.dart';
import 'start_gate_screen.dart';

const String _kReelAsset = 'assets/onboarding/charge_ritual_reel.mp4';
const String _kPosterAsset = 'assets/onboarding/charge_ritual_reel_poster.webp';

/// The **Charge Ritual** — a once-only first-run screen between the reminders
/// primer and the Start Gate. A ~15s motivational reel is revealed with a CRT
/// power-on (screen turns on → held frame → eases into motion), auto-charges a
/// console meter to 90%, then the user press-**holds** to pour the final 10%;
/// at 100% a pixel ignition fires a cinematic transition into the character
/// reveal. The reel's END recedes gracefully into the HOLD prompt (peak-end),
/// rather than snapping. Tap the reel to pause; a single tap ("BIT pours it")
/// is the accessible path; a delayed skip proceeds without charging.
class ChargeRitualScreen extends StatefulWidget {
  const ChargeRitualScreen({
    super.key,
    required this.character,
    this.avatarSpec = AvatarSpec.fallback,
  });

  final Character character;
  final AvatarSpec avatarSpec;

  @override
  State<ChargeRitualScreen> createState() => _ChargeRitualScreenState();
}

class _ChargeRitualScreenState extends State<ChargeRitualScreen>
    with TickerProviderStateMixin {
  // ── entry/exit choreography (fractions of the controllers below) ────────────
  static const int _entryMs = 1200;
  static const int _exitMs = 1400;
  static const double _beatA = 0.30; // power-on ends
  static const double _beatC = 0.72; // ease-in starts; play()+beginReel() here
  static const double _dimBrightness = 0.30; // held-frame dim level
  static const double _audioTailMs = 550; // reel-end audio fade window
  // BIT dialogue timing (post-reel thank-you → boost dwell)
  static const double _kHoldThankYouMs =
      3800; // thank-you dwell: type-out (~0.7s) + ~3s read → boost cue (tap skips)
  // Held-frame BIT intro: line 1 on entry, line 2 after this dwell (self-paced —
  // both live on the START BOOSTING wait so nothing competes with the reel).
  static const int _kIntroLine2Ms = 3200;
  // NOTE (deviation from the plan's Step 3, which bundles this Phase A constant
  // with two Phase-B-only ones, `_kChromeDimFloor`/`_kReelDimRampMs`): this
  // session implements Phase A only (Task A1/A2), so those two are deferred to
  // Phase B's own task — adding them here now would be unused (analyze warning).
  // exit sub-ranges
  static const double _exFreeze = 0.14; // hold the final frame
  static const double _exRecedeEnd = 0.60; // picture -> scrim done
  static const double _exPromptStart = 0.74; // prompt eases in

  late final ChargeRitualEngine _engine;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsedMs = 0; // wall-clock (pausable) — drives the held-frame dwell
  double _animClock = 0; // seconds (pausable) — ambient pour/pulse sines

  VideoPlayerController? _video;
  bool _muted = false;
  bool _playStarted = false; // guards the one-shot play()+beginReel()
  bool _exitStarted = false;
  double _lastVolume = -1; // throttle setVolume() calls
  double?
  _holdStartMs; // pausable wall-clock ms stamped when the hold gate lands
  double? _reelStartMs; // pausable clock stamped when the reel phase begins
  bool _heldFrameReached = false; // latched once the START BOOSTING gate is shown
  bool _boostCued =
      false; // latched once the boost cue / pour begins (never un-cues)
  bool _thankYouSkipped = false; // tap-to-skip the thank-you read dwell

  final ValueNotifier<int> _pump = ValueNotifier<int>(0);

  // Eager (initState) so a reduced-motion build that never forwards them can't
  // lazily construct a controller in dispose() (documented crash).
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _entryMs),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _exitMs),
  );
  // Full-screen CRT power-off collapse at ignition — the LONGER half of the
  // asymmetric power-cycle (the Start Gate's `powerOn` route is the shorter
  // half). Its own controller so no other effect inherits this timing.
  // Assigned in initState (NOT a `late final = …` initializer): the reduced-motion
  // path never reads it, so a lazy field would first construct in dispose() — the
  // deactivated-TickerMode crash. `_entry`/`_exit` are safe only because the
  // reduced-motion branch reads their `.value`.
  late final AnimationController _collapse;

  ChargeRitualPhase _prevPhase = ChargeRitualPhase.preroll;
  bool _routed = false;
  bool _deps = false;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    // Preroll is user-gated by the "START BOOSTING" press — disable the auto
    // watchdog (the always-available skip is the escape, so it can't soft-lock).
    _engine = ChargeRitualEngine(
      prerollMs: 600000,
      fillMs: 3000, // ~3s cinematic hold-to-charge (was 1.4s)
      autoFillMs: 3000, // the accessible tap path matches the 3s build
    );
    _collapse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deps) return;
    _deps = true;
    if (_reduceMotion) {
      // Reduced motion: no reel — 17s of video is motion the OS asked to avoid
      // (WCAG). Land on the still hold state; the charge/boost interaction (the
      // gift's core) remains, and the poster stands in for the clip.
      _engine
        ..reelMs = 1200
        ..finishReel();
      _entry.value = 1;
      _exit.value = 1;
      _exitStarted = true;
    } else {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_kReelAsset);
    _video = controller;
    controller.addListener(_onVideoTick);
    try {
      await controller.initialize();
      // The ritual may have been skipped/left while init was pending — the
      // controller and the animation controllers are then disposed, so touching
      // them (setLooping/_exit/_entry) would throw across the async gap.
      if (!mounted || _video != controller) return;
      await controller.setLooping(false);
      await controller.setVolume(
        0,
      ); // ramps up in Beat C; device volume governs
      if (!mounted || _video != controller) return;
      final dur = controller.value.duration;
      if (dur > Duration.zero) _engine.reelMs = dur.inMilliseconds.toDouble();
      // Power on + reveal the held (poster) frame, then STOP — the reel waits for
      // the user's "START BOOSTING" press (never autoplay).
      _entry.animateTo(_beatC);
    } catch (e) {
      // Playback unavailable (bad asset / no platform in tests) — the poster
      // renders and the watchdog advances the ritual so it can never soft-lock.
      debugPrint('ChargeRitual: video init failed: $e');
      if (!mounted || _video != controller) return;
      _engine.finishReel();
      _exit.value = 1;
      _exitStarted = true;
    }
    if (mounted) setState(() {});
  }

  // The user pressed "START BOOSTING" — begin playback + the reel clock as the
  // picture eases in (Beat C). One-shot; the held frame + delayed skip guard the
  // wait, so the preroll watchdog is intentionally disabled (see initState).
  void _startBoost() {
    if (_playStarted || _reduceMotion) return;
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    _playStarted = true;
    v.play();
    _engine.beginReel();
    _entry.forward(); // Beat C fade-in (from the held frame to full)
  }

  // Video listener — audio tail near the end; advance the gate on end/error.
  void _onVideoTick() {
    final v = _video;
    if (v == null) return;
    if (v.value.hasError) {
      _engine.finishReel();
      return;
    }
    if (!v.value.isInitialized) return;
    final dur = v.value.duration;
    if (dur > Duration.zero &&
        v.value.position >= dur - const Duration(milliseconds: 60)) {
      _engine.finishReel();
    }
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    if (!_engine.isPaused) {
      _elapsedMs += dtMs;
      _animClock += dtMs / 1000.0;
    }

    _engine.tick(dtMs);
    _applyVolume();
    final phase = _engine.phase;

    // First frame the hold gate is reached (reel end, failed preroll, or the
    // reduced-motion cold-open) — stamp the pausable clock so the post-reel BIT
    // dialogue advances thank-you → boost off a dwell, not the typewriter. A
    // standalone guard (not the _exitStarted edges below) so reduced motion,
    // where _exitStarted is already true, still captures it.
    if (phase == ChargeRitualPhase.hold && _holdStartMs == null) {
      _holdStartMs = _elapsedMs;
    }
    if (phase == ChargeRitualPhase.reel && _reelStartMs == null) {
      _reelStartMs = _elapsedMs;
    }
    // Latch the boost cue once the pour begins, so an early pour that drains
    // back to hold (hold ⇄ pouring) never regresses BIT to the thank-you line.
    if (phase == ChargeRitualPhase.pouring ||
        phase == ChargeRitualPhase.ignited) {
      _boostCued = true;
    }

    // Strong rising hold-boost buzz — fired ONCE as a pre-baked shaped envelope
    // when the pour begins. Re-issuing vibrate() every frame risks a stuttery
    // cancel/restart on Android, so we play one rising waveform and cut it the
    // instant the pour ends (release / ignite).
    if (phase == ChargeRitualPhase.pouring &&
        _prevPhase != ChargeRitualPhase.pouring) {
      HapticService.instance.boostSwell();
      SfxService.instance.playBoostCharge();
    } else if (phase != ChargeRitualPhase.pouring &&
        _prevPhase == ChargeRitualPhase.pouring) {
      HapticService.instance.stopBuzz();
      // Only a drain-back (pouring→hold) is a release; pouring→ignited plays the
      // ignite cue from _onIgnited instead.
      if (phase == ChargeRitualPhase.hold) {
        SfxService.instance.playBoostRelease();
      }
    }

    if (_prevPhase != phase) {
      if (phase == ChargeRitualPhase.hold &&
          _prevPhase == ChargeRitualPhase.reel &&
          !_exitStarted) {
        // Reel ended → the graceful settle (freeze → recede → prompt).
        _exitStarted = true;
        if (_reduceMotion) {
          _exit.value = 1;
        } else {
          _exit.forward();
          HapticService.instance.selection();
        }
      } else if (phase == ChargeRitualPhase.hold &&
          _prevPhase == ChargeRitualPhase.preroll &&
          !_exitStarted) {
        // Video failed before the reel — land on hold instantly (no reel to exit).
        _exit.value = 1;
        _exitStarted = true;
      }
    }

    if (phase == ChargeRitualPhase.ignited &&
        _prevPhase != ChargeRitualPhase.ignited) {
      _onIgnited();
    }

    _prevPhase = phase;
    _pump.value++;
  }

  // Volume ramps: up over Beat C (0->1), down over the reel's final window; 0
  // when muted / paused / not playing. Clamped to 0 before the hard asset end so
  // ExoPlayer quantization can't leave an end-slam. Throttled to real changes.
  void _applyVolume() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    double target;
    if (_muted || _engine.isPaused || !_playStarted) {
      target = 0;
    } else {
      final inFactor = ((_entry.value - _beatC) / (1 - _beatC)).clamp(0.0, 1.0);
      final dur = v.value.duration.inMilliseconds.toDouble();
      final pos = v.value.position.inMilliseconds.toDouble();
      final remain = dur - pos;
      final outFactor = (dur <= 0 || remain > _audioTailMs)
          ? 1.0
          : (remain / _audioTailMs).clamp(0.0, 1.0);
      target = inFactor * outFactor;
    }
    if ((target - _lastVolume).abs() > 0.02 ||
        (target == 0 && _lastVolume != 0)) {
      _lastVolume = target;
      v.setVolume(target);
    }
  }

  void _onIgnited() {
    // The charge climax — a firm stamp distinct from the rising hold buzz.
    HapticService.instance.stopBuzz();
    HapticService.instance.boostClimax();
    SfxService.instance.playBoostIgnite();
    _video?.pause();
    if (_reduceMotion) {
      _goToGate(ArcadeRouteMotion.fade);
    } else {
      _collapse.forward(from: 0).whenComplete(() {
        if (mounted) _goToGate(ArcadeRouteMotion.powerOn);
      });
    }
  }

  void _goToGate(ArcadeRouteMotion motion) {
    if (_routed || !mounted) return;
    _routed = true;
    _ticker?.stop();
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => StartGateScreen(
          character: widget.character,
          avatarSpec: widget.avatarSpec,
        ),
        motion: motion,
      ),
    );
  }

  // ── input ──────────────────────────────────────────────────────────────────
  void _keycapDown() {
    if (_engine.phase == ChargeRitualPhase.hold) {
      HapticService.instance.selection();
    }
    _engine.startHold();
  }

  void _keycapUp() {
    _engine.endHold();
    HapticService.instance.stopBuzz();
  }

  // Tap the BIT area during the post-reel thank-you read to skip its dwell and
  // jump to the boost cue (the "finish instantly when the user taps" path).
  void _skipThankYouRead() {
    if (_thankYouSkipped) return;
    setState(() => _thankYouSkipped = true);
    HapticService.instance.selection();
  }

  void _tapComplete() {
    HapticService.instance.tap();
    _engine.tapComplete();
  }

  void _skip() {
    HapticService.instance.selection();
    _goToGate(ArcadeRouteMotion.flow);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _applyVolume();
  }

  // Tap-to-pause — reel phase only; freezes the video + charge clock + skip timer
  // + ambient sines together (via _engine.isPaused), so nothing desyncs.
  void _togglePause() {
    if (_engine.phase != ChargeRitualPhase.reel) return;
    HapticService.instance.selection();
    if (_engine.isPaused) {
      _engine.resume();
      _video?.play();
    } else {
      _engine.pause();
      _video?.pause();
    }
  }

  @override
  void dispose() {
    HapticService.instance.stopBuzz();
    _ticker?.dispose();
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _entry.dispose();
    _exit.dispose();
    _collapse.dispose();
    _pump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.75),
                  radius: 1.3,
                  colors: [kBgGradientTop, kBg, kBgGradientBottom],
                  stops: [0, 0.55, 1],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(kSpace4),
                  child: LayoutBuilder(
                    builder: (context, constraints) => AnimatedBuilder(
                      animation: Listenable.merge([_pump, _entry, _exit]),
                      builder: (context, _) =>
                          _composition(constraints.maxHeight),
                    ),
                  ),
                ),
              ),
            ),
            // Full-screen CRT power-off collapse at ignition (the longer half of
            // the asymmetric power-cycle; the Start Gate powers on via the route).
            if (!_reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _collapse,
                    builder: (context, _) => _collapse.value <= 0
                        ? const SizedBox.shrink()
                        : CustomPaint(
                            painter: _PowerCyclePainter(_collapse.value),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composition(double availableHeight) {
    final phase = _engine.phase;
    final charge = _engine.charge;
    final reelDone =
        phase == ChargeRitualPhase.hold ||
        phase == ChargeRitualPhase.pouring ||
        phase == ChargeRitualPhase.ignited;
    final pouring = phase == ChargeRitualPhase.pouring;
    final ignited = phase == ChargeRitualPhase.ignited;
    final accent = (pouring || ignited) ? kNeon : kAmber;
    final reelPlaying = phase == ChargeRitualPhase.reel;

    // Entry: power-on (Beat A) + picture brightness (dim through B, ramps in C).
    final entryV = _reduceMotion ? 1.0 : _entry.value;
    final powerOn = (entryV / _beatA).clamp(0.0, 1.0);
    final entryBrightness = entryV >= _beatC
        ? _dimBrightness +
              (1 - _dimBrightness) * ((entryV - _beatC) / (1 - _beatC))
        : _dimBrightness;

    // Exit: recede scrim + staggered prompt reveal.
    final exitV = _reduceMotion ? (reelDone ? 1.0 : 0.0) : _exit.value;
    final exitFade = Curves.easeInOut.transform(
      ((exitV - _exFreeze) / (_exRecedeEnd - _exFreeze)).clamp(0.0, 1.0),
    );
    final promptReveal = Curves.easeOut.transform(
      ((exitV - _exPromptStart) / (1 - _exPromptStart)).clamp(0.0, 1.0),
    );

    // Held frame revealed + playback not yet started → the flickering "START
    // BOOSTING" gate (the reel plays only on this press).
    final boostReady =
        !_reduceMotion &&
        !_playStarted &&
        phase == ChargeRitualPhase.preroll &&
        entryV >= _beatC &&
        (_video?.value.isInitialized ?? false);
    if (boostReady) _heldFrameReached = true;

    // Skip is a whole-ritual escape, pre-armed with the held frame (Codex F2) —
    // reachable the moment the START BOOSTING gate is shown, never a raw timer
    // that could pop in mid-reel. Reduced motion has no held frame but lands
    // straight on `reelDone` (the still hold state).
    final skipVisible =
        !ignited && (_heldFrameReached || reelDone || _reduceMotion);

    // BIT is silent during the reel (Change A): the intro lines are relocated
    // to the self-paced held-frame wait (pre-reel), post-reel thank-you → boost
    // advances by a clock dwell. pouring/ignited keep priority (charge feedback).
    // [boost]/[BOOSTING] render amber + shaky.
    final holdElapsedMs = _elapsedMs - (_holdStartMs ?? _elapsedMs);
    // Boost cue = the dwell elapsed OR a pour has begun (latched) — so a release
    // back to hold before the dwell keeps the boost copy, never the thank-you.
    final boostCued =
        _boostCued || _thankYouSkipped || holdElapsedMs >= _kHoldThankYouMs;
    final bitHyped = ignited || pouring || (reelDone && boostCued);
    final heldElapsedMs = _elapsedMs; // pre-play clock (0 at mount, ticks in preroll)
    final introLine = heldElapsedMs < _kIntroLine2Ms
        ? 'say hi to our coach, jack mercer.'
        : "let's listen to his message together.";
    final bitLine = ignited
        ? "fully charged. let's keep moving."
        : pouring
        ? '[BOOSTING]'
        : reelDone
        ? (boostCued
              ? "alright warrior, let's [boost] this up and start strong."
              : 'thank you for the message, coach.')
        : introLine;

    return Semantics(
      label:
          'Charging your first session. Hold the button, or tap, to complete.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChargeHeader(charged: ignited),
          const SizedBox(height: kSpace3),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: availableHeight * 0.36),
              child: _ReelMonitor(
                video: _video,
                showVideo:
                    !_reduceMotion &&
                    _playStarted &&
                    (_video?.value.isInitialized ?? false),
                reduceMotion: _reduceMotion,
                powerOn: powerOn,
                brightness: entryBrightness,
                exitFade: exitFade,
                showHoldPrompt: reelDone && !ignited,
                promptReveal: _reduceMotion ? 1.0 : promptReveal,
                paused: _engine.isPaused,
                pausable: phase == ChargeRitualPhase.reel,
                onTapPause: _togglePause,
                muted: _muted,
                onToggleMute:
                    (!_reduceMotion && phase == ChargeRitualPhase.reel)
                    ? _toggleMute
                    : null,
              ),
            ),
          ),
          const SizedBox(height: kSpace4),
          // Custom skip-read hit-area (armed only during the thank-you dwell); fires
          // a selection tick in _skipThankYouRead. // haptic-ok: not a primary control
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: (reelDone && !boostCued) ? _skipThankYouRead : null,
            child: _PowerZone(
              charge: charge,
              accent: accent,
              pouring: pouring,
              reelDone: reelDone,
              clock: _animClock,
              reduceMotion: _reduceMotion,
              bitLine: bitLine,
              bitPose: bitHyped ? BitPose.cheer : BitPose.neutral,
              showBubble: !reelPlaying,
            ),
          ),
          const Spacer(),
          _ActionZone(
            phase: phase,
            boostReady: boostReady,
            onStartBoost: _startBoost,
            onDown: _keycapDown,
            onUp: _keycapUp,
            onTapComplete: _tapComplete,
          ),
          const SizedBox(height: kSpace3),
          SizedBox(
            height: 22,
            child: skipVisible
                ? _SkipLink(onTap: _skip)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── header ─────────────────────────────────────────────────────────────────
class _ChargeHeader extends StatelessWidget {
  const _ChargeHeader({required this.charged});

  final bool charged;

  @override
  Widget build(BuildContext context) {
    final color = charged ? kNeon : kAmber;
    return Semantics(
      label: charged ? 'Charged' : 'Charging',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 6, height: 6, color: color),
          const SizedBox(width: 8),
          Text(
            charged ? 'CHARGED' : 'CHARGING',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              letterSpacing: 1.5,
            ).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── reel monitor (video + phosphor grade + power-on + recede) ─────────────────
class _ReelMonitor extends StatelessWidget {
  const _ReelMonitor({
    required this.video,
    required this.showVideo,
    required this.reduceMotion,
    required this.powerOn,
    required this.brightness,
    required this.exitFade,
    required this.showHoldPrompt,
    required this.promptReveal,
    required this.paused,
    required this.pausable,
    required this.onTapPause,
    required this.muted,
    required this.onToggleMute,
  });

  final VideoPlayerController? video;
  final bool showVideo;
  final bool reduceMotion;
  final double powerOn; // 0..1 (Beat A; >=1 = done)
  final double brightness; // 0..1 picture brightness
  final double exitFade; // 0..1 recede scrim
  final bool showHoldPrompt;
  final double promptReveal; // 0..1
  final bool paused;
  final bool pausable;
  final VoidCallback onTapPause;
  final bool muted;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    final ar = showVideo
        ? video!.value.aspectRatio
        : 4 / 3; // matches the 4:3 reel
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          BoxShadow(color: kCyan.withValues(alpha: 0.10), blurRadius: 6),
        ],
      ),
      child: ClipRect(
        child: AspectRatio(
          aspectRatio: ar,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: kBlack),
              if (showVideo) VideoPlayer(video!) else _poster(),
              // Inner vignette — seats the picture in the screen.
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.05),
                      radius: 0.95,
                      colors: [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x66000000),
                      ],
                      stops: [0, 0.6, 1],
                    ),
                  ),
                ),
              ),
              const CrtScanlineOverlay(opacity: 0.5),
              // Entry dim: black wash that clears as the picture eases to full.
              if (brightness < 1)
                IgnorePointer(
                  child: ColoredBox(
                    color: kBlack.withValues(
                      alpha: (1 - brightness).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              // Beat A — CRT power-on (shutters open from a center scanline).
              if (!reduceMotion && powerOn < 1)
                IgnorePointer(
                  child: CustomPaint(painter: _MonitorPowerOnPainter(powerOn)),
                ),
              // Exit — the picture recedes into the scrim (the "exhale").
              if (exitFade > 0)
                IgnorePointer(
                  child: ColoredBox(
                    color: kBlack.withValues(
                      alpha: (0.85 * exitFade).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              // Tap-to-pause hit layer (reel only) — below the mute so its corner
              // tap doesn't bubble here.
              if (pausable)
                Positioned.fill(
                  child: ArcadeTap(
                    onTap: onTapPause,
                    flashOpacity: 0,
                    haptic: HapticIntent.none, // the handler owns the beat
                    child: const SizedBox.expand(),
                  ),
                ),
              if (paused)
                const IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.pause_sharp,
                      size: 34,
                      color: kText,
                      semanticLabel: 'Paused',
                    ),
                  ),
                ),
              if (showHoldPrompt)
                IgnorePointer(
                  child: Center(
                    child: _HoldPrompt(
                      reveal: promptReveal,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
              if (onToggleMute != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ArcadeTap(
                    onTap: onToggleMute,
                    haptic: HapticIntent.selection,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        muted ? Icons.volume_off_sharp : Icons.volume_up_sharp,
                        size: 18,
                        color: kMutedText,
                        semanticLabel: muted ? 'Unmute' : 'Mute',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poster() => Image.asset(
    _kPosterAsset,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const ColoredBox(color: kBlack),
  );
}

/// Beat A — the monitor "turns on": kBg shutters open from a bright center
/// scanline (a real CRT power-on), with a cyan phosphor edge glow that fades as
/// the band fills and an initial white beam flash. Reduced motion skips it.
class _MonitorPowerOnPainter extends CustomPainter {
  _MonitorPowerOnPainter(this.progress);
  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final h = size.height, w = size.width, cy = h / 2;
    final bandHalf = _lerp(1.5, h / 2, Curves.easeOutCubic.transform(p));
    final top = (cy - bandHalf).clamp(0.0, h);
    final bot = (cy + bandHalf).clamp(0.0, h);
    final bg = Paint()
      ..color = kBlack
      ..isAntiAlias = false;
    if (top > 0) canvas.drawRect(Rect.fromLTRB(0, 0, w, top), bg);
    if (bot < h) canvas.drawRect(Rect.fromLTRB(0, bot, w, h), bg);

    final edgeA = (1 - p) * 0.9;
    if (edgeA > 0.01 && bandHalf < h / 2) {
      final edge = Paint()
        ..color = kCyan.withValues(alpha: edgeA)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(Offset(0, top), Offset(w, top), edge);
      canvas.drawLine(Offset(0, bot), Offset(w, bot), edge);
    }
    if (p < 0.2) {
      final flash = (1 - p / 0.2) * 0.5;
      canvas.drawRect(
        Rect.fromLTRB(0, cy - 2, w, cy + 2),
        Paint()..color = kWhite.withValues(alpha: flash),
      );
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _MonitorPowerOnPainter old) =>
      old.progress != progress;
}

class _HoldPrompt extends StatelessWidget {
  const _HoldPrompt({required this.reveal, required this.reduceMotion});

  final double reveal; // 0..1 staggered ease-in
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      'HOLD TO CHARGE UP',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 10,
        letterSpacing: 1.5,
        color: kNeon,
        shadows: [Shadow(color: kBlack, offset: Offset(2, 2))],
      ),
    );
    if (reduceMotion) return text;
    // Author the prompt in as a beat: fade + a small scale, then a soft blink.
    final revealed = Opacity(
      opacity: reveal.clamp(0.0, 1.0),
      child: Transform.scale(scale: 0.96 + 0.04 * reveal, child: text),
    );
    return reveal >= 1 ? _SoftBlink(child: text) : revealed;
  }
}

class _SoftBlink extends StatefulWidget {
  const _SoftBlink({required this.child});
  final Widget child;

  @override
  State<_SoftBlink> createState() => _SoftBlinkState();
}

class _SoftBlinkState extends State<_SoftBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.55).animate(_c),
    child: widget.child,
  );
}

// ── power zone (bar + BIT + pour stream) ─────────────────────────────────────
class _PowerZone extends StatelessWidget {
  const _PowerZone({
    required this.charge,
    required this.accent,
    required this.pouring,
    required this.reelDone,
    required this.clock,
    required this.reduceMotion,
    required this.bitLine,
    required this.bitPose,
    required this.showBubble,
  });

  final double charge;
  final Color accent;
  final bool pouring;
  final bool reelDone;
  final double clock;
  final bool reduceMotion;
  final String bitLine;
  final BitPose bitPose;
  final bool showBubble;

  @override
  Widget build(BuildContext context) {
    final pulse = (reelDone && !reduceMotion)
        ? 0.5 + 0.5 * math.sin(clock * (pouring ? 6.0 : 3.0))
        : 0.0;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: reelDone
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18 + 0.16 * pulse),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: ArcadeBar(value: charge, height: 16, accent: accent),
        ),
        const SizedBox(height: kSpace4),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            if (pouring && !reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _PourStreamPainter(clock)),
                ),
              ),
            Column(
              children: [
                Semantics(
                  excludeSemantics: true,
                  child: SizedBox(
                    height: 84,
                    child: pouring && !reduceMotion
                        ? _GlowWrap(child: _bit())
                        : _bit(),
                  ),
                ),
                const SizedBox(height: kSpace2),
                SizedBox(
                  height: 40, // reserve the bubble's line box so BIT doesn't jump
                  child: showBubble
                      ? BitSpeechBubble(
                          key: ValueKey(bitLine),
                          text: bitLine,
                          tailDirection: BitTailDirection.none,
                          typewriter: !reduceMotion,
                          fontSize: 12,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _bit() => BitMoodCore(pose: bitPose, reveal: 1, size: 84);
}

class _GlowWrap extends StatelessWidget {
  const _GlowWrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      boxShadow: neonGlow(color: kNeon, opacity: 0.28, blur: 14),
    ),
    child: child,
  );
}

class _PourStreamPainter extends CustomPainter {
  _PourStreamPainter(this.clock);
  final double clock;

  static const int _count = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < _count; i++) {
      final speed = 1.4 + (i % 3) * 0.28;
      final offset = (i * 0.137) % 1.0;
      final t = (clock * speed + offset) % 1.0;
      final y = size.height * (0.62 - 0.60 * t);
      final xJitter = (i % 4) * 0.03 + (i.isEven ? 0.0 : 0.02);
      final x = size.width * (0.44 + xJitter);
      final a = (math.sin(t * math.pi)).clamp(0.0, 1.0);
      if (a <= 0.02) continue;
      final sz = 4.0 + (i % 2) * 2.0;
      paint.color = (i % 3 == 2 ? const Color(0xFF7FFFCD) : kNeon).withValues(
        alpha: a,
      );
      canvas.drawRect(Rect.fromLTWH(x, y, sz, sz), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PourStreamPainter old) => old.clock != clock;
}

// ── action zone (hold keycap + always-visible tap + ignition burst) ──────────
class _ActionZone extends StatelessWidget {
  const _ActionZone({
    required this.phase,
    required this.boostReady,
    required this.onStartBoost,
    required this.onDown,
    required this.onUp,
    required this.onTapComplete,
  });

  final ChargeRitualPhase phase;
  final bool boostReady;
  final VoidCallback onStartBoost;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onTapComplete;

  @override
  Widget build(BuildContext context) {
    if (boostReady) {
      return _StartBoostButton(onPressed: onStartBoost);
    }
    if (phase == ChargeRitualPhase.ignited) {
      // The full-screen power-cycle collapse overlay owns the ignition visual
      // now; keep the zone's height so the layout doesn't jump under it.
      return const SizedBox(height: 84);
    }

    // Gate opens only once the reel is done (hold/pouring) — disabled through
    // the preroll cinematic + the reel.
    final ready =
        phase == ChargeRitualPhase.hold || phase == ChargeRitualPhase.pouring;
    return Column(
      children: [
        _HoldKeycap(enabled: ready, onDown: onDown, onUp: onUp),
        const SizedBox(height: kSpace2),
        Opacity(
          opacity: ready ? 1 : 0,
          child: Semantics(
            button: true,
            enabled: ready,
            label: 'Tap to charge up — BIT pours it for you',
            child: ArcadeTap(
              onTap: ready ? onTapComplete : null,
              haptic: HapticIntent.tap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'or tap — BIT pours it',
                  textAlign: TextAlign.center,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The reel's start gate: a chunky neon "START BOOSTING" keycap that slowly
/// breathes (a "press me" cue). Pressing it begins the reel (Beat C fade-in).
class _StartBoostButton extends StatefulWidget {
  const _StartBoostButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_StartBoostButton> createState() => _StartBoostButtonState();
}

class _StartBoostButtonState extends State<_StartBoostButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = MediaQuery.of(context);
    final reduce = m.disableAnimations || m.accessibleNavigation;
    if (reduce) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: neonGlow(
            color: kNeon,
            opacity: 0.18 + 0.34 * _pulse.value,
            blur: 14 + 10 * _pulse.value,
          ),
        ),
        child: PixelButton(
          label: 'START BOOSTING',
          minHeight: 56,
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

class _HoldKeycap extends StatefulWidget {
  const _HoldKeycap({
    required this.enabled,
    required this.onDown,
    required this.onUp,
  });

  final bool enabled;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<_HoldKeycap> createState() => _HoldKeycapState();
}

class _HoldKeycapState extends State<_HoldKeycap>
    with SingleTickerProviderStateMixin {
  bool _held = false;
  // A slow breathing halo (glow only, never the geometry — doctrine forbids a
  // scale-pulse) that lures the press while the keycap is armed. Created eagerly
  // in initState so a dispose-before-first-build can't lazy-create it mid-teardown.
  late final AnimationController _pulse;

  bool get _reduce {
    final m = MediaQuery.of(context);
    return m.disableAnimations || m.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse(); // _reduce reads MediaQuery
  }

  @override
  void didUpdateWidget(covariant _HoldKeycap old) {
    super.didUpdateWidget(old);
    _syncPulse(); // `enabled` flips via prop → no didChangeDependencies
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // Breathe only while armed, at rest, and motion is allowed; otherwise sit at a
  // steady base glow (a still, legible "ready" signal under reduced motion).
  void _syncPulse() {
    if (widget.enabled && !_reduce && !_held) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _down() {
    if (!widget.enabled) return;
    setState(() => _held = true);
    _syncPulse();
    widget.onDown();
  }

  void _up() {
    if (!_held) return;
    setState(() => _held = false);
    _syncPulse();
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final enabled = widget.enabled;
        final label = enabled ? 'HOLD TO CHARGE UP' : 'BIT IS CHARGING YOU…';
        final held = _held && !_reduce;
        final glow = held
            ? neonGlow(color: kNeon, opacity: 0.75, blur: 20)
            : enabled
            ? neonGlow(
                color: kNeon,
                opacity: 0.18 + 0.34 * _pulse.value,
                blur: 14 + 10 * _pulse.value,
              )
            : null;
        return Semantics(
          button: true,
          enabled: enabled,
          label: 'Hold to charge up',
          child: Listener(
            // haptic-ok: sustained press-and-hold charge gesture (not a tap); the
            // pour-start tick fires in the parent's _keycapDown.
            onPointerDown: enabled ? (_) => _down() : null,
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: AnimatedContainer(
              duration: kMotionFast,
              curve: kMotionCurve,
              height: 48,
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, held ? 2 : 0, 0),
              decoration: BoxDecoration(
                color: enabled ? kNeon : kBorderDark,
                borderRadius: BorderRadius.circular(kCardRadius),
                border: Border(
                  bottom: BorderSide(
                    color: kBlack.withValues(alpha: enabled ? 0.35 : 0.25),
                    width: held ? 1 : 3,
                  ),
                ),
                boxShadow: glow,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: enabled ? kBg : kDim,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The full-screen CRT power-off collapse at ignition (`p`: 0→1 over ~700ms):
/// an overload flash (amber→white) → the picture darkens to near-black while a
/// bright phosphor band squashes vertically to a line → the line contracts
/// horizontally to a dot → the dot winks out. Ends at near-black (`kBg`) so the
/// handoff to the Start Gate's `powerOn` route is dark-to-dark (no flash). Only
/// painted under full motion (the reduced path routes with a plain fade).
class _PowerCyclePainter extends CustomPainter {
  const _PowerCyclePainter(this.p);
  final double p; // 0..1

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h / 2);
    final paint = Paint()..isAntiAlias = false;

    // 1 · overload flash (amber → white), a quick pulse at the very start.
    final flash = p < 0.06 ? p / 0.06 : (1 - (p - 0.06) / 0.10).clamp(0.0, 1.0);
    if (flash > 0) {
      final c = Color.lerp(kAmber, kText, (p / 0.16).clamp(0.0, 1.0))!;
      canvas.drawRect(
        Offset.zero & size,
        paint..color = c.withValues(alpha: flash * 0.9),
      );
    }

    // 2 · scrim: the picture darkens to near-black as it collapses.
    final scrim = ((p - 0.12) / 0.4).clamp(0.0, 1.0);
    if (scrim > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kBg.withValues(alpha: scrim),
      );
    }

    // 3 · the bright collapsing phosphor: full band → thin line → dot → wink.
    if (p >= 0.12) {
      double bandH, bandW, glow;
      if (p < 0.55) {
        final t = Curves.easeIn.transform((p - 0.12) / 0.43);
        bandH = _lerp(h, 3, t);
        bandW = w;
        // A dim wash while wide → concentrates to a bright line as it collapses
        // (avoids a full-screen bright flash early on).
        glow = _lerp(0.12, 1.0, t);
      } else if (p < 0.8) {
        final t = Curves.easeIn.transform((p - 0.55) / 0.25);
        bandH = 3;
        bandW = _lerp(w, 3, t);
        glow = 1;
      } else {
        bandH = 3;
        bandW = 3;
        glow = (1 - (p - 0.8) / 0.2).clamp(0.0, 1.0);
      }
      if (glow > 0) {
        final rect = Rect.fromCenter(
          center: center,
          width: bandW,
          height: bandH,
        );
        canvas.drawRect(rect, Paint()..color = kText.withValues(alpha: glow));
        canvas.drawRect(
          rect,
          Paint()
            ..color = kNeon.withValues(alpha: glow * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PowerCyclePainter old) => old.p != p;
}

// ── skip ─────────────────────────────────────────────────────────────────────
class _SkipLink extends StatelessWidget {
  const _SkipLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Skip, continue without charging',
      child: ArcadeTap(
        onTap: onTap,
        haptic: HapticIntent.selection,
        child: Center(
          child: Text(
            'skip — continue without charging',
            style: AppFonts.shareTechMono(color: kDim, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
