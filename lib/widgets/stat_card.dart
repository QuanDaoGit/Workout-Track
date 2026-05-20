import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/stat_engine.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import 'segmented_progress_bar.dart';

const double _statLabelWidth = 38;
const double _statVisualValueGap = 10;
const double _statValueWidth = 42;
const double _statValueRankGap = 8;
const double _statRankWidth = 34;

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.stats});

  final Map<String, int> stats;

  int _value(String stat) => stats[stat] ?? 0;

  int _segments(int value) {
    if (value <= 0) return 0;
    return (value / 100).ceil().clamp(0, 10);
  }

  int _luckDiamonds(int value) {
    return XpService.lckDiamondCount(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ImageIcon(
                AssetImage('assets/icons/control/icon_star.png'),
                color: kNeon,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'CHARACTER STATS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 12),
          for (final stat in StatEngine.volumeStats) ...[
            _StatRow(stat: stat, value: _value(stat), segments: _segments),
            const SizedBox(height: 9),
          ],
          _LuckRow(value: _value('LCK'), filled: _luckDiamonds(_value('LCK'))),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.stat,
    required this.value,
    required this.segments,
  });

  final String stat;
  final int value;
  final int Function(int value) segments;

  @override
  Widget build(BuildContext context) {
    final engine = StatEngine();
    final rankColor = engine.getRankColor(value);
    final rank = engine.getRank(value);

    return Row(
      children: [
        SizedBox(
          width: _statLabelWidth,
          child: Text(
            stat,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kText,
            ),
          ),
        ),
        Expanded(
          child: SegmentedProgressBar(
            totalCells: 10,
            litCells: segments(value),
            height: 8,
          ),
        ),
        _StatTrailing(
          value: value,
          valueColor: rankColor,
          rank: rank,
          rankColor: rankColor,
        ),
      ],
    );
  }
}

class _LuckRow extends StatelessWidget {
  const _LuckRow({required this.value, required this.filled});

  final int value;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: _statLabelWidth,
          child: Text(
            'LCK',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            List.generate(4, (i) => i < filled ? '\u25C6' : '\u25C7').join(),
            style: const TextStyle(
              color: kNeon,
              fontSize: 14,
              letterSpacing: 3,
            ),
          ),
        ),
        _StatTrailing(value: value, valueColor: kNeon),
      ],
    );
  }
}

class _StatTrailing extends StatelessWidget {
  const _StatTrailing({
    required this.value,
    required this.valueColor,
    this.rank,
    this.rankColor,
  });

  final int value;
  final Color valueColor;
  final String? rank;
  final Color? rankColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: _statVisualValueGap),
        SizedBox(
          width: _statValueWidth,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppFonts.shareTechMono(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: _statValueRankGap),
        SizedBox(
          width: _statRankWidth,
          child: rank == null
              ? const SizedBox.shrink()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '[$rank]',
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: rankColor ?? valueColor,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
