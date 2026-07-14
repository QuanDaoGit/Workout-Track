import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/bit_room_copy.dart';
import '../../models/adventure_models.dart' show AdventurePhase;
import '../../services/haptic_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../companion/bit_companion.dart';
import '../companion/bit_core_engine.dart' show bitGlow;
import '../companion/bit_speech_bubble.dart';
import '../companion/bit_sprite.dart' show BitMood;
import 'bit_hologram.dart';
import 'bit_pad.dart';
import 'pad_charge_meter.dart';
import 'bit_pad_beam.dart';
import 'bit_pad_light.dart';
import 'coffer.dart';
import 'launch_fx.dart';
import 'quest_board.dart';
import 'world_window.dart';

/// Empty-dock gap after a send-off before BIT's hologram **flicker-ignites**
/// (the `BIT Hologram Ignition` handoff's beat). The handoff ships **2000ms**;
/// dialled to **1000ms** here per the app — the one deviation from its timing.
const int _kAwayDockGapMs = 1000;

/// Compact, presentation-only view-model the room consumes to drive the pad's
/// **Expedition dock** state. [phase] is the *sole* authority — derived fresh by
/// the caller from `adventureUiStateOf`, never cached in the room — so the dock
/// can never disagree with the service (Codex-hardened). Null on the scene means
/// no dock affordance at all (loading / feature unavailable): the pad is just
/// BIT's home.
@immutable
class RoomAdventureView {
  const RoomAdventureView({
    required this.phase,
    required this.charges,
    required this.canDispatch,
    this.haulReady = false,
    this.homecomingTick = 0,
    this.routeName,
    this.routeAccent,
    this.backInHours,
    this.voice,
  });

  final AdventurePhase phase;
  final int charges;

  /// True only when a fresh expedition may be dispatched right now (idle +
  /// charge + not weekly-capped + no uncollected haul) — gates the dispatch
  /// signifier + the launch.
  final bool canDispatch;

  /// A haul is on the pad waiting to be collected — the **persisted authority**
  /// for the coffer (derived by Home from `hasUncollectedHaul`, never a volatile
  /// held report). True both after settle (unviewed history) and on a
  /// returned-but-unsettled pending. The coffer + COLLECT shows whenever this is
  /// true, independent of [phase]; tapping the pad collects (not dispatches).
  final bool haulReady;

  /// Monotonic one-shot homecoming token. Home bumps it **only on a fresh
  /// settle this open**, so the descent+fabricate animation plays once for a
  /// newly-returned haul; a backlog/already-waiting haul (same tick) renders a
  /// static coffer. The room plays when `tick > _playedTick && haulReady`.
  final int homecomingTick;

  /// Pending/standing route name + accent (for the `out` status caption).
  final String? routeName;
  final Color? routeAccent;

  /// Coarse hours until the haul returns, for the `out` caption ("BACK IN ~Nh").
  final int? backInHours;

  /// BIT's resolved voice line for this state (advice / "I'm back" / scouting /
  /// haul) — selected purely by Home; the room only renders it in the bubble.
  final BitRoomLine? voice;
}

/// Room scroll parallax: the whole diorama drifts up at `1 - factor` of the
/// scroll (lagging the content list), capped at [_kRoomParallaxMaxTravel] px so
/// the lag stays subtle on a daily-visited surface.
const double _kRoomParallaxFactor = 0.3;
const double _kRoomParallaxMaxTravel = 48;

/// The **Home Room** — BIT's lit chamber. A painted lit-chamber scene that fits
/// the viewport: the caller (Home) measures the available height and passes
/// [height]; the scene **top-anchors** the identity + world-window and anchors
/// the pad → BIT → light-pool stack to a single **horizon** line (the wall/floor
/// seam), with the pad's center sitting on it. Sprite/position scale is clamped
/// to a phone range
/// (`kx`), decoupled from [height], so nothing balloons on wide/tall surfaces.
///
/// The ceiling key-light now lives on the Home status bar (the "ceiling-scrim
/// header"), not in the room — the room's top just receives a soft glow.
///
/// Scope: the room only. Nav, resource HUD, and the card feed are the app's
/// existing surfaces and are NOT part of this widget.
class HomeRoomScene extends StatefulWidget {
  const HomeRoomScene({
    super.key,
    required this.height,
    required this.name,
    required this.level,
    required this.title,
    this.titleColor = kAmber,
    this.mood = BitMood.neutral,
    this.timeOfDay,
    this.scrollOffset,
    this.adventure,
    this.onDispatchTap,
    this.onStatusTap,
    this.onCollect,
    this.questWeeklyFilled = 0,
    this.questWeeklyTotal = 0,
    this.questClaimable = 0,
    this.onViewQuests,
    this.questBoardPowered = true,
    this.questBoardOfflineLabel,
    this.onDormantPadTap,
    this.dormantPadLabel,
  });

  /// The exact height to render at (measured by the caller from the viewport).
  final double height;
  final String name;
  final int level;
  final String title;
  final Color titleColor;
  final BitMood mood;
  final RoomTimeOfDay? timeOfDay;

  /// Live scroll offset of the enclosing list (px). When non-null, the **whole
  /// room** drifts up slower than the scroll (a subtle parallax — the diorama
  /// lags the content sliding past it; its layers stay internally synced, so the
  /// pad keeps sitting on the horizon). Null → no parallax (the static render;
  /// keeps standalone/golden uses byte-identical). The drift is quantised to a
  /// whole device pixel so the crisp sprites stay sharp, and it's gated off under
  /// reduced motion.
  final ValueListenable<double>? scrollOffset;

  /// The Expedition-dock state, or null for no dock affordance (the pad is just
  /// BIT's home). Phase is authoritative; presence of BIT is derived from it.
  final RoomAdventureView? adventure;

  /// Pad tapped while idle (the caller decides: open the dispatch console if a
  /// charge is ready, else nudge "train to earn a charge").
  final VoidCallback? onDispatchTap;

  /// Pad tapped while an expedition is out — a read-only status peek.
  final VoidCallback? onStatusTap;

  /// Pad tapped while a haul is back but unrevealed — runs the report ceremony.
  final VoidCallback? onCollect;

  /// Weekly-quest progress for the wall board's 5-seg bar (completed / total).
  final int questWeeklyFilled;
  final int questWeeklyTotal;

  /// Rewards ready to claim — drives the board's amber claimable cue + BIT's
  /// nudge line. 0 → the board sits calm steady-cyan, nothing breathes.
  final int questClaimable;

  /// Tap on the wall board (or BIT's claimable line) → open the Quests page.
  final VoidCallback? onViewQuests;

  /// False = the earned-unlock locked state: the wall board renders dark/off
  /// (no bar, no pip, no claim cue). The tap still routes to [onViewQuests]
  /// (the shell's gate shows the invitation notice).
  final bool questBoardPowered;

  /// Screen-reader label for the unpowered board (the unlock condition).
  final String? questBoardOfflineLabel;

  /// When [adventure] is withheld because the expedition system is still
  /// locked, the bare pad becomes a notice tap target with [dormantPadLabel]
  /// as its accessible name. Null = the plain pre-load bare pad (no target).
  final VoidCallback? onDormantPadTap;
  final String? dormantPadLabel;

  /// Floor below which the composition would crush — the caller should not pass
  /// less, but we guard internally too.
  static const double minHeight = 380;

  @override
  State<HomeRoomScene> createState() => _HomeRoomSceneState();
}

class _HomeRoomSceneState extends State<HomeRoomScene>
    with TickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(5.0);
  bool _reduce = false;

  /// The expedition-launch transition — a NON-authoritative cosmetic overlay.
  /// Created lazily and only when motion is on; the authoritative state is
  /// always `widget.adventure.phase`. While it animates BIT is rendered riding
  /// the beam out even though the phase has already flipped to `out`.
  AnimationController? _launch;
  bool get _launching => _launch?.isAnimating ?? false;

  /// The handoff's **hologram-ignition** beat, bound to the real send-off: once
  /// the launch has carried BIT out, the dock sits **empty** for
  /// [_kAwayDockGapMs], then his hologram **flicker-ignites**
  /// (`BitHologramPainter.igniteEnv`). [_awayDockEmpty] hides the hologram +
  /// caption during the gap; [_ignitionStart] is the room-clock value the
  /// flicker begins at (`null` ⇒ online/steady — also a cold mid-expedition
  /// reopen, which never re-ignites). Only ever armed when motion is on.
  bool _awayDockEmpty = false;
  double? _ignitionStart;
  Timer? _igniteTimer;

  /// Send-off particles, generated once per launch from a seed (never RNG in
  /// paint). Memoised by [_launchSeed]; positions are a pure function of time.
  int _launchSeed = 0;
  int _builtSparksSeed = -1;
  List<LaunchSpark> _launchSparks = const [];

  /// The homecoming transition (BIT rides home + the coffer fabricates) — a
  /// cosmetic one-shot, same discipline as [_launch]. Fired once per fresh
  /// `homecomingTick`; the coffer is authoritative (renders whenever
  /// `haulReady`), this only animates its *arrival*.
  AnimationController? _homecoming;
  bool get _homecomingPlaying => _homecoming?.isAnimating ?? false;
  int _playedHomecomingTick = 0;

  /// The COLLECT dissolve (the curtain). Re-entrancy is guarded by
  /// `_collect.isAnimating`; on completion we hand off to Home, which pushes the
  /// report (occluding the room through the reload window).
  AnimationController? _collect;
  bool get _collecting => _collect?.isAnimating ?? false;

  /// Bumped to fire BIT's tap-spin cheer on COLLECT (reuses his exact motion).
  int _cheerTick = 0;

  /// True while the spam-tap easter egg holds BIT in REST — the room swaps his
  /// voice bubble to the "I guess bro..." sigh. BitCompanion owns the pose + the
  /// timing; this is just its report so the bubble follows.
  bool _bitResting = false;

  /// One-shot "a charge just landed" flash on the newly-lit meter segment — fired
  /// from [didUpdateWidget] when banked charges increase. Lazy + motion-only.
  AnimationController? _chargePulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _ticker?.stop();
      _time.value = 5.0;
      // No motion → never leave a transition mid-flight (keeps the dock legible
      // and can't hang a page-level pumpAndSettle).
      _launch?.stop();
      _homecoming?.stop();
      _collect?.stop();
      // No motion → never sit mid-ignition: drop the gap and show the static
      // still (the hologram online, no stutter).
      _igniteTimer?.cancel();
      _awayDockEmpty = false;
      _ignitionStart = null;
    } else {
      _ticker ??= createTicker((d) => _time.value = d.inMicroseconds / 1e6);
      if (!_ticker!.isActive) _ticker!.start();
    }
    // Safety net for a cold open where the room is built directly with a fresh
    // haul (no prior widget for didUpdateWidget to compare); the tick guard
    // keeps it idempotent.
    _maybePlayHomecoming();
  }

  @override
  void didUpdateWidget(HomeRoomScene old) {
    super.didUpdateWidget(old);
    // Play the launch only on a fresh idle→out flip while mounted + motion on
    // (not on an initial `out`, e.g. reopening mid-expedition).
    final was = old.adventure?.phase;
    final now = widget.adventure?.phase;
    if (!_reduce && was == AdventurePhase.idle && now == AdventurePhase.out) {
      _playLaunch();
    }
    // Expedition left `out` (returned / collected) — drop any pending empty-dock
    // ignition so its timer can't fire against the wrong phase or strand state.
    if (was == AdventurePhase.out && now != AdventurePhase.out) {
      _igniteTimer?.cancel();
      _awayDockEmpty = false;
      _ignitionStart = null;
    }
    // A workout just banked a charge (count rose) → flash the newly-lit meter
    // segment, so the rare earned-charge arrival gets a beat. Motion only; fires
    // once per genuine increase (a dispatch drops the count → no flash; a settle
    // awards gems, not charges). A charge earned while the app was closed lands
    // on the first build, not an update, so it won't flash — acceptable.
    final wasCharges = old.adventure?.charges ?? 0;
    final nowCharges = widget.adventure?.charges ?? 0;
    if (!_reduce && nowCharges > wasCharges) {
      (_chargePulse ??= AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 480),
        ))
        ..reset()
        ..forward();
    }
    _maybePlayHomecoming();
  }

  /// Fire the homecoming once per fresh `homecomingTick` (the monotonic one-shot
  /// from Home — bumped only on a settle this open). Covers cold open
  /// (didChangeDependencies) and in-session settle (didUpdateWidget); the tick
  /// guard makes both idempotent.
  void _maybePlayHomecoming() {
    final adv = widget.adventure;
    if (adv == null || !adv.haulReady) return;
    if (adv.homecomingTick <= _playedHomecomingTick) return;
    _playedHomecomingTick = adv.homecomingTick;
    if (_reduce) return; // reduced motion → static coffer, no descent
    _playHomecoming();
  }

  void _playLaunch() {
    _launchSeed++; // fresh deterministic particle set for this launch
    // BIT is visibly launching — clear any prior ignition so this send-off
    // restarts the empty-dock → flicker beat cleanly.
    _igniteTimer?.cancel();
    _awayDockEmpty = false;
    _ignitionStart = null;
    (_launch ??=
          AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2000),
          )..addStatusListener((s) {
            // On completion BIT has left: run the empty-dock → hologram-ignition
            // beat (which rebuilds), instead of snapping straight to the steady dock.
            if (s == AnimationStatus.completed && mounted) _beginAwayIgnition();
          }))
      ..reset()
      ..forward();
  }

  /// The handoff's empty-dock → flicker-ignition beat, fired when a send-off
  /// launch completes: hold the dock empty for [_kAwayDockGapMs], then start the
  /// hologram's flicker (the painter ramps `igniteEnv` from [_ignitionStart]). A
  /// cold mid-expedition reopen never calls this (no launch plays) — its
  /// hologram is simply already online.
  void _beginAwayIgnition() {
    _igniteTimer?.cancel();
    setState(() {
      _awayDockEmpty = true; // BIT departed — empty dock
      _ignitionStart = null;
    });
    _igniteTimer = Timer(const Duration(milliseconds: _kAwayDockGapMs), () {
      if (!mounted) return;
      setState(() {
        _awayDockEmpty = false;
        _ignitionStart = _time.value; // flicker-ignite from now
      });
    });
  }

  /// Generate this launch's particles once (memoised by seed) — geometry is
  /// only known at build time, so this is called from build when launching.
  void _ensureLaunchSparks(double emitterX, double emitterY, double exitY) {
    if (_builtSparksSeed == _launchSeed) return;
    _launchSparks = generateLaunchSparks(
      seed: _launchSeed,
      emitterX: emitterX,
      emitterY: emitterY,
      exitY: exitY,
    );
    _builtSparksSeed = _launchSeed;
  }

  void _playHomecoming() {
    (_homecoming ??=
          AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1900),
          )..addStatusListener((s) {
            // Rebuild on completion so the coffer settles to its static state.
            if (s == AnimationStatus.completed && mounted) setState(() {});
          }))
      ..reset()
      ..forward();
  }

  /// COLLECT — the curtain. Tap the coffer → BIT cheers + the coffer dissolves →
  /// on completion Home is asked to reveal the report (it pushes a full-screen
  /// route that occludes the room through the reload). Re-entrancy is guarded by
  /// `_collecting`; reduced motion routes immediately.
  void _startCollect() {
    if (_collecting) return; // guard double-tap during the dissolve
    if (_reduce) {
      widget.onCollect?.call();
      return;
    }
    setState(() => _cheerTick++); // fire BIT's spin (reuses his tap motion)
    (_collect ??=
          AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 640),
          )..addStatusListener((s) {
            if (s != AnimationStatus.completed) return;
            // Hand off only while still mounted + current (Codex: gate completion).
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
              widget.onCollect?.call();
            }
          }))
      ..reset()
      ..forward();
  }

  /// Chunky scattered pixel-dropout for the dissolve: each 2×2 block drops once
  /// `t` passes its stable hash threshold (no stored permutation needed).
  Set<int> _dissolveDropped(double t) {
    if (t <= 0) return const <int>{};
    final out = <int>{};
    for (var b = 0; b < 140; b++) {
      final h = math.sin(b * 12.9898) * 43758.5453;
      if (t > (h - h.floorToDouble())) out.add(b);
    }
    return out;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _igniteTimer?.cancel();
    _launch?.dispose();
    _homecoming?.dispose();
    _collect?.dispose();
    _chargePulse?.dispose();
    _time.dispose();
    super.dispose();
  }

  /// Live transition values, read inside the adventure AnimatedBuilders (build()
  /// doesn't re-run per frame). `hc` = homecoming progress (1 when settled);
  /// `dep` = its deposit/fabricate sub-progress; `cv` = collect-dissolve
  /// progress; `launch` = launch progress.
  ({double hc, double dep, double cv, double launch}) _advValues() {
    final hc = _homecomingPlaying ? _homecoming!.value : 1.0;
    final dep = _homecomingPlaying
        ? ((hc - 0.526) / 0.263).clamp(0.0, 1.0)
        : 1.0;
    final cv = _collecting ? _collect!.value : 0.0;
    final launch = _launching ? _launch!.value : 0.0;
    return (hc: hc, dep: dep, cv: cv, launch: launch);
  }

  /// The pad's P1 ignition recoil kick (350–520ms of the launch) in px — shared
  /// by the pad sprite AND its charge-meter overlay so the meter rides the recoil
  /// instead of being hidden (which would expose the pad sprite's bare baked
  /// strip — reading as "the old pad" during the send-off).
  double _padRecoilDy(double kx) {
    if (!_launching) return 0.0;
    final e = (_launch?.value ?? 0.0) * 2000;
    if (e >= 350 && e < 520) {
      return 2 * math.sin(((e - 350) / 170) * math.pi) * kx;
    }
    return 0.0;
  }

  /// The bare pad tapped while the expedition system is still locked — a
  /// glance-tick + the shell's invitation notice, never a dead tap.
  void _onDormantPadTap() {
    HapticService.instance.selection();
    widget.onDormantPadTap?.call();
  }

  void _onPadTap() {
    final adv = widget.adventure;
    if (adv == null) return;
    // A waiting haul always collects, whatever the (already-settled) phase is —
    // the single guard so a settled idle+haul can't fall through to dispatch.
    if (adv.haulReady) {
      _startCollect();
      return;
    }
    switch (adv.phase) {
      case AdventurePhase.idle:
        widget.onDispatchTap?.call();
      case AdventurePhase.out:
        widget.onStatusTap?.call();
      case AdventurePhase.returned:
        _startCollect();
    }
  }

  String _padSemantics(RoomAdventureView adv) {
    if (adv.haulReady) return 'BIT has returned. Collect the haul.';
    switch (adv.phase) {
      case AdventurePhase.idle:
        return adv.canDispatch
            ? 'Expedition dock. Dispatch BIT.'
            : 'Expedition dock. Train to earn a charge.';
      case AdventurePhase.out:
        final r = adv.routeName ?? 'an expedition';
        final b = adv.backInHours == null
            ? ''
            : ' Back in about ${adv.backInHours} hours.';
        return 'BIT is scouting $r.$b';
      case AdventurePhase.returned:
        return 'BIT has returned. Collect the haul.';
    }
  }

  /// BIT's voice bubble — his single text-box surface, an **in-world balloon
  /// ABOVE BIT with a downward tail** pointing at his screen (the comic / game
  /// convention for a character speaking in a scene; a beside-bubble reads as a
  /// chat UI, not in-world). Plain lines (advice, greeting) + the haul prompt
  /// type into [BitSpeechBubble] at a room-scaled ~12px (smaller than the
  /// full-screen 14px so it sits in the diorama's text density, not over it); the
  /// haul bubble is itself the collect tap target ("loots" tinted [kGemMagenta]);
  /// the scouting line hosts the relocated status readout (same fonts) as the
  /// bubble's rich child.
  Widget _voiceBubble(BitRoomLine line, RoomAdventureView adv, double kx) {
    final fontSize = 12 * kx;
    switch (line.kind) {
      case BitRoomVoiceKind.scouting:
        return BitSpeechBubble(
          text: '',
          tailDirection: BitTailDirection.down,
          downTailDx: _voiceTailDx(kx),
          downApexFrac: _voiceTailApexFrac,
          semanticsLabel: line.semanticsLabel,
          child: _scoutingContent(line, adv, kx),
        );
      case BitRoomVoiceKind.haul:
        return Semantics(
          button: true,
          label: line.semanticsLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startCollect,
            child: ExcludeSemantics(
              child: BitSpeechBubble(
                text: line.text ?? '',
                emphasis: line.emphasis,
                emphasisColor: kGemMagenta,
                tailDirection: BitTailDirection.down,
                downTailDx: _voiceTailDx(kx),
                downApexFrac: _voiceTailApexFrac,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      case BitRoomVoiceKind.claimable:
        return Semantics(
          button: widget.onViewQuests != null,
          label: line.semanticsLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onViewQuests,
            child: ExcludeSemantics(
              child: BitSpeechBubble(
                text: line.text ?? '',
                tailDirection: BitTailDirection.down,
                downTailDx: _voiceTailDx(kx),
                downApexFrac: _voiceTailApexFrac,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      case BitRoomVoiceKind.advice:
      case BitRoomVoiceKind.greeting:
        return BitSpeechBubble(
          text: line.text ?? '',
          tailDirection: BitTailDirection.down,
          downTailDx: _voiceTailDx(kx),
          downApexFrac: _voiceTailApexFrac,
          fontSize: fontSize,
        );
    }
  }

  /// The spam-tap easter-egg sigh — a plain down-tail bubble above BIT, the same
  /// shape/size as his advice line. He's worn out from being poked.
  Widget _restBubble(double kx) => BitSpeechBubble(
    text: bitRoomRestQuip,
    tailDirection: BitTailDirection.down,
    downTailDx: _voiceTailDx(kx),
    downApexFrac: _voiceTailApexFrac,
    fontSize: 12 * kx,
  );

  /// BIT's balloon sits centred above him, but a dead-centre tail reads stiff —
  /// the comic convention slides the tail slightly off-centre (left) and leans
  /// the apex back toward the speaker. Tuned on-device against the centred BIT.
  static double _voiceTailDx(double kx) => -7 * kx;
  static const double _voiceTailApexFrac = 0.82;

  /// The relocated away status (SCOUTING / ROUTE / BACK IN ~Nh) — same fonts as
  /// the old dock readout, now hosted inside the voice bubble.
  Widget _scoutingContent(BitRoomLine line, RoomAdventureView adv, double kx) {
    final accent = adv.routeAccent ?? kCyan;
    final route = (line.routeName ?? 'EXPEDITION').toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SCOUTING',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7 * kx,
            height: 1,
            letterSpacing: 0.5,
            color: accent,
          ),
        ),
        SizedBox(height: 4 * kx),
        Text(
          route,
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 9 * kx,
            letterSpacing: 1,
          ),
        ),
        if (line.backInHours != null) ...[
          SizedBox(height: 2 * kx),
          Text(
            'BACK IN ~${line.backInHours}H',
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 9 * kx,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height < HomeRoomScene.minHeight
        ? HomeRoomScene.minHeight
        : widget.height;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final kx = (w / 340.0).clamp(0.85, 1.15);
        final cx = w * 0.5;

        // One horizon line drives the whole composition so the wall/floor seam
        // and the pad can't drift apart (coherence). The pad's CENTER sits on
        // the horizon — a floating emitter dock anchored on the seam — and BIT
        // floats a fixed gap above it. We solve for the horizon so BIT lands in
        // the **vertical center** of the room, then clamp so there is always
        // floor below the pad for the light pool.
        final padW = 150 * kx, padH = 52 * kx;
        final bitSize = 92 * kx;
        // BIT center is always (padH/2 - 4 + 80)·kx = 102·kx above the pad
        // center; invert that to place BIT at h/2.
        final padBitGap = 102 * kx;
        final maxPadCenterY = h - 92 * kx;
        final padCenterY = (h * 0.5 + padBitGap).clamp(
          padBitGap,
          maxPadCenterY,
        );
        final horizonY = padCenterY;
        final horizonFrac = horizonY / h;
        final padTopY = padCenterY - padH / 2;
        final padBottomY = padCenterY + padH / 2;
        final emitterY = padTopY + 4 * kx;
        final bitCenterY = emitterY - 80 * kx;
        final poolW = 220 * kx, poolH = 140 * kx;
        // The pool's bright mass centres ~⅔ down its box, so push the box up
        // until that bright region tucks behind the pad base. The pad (z5) is
        // drawn in front of the pool (z3) and occludes the overlap, so the
        // visible glow starts exactly at the pad edge — no floating gap.
        final poolTop = padBottomY - 84 * kx;
        final beamW = 64 * kx;
        final beamTop = bitCenterY + 14 * kx;
        // The beam painter's apex (its emitter origin) sits at 22/26 of its box;
        // size the box so the apex lands on the pad's emitter mouth (emitterY)
        // instead of floating above it.
        const beamApexFrac = 22 / 26;
        final beamHeight = (emitterY - beamTop) / beamApexFrac;

        // Dock state (phase is authoritative). BIT is present unless he's away
        // — and still rendered (flying out) while the launch overlay runs.
        // Smooth per-frame values are read LIVE inside each AnimatedBuilder via
        // _advValues(); only structural booleans are computed here (stable for
        // the whole transition — the controllers setState only at start/end).
        final adv = widget.adventure;
        final phase = adv?.phase;
        final out = phase == AdventurePhase.out;
        final haulReady = adv?.haulReady ?? false;
        final bitPresent = !out || _launching;
        final hcPlaying = _homecomingPlaying;
        final collecting = _collecting;

        // Beam withdraws into the pad once a haul is present, re-emerges on
        // collect; otherwise the normal cone (hidden while BIT is away).
        final beamShown =
            (!out && !haulReady) || _launching || hcPlaying || collecting;

        // The pad's own charge meter shows in EVERY pad state — so the dock never
        // reverts to its bare baked strip (which reads as "the old pad"). The pad
        // sprite is static through homecoming + collect (only the coffer / BIT /
        // beam animate, all clear of the strip); through the **launch** the pad
        // recoils, so the meter rides the SAME recoil (`_padRecoilDy`) to stay
        // aligned rather than hiding and exposing the baked strip. The coffer sits
        // over the strip's MIDDLE cell only, and banked charges run 0–1 in practice
        // (left-first), so the lit cells stay visible. Segments reflect banked
        // `charges`; the armed glow only when a dispatch is possible (`canDispatch`).
        final showMeter = adv != null;
        final meterArmed = adv?.canDispatch ?? false;

        // BIT's voice bubble shows whenever a line is resolved and no transition
        // owns the stage (launch / homecoming / collect / the away-dock gap).
        final noTransition =
            !_launching && !hcPlaying && !collecting && !_awayDockEmpty;
        // The spam-tap sigh wins the bubble only at home — never over a haul or
        // away line (the reward/status still speaks); BitCompanion owns the pose.
        final showRest = _bitResting && !out && !haulReady && noTransition;
        final showVoice = showRest || (adv?.voice != null && noTransition);
        // The balloon's bottom (its down-tail) sits ~8px above BIT — or above the
        // taller away-hologram while out — so the tail points right down at him.
        final voiceClearY =
            (out ? bitCenterY - bitSize * 0.82 : bitCenterY - bitSize * 0.5) -
            8 * kx;

        final advAnim = Listenable.merge([_launch, _homecoming, _collect]);

        // Send-off particles for this launch (generated once, pure-function in
        // paint); exit-pop sits near the top edge where BIT vanishes.
        if (_launching) _ensureLaunchSparks(cx, emitterY, 36 * kx);

        // Coffer geometry (28:20 native): ~⅓ the pad width, seated on the pad's
        // front lip so the banded-chest silhouette stays distinct from the pad
        // console, BIT floating just above it.
        final cofferW = 44 * kx, cofferH = 44 * 20 / 28 * kx;
        final cofferTop = padTopY - 26 * kx;

        return SizedBox(
          width: w,
          height: h,
          child: _RoomParallax(
            scrollOffset: widget.scrollOffset,
            reduce: _reduce,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoomShellPainter(floorTopFrac: horizonFrac),
                  ),
                ),

                // BIT cast-light bloom — a faint static turquoise wash on the wall
                // behind the self-luminous BIT (he casts LIGHT, not a shadow). The
                // positive form of a contrast pedestal: it advances his lit
                // silhouette off the backdrop and reads as a near-plane cue. Sits
                // on the wall (behind every foreground object); quiets with the
                // chamber while he's away (matches the dimmed pool). Static ⇒
                // reduced-motion-identical, zero per-frame cost.
                Positioned(
                  left: cx - bitSize * 0.95,
                  top: bitCenterY - bitSize * 0.95,
                  width: bitSize * 1.9,
                  height: bitSize * 1.9,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: out ? 0.0 : 1.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              bitGlow.withValues(alpha: 0.16),
                              bitGlow.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Quest board — a flush wall fixture on the LEFT wall at BIT's
                // eye level (the open left-middle panel), per the user's chosen
                // placement. A glance peek: tap routes to Quests. Back-wall layer
                // (behind BIT); **vertically centred on BIT** so it tracks him
                // across room heights and clears the nameplate above, the bubble
                // band, and BIT to its right. Offsets tuned on-device.
                Positioned(
                  left: 40 * kx,
                  top: bitCenterY - 16 * kx,
                  width: 65 * kx,
                  height: 72 * kx,
                  child: QuestBoard(
                    width: 65 * kx,
                    height: 72 * kx,
                    total: widget.questWeeklyTotal,
                    filled: widget.questWeeklyFilled,
                    ready: widget.questClaimable,
                    onTap: widget.onViewQuests,
                    powered: widget.questBoardPowered,
                    semanticsLabel: widget.questBoardPowered
                        ? null
                        : widget.questBoardOfflineLabel,
                  ),
                ),

                // floor pool (z3) — the light spilling onto the floor below the
                // horizon; this grounds the floating dock. Dimmed while BIT is
                // away (the chamber quiets *because* he's out).
                Positioned(
                  left: cx - poolW / 2,
                  top: poolTop,
                  width: poolW,
                  height: poolH,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: out ? 0.5 : 1.0,
                      child: AnimatedBuilder(
                        animation: advAnim,
                        builder: (context, _) {
                          final v = _advValues();
                          final tint = _collecting
                              ? (1 - v.cv).clamp(0.0, 1.0)
                              : haulReady
                              ? v.dep
                              : 0.0;
                          return CustomPaint(
                            painter: BitPadLightPainter(
                              time: _time,
                              reduceMotion: _reduce,
                              tint: tint,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // emitter (z5) — the approved sprite (painted BitPad is the
                // never-crash fallback). The whole pad is the dispatch dock's
                // tap target, dispatching by phase.
                Positioned(
                  left: cx - padW / 2,
                  top: padTopY,
                  width: padW,
                  height: padH,
                  child: Semantics(
                    button: adv != null || widget.onDormantPadTap != null,
                    label: adv != null
                        ? _padSemantics(adv)
                        : widget.dormantPadLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: adv != null
                          ? _onPadTap
                          : (widget.onDormantPadTap == null
                                ? null
                                : _onDormantPadTap),
                      child: AnimatedBuilder(
                        animation:
                            _launch ?? const AlwaysStoppedAnimation<double>(0),
                        child: Image.asset(
                          'assets/room/bit_pad.png',
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          isAntiAlias: false,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stack) =>
                              BitPad(width: padW, height: padH),
                        ),
                        builder: (context, child) {
                          // P1 ignition recoil kick (350–520ms).
                          return Transform.translate(
                            offset: Offset(0, _padRecoilDy(kx.toDouble())),
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // rising beam (z6) — originates at the pad's emitter mouth.
                // Hidden while BIT is away or a haul sits on the pad; surges on
                // launch, withdraws on deposit, re-emerges cyan on collect.
                if (beamShown)
                  Positioned(
                    left: cx - beamW / 2,
                    top: beamTop,
                    width: beamW,
                    height: beamHeight,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: advAnim,
                        builder: (context, _) {
                          final v = _advValues();
                          // scale = brightness in place; topY01 = retract into
                          // the emitter — verbatim from the handoff beam.set()
                          // calls (the beam never extends past BIT).
                          double beamScale, beamTopY01;
                          if (_launching) {
                            final e = v.launch * 2000;
                            if (e < 350) {
                              beamScale = 0.4 + 0.6 * (e / 350); // charge ramp
                              beamTopY01 = 0;
                            } else if (e < 1250) {
                              beamScale =
                                  1.15; // ignition + ascent: bright, full
                              beamTopY01 = 0;
                            } else if (e < 1450) {
                              final k2 =
                                  (e - 1250) / 200; // exit-pop: collapse begins
                              beamScale = 1.15 * (1 - k2) + 0.2;
                              beamTopY01 = 0.6 * k2;
                            } else {
                              final k3 =
                                  (e - 1450) / 550; // withdraw into emitter
                              beamScale = 0.2 * (1 - k3);
                              beamTopY01 = 0.6 + 0.4 * k3;
                            }
                          } else if (_collecting) {
                            beamScale = v.cv; // cyan beam re-emerges
                            beamTopY01 = 1 - v.cv;
                          } else if (_homecomingPlaying) {
                            beamScale =
                                1 - v.dep; // withdraws as the haul deposits
                            beamTopY01 = v.dep * 0.8;
                          } else {
                            beamScale = 1.0;
                            beamTopY01 = 0.0;
                          }
                          return CustomPaint(
                            painter: BitPadBeamPainter(
                              time: _time,
                              reduceMotion: _reduce,
                              scale: beamScale.clamp(0.0, 1.3),
                              topY01: beamTopY01.clamp(0.0, 1.0),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // coffer (z6.5) — the haul on the pad. Behind BIT, in front of
                // the beam. Fabricates bottom-up on homecoming, dissolves on
                // collect. Visibility is the persisted authority (haulReady).
                if (haulReady)
                  Positioned(
                    left: cx - cofferW / 2,
                    top: cofferTop,
                    width: cofferW,
                    height: cofferH,
                    // Tapping the haul itself claims it (the pad does too); the
                    // pad's Semantics is the single collect announce, so the
                    // coffer is excluded to avoid a double screen-reader button.
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _startCollect,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([advAnim, _time]),
                          builder: (context, _) {
                            final v = _advValues();
                            final lift = _collecting ? 10 * kx * v.cv : 0.0;
                            // A gentle idle hover while the haul waits — sub-pixel
                            // (the coffer is painted), paused during the arrival /
                            // collect transitions and frozen under reduced motion.
                            final floatY =
                                (_homecomingPlaying || _collecting || _reduce)
                                ? 0.0
                                : 1.8 * kx * math.sin(_time.value * 1000 / 600);
                            final op = _collecting
                                ? (1 - ((v.cv - 0.55) / 0.45).clamp(0.0, 1.0))
                                : 1.0;
                            return Transform.translate(
                              offset: Offset(0, -lift + floatY),
                              child: Opacity(
                                opacity: op,
                                child: CustomPaint(
                                  painter: CofferPainter(
                                    build: _collecting ? 1.0 : v.dep,
                                    dropped: _collecting
                                        ? _dissolveDropped(v.cv)
                                        : const <int>{},
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // send-off FX (launch only) — charge sparks, ignition burst +
                // core flash, vapor trail + speed-streaks, exit-pop. Behind BIT.
                if (_launching)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _launch!,
                        builder: (context, _) => CustomPaint(
                          painter: LaunchFxPainter(
                            sparks: _launchSparks,
                            elapsedMs: (_launch?.value ?? 0.0) * 2000,
                            emitterX: cx,
                            bitCenterY: bitCenterY,
                            bitSpan: bitCenterY + bitSize,
                            kx: kx.toDouble(),
                          ),
                        ),
                      ),
                    ),
                  ),

                // BIT (z7) — the brightest thing. Absent while scouting; rides
                // the beam out on launch, rides it home on homecoming, cheers on
                // collect (his exact tap-spin via cheerTick).
                if (bitPresent)
                  Positioned(
                    left: cx - bitSize / 2,
                    top: bitCenterY - bitSize / 2,
                    width: bitSize,
                    height: bitSize,
                    child: AnimatedBuilder(
                      animation: advAnim,
                      child: BitCompanion(
                        mood: widget.mood,
                        size: bitSize,
                        cheerTick: _cheerTick,
                        // Arm the spam-tap rest gag only at home/idle, so it can
                        // never bury a waiting haul or the away status.
                        spamRestArmed: !out && !haulReady,
                        onRestEasterEgg: (resting) {
                          if (mounted) setState(() => _bitResting = resting);
                        },
                      ),
                      builder: (context, child) {
                        final v = _advValues();
                        // Launch (handoff playLaunch, 2000ms): P0 6px crouch →
                        // P1 spring → P2 ease-in ascent (-490·a²) fading out →
                        // P3+ gone. Matches LaunchFxPainter._bitDy exactly so the
                        // trail/streaks line up.
                        if (_launching) {
                          final e = v.launch * 2000;
                          final span = bitCenterY + bitSize;
                          double dy;
                          var op = 1.0;
                          if (e < 350) {
                            dy = 6 * math.sin((e / 350) * math.pi * 0.5) * kx;
                          } else if (e < 520) {
                            dy = 6 * (1 - (e - 350) / 170) * kx;
                          } else if (e < 1250) {
                            final a = (e - 520) / 730;
                            dy = -span * (a * a);
                            op = a < 0.7
                                ? 1.0
                                : math.max(0.0, 1 - (a - 0.7) / 0.3);
                          } else {
                            dy = -span;
                            op = 0.0;
                          }
                          return Opacity(
                            opacity: op,
                            child: Transform.translate(
                              offset: Offset(0, dy),
                              child: child,
                            ),
                          );
                        }
                        // Homecoming: drops in from above (ease-out, gravitas).
                        if (_homecomingPlaying) {
                          final hc = v.hc;
                          final dT = ((hc - 0.105) / (0.526 - 0.105)).clamp(
                            0.0,
                            1.0,
                          );
                          final eased = Curves.easeOutCubic.transform(dT);
                          final drop = -(1 - eased) * (bitCenterY + bitSize);
                          final op = hc < 0.105
                              ? 0.0
                              : ((hc - 0.105) / 0.08).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: op,
                            child: Transform.translate(
                              offset: Offset(0, drop),
                              child: child,
                            ),
                          );
                        }
                        return child!;
                      },
                    ),
                  ),

                // away hologram (out) — BIT's real sprite projected as a
                // turquoise hologram in a containment rig where he floats,
                // reading "out there", not "gone". A taller box than BIT so the
                // rig frames him above (volume top) and below (emitter field).
                if (out && !_launching && !_awayDockEmpty)
                  Positioned(
                    left: cx - bitSize / 2,
                    top: bitCenterY - bitSize * 0.5 - bitSize * 0.32,
                    width: bitSize,
                    height: bitSize * 1.64,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: BitHologramPainter(
                          time: _time,
                          reduceMotion: _reduce,
                          ignitionStartSeconds: _ignitionStart,
                        ),
                      ),
                    ),
                  ),

                // pad charge meter (z6) — the pad's own readout strip repainted
                // as a 3-segment LED, lit per banked charge. Overlaid on the pad
                // box (same coords) so it tracks the sprite's stretch 1:1; nothing
                // protrudes. Armed glow only when a dispatch is possible.
                if (showMeter)
                  Positioned(
                    left: cx - padW / 2,
                    top: padTopY,
                    width: padW,
                    height: padH,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_chargePulse, _launch]),
                        builder: (context, _) => Transform.translate(
                          // Ride the pad's launch recoil so the meter face stays on
                          // the sprite instead of exposing the bare baked strip.
                          offset: Offset(0, _padRecoilDy(kx.toDouble())),
                          child: CustomPaint(
                            painter: PadChargeMeterPainter(
                              charges: adv.charges.clamp(0, 3),
                              armed: meterArmed,
                              pulse: _chargePulse?.value ?? 0.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // world window (top-anchored, right)
                Positioned(
                  left: w - 107 * kx,
                  top: 12 * kx,
                  width: 91 * kx,
                  height: 76 * kx,
                  child: WorldWindow(timeOfDay: widget.timeOfDay),
                ),

                // BIT's voice bubble — his single text-box surface (advice /
                // greeting / scouting / haul, or the spam-tap "I guess bro..."
                // sigh). Drawn AFTER the world window so a 2-line balloon paints
                // OVER it (the nameplate still wins — it's drawn last). Centred on
                // BIT with a bottomCenter down-tail; capped to ~85% width so it
                // stays a balloon, not a wall-wide banner.
                if (showVoice)
                  Positioned(
                    // TOP-referenced region (room top → just above BIT) with
                    // bottomCenter pins the down-tail at BIT and lets the bubble
                    // grow up toward the HUD. Top-referenced (not `bottom: h - …`)
                    // so it's exact at full height or a clamped test surface.
                    top: 0,
                    left: 16 * kx,
                    right: 16 * kx,
                    height: voiceClearY.clamp(0.0, double.infinity),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (w - 32 * kx) * 0.85,
                        ),
                        child: showRest
                            ? IgnorePointer(child: _restBubble(kx.toDouble()))
                            : adv!.voice!.tappable
                            ? _voiceBubble(adv.voice!, adv, kx.toDouble())
                            : IgnorePointer(
                                child: _voiceBubble(
                                  adv.voice!,
                                  adv,
                                  kx.toDouble(),
                                ),
                              ),
                      ),
                    ),
                  ),

                // identity nameplate (top-anchored, left)
                Positioned(
                  left: 16 * kx,
                  top: 12 * kx,
                  child: _Identity(
                    name: widget.name,
                    level: widget.level,
                    title: widget.title,
                    titleColor: widget.titleColor,
                    k: kx.toDouble(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Drifts the **whole room** as one coupled unit for a subtle scroll parallax —
/// the diorama lags the content list sliding past it, so its layers (wall seam,
/// pad, BIT, light pool) stay internally synchronised (the pad keeps sitting on
/// the horizon — they're one depth plane and cannot move independently). With no
/// [scrollOffset] (or under reduced motion) it returns the child unchanged — the
/// static render, so standalone/golden uses stay byte-identical and the a11y gate
/// (WCAG 2.3.3) is honoured. Live: the room sinks by `offset * factor` (capped)
/// inside a `ClipRect` (bottom bleed clipped; the small top gap scrolls under the
/// pinned HUD, with a wall-colour [kCard] underlay behind it). The drift is
/// **quantised to a whole device pixel** so the crisp `FilterQuality.none` sprites
/// blit 1:1 and never shimmer.
class _RoomParallax extends StatelessWidget {
  const _RoomParallax({
    required this.scrollOffset,
    required this.reduce,
    required this.child,
  });

  final ValueListenable<double>? scrollOffset;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = scrollOffset;
    if (offset == null || reduce) return child;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: kCard),
          ValueListenableBuilder<double>(
            valueListenable: offset,
            child: child,
            builder: (context, value, child) {
              final raw = (value * _kRoomParallaxFactor).clamp(
                0.0,
                _kRoomParallaxMaxTravel,
              );
              // Snap to a whole device pixel so the crisp sprites don't shimmer.
              final dy = (raw * dpr).roundToDouble() / dpr;
              return Transform.translate(
                key: const ValueKey('room_parallax_shell'),
                offset: Offset(0, dy),
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// In-room nameplate — quiet supporting identity (must not compete with BIT).
class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.level,
    required this.title,
    required this.titleColor,
    required this.k,
  });

  final String name;
  final int level;
  final String title;
  final Color titleColor;
  final double k;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14 * k,
            height: 1,
            letterSpacing: 0.5,
            color: kText,
            shadows: [
              Shadow(color: kText.withValues(alpha: 0.25), blurRadius: 12 * k),
            ],
          ),
        ),
        SizedBox(height: 8 * k),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LV.$level',
              style: AppFonts.shareTechMono(
                fontSize: 13 * k,
                height: 1,
                color: kMutedText,
              ),
            ),
            Container(
              width: 1,
              height: 11 * k,
              margin: EdgeInsets.symmetric(horizontal: 8 * k),
              color: kAmber.withValues(alpha: 0.4),
            ),
            Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9 * k,
                height: 1,
                letterSpacing: 0.5,
                color: titleColor,
                shadows: [
                  Shadow(
                    color: titleColor.withValues(alpha: 0.35),
                    blurRadius: 10 * k,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The lit room shell: three value planes (wall lighter than bg & floor) with a
/// soft top glow (receiving the header's ceiling light), panel seams (the future
/// collection grid), mount points, a neon wall-floor seam, and an edge vignette.
/// Ambient room-light surfaces, so soft gradients are correct here — only the
/// pad light must be pixel art.
class _RoomShellPainter extends CustomPainter {
  const _RoomShellPainter({required this.floorTopFrac});

  /// Where the wall/floor seam sits (fraction of room height). Shared with the
  /// scene so the horizon and the pad center can't drift apart.
  final double floorTopFrac;

  static const Color _ceilTop = Color(0x29969FEB);
  static const Color _ceilMid = Color(0x0D7887D2);
  static const Color _shadeLo = Color(0x1A000000);
  static const Color _shadeHi = Color(0x38000000);
  static const Color _seamDark = Color(0x4D000000);
  static const Color _seamLite = Color(0x0AFFFFFF);
  static const Color _floorTopC = Color(0xFF131322);
  static const Color _floorMidC = Color(0xFF0C0C16);
  static const Color _floorBotC = Color(0xFF07070E);
  static const Color _vignEdge = Color(0x6B07070E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final k = w / 340.0;
    final floorTop = h * floorTopFrac;
    final wallRect = Rect.fromLTWH(0, 0, w, floorTop);
    final p = Paint()..isAntiAlias = false;

    canvas.drawRect(Offset.zero & size, p..color = kBg);
    canvas.drawRect(wallRect, p..color = kCard);

    // Ceiling-lit gradient down the wall (the top receives the header light).
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ceilTop, _ceilMid, Color(0x00000000), _shadeLo, _shadeHi],
          stops: [0, 0.24, 0.5, 0.84, 1.0],
        ).createShader(wallRect),
    );

    // Panel seams — vertical every 91px + a horizontal seam at 43% of the wall.
    final seam = Paint()..isAntiAlias = false;
    for (final sxv in const [91.0, 182.0, 273.0]) {
      final x = sxv * k;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 1 * k, floorTop),
        seam..color = _seamDark,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 1 * k, 0, 1 * k, floorTop),
        seam..color = _seamLite,
      );
    }
    final hy = floorTop * 0.43;
    canvas.drawRect(Rect.fromLTWH(0, hy, w, 1 * k), seam..color = _seamDark);
    canvas.drawRect(
      Rect.fromLTWH(0, hy + 1 * k, w, 1 * k),
      seam..color = _seamLite,
    );

    // Floor plane.
    final floorRect = Rect.fromLTWH(0, floorTop, w, h - floorTop);
    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_floorTopC, _floorMidC, _floorBotC],
          stops: [0, 0.42, 1.0],
        ).createShader(floorRect),
    );
    final pool = Rect.fromLTWH(
      w * 0.24,
      floorTop,
      w * 0.52,
      (h - floorTop) * 0.8,
    );
    canvas.drawRect(
      pool,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 1.0,
          colors: [const Color(0x1A7887C8), const Color(0x007887C8)],
          stops: const [0, 0.7],
        ).createShader(pool),
    );

    // Neon wall-floor seam + soft bloom.
    final seamRect = Rect.fromLTWH(0, floorTop - 1 * k, w, 2 * k);
    canvas.drawRect(
      seamRect,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * k)
        ..shader = LinearGradient(
          colors: [
            const Color(0x00000000),
            kNeon.withValues(alpha: 0.18),
            kNeon.withValues(alpha: 0.42),
            kNeon.withValues(alpha: 0.18),
            const Color(0x00000000),
          ],
          stops: const [0, 0.18, 0.5, 0.82, 1.0],
        ).createShader(seamRect),
    );

    // Edge vignette over the wall.
    canvas.drawRect(
      wallRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_vignEdge, Color(0x00000000), Color(0x00000000), _vignEdge],
          stops: [0, 0.26, 0.74, 1.0],
        ).createShader(wallRect),
    );

    // Ambient occlusion — depth by light alone (static). Faint radial darkening
    // pooled in the wall corners (ceiling/wall + wall/floor meets), plus a gentle
    // settle gathering toward the horizon so the back wall recedes. Neutral dark
    // (kBlack α) keeps the indigo palette + the WCAG contrast of the top-anchored
    // nameplate/window untouched; the cool nuance is carried by the existing
    // ceiling gradient, not re-tinted here.
    void cornerAO(Offset c, double radius, double alpha) {
      if (radius <= 0) return;
      final r = Rect.fromCircle(center: c, radius: radius);
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              kBlack.withValues(alpha: alpha),
              kBlack.withValues(alpha: 0),
            ],
          ).createShader(r),
      );
    }

    final topAOr = math.min(w * 0.34, floorTop * 0.7);
    cornerAO(Offset.zero, topAOr, 0.26);
    cornerAO(Offset(w, 0), topAOr, 0.26);
    cornerAO(Offset(0, floorTop), w * 0.26, 0.15);
    cornerAO(Offset(w, floorTop), w * 0.26, 0.15);

    // Cool air settling toward the horizon — a faint dark gather just above the
    // wall/floor seam, deepening the recession the ceiling gradient began.
    final settleH = floorTop * 0.22;
    final settleRect = Rect.fromLTWH(0, floorTop - settleH, w, settleH);
    canvas.drawRect(
      settleRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBlack.withValues(alpha: 0), kBlack.withValues(alpha: 0.14)],
        ).createShader(settleRect),
    );

    // Contact / grounding shadows — a soft dark blur just below each wall fixture
    // seats it ON the wall instead of floating in front of it (the room's key
    // light is from above, so the shadow falls below). Painted in the shell, so it
    // sits BEHIND the fixtures (drawn later) and only the offset-down crescent
    // shows. Footprint coords mirror the scene's clamped `kx` so the blob tracks
    // the fixture across widths.
    final kc = (w / 340.0).clamp(0.85, 1.15);
    void contactShadow(double cx, double cy, double halfW, double halfH,
        double alpha) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: halfW * 2,
          height: halfH * 2,
        ),
        Paint()
          ..color = kBlack.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * kc),
      );
    }

    // World window: left w-107·kx, top 12·kx, 91×76·kx → bottom edge at 88·kx.
    contactShadow(w - 61.5 * kc, 91 * kc, 39 * kc, 5 * kc, 0.40);
    // Quest board: left 8·kx, top 58·kx, 65×72·kx → bottom edge at 130·kx.
    contactShadow(40.5 * kc, 133 * kc, 28 * kc, 4.5 * kc, 0.40);

    // Mount points — reserved collection hang-points (near-invisible).
    final mount = Paint()
      ..color = const Color(0xFF0E0E22)
      ..isAntiAlias = false;
    for (final mx in const [91.0, 182.0, 273.0]) {
      for (final myFrac in const [0.0, 0.44]) {
        final mxp = mx * k, myp = floorTop * myFrac;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(mxp, myp),
            width: 4 * k,
            height: 4 * k,
          ),
          mount,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoomShellPainter oldDelegate) =>
      oldDelegate.floorTopFrac != floorTopFrac;
}
