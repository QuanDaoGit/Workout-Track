import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/character.dart';
import '../../services/notification_service.dart';
import '../../services/notification_settings_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/companion/bit_mood_core.dart';
import '../../widgets/companion/bit_speech_bubble.dart';
import '../../widgets/motion/ambient_drift.dart';
import '../../widgets/motion/hold_depress.dart';
import '../../widgets/motion/phosphor_tap.dart';
import '../../widgets/pixel_button.dart';
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
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => StartGateScreen(
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
              child: Padding(
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
                    const Spacer(),
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
