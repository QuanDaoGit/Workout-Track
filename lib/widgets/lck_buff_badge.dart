import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'motion/phosphor_tap.dart';
import 'pulse_color_text.dart';

/// LCK reframed as a *buff*, not a stat. Sits beside the XP bar and reads as a
/// reward modifier ("LCK x2"), with the streak reason + XP boost on tap. Hidden
/// entirely when there is no active buff (multiplier <= 1.0).
///
/// LCK in this app is the consecutive-day training streak (capped 100); the
/// diamond tiers convert it to the XP multiplier via [XpService].
class LckBuffBadge extends StatelessWidget {
  const LckBuffBadge({super.key, required this.multiplier, required this.lck});

  /// The XP multiplier (e.g. 2.0). Badge is hidden when <= 1.0.
  final double multiplier;

  /// The raw LCK value (streak in days, capped 100) — drives the reason copy.
  final int lck;

  String get _label {
    // "2.0" → "2", "1.5" → "1.5" — no trailing ".0", no double "x".
    final m = multiplier.toStringAsFixed(1);
    final trimmed = m.endsWith('.0') ? m.substring(0, m.length - 2) : m;
    return 'LCK x$trimmed';
  }

  String get _reason {
    final pct = ((multiplier - 1.0) * 100).round();
    final weeks = lck ~/ 7;
    final streak = weeks >= 1
        ? '$weeks clean ${weeks == 1 ? 'week' : 'weeks'}'
        : '$lck-day streak';
    return '$streak · +$pct% XP';
  }

  @override
  Widget build(BuildContext context) {
    if (multiplier <= 1.0) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: '$_label. $_reason.',
      child: PhosphorTap(
        onTap: () => _showReason(context),
        color: kAmber,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: kAmber.withValues(alpha: 0.12),
            border: Border.all(color: kAmber),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_sharp, size: 10, color: kAmber),
              const SizedBox(width: 3),
              PulseColorText(
                _label,
                style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 7),
                colorA: kAmber,
                colorB: Colors.white,
                periodMs: 1000,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReason(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: kAmber),
        ),
        title: Text(
          _label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: kAmber,
          ),
        ),
        content: Text(
          '$_reason\n\nTrain on consecutive days to raise your streak and the '
          'XP multiplier. Miss a day and the streak resets.',
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppFonts.shareTechMono(
                color: kAmber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
