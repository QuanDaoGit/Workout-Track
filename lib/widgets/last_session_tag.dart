import 'package:flutter/material.dart';

import '../services/stat_engine.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'count_up_text.dart';

/// The "changed Home" closing beat: a compact tag summarizing the just-finished
/// session's visible capability gains (STR/AGI/END) with any rank-ups. VIT is
/// the recovery meter and LCK is a milestone — neither appears here. Renders
/// nothing when the session produced no visible capability gain.
class LastSessionTag extends StatelessWidget {
  const LastSessionTag({super.key, required this.delta, required this.stats});

  /// The last session's per-stat delta.
  final Map<String, int> delta;

  /// Combat stats after the session (for rank-up detection).
  final Map<String, int> stats;

  static const List<String> _visible = ['STR', 'AGI', 'END'];

  @override
  Widget build(BuildContext context) {
    final engine = StatEngine();
    final gains = [
      for (final stat in _visible)
        if ((delta[stat] ?? 0) > 0) stat,
    ];
    if (gains.isEmpty) return const SizedBox.shrink();

    final labelStyle = TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: 8,
      color: kAmber,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace3,
        vertical: kSpace2,
      ),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kAmber.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST SESSION', style: labelStyle),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace3,
            runSpacing: kSpace1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [for (final stat in gains) _gain(stat, engine)],
          ),
        ],
      ),
    );
  }

  Widget _gain(String stat, StatEngine engine) {
    final amount = delta[stat] ?? 0;
    final after = stats[stat] ?? 0;
    final before = after - amount;
    final fromRank = engine.getRank(before);
    final toRank = engine.getRank(after);
    final rankedUp = fromRank != toRank;
    final style = AppFonts.shareTechMono(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: kNeon,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$stat +', style: style),
        CountUpText(value: amount, style: style),
        if (rankedUp) ...[
          const SizedBox(width: kSpace1),
          Text(
            '$fromRank->$toRank',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kAmber,
            ),
          ),
        ],
      ],
    );
  }
}
