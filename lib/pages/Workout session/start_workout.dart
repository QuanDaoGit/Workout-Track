import 'package:flutter/material.dart';

import '../../data/curated_exercises.dart';
import '../../data/muscle_groups.dart';
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
import '../../widgets/level_badge.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/pixel_loader.dart';
import 'active_workout.dart';

class StartWorkoutPage extends StatefulWidget {
  const StartWorkoutPage({
    super.key,
    this.initialMuscleGroup,
    this.initialMuscleGroups,
    this.programDayLabel,
    this.programFocusSummary,
    this.programCuratedExerciseIds,
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
  });

  final String? initialMuscleGroup;
  final List<String>? initialMuscleGroups;
  final String? programDayLabel;
  final String? programFocusSummary;
  final List<String>? programCuratedExerciseIds;
  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;

  @override
  State<StartWorkoutPage> createState() => _StartWorkoutPageState();
}

class _StartWorkoutPageState extends State<StartWorkoutPage> {
  final FavoriteService _favoriteService = const FavoriteService();
  final TextEditingController _searchController = TextEditingController();

  Future<List<Exercise>>? _exerciseCatalogFuture;
  List<String> _selectedMuscleGroups = const [];
  Set<String> _selectedExerciseIds = {};
  Set<String> _favoriteExerciseIds = {};
  String _searchQuery = '';
  String? _levelFilter;
  bool _showFavoritesOnly = false;
  bool _filtersExpanded = false;
  int _durationMinutes = WorkoutDefaultsService.defaultDurationMinutes;
  int _restSeconds = 90;

  bool get _programMode => widget.isProgramWorkout;

  Future<List<Exercise>> get _safeExerciseCatalogFuture {
    return _exerciseCatalogFuture ??= ExerciseCatalogService().getFullCatalog();
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
    if (_selectedMuscleGroups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshHistoryPreselection();
      });
    }
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
    });
    _refreshHistoryPreselection();
  }

  Future<void> _refreshHistoryPreselection() async {
    final targets = List<String>.from(_selectedMuscleGroups);
    if (targets.isEmpty) {
      if (mounted) setState(() => _selectedExerciseIds = {});
      return;
    }

    final catalog = await _safeExerciseCatalogFuture;
    final topIds = _programMode && widget.programCuratedExerciseIds != null
        ? widget.programCuratedExerciseIds!.take(3).toList()
        : await WorkoutStorageService().topExerciseIdsForTargets(
            targets,
            catalog,
            limit: 3,
          );
    if (!mounted || !_sameTargets(targets, _selectedMuscleGroups)) return;
    setState(() => _selectedExerciseIds = topIds.toSet());
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

    _pushActiveWorkout(
      muscleGroup: session.muscleGroup,
      targetMuscleGroups: session.targetMuscleGroups,
      durationMinutes: session.targetDurationMinutes,
      exercises: exercises,
      restSeconds: _restSeconds,
      resumeFromSession: session,
      isProgramWorkout: await ProgramService().isOngoingProgramSession(
        session.id,
      ),
      advanceProgramRestDayOnCompletion: await ProgramService()
          .isOngoingProgramRestSession(session.id),
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
        ),
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
    final ids =
        widget.programCuratedExerciseIds ??
        curatedExerciseIdsForMuscleGroups(_selectedMuscleGroups);
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
                children: [
                  const _StepHeader(label: '1. CHOOSE TARGET'),
                  const SizedBox(height: kSpace2),
                  if (_programMode)
                    _ProgramTargetSummary(
                      label: widget.programDayLabel ?? targetLabel,
                      summary:
                          widget.programFocusSummary ??
                          'Program workout selected.',
                    )
                  else ...[
                    Text(
                      _selectedMuscleGroups.isEmpty
                          ? 'Tap one target to begin. Add more only if needed.'
                          : targetLabel,
                      style: AppFonts.shareTechMono(
                        color: _selectedMuscleGroups.isEmpty
                            ? kMutedText
                            : kText,
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
                            selected: _selectedMuscleGroups.contains(
                              muscleGroup,
                            ),
                            onTap: () => _toggleMuscleGroup(muscleGroup),
                          ),
                      ],
                    ),
                  ],
                  if (_selectedMuscleGroups.isNotEmpty) ...[
                    const SizedBox(height: kSpace5),
                    const _StepHeader(label: '2. PICK EXERCISES'),
                    const SizedBox(height: kSpace2),
                    Text(
                      _selectedExerciseIds.isEmpty
                          ? 'Choose at least one exercise.'
                          : '${_selectedExerciseIds.length} selected',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: kSpace3),
                    _buildSearchAndFilters(),
                    const SizedBox(height: kSpace3),
                    _buildExerciseList(),
                  ],
                ],
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
        TextField(
          controller: _searchController,
          onChanged: (query) => setState(() => _searchQuery = query),
          style: AppFonts.shareTechMono(color: kText, fontSize: 14),
          decoration: InputDecoration(
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
            filled: true,
            fillColor: kBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: kNeon),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
                            exercise.imageAssetPath,
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
                    backgroundColor: kBorderDark,
                    foregroundColor: isFavorite ? kDanger : kMutedText,
                  ),
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_sharp
                        : Icons.favorite_border_sharp,
                    size: 18,
                  ),
                  label: Text(isFavorite ? 'FAVORITE' : 'MARK FAVORITE'),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: kBorderDark,
                foregroundColor: kText,
              ),
              child: const Text('CLOSE'),
            ),
            PixelButton(
              label: isSelected ? 'DESELECT' : 'SELECT',
              fullWidth: false,
              onPressed: () {
                Navigator.pop(context);
                _toggleSelectedExercise(exercise.id);
              },
            ),
          ],
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
        color: kAmber,
      ),
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
            color: kAmber,
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
