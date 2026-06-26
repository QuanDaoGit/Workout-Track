import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_tap.dart';

/// A white section label with a small green action link on its right, sat
/// directly above a Home section card.
///
/// Replaces the three inconsistent in-card "VIEW >" affordances (Expedition /
/// Last Workout / Quests) with one shared, role-legible header: the white
/// PressStart2P title names the section (a clear tier-1 cue, distinct from the
/// card's own muted/state-bearing chrome), and the green mono link is a
/// labelled secondary door. The card beneath stays the primary tap target for
/// the same destination, so the link is a convenience shortcut, never the only
/// way in.
///
/// The action link is a real [Semantics] button (one announcement, the arrow
/// stripped from the label); its hit area is padded out left + vertically. It
/// carries no motion, so it is already a still, legible control under reduced
/// motion.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                height: 1.4,
                color: kText,
              ),
            ),
          ),
          if (hasAction)
            Semantics(
              button: true,
              label: '$title, ${actionLabel!.replaceAll('>', '').trim()}',
              excludeSemantics: true,
              child: ArcadeTap(
                onTap: onAction,
                borderRadius: BorderRadius.circular(kCardRadius),
                // Asymmetric pad: left + vertical grow the tap target; the right
                // edge stays flush so the link right-aligns with the card body.
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: kSpace4,
                    top: kSpace2,
                    bottom: kSpace2,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppFonts.shareTechMono(
                      color: kNeon,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
