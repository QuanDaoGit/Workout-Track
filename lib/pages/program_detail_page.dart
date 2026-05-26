import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/program_service.dart';
import '../theme/tokens.dart';
import '../widgets/pixel_button.dart';

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
  late Future<Map<String, String>> _exerciseNamesFuture;
  String? _activeProgramId;

  @override
  void initState() {
    super.initState();
    _activeProgramId = widget.activeProgramId;
    _exerciseNamesFuture = _loadExerciseNames();
  }

  bool get _isActive => _activeProgramId == widget.program.id;

  Future<Map<String, String>> _loadExerciseNames() async {
    final exercises = await ExerciseCatalogService().getFullCatalog();
    return {for (final exercise in exercises) exercise.id: exercise.name};
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
  }

  Future<void> _quitProgram() async {
    await _programService.quitProgram();
    if (!mounted) return;
    setState(() => _activeProgramId = null);
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
    final tierColor = programTierColor(widget.program.tier);
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
                    _TierBadge(label: widget.program.tier, color: tierColor),
                  ],
                ),
                const SizedBox(height: kSpace3),
                Text(
                  '${widget.program.daysPerWeek} days/week - ${widget.program.recommendedWeeks} weeks',
                  style: AppFonts.shareTechMono(color: kAmber, fontSize: 13),
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
                    child: _ProgramDayCard(day: day, exerciseNames: names),
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
  const _ProgramDayCard({required this.day, required this.exerciseNames});

  final ProgramDay day;
  final Map<String, String> exerciseNames;

  @override
  Widget build(BuildContext context) {
    final color = day.isWorkout ? kNeon : kMutedText;
    final exercises = [
      for (final id in day.suggestedExerciseIds)
        exerciseNames[id] ?? id.replaceAll('_', ' '),
    ];
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
                  color: kAmber,
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
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: kSpace2),
            for (final exercise in exercises.take(6))
              Text(
                '- $exercise',
                style: AppFonts.shareTechMono(color: kText, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.contains('ADVANCED') ? 'ADVANCED' : label,
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 7, color: color),
      ),
    );
  }
}
