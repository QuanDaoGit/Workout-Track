import 'package:flutter/material.dart';

import '../../models/unit_models.dart';
import '../../models/workout_models.dart';
import '../../services/stat_engine.dart';
import '../../services/unit_settings_service.dart';
import '../../services/workout_storage_service.dart';
import '../../services/xp_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/motion/phosphor_tap.dart';
import '../../widgets/pixel_button.dart';
import '../exercise_history_page.dart';
import 'start_workout.dart';

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  /// Local working copy — set edits rewrite storage and refresh this.
  late WorkoutSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime date) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'DELETE THIS SESSION?',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kDanger,
          ),
        ),
        content: Text(
          'STATS AND TOTALS WILL RECALCULATE. THIS CANNOT BE UNDONE.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: kDanger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: kBg,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await WorkoutStorageService().deleteSession(_session.id);
    await StatEngine().calculateAllStats();
    if (!mounted) return;
    navigator.pop(true);
  }

  Future<void> _editSet(int logIndex, int setIndex) async {
    final log = _session.exercises[logIndex];
    final set = log.sets[setIndex];
    final weightController = TextEditingController(
      text: weightValue(set.weight, Units.weight),
    );
    final repsController = TextEditingController(text: '${set.reps}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(
          'EDIT SET ${setIndex + 1}',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kNeon,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.exerciseName,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ArcadeTextField(
                    controller: weightController,
                    hintText: 'Weight (${Units.weight.label})',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    height: 48,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    enableEcho: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ArcadeTextField(
                    controller: repsController,
                    hintText: 'Reps',
                    keyboardType: TextInputType.number,
                    height: 48,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    enableEcho: false,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'SAVE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: kBg,
              ),
            ),
          ),
        ],
      ),
    );

    final weightText = weightController.text;
    final repsText = repsController.text;
    weightController.dispose();
    repsController.dispose();
    if (saved != true || !mounted) return;

    final w = parseWeightToKg(weightText, Units.weight);
    final r = int.tryParse(repsText);
    if (w == null || w < 0 || r == null || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight and reps')),
      );
      return;
    }

    final newSets = List<SetEntry>.from(log.sets);
    newSets[setIndex] = SetEntry(weight: w, reps: r);
    final newLogs = List<ExerciseLog>.from(_session.exercises);
    newLogs[logIndex] = ExerciseLog(
      exerciseId: log.exerciseId,
      exerciseName: log.exerciseName,
      sets: newSets,
    );
    final updated = _session.copyWith(exercises: newLogs);
    // awardedXP is deliberately untouched: XP was earned at save time —
    // edits fix the record, not the reward (and must never farm XP).
    await WorkoutStorageService().updateSession(updated);
    await StatEngine().calculateAllStats();
    if (!mounted) return;
    setState(() => _session = updated);
  }

  void _openExerciseHistory(ExerciseLog log) {
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ExerciseHistoryPage(
          exerciseId: log.exerciseId,
          exerciseName: log.exerciseName,
        ),
      ),
    );
  }

  void _repeatWorkout() {
    final exerciseIds = _session.selectedExerciseIds.isNotEmpty
        ? _session.selectedExerciseIds
        : _session.exercises.map((log) => log.exerciseId).toList();
    Navigator.push(
      context,
      arcadeRoute(
        (_) => StartWorkoutPage(
          initialMuscleGroups: _session.targetMuscleGroups,
          initialSelectedExerciseIds: exerciseIds,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final totalSets = session.exercises.fold<int>(
      0,
      (sum, log) => sum + log.sets.length,
    );
    final totalVolume = session.exercises.fold<double>(
      0,
      (sum, log) => sum + log.totalVolume,
    );
    final earnedXP = XpService.calculateSessionXP(session);
    final hasLoggedSets = session.exercises.any((log) => log.sets.isNotEmpty);
    final canRepeat = session.selectedExerciseIds.isNotEmpty || hasLoggedSets;
    final statDelta = {
      for (final entry in session.statDelta.entries)
        if (entry.value > 0 && StatEngine.stats.contains(entry.key))
          entry.key: entry.value,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_fmtDate(session.date)),
        actions: [
          IconButton(
            tooltip: 'Delete session',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_sharp, color: kDanger, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              if (session.isAbandoned) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'ENDED EARLY - $earnedXP XP earned from time. No mission progress.',
                      style: const TextStyle(color: kAmber),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  _StatBox(
                    label: 'Time',
                    value: _fmtDuration(session.actualDurationSeconds),
                  ),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Sets', value: totalSets.toString()),
                  const SizedBox(width: 8),
                  _StatBox(
                    label: 'Moves',
                    value: session.exercises.length.toString(),
                  ),
                  const SizedBox(width: 8),
                  _StatBox(
                    label: 'kcal',
                    value: session.estimatedCalories.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatBox(
                    label: 'Volume',
                    value:
                        '${fmtVol(kgToDisplay(totalVolume, Units.weight))} ${Units.weight.label}',
                  ),
                  const SizedBox(width: 8),
                  _StatBox(label: 'XP', value: earnedXP.toString()),
                ],
              ),

              if (hasLoggedSets) ...[
                if (statDelta.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _StatDeltaCard(delta: statDelta),
                ],
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BREAKDOWN',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'tap a set to edit',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                for (
                  int logIndex = 0;
                  logIndex < session.exercises.length;
                  logIndex++
                )
                  if (session.exercises[logIndex].sets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildExerciseCard(context, logIndex),
                    ),
              ],

              if (canRepeat) ...[
                const SizedBox(height: 24),
                PixelButton(label: 'RUN IT BACK', onPressed: _repeatWorkout),
                const SizedBox(height: 4),
                Text(
                  'Start a new workout with this loadout.',
                  textAlign: TextAlign.center,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, int logIndex) {
    final log = _session.exercises[logIndex];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhosphorTap(
              onTap: () => _openExerciseHistory(log),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      log.exerciseName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const ImageIcon(
                    AssetImage('assets/icons/control/icon_graph.png'),
                    size: 14,
                    color: kCyan,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < log.sets.length; i++)
              PhosphorTap(
                onTap: () => _editSet(logIndex, i),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          'Set ${i + 1}',
                          style: const TextStyle(
                            color: kMutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${weightValue(log.sets[i].weight, Units.weight)} ${Units.weight.label}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${log.sets[i].reps} reps',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_sharp, size: 12, color: kMutedText),
                    ],
                  ),
                ),
              ),
            const Divider(height: 16, color: kBorder),
            Text(
              'Volume: ${fmtVol(kgToDisplay(log.totalVolume, Units.weight))} ${Units.weight.label}',
              style: const TextStyle(color: kNeon, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDeltaCard extends StatelessWidget {
  const _StatDeltaCard({required this.delta});

  final Map<String, int> delta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ImageIcon(
                  AssetImage('assets/icons/control/icon_star.png'),
                  color: kAmber,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'STAT GAINS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: kAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final entry in delta.entries)
                  Text(
                    '+${entry.value} ${entry.key}',
                    style: AppFonts.shareTechMono(
                      color: kNeon,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kNeon,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
