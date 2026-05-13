import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workout_models.dart';
import '../../widgets/pixel_button.dart';
import '../../services/calorie_service.dart';
import '../../services/workout_storage_service.dart';
import 'exercise_session.dart';
import 'workout_summary.dart';

enum _ExerciseStatus { notStarted, inProgress, done }

class ActiveWorkoutPage extends StatefulWidget {
  const ActiveWorkoutPage({
    super.key,
    required this.muscleGroup,
    required this.durationMinutes,
    required this.exercises,
    this.resumeFromSession,
  });

  final String muscleGroup;
  final int durationMinutes;
  final List<Exercise> exercises;
  final WorkoutSession? resumeFromSession;

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage>
    with WidgetsBindingObserver {
  static const String _startTimeKey = 'session_start_time';

  int _elapsedSeconds = 0;
  Timer? _timer;
  late DateTime _sessionStartTime;
  late Map<String, _ExerciseStatus> _status;
  final Map<String, List<SetEntry>> _loggedSets = {};
  final Map<String, GlobalKey> _exerciseKeys = {};
  String? _flashingExerciseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.resumeFromSession != null) {
      // Resuming: compute start time so elapsed stays continuous
      _sessionStartTime = DateTime.now().subtract(
        Duration(seconds: widget.resumeFromSession!.actualDurationSeconds),
      );
      for (final log in widget.resumeFromSession!.exercises) {
        if (log.sets.isNotEmpty) {
          _loggedSets[log.exerciseId] = log.sets;
        }
      }
    } else {
      _sessionStartTime = DateTime.now();
    }

    _persistStartTime();
    _updateElapsed();

    _status = {
      for (final e in widget.exercises)
        e.id: _loggedSets.containsKey(e.id)
            ? _ExerciseStatus.done
            : _ExerciseStatus.notStarted,
    };

    for (final e in widget.exercises) {
      _exerciseKeys[e.id] = GlobalKey();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(_updateElapsed);
    });

    // Auto-scroll to first incomplete exercise on resume
    if (widget.resumeFromSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstIncomplete();
      });
    }
  }

  void _scrollToFirstIncomplete() {
    for (final e in widget.exercises) {
      if (_status[e.id] != _ExerciseStatus.done) {
        final key = _exerciseKeys[e.id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            alignment: 0.3,
            duration: const Duration(milliseconds: 400),
          );
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_updateElapsed);
    }
  }

  void _updateElapsed() {
    _elapsedSeconds = DateTime.now().difference(_sessionStartTime).inSeconds;
  }

  Future<void> _persistStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startTimeKey, _sessionStartTime.toIso8601String());
  }

  Future<void> _clearStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_startTimeKey);
  }

  bool get _allDone =>
      widget.exercises.isNotEmpty &&
      widget.exercises.every((e) => _status[e.id] == _ExerciseStatus.done);

  int get _completedExerciseCount => widget.exercises
      .where((e) => _status[e.id] == _ExerciseStatus.done)
      .length;

  int get _totalLoggedSets =>
      _loggedSets.values.fold<int>(0, (sum, sets) => sum + sets.length);

  String get _elapsed {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openExercise(Exercise exercise) async {
    final previousStatus = _status[exercise.id] ?? _ExerciseStatus.notStarted;
    setState(() => _status[exercise.id] = _ExerciseStatus.inProgress);
    final sets = await Navigator.push<List<SetEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseSessionPage(
          exercise: exercise,
          initialSets: _loggedSets[exercise.id] ?? const [],
        ),
      ),
    );
    if (!mounted) return;
    if (sets != null && sets.isNotEmpty) {
      setState(() {
        _loggedSets[exercise.id] = sets;
        _status[exercise.id] = _ExerciseStatus.done;
        _flashingExerciseId = exercise.id;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _flashingExerciseId == exercise.id) {
          setState(() => _flashingExerciseId = null);
        }
      });
    } else {
      setState(() => _status[exercise.id] = previousStatus);
    }
  }

  List<ExerciseLog> _buildExerciseLogs() => [
    for (final e in widget.exercises)
      if (_loggedSets[e.id] != null)
        ExerciseLog(
          exerciseId: e.id,
          exerciseName: e.name,
          sets: _loggedSets[e.id]!,
        ),
  ];

  void _goToSummary() {
    if (_totalLoggedSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one set before finishing.')),
      );
      return;
    }
    _timer?.cancel();
    _clearStartTime();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryPage(
          muscleGroup: widget.muscleGroup,
          durationMinutes: widget.durationMinutes,
          elapsedSeconds: _elapsedSeconds,
          exerciseLogs: _buildExerciseLogs(),
          isPartial: false,
          resumeFromSession: widget.resumeFromSession,
        ),
      ),
    );
  }

  Future<void> _savePartialAndQuit() async {
    _timer?.cancel();
    _clearStartTime();
    if (widget.resumeFromSession != null) {
      await WorkoutStorageService().deleteSession(widget.resumeFromSession!.id);
    }
    final logs = _buildExerciseLogs();
    await WorkoutStorageService().saveSession(
      WorkoutSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        muscleGroup: widget.muscleGroup,
        targetDurationMinutes: widget.durationMinutes,
        actualDurationSeconds: _elapsedSeconds,
        exercises: logs,
        estimatedCalories: CalorieService.estimateCalories(
          widget.muscleGroup,
          _elapsedSeconds,
        ),
        isPartial: true,
        selectedExerciseIds: widget.exercises.map((e) => e.id).toList(),
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _discardAndQuit() {
    _timer?.cancel();
    _clearStartTime();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _showAbandonDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('ABANDON SESSION?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('All sets will be lost.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A3E),
                foregroundColor: const Color(0xFF00FF9C),
              ),
              child: const Text('KEEP TRAINING'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _discardAndQuit();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
              ),
              child: const Text('ABANDON'),
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Future<void> _confirmEndEarly() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('END EARLY?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Save progress and return home.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _savePartialAndQuit();
              },
              child: const Text('SAVE & EXIT'),
            ),
            const SizedBox(height: 12),
            Align(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showAbandonDialog();
                },
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  foregroundColor: const WidgetStatePropertyAll(
                    Color(0xFFFF2D55),
                  ),
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  overlayColor: WidgetStatePropertyAll(
                    const Color(0xFFFF2D55).withValues(alpha: 0.12),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                child: const Text('DISCARD'),
              ),
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Widget _statusWidget(_ExerciseStatus status) {
    switch (status) {
      case _ExerciseStatus.notStarted:
        return const Text(
          'READY',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontFamily: 'PressStart2P',
            fontSize: 8,
          ),
        );
      case _ExerciseStatus.inProgress:
        return const Text(
          'ACTIVE',
          style: TextStyle(
            color: Color(0xFF00BFFF),
            fontFamily: 'PressStart2P',
            fontSize: 8,
          ),
        );
      case _ExerciseStatus.done:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_sharp, color: Color(0xFF00FF9C), size: 16),
            SizedBox(width: 4),
            Text(
              'CLEARED',
              style: TextStyle(
                color: Color(0xFF00FF9C),
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.exercises.isEmpty
        ? 0.0
        : _completedExerciseCount / widget.exercises.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PixelButton(
              label: 'End Early',
              fullWidth: false,
              color: const Color(0xFFFF2D55),
              onPressed: _confirmEndEarly,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.muscleGroup,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ELAPSED',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _elapsed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 20,
                        color: Color(0xFF00FF9C),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Target: ${widget.durationMinutes} min',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF6B6B8A)),
                          ),
                        ),
                        Text(
                          '$_completedExerciseCount/${widget.exercises.length} cleared',
                          style: GoogleFonts.shareTechMono(
                            color: const Color(0xFFE8E8FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF2A2A3E),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00FF9C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text('EXERCISES', style: Theme.of(context).textTheme.headlineSmall),

            const SizedBox(height: 12),

            for (final exercise in widget.exercises) ...[
              AnimatedContainer(
                key: _exerciseKeys[exercise.id],
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: _flashingExerciseId == exercise.id
                      ? const Color(0xFF00FF9C).withValues(alpha: 0.2)
                      : const Color(0xFF1A1A2E),
                  border: Border.all(color: const Color(0xFF2A2A4A)),
                  borderRadius: BorderRadius.circular(4),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _openExercise(exercise),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                exercise.levelLabel,
                                style: const TextStyle(
                                  color: Color(0xFF6B6B8A),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _statusWidget(_status[exercise.id]!),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            PixelButton(
              label: 'Finish Workout',
              onPressed: _allDone ? _goToSummary : null,
            ),
          ],
        ),
      ),
    );
  }
}
