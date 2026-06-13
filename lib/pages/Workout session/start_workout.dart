import 'package:flutter/material.dart';

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
import '../../services/program_service.dart';
import '../../services/workout_defaults_service.dart';
import '../../services/workout_storage_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/active_session_found_dialog.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/arcade_image_filter.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/exercise_card.dart';
import '../../widgets/exercise_replace_sheet.dart';
import '../../widgets/level_badge.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/pixel_loader.dart';
import 'active_workout.dart';

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
        TextButton(
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
  });

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
  Set<String> _selectedExerciseIds = {};
  Set<String> _favoriteExerciseIds = {};
  String _searchQuery = '';
  String? _levelFilter;
  bool _showFavoritesOnly = false;
  bool _filtersExpanded = false;
  int _durationMinutes = WorkoutDefaultsService.defaultDurationMinutes;
  int _restSeconds = 90;

  /// Manual-path UI state. The muscle target step collapses behind a "Focus"
  /// affordance once a default loadout exists; the full curated picker hides
  /// behind "ADD EXERCISE" (See All). `_userTouchedSelection` guards the
  /// history default from re-clobbering a manual edit (Codex plan-review F2).
  bool _targetExpanded = false;
  bool _seeAllExpanded = false;
  bool _userTouchedSelection = false;
  _SeedSource _seedSource = _SeedSource.none;

  /// Minimum live exercises a history seed must yield to become the front-door
  /// default (Codex plan-review F3 quality gate). Below this → chip-first.
  static const int _minSeedSize = 3;

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
    // A preset target (program day or repeat-workout) keeps the chips visible;
    // a plain manual quick-start tries the front-door default first.
    _targetExpanded = _selectedMuscleGroups.isNotEmpty;
    _loadDefaults();
    _loadFavoriteExerciseIds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSeed());
  }

  /// Resolves the catalog once, then applies the right pre-selection per the
  /// precedence order (Codex plan-review F2): program / preset target / repeat
  /// run the existing target seeding; a plain manual start gets the front-door
  /// "usual" default.
  Future<void> _initSeed() async {
    final catalog = await _safeExerciseCatalogFuture;
    if (!mounted) return;
    setState(() => _catalog = catalog);
    if (_programMode ||
        _selectedMuscleGroups.isNotEmpty ||
        widget.initialSelectedExerciseIds != null) {
      await _refreshHistoryPreselection();
    } else {
      await _applyFrontDoorDefault(catalog);
    }
  }

  /// Plain manual quick-start: seed the screen with the user's frequency-ranked
  /// "usual" lifts across all training. Accept only if ≥[_minSeedSize] live
  /// exercises survive AND their muscle groups resolve (so START and the curated
  /// See-All stay coherent); otherwise fall back to the chip-first flow.
  Future<void> _applyFrontDoorDefault(List<Exercise> catalog) async {
    if (_userTouchedSelection || _selectedExerciseIds.isNotEmpty) return;
    final seed = await WorkoutStorageService().topExerciseIds(catalog, limit: 5);
    if (!mounted || _userTouchedSelection || _selectedExerciseIds.isNotEmpty) {
      return;
    }
    final groups = _groupsForIds(seed, catalog);
    if (seed.length >= _minSeedSize && groups.isNotEmpty) {
      setState(() {
        _selectedExerciseIds = seed.toSet();
        _selectedMuscleGroups = groups;
        _seedSource = _SeedSource.usual;
        _targetExpanded = false;
        _seeAllExpanded = false;
      });
    } else {
      setState(() {
        _targetExpanded = true;
        _seeAllExpanded = true;
        _seedSource = _SeedSource.none;
      });
    }
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

  /// Deduped, normalized canonical groups implied by a set of exercise ids —
  /// used to derive the target focus from a history-seeded loadout.
  List<String> _groupsForIds(Iterable<String> ids, List<Exercise> catalog) {
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final groups = <String>[];
    for (final id in ids) {
      final group = _groupForExercise(byId[id]);
      if (group != null) groups.add(group);
    }
    return normalizeTargetMuscleGroups(groups);
  }

  @override
  void dispose() {
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
    setState(() {
      final selected = _selectedMuscleGroups.toSet();
      if (selected.contains(muscleGroup)) {
        selected.remove(muscleGroup);
      } else {
        selected.add(muscleGroup);
      }
      _selectedMuscleGroups = normalizeTargetMuscleGroups(selected);
      _selectedExerciseIds = {};
      // A deliberate focus change re-seeds the loadout for the new target.
      _userTouchedSelection = false;
    });
    _refreshHistoryPreselection();
  }

  bool _initialSelectionConsumed = false;

  Future<void> _refreshHistoryPreselection() async {
    final targets = List<String>.from(_selectedMuscleGroups);
    if (targets.isEmpty) {
      if (mounted) setState(() => _selectedExerciseIds = {});
      return;
    }

    final catalog = await _safeExerciseCatalogFuture;
    if (mounted && _catalog == null) setState(() => _catalog = catalog);

    final initialIds = widget.initialSelectedExerciseIds;
    if (initialIds != null && !_initialSelectionConsumed) {
      _initialSelectionConsumed = true;
      final catalogIds = {for (final exercise in catalog) exercise.id};
      final valid = initialIds.where(catalogIds.contains).toSet();
      if (valid.isNotEmpty && mounted) {
        setState(() {
          _selectedExerciseIds = valid;
          _seedSource = _SeedSource.repeat;
        });
        return;
      }
    }

    // Program mode pre-selects today's full prescribed loadout (not a slice).
    if (_programMode && widget.programCuratedExerciseIds != null) {
      final ids = widget.programCuratedExerciseIds!;
      if (!mounted || !_sameTargets(targets, _selectedMuscleGroups)) return;
      setState(() => _selectedExerciseIds = ids.toSet());
      return;
    }

    // Manual target: the frequency "usual" for this focus, else the curated
    // starter head so a never-trained target still yields a non-empty default.
    final topIds = await WorkoutStorageService().topExerciseIdsForTargets(
      targets,
      catalog,
      limit: 5,
    );
    if (!mounted || !_sameTargets(targets, _selectedMuscleGroups)) return;
    if (topIds.isNotEmpty) {
      setState(() {
        _selectedExerciseIds = topIds.toSet();
        _seedSource = _SeedSource.target;
      });
    } else {
      final starter = curatedExerciseIdsForMuscleGroups(targets).take(5).toList();
      setState(() {
        _selectedExerciseIds = starter.toSet();
        _seedSource = starter.isEmpty ? _SeedSource.none : _SeedSource.curated;
      });
    }
  }

  bool _sameTargets(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _toggleSelectedExercise(String id) {
    setState(() {
      final next = {..._selectedExerciseIds};
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      _selectedExerciseIds = next;
      _userTouchedSelection = true;
    });
  }

  /// Swap one loadout slot for an alternative (or open See All). Preserves the
  /// slot's position by mapping the id in place across the ordered selection.
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
    setState(() {
      _selectedExerciseIds = {
        for (final id in _selectedExerciseIds)
          if (id == replaced.id) replacement.id else id,
      };
      _userTouchedSelection = true;
    });
  }

  void _removeExercise(String id) {
    setState(() {
      _selectedExerciseIds = {
        for (final existing in _selectedExerciseIds)
          if (existing != id) existing,
      };
      _userTouchedSelection = true;
    });
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
    if (_selectedMuscleGroups.isEmpty || _selectedExerciseIds.isEmpty) return;

    final catalog = await _safeExerciseCatalogFuture;
    final selected = _candidateExercises(
      catalog,
      applyFilters: false,
    ).where((exercise) => _selectedExerciseIds.contains(exercise.id)).toList();
    if (!mounted || selected.isEmpty) return;

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
      muscleGroup: _selectedMuscleGroups.first,
      targetMuscleGroups: _selectedMuscleGroups,
      durationMinutes: _durationMinutes,
      exercises: selected,
      restSeconds: _restSeconds,
      isProgramWorkout: widget.isProgramWorkout,
      advanceProgramRestDayOnCompletion:
          widget.advanceProgramRestDayOnCompletion,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resume active session.')),
      );
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
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    );
  }

  List<Exercise> _candidateExercises(
    List<Exercise> exercises, {
    bool applyFilters = true,
  }) {
    if (_selectedMuscleGroups.isEmpty) return const [];
    final exerciseById = {
      for (final exercise in exercises) exercise.id: exercise,
    };
    // Program mode shows today's prescribed lifts PLUS the rest of the curated
    // pool for the day's locked muscles, so the user can genuinely add/swap
    // (not just re-check the prescribed set). Today's lifts stay pre-selected.
    final ids = _programMode && widget.programCuratedExerciseIds != null
        ? [
            ...widget.programCuratedExerciseIds!,
            ...curatedExerciseIdsForMuscleGroups(_selectedMuscleGroups),
          ]
        : curatedExerciseIdsForMuscleGroups(_selectedMuscleGroups);
    final result = <Exercise>[];
    final added = <String>{};

    void addExercise(Exercise exercise) {
      if (added.add(exercise.id)) result.add(exercise);
    }

    for (final exercise in exercises) {
      if (!exercise.isCustom) continue;
      final group = exercise.muscleGroup;
      if (group != null && hasTargetMuscle(_selectedMuscleGroups, group)) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Start Workout')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _programMode
                    ? _buildProgramSections(targetLabel)
                    : _buildManualSections(targetLabel),
              ),
            ),
          ),
          _SelectionBar(
            count: _selectedExerciseIds.length,
            onContinue:
                _selectedMuscleGroups.isEmpty || _selectedExerciseIds.isEmpty
                ? null
                : _startSelectedWorkout,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProgramSections(String targetLabel) {
    return [
      const _StepHeader(label: '1. CHOOSE TARGET'),
      const SizedBox(height: kSpace2),
      _ProgramTargetSummary(
        label: widget.programDayLabel ?? targetLabel,
        summary: widget.programFocusSummary ?? 'Program workout selected.',
      ),
      if (_selectedMuscleGroups.isNotEmpty) ...[
        const SizedBox(height: kSpace5),
        const _StepHeader(label: '2. PICK EXERCISES'),
        const SizedBox(height: kSpace2),
        Text(
          _selectedExerciseIds.isEmpty
              ? 'Choose at least one exercise.'
              : '${_selectedExerciseIds.length} selected',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
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
      if (_targetExpanded) ...[
        Text(
          _selectedMuscleGroups.isEmpty
              ? 'Tap one target to begin. Add more only if needed.'
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
      ] else
        _FocusSummary(
          label: targetLabel,
          onChange: () => setState(() => _targetExpanded = true),
        ),
      if (_selectedMuscleGroups.isNotEmpty) ...[
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
            'Choose at least one exercise.',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
          ),
        if (_seeAllExpanded || !hasLoadout) ...[
          const SizedBox(height: kSpace3),
          _buildSearchAndFilters(),
          const SizedBox(height: kSpace3),
          _buildExerciseList(),
        ],
      ],
    ];
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
    for (final id in _selectedExerciseIds) {
      final exercise = byId[id];
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
              TextButton(
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
                FilledButton.icon(
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

/// Where the manual default loadout came from — drives an honest source label
/// (Codex plan-review F3) so a history-seeded default is never presented as if
/// the user hand-picked it.
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

/// Collapsed muscle-target row shown once a default loadout exists — keeps the
/// focus/stat cue visible (Codex F5) while hiding the chips behind CHANGE.
class _FocusSummary extends StatelessWidget {
  const _FocusSummary({required this.label, required this.onChange});

  final String label;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'FOCUS: ${label.toUpperCase()}',
              style: AppFonts.shareTechMono(
                color: kText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(
              'CHANGE',
              style: AppFonts.shareTechMono(color: kNeon, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
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
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: onReplace,
          tooltip: 'Replace',
          icon: const Icon(Icons.swap_horiz_sharp, size: 20, color: kNeon),
        ),
        IconButton(
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
