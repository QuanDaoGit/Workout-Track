import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../data/muscle_groups.dart';
import '../../models/program_models.dart';
import '../../models/workout_models.dart';
import '../../services/analytics_service.dart';
import '../../services/calorie_service.dart';
import '../../services/haptic_service.dart';
import '../../services/idle_session_guard.dart';
import '../../services/notification_service.dart';
import '../../services/ongoing_program_swap_service.dart';
import '../../services/program_service.dart';
import '../../services/rest_timer_service.dart';
import '../../services/workout_storage_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_dialog_button_column.dart';
import '../../widgets/idle_session_dialog.dart';
import '../../widgets/arcade_bar.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/arcade_tap.dart';
import '../../widgets/blinking_colon.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/rest_break_panel.dart';
import '../../widgets/strobe_flash.dart';
import 'exercise_session.dart';
import 'workout_summary.dart';
import '../../widgets/arcade_notice.dart';

enum _ExerciseStatus { notStarted, inProgress, done }

class ActiveWorkoutPage extends StatefulWidget {
  const ActiveWorkoutPage({
    super.key,
    required this.muscleGroup,
    this.targetMuscleGroups = const [],
    required this.durationMinutes,
    required this.exercises,
    this.restSeconds = 90,
    this.resumeFromSession,
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
    this.isCalibration = false,
    this.prescriptions = const {},
    this.programSwaps,
    this.idleTimeout = WorkoutStorageService.idleTimeout,
  });

  final String muscleGroup;
  final List<String> targetMuscleGroups;
  final int durationMinutes;
  final List<Exercise> exercises;
  final int restSeconds;
  final WorkoutSession? resumeFromSession;
  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;

  /// Onboarding calibration run. Summary and rank reveal are awaited
  /// sequentially so the onboarding flow resumes only after they unwind.
  final bool isCalibration;

  /// Per-exercise sets × reps targets, keyed by exercise id. Empty for manual
  /// workouts and resumed sessions.
  final Map<String, SetRepScheme> prescriptions;

  /// Ephemeral program-day swaps (effectiveOriginalId → replacementId) recorded
  /// at START so a force-kill resume can re-key prescriptions; persisted to
  /// [OngoingProgramSwapService] on a fresh start. Null for manual/resume.
  final Map<String, String>? programSwaps;

  /// Inactivity window before the idle auto-save reveal. Overridable in tests;
  /// defaults to the production 30-minute constant.
  final Duration idleTimeout;

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage>
    with WidgetsBindingObserver {
  int _elapsedSeconds = 0;
  Timer? _timer;
  late DateTime _sessionStartTime;
  late final String _sessionId;
  late Map<String, _ExerciseStatus> _status;
  final Map<String, List<SetEntry>> _loggedSets = {};
  final Map<String, GlobalKey> _exerciseKeys = {};
  final Map<String, int> _flashTriggers = {};
  bool _leaving = false;
  // True only between *finishing an exercise* and the next exercise / skip — so
  // the rest takeover fires for a genuine between-exercise rest, never for a
  // between-set rest still counting when the user backs out mid-exercise (both
  // share the one RestTimerService).
  bool _restAfterFinish = false;
  // Collapsed by default during a rest takeover so the rest countdown is the one
  // live timer; the user can expand it to a dimmed (still-running) ELAPSED.
  bool _headerExpanded = false;

  // Idle auto-save: the wall-clock of the last logged set (drives the 30-min
  // timeout) and the elapsed seconds captured at that moment (the credited
  // duration, so an idle gap never inflates time/calorie XP).
  late DateTime _lastActivityAt;
  int _lastActivitySeconds = 0;
  Timer? _idleTimer;
  bool _idleHandling = false;
  bool _programMarked = false;
  // The most recent in-flight checkpoint write. Exit paths drain it before
  // writing final state so a late read-modify-write can't resurrect the ongoing
  // row or clobber the completed save.
  Future<void>? _checkpointInFlight;

  List<String> get _targetMuscleGroups {
    final normalized = normalizeTargetMuscleGroups(widget.targetMuscleGroups);
    if (normalized.isNotEmpty) return normalized;
    return normalizeTargetMuscleGroups([widget.muscleGroup]);
  }

  String get _targetLabel => targetMuscleGroupsLabel(
    _targetMuscleGroups,
    fallback: widget.muscleGroup,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Contextual one-time permission ask for the rest-timer alert — a workout is
    // starting, so a rest is imminent. Guarded + fire-and-forget; never re-nags.
    NotificationService.instance.maybeAskRestPermission();
    _sessionId =
        widget.resumeFromSession?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();

    // Persist this session's ephemeral program swaps so a force-kill resume can
    // re-pair sets×reps (fresh start only; a resume reuses the stored map).
    if (widget.resumeFromSession == null &&
        widget.programSwaps != null &&
        widget.programSwaps!.isNotEmpty) {
      OngoingProgramSwapService().setSwaps(_sessionId, widget.programSwaps!);
    }

    if (widget.resumeFromSession != null) {
      _sessionStartTime = widget.resumeFromSession!.resumeStartTime(
        DateTime.now(),
      );
      for (final log in widget.resumeFromSession!.exercises) {
        // Recombine working + warm-up sets into the single flagged list the
        // session page round-trips, so a force-kill resume never drops the
        // logged warm-up sets (and with them, the bonus eligibility).
        if (log.sets.isNotEmpty || log.warmupSets.isNotEmpty) {
          _loggedSets[log.exerciseId] = [...log.sets, ...log.warmupSets];
        }
      }
      // A force-killed session was re-entered into the live flow (found →
      // recovered → saved funnel; `workout_saved` records the persist).
      unawaited(AnalyticsService.instance.logWorkoutRecovered());
    } else {
      _sessionStartTime = DateTime.now();
      unawaited(
        AnalyticsService.instance.logWorkoutStarted(
          muscleGroups: _targetMuscleGroups,
          exerciseCount: widget.exercises.length,
          source: widget.isProgramWorkout
              ? AnalyticsValue.sourceProgram
              : AnalyticsValue.sourceFree,
        ),
      );
    }

    _updateElapsed();

    // Resuming counts as activity now; a fresh session's last activity is its
    // start. Credited seconds = elapsed so far (0 fresh; the resumed duration).
    _lastActivityAt = widget.resumeFromSession != null
        ? DateTime.now()
        : _sessionStartTime;
    _lastActivitySeconds = _elapsedSeconds;

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
    _armIdleTimer();

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
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_updateElapsed);
      // The idle timer is suspended while backgrounded; re-arm it relative to
      // the real last-activity time so a 30-min absence is caught on return
      // (fires immediately if the window already elapsed).
      _armIdleTimer();
    }
  }

  void _updateElapsed() {
    _elapsedSeconds = DateTime.now().difference(_sessionStartTime).inSeconds;
  }

  bool get _allDone =>
      widget.exercises.isNotEmpty &&
      widget.exercises.every((e) => _status[e.id] == _ExerciseStatus.done);

  /// The next exercise not yet cleared (list order) — shown on the rest panel so
  /// the user can eye the next movement during the break. Null when all cleared.
  String? get _nextUndoneExerciseName {
    for (final e in widget.exercises) {
      if (_status[e.id] != _ExerciseStatus.done) return e.name;
    }
    return null;
  }

  int get _completedExerciseCount => widget.exercises
      .where((e) => _status[e.id] == _ExerciseStatus.done)
      .length;

  double get _exerciseProgress => widget.exercises.isEmpty
      ? 0.0
      : (_completedExerciseCount / widget.exercises.length)
            .clamp(0.0, 1.0)
            .toDouble();

  // Counts working sets only — a warm-up-only session has nothing to finish or
  // checkpoint, so warm-up sets never satisfy the "log a set" gate.
  int get _totalLoggedSets => _loggedSets.values.fold<int>(
    0,
    (sum, sets) => sum + sets.where((s) => !s.isWarmup).length,
  );

  String get _elapsedMinutes =>
      (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');

  String get _elapsedSecondsPart =>
      (_elapsedSeconds % 60).toString().padLeft(2, '0');

  Future<void> _openExercise(Exercise exercise) async {
    final previousStatus = _status[exercise.id] ?? _ExerciseStatus.notStarted;
    // Entering any exercise clears the prior finish flag (a fresh context). An
    // active rest is a global singleton that simply carries into the exercise
    // screen (shown by its own rest bar) — opening an exercise is unambiguous
    // intent, so there is no skip prompt and no silent cancel.
    _restAfterFinish = false;
    setState(() => _status[exercise.id] = _ExerciseStatus.inProgress);
    final sets = await Navigator.push<List<SetEntry>>(
      context,
      arcadeRoute(
        (_) => ExerciseSessionPage(
          exercise: exercise,
          initialSets: _loggedSets[exercise.id] ?? const [],
          restSeconds: widget.restSeconds,
          prescription: widget.prescriptions[exercise.id],
          // Each in-exercise commit (a saved set / warm-up change) is persisted
          // immediately so a back-out or force-kill mid-exercise never loses it.
          onSetsCommitted: (committed) {
            if (!mounted) return;
            setState(() {
              if (committed.isEmpty) {
                _loggedSets.remove(exercise.id);
              } else {
                _loggedSets[exercise.id] = committed;
              }
            });
            _registerActivity();
          },
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
    if (!mounted) return;
    if (sets != null && sets.isNotEmpty) {
      setState(() {
        _loggedSets[exercise.id] = sets;
        _status[exercise.id] = _ExerciseStatus.done;
        _flashTriggers[exercise.id] = (_flashTriggers[exercise.id] ?? 0) + 1;
      });
      _registerActivity();
      // A genuine between-exercise rest — the takeover may now show; the session
      // header starts collapsed for it.
      _restAfterFinish = true;
      _headerExpanded = false;
      // Suppress-on-last: finishing the final exercise leaves nothing to rest
      // for — cancel the rest the session page just started so the rest panel
      // never shows and Finish Workout is immediately reachable.
      if (_allDone) RestTimerService.instance.cancel();
    } else {
      // Back-out (no Finish): keep any committed sets (already persisted via the
      // callback) but do NOT mark the exercise complete — completion is explicit
      // via Finish Exercise. Show in-progress if real work exists, else revert.
      final hasCommittedWork =
          _loggedSets[exercise.id]?.any((s) => !s.isWarmup) ?? false;
      setState(() {
        _status[exercise.id] = hasCommittedWork
            ? _ExerciseStatus.inProgress
            : previousStatus;
      });
    }
  }

  // Splits the session page's single flagged set list into working vs. warm-up
  // sets — the one boundary where warm-up sets are partitioned out so every
  // stat/XP/overload consumer reading [ExerciseLog.sets] stays working-only.
  List<ExerciseLog> _buildExerciseLogs() => [
    for (final e in widget.exercises)
      if (_loggedSets[e.id] != null)
        ExerciseLog(
          exerciseId: e.id,
          exerciseName: e.name,
          sets: [
            for (final s in _loggedSets[e.id]!)
              if (!s.isWarmup) s,
          ],
          warmupSets: [
            for (final s in _loggedSets[e.id]!)
              if (s.isWarmup) s,
          ],
        ),
  ];

  Future<void> _goToSummary({
    int? creditedElapsed,
    bool autoSavedAfterIdle = false,
  }) async {
    _updateElapsed();
    if (_totalLoggedSets == 0) {
      showArcadeNotice(context, 'Save at least one set before finishing.');
      return;
    }
    _leaving = true;
    _timer?.cancel();
    _idleTimer?.cancel();
    // No rest carries into the summary or the next workout.
    RestTimerService.instance.cancel();
    await _drainCheckpoint();
    if (!mounted) return;
    // Idle auto-save credits time only up to the last logged set; a normal
    // finish credits the live elapsed.
    final elapsed = creditedElapsed ?? _elapsedSeconds;
    final summary = arcadeRoute(
      (_) => WorkoutSummaryPage(
        muscleGroup: widget.muscleGroup,
        targetMuscleGroups: _targetMuscleGroups,
        durationMinutes: widget.durationMinutes,
        elapsedSeconds: elapsed,
        exerciseLogs: _buildExerciseLogs(),
        selectedExerciseIds: widget.exercises.map((e) => e.id).toList(),
        sessionId: _sessionId,
        isPartial: false,
        startedAt: _sessionStartTime,
        resumeFromSession: widget.resumeFromSession,
        isProgramWorkout: widget.isProgramWorkout,
        advanceProgramRestDayOnCompletion:
            widget.advanceProgramRestDayOnCompletion,
        isCalibration: widget.isCalibration,
        autoSavedAfterIdle: autoSavedAfterIdle,
      ),
      motion: ArcadeRouteMotion.reveal,
    );
    if (widget.isCalibration) {
      // Keep calibration navigation sequential so OnboardingFlowPage only
      // continues after Summary -> Rank reveal fully unwinds.
      await Navigator.push(context, summary);
      if (mounted) Navigator.of(context).pop();
    } else {
      Navigator.push(context, summary);
    }
  }

  /// Records a fresh activity beat (a logged set): resets the idle window and
  /// the credited duration to "now", then checkpoints to storage so a crash
  /// keeps the logged sets.
  void _registerActivity() {
    _updateElapsed();
    _lastActivityAt = DateTime.now();
    _lastActivitySeconds = _elapsedSeconds;
    _idleHandling = false;
    _armIdleTimer();
    _checkpointInFlight = _checkpoint();
  }

  /// Max time to wait for an in-flight checkpoint before exiting anyway. A hung
  /// `SharedPreferences` write (rare — Android under memory pressure or during a
  /// system backup) must not freeze the exit flow. The completed session the
  /// caller is about to write is the source of truth, not this ongoing
  /// checkpoint, so timing out here is safe.
  static const _checkpointDrainTimeout = Duration(seconds: 5);

  /// Awaits any in-flight checkpoint write so a stale read-modify-write can't
  /// land after the caller's final storage write. Bounded by
  /// [_checkpointDrainTimeout] so a hung write can't hang the exit.
  Future<void> _drainCheckpoint() async {
    final pending = _checkpointInFlight;
    if (pending == null) return;
    try {
      await pending.timeout(_checkpointDrainTimeout);
    } on TimeoutException {
      // Storage write is hung well past any healthy latency — stop waiting so
      // the exit UI isn't frozen. We accept the rare RMW-ordering risk this
      // guard normally prevents: a frozen app is a worse outcome than a
      // possible stale ongoing row (which the next launch's resume/idle flow
      // can still surface and let the user discard).
    } catch (_) {
      // A failed checkpoint must not block exit.
    }
  }

  /// Arms (or re-arms) the inactivity timer relative to the last logged set, so
  /// it fires exactly [WorkoutStorageService.idleTimeout] after that set.
  void _armIdleTimer() {
    _idleTimer?.cancel();
    if (_leaving) return;
    final remaining =
        widget.idleTimeout - DateTime.now().difference(_lastActivityAt);
    _idleTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _onIdleTimeout,
    );
  }

  /// Silently persists the live session as an ongoing checkpoint (only once at
  /// least one set is logged — an empty session has nothing to recover).
  Future<void> _checkpoint() async {
    if (_leaving || _loggedSets.isEmpty) return;
    if ((widget.isProgramWorkout || widget.advanceProgramRestDayOnCompletion) &&
        !_programMarked) {
      _programMarked = true;
      await ProgramService().markOngoingProgramSession(
        _sessionId,
        restDayWorkout: widget.advanceProgramRestDayOnCompletion,
      );
    }
    await WorkoutStorageService().checkpointOngoingSession(
      WorkoutSession(
        id: _sessionId,
        date: DateTime.now(),
        startedAt: _sessionStartTime,
        lastActivityAt: _lastActivityAt,
        muscleGroup: widget.muscleGroup,
        targetMuscleGroups: _targetMuscleGroups,
        targetDurationMinutes: widget.durationMinutes,
        actualDurationSeconds: _lastActivitySeconds,
        exercises: _buildExerciseLogs(),
        estimatedCalories: CalorieService.estimateCaloriesForGroups(
          _targetMuscleGroups,
          _lastActivitySeconds,
        ),
        isPartial: true,
        selectedExerciseIds: widget.exercises.map((e) => e.id).toList(),
      ),
    );
  }

  /// Fired when the session has gone [WorkoutStorageService.idleTimeout] without
  /// a new set while this page is on top. Offers save / keep training / discard.
  Future<void> _onIdleTimeout() async {
    if (!mounted || _leaving || _idleHandling) return;
    // Only the active page *while it is actually on top* owns the reveal. If a
    // pushed surface (e.g. ExerciseSessionPage) covers it, stand down — never pop
    // the reveal over another route — and re-poll in a minute so it catches up
    // once we're current again. Stored in _idleTimer so dispose/activity cancels
    // it; a 1-min delay (not _armIdleTimer) avoids an immediate refire loop since
    // _lastActivityAt is already in the past.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      if (!_leaving) {
        _idleTimer = Timer(const Duration(minutes: 1), _onIdleTimeout);
      }
      return;
    }
    // The page that's on top owns the reveal; if one is already in flight (e.g.
    // RootPage on a near-simultaneous resume), stand down.
    if (!IdleSessionGuard.instance.claim(_sessionId)) return;
    _idleHandling = true;
    await _drainCheckpoint();
    if (!mounted) {
      IdleSessionGuard.instance.release(_sessionId);
      return;
    }
    // Nothing logged — drop it silently (matching the cold-reopen path) rather
    // than prompting over an empty session.
    if (_totalLoggedSets == 0) {
      IdleSessionGuard.instance.release(_sessionId);
      unawaited(
        AnalyticsService.instance.logWorkoutDiscarded(
          AnalyticsValue.discardIdleZeroSets,
        ),
      );
      await _discardIdleNoReward();
      return;
    }
    final idleMinutes = DateTime.now()
        .difference(_lastActivityAt)
        .inMinutes
        .clamp(WorkoutStorageService.idleTimeout.inMinutes, 1 << 30);
    final choice = await showIdleSessionDialog(
      context,
      hasSets: true,
      resumeLabel: 'KEEP TRAINING',
      idleMinutes: idleMinutes,
    );
    IdleSessionGuard.instance.release(_sessionId);
    if (!mounted) return;
    switch (choice) {
      case IdleSessionChoice.save:
        await _goToSummary(
          creditedElapsed: _lastActivitySeconds,
          autoSavedAfterIdle: true,
        );
      case IdleSessionChoice.discard:
        unawaited(
          AnalyticsService.instance.logWorkoutDiscarded(
            AnalyticsValue.discardUser,
          ),
        );
        await _discardIdleNoReward();
      case IdleSessionChoice.resume:
      case null:
        // Keep training: restart the idle window (credited duration stays at the
        // last logged set until the next one).
        _idleHandling = false;
        _lastActivityAt = DateTime.now();
        _armIdleTimer();
    }
  }

  /// Drops an idle session that logged nothing — no XP, no mission, no history.
  Future<void> _discardIdleNoReward() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    _idleTimer?.cancel();
    await _drainCheckpoint();
    await WorkoutStorageService().deleteSession(_sessionId);
    if (_programMarked) {
      await ProgramService().clearOngoingProgramSession(_sessionId);
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _savePartialAndQuit() async {
    if (_leaving) return;
    _leaving = true;
    _updateElapsed();
    _timer?.cancel();
    _idleTimer?.cancel();
    await _drainCheckpoint();
    final logs = _buildExerciseLogs();
    await WorkoutStorageService().replaceOngoingSession(
      WorkoutSession(
        id: _sessionId,
        date: DateTime.now(),
        startedAt: _sessionStartTime,
        lastActivityAt: _lastActivityAt,
        muscleGroup: widget.muscleGroup,
        targetMuscleGroups: _targetMuscleGroups,
        targetDurationMinutes: widget.durationMinutes,
        actualDurationSeconds: _elapsedSeconds,
        exercises: logs,
        estimatedCalories: CalorieService.estimateCaloriesForGroups(
          _targetMuscleGroups,
          _elapsedSeconds,
        ),
        isPartial: true,
        selectedExerciseIds: widget.exercises.map((e) => e.id).toList(),
      ),
    );
    if (widget.isProgramWorkout || widget.advanceProgramRestDayOnCompletion) {
      await ProgramService().markOngoingProgramSession(
        _sessionId,
        restDayWorkout: widget.advanceProgramRestDayOnCompletion,
      );
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  DateTime _nextLocalMidnight(DateTime from) {
    return DateTime(
      from.year,
      from.month,
      from.day,
    ).add(const Duration(days: 1));
  }

  Future<void> _pauseAndQuit() async {
    if (_leaving) return;
    _leaving = true;
    _updateElapsed();
    _timer?.cancel();
    _idleTimer?.cancel();
    await _drainCheckpoint();
    RestTimerService.instance.cancel();
    final logs = _buildExerciseLogs();
    final now = DateTime.now();
    await WorkoutStorageService().replaceOngoingSession(
      WorkoutSession(
        id: _sessionId,
        date: now,
        startedAt: _sessionStartTime,
        pausedAt: now,
        autoDiscardAt: _nextLocalMidnight(now),
        lastActivityAt: _lastActivityAt,
        muscleGroup: widget.muscleGroup,
        targetMuscleGroups: _targetMuscleGroups,
        targetDurationMinutes: widget.durationMinutes,
        actualDurationSeconds: _elapsedSeconds,
        exercises: logs,
        estimatedCalories: CalorieService.estimateCaloriesForGroups(
          _targetMuscleGroups,
          _elapsedSeconds,
        ),
        isPartial: true,
        isPausedForResume: true,
        selectedExerciseIds: widget.exercises.map((e) => e.id).toList(),
      ),
    );
    if (widget.isProgramWorkout || widget.advanceProgramRestDayOnCompletion) {
      await ProgramService().markOngoingProgramSession(
        _sessionId,
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
    _idleTimer?.cancel();
    await _drainCheckpoint();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      arcadeRoute(
        (_) => WorkoutSummaryPage(
          muscleGroup: widget.muscleGroup,
          targetMuscleGroups: _targetMuscleGroups,
          durationMinutes: widget.durationMinutes,
          elapsedSeconds: _elapsedSeconds,
          exerciseLogs: const [],
          selectedExerciseIds: widget.exercises.map((e) => e.id).toList(),
          sessionId: _sessionId,
          isPartial: true,
          isAbandoned: true,
          markMissionFinished: true,
          startedAt: _sessionStartTime,
          resumeFromSession: widget.resumeFromSession,
          isProgramWorkout: widget.isProgramWorkout,
          advanceProgramRestDayOnCompletion:
              widget.advanceProgramRestDayOnCompletion,
        ),
        motion: ArcadeRouteMotion.reveal,
      ),
    );
  }

  Future<void> _showAbandonDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface3,
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
                    backgroundColor: kBorderVariant,
                    foregroundColor: kText,
                    side: const BorderSide(color: kBorder),
                  ),
                  child: const Text('KEEP TRAINING'),
                ),
                FilledButton(
                  onPressed: () {
                    HapticService.instance.warning();
                    Navigator.of(ctx).pop();
                    _abandonAndShowSummary();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kDanger,
                    foregroundColor: kWhite,
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
        backgroundColor: kSurface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('END EARLY?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Saved until midnight. If not resumed, it ends early with time-only XP.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pauseAndQuit();
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
                  foregroundColor: const WidgetStatePropertyAll(kDanger),
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  overlayColor: WidgetStatePropertyAll(
                    kDanger.withValues(alpha: 0.12),
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

  /// True exactly when the between-exercise rest panel is on screen (matches the
  /// body's panel gate) — used to collapse the session header in step.
  bool _restPanelActive(RestSnapshot? snap) =>
      _restAfterFinish && (snap?.isActive ?? false) && !_allDone;

  /// The full session header. [dim] mutes the live ELAPSED (still ticking) while
  /// resting-and-expanded; [onToggle] (non-null only during rest) makes the card
  /// tap-to-collapse and shows the collapse chevron.
  Widget _sessionHeader(
    BuildContext context, {
    required bool dim,
    VoidCallback? onToggle,
  }) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_targetLabel, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ELAPSED', style: Theme.of(context).textTheme.bodySmall),
                if (onToggle != null) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.expand_less_sharp,
                    color: kMutedText,
                    size: 16,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            _ElapsedDisplay(
              minutes: _elapsedMinutes,
              seconds: _elapsedSecondsPart,
              color: dim ? kMutedText : kNeon,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Target: ${widget.durationMinutes} min',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kMutedText),
                  ),
                ),
                Text(
                  '$_completedExerciseCount/${widget.exercises.length} cleared',
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ArcadeBar(value: _exerciseProgress, height: 8),
          ],
        ),
      ),
    );
    if (onToggle == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: card,
    );
  }

  /// The slim, ELAPSED-less header shown by default during a rest takeover —
  /// keeps orientation (muscle group · cleared · progress) and a chevron to
  /// expand to the dimmed full header.
  Widget _collapsedHeader(
    BuildContext context, {
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _targetLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: kText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_completedExerciseCount/${widget.exercises.length} cleared',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.expand_more_sharp,
                    color: kMutedText,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ArcadeBar(value: _exerciseProgress, height: 6),
            ],
          ),
        ),
      ),
    );
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
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<RestSnapshot?>(
                  valueListenable: RestTimerService.instance.current,
                  builder: (context, snap, _) {
                    // During the rest takeover the rest countdown is the one hero
                    // timer — collapse the session header by default; tapping it
                    // reveals a dimmed (still-live) ELAPSED. It auto-restores to
                    // the full bright header the moment the rest ends.
                    final resting = _restPanelActive(snap);
                    if (resting && !_headerExpanded) {
                      return _collapsedHeader(
                        context,
                        onToggle: () => setState(() => _headerExpanded = true),
                      );
                    }
                    return _sessionHeader(
                      context,
                      dim: resting && _headerExpanded,
                      onToggle: resting
                          ? () => setState(
                              () => _headerExpanded = !_headerExpanded,
                            )
                          : null,
                    );
                  },
                ),

                const SizedBox(height: 24),

                ValueListenableBuilder<RestSnapshot?>(
                  valueListenable: RestTimerService.instance.current,
                  builder: (context, snap, _) {
                    // Between-exercise rest takeover: while a rest counts down
                    // and the workout is not yet complete, BIT's rest panel
                    // replaces the list (SKIP REST returns to logging). Once
                    // every exercise is cleared there is nothing to rest for, so
                    // the panel is suppressed and Finish Workout is reachable.
                    if (_restPanelActive(snap)) {
                      return RestBreakPanel(
                        onSkip: () {
                          RestTimerService.instance.cancel();
                          _restAfterFinish = false;
                          if (mounted) setState(() {});
                        },
                        nextExerciseName: _nextUndoneExerciseName,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  haptic: HapticIntent.selection,
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                exercise.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color: kWhite,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                          powerOn: true,
                          haptic: HapticIntent.success,
                          onPressed: _allDone ? () => _goToSummary() : null,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElapsedDisplay extends StatelessWidget {
  const _ElapsedDisplay({
    required this.minutes,
    required this.seconds,
    this.color = kNeon,
  });

  final String minutes;
  final String seconds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: 20,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(minutes, style: style),
        BlinkingColon(child: Text(':', style: style)),
        Text(seconds, style: style),
      ],
    );
  }
}
