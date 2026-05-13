import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/workout_models.dart';
import '../../services/calorie_service.dart';
import '../../services/workout_storage_service.dart';
import '../../services/xp_service.dart';

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

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage>
    with SingleTickerProviderStateMixin {
  bool _saving = false;
  bool _saved = false;

  late final AnimationController _xpController;
  late final Animation<double> _xpScale;

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
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _xpScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _xpController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _saveAndExit());
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
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
      _xpController.forward(from: 0);
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
              ScaleTransition(
                scale: _xpScale,
                child: Text(
                  '+$_earnedXP XP EARNED',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 16,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (statBoxes.isNotEmpty)
                Row(
                  children: [
                    for (var i = 0; i < statBoxes.length; i++) ...[
                      statBoxes[i],
                      if (i < statBoxes.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              if (exerciseLogs.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'BREAKDOWN',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                for (final log in exerciseLogs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(log.exerciseName),
                        subtitle: Text(
                          '${log.sets.length} sets - '
                          '${log.totalVolume.toStringAsFixed(0)} kg total',
                          style: const TextStyle(color: Color(0xFF6B6B8A)),
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
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saved ? _goHome : null,
                child: Text(_saving ? 'SAVING...' : 'BACK TO HOME'),
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
                style: GoogleFonts.shareTechMono(
                  fontSize: 18,
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
