import 'package:flutter/material.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// One program day as an info card: DAY N + focus summary + its prescribed lifts
/// (name + sets×reps). Shared by the Programs detail page (swap-enabled) and the
/// onboarding program preview (read-only).
///
/// Passing [onSwapRequested] turns each lift row into a tappable swap affordance
/// (the detail-page behavior); omitting it — the default — renders a plain,
/// read-only list: info, no adjustment surfaced. Keeping ONE widget for both
/// surfaces stops the two from drifting apart.
class ProgramDayCard extends StatelessWidget {
  const ProgramDayCard({
    super.key,
    required this.day,
    required this.exerciseNames,
    this.swaps = const {},
    this.onSwapRequested,
    this.onRevert,
  });

  final ProgramDay day;
  final Map<String, String> exerciseNames;

  /// originalId → replacementId for this program. A row whose id is a key shows
  /// the replacement and (when swapping is allowed) a revert affordance.
  final Map<String, String> swaps;

  /// Tap handler to replace [originalId]. Null = **read-only** (no swap icon, the
  /// rows are not tappable) — the onboarding preview path.
  final ValueChanged<String>? onSwapRequested;
  final ValueChanged<String>? onRevert;

  bool get _allowSwap => onSwapRequested != null;

  @override
  Widget build(BuildContext context) {
    final color = day.isWorkout ? kNeon : kMutedText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: day.isWorkout ? kBorder : kBorderDark),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'DAY ${day.dayNumber}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: kMutedText,
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                child: Text(
                  day.label,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          Text(
            programDayFocusSummary(day),
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
          ),
          if (day.suggestedExerciseIds.isNotEmpty) ...[
            const SizedBox(height: kSpace2),
            for (final id in day.suggestedExerciseIds.take(6)) _exerciseRow(id),
          ],
        ],
      ),
    );
  }

  Widget _exerciseRow(String id) {
    final effectiveId = swaps[id] ?? id;
    final swapped = swaps.containsKey(id);
    final name = exerciseNames[effectiveId] ?? effectiveId.replaceAll('_', ' ');
    final scheme = day.prescription[id];
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '- $name',
                  style: AppFonts.shareTechMono(color: kText, fontSize: 12),
                ),
                if (swapped)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'SWAPPED · was '
                      '${exerciseNames[id] ?? id.replaceAll('_', ' ')}',
                      style: AppFonts.shareTechMono(color: kNeon, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          if (scheme != null) ...[
            const SizedBox(width: kSpace2),
            Text(
              scheme.label(),
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
          ],
          if (_allowSwap) ...[
            const SizedBox(width: kSpace2),
            if (swapped)
              GestureDetector(
                onTap: () => onRevert?.call(id),
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.undo_sharp, size: 15, color: kMutedText),
              )
            else
              const Icon(Icons.swap_horiz_sharp, size: 15, color: kMutedText),
          ],
        ],
      ),
    );
    if (!_allowSwap) return row;
    return InkWell(onTap: () => onSwapRequested?.call(id), child: row);
  }
}
