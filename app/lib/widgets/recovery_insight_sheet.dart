import 'package:flutter/material.dart';

import '../data/recovery_insights.dart';
import '../services/recovery_insight_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'companion/bit_mood_core.dart';
import 'companion/bit_speech_bubble.dart';
import 'pixel_button.dart';

/// Shown once per wrap day, when the whole pool has been heard and the
/// rotation honestly restarts (spec: the "new each rest day" promise never
/// silently degrades into repeats).
const kRecoveryInsightWrapLine =
    "You've heard the full briefing. Refreshers from here.";

/// Opens BIT's rest-day recovery briefing over [context]'s navigator.
/// The caller resolves the pick first (async) so the sheet itself is pure UI.
Future<void> showRecoveryInsightSheet(
  BuildContext context,
  RecoveryInsightPick pick,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kCard,
    // Scroll-controlled + scrollable body so a large accessibility text scale
    // grows the sheet instead of overflowing it (the warmup_sheet pattern).
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
    ),
    builder: (context) => RecoveryInsightSheetContent(pick: pick),
  );
}

/// The sheet body: faced BIT delivering today's insight in the calm recovery
/// register (cyan accent, no reward mechanics, one dismiss action).
class RecoveryInsightSheetContent extends StatelessWidget {
  const RecoveryInsightSheetContent({super.key, required this.pick});

  final RecoveryInsightPick pick;

  @override
  Widget build(BuildContext context) {
    final insight = pick.insight;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RECOVERY BRIEFING',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: kRecoveryAccent,
                  ),
                ),
              ),
              // Icon-only category marker — the glyphs are self-explanatory
              // (bed/meat/bars/boots/brain); the category name survives as the
              // screen-reader label only.
              Semantics(
                label: insight.category,
                child: ImageIcon(
                  AssetImage(kRecoveryInsightCategoryIcons[insight.category] ??
                      'assets/icons/control/icon_stat.png'),
                  size: 18,
                  color: kRecoveryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BitMoodCore(size: 72, reveal: 1),
              const SizedBox(width: kSpace2),
              Expanded(
                child: BitSpeechBubble(text: insight.text),
              ),
            ],
          ),
          if (pick.poolWrapped) ...[
            const SizedBox(height: kSpace3),
            Text(
              kRecoveryInsightWrapLine,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
          ],
          const SizedBox(height: kSpace4),
          PixelButton(
            label: 'CLOSE',
            secondary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
