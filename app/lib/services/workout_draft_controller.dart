import 'package:flutter/foundation.dart';

import '../models/program_models.dart';

/// The inputs needed to seed an exercise-selection draft. Mirrors the
/// [StartWorkoutPage] constructor so every launcher (manual Train tap, Home
/// program day, onboarding finale, repeat-workout) flows through one shape.
class WorkoutDraftSeed {
  const WorkoutDraftSeed({
    this.initialMuscleGroups,
    this.initialSelectedExerciseIds,
    this.programDayLabel,
    this.programFocusSummary,
    this.programCuratedExerciseIds,
    this.programPrescriptions = const {},
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
  });

  /// A blank manual pick (the bare center-Train tap).
  const WorkoutDraftSeed.manual() : this();

  /// "Repeat workout" — pre-select a past session's lifts.
  factory WorkoutDraftSeed.repeat(
    List<String> exerciseIds, {
    List<String>? muscleGroups,
  }) => WorkoutDraftSeed(
    initialSelectedExerciseIds: exerciseIds,
    initialMuscleGroups: muscleGroups,
  );

  final List<String>? initialMuscleGroups;
  final List<String>? initialSelectedExerciseIds;
  final String? programDayLabel;
  final String? programFocusSummary;
  final List<String>? programCuratedExerciseIds;
  final Map<String, SetRepScheme> programPrescriptions;
  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;
}

/// In-memory, shell-owned controller for a **pre-start** workout draft (exercise
/// selection in progress). It survives tab navigation but NOT an app kill (the
/// live-session machine, not this, owns started workouts).
///
/// The live session always takes precedence: when an ongoing/paused/expired
/// session exists the shell [clear]s the draft and Train shows live/resume — the
/// armed state is never shown on top of a real session. Validity ([isValid]) is
/// the single source of truth the shell reads to arm Train, and is re-read
/// synchronously at commit so a stale-armed button can never start an empty
/// draft.
class WorkoutDraftController extends ChangeNotifier {
  WorkoutDraftSeed? _seed;
  bool _valid = false;
  VoidCallback? _committer;

  WorkoutDraftSeed? get seed => _seed;

  /// A draft selection is open (the in-shell selection surface is showing).
  bool get active => _seed != null;
  bool get isValid => _valid;

  /// Safe to launch: a draft exists AND has at least one exercise.
  bool get canStart => _seed != null && _valid;

  void begin(WorkoutDraftSeed seed) {
    _seed = seed;
    _valid = false;
    notifyListeners();
  }

  /// Pushed by the embedded selection whenever the loadout changes (≥1 lift).
  void setValid(bool value) {
    if (_valid == value) return;
    _valid = value;
    notifyListeners();
  }

  /// The embedded selection registers its confirm+launch here (and unregisters
  /// on dispose). The committer lifecycle is tied to the page's mount, not to
  /// [clear], so a precedence-clear never strands a live page's commit.
  void registerCommitter(VoidCallback? committer) => _committer = committer;

  /// Run the registered commit (the existing confirm → launch) — but only when
  /// the draft is genuinely startable.
  void requestCommit() {
    if (canStart) _committer?.call();
  }

  /// Drop the draft (confirmed start, cancel/back/discard, or a live/paused/
  /// expired session taking precedence).
  void clear() {
    if (_seed == null && !_valid) return;
    _seed = null;
    _valid = false;
    notifyListeners();
  }
}
