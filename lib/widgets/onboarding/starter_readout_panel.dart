import 'package:flutter/material.dart';

import '../../data/class_definitions.dart';
import '../../data/programs_library.dart';
import '../../models/character_class.dart';
import '../../models/character_draft.dart';
import '../../models/program_models.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../companion/bit_mood_core.dart';
import '../motion/hold_depress.dart';

/// Single-letter week strip labels (Mon..Sun) for the compact day pips.
const _weekdayLetters = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};

/// The onboarding "starter readout" — a faced, living BIT presents the plan the
/// app *recommended* from the user's quiz answers, right before the irreversible
/// naming commit. Framed as a **reversible recommendation** (BIG "Your program
/// is built, warrior." + "Tap to edit"), never an owned/assigned identity — the
/// whole card taps back to program selection to change it (`onEdit`). Body-neutral:
/// class is identity *flavor* (one accent), program + days are the plan; no
/// scores/ranks/weights. See research/insights.md (onboarding "build" panel).
class StarterReadoutPanel extends StatelessWidget {
  const StarterReadoutPanel({
    super.key,
    required this.draft,
    required this.onEdit,
  });

  final CharacterDraft draft;

  /// Routes back to program selection to change the plan (the reversibility the
  /// recommendation framing requires). Wired to the same pop the back chevron uses.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final clazz = draft.calibration.clazz;
    final program = programById(draft.selectedProgramId ?? '');
    final hasProgram = program != null;
    final weekdays = draft.trainingWeekdays;
    final headline = hasProgram
        ? 'Your program is built, warrior.'
        : 'Your path is set, warrior.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // BIT, alive (idle float + plate breathing; snaps + freezes under
        // reduced motion), delivering the moment beside the BIG headline.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ExcludeSemantics(
              child: BitMoodCore(pose: BitPose.neutral, reveal: 1, size: 60),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      height: 1.6,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: kSpace2),
                  Text(
                    'Tap to edit',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpace3),
        Semantics(
          button: true,
          excludeSemantics: true,
          label:
              'Starter plan. Class ${clazz.displayName}. '
              '${hasProgram ? 'Program ${program.name}, ${program.daysPerWeek} days per week' : 'Manual training'}. '
              'Tap to edit.',
          child: HoldDepress(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(kCardRadius),
            child: Container(
              padding: const EdgeInsets.all(kSpace4),
              decoration: BoxDecoration(
                color: kCard,
                border: Border.all(
                  color: kNeon.withValues(alpha: 0.45),
                  width: kPrimaryCardBorderWidth,
                ),
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  _divider(),
                  _classRow(clazz),
                  _divider(),
                  _programRow(program),
                  if (hasProgram &&
                      weekdays != null &&
                      weekdays.isNotEmpty) ...[
                    _divider(),
                    _daysRow(weekdays),
                  ],
                  const SizedBox(height: kSpace3),
                  Text(
                    '▸ Tuned to your goal, experience & schedule',
                    style: AppFonts.shareTechMono(color: kDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Text(
          'STARTER PLAN',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            letterSpacing: 1.5,
            color: kMutedText,
          ),
        ),
        const Spacer(),
        Text(
          'EDIT',
          style: AppFonts.shareTechMono(
            color: kNeon,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Icon(Icons.chevron_right_sharp, size: 16, color: kNeon),
      ],
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: kSpace3),
    child: SizedBox(
      height: 1,
      child: DecoratedBox(decoration: BoxDecoration(color: kBorderDark)),
    ),
  );

  Widget _classRow(CharacterClass clazz) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 3, height: 38, color: clazz.themeColor),
        const SizedBox(width: kSpace3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clazz.displayName,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 13,
                  height: 1.3,
                  color: clazz.themeColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                focusMusclesLabel(clazz),
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
              ),
            ],
          ),
        ),
        _tag('CLASS'),
      ],
    );
  }

  Widget _programRow(Program? program) {
    final hasProgram = program != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Indent to align with the class row's text (3px accent + gap).
        const SizedBox(width: 3 + kSpace3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasProgram ? program.name : 'MANUAL TRAINING',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  height: 1.35,
                  color: kText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasProgram
                    ? '${program.daysPerWeek} days/week · ${program.recommendedWeeks} weeks'
                    : 'log freely — no fixed plan',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
              ),
            ],
          ),
        ),
        _tag('PROGRAM'),
      ],
    );
  }

  Widget _daysRow(Set<int> weekdays) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 3 + kSpace3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRAINING DAYS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  letterSpacing: 1,
                  color: kMutedText,
                ),
              ),
              const SizedBox(height: kSpace2),
              Row(
                children: [
                  for (var d = 1; d <= 7; d++) ...[
                    Expanded(
                      child: _pip(d, weekdays.contains(d)),
                    ),
                    if (d < 7) const SizedBox(width: kSpace1),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pip(int day, bool active) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? kNeon.withValues(alpha: 0.15) : kBorderDark,
        border: Border.all(color: active ? kNeon : kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        _weekdayLetters[day]!,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: active ? kNeon : kDim,
        ),
      ),
    );
  }

  Widget _tag(String label) => Text(
    label,
    style: const TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: 7,
      letterSpacing: 1,
      color: kDim,
    ),
  );
}
