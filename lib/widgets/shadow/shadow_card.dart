import 'package:flutter/material.dart';

import '../../models/avatar_spec.dart';
import '../../models/shadow_models.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../avatar/ghost_avatar.dart';

/// Compact Home callout for the Shadow — the glanceable hook. One ghost face,
/// one status line, tap-through to the Guild-tab detail (the arena).
class ShadowCard extends StatelessWidget {
  const ShadowCard({
    super.key,
    required this.evaluation,
    required this.avatarSpec,
    this.onTap,
  });

  final ShadowEvaluation evaluation;
  final AvatarSpec avatarSpec;
  final VoidCallback? onTap;

  ({String title, Color accent}) get _copy {
    switch (evaluation.status) {
      case ShadowStatus.locked:
        return (title: 'SOMETHING IS FORMING…', accent: kMutedText);
      case ShadowStatus.forming:
        return (title: 'YOUR SHADOW IS TAKING SHAPE', accent: kCyan);
      case ShadowStatus.contest:
        if (evaluation.gapClosing) {
          return (title: 'GAP CLOSING — KEEP PUSHING', accent: kAmber);
        }
        if (evaluation.headline != null) {
          return (title: evaluation.headline!, accent: kDanger);
        }
        return (title: 'DEAD HEAT WITH YOUR SHADOW', accent: kCyan);
      case ShadowStatus.defeated:
        return (title: 'SHADOW DEFEATED', accent: kNeon);
      case ShadowStatus.faded:
        return (title: 'YOUR SHADOW HAS FADED', accent: kMutedText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final locked = evaluation.status == ShadowStatus.locked;
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder, width: kPrimaryCardBorderWidth),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: locked ? 0.35 : 1,
                child: GhostAvatar(spec: avatarSpec, size: 40),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THE SHADOW',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    Text(
                      copy.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        height: 1.5,
                        color: copy.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace2),
              const Icon(Icons.chevron_right_sharp, color: kMutedText),
            ],
          ),
        ),
      ),
    );
  }
}
