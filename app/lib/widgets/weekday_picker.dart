import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/ui_sound.dart';
import '../theme/tokens.dart';
import 'motion/hold_depress.dart';

/// The Mon–Sun training-day toggle row shared by Settings → Training Goals and
/// the onboarding weekday step, so both read identically. Each cell is a
/// selectable arcade chip; the row wraps on narrow widths. Selected = neon fill.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  /// Selected weekdays, 1=Mon..7=Sun.
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _days = [
    (1, 'MON'),
    (2, 'TUE'),
    (3, 'WED'),
    (4, 'THU'),
    (5, 'FRI'),
    (6, 'SAT'),
    (7, 'SUN'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in _days)
          _WeekdayToggle(
            label: day.$2,
            weekday: day.$1,
            selected: selected.contains(day.$1),
            onTap: () => onToggle(day.$1),
          ),
      ],
    );
  }
}

class _WeekdayToggle extends StatelessWidget {
  const _WeekdayToggle({
    required this.label,
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: '$label training day, ${selected ? 'on' : 'off'}',
      child: HoldDepress(
        onTap: onTap,
        haptic: HapticIntent.selection,
        sound: UiSound.select,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kMotionFast,
          curve: kMotionCurve,
          width: 52,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kNeon : kCard,
            border: Border.all(color: selected ? kNeon : kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: selected ? kBg : kMutedText,
            ),
          ),
        ),
      ),
    );
  }
}
