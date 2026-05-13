import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../widgets/pixel_button.dart';
import '../../services/calorie_service.dart';
import '../../services/workout_storage_service.dart';

class WorkoutSummaryPage extends StatefulWidget {
  const WorkoutSummaryPage({
    super.key,
    required this.muscleGroup,
    required this.durationMinutes,
    required this.elapsedSeconds,
    required this.exerciseLogs,
    this.isPartial = false,
    this.resumeFromSession,
  });

  final String muscleGroup;
  final int durationMinutes;
  final int elapsedSeconds;
  final List<ExerciseLog> exerciseLogs;
  final bool isPartial;
  final WorkoutSession? resumeFromSession;

  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage> {
  bool _saving = false;

  late final int _estimatedCalories = CalorieService.estimateCalories(
    widget.muscleGroup,
    widget.elapsedSeconds,
  );

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAndExit() async {
    setState(() => _saving = true);
    if (widget.resumeFromSession != null) {
      await WorkoutStorageService().deleteSession(widget.resumeFromSession!.id);
    }
    await WorkoutStorageService().saveSession(
      WorkoutSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        muscleGroup: widget.muscleGroup,
        targetDurationMinutes: widget.durationMinutes,
        actualDurationSeconds: widget.elapsedSeconds,
        exercises: widget.exerciseLogs,
        estimatedCalories: _estimatedCalories,
        isPartial: widget.isPartial,
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = widget.exerciseLogs.fold<int>(
      0,
      (sum, log) => sum + log.sets.length,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout Complete'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              const ImageIcon(
                AssetImage('assets/icons/control/icon_star.png'),
                color: Color(0xFF00FF9C),
                size: 72,
              ),
              const SizedBox(height: 12),
              Text(
                'SESSION COMPLETE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  _StatBox(label: 'Time', value: _fmt(widget.elapsedSeconds)),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Sets', value: totalSets.toString()),
                  const SizedBox(width: 8),
                  _StatBox(
                    label: 'Moves',
                    value: widget.exerciseLogs.length.toString(),
                  ),
                  const SizedBox(width: 8),
                  _StatBox(label: 'kcal', value: _estimatedCalories.toString()),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'BREAKDOWN',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              for (final log in widget.exerciseLogs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(log.exerciseName),
                      subtitle: Text(
                        '${log.sets.length} sets · '
                        '${log.totalVolume.toStringAsFixed(0)} kg total',
                        style: const TextStyle(color: Color(0xFFAAA8C0)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/icons/control/icon_particle.png',
                            width: 16,
                            height: 16,
                            color: const Color(0xFF00FF9C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${CalorieService.exerciseCalories(log, _estimatedCalories, widget.exerciseLogs)} calories',
                            style: const TextStyle(
                              color: Color(0xFF00FF9C),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              PixelButton(
                label: 'Save & Exit',
                onPressed: _saveAndExit,
                isLoading: _saving,
              ),
            ],
          ),
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
                  color: const Color(0xFF00FF9C),
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
