import 'package:flutter/material.dart';

import '../../data/body_map_regions.dart';
import '../../data/curated_exercises.dart';
import '../../data/exercise_alternatives.dart';
import '../../data/exercise_demos.dart';
import '../../data/muscle_groups.dart';
import '../../data/programs_library.dart';
import '../../models/program_models.dart';
import '../../models/workout_models.dart';
import '../../services/calorie_service.dart';
import '../../services/exercise_catalog_service.dart';
import '../../services/favorite_service.dart';
import '../../services/haptic_service.dart';
import '../../services/program_service.dart';
import '../../services/ui_sound.dart';
import '../../services/workout_defaults_service.dart';
import '../../services/workout_draft_controller.dart';
import '../../services/simple_mode_service.dart';
import '../../services/workout_storage_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/active_session_found_dialog.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/arcade_filled.dart';
import '../../widgets/arcade_image_filter.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/exercise_card.dart';
import '../../widgets/exercise_replace_sheet.dart';
import '../../widgets/level_badge.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/motion/phosphor_tap.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/pixel_loader.dart';
import '../../widgets/target_body_preview.dart';
import '../../widgets/warmup_sheet.dart';
import 'active_workout.dart';
import '../../widgets/arcade_notice.dart';

/// Builds a program-mode [StartWorkoutPage] for [day]: the day's target groups
/// and prescribed lifts pre-filled and pre-selected, muscle focus locked. Shared
/// by the onboarding first session and the Home program-day start so both routes
/// pre-fill the same full Day 1 loadout (a time-pressed user trims it on the
/// review screen before starting).
StartWorkoutPage programDayStarter(ProgramDay day) {
  final targetGroups = programDayTargetMuscleGroups(day);
  final curated = day.suggestedExerciseIds.isNotEmpty
      ? day.suggestedExerciseIds
      : curatedExerciseIdsForMuscleGroups(targetGroups);
  return StartWorkoutPage(
    initialMuscleGroups: targetGroups,
    programCuratedExerciseIds: curated,
    programPrescriptions: day.prescription,
    programDayLabel: day.label,
    programFocusSummary: programDayFocusSummary(day),
    isProgramWorkout: true,
  );
}

/// The [WorkoutDraftSeed] equivalent of [programDayStarter] — used by the in-shell
/// selection entry so program-day starts flow through the one draft API.
WorkoutDraftSeed workoutDraftSeedForProgramDay(ProgramDay day) {
  final targetGroups = programDayTargetMuscleGroups(day);
  final curated = day.suggestedExerciseIds.isNotEmpty
      ? day.suggestedExerciseIds
      : curatedExerciseIdsForMuscleGroups(targetGroups);
  return WorkoutDraftSeed(
    initialMuscleGroups: targetGroups,
    programCuratedExerciseIds: curated,
    programPrescriptions: day.prescription,
    programDayLabel: day.label,
    programFocusSummary: programDayFocusSummary(day),
    isProgramWorkout: true,
  );
}

/// Final commit gate shown after CONTINUE, before the live workout timer starts.
/// Returns true only if the user confirms. Non-destructive: declining leaves the
/// review screen untouched.
Future<bool> showStartWorkoutConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: kNeon),
      ),
      title: const Text(
        'START THIS WORKOUT?',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 11,
          color: kNeon,
        ),
      ),
      content: Text(
        'Begin the live session now?',
        style: AppFonts.shareTechMono(fontSize: 14, color: kMutedText),
      ),
      actions: [
        ArcadeTextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'CANCEL',
            style: AppFonts.shareTechMono(color: kMutedText),
          ),
        ),
        SizedBox(
          width: 150,
          child: PixelButton(
            label: 'START',
            fullWidth: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class StartWorkoutPage extends StatefulWidget {
  const StartWorkoutPage({
    super.key,
    this.initialMuscleGroup,
    this.initialMuscleGroups,
    this.programDayLabel,
    this.programFocusSummary,
    this.programCuratedExerciseIds,
    this.programPrescriptions = const {},
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
    this.initialSelectedExerciseIds,
    this.catalogOverride,
    this.embedded = false,
    this.draftController,
    this.onCommitted,
  });

  /// When true the page renders as an in-shell surface (no Scaffold/AppBar and
  /// no own selection bar — the shell's persistent nav + center Train drive the
  /// commit). It reports loadout validity to [draftController] and registers its
  /// confirm+launch as the draft committer.
  final bool embedded;
  final WorkoutDraftController? draftController;

  /// Fired right after a live session is launched, so the shell can drop the
  /// draft and leave selection mode.
  final VoidCallback? onCommitted;

  final String? initialMuscleGroup;
  final List<String>? initialMuscleGroups;

  /// Test seam: supply an in-memory exercise catalog instead of loading
  /// `assets/exercises.json` (matches the codebase's injectable-override idiom).
  final List<Exercise>? catalogOverride;

  /// Pre-selected exercise ids ("repeat workout" from a past session).
  /// Consumed once: after the first preselection pass, changing the muscle
  /// focus falls back to the normal history-based seeding.
  final List<String>? initialSelectedExerciseIds;
  final String? programDayLabel;
  final String? programFocusSummary;

  /// The day's full prescribed loadout — pre-filled, pre-selected, and the
  /// candidate pool for the picker (so every prescribed lift stays addable).
  final List<String>? programCuratedExerciseIds;

  /// Per-exercise sets × reps targets for program days, keyed by exercise id.
  /// Empty for manual workouts.
  final Map<String, SetRepScheme> programPrescriptions;

  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;

  @override
  State<StartWorkoutPage> createState() => _StartWorkoutPageState();
}

class _StartWorkoutPageState extends State<StartWorkoutPage> {
  final FavoriteService _favoriteService = const FavoriteService();
  final TextEditingController _searchController = TextEditingController();

  Future<List<Exercise>>? _exerciseCatalogFuture;
  List<Exercise>? _catalog;
  List<String> _selectedMuscleGroups = const [];

  /// The loadout as provenance-tagged slots (v2 chip-owned model).
  /// [_selectedExerciseIds] is a read-only projection so no writer can bypass
  /// the slot mutation API.
  final List<_LoadoutSlot> _slots = [];

  Set<String> _favoriteExerciseIds = {};
  String _searchQuery = '';
  String? _levelFilter;
  bool _showFavoritesOnly = false;
  bool _filtersExpanded = false;
  int _durationMinutes = WorkoutDefaultsService.defaultDurationMinutes;
  int _restSeconds = 90;

  /// The full curated picker hides behind "ADD EXERCISE" (See All).
  bool _seeAllExpanded = false;
  _SeedSource _seedSource = _SeedSource.none;
  bool _entrySeeded = false;

  /// Program-day in-session state: a live (re-keyed) prescription map, and the
  /// cumulative ephemeral swaps (effectiveOriginalId → replacementId) handed to
  /// the live session so a force-kill resume can re-pair sets×reps.
  late final Map<String, SetRepScheme> _prescriptions = Map.of(
    widget.programPrescriptions,
  );
  final Map<String, String> _sessionSwaps = {};

  /// Read-only projection of the loadout. Mutating the loadout goes through the
  /// slot API ([_selectChip]/[_deselectChip]/[_addUser]/[_removeSlot]/
  /// [_replaceSlot]/[_seedImport]) — there is deliberately no setter.
  Set<String> get _selectedExerciseIds => {for (final slot in _slots) slot.id};

  bool get _programMode => widget.isProgramWorkout;

  Future<List<Exercise>> get _safeExerciseCatalogFuture {
    return _exerciseCatalogFuture ??= widget.catalogOverride != null
        ? Future.value(widget.catalogOverride)
        : ExerciseCatalogService().getFullCatalog();
  }

  @override
  void initState() {
    super.initState();
    _selectedMuscleGroups = normalizeTargetMuscleGroups(
      widget.initialMuscleGroups ??
          [if (widget.initialMuscleGroup != null) widget.initialMuscleGroup!],
    );
    _loadDefaults();
    _loadFavoriteExerciseIds();
    if (widget.embedded) {
      widget.draftController?.registerCommitter(_startSelectedWorkout);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSeed());
  }

  /// Resolves the catalog once, then seeds the loadout by precedence:
  /// repeat import (seed-owned, no chips) → program prescribed lifts (seed-owned,
  /// no chips) → manual entry (pre-select the last completed session's groups and
  /// add each group's 2 defaults). Runs once.
  Future<void> _initSeed() async {
    final catalog = await _safeExerciseCatalogFuture;
    if (!mounted) return;
    setState(() => _catalog = catalog);
    if (_entrySeeded) return;
    _entrySeeded = true;

    final catalogIds = {for (final exercise in catalog) exercise.id};

    // Repeat-workout import: seed-owned slots, chips NOT pre-selected, so a chip
    // toggle can never delete the imported workout (Codex opinion F2).
    if (!_programMode && widget.initialSelectedExerciseIds != null) {
      final valid = widget.initialSelectedExerciseIds!
          .where(catalogIds.contains)
          .toList();
      if (valid.isNotEmpty) {
        _seedImport(valid);
        setState(() => _seedSource = _SeedSource.repeat);
        return;
      }
    }

    // Program day: the prescribed lifts are the (seed-owned) loadout; no chips.
    if (_programMode) {
      final ids = (widget.programCuratedExerciseIds ?? const <String>[])
          .where(catalogIds.contains)
          .toList();
      _seedImport(ids);
      return;
    }

    // Manual: pre-select the last completed session's groups (else any preset),
    // then add each group's 2 defaults — one-tap START for a returning user.
    if (_selectedMuscleGroups.isEmpty) {
      final last = await WorkoutStorageService().lastCompletedSession();
      if (!mounted) return;
      if (last != null) {
        setState(() {
          _selectedMuscleGroups = normalizeTargetMuscleGroups(
            last.targetMuscleGroups,
          );
        });
      }
    }
    for (final group in List<String>.from(_selectedMuscleGroups)) {
      await _selectChip(group, catalog);
      if (!mounted) return;
    }
  }

  // ── Slot mutation API (the only writers of _slots) ────────────────────────

  _LoadoutSlot? _slotFor(String id) {
    for (final slot in _slots) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  /// The 2 defaults for a group: the user's top-2 history for it, else the
  /// curated head.
  Future<List<String>> _defaultIdsForGroup(
    String group,
    List<Exercise> catalog,
  ) async {
    final top = await WorkoutStorageService().topExerciseIdsForTargets(
      [group],
      catalog,
      limit: 2,
    );
    if (top.isNotEmpty) return top;
    // Simple Mode skips the curated first-run template (the generic "forced
    // default") — a Simple-Mode user with no history for this group starts it
    // empty and picks their own. Read at use-time (the curated fallback is rare,
    // only a group with no history) so there's no init race on chip taps.
    if (await SimpleModeService().isEnabled()) return const <String>[];
    return curatedExerciseIdsForMuscleGroups([group]).take(2).toList();
  }

  /// Add a group's 2 defaults as chip-owned (ref-counted). Bails if the group
  /// was deselected while the history read was in flight.
  Future<void> _selectChip(String group, List<Exercise> catalog) async {
    final ids = await _defaultIdsForGroup(group, catalog);
    if (!mounted || !_selectedMuscleGroups.contains(group)) return;
    setState(() {
      for (final id in ids) {
        final existing = _slotFor(id);
        if (existing != null) {
          existing.chipOwners.add(group);
        } else {
          _slots.add(_LoadoutSlot(id: id, chipOwners: {group}));
        }
      }
    });
  }

  /// Drop a group's ownership; a slot is removed only when no chip/user/seed
  /// owner remains — a default shared with another selected group survives (F3).
  void _deselectChip(String group) {
    setState(() {
      for (final slot in _slots) {
        slot.chipOwners.remove(group);
      }
      _slots.removeWhere(
        (slot) => slot.chipOwners.isEmpty && !slot.userOwned && !slot.seedOwned,
      );
    });
  }

  void _addUser(String id) {
    setState(() {
      final existing = _slotFor(id);
      if (existing != null) {
        existing.userOwned = true;
      } else {
        _slots.add(_LoadoutSlot(id: id, userOwned: true));
      }
    });
  }

  void _removeSlot(String id) {
    setState(() => _slots.removeWhere((slot) => slot.id == id));
  }

  /// Swap a slot in place. If [newId] already occupies a slot, fold the old
  /// slot's owners into it and drop the old one — slot ids stay unique so the
  /// derived set never hides a duplicate (Codex plan-review F1).
  void _replaceSlot(String oldId, String newId) {
    setState(() {
      if (oldId == newId) return;
      final oldIndex = _slots.indexWhere((slot) => slot.id == oldId);
      if (oldIndex < 0) return;
      final old = _slots[oldIndex];
      final existing = _slotFor(newId);
      if (existing != null && !identical(existing, old)) {
        existing.chipOwners.addAll(old.chipOwners);
        existing.userOwned = existing.userOwned || old.userOwned;
        existing.seedOwned = existing.seedOwned || old.seedOwned;
        _slots.removeAt(oldIndex);
      } else {
        old.id = newId;
      }
    });
  }

  void _seedImport(List<String> ids) {
    setState(() {
      for (final id in ids) {
        final existing = _slotFor(id);
        if (existing != null) {
          existing.seedOwned = true;
        } else {
          _slots.add(_LoadoutSlot(id: id, seedOwned: true));
        }
      }
    });
  }

  /// Canonical muscle group for an exercise (primary-muscle bucket, else the
  /// stored group). Null when neither resolves.
  String? _groupForExercise(Exercise? exercise) {
    if (exercise == null) return null;
    final primary = exercise.primaryMuscle;
    if (primary != null) {
      final bucket = muscleGroupForDetailed(primary);
      if (bucket != null) return bucket;
    }
    final group = exercise.muscleGroup;
    if (group != null) return normalizeMuscleGroup(group);
    return null;
  }

  @override
  void dispose() {
    if (widget.embedded) widget.draftController?.registerCommitter(null);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final service = WorkoutDefaultsService();
    final duration = await service.getDurationMinutes();
    final rest = await service.getRestSeconds();
    if (!mounted) return;
    setState(() {
      _durationMinutes = duration;
      _restSeconds = rest;
    });
  }

  Future<void> _loadFavoriteExerciseIds() async {
    final favoriteIds = await _favoriteService.getFavoriteExerciseIds();
    if (!mounted) return;
    setState(() => _favoriteExerciseIds = favoriteIds);
  }

  void _toggleMuscleGroup(String muscleGroup) {
    // The chip itself ticks now (ArcadeChip default selection), so no manual
    // haptic here — that would double-fire.
    final wasSelected = _selectedMuscleGroups.contains(muscleGroup);
    setState(() {
      final selected = _selectedMuscleGroups.toSet();
      if (wasSelected) {
        selected.remove(muscleGroup);
      } else {
        selected.add(muscleGroup);
      }
      _selectedMuscleGroups = normalizeTargetMuscleGroups(selected);
    });
    if (wasSelected) {
      _deselectChip(muscleGroup);
    } else {
      final catalog = _catalog;
      if (catalog != null) _selectChip(muscleGroup, catalog);
    }
  }

  /// See-All checkbox toggle: add as user-owned (survives chip deselect) or
  /// remove the slot entirely.
  void _toggleSelectedExercise(String id) {
    if (_selectedExerciseIds.contains(id)) {
      _removeSlot(id);
    } else {
      _addUser(id);
    }
  }

  /// Swap one loadout slot for a same-muscle alternative (or open See All).
  Future<void> _replaceExercise(Exercise replaced) async {
    final catalog = _catalog ?? await _safeExerciseCatalogFuture;
    if (!mounted) return;
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final group = _groupForExercise(replaced);
    final pool = group == null
        ? const <Exercise>[]
        : [
            for (final id in curatedExerciseIdsForMuscleGroups([group]))
              if (byId[id] != null) byId[id]!,
          ];
    final alternatives = alternativesFor(replaced, pool, _selectedExerciseIds);
    final result = await showExerciseReplaceSheet(
      context,
      replaced: replaced,
      alternatives: alternatives,
    );
    if (!mounted || result == null) return;
    if (result.seeAll) {
      setState(() => _seeAllExpanded = true);
      return;
    }
    final replacement = result.replacement!;
    _replaceSlot(replaced.id, replacement.id);
    if (_programMode) _recordProgramSwap(replaced.id, replacement.id);
  }

  void _removeExercise(String id) => _removeSlot(id);

  /// Program-day ephemeral swap: re-key the live prescription to the new lift
  /// and record the cumulative effectiveOriginalId→replacement map so a
  /// force-kill resume can re-pair sets×reps (Codex F1/F4).
  void _recordProgramSwap(String oldId, String newId) {
    final scheme = _prescriptions.remove(oldId);
    if (scheme != null) _prescriptions[newId] = scheme;
    String? origin;
    for (final entry in _sessionSwaps.entries) {
      if (entry.value == oldId) {
        origin = entry.key;
        break;
      }
    }
    _sessionSwaps[origin ?? oldId] = newId;
  }

  Future<bool> _toggleFavoriteExercise(Exercise exercise) async {
    final isFavorite = await _favoriteService.toggleFavoriteExercise(
      exercise.id,
    );
    if (!mounted) return isFavorite;

    setState(() {
      final next = {..._favoriteExerciseIds};
      if (isFavorite) {
        next.add(exercise.id);
      } else {
        next.remove(exercise.id);
      }
      _favoriteExerciseIds = next;
    });
    return isFavorite;
  }

  Future<void> _startSelectedWorkout() async {
    if (_selectedExerciseIds.isEmpty) return;

    final catalog = await _safeExerciseCatalogFuture;
    if (!mounted) return;
    final effectiveGroups = _candidateGroups(catalog);
    if (effectiveGroups.isEmpty) return;
    // Loadout order = slot order.
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final selected = [
      for (final slot in _slots)
        if (byId[slot.id] != null) byId[slot.id]!,
    ];
    if (selected.isEmpty) return;

    final ongoing = await WorkoutStorageService().getOngoingSession();
    if (!mounted) return;
    if (ongoing != null) {
      final action = await showActiveSessionFoundDialog(context);
      if (!mounted || action == null) return;
      if (action == ActiveSessionAction.continueOld) {
        await _continueOngoingSession(ongoing);
        return;
      }
      await _endOngoingWithoutSummary(ongoing);
    }

    if (!mounted) return;
    // Final commit gate before the live timer starts. Cancel → stay on the
    // review screen with no session created. (Resuming an ongoing session above
    // returns early and is exempt — it's continuing, not starting.)
    final confirmed = await showStartWorkoutConfirmDialog(context);
    if (!mounted || !confirmed) return;

    _pushActiveWorkout(
      muscleGroup: effectiveGroups.first,
      targetMuscleGroups: effectiveGroups,
      durationMinutes: _durationMinutes,
      exercises: selected,
      restSeconds: _restSeconds,
      isProgramWorkout: widget.isProgramWorkout,
      advanceProgramRestDayOnCompletion:
          widget.advanceProgramRestDayOnCompletion,
      prescriptions: _programMode ? _prescriptions : null,
      programSwaps: _programMode ? _sessionSwaps : null,
    );
  }

  Future<void> _continueOngoingSession(WorkoutSession session) async {
    final catalog = await _safeExerciseCatalogFuture;
    if (!mounted) return;

    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final exerciseIds = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds
        : session.exercises.map((log) => log.exerciseId).toList();
    final exercises = exerciseIds
        .map((id) => byId[id])
        .whereType<Exercise>()
        .toList();

    if (exercises.isEmpty) {
      showArcadeNotice(context, 'Could not resume active session.');
      return;
    }

    // Rebuilt from program state: the session's own prescriptions were never
    // persisted, and widget.programPrescriptions may belong to a newer day.
    final programService = ProgramService();
    _pushActiveWorkout(
      muscleGroup: session.muscleGroup,
      targetMuscleGroups: session.targetMuscleGroups,
      durationMinutes: session.targetDurationMinutes,
      exercises: exercises,
      restSeconds: _restSeconds,
      resumeFromSession: session,
      isProgramWorkout: await programService.isOngoingProgramSession(
        session.id,
      ),
      advanceProgramRestDayOnCompletion: await programService
          .isOngoingProgramRestSession(session.id),
      prescriptions: await programService.prescriptionsForOngoingSession(
        session.id,
      ),
    );
  }

  Future<void> _endOngoingWithoutSummary(WorkoutSession session) async {
    final elapsedSeconds = session.elapsedSecondsForDisplay(DateTime.now());
    await WorkoutStorageService().replaceOngoingWithAbandoned(
      WorkoutSession(
        id: session.id,
        date: DateTime.now(),
        startedAt: session.startedAt,
        muscleGroup: session.muscleGroup,
        targetMuscleGroups: session.targetMuscleGroups,
        targetDurationMinutes: session.targetDurationMinutes,
        actualDurationSeconds: elapsedSeconds,
        exercises: const [],
        estimatedCalories: CalorieService.estimateCaloriesForGroups(
          session.targetMuscleGroups,
          elapsedSeconds,
        ),
        isPartial: true,
        isAbandoned: true,
      ),
    );
    await ProgramService().clearOngoingProgramSession(session.id);
  }

  // Opens the general (pre-session) mobility guide. Optional, unrewarded
  // reference — the rewarded warm-up is the warm-up *sets* logged in-session.
  Future<void> _openWarmupSheet() async {
    await WarmupSheet.show(context, targets: _selectedMuscleGroups);
  }

  void _pushActiveWorkout({
    required String muscleGroup,
    required List<String> targetMuscleGroups,
    required int durationMinutes,
    required List<Exercise> exercises,
    required int restSeconds,
    WorkoutSession? resumeFromSession,
    bool isProgramWorkout = false,
    bool advanceProgramRestDayOnCompletion = false,
    Map<String, SetRepScheme>? prescriptions,
    Map<String, String>? programSwaps,
  }) {
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: muscleGroup,
          targetMuscleGroups: targetMuscleGroups,
          durationMinutes: durationMinutes,
          exercises: exercises,
          restSeconds: restSeconds,
          resumeFromSession: resumeFromSession,
          isProgramWorkout: isProgramWorkout,
          advanceProgramRestDayOnCompletion: advanceProgramRestDayOnCompletion,
          prescriptions: prescriptions ?? widget.programPrescriptions,
          programSwaps: programSwaps,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
    // Embedded: the live session is launched — tell the shell to drop the draft
    // and leave selection mode. No-op for the standalone pushed page.
    widget.onCommitted?.call();
  }

  /// Candidate-universe groups = selected chips ∪ the groups of the current
  /// slots, so See-All/ADD stays relevant even when the loadout has no chips lit
  /// (a repeat import — Codex plan-review F5).
  List<String> _candidateGroups(List<Exercise> exercises) {
    final groups = _selectedMuscleGroups.toSet();
    final byId = {for (final exercise in exercises) exercise.id: exercise};
    for (final slot in _slots) {
      final group = _groupForExercise(byId[slot.id]);
      if (group != null) groups.add(group);
    }
    return normalizeTargetMuscleGroups(groups.toList());
  }

  List<Exercise> _candidateExercises(
    List<Exercise> exercises, {
    bool applyFilters = true,
  }) {
    final groups = _candidateGroups(exercises);
    if (groups.isEmpty && _slots.isEmpty) return const [];
    final exerciseById = {
      for (final exercise in exercises) exercise.id: exercise,
    };
    // Program mode shows today's prescribed lifts PLUS the rest of the curated
    // pool for the day's locked muscles; manual shows curated for the universe.
    final ids = _programMode && widget.programCuratedExerciseIds != null
        ? [
            ...widget.programCuratedExerciseIds!,
            ...curatedExerciseIdsForMuscleGroups(groups),
          ]
        : curatedExerciseIdsForMuscleGroups(groups);
    final result = <Exercise>[];
    final added = <String>{};

    void addExercise(Exercise exercise) {
      if (added.add(exercise.id)) result.add(exercise);
    }

    for (final exercise in exercises) {
      if (!exercise.isCustom) continue;
      final group = exercise.muscleGroup;
      if (group != null && hasTargetMuscle(groups, group)) {
        addExercise(exercise);
      }
    }

    for (final id in _selectedExerciseIds) {
      final exercise = exerciseById[id];
      if (exercise != null) addExercise(exercise);
    }

    for (final id in ids) {
      final exercise = exerciseById[id];
      if (exercise != null) addExercise(exercise);
    }

    if (!applyFilters) return result;

    var filtered = result;
    if (_levelFilter != null) {
      filtered = filtered
          .where((exercise) => exercise.level == _levelFilter)
          .toList();
    }
    if (_showFavoritesOnly) {
      filtered = filtered
          .where((exercise) => _favoriteExerciseIds.contains(exercise.id))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((exercise) => exercise.name.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = targetMuscleGroupsLabel(
      _selectedMuscleGroups,
      fallback: 'target',
    );
    final sections = _programMode
        ? _buildProgramSections(targetLabel)
        : _buildManualSections(targetLabel);
    // Optional pre-session mobility guide — a calm, unrewarded reference (the
    // rewarded warm-up is the warm-up sets logged in-session). Shown once
    // there's a loadout to start.
    if (_selectedExerciseIds.isNotEmpty) {
      sections
        ..add(const SizedBox(height: kSpace5))
        ..add(_WarmupStartCard(onTap: _openWarmupSheet));
    }

    // Embedded under the shell: no Scaffold/AppBar/selection bar — the shell's
    // persistent nav + center Train commit. Report loadout validity so Train can
    // arm (re-read synchronously at commit by the controller).
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.draftController?.setValid(_selectedExerciseIds.isNotEmpty);
        }
      });
      return SingleChildScrollView(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Start Workout')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sections,
              ),
            ),
          ),
          _SelectionBar(
            count: _selectedExerciseIds.length,
            onContinue: _selectedExerciseIds.isEmpty
                ? null
                : _startSelectedWorkout,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProgramSections(String targetLabel) {
    final hasLoadout = _selectedExerciseIds.isNotEmpty;
    return [
      const _StepHeader(label: '1. CHOOSE TARGET'),
      const SizedBox(height: kSpace2),
      _ProgramTargetSummary(
        label: widget.programDayLabel ?? targetLabel,
        summary: widget.programFocusSummary ?? 'Program workout selected.',
      ),
      if (_targetPreview() case final preview?) ...[
        const SizedBox(height: kSpace4),
        preview,
      ],
      const SizedBox(height: kSpace5),
      const _StepHeader(label: '2. YOUR LOADOUT'),
      const SizedBox(height: kSpace2),
      if (hasLoadout) ...[
        ..._buildLoadoutCards(),
        const SizedBox(height: kSpace2),
        _AddExerciseButton(
          expanded: _seeAllExpanded,
          onTap: () => setState(() => _seeAllExpanded = !_seeAllExpanded),
        ),
      ] else
        Text(
          'Choose at least one exercise.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
      if (_seeAllExpanded || !hasLoadout) ...[
        const SizedBox(height: kSpace3),
        _buildSearchAndFilters(),
        const SizedBox(height: kSpace3),
        _buildExerciseList(),
      ],
    ];
  }

  List<Widget> _buildManualSections(String targetLabel) {
    final hasLoadout = _selectedExerciseIds.isNotEmpty;
    return [
      const _StepHeader(label: '1. CHOOSE TARGET'),
      const SizedBox(height: kSpace2),
      Text(
        _selectedMuscleGroups.isEmpty
            ? 'Tap a target — two exercises are added for each.'
            : targetLabel,
        style: AppFonts.shareTechMono(
          color: _selectedMuscleGroups.isEmpty ? kMutedText : kText,
          fontSize: 14,
          fontWeight: _selectedMuscleGroups.isEmpty
              ? FontWeight.w400
              : FontWeight.w700,
        ),
      ),
      const SizedBox(height: kSpace4),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final muscleGroup in canonicalMuscleGroups)
            ArcadeChip(
              label: muscleGroup,
              selected: _selectedMuscleGroups.contains(muscleGroup),
              onTap: () => _toggleMuscleGroup(muscleGroup),
            ),
        ],
      ),
      if (_targetPreview() case final preview?) ...[
        const SizedBox(height: kSpace4),
        preview,
      ],
      const SizedBox(height: kSpace5),
      _StepHeader(label: hasLoadout ? '2. YOUR LOADOUT' : '2. PICK EXERCISES'),
      const SizedBox(height: kSpace2),
      if (hasLoadout) ...[
        if (_seedSource.label != null) ...[
          Text(
            _seedSource.label!,
            style: AppFonts.shareTechMono(color: kNeon, fontSize: 12),
          ),
          const SizedBox(height: kSpace2),
        ],
        ..._buildLoadoutCards(),
        const SizedBox(height: kSpace2),
        _AddExerciseButton(
          expanded: _seeAllExpanded,
          onTap: () => setState(() => _seeAllExpanded = !_seeAllExpanded),
        ),
      ] else
        Text(
          _selectedMuscleGroups.isEmpty
              ? 'Pick a target above to build your loadout.'
              : 'Choose at least one exercise.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
      if (_seeAllExpanded ||
          (!hasLoadout && _selectedMuscleGroups.isNotEmpty)) ...[
        const SizedBox(height: kSpace3),
        _buildSearchAndFilters(),
        const SizedBox(height: kSpace3),
        _buildExerciseList(),
      ],
    ];
  }

  /// The "today's targets" body preview for the current loadout, or null when
  /// there's nothing to show yet (catalog still loading, or no lifts picked).
  /// Reuses the shared exercise→body-muscle mapping so it agrees with the
  /// history coverage map.
  Widget? _targetPreview() {
    final catalog = _catalog;
    if (catalog == null || _slots.isEmpty) return null;
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final selected = [
      for (final slot in _slots)
        if (byId[slot.id] != null) byId[slot.id]!,
    ];
    if (selected.isEmpty) return null;
    final targets = targetedBodyMuscles(selected);
    if (targets.primary.isEmpty && targets.secondary.isEmpty) return null;
    return TargetBodyPreview(
      primaryMuscles: targets.primary,
      secondaryMuscles: targets.secondary,
    );
  }

  List<Widget> _buildLoadoutCards() {
    final catalog = _catalog;
    if (catalog == null) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: kSpace4),
          child: Center(child: PixelLoader()),
        ),
      ];
    }
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final cards = <Widget>[];
    for (final slot in _slots) {
      final exercise = byId[slot.id];
      if (exercise == null) continue;
      cards.add(
        ExerciseCard(
          exercise: exercise,
          showCheckbox: false,
          showFavorite: false,
          isSelected: true,
          isCustom: exercise.isCustom,
          onTap: () => _replaceExercise(exercise),
          trailing: _LoadoutActions(
            onReplace: () => _replaceExercise(exercise),
            onRemove: () => _removeExercise(exercise.id),
          ),
        ),
      );
    }
    return cards;
  }

  Widget _buildSearchAndFilters() {
    final hasFilter = _levelFilter != null || _showFavoritesOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ArcadeChip(
              label: hasFilter ? 'FILTER ON' : 'FILTER',
              selected: _filtersExpanded || hasFilter,
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            ),
            if (hasFilter) ...[
              const SizedBox(width: kSpace2),
              ArcadeTextButton(
                onPressed: () => setState(() {
                  _levelFilter = null;
                  _showFavoritesOnly = false;
                }),
                child: Text(
                  'Clear',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_filtersExpanded) ...[
          const SizedBox(height: kSpace2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ArcadeChip(
                  label: 'All',
                  selected: _levelFilter == null && !_showFavoritesOnly,
                  onTap: () => setState(() {
                    _levelFilter = null;
                    _showFavoritesOnly = false;
                  }),
                ),
                const SizedBox(width: kSpace2),
                for (final filter in const [
                  ('Beginner', 'beginner'),
                  ('Intermediate', 'intermediate'),
                  ('Expert', 'expert'),
                ]) ...[
                  ArcadeChip(
                    label: filter.$1,
                    selected: _levelFilter == filter.$2,
                    onTap: () => setState(() {
                      _levelFilter = _levelFilter == filter.$2
                          ? null
                          : filter.$2;
                    }),
                  ),
                  const SizedBox(width: kSpace2),
                ],
                ArcadeChip(
                  label: 'Fav',
                  selected: _showFavoritesOnly,
                  onTap: () =>
                      setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: kSpace2),
        ArcadeTextField(
          controller: _searchController,
          onChanged: (query) => setState(() => _searchQuery = query),
          style: AppFonts.shareTechMono(color: kText, fontSize: 14),
          hintText: 'Search exercises',
          hintStyle: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: ImageIcon(
              AssetImage('assets/icons/control/icon_search.png'),
              color: kMutedText,
              size: 18,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseList() {
    return FutureBuilder<List<Exercise>>(
      future: _safeExerciseCatalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: kSpace5),
            child: Center(child: PixelLoader()),
          );
        }
        if (snapshot.hasError) {
          return const _InfoMessage(label: 'Could not load exercises.');
        }

        final filtered = _candidateExercises(snapshot.data ?? const []);
        if (filtered.isEmpty) {
          return const _InfoMessage(label: 'No exercises found.');
        }

        return Column(
          children: [
            for (final exercise in filtered)
              ExerciseCard(
                exercise: exercise,
                showInfoIcon: true,
                showFavorite: false,
                showCheckbox: true,
                isFavorite: _favoriteExerciseIds.contains(exercise.id),
                isSelected: _selectedExerciseIds.contains(exercise.id),
                isCustom: exercise.isCustom,
                onTap: () => _toggleSelectedExercise(exercise.id),
                onInfoPressed: () => _showExercisePreview(exercise),
                onCheckboxToggle: () => _toggleSelectedExercise(exercise.id),
              ),
          ],
        );
      },
    );
  }

  void _showExercisePreview(Exercise exercise) {
    final isSelected = _selectedExerciseIds.contains(exercise.id);
    var isFavorite = _favoriteExerciseIds.contains(exercise.id);
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(exercise.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ArcadeImageFilter(
                          borderRadius: BorderRadius.zero,
                          child: Image.asset(
                            exerciseThumbAsset(exercise),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (context, error, stackTrace) =>
                                const _NoPhotoPreview(),
                          ),
                        ),
                        Container(color: kBg.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kSpace3),
                LevelBadge(exercise: exercise),
                const SizedBox(height: kSpace2),
                Text(
                  'Muscles: ${targetMuscleGroupsLabel(_selectedMuscleGroups, fallback: 'target')}',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: kSpace3),
                ArcadeFilled.icon(
                  onPressed: () async {
                    final next = await _toggleFavoriteExercise(exercise);
                    if (context.mounted) {
                      setDialogState(() => isFavorite = next);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kBorderVariant,
                    foregroundColor: kText,
                    side: const BorderSide(color: kBorder),
                  ),
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_sharp
                        : Icons.favorite_border_sharp,
                    size: 18,
                    color: isFavorite ? kDanger : kText,
                  ),
                  label: Text(isFavorite ? 'FAVORITE' : 'MARK FAVORITE'),
                ),
                const SizedBox(height: kSpace4),
                PixelButton(
                  label: isSelected ? 'DESELECT' : 'SELECT',
                  onPressed: () {
                    Navigator.pop(context);
                    _toggleSelectedExercise(exercise.id);
                  },
                ),
                const SizedBox(height: kSpace2),
                PixelButton(
                  label: 'CLOSE',
                  secondary: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          actions: const [],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
        color: kNeon,
      ),
    );
  }
}

/// Pre-session warm-up opt-in card. Tapping opens the tailored warm-up sheet;
/// once done it flips to a calm confirmed state. Its absence/decline is silent
/// (no nag) — the reward is a small cherry, the prompt is an invitation.
/// Optional pre-session mobility guide entry — calm and unrewarded (the rewarded
/// warm-up is the warm-up *sets* logged in-session). Opens [WarmupSheet].
class _WarmupStartCard extends StatelessWidget {
  const _WarmupStartCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Warm-up guide — optional pre-session mobility routine',
      child: PhosphorTap(
        onTap: onTap,
        haptic: HapticIntent.selection,
        sound: UiSound.tick,
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_sharp,
                size: 22,
                color: kMutedText,
              ),
              const SizedBox(width: kSpace3),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WARM-UP GUIDE',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: kText,
                      ),
                    ),
                    SizedBox(height: 5),
                    _WarmupGuideSubtitle(),
                  ],
                ),
              ),
              const SizedBox(width: kSpace2),
              const Icon(
                Icons.chevron_right_sharp,
                size: 18,
                color: kMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarmupGuideSubtitle extends StatelessWidget {
  const _WarmupGuideSubtitle();

  @override
  Widget build(BuildContext context) => Text(
    'Optional — a quick tailored mobility routine.',
    style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
  );
}

/// A provenance-tagged loadout entry (v2). `chipOwners` ref-counts the muscle
/// chips that contributed it; `userOwned` = added via See All; `seedOwned` =
/// imported (repeat / program prescribed). The slot survives a chip deselect
/// while any owner remains. `id` is mutable for in-place Replace.
class _LoadoutSlot {
  _LoadoutSlot({
    required this.id,
    Set<String>? chipOwners,
    this.userOwned = false,
    this.seedOwned = false,
  }) : chipOwners = chipOwners ?? <String>{};

  String id;
  final Set<String> chipOwners;
  bool userOwned;
  bool seedOwned;
}

/// Where the manual loadout's source label came from (repeat import only in v2).
enum _SeedSource { none, usual, target, curated, repeat }

extension _SeedSourceLabel on _SeedSource {
  String? get label => switch (this) {
    _SeedSource.usual => 'YOUR USUAL LIFTS',
    _SeedSource.target => 'RECENT FOR THIS FOCUS',
    _SeedSource.curated => 'STARTER SET',
    _SeedSource.repeat => 'REPEAT OF LAST WORKOUT',
    _SeedSource.none => null,
  };
}

/// Loadout card trailing controls: swap (Replace sheet) and remove.
class _LoadoutActions extends StatelessWidget {
  const _LoadoutActions({required this.onReplace, required this.onRemove});

  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArcadeIconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: onReplace,
          tooltip: 'Replace',
          icon: const Icon(Icons.swap_horiz_sharp, size: 20, color: kNeon),
        ),
        ArcadeIconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: onRemove,
          tooltip: 'Remove',
          icon: const Icon(Icons.close_sharp, size: 18, color: kMutedText),
        ),
      ],
    );
  }
}

/// Demotes the full curated picker to "the exception": toggles See All.
class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PixelButton(
      label: expanded ? 'HIDE EXERCISE LIST' : 'ADD EXERCISE',
      secondary: true,
      onPressed: onTap,
    );
  }
}

class _ProgramTargetSummary extends StatelessWidget {
  const _ProgramTargetSummary({required this.label, required this.summary});

  final String label;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const ImageIcon(
            AssetImage('assets/icons/control/icon_scroll.png'),
            color: kNeon,
            size: 18,
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: kNeon,
                  ),
                ),
                const SizedBox(height: kSpace2),
                Text(
                  summary,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onContinue});

  final int count;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        padding: const EdgeInsets.all(kSpace3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0 ? 'NO EXERCISES SELECTED' : '$count SELECTED',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: kText,
                ),
              ),
            ),
            PixelButton(
              label: 'CONTINUE',
              fullWidth: false,
              powerOn: true,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: kSpace3),
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppFonts.shareTechMono(color: kMutedText, fontSize: 14),
      ),
    );
  }
}

class _NoPhotoPreview extends StatelessWidget {
  const _NoPhotoPreview();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'NO PHOTO',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
