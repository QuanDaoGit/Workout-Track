import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/workout_models.dart';
import '../../services/calorie_service.dart';
import '../../services/program_service.dart';
import '../../services/workout_storage_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_dialog_button_column.dart';
import '../../widgets/arcade_progress_bar.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/arcade_tap.dart';
import '../../widgets/blinking_colon.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/strobe_flash.dart';
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
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
  });

  final String muscleGroup;
  final int durationMinutes;
  final List<Exercise> exercises;
  final WorkoutSession? resumeFromSession;
  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage>
    with WidgetsBindingObserver {
  int _elapsedSeconds = 0;
  Timer? _timer;
  late DateTime _sessionStartTime;
  late Map<String, _ExerciseStatus> _status;
  final Map<String, List<SetEntry>> _loggedSets = {};
  final Map<String, GlobalKey> _exerciseKeys = {};
  final Map<String, int> _flashTriggers = {};
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.resumeFromSession != null) {
      _sessionStartTime = widget.resumeFromSession!.startedAt;
      for (final log in widget.resumeFromSession!.exercises) {
        if (log.sets.isNotEmpty) {
          _loggedSets[log.exerciseId] = log.sets;
        }
      }
    } else {
      _sessionStartTime = DateTime.now();
    }

    _updateElapsed();

    _status = {
      for (final e in widget.exercises)
        e.id: _loggedSets.containsKey(e.id)
            ? _ExerciseStatus.done
            : _ExerciseStatus.notStarted,
    };

    for (final e in widget.exercises) {
      _exerciseKeys[e.id] = GlobalKey();
      _flashTriggers[e.id] = 0;
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

  bool get _allDone =>
      widget.exercises.isNotEmpty &&
      widget.exercises.every((e) => _status[e.id] == _ExerciseStatus.done);

  int get _completedExerciseCount => widget.exercises
      .where((e) => _status[e.id] == _ExerciseStatus.done)
      .length;

  double get _exerciseProgress => widget.exercises.isEmpty
      ? 0.0
      : (_completedExerciseCount / widget.exercises.length)
            .clamp(0.0, 1.0)
            .toDouble();

  int get _totalLoggedSets =>
      _loggedSets.values.fold<int>(0, (sum, sets) => sum + sets.length);

  String get _elapsedMinutes =>
      (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');

  String get _elapsedSecondsPart =>
      (_elapsedSeconds % 60).toString().padLeft(2, '0');

  Future<void> _openExercise(Exercise exercise) async {
    final previousStatus = _status[exercise.id] ?? _ExerciseStatus.notStarted;
    setState(() => _status[exercise.id] = _ExerciseStatus.inProgress);
    final sets = await Navigator.push<List<SetEntry>>(
      context,
      arcadeRoute(
        (_) => ExerciseSessionPage(
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
        _flashTriggers[exercise.id] = (_flashTriggers[exercise.id] ?? 0) + 1;
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
    _updateElapsed();
    if (_totalLoggedSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one set before finishing.')),
      );
      return;
    }
    _timer?.cancel();
    Navigator.push(
      context,
      arcadeRoute(
        (_) => WorkoutSummaryPage(
          muscleGroup: widget.muscleGroup,
          durationMinutes: widget.durationMinutes,
          elapsedSeconds: _elapsedSeconds,
          exerciseLogs: _buildExerciseLogs(),
          isPartial: false,
          startedAt: _sessionStartTime,
          resumeFromSession: widget.resumeFromSession,
          isProgramWorkout: widget.isProgramWorkout,
          advanceProgramRestDayOnCompletion:
              widget.advanceProgramRestDayOnCompletion,
        ),
      ),
    );
  }

  Future<void> _savePartialAndQuit() async {
    if (_leaving) return;
    _leaving = true;
    _updateElapsed();
    _timer?.cancel();
    final logs = _buildExerciseLogs();
    final sessionId =
        widget.resumeFromSession?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await WorkoutStorageService().replaceOngoingSession(
      WorkoutSession(
        id: sessionId,
        date: DateTime.now(),
        startedAt: _sessionStartTime,
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
    if (widget.isProgramWorkout || widget.advanceProgramRestDayOnCompletion) {
      await ProgramService().markOngoingProgramSession(
        sessionId,
        restDayWorkout: widget.advanceProgramRestDayOnCompletion,
      );
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _abandonAndShowSummary() async {
    if (_leaving) return;
    _leaving = true;
    _updateElapsed();
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => WorkoutSummaryPage(
          muscleGroup: widget.muscleGroup,
          durationMinutes: widget.durationMinutes,
          elapsedSeconds: _elapsedSeconds,
          exerciseLogs: const [],
          isPartial: true,
          isAbandoned: true,
          startedAt: _sessionStartTime,
          resumeFromSession: widget.resumeFromSession,
          isProgramWorkout: widget.isProgramWorkout,
          advanceProgramRestDayOnCompletion:
              widget.advanceProgramRestDayOnCompletion,
        ),
      ),
    );
  }

  Future<void> _showAbandonDialog() async {
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
            const Text(
              'All sets will be lost. This will not count toward missions.',
            ),
            const SizedBox(height: 16),
            ArcadeDialogButtonColumn(
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A3E),
                    foregroundColor: const Color(0xFF00FF9C),
                  ),
                  child: const Text('KEEP TRAINING'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _abandonAndShowSummary();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('END EARLY'),
                ),
              ],
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
            color: kAmber,
            fontFamily: 'PressStart2P',
            fontSize: 8,
          ),
        );
      case _ExerciseStatus.inProgress:
        return const Text(
          'ACTIVE',
          style: TextStyle(
            color: kCyan,
            fontFamily: 'PressStart2P',
            fontSize: 8,
          ),
        );
      case _ExerciseStatus.done:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_sharp, color: kNeon, size: 16),
            SizedBox(width: 4),
            Text(
              'CLEARED',
              style: TextStyle(
                color: kNeon,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _savePartialAndQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Return home',
            onPressed: _savePartialAndQuit,
            icon: Transform.scale(
              scaleX: -1,
              child: const ImageIcon(
                AssetImage('assets/icons/control/icon_next.png'),
                color: kNeon,
                size: 22,
              ),
            ),
          ),
          title: const Text('Session'),
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              child: FilledButton(
                onPressed: _confirmEndEarly,
                style: FilledButton.styleFrom(
                  backgroundColor: kDanger,
                  foregroundColor: kBg,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'END EARLY',
                  style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
                ),
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
                      _ElapsedDisplay(
                        minutes: _elapsedMinutes,
                        seconds: _elapsedSecondsPart,
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
                      ArcadeProgressBar(value: _exerciseProgress, height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'EXERCISES',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 12),

              for (final exercise in widget.exercises) ...[
                Padding(
                  key: _exerciseKeys[exercise.id],
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StrobeFlash(
                    trigger: _flashTriggers[exercise.id],
                    borderRadius: BorderRadius.circular(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kCard,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ArcadeTap(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
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
                                        color: kMutedText,
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
      ),
    );
  }
}

class _ElapsedDisplay extends StatelessWidget {
  const _ElapsedDisplay({required this.minutes, required this.seconds});

  final String minutes;
  final String seconds;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: 20,
      color: kNeon,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(minutes, style: style),
        const BlinkingColon(child: Text(':', style: style)),
        Text(seconds, style: style),
      ],
    );
  }
}
