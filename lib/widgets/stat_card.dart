import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/stat_engine.dart';
import '../theme/tokens.dart';
import 'motion/phosphor_tap.dart';
import 'segmented_progress_bar.dart';
import 'stat_radar.dart';

const double _statLabelWidth = 38;
const double _statVisualValueGap = 10;
const double _statValueWidth = 42;
const double _statValueRankGap = 8;
const double _statRankWidth = 34;

/// DEF is retired from visible UI but keeps accumulating in the engine for
/// possible future revival (the spec's "feature flag", local-app form).
const bool kDefVisible = false;

/// Stats shown on the radar triangle (STR/AGI/END), in detail rows.
const List<String> _radarStats = ['STR', 'AGI', 'END'];

/// Visible volume stats for grade targeting: radar trio + VIT (shown as a bar).
const List<String> _visibleStats = ['STR', 'AGI', 'END', 'VIT'];

class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.stats,
    this.showEndBackfillNotice = false,
  });

  final Map<String, int> stats;
  final bool showEndBackfillNotice;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _detailVisible = false;

  int _value(String stat) => widget.stats[stat] ?? 0;

  int _segments(int value) {
    if (value <= 0) return 0;
    return (value / 100).ceil().clamp(0, 10);
  }

  String _nextGradeLabel() {
    // Operate over visible stats only (STR/AGI/END/VIT); DEF/LCK excluded.
    final values = {for (final stat in _visibleStats) stat: _value(stat)};
    if (values.values.every((value) => value >= StatEngine.rankThresholdS)) {
      return 'NEXT: HOLD [S]';
    }

    var targetStat = _visibleStats.first;
    for (final stat in _visibleStats.skip(1)) {
      if ((values[stat] ?? 0) < (values[targetStat] ?? 0)) {
        targetStat = stat;
      }
    }

    final value = values[targetStat] ?? 0;
    final next = value < StatEngine.rankThresholdC
        ? ('C', StatEngine.rankThresholdC)
        : value < StatEngine.rankThresholdB
        ? ('B', StatEngine.rankThresholdB)
        : value < StatEngine.rankThresholdA
        ? ('A', StatEngine.rankThresholdA)
        : ('S', StatEngine.rankThresholdS);
    return 'NEXT: $targetStat -> [${next.$1}] AT ${next.$2}';
  }

  void _showStatsInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: kBorder),
        ),
        title: const Text(
          'STAT BOARD',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: kNeon,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(
              text:
                  'STR / AGI / VIT grow from logged workout volume. END grows from logged reps.',
            ),
            const SizedBox(height: 8),
            _InfoLine(text: 'Grades: D, C 100, B 300, A 600, S 900.'),
            const SizedBox(height: 8),
            _InfoLine(
              text:
                  'LCK is a buff beside your XP bar — your streak multiplies XP.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppFonts.shareTechMono(
                color: kNeon,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_star.png'),
                color: kNeon,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CHARACTER STATS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: kNeon,
                  ),
                ),
              ),
              _StatsInfoButton(onPressed: _showStatsInfo),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 12),
          StatRadar(stats: widget.stats),
          const SizedBox(height: 8),
          Text(
            _nextGradeLabel(),
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          if (widget.showEndBackfillNotice) ...[
            const SizedBox(height: 6),
            Text(
              '+END FROM HISTORY',
              style: AppFonts.shareTechMono(
                color: kAmber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // VIT sits below the radar as its own bar (capability stat, not on
          // the triangle). LCK is no longer a stat here — it's a buff badge
          // beside the XP bar.
          _StatRow(stat: 'VIT', value: _value('VIT'), segments: _segments),
          const SizedBox(height: 10),
          _DetailToggle(
            visible: _detailVisible,
            onTap: () => setState(() => _detailVisible = !_detailVisible),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _detailVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        for (final stat in _radarStats) ...[
                          _StatRow(
                            stat: stat,
                            value: _value(stat),
                            segments: _segments,
                          ),
                          if (stat != _radarStats.last)
                            const SizedBox(height: 9),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StatsInfoButton extends StatelessWidget {
  const _StatsInfoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PhosphorTap(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kBg.withValues(alpha: 0.35),
          border: Border.all(color: kNeon),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '?',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            color: kNeon,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.shareTechMono(color: kText, fontSize: 13, height: 1.25),
    );
  }
}

class _DetailToggle extends StatelessWidget {
  const _DetailToggle({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PhosphorTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          visible ? '[ HIDE DETAIL ]' : '[ SHOW DETAIL ]',
          style: AppFonts.shareTechMono(
            color: kNeon,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
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
