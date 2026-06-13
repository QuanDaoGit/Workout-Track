import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/shadow_models.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../avatar/ghost_avatar.dart';
import 'shadow_radar.dart';

/// Guild-tab Shadow arena: ghost avatar, plain-language drivers, the dual
/// contest radar, per-axis reads, and reward state. Intimate (you vs you) —
/// pinned above the NPC roster, never inside it.
class ShadowDetail extends StatelessWidget {
  const ShadowDetail({
    super.key,
    required this.evaluation,
    required this.avatarSpec,
  });

  final ShadowEvaluation evaluation;
  final AvatarSpec avatarSpec;

  @override
  Widget build(BuildContext context) {
    final eval = evaluation;
    final live =
        eval.status != ShadowStatus.locked &&
        eval.status != ShadowStatus.forming;
    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder, width: kPrimaryCardBorderWidth),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'YOUR SHADOW',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: kCyan,
                  ),
                ),
              ),
              if (eval.provisional && live)
                Text(
                  'FORMING — EXPERIMENTAL',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 9,
                    letterSpacing: 1.1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: eval.status == ShadowStatus.locked ? 0.35 : 1,
                child: GhostAvatar(spec: avatarSpec, size: 60),
              ),
              const SizedBox(width: kSpace4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _driverLine(
                      context,
                      color: kCyan,
                      label: 'SHADOW — your steady last month',
                    ),
                    const SizedBox(height: kSpace2),
                    _driverLine(
                      context,
                      color: kNeon,
                      label: 'YOU — your last 10 days',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!live) ...[
            const SizedBox(height: kSpace3),
            Text(
              eval.status == ShadowStatus.locked
                  ? 'Something is forming. Keep training — it takes shape '
                        'after ${_remainingLabel(eval.completedSessions)}.'
                  : 'Your Shadow is taking shape. It needs a month of '
                        'training behind it to hold a baseline.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: kMutedText, height: 1.4),
            ),
          ] else ...[
            ShadowRadar(axes: eval.axes),
            const SizedBox(height: kSpace2),
            for (final read in eval.axes) _axisRow(context, read),
            const SizedBox(height: kSpace3),
            _statusBanner(context),
          ],
        ],
      ),
    );
  }

  String _remainingLabel(int completed) {
    final remaining = 6 - completed;
    return remaining <= 1 ? '1 more session' : '$remaining more sessions';
  }

  Widget _driverLine(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Text(
            label,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _axisRow(BuildContext context, ShadowAxisRead read) {
    final (label, color) = switch (read.state) {
      ShadowAxisState.ahead => ('AHEAD', kNeon),
      ShadowAxisState.close => ('CLOSE', kAmber),
      ShadowAxisState.behind => ('BEHIND', kDanger),
      ShadowAxisState.forming => ('FORMING', kMutedText),
    };
    final ratio = read.ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace1),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${read.axis} ',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kText,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppFonts.shareTechMono(
                color: color,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              ratio == null
                  ? '—'
                  : '${(ratio * 100).round()}% of your month pace',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(BuildContext context) {
    final eval = evaluation;
    final (line, color) = switch (eval.status) {
      ShadowStatus.defeated when eval.titleEarnedNow => (
        'SHADOW DEFEATED — TITLE EARNED: SHADOWBANE',
        kNeon,
      ),
      ShadowStatus.defeated => ('SHADOW DEFEATED THIS WEEK', kNeon),
      ShadowStatus.faded => (
        'YOUR SHADOW HAS FADED — REBUILD. IT REMEMBERS MORE OF YOU.',
        kMutedText,
      ),
      _ when eval.gapClosing => ('GAP CLOSING — KEEP PUSHING', kAmber),
      _ when eval.headline != null => (eval.headline!, kDanger),
      _ => ('DEAD HEAT — HOLD THE PACE', kCyan),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace2),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.5),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        line,
        style: AppFonts.shareTechMono(
          color: color,
          fontSize: 10,
          letterSpacing: 1.1,
          height: 1.4,
        ),
      ),
    );
  }
}
