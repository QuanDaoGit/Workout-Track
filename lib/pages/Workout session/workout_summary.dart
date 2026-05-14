import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/workout_models.dart';
import '../../services/calorie_service.dart';
import '../../services/workout_storage_service.dart';
import '../../services/xp_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/pulse_color_text.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/typewriter_text.dart';

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
  bool _saved = false;
  int _shakeTrigger = 0;

  late final int _estimatedCalories = CalorieService.estimateCalories(
    widget.muscleGroup,
    widget.elapsedSeconds,
  );

  late final WorkoutSession _savedSession = WorkoutSession(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    date: DateTime.now(),
    muscleGroup: widget.muscleGroup,
    targetDurationMinutes: widget.durationMinutes,
    actualDurationSeconds: widget.elapsedSeconds,
    exercises: widget.exerciseLogs,
    estimatedCalories: _estimatedCalories,
    isPartial: widget.isPartial,
  );

  late final int _earnedXP = XpService.calculateSessionXP(_savedSession);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _shakeTrigger++);
      _saveAndExit();
    });
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _totalSets =>
      widget.exerciseLogs.fold<int>(0, (sum, log) => sum + log.sets.length);

  Future<void> _saveAndExit() async {
    if (_saving || _saved) return;

    if (_totalSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one set before saving.')),
      );
      return;
    }

    setState(() => _saving = true);
    if (widget.resumeFromSession != null) {
      await WorkoutStorageService().deleteSession(widget.resumeFromSession!.id);
    }
    await WorkoutStorageService().saveSession(_savedSession);
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = _totalSets;
    final exerciseLogs = widget.exerciseLogs
        .where((log) => log.sets.isNotEmpty)
        .toList();
    final statBoxes = [
      if (widget.elapsedSeconds > 0)
        _StatBox(label: 'Time', value: _fmt(widget.elapsedSeconds)),
      if (totalSets > 0) _StatBox(label: 'Sets', value: totalSets.toString()),
      if (exerciseLogs.isNotEmpty)
        _StatBox(label: 'Moves', value: exerciseLogs.length.toString()),
      if (_estimatedCalories > 0)
        _StatBox(label: 'kcal', value: _estimatedCalories.toString()),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout Complete'),
          automaticallyImplyLeading: false,
        ),
        body: ScreenShake(
          trigger: _shakeTrigger,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kSpace4),
                const ImageIcon(
                  AssetImage('assets/icons/control/icon_star.png'),
                  color: kNeon,
                  size: 72,
                ),
                const SizedBox(height: kSpace3),
                const TypewriterText(
                  'SESSION COMPLETE',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: kNeon,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: kSpace3),
                PulseColorText(
                  '+$_earnedXP XP EARNED',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (statBoxes.isNotEmpty)
                  Row(
                    children: [
                      for (var i = 0; i < statBoxes.length; i++) ...[
                        statBoxes[i],
                        if (i < statBoxes.length - 1)
                          const SizedBox(width: kSpace2),
                      ],
                    ],
                  ),
                if (exerciseLogs.isNotEmpty) ...[
                  const SizedBox(height: kSpace5),
                  Text(
                    'BREAKDOWN',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: kSpace3),
                  for (final log in exerciseLogs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: kSpace2),
                      child: Card(
                        child: ListTile(
                          title: Text(log.exerciseName),
                          subtitle: Text(
                            '${log.sets.length} sets - '
                            '${log.totalVolume.toStringAsFixed(0)} kg total',
                            style: const TextStyle(color: kMutedText),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/control/icon_particle.png',
                                width: 16,
                                height: 16,
                                color: kNeon,
                              ),
                              const SizedBox(width: kSpace1),
                              Text(
                                '${CalorieService.exerciseCalories(log, _estimatedCalories, widget.exerciseLogs)} calories',
                                style: const TextStyle(
                                  color: kNeon,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: kSpace5),
                FilledButton(
                  onPressed: _saved ? _goHome : null,
                  child: Text(_saving ? 'SAVING...' : 'BACK TO HOME'),
                ),
              ],
            ),
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
          padding: const EdgeInsets.symmetric(
            vertical: kSpace4,
            horizontal: kSpace2,
          ),
          child: Column(
            children: [
              Text(
                value,
                style: GoogleFonts.shareTechMono(
                  fontSize: 18,
                  color: kNeon,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpace1),
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
