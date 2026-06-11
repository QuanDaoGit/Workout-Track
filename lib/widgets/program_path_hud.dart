import 'package:flutter/material.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_progress_bar.dart';

class ProgramPathHud extends StatelessWidget {
  const ProgramPathHud({
    super.key,
    required this.program,
    required this.progress,
    this.compact = false,
    this.showReward = true,
  });

  final Program program;
  final ProgramProgress progress;
  final bool compact;
  final bool showReward;

  int get _target => program.targetSessions;

  int get _done {
    final target = _target;
    if (target <= 0) return progress.arcSessions;
    return progress.arcSessions.clamp(0, target);
  }

  double get _ratio {
    final target = _target;
    if (target <= 0) return 0;
    return (_done / target).clamp(0.0, 1.0);
  }

  bool get _complete =>
      progress.completedArc || (_target > 0 && _done >= _target);

  bool get _finalStretch => !_complete && _ratio >= 0.75;

  LootItem? get _reward {
    final titleId = titleIdForProgram(program.id);
    return titleId == null ? null : lootItemById(titleId);
  }

  String get _stateLabel {
    if (_complete) return 'PATH COMPLETE';
    if (_done <= 0) return 'PATH SET';
    if (_finalStretch) return 'FINAL STRETCH';
    return 'PATH PROGRESS';
  }

  String get _countLabel {
    final target = _target;
    if (_complete) return 'PATH COMPLETE · $_done / $target';
    if (_done <= 0) return 'PATH SET · 0 / $target';
    if (_finalStretch) return 'FINAL STRETCH · $_done / $target';
    return '$_done / $target';
  }

  Color get _accent {
    if (_complete || _finalStretch) return kAmber;
    return kNeon;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final reward = _reward;
    final padding = compact ? kSpace3 : kSpace4;
    final borderColor = _complete
        ? kAmber
        : _finalStretch
        ? kAmber.withValues(alpha: 0.78)
        : kBorder;
    final meterHeight = compact ? 8.0 : 10.0;

    return Semantics(
      label:
          '${program.name} path, $_done of $_target sessions, '
          '${(_ratio * 100).round()} percent complete'
          // Keep the reward name out until it's earned (anticipation).
          '${reward == null || !showReward ? '' : (_complete ? ', reward ${reward.name}' : ', reward locked')}',
      child: Container(
        key: const ValueKey('program_path_hud'),
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: kCard.withValues(alpha: compact ? 0.52 : 0.72),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _stateLabel,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: compact ? 7.5 : 9,
                color: _accent,
                height: 1.35,
              ),
            ),
            const SizedBox(height: kSpace3),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ArcadeProgressBar(
                  value: _ratio,
                  height: meterHeight,
                  fillColor: _complete || _finalStretch ? kAmber : kNeon,
                  trackColor: kBorderDark,
                  flashOnIncrease: !reduceMotion && _done > 0,
                  increaseSignal: _done,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 380),
                ),
                if (!reduceMotion && _done > 0 && !_complete)
                  Positioned.fill(
                    key: const ValueKey('program_path_sparks'),
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(
                          'program_path_sparks_${program.id}_$_done',
                        ),
                        tween: Tween(begin: 1, end: 0),
                        duration: const Duration(milliseconds: 380),
                        builder: (context, t, _) => CustomPaint(
                          painter: _PathSparkPainter(
                            ratio: _ratio,
                            progress: t,
                            color: _finalStretch ? kAmber : kNeon,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: kSpace2),
            Row(
              children: [
                if (_done <= 0) ...[
                  const _BootPip(),
                  const SizedBox(width: 4),
                  const _BootPip(),
                  const SizedBox(width: kSpace2),
                ],
                Expanded(
                  child: Text(
                    _countLabel,
                    style: compact
                        ? AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 11,
                            height: 1.2,
                          )
                        : const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: kMutedText,
                            height: 1.35,
                          ),
                  ),
                ),
              ],
            ),
            if (reward != null && showReward) ...[
              const SizedBox(height: kSpace3),
              // Revealed once earned; redacted to a teaser beforehand so the
              // name + rarity stay a surprise (motivating-uncertainty effect).
              if (_complete)
                Text(
                  'PATH REWARD: ${reward.name}',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: compact ? 7 : 8.5,
                    color: reward.rarity.color,
                    height: 1.35,
                  ),
                )
              else
                Row(
                  children: [
                    ImageIcon(
                      const AssetImage('assets/icons/control/icon_lock.png'),
                      size: compact ? 10 : 12,
                      color: kMutedText,
                    ),
                    const SizedBox(width: kSpace2),
                    Text(
                      'REWARD AT 100%',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: compact ? 7 : 8.5,
                        color: kMutedText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BootPip extends StatelessWidget {
  const _BootPip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('program_path_boot_pip'),
      width: 13,
      height: 7,
      decoration: BoxDecoration(
        color: kBorderDark,
        border: Border.all(color: kBorderVariant),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _PathSparkPainter extends CustomPainter {
  const _PathSparkPainter({
    required this.ratio,
    required this.progress,
    required this.color,
  });

  final double ratio;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = (size.width * ratio).clamp(3.0, size.width - 3);
    final paint = Paint()..color = color.withValues(alpha: 0.72 * progress);
    final offsets = [
      Offset(x + 4, -5 - (1 - progress) * 5),
      Offset(x - 7, 2 + (1 - progress) * 3),
      Offset(x + 9, size.height + 2 + (1 - progress) * 4),
    ];
    for (final offset in offsets) {
      canvas.drawRect(offset & const Size(2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathSparkPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
