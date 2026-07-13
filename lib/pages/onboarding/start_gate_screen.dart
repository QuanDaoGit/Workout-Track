import 'dart:async';

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

class _StartGateScreenState extends State<StartGateScreen> {
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
      // TalkBack / reduce-motion users land on the sustained state instantly.
      final mq = MediaQuery.of(context);
      if (mq.accessibleNavigation || mq.disableAnimations) {
        _skipToEnd();
        return;
      }
      _scheduleSequence();
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
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
    // Cumulative ms offsets from screen enter (per §5 of the build prompt).
    _step(150, () => _cardFrameVisible = true);
    _step(350, () => _avatarVisible = true); // 150 + 200
    _step(550, () => _nameTyping = true); // + 200
    _step(730, () => _untitledVisible = true); // + 180
    _step(880, () => _badgesVisible = true); // + 150 (triggers StrobeFlash)
    _step(1130, () => _xpBarVisible = true); // + 250
    _step(1280, () => _countersVisible = true); // + 150
    _step(1580, () => _promptTyping = true); // + 300 stillness beat
    _step(2030, () => _subtextVisible = true); // + 450 (typed prompt window)
    _step(2230, () => _primaryOn = true); // + 200
    _step(2330, () => _secondaryOn = true); // + 100 overlap
    _step(2530, () => _completed = true); // + 200 (buttons interactive)
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
                    _buildCharacterCard(character, reduceMotion),
                    const SizedBox(height: 32),
                    // BIT embodies here — powers on below the character card and
                    // delivers its first name-drop. Gated on the existing reveal
                    // flags (_promptTyping / _subtextVisible) so it shows on the
                    // timed, tap-skip, and reduce-motion paths alike; StrobeFlash
                    // is the one-shot "online" beat (no new timers).
                    SizedBox(
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
                                  // The living, painted core — breathing plates +
                                  // glow, reduced-motion-safe — the same companion
                                  // engine the cold open / quiz / loader carry.
                                  const BitMoodCore(
                                    pose: BitPose.neutral,
                                    reveal: 1,
                                    size: 56,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      opacity: _subtextVisible ? 1.0 : 0.0,
                                      child: BitSpeechBubble(
                                        text: bitPrompt,
                                        emphasis: addressed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const Spacer(),
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

  Widget _buildCharacterCard(Character character, bool reduceMotion) {
    final clazz = character.calibration.clazz;
    return Semantics(
      label:
          'Character: ${character.characterName}, ${clazz.displayName}, Recruit, Level 1',
      container: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _cardFrameVisible ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _avatarVisible ? 1.0 : 0.0,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        // Neutral identity frame (matches the Profile avatar
                        // frame); the class is conveyed elsewhere, not by tinting
                        // the user's own face.
                        border: Border.all(color: kBorderVariant),
                        borderRadius: BorderRadius.circular(kCardRadius),
                        color: kBg,
                      ),
                      child: Center(
                        child: IronbitAvatar(
                          spec: widget.avatarSpec,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
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
                                        style: const TextStyle(
                                          fontFamily: 'PressStart2P',
                                          fontSize: 22,
                                          color: kText,
                                        ),
                                      )),
                        ),
                        const SizedBox(height: 5),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _untitledVisible ? 1.0 : 0.0,
                          child: Text(
                            'untitled',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Badges hard-reveal (no fade) with a single StrobeFlash
                        // pulse when they appear ("system online" beat).
                        if (_badgesVisible)
                          StrobeFlash(
                            trigger: _badgesVisible,
                            color: kNeon,
                            opacity: 0.25,
                            toggles: 1,
                            toggleMs: 80,
                            borderRadius: BorderRadius.circular(kCardRadius),
                            child: Row(
                              children: [
                                const _IdentityBadge(
                                  label: 'RECRUIT',
                                  color: kMutedText,
                                ),
                                const SizedBox(width: 8),
                                const _IdentityBadge(
                                  label: 'LV.1',
                                  color: kNeon,
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _xpBarVisible ? 1.0 : 0.0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(kCardRadius),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _countersVisible ? 1.0 : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
