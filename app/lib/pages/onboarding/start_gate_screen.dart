import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/companion_address.dart';
import '../../models/avatar_spec.dart';
import '../../models/character.dart';
import '../../models/character_class.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion/ambient_drift.dart';
import '../../widgets/motion/hold_depress.dart';
import '../../widgets/motion/phosphor_tap.dart';
import '../../widgets/motion/power_on.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/strobe_flash.dart';
import '../../widgets/avatar/ironbit_avatar.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';
import '../../widgets/typewriter_text.dart';
import '../root_page.dart';

/// Final screen of the onboarding body. Unveils the assembled character and
/// routes the user either into an immediate workout or to Home. Both exits
/// clear the onboarding stack (root replacement). System back is a no-op.
class StartGateScreen extends StatefulWidget {
  const StartGateScreen({
    super.key,
    required this.character,
    this.avatarSpec = AvatarSpec.fallback,
  });

  final Character character;

  /// The starter pixel face (gender-seeded default) revealed on the card.
  final AvatarSpec avatarSpec;

  @override
  State<StartGateScreen> createState() => _StartGateScreenState();
}

class _StartGateScreenState extends State<StartGateScreen>
    with TickerProviderStateMixin {
  // The one-shot charge-arrival surge duration (frame ignite + name lerp +
  // XP shimmer), and the screen-enter offset at which BIT's hyped arrival
  // line settles to the guiding prompt (Phase D of the reel→gate cinematic
  // plan — lands ~1.8s after the BIT row reveals at 1420ms).
  static const int _kArrivalMs = 900;
  static const int _kBitSettleMs = 3200;

  // Reveal flags driving the auto-sequence (see §5 of the build prompt).
  bool _cardFrameVisible = false;
  bool _avatarVisible = false;
  bool _nameTyping = false;
  bool _untitledVisible = false;
  bool _badgesVisible = false;
  bool _xpBarVisible = false;
  bool _countersVisible = false;
  bool _promptTyping = false;
  bool _subtextVisible = false;
  bool _primaryOn = false;
  bool _secondaryOn = false;
  bool _completed = false;

  // Full-motion-only: the poured charge arriving on the hero (frame glow +
  // name color lerp + XP-bar shimmer) and BIT's hyped arrival line before it
  // settles to the guiding prompt.
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _kArrivalMs),
  );
  bool _bitHyped = false;

  final List<Timer> _timers = [];
  bool _skipDispatched = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      AnalyticsService.instance.logOnboardingStep(AnalyticsValue.stepStartGate),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // TalkBack / reduce-motion users land on the sustained state instantly
      // — no arrival surge, no hyped line (WCAG fallback, byte-identical).
      final mq = MediaQuery.of(context);
      if (mq.accessibleNavigation || mq.disableAnimations) {
        _skipToEnd();
        return;
      }
      _bitHyped = true;
      _arrival.forward();
      _scheduleSequence();
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _arrival.dispose();
    super.dispose();
  }

  // Chain a flag flip after `delayMs` from "now" (relative to previous step).
  void _step(int delayMs, void Function() apply) {
    _timers.add(
      Timer(Duration(milliseconds: delayMs), () {
        if (!mounted || _skipDispatched) return;
        setState(apply);
      }),
    );
  }

  void _scheduleSequence() {
    // Cumulative ms offsets from screen enter, re-ordered payoff-first: the
    // hero avatar + name are the peak and land first, then the identity
    // details stagger in beneath, then BIT, then the CTAs (see Phase C of the
    // reel→gate cinematic plan).
    _step(120, () => _cardFrameVisible = true); // frame fades in under the hero
    _step(120, () => _avatarVisible = true); // the face is the peak — first
    _step(360, () => _nameTyping = true);
    _step(560, () => _untitledVisible = true);
    _step(720, () => _badgesVisible = true); // "system online" strobe
    _step(980, () => _xpBarVisible = true);
    _step(1120, () => _countersVisible = true);
    _step(1420, () => _promptTyping = true); // BIT arrives
    _step(1900, () => _subtextVisible = true);
    _step(2100, () => _primaryOn = true);
    _step(2200, () => _secondaryOn = true);
    _step(2400, () => _completed = true);
    _step(_kBitSettleMs, () => _bitHyped = false); // "fully charged" → prompt
  }

  void _skipToEnd() {
    if (_skipDispatched) return;
    _skipDispatched = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    if (!mounted) return;
    setState(() {
      _cardFrameVisible = true;
      _avatarVisible = true;
      _nameTyping = true;
      _untitledVisible = true;
      _badgesVisible = true;
      _xpBarVisible = true;
      _countersVisible = true;
      _promptTyping = true;
      _subtextVisible = true;
      _primaryOn = true;
      _secondaryOn = true;
      _completed = true;
      _bitHyped = false;
    });
  }

  void _startWorkout() {
    // Establish the app shell as the navigation root, then open the workout
    // starter on top of it (RootPage does the push on launch). This mirrors the
    // in-app Home → Start Workout path, so ending a workout early returns to
    // Home — not the orphaned exercise picker (which had no shell beneath it).
    Navigator.of(context).pushAndRemoveUntil(
      arcadeRoute(
        (_) => const RootPage(openWorkoutStarterOnLaunch: true),
        motion: ArcadeRouteMotion.flow,
      ),
      (route) => false,
    );
  }

  void _exploreFirst() {
    Navigator.of(context).pushAndRemoveUntil(
      arcadeRoute((_) => const RootPage(), motion: ArcadeRouteMotion.flow),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final mq = MediaQuery.of(context);
    final reduceMotion = mq.disableAnimations || mq.accessibleNavigation;
    final addressed = bitAddress(
      BitRegister.name,
      name: character.characterName,
    );
    final bitPrompt = 'What should we do first, $addressed?';
    final bitLine = _bitHyped ? 'fully charged, $addressed.' : bitPrompt;
    final bitPose = _bitHyped ? BitPose.cheer : BitPose.neutral;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: AmbientDrift())),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Centered middle band (hero + BIT). It vertically centers
                    // when there's room and scrolls when large text / a short
                    // viewport would otherwise overflow — the CTAs below stay
                    // anchored at the bottom, outside the scroll.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHero(character, reduceMotion),
                                const SizedBox(height: 24),
                                // BIT embodies here — powers on below the hero
                                // and delivers its first name-drop, arriving
                                // hyped (cheer) then settling to the guiding
                                // prompt (neutral) via `_bitHyped`; gated on
                                // the existing reveal flags so it shows on
                                // the timed, tap-skip, and reduce-motion
                                // paths alike.
                                _buildBitRow(bitLine, bitPose, addressed),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: 'Start workout',
                      child: PowerOn(
                        enabled: _primaryOn,
                        builder: (ctx, p) => Opacity(
                          opacity: p,
                          child: PixelButton(
                            label: 'START WORKOUT',
                            minHeight: 56,
                            onPressed: _completed ? _startWorkout : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      label: 'Explore first',
                      child: PowerOn(
                        enabled: _secondaryOn,
                        builder: (ctx, p) => Opacity(
                          opacity: p,
                          child: _ExploreFirstButton(
                            enabled: _completed,
                            onTap: _exploreFirst,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Skip-the-cinematic overlay — any tap during the auto-sequence
            // fast-forwards. Removed once the buttons are interactive.
            if (!_completed)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _skipToEnd,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Focal hero: a large centered framed pixel face owning the vertical
  /// center, with the identity strip (name · untitled · badges · XP bar ·
  /// counters) compressed beneath the portrait. Reuses the same reveal flags
  /// as before (`_avatarVisible` … `_countersVisible`), only the composition
  /// and reveal order changed (Phase C of the reel→gate cinematic plan).
  Widget _buildHero(Character character, bool reduceMotion) {
    final clazz = character.calibration.clazz;
    return Semantics(
      label:
          'Character: ${character.characterName}, ${clazz.displayName}, Recruit, Level 1',
      container: true,
      child: AnimatedOpacity(
        // Frame fades in under the hero, alongside the avatar itself.
        duration: const Duration(milliseconds: 180),
        opacity: _cardFrameVisible ? 1.0 : 0.0,
        child: Column(
          children: [
            // Focal hero: a large framed pixel face (echoes the Profile hero
            // card). The poured charge arrives here (Phase D): the frame
            // ignites in neon then cools as `_arrival` runs 0→1 — full
            // motion only (reduced motion never starts `_arrival`, so
            // `ignite` stays 0 and the boxShadow is a no-op empty list).
            AnimatedBuilder(
              animation: _arrival,
              builder: (context, child) {
                final ignite = math.sin(_arrival.value * math.pi); // 0→1→0
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _avatarVisible ? 1.0 : 0.0,
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      border: Border.all(color: kBorderVariant),
                      borderRadius: BorderRadius.circular(kCardRadius),
                      color: kBg,
                      boxShadow: neonGlow(
                        color: kNeon,
                        opacity: 0.55 * ignite,
                        blur: 22 * ignite,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: Center(
                child: IronbitAvatar(spec: widget.avatarSpec, size: 132),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _arrival,
              builder: (context, _) {
                final nameColor = reduceMotion
                    ? kText
                    : Color.lerp(
                        kNeon,
                        kText,
                        Curves.easeOut.transform(_arrival.value),
                      )!;
                return SizedBox(
                  height: 28,
                  child: !_nameTyping
                      ? const SizedBox.shrink()
                      : (reduceMotion
                            ? Text(
                                character.characterName,
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 22,
                                  color: kText,
                                ),
                              )
                            : TypewriterText(
                                character.characterName,
                                charMs: 30,
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 22,
                                  color: nameColor,
                                ),
                              )),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _untitledVisible ? 1.0 : 0.0,
              child: Text(
                'untitled',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            if (_badgesVisible)
              StrobeFlash(
                trigger: _badgesVisible,
                color: kNeon,
                opacity: 0.25,
                toggles: 1,
                toggleMs: 80,
                borderRadius: BorderRadius.circular(kCardRadius),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _IdentityBadge(label: 'RECRUIT', color: kMutedText),
                    SizedBox(width: 8),
                    _IdentityBadge(label: 'LV.1', color: kNeon),
                  ],
                ),
              )
            else
              const SizedBox(height: 22),
            const SizedBox(height: 14),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _xpBarVisible ? 1.0 : 0.0,
              // The charge conducts through the bar as it reveals — ONE
              // moving neon strip over the bar's fixed track. The bar's
              // VALUE never changes (still 0/50); this is decoration only,
              // never fabricated progress.
              child: SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: kBorder,
                        borderRadius: BorderRadius.circular(kCardRadius),
                      ),
                    ),
                    if (!reduceMotion)
                      AnimatedBuilder(
                        animation: _arrival,
                        builder: (context, _) {
                          final t = _arrival.value;
                          if (t <= 0 || t >= 1) return const SizedBox.shrink();
                          return Align(
                            alignment: Alignment(-1 + 2 * t, 0),
                            child: FractionallySizedBox(
                              widthFactor: 0.28,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: kNeon.withValues(
                                    alpha: 0.5 * math.sin(t * math.pi),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    kCardRadius,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _countersVisible ? 1.0 : 0.0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0 / 50 XP',
                        style: AppFonts.shareTechMono(
                          color: kMutedText,
                          fontSize: 12,
                        ),
                      ),
                      // Endowed progress: reframe "0 rewards" as a quest already
                      // in progress (mirrors the `side_first_workout` quest).
                      Text(
                        '1 QUEST ACTIVE',
                        style: AppFonts.shareTechMono(
                          color: kAmber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '▸ First Forge · save your first workout',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BIT's guide row beneath the hero — the living, painted core (breathing
  /// plates + glow, reduced-motion-safe) + its speech bubble. Extracted
  /// verbatim from the pre-Phase-C composition; gated on the same
  /// `_promptTyping` / `_subtextVisible` reveal flags. In this phase it is
  /// always called with the settled values (Phase D wires the hyped
  /// charge-arrival line/pose).
  Widget _buildBitRow(String bitLine, BitPose bitPose, String addressed) {
    return SizedBox(
      height: 80,
      child: !_promptTyping
          ? const SizedBox.shrink()
          : StrobeFlash(
              trigger: _promptTyping,
              color: kNeon,
              opacity: 0.2,
              toggles: 1,
              toggleMs: 80,
              borderRadius: BorderRadius.circular(kCardRadius),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The living, painted core — breathing plates + glow,
                  // reduced-motion-safe — the same companion engine the cold
                  // open / quiz / loader carry.
                  BitMoodCore(pose: bitPose, reveal: 1, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _subtextVisible ? 1.0 : 0.0,
                      child: BitSpeechBubble(
                        text: bitLine,
                        emphasis: addressed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// RECRUIT (title rank) and LV.1 badges on the character card. RECRUIT uses the
/// muted title-rank color (matching the in-app rank badge); LV.1 is neon.
class _IdentityBadge extends StatelessWidget {
  const _IdentityBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }
}

/// EXPLORE FIRST secondary button — per the build prompt: panel bg, 1px neon
/// border, neon label, HoldDepress + PhosphorTap, no PixelButton-style halo.
/// (Deliberately diverges from the app-wide blue-grey secondary for this
/// onboarding payoff screen — flagged in the plan.)
class _ExploreFirstButton extends StatelessWidget {
  const _ExploreFirstButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kCardRadius);
    return PhosphorTap(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      color: kNeon,
      opacity: 0.3,
      borderRadius: radius,
      child: HoldDepress(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kNeon),
            borderRadius: radius,
          ),
          child: const Text(
            'EXPLORE FIRST',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
            ),
          ),
        ),
      ),
    );
  }
}
