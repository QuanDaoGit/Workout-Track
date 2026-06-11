import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/stat_radar_read.dart';
import '../services/stat_engine.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import 'motion/phosphor_tap.dart';
import 'radar_stat_icon.dart';
import 'segmented_progress_bar.dart';
import 'stat_radar.dart';

const double _statLabelWidth = 38;
const double _statusLabelWidth = 62;
const double _statVisualValueGap = 10;
const double _statValueWidth = 42;
const double _statValueRankGap = 8;
const double _statRankWidth = 34;

/// DEF is retired from visible UI but keeps accumulating in the engine for
/// possible future revival (the spec's "feature flag", local-app form).
const bool kDefVisible = false;

/// Capability stats — radar triangle + graded D→S detail rows. VIT (recovery)
/// and LCK (consistency) are different categories, shown as their own rows.
const List<String> _radarStats = StatRadarRead.visibleStats;

/// Stats used for "NEXT grade" targeting — the graded capability trio only.
const List<String> _visibleStats = StatRadarRead.visibleStats;

class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.stats,
  });

  final Map<String, int> stats;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _detailVisible = false;

  int _value(String stat) => widget.stats[stat] ?? 0;

  int _segments(int value) {
    if (value <= 0) return 0;
    // Rank-band scale (shared with the radar): each rank D/C/B/A/S fills an
    // equal 2 of the 10 cells, so months of training read as real progress
    // instead of crawling toward the effectively-unreachable 1000 cap.
    return (StatRadarRead.rankBandFraction(value) * 10).ceil().clamp(0, 10);
  }

  String _nextGradeLabel() {
    // Operate over the graded capability trio only (STR/AGI/END).
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

  String _buildReadMeaning() {
    return StatRadarRead.buildRead({
      for (final stat in StatRadarRead.visibleStats) stat: _value(stat),
    });
  }

  String _vitalityRead() {
    final value = _value('VIT');
    if (value >= 100) return 'FULL VITALITY';
    if (value >= 70) return 'READY';
    if (value >= 40) return 'RECOVERING';
    return 'LOW VITALITY';
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
                  'STR is power, AGI is control, END is stamina. They grow '
                  'from logged training (volume and reps) and rank D->S '
                  '(C 100, B 300, A 600, S 900).',
            ),
            const SizedBox(height: 8),
            _InfoLine(
              text:
                  'VIT is recovery — your train/rest balance over the last 2 weeks. '
                  'Rest on your rest days to raise it; it falls if you stop training '
                  'or never rest.',
            ),
            const SizedBox(height: 8),
            _InfoLine(
              text:
                  'LCK is consistency — your training streak. Each of the 4 diamonds '
                  'is an XP-multiplier tier (up to x3), also shown beside the XP bar.',
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
              Image.asset(
                RadarStatIcons.statsBuild,
                key: const ValueKey('stat_card_header_icon'),
                width: 22,
                height: 22,
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
          StatRadar(stats: widget.stats, height: 172),
          const SizedBox(height: 12),
          _StatusReadLine(
            buildMeaning: _buildReadMeaning(),
            vitalityMeaning: _vitalityRead(),
          ),
          const SizedBox(height: 12),
          // Recovery and Consistency are different categories from the
          // capability triangle — their own rows, not graded D->S.
          _RecoveryRow(value: _value('VIT')),
          const SizedBox(height: 9),
          _LuckRow(
            value: _value('LCK'),
            filled: XpService.lckDiamondCount(_value('LCK')),
          ),
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        const Divider(height: 1, color: kBorder),
                        const SizedBox(height: 8),
                        const _RadarMeaningLegend(),
                        const SizedBox(height: 8),
                        _NextGradeLine(label: _nextGradeLabel()),
                        const SizedBox(height: 8),
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

class _RadarMeaningLegend extends StatelessWidget {
  const _RadarMeaningLegend();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'STR means ${StatRadarRead.meaningForAxis('STR')}. '
          'AGI means ${StatRadarRead.meaningForAxis('AGI')}. '
          'END means ${StatRadarRead.meaningForAxis('END')}.',
      child: Text.rich(
        TextSpan(
          children: [
            _legendSpan('STR', StatRadarRead.meaningForAxis('STR')),
            _separatorSpan(),
            _legendSpan('AGI', StatRadarRead.meaningForAxis('AGI')),
            _separatorSpan(),
            _legendSpan('END', StatRadarRead.meaningForAxis('END')),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  TextSpan _legendSpan(String stat, String meaning) {
    return TextSpan(
      children: [
        TextSpan(
          text: stat,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7,
            color: kMutedText,
          ),
        ),
        TextSpan(
          text: ' $meaning',
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  TextSpan _separatorSpan() {
    return TextSpan(
      text: '  /  ',
      style: AppFonts.shareTechMono(
        color: kDim,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StatusReadLine extends StatelessWidget {
  const _StatusReadLine({
    required this.buildMeaning,
    required this.vitalityMeaning,
  });

  final String buildMeaning;
  final String vitalityMeaning;

  @override
  Widget build(BuildContext context) {
    final buildColor = buildMeaning == 'BALANCED' ? kText : kNeon;
    final vitColor = vitalityMeaning == 'LOW VITALITY' ? kMutedText : kNeon;

    return Semantics(
      label: 'Character status $buildMeaning, $vitalityMeaning',
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'STATUS: ',
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: buildMeaning,
              style: AppFonts.shareTechMono(
                color: buildColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: ' - ',
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: vitalityMeaning,
              style: AppFonts.shareTechMono(
                color: vitColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

class _NextGradeLine extends StatelessWidget {
  const _NextGradeLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppFonts.shareTechMono(
          color: kMutedText,
          fontSize: 11,
          height: 1.2,
        ),
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
          valueColor: kText,
          rank: rank,
          rankColor: rankColor,
          valueKey: ValueKey('stat_card_${stat}_value'),
          rankKey: ValueKey('stat_card_${stat}_rank'),
        ),
      ],
    );
  }
}

/// VIT recovery meter — a 0–100 balance gauge, not a graded capability stat.
/// Fills red-deepening with the value, mirroring the recovery heart icon.
class _RecoveryRow extends StatelessWidget {
  const _RecoveryRow({required this.value});

  final int value; // 0–100

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _statusLabelWidth,
          child: _StatusLabel(
            label: 'VIT',
            icon: RadarStatIcon(
              key: const ValueKey('stat_card_vit_icon'),
              assetPath: RadarStatIcons.vitalityForValue(value),
              size: 14,
              semanticLabel: 'Vitality',
            ),
          ),
        ),
        Expanded(child: _VitalityTintedBar(value: value)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: _statVisualValueGap),
            SizedBox(
              width: _statValueWidth,
              child: Text(
                '$value',
                key: const ValueKey('stat_card_vit_value'),
                textAlign: TextAlign.right,
                style: AppFonts.shareTechMono(
                  color: kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: _statValueRankGap),
            SizedBox(
              width: _statRankWidth,
              child: Text(
                'REC',
                key: const ValueKey('stat_card_vit_rec'),
                textAlign: TextAlign.right,
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// LCK consistency — the 4-diamond row where each filled diamond is an
/// XP-multiplier tier (25/50/75/100 streak → x1.5 / x2 / x2.5 / x3).
class _LuckRow extends StatelessWidget {
  const _LuckRow({required this.value, required this.filled});

  final int value; // streak (LCK)
  final int filled; // diamonds 0–4

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _statusLabelWidth,
          child: const _PlainStatusLabel(label: 'LCK'),
        ),
        Expanded(
          child: Text(
            List.generate(4, (i) => i < filled ? '◆' : '◇').join(),
            style: const TextStyle(
              color: kAmber,
              fontSize: 14,
              letterSpacing: 3,
            ),
          ),
        ),
        _StatTrailing(
          value: value,
          valueColor: kAmber,
          valueKey: const ValueKey('stat_card_lck_value'),
        ),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.icon});

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: kText,
          ),
        ),
      ],
    );
  }
}

class _PlainStatusLabel extends StatelessWidget {
  const _PlainStatusLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
        color: kText,
      ),
    );
  }
}

class _VitalityTintedBar extends StatelessWidget {
  const _VitalityTintedBar({required this.value});

  final int value;

  double get _fillFraction => (value.clamp(0, 100) / 100).toDouble();

  // Recovery red: a muted dark red at low recovery deepening to vivid kDanger as
  // the meter fills — mirroring the heart icon, which fills red bottom-up. Alpha
  // also rises with the value so a fuller meter reads more intense.
  double get _fillAlpha => (0.6 + 0.4 * _fillFraction).clamp(0.0, 1.0);

  Color get _fillColor =>
      Color.lerp(const Color(0xFF7A1E32), kDanger, _fillFraction)!
          .withValues(alpha: _fillAlpha);

  @override
  Widget build(BuildContext context) {
    const height = 10.0;

    return Container(
      key: const ValueKey('stat_card_vit_tinted_bar'),
      height: height,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.22),
        border: Border.all(
          color: _fillFraction > 0
              ? kMutedText.withValues(alpha: 0.72)
              : kBorder.withValues(alpha: 0.62),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          key: const ValueKey('stat_card_vit_fill_fraction'),
          widthFactor: _fillFraction,
          // heightFactor: 1 forces the childless ColoredBox to the full bar
          // height — without it the fill collapses to zero height (invisible).
          heightFactor: 1,
          child: ColoredBox(
            key: const ValueKey('stat_card_vit_fill'),
            color: _fillFraction > 0 ? _fillColor : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _StatTrailing extends StatelessWidget {
  const _StatTrailing({
    required this.value,
    required this.valueColor,
    this.rank,
    this.rankColor,
    this.valueKey,
    this.rankKey,
  });

  final int value;
  final Color valueColor;
  final String? rank;
  final Color? rankColor;
  final Key? valueKey;
  final Key? rankKey;

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
            key: valueKey,
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
                    key: rankKey,
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
