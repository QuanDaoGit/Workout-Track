import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/unit_models.dart';
import '../services/strength_trend_service.dart';
import '../services/unit_settings_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'lift_icon.dart';
import 'motion/hold_depress.dart';

/// The reworked "all lifts" roster row — visual-first: a movement-pattern lift
/// icon, the name, a big estimated-max number, and a verdict **glyph** (▲ rising
/// · ★ new-best · – holding · ▼ rebuilding) instead of the verdict word, plus a
/// small signed delta. The number's "est. max" framing is carried once by the
/// page's column hint (and the Semantics label here), not repeated per row.
/// Body-neutral: the down glyph is muted, never red; only a genuine new PR gets
/// the amber flourish (accent bar + tinted border). Tap → the detail chart.
class StrengthRosterRow extends StatelessWidget {
  const StrengthRosterRow({
    super.key,
    required this.trend,
    required this.onTap,
    this.onLongPress,
    this.longPressLabel,
  });

  final StrengthTrend trend;
  final VoidCallback onTap;

  /// Optional long-press (e.g. pin/unpin). Also exposed as a custom Semantics
  /// action labelled [longPressLabel] so switch / screen-reader users get the
  /// same action without the gesture.
  final VoidCallback? onLongPress;
  final String? longPressLabel;

  static (IconData?, Color) _glyph(StrengthMomentum m) => switch (m) {
    StrengthMomentum.newBest => (Icons.star_sharp, kAmber),
    StrengthMomentum.rising => (Icons.arrow_upward_sharp, kNeon),
    StrengthMomentum.holding => (Icons.remove_sharp, kMutedText),
    StrengthMomentum.rebuilding => (Icons.arrow_downward_sharp, kMutedText),
    StrengthMomentum.fresh => (null, kMutedText),
  };

  static String _word(StrengthMomentum m) => switch (m) {
    StrengthMomentum.newBest => 'new best',
    StrengthMomentum.rising => 'on the rise',
    StrengthMomentum.holding => 'holding',
    StrengthMomentum.rebuilding => 'rebuilding',
    StrengthMomentum.fresh => 'one session',
  };

  String get _estMax => weightValue(trend.lastE1rm, Units.weight);

  ({String text, Color color})? get _delta {
    final m = trend.momentum;
    if (m == StrengthMomentum.fresh) {
      return (text: '1 session · log once more', color: kDim);
    }
    final d = trend.deltaVsPrevious;
    if (m == StrengthMomentum.holding || d.abs() < 0.05) {
      return (text: 'holding steady', color: kDim);
    }
    final mag = weightValue(d.abs(), Units.weight);
    final color = m == StrengthMomentum.newBest
        ? kAmber
        : (m == StrengthMomentum.rising ? kNeon : kMutedText);
    return (text: '${d > 0 ? '+' : '−'}$mag ${Units.weight.label}', color: color);
  }

  @override
  Widget build(BuildContext context) {
    final m = trend.momentum;
    final newBest = m == StrengthMomentum.newBest;
    final (glyph, glyphColor) = _glyph(m);
    final delta = _delta;

    // The one celebratory flourish: a uniform amber border on a genuine new best
    // (a non-uniform accent bar can't co-exist with a borderRadius). The amber
    // star glyph + amber delta carry the rest.
    final border = newBest
        ? Border.all(color: kAmber.withValues(alpha: 0.55), width: 1.4)
        : Border.all(color: kBorder);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${trend.exerciseName}, ${_word(m)}, estimated max $_estMax '
          '${Units.weight.label}${delta == null ? '' : ', ${delta.text}'}',
      customSemanticsActions: onLongPress == null
          ? null
          : {
              CustomSemanticsAction(label: longPressLabel ?? 'Pin to top'):
                  onLongPress!,
            },
      child: GestureDetector(
        onLongPress: onLongPress,
        child: HoldDepress(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3,
            vertical: kSpace3,
          ),
          decoration: BoxDecoration(
            color: kSurface2,
            border: border,
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kSurface3,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(kCardRadius),
                ),
                child: LiftIcon(exerciseName: trend.exerciseName, size: 40),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.shareTechMono(
                        color: kText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        delta.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.shareTechMono(
                          color: delta.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: kSpace2),
              Text(
                _estMax,
                style: AppFonts.shareTechMono(color: kText, fontSize: 22),
              ),
              const SizedBox(width: kSpace2),
              SizedBox(
                width: 22,
                child: glyph == null
                    ? const SizedBox.shrink()
                    : Icon(glyph, size: 20, color: glyphColor),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
