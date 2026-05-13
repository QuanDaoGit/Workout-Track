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
    await prefs.setString(
      _startTimeKey,
      _sessionStartTime.toIso8601String(),
    );
  }

  Future<void> _clearStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_startTimeKey);
  }

  bool get _allDone =>
      widget.exercises.isNotEmpty &&
      widget.exercises.every((e) => _status[e.id] == _ExerciseStatus.done);

  String get _elapsed {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openExercise(Exercise exercise) async {
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
      });
    } else {
      setState(() => _status[exercise.id] = _ExerciseStatus.notStarted);
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        title: const Text('ABANDON SESSION?'),
        content: const Text(
          'All logged sets will be lost. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('KEEP TRAINING'),
          ),
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
    );
  }

  Future<void> _confirmEndEarly() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End workout?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose how to end this session.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _savePartialAndQuit();
                },
                child: const Text('Save & Quit'),
              ),
            ),
            const SizedBox(height: 8),
            PixelButton(
              label: 'End Session',
              onPressed: () {
                Navigator.of(ctx).pop();
                _goToSummary();
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showAbandonDialog();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF2D55),
                  side: const BorderSide(color: Color(0xFFFF2D55)),
                ),
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
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
          'Not Started',
          style: TextStyle(color: Color(0xFF6B6B8A), fontSize: 12),
        );
      case _ExerciseStatus.inProgress:
        return const Text(
          'In Progress',
          style: TextStyle(color: Color(0xFF00FF9C), fontSize: 12),
        );
      case _ExerciseStatus.done:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(
              AssetImage('assets/icons/control/icon_trophy.png'),
              color: Color(0xFF00FF9C),
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(color: Color(0xFF00FF9C), fontSize: 12),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.muscleGroup,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Target: ${widget.durationMinutes} min',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: const Color(
                                      0xFF6B6B8A,
                                    ), // force visible muted white
                                  ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ELAPSED',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _elapsed,
                              style: GoogleFonts.shareTechMono(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00FF9C),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.exercises.length} exercises',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B6B8A),
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
              Card(
                key: _exerciseKeys[exercise.id],
                child: InkWell(
                  onTap: () => _openExercise(exercise),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
              const SizedBox(height: 8),
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
