import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/calibration_quiz_models.dart';
import '../../models/character.dart';
import '../../services/haptic_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_settings_service.dart';
import '../../services/simple_mode_service.dart';
import '../../services/unit_settings_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';
import '../../widgets/motion/ambient_drift.dart';
import '../../widgets/motion/hold_depress.dart';
import '../../widgets/motion/phosphor_tap.dart';
import '../../widgets/pixel_button.dart';
import 'gift_reveal_screen.dart';
import 'start_gate_screen.dart';

/// One-time, opt-in **soft-ask** for Tier B training-day reminders, shown once at
/// the end of onboarding (between the name commit and the Start Gate). It is a
/// *primer*, not the OS dialog: "Turn on" requests the OS permission and opts in;
/// "Not now" leaves reminders off (the anti-guilt default) and never fires the OS
/// dialog, so the scarce Android prompt is preserved. Both paths continue to the
/// Start Gate. The reminder is body-neutral, local/on-device, and never framed as
/// a streak or a guilt nudge.
class RemindersPrimerPage extends StatefulWidget {
  const RemindersPrimerPage({
    super.key,
    required this.character,
    required this.avatarSpec,
    required this.trainingWeekdays,
  });

  final Character character;
  final AvatarSpec avatarSpec;

  /// The committed training weekdays (1=Mon..7=Sun) — already persisted by the
  /// name screen, so they can be named back to the user here.
  final Set<int> trainingWeekdays;

  @override
  State<RemindersPrimerPage> createState() => _RemindersPrimerPageState();
}

class _RemindersPrimerPageState extends State<RemindersPrimerPage> {
  bool _busy = false;

  // The onboarding "guidance" preference — the visible on/off for the existing
  // Simple Mode (key `simple_mode_enabled_v1`). Pre-selected from the user's
  // self-reported experience (intermediate/advanced → Compact/ON). It is a
  // *reversible preference*, never a mode fork: it writes the one Simple Mode
  // key that Settings also owns.
  late bool _compact = simpleModeDefaultForExperience(
    widget.character.calibration.exp,
  );
  bool _previewExpanded = false;
  // Guards the one-time persist of the derived default (see [initState]).
  bool _guidanceSeeded = false;

  @override
  void initState() {
    super.initState();
    // Persist the derived default the moment the guidance card is DISPLAYED —
    // deliberately NOT at the earlier character-commit (Codex F1: never persist
    // a first-workout reduction before the user has seen the choice). The primer
    // is the single mandatory funnel screen every new user passes through, so
    // the card is always shown here; a kill before this point leaves Simple Mode
    // OFF — the fail-safe direction (more guidance, never silently less).
    // Persisting here (and on every flip) also makes SimpleModeService the
    // single source of truth (Codex F2): the shown selection always equals the
    // stored value.
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedGuidanceDefault());
  }

  Future<void> _seedGuidanceDefault() async {
    if (_guidanceSeeded || !mounted) return;
    _guidanceSeeded = true;
    await SimpleModeService().setEnabled(_compact);
  }

  Future<void> _setCompact(bool value) async {
    if (_compact == value) return;
    // An explicit pick supersedes the post-frame seed and writes immediately —
    // the guidance commits by its OWN control, decoupled from TURN ON / NOT NOW
    // (Codex F4: those stay purely the notification decision).
    _guidanceSeeded = true;
    setState(() => _compact = value);
    HapticService.instance.selection();
    await SimpleModeService().setEnabled(value);
  }

  void _togglePreview() {
    HapticService.instance.selection();
    setState(() => _previewExpanded = !_previewExpanded);
  }

  Future<void> _turnOn() async {
    if (_busy) return;
    setState(() => _busy = true);
    final settings = NotificationSettingsService();
    await settings.setTrainingReminderEnabled(true);
    await settings.setTrainingPrimerShown(true);
    // The in-app primer earned the OS prompt — fire it now.
    await NotificationService.instance.requestPermissions();
    // Schedule (no-ops cleanly if the OS prompt was declined).
    await NotificationService.instance.syncTrainingReminders();
    _continue();
  }

  Future<void> _notNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Leave the opt-in OFF (anti-guilt default); just remember we asked once so
    // we never re-nag — Settings is the path back.
    await NotificationSettingsService().setTrainingPrimerShown(true);
    _continue();
  }

  void _continue() {
    if (!mounted) return;
    // The motivational reel — offered via the "gift" beat, then the Charge
    // Ritual — is for the two LOWEST experience tiers only (novice / beginner).
    // Seasoned lifters (intermediate / advanced) don't need the hype video, so
    // they skip the gift + reel entirely and go straight to the Start Gate.
    final exp = widget.character.calibration.exp;
    final showReel =
        exp == Experience.novice || exp == Experience.beginner;
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => showReel
            ? GiftRevealScreen(
                character: widget.character,
                avatarSpec: widget.avatarSpec,
              )
            : StartGateScreen(
                character: widget.character,
                avatarSpec: widget.avatarSpec,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _dayLabels(widget.trainingWeekdays);
    final timeLabel = _formatMinutes(
      NotificationSettingsService.defaultTrainingReminderMinutes,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: AmbientDrift())),
            SafeArea(
              child: Column(
                children: [
                  // Scrolling content — the guidance card + its expandable
                  // preview can grow, so the reminder actions stay pinned in a
                  // footer below rather than being pushed off small screens.
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        kSpace4,
                        kSpace5,
                        kSpace4,
                        kSpace4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: kSpace4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const BitMoodCore(
                                pose: BitPose.neutral,
                                reveal: 1,
                                size: 56,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BitSpeechBubble(
                                  text:
                                      'Want a heads-up on your training days? '
                                      'A quiet nudge — nothing else.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpace5),
                          _ScheduleCard(days: days, timeLabel: timeLabel),
                          const SizedBox(height: kSpace3),
                          Text(
                            'On your device only. No account, never shared. '
                            'Change the time or turn it off anytime in Settings.',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: kSpace5),
                          // A separate, self-contained preference (Codex F4): its
                          // own titled card, committed by its own controls — the
                          // reminder buttons below never touch it.
                          _GuidanceCard(
                            compact: _compact,
                            onChanged: _setCompact,
                            previewExpanded: _previewExpanded,
                            onTogglePreview: _togglePreview,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Pinned reminder footer — TURN ON / NOT NOW are the ONLY
                  // notification actions (kept distinct from the guidance card).
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace4,
                      kSpace3,
                      kSpace4,
                      kSpace4,
                    ),
                    decoration: const BoxDecoration(
                      color: kBg,
                      border: Border(top: BorderSide(color: kBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Turn on training reminders',
                          child: PixelButton(
                            label: 'TURN ON',
                            minHeight: 56,
                            onPressed: _busy ? null : _turnOn,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _NotNowButton(enabled: !_busy, onTap: _notNow),
                      ],
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

  static List<String> _dayLabels(Set<int> weekdays) {
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final sorted = weekdays.where((d) => d >= 1 && d <= 7).toList()..sort();
    return [for (final d in sorted) names[d - 1]];
  }

  static String _formatMinutes(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final period = h24 < 12 ? 'AM' : 'PM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm $period';
  }
}

/// The "this is what you'll get" readout — the chosen training days + the fire
/// time, so the opt-in is concrete (and never a surprise).
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.days, required this.timeLabel});

  final List<String> days;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAINING DAYS',
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: kSpace2),
          if (days.isEmpty)
            Text(
              'Your schedule',
              style: AppFonts.shareTechMono(color: kText, fontSize: 14),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final d in days) _DayChip(label: d)],
            ),
          const SizedBox(height: kSpace3),
          Row(
            children: [
              Icon(Icons.schedule_sharp, size: 16, color: kNeon),
              const SizedBox(width: 6),
              Text(
                timeLabel,
                style: AppFonts.shareTechMono(color: kText, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 10,
          color: kNeon,
        ),
      ),
    );
  }
}

/// Equal-weight, guilt-free decline — a clear outlined button, not a buried grey
/// link (anti-guilt: declining must be as easy and legible as opting in).
class _NotNowButton extends StatelessWidget {
  const _NotNowButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kCardRadius);
    return Semantics(
      button: true,
      label: 'Not now',
      child: PhosphorTap(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        color: kMutedText,
        opacity: 0.25,
        borderRadius: radius,
        child: HoldDepress(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: kBorder),
              borderRadius: radius,
            ),
            child: Text(
              'NOT NOW',
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The onboarding "guidance" preference — a self-contained card that flips the
/// existing Simple Mode on/off. Pre-selected from experience, committed by its
/// own radio options (never by the reminder buttons), with a tappable "see the
/// difference" preview and a reversibility line pointing to Settings. Not a
/// mode fork: it writes the one `simple_mode_enabled_v1` key Settings owns.
class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.compact,
    required this.onChanged,
    required this.previewExpanded,
    required this.onTogglePreview,
  });

  final bool compact;
  final ValueChanged<bool> onChanged;
  final bool previewExpanded;
  final VoidCallback onTogglePreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_visibility_off.png'),
                size: 16,
                color: kMutedText,
              ),
              const SizedBox(width: kSpace2),
              Text(
                'WORKOUT GUIDANCE',
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Text(
            'How much on-screen help during a workout? '
            'We picked one from your experience — change it anytime.',
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: kSpace3),
          _GuidanceOption(
            label: 'COMPACT',
            hint: 'Just your sets — no tips or suggestions.',
            selected: compact,
            onTap: () => onChanged(true),
          ),
          const SizedBox(height: kSpace2),
          _GuidanceOption(
            label: 'EXTRA SUGGESTIONS',
            hint: 'Warm-up tips and suggested weights shown.',
            selected: !compact,
            onTap: () => onChanged(false),
          ),
          const SizedBox(height: kSpace3),
          _SeeDifferenceToggle(
            expanded: previewExpanded,
            onTap: onTogglePreview,
          ),
          _GuidancePreview(compact: compact, expanded: previewExpanded),
          const SizedBox(height: kSpace2),
          Text(
            'Change anytime in Settings › Simple Mode.',
            style: AppFonts.shareTechMono(color: kDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// One radio-style guidance option (single-select). Full-width so long labels
/// never overflow; taps route through [HoldDepress] (the selection tick fires
/// once, on an actual change, from the owning state).
class _GuidanceOption extends StatelessWidget {
  const _GuidanceOption({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? kNeon : kMutedText;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3,
            vertical: kSpace3,
          ),
          decoration: BoxDecoration(
            color: selected ? kSurface2 : kCard,
            border: Border.all(
              color: selected ? kNeon : kBorder,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_sharp
                    : Icons.radio_button_unchecked_sharp,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: selected ? kNeon : kText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 12,
                        height: 1.3,
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

/// The user-triggered "peek" affordance — reveals the swapping preview mock.
class _SeeDifferenceToggle extends StatelessWidget {
  const _SeeDifferenceToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: expanded ? 'Hide preview' : 'See the difference',
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpace2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                expanded ? 'HIDE PREVIEW' : 'SEE THE DIFFERENCE',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: kMutedText,
                  height: 1.3,
                ),
              ),
              const SizedBox(width: kSpace2),
              Icon(
                expanded ? Icons.expand_less_sharp : Icons.expand_more_sharp,
                size: 16,
                color: kMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The revealed preview — an illustrative workout card that swaps between the
/// two guidance states. Reduced motion shows/hides without the size tween.
class _GuidancePreview extends StatelessWidget {
  const _GuidancePreview({required this.compact, required this.expanded});

  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final revealed = Padding(
      padding: const EdgeInsets.only(top: kSpace3),
      child: _PreviewWorkoutCard(compact: compact),
    );
    if (MediaQuery.of(context).disableAnimations) {
      return expanded ? revealed : const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: kMotionPop,
      curve: kMotionCurve,
      alignment: Alignment.topCenter,
      child: expanded
          ? revealed
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// A static mock of the exercise screen, mirroring the real `_WarmupCard` /
/// `_TryLine` vocabulary so the peek reads true to what Simple Mode hides.
class _PreviewWorkoutCard extends StatelessWidget {
  const _PreviewWorkoutCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final unit = Units.weight.label;
    return Semantics(
      label: compact
          ? 'Preview: a compact workout screen — the exercise and your sets only.'
          : 'Preview: a workout screen with a warm-up tip and a suggested weight.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kSpace3),
        decoration: BoxDecoration(
          color: kBg,
          border: Border.all(color: kBorderDark),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BENCH PRESS',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: kText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: kSpace3),
            if (!compact) ...[
              const _PreviewWarmup(),
              const SizedBox(height: kSpace2),
            ],
            _PreviewSetRow(index: 1, value: '60 $unit  ×  8'),
            const SizedBox(height: kSpace2),
            _PreviewSetRow(index: 2, value: '60 $unit  ×  8'),
            if (!compact) ...[
              const SizedBox(height: kSpace3),
              _PreviewTry(text: 'TRY: 62.5 $unit × 8'),
            ],
          ],
        ),
      ),
    );
  }
}

/// The mock warm-up row (mirrors `_WarmupCard`'s amber "W" chip + label).
class _PreviewWarmup extends StatelessWidget {
  const _PreviewWarmup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: kAmber.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            'W',
            style: AppFonts.shareTechMono(fontSize: 10, color: kAmber),
          ),
        ),
        const SizedBox(width: kSpace3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warm up',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: kMutedText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Empty bar  ×  8',
                style: AppFonts.shareTechMono(fontSize: 13, color: kMutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The mock "TRY:" suggestion chip (mirrors `_TryLine`).
class _PreviewTry extends StatelessWidget {
  const _PreviewTry({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = kNeon.withValues(alpha: 0.7);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: AppFonts.shareTechMono(
            fontSize: 11,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _PreviewSetRow extends StatelessWidget {
  const _PreviewSetRow({required this.index, required this.value});

  final int index;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SET $index',
          style: AppFonts.shareTechMono(fontSize: 11, color: kMutedText),
        ),
        const Spacer(),
        Text(
          value,
          style: AppFonts.shareTechMono(fontSize: 13, color: kText),
        ),
      ],
    );
  }
}
