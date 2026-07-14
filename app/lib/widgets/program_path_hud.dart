import 'package:flutter/material.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_bar.dart';
import 'arcade_card.dart';

class ProgramPathHud extends StatelessWidget {
  const ProgramPathHud({
    super.key,
    required this.program,
    required this.progress,
    this.compact = false,
    this.showReward = true,
    this.showStateLabel = true,
  });

  final Program program;
  final ProgramProgress progress;
  final bool compact;
  final bool showReward;

  /// The leading eyebrow ("CURRENT PATH" / "PATH PROGRESS" / "FINAL STRETCH" /
  /// "PATH COMPLETE"). Hidden where a surface already supplies its own header
  /// (the Program Detail page) so the title is never duplicated.
  final bool showStateLabel;

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
    if (_done <= 0) return 'CURRENT PATH';
    if (_finalStretch) return 'FINAL STRETCH';
    return 'PATH PROGRESS';
  }

  String get _countLabel {
    final target = _target;
    if (_complete) return 'PATH COMPLETE · $_done / $target';
    if (_done <= 0) return '0 / $target';
    if (_finalStretch) return 'FINAL STRETCH · $_done / $target';
    return '$_done / $target';
  }

  // The state label is an eyebrow — muted in the normal state so the neon stays
  // on the bar fill (the one interior focal element). Amber only when the state
  // is *earned* (FINAL STRETCH / PATH COMPLETE), where the colour-shift is the
  // signal. (The bar accent is computed separately, below.)
  Color get _labelColor {
    if (_complete || _finalStretch) return kAmber;
    return kMutedText;
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
      // The PATH zone — the *primary* common-region panel, via the canonical
      // ArcadeCard so it shares one system with the (lighter) NEXT zone.
      child: ArcadeCard(
        key: const ValueKey('program_path_hud'),
        background: kCard,
        backgroundAlpha: compact ? 0.52 : 0.72,
        borderColor: borderColor,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStateLabel) ...[
              Text(
                _stateLabel,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: compact ? 7.5 : 9,
                  color: _labelColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: kSpace3),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: [
                ArcadeBar(
                  value: _ratio,
                  height: meterHeight,
                  accent: _complete || _finalStretch ? kAmber : kNeon,
                  flashOnIncrease: !reduceMotion && _done > 0,
                  increaseSignal: _done,
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
            Text(
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
                      // Concise — the lock + the path panel context already say
                      // "the reward for this path, locked until 100%".
                      'REWARD',
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
