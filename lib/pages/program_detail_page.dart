import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/curated_exercises.dart';
import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/program_customization_service.dart';
import '../services/program_service.dart';
import '../theme/tokens.dart';
import '../widgets/pixel_button.dart';
import '../widgets/program_path_hud.dart';

class ProgramDetailPage extends StatefulWidget {
  const ProgramDetailPage({
    super.key,
    required this.program,
    required this.activeProgramId,
  });

  final Program program;
  final String? activeProgramId;

  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> {
  final ProgramService _programService = ProgramService();
  final ProgramCustomizationService _customizationService =
      ProgramCustomizationService();
  late Future<Map<String, String>> _exerciseNamesFuture;
  String? _activeProgramId;
  ProgramProgress? _activeProgress;
  Map<String, String> _swaps = const {};

  @override
  void initState() {
    super.initState();
    _activeProgramId = widget.activeProgramId;
    _exerciseNamesFuture = _loadExerciseNames();
    _loadProgress();
    _loadSwaps();
  }

  Future<void> _loadSwaps() async {
    final swaps = await _customizationService.swapsFor(widget.program.id);
    if (!mounted) return;
    setState(() => _swaps = swaps);
  }

  bool get _isActive => _activeProgramId == widget.program.id;

  Future<void> _loadProgress() async {
    final progress = await _programService.getActiveProgress();
    if (!mounted) return;
    setState(() => _activeProgress = progress);
  }

  Future<Map<String, String>> _loadExerciseNames() async {
    final exercises = await ExerciseCatalogService().getFullCatalog();
    return {for (final exercise in exercises) exercise.id: exercise.name};
  }

  /// Opens the replace sheet for the prescribed lift [originalId] on [day]. The
  /// alternatives are the day's curated muscle pool minus lifts already in the
  /// (effective) day, so a swap can never duplicate an existing exercise.
  Future<void> _openSwapSheet(
    ProgramDay day,
    String originalId,
    Map<String, String> names,
  ) async {
    final currentId = _swaps[originalId] ?? originalId;
    final present = day.suggestedExerciseIds
        .map((id) => _swaps[id] ?? id)
        .toSet();
    final options =
        curatedExerciseIdsForMuscleGroups(programDayTargetMuscleGroups(day))
            .where((id) => !present.contains(id))
            .toList();

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: kBorder),
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (_) => _SwapSheet(
        originalId: originalId,
        currentId: currentId,
        optionIds: options,
        names: names,
      ),
    );
    if (result == null || !mounted) return;
    if (result == originalId) {
      await _customizationService.removeSwap(widget.program.id, originalId);
    } else {
      await _customizationService.setSwap(
        widget.program.id,
        originalId,
        result,
      );
    }
    await _loadSwaps();
  }

  Future<void> _revertSwap(String originalId) async {
    await _customizationService.removeSwap(widget.program.id, originalId);
    await _loadSwaps();
  }

  Future<void> _startProgram() async {
    if (_activeProgramId != null && _activeProgramId != widget.program.id) {
      final current = programById(_activeProgramId!);
      final confirmed = await _confirmSwitch(current?.name ?? 'CURRENT');
      if (confirmed != true) return;
    }

    await _programService.startProgram(widget.program.id);
    if (!mounted) return;
    setState(() => _activeProgramId = widget.program.id);
    await _loadProgress();
  }

  Future<void> _quitProgram() async {
    await _programService.quitProgram();
    if (!mounted) return;
    setState(() {
      _activeProgramId = null;
      _activeProgress = null;
    });
  }

  String _pathIdentity(String programId) => switch (programId) {
    'full_body_3x' => 'The foundation path — learn the base.',
    'upper_lower' => 'The discipline path — split the work.',
    'ppl' => 'The mastery path — repeatable strength.',
    _ => 'A training path.',
  };

  LootItem? _programReward() {
    final titleId = titleIdForProgram(widget.program.id);
    return titleId == null ? null : lootItemById(titleId);
  }

  Widget _pathSection() {
    final progress = _activeProgress;
    if (progress != null && progress.programId == widget.program.id) {
      return Padding(
        padding: const EdgeInsets.only(top: kSpace4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace4),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CURRENT PATH',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kNeon,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: kSpace3),
              ProgramPathHud(program: widget.program, progress: progress),
              const SizedBox(height: kSpace3),
              Text(
                'Missed days slow the path. They do not reset it.',
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final reward = _programReward();
    if (reward == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: kSpace4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kSpace4),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PATH REWARD',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kMutedText,
                height: 1.35,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text(
              reward.name,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: reward.rarity.color,
                height: 1.35,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text(
              'Complete this path to forge the title.',
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmSwitch(String currentName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SWITCH FROM $currentName?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Progress will reset. Workout history stays saved.'),
            const SizedBox(height: kSpace4),
            PixelButton(
              label: 'CONFIRM',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: kSpace2),
            PixelButton(
              label: 'CANCEL',
              secondary: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.program.name)),
      body: FutureBuilder<Map<String, String>>(
        future: _exerciseNamesFuture,
        builder: (context, snapshot) {
          final names = snapshot.data ?? const <String, String>{};
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              kSpace4,
              kSpace4,
              kSpace4,
              kSpace5 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.program.name,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: kNeon,
                          height: 1.4,
                        ),
                      ),
                    ),
                    _TierBadge(label: widget.program.tier),
                  ],
                ),
                const SizedBox(height: kSpace3),
                Text(
                  '${widget.program.daysPerWeek} days/week - ${widget.program.recommendedWeeks} weeks',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: kSpace2),
                Text(
                  widget.program.description,
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: kSpace3),
                Text(
                  _pathIdentity(widget.program.id),
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                _pathSection(),
                const SizedBox(height: kSpace5),
                const Text(
                  'WEEK SCHEDULE',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: kNeon,
                  ),
                ),
                const SizedBox(height: kSpace3),
                for (final day in widget.program.weekSchedule)
                  Padding(
                    padding: const EdgeInsets.only(bottom: kSpace2),
                    child: _ProgramDayCard(
                      day: day,
                      exerciseNames: names,
                      swaps: _swaps,
                      onSwapRequested: (originalId) =>
                          _openSwapSheet(day, originalId, names),
                      onRevert: _revertSwap,
                    ),
                  ),
                const SizedBox(height: kSpace4),
                if (_isActive)
                  FilledButton(
                    onPressed: _quitProgram,
                    style: FilledButton.styleFrom(
                      backgroundColor: kDanger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('QUIT PROGRAM'),
                  )
                else
                  PixelButton(label: 'START PROGRAM', onPressed: _startProgram),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgramDayCard extends StatelessWidget {
  const _ProgramDayCard({
    required this.day,
    required this.exerciseNames,
    required this.swaps,
    required this.onSwapRequested,
    required this.onRevert,
  });

  final ProgramDay day;
  final Map<String, String> exerciseNames;

  /// originalId → replacementId for this program. A row whose id is a key shows
  /// the replacement and a revert affordance.
  final Map<String, String> swaps;
  final ValueChanged<String> onSwapRequested;
  final ValueChanged<String> onRevert;

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
    return InkWell(
      onTap: () => onSwapRequested(id),
      child: Padding(
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
            const SizedBox(width: kSpace2),
            if (swapped)
              GestureDetector(
                onTap: () => onRevert(id),
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.undo_sharp,
                  size: 15,
                  color: kMutedText,
                ),
              )
            else
              const Icon(Icons.swap_horiz_sharp, size: 15, color: kMutedText),
          ],
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.contains('ADVANCED') ? 'ADVANCED' : label;
    return Container(
      key: ValueKey('program_detail_tier_badge_$normalized'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.35),
        border: Border.all(color: kBorderVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        normalized,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: kMutedText,
        ),
      ),
    );
  }
}

/// Bottom sheet to permanently replace one prescribed lift. Returns the chosen
/// replacement id, the original id (revert), or null (cancel).
class _SwapSheet extends StatelessWidget {
  const _SwapSheet({
    required this.originalId,
    required this.currentId,
    required this.optionIds,
    required this.names,
  });

  final String originalId;
  final String currentId;
  final List<String> optionIds;
  final Map<String, String> names;

  String _name(String id) => names[id] ?? id.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final swapped = currentId != originalId;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'REPLACE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kNeon,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text(
              _name(currentId),
              style: AppFonts.shareTechMono(color: kText, fontSize: 14),
            ),
            const SizedBox(height: kSpace3),
            if (swapped) ...[
              _SwapOption(
                label: 'REVERT TO ${_name(originalId)}',
                icon: Icons.undo_sharp,
                onTap: () => Navigator.of(context).pop(originalId),
              ),
              const SizedBox(height: kSpace2),
            ],
            if (optionIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpace3),
                child: Text(
                  'No other lifts available for this focus.',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final id in optionIds)
                        Padding(
                          padding: const EdgeInsets.only(bottom: kSpace2),
                          child: _SwapOption(
                            label: _name(id),
                            icon: Icons.swap_horiz_sharp,
                            onTap: () => Navigator.of(context).pop(id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: kSpace2),
            PixelButton(
              label: 'CANCEL',
              secondary: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapOption extends StatelessWidget {
  const _SwapOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 12),
        decoration: BoxDecoration(
          color: kBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: kMutedText),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Text(
                label,
                style: AppFonts.shareTechMono(color: kText, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
