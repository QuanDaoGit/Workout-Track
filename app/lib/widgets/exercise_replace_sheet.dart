import 'package:flutter/material.dart';

import '../data/exercise_alternatives.dart';
import '../models/workout_models.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'exercise_card.dart';
import 'pixel_button.dart';

/// Outcome of the Replace sheet: either a chosen [replacement] (swap in place)
/// or [seeAll] = open the full curated picker. Null pop = dismissed, no change.
class ExerciseReplaceResult {
  const ExerciseReplaceResult.swap(Exercise this.replacement) : seeAll = false;
  const ExerciseReplaceResult.seeAll() : replacement = null, seeAll = true;

  final Exercise? replacement;
  final bool seeAll;
}

/// Card-level Replace sheet: strong, slot-equivalent swaps under "REPLACE WITH",
/// weak same-muscle top-ups under "MORE FOR THIS MUSCLE" (kept distinct so a
/// loose match is never framed as equivalent), with "SEE ALL" always available
/// as the escape hatch — including when there are no ranked alternatives at all.
Future<ExerciseReplaceResult?> showExerciseReplaceSheet(
  BuildContext context, {
  required Exercise replaced,
  required ExerciseAlternatives alternatives,
}) {
  return showModalBottomSheet<ExerciseReplaceResult>(
    context: context,
    backgroundColor: kCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      side: BorderSide(color: kBorder),
    ),
    builder: (ctx) => _ReplaceSheet(replaced: replaced, alternatives: alternatives),
  );
}

class _ReplaceSheet extends StatelessWidget {
  const _ReplaceSheet({required this.replaced, required this.alternatives});

  final Exercise replaced;
  final ExerciseAlternatives alternatives;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace2),
              child: Text(
                'REPLACE: ${replaced.name.toUpperCase()}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kNeon,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (alternatives.strong.isNotEmpty) ...[
                      const _SectionLabel('REPLACE WITH'),
                      for (final exercise in alternatives.strong)
                        _option(context, exercise),
                    ],
                    if (alternatives.more.isNotEmpty) ...[
                      const _SectionLabel('MORE FOR THIS MUSCLE'),
                      for (final exercise in alternatives.more)
                        _option(context, exercise),
                    ],
                    if (alternatives.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: kSpace3),
                        child: Text(
                          'No close matches — browse the full list.',
                          style: AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: PixelButton(
                label: 'SEE ALL EXERCISES',
                secondary: true,
                onPressed: () => Navigator.pop(
                  context,
                  const ExerciseReplaceResult.seeAll(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, Exercise exercise) {
    return ExerciseCard(
      exercise: exercise,
      showCheckbox: false,
      showFavorite: false,
      showArrow: true,
      isCustom: exercise.isCustom,
      onTap: () => Navigator.pop(
        context,
        ExerciseReplaceResult.swap(exercise),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: kSpace2, bottom: kSpace2),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: kMutedText,
        ),
      ),
    );
  }
}
