import 'package:flutter/material.dart';

import '../../data/programs_library.dart';
import '../../models/calibration_quiz_models.dart';
import '../../models/character_draft.dart';
import '../../models/program_models.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/motion/hold_depress.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/session_projection.dart';
import '../../widgets/weekday_picker.dart';
import 'name_screen.dart';

/// A sensible, evenly-spread default weekday anchor for a program of [days]
/// sessions/week, used to seed the onboarding weekday step from the chosen
/// program's cadence (the user can still adjust).
const _weekdaySpreadByCount = <int, Set<int>>{
  1: {1},
  2: {1, 4},
  3: {1, 3, 5},
  4: {1, 2, 4, 5},
  5: {1, 2, 3, 4, 5},
  6: {1, 2, 3, 4, 5, 6},
};

Set<int> seedTrainingWeekdays(int daysPerWeek) => Set<int>.from(
  _weekdaySpreadByCount[daysPerWeek.clamp(1, 6)] ?? const {1, 3, 5},
);

class ProgramSelectionPage extends StatefulWidget {
  const ProgramSelectionPage({super.key, required this.draft});

  final CharacterDraft draft;

  @override
  State<ProgramSelectionPage> createState() => _ProgramSelectionPageState();
}

class _ProgramSelectionPageState extends State<ProgramSelectionPage> {
  late String _selectedProgramId = recommendedProgramIdFor(
    widget.draft.calibration,
  );

  late Set<int> _trainingWeekdays = seedTrainingWeekdays(
    programById(_selectedProgramId)?.daysPerWeek ?? 3,
  );
  // Once the user edits weekdays, stop re-seeding them when they switch program.
  bool _weekdaysTouched = false;

  bool _committing = false;

  void _selectProgram(String id) {
    setState(() {
      _selectedProgramId = id;
      if (!_weekdaysTouched) {
        _trainingWeekdays = seedTrainingWeekdays(
          programById(id)?.daysPerWeek ?? 3,
        );
      }
    });
  }

  /// Recommended program first (seen on load, no scroll), then the rest in
  /// library order.
  List<Program> _orderedPrograms(String recommendedId) => [
    for (final p in programsLibrary) if (p.id == recommendedId) p,
    for (final p in programsLibrary) if (p.id != recommendedId) p,
  ];

  Future<void> _editTrainingDays(Program program) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      builder: (_) => _TrainingDaysSheet(
        initial: _trainingWeekdays,
        program: program,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _trainingWeekdays = result;
        _weekdaysTouched = true;
      });
    }
  }

  Future<void> _continue({required bool withProgram}) async {
    if (_committing) return;
    setState(() => _committing = true);

    final nextDraft = widget.draft.copyWith(
      selectedProgramId: withProgram ? _selectedProgramId : null,
      trainingWeekdays: withProgram ? _trainingWeekdays : null,
    );
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => NameScreen(draft: nextDraft),
        motion: ArcadeRouteMotion.flow,
      ),
    );
    if (mounted) setState(() => _committing = false);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.draft.calibration;
    final recommendedId = recommendedProgramIdFor(result);
    final selectedProgram = programById(_selectedProgramId);

    // Point of no return: the spent quiz no longer sits beneath this route, so
    // the back chevron is gone and the Android back gesture is absorbed —
    // backing out here used to land on a dead (re-entrancy-locked) quiz question.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: kSpace4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    kSpace4,
                    kSpace3,
                    kSpace4,
                    kSpace4,
                  ),
                  children: [
                    const Text(
                      'YOUR FIRST PATH',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        color: kNeon,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    Text(
                      'Recommended from: ${trainingRhythmLabel(result.freq)} - ${result.exp.name}',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: kSpace5),
                    // Recommended program first, so the auto-selection is seen on
                    // load without scrolling (the rest keep library order).
                    for (final program in _orderedPrograms(recommendedId)) ...[
                      _ProgramSelectionCard(
                        program: program,
                        selected: program.id == _selectedProgramId,
                        recommended: program.id == recommendedId,
                        onTap: () => _selectProgram(program.id),
                      ),
                      const SizedBox(height: kSpace3),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  kSpace4,
                  kSpace3,
                  kSpace4,
                  kSpace5 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: const BoxDecoration(
                  color: kBg,
                  border: Border(top: BorderSide(color: kBorder)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedProgram == null
                          ? 'No program selected'
                          : '${selectedProgram.daysPerWeek} days/week - ${selectedProgram.recommendedWeeks} weeks',
                      textAlign: TextAlign.center,
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 12,
                      ),
                    ),
                    if (selectedProgram != null) ...[
                      const SizedBox(height: kSpace3),
                      _TrainingDaysSummary(
                        weekdays: _trainingWeekdays,
                        onTap: () => _editTrainingDays(selectedProgram),
                      ),
                    ],
                    const SizedBox(height: kSpace3),
                    PixelButton(
                      label: 'START THIS PATH',
                      minHeight: 56,
                      fontSize: 13,
                      powerOn: true,
                      onPressed: _committing
                          ? null
                          : () => _continue(withProgram: true),
                    ),
                    const SizedBox(height: kSpace2),
                    PixelButton(
                      label: 'TRAIN MANUALLY',
                      secondary: true,
                      onPressed: _committing
                          ? null
                          : () => _continue(withProgram: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramSelectionCard extends StatelessWidget {
  const _ProgramSelectionCard({
    required this.program,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final Program program;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? kNeon : kBorder;
    return Semantics(
      button: true,
      selected: selected,
      label: '${program.name} program',
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kMotionFast,
          curve: kMotionCurve,
          padding: const EdgeInsets.all(kSpace4),
          decoration: BoxDecoration(
            color: selected ? kSurface2 : kCard,
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(kCardRadius),
            boxShadow: selected ? neonGlow(opacity: 0.12, blur: 12) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      program.name,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 12,
                        color: selected ? kNeon : kText,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  _TinyBadge(
                    label: recommended ? 'RECOMMENDED' : _tierLabel(program),
                    color: recommended ? kAmber : kMutedText,
                  ),
                ],
              ),
              const SizedBox(height: kSpace3),
              Text(
                program.description,
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: kSpace3),
              _SchedulePreview(program: program, selected: selected),
              const SizedBox(height: kSpace3),
              Text(
                '${program.daysPerWeek} sessions/week - ${program.targetSessions} workouts to forge the path',
                style: AppFonts.shareTechMono(
                  color: selected ? kText : kMutedText,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tierLabel(Program program) {
    if (program.tier == 'INTERMEDIATE/ADVANCED') return 'INT/ADV';
    return program.tier;
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.program, required this.selected});

  final Program program;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in program.weekSchedule) ...[
          Expanded(
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: day.isWorkout
                    ? (selected ? kNeonDark.withValues(alpha: 0.28) : kBg)
                    : kBorderDark,
                border: Border.all(
                  color: day.isWorkout
                      ? (selected ? kNeon : kBorderVariant)
                      : kBorder,
                ),
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Text(
                programDayAbbreviation(day),
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: day.isWorkout ? (selected ? kNeon : kMutedText) : kDim,
                ),
              ),
            ),
          ),
          if (day.dayNumber < 7) const SizedBox(width: kSpace1),
        ],
      ],
    );
  }
}

const _weekdayAbbrev = {
  1: 'MON',
  2: 'TUE',
  3: 'WED',
  4: 'THU',
  5: 'FRI',
  6: 'SAT',
  7: 'SUN',
};

String _weekdaysLabel(Set<int> weekdays) {
  final days = weekdays.toList()..sort();
  return days.map((d) => _weekdayAbbrev[d] ?? '').join('·');
}

/// Always-visible, compact "training days" affordance pinned above the CTA. Shows
/// the current pick and opens the editor on tap — so the optional weekday step is
/// discoverable without scrolling, while START THIS PATH stays an honest advance.
class _TrainingDaysSummary extends StatelessWidget {
  const _TrainingDaysSummary({required this.weekdays, required this.onTap});

  final Set<int> weekdays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Training days, ${_weekdaysLabel(weekdays)}, edit',
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3,
            vertical: kSpace3,
          ),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_target.png'),
                size: 16,
                color: kMutedText,
              ),
              const SizedBox(width: kSpace2),
              const Text(
                'TRAINING DAYS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: kMutedText,
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                child: Text(
                  _weekdaysLabel(weekdays),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(color: kNeon, fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_sharp, size: 18, color: kMutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// The onboarding weekday editor (bottom sheet). Pops the chosen set, or null on
/// dismiss. Applied immediately at character creation (no next-Monday pending).
class _TrainingDaysSheet extends StatefulWidget {
  const _TrainingDaysSheet({required this.initial, required this.program});

  final Set<int> initial;
  final Program program;

  @override
  State<_TrainingDaysSheet> createState() => _TrainingDaysSheetState();
}

class _TrainingDaysSheetState extends State<_TrainingDaysSheet> {
  late Set<int> _local = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final valid = _local.isNotEmpty && _local.length < 7;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace4,
          kSpace4,
          kSpace4,
          kSpace4 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'WHEN WILL YOU TRAIN?',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: kNeon,
                height: 1.35,
              ),
            ),
            const SizedBox(height: kSpace3),
            Text(
              'Pick your training days. The rest become recovery — change it any time in Settings.',
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: kSpace4),
            WeekdayPicker(
              selected: _local,
              onToggle: (weekday) {
                setState(() {
                  if (_local.contains(weekday)) {
                    _local = {..._local}..remove(weekday);
                  } else {
                    _local = {..._local}..add(weekday);
                  }
                });
              },
            ),
            const SizedBox(height: kSpace4),
            SessionProjection(selected: _local, program: widget.program),
            const SizedBox(height: kSpace3),
            Text(
              valid
                  ? 'These days anchor your sessions from week one.'
                  : 'Choose at least one training day and one rest day.',
              style: TextStyle(
                color: valid ? kMutedText : kAmber,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: kSpace4),
            PixelButton(
              label: 'DONE',
              minHeight: 52,
              onPressed: valid ? () => Navigator.of(context).pop(_local) : null,
            ),
          ],
        ),
      ),
    );
  }
}

String recommendedProgramIdFor(CalibrationResult result) {
  if (result.freq == TrainingFreq.high || result.exp == Experience.advanced) {
    return 'ppl';
  }
  if (result.freq == TrainingFreq.low || result.exp == Experience.novice) {
    return 'full_body_3x';
  }
  return 'upper_lower';
}

String trainingRhythmLabel(TrainingFreq freq) => switch (freq) {
  TrainingFreq.low => '2-3 days',
  TrainingFreq.mid => '4-5 days',
  TrainingFreq.high => '6+ days',
};
