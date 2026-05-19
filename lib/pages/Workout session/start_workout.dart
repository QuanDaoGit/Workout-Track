import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../data/curated_exercises.dart';
import '../../data/muscle_groups.dart';
import '../../models/workout_models.dart';
import '../../services/calorie_service.dart';
import '../../services/class_service.dart';
import '../../services/exercise_catalog_service.dart';
import '../../services/favorite_service.dart';
import '../../services/program_service.dart';
import '../../services/rest_preference_service.dart';
import '../../services/workout_storage_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/arcade_dialog_button_column.dart';
import '../../widgets/arcade_image_filter.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/exercise_card.dart';
import '../../widgets/level_badge.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/pixel_loader.dart';
import 'active_workout.dart';

enum _OngoingAction { continueOld, endOldAndStartNew }

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
  static const List<String> muscleGroups = canonicalMuscleGroups;

  List<String> selectedMuscleGroups = const [];
  int selectedHour = 1;
  int selectedMinute = 30;
  int _restSeconds = 90;
  Future<List<Exercise>>? exerciseCatalogFuture;

  bool get _programMode => widget.isProgramWorkout;

  static const List<int> minuteOptions = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
  ];

  Future<List<Exercise>> get safeExerciseCatalogFuture {
    return exerciseCatalogFuture ??= _loadExerciseCatalog();
  }

  @override
  void initState() {
    super.initState();
    selectedMuscleGroups = normalizeTargetMuscleGroups(
      widget.initialMuscleGroups ??
          [if (widget.initialMuscleGroup != null) widget.initialMuscleGroup!],
    );
    _loadRestPreference();
  }

  Future<void> _loadRestPreference() async {
    final saved = await RestPreferenceService().get();
    if (saved != null) {
      if (!mounted) return;
      setState(() => _restSeconds = saved);
      return;
    }
    final cls = await ClassService().getCurrentClass();
    if (!mounted) return;
    setState(() => _restSeconds = RestPreferenceService.defaultForClass(cls));
  }

  String _fmtRest(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int? get workoutMinutes {
    final totalMinutes = selectedHour * 60 + selectedMinute;
    if (totalMinutes <= 0) return null;
    return totalMinutes;
  }

  int? get recommendedExerciseCount {
    final minutes = workoutMinutes;
    if (minutes == null) {
      return null;
    }

    return (minutes / 15).ceil();
  }

  void toggleMuscleGroup(String muscleGroup) {
    setState(() {
      final selected = selectedMuscleGroups.toSet();
      if (selected.contains(muscleGroup)) {
        selected.remove(muscleGroup);
      } else {
        selected.add(muscleGroup);
      }
      selectedMuscleGroups = normalizeTargetMuscleGroups(selected);
    });
  }

  void toggleAllTargets() {
    setState(() {
      selectedMuscleGroups =
          selectedMuscleGroups.length == canonicalMuscleGroups.length
          ? const []
          : canonicalMuscleGroups;
    });
  }

  void updateSelectedHour(int hour) {
    setState(() {
      selectedHour = hour;
    });
  }

  void updateSelectedMinute(int minute) {
    setState(() {
      selectedMinute = minute;
    });
  }

  void showExercisePicker() async {
    final targetGroups = selectedMuscleGroups;
    final exerciseCount = recommendedExerciseCount;
    if (targetGroups.isEmpty || exerciseCount == null) return;
    final primaryGroup = targetGroups.first;
    final targetLabel = targetMuscleGroupsLabel(
      targetGroups,
      fallback: primaryGroup,
    );

    final selected = await showModalBottomSheet<List<Exercise>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) {
        return SafeArea(
          child: _ExercisePickerSheet(
            muscleGroup: widget.programDayLabel ?? targetLabel,
            targetMuscleGroups: targetGroups,
            exerciseCatalogFuture: safeExerciseCatalogFuture,
            curatedExerciseIds:
                widget.programCuratedExerciseIds ??
                curatedExerciseIdsForMuscleGroups(targetGroups),
            recommendedCount: exerciseCount,
          ),
        );
      },
    );

    if (selected == null || selected.isEmpty) return;

    await RestPreferenceService().set(_restSeconds);

    if (!mounted) return;
    await _startSelectedWorkout(targetGroups, selected);
  }

  Future<void> _startSelectedWorkout(
    List<String> targetGroups,
    List<Exercise> selected,
  ) async {
    final ongoing = await WorkoutStorageService().getOngoingSession();
    if (!mounted) return;

    if (ongoing != null) {
      final action = await _showActiveSessionFoundDialog();
      if (!mounted || action == null) return;

      if (action == _OngoingAction.continueOld) {
        await _continueOngoingSession(ongoing);
        return;
      }

      await _abandonOngoingWithoutSummary(ongoing);
    }

    if (!mounted) return;
    final primaryGroup = targetGroups.first;
    _pushActiveWorkout(
      muscleGroup: primaryGroup,
      targetMuscleGroups: targetGroups,
      durationMinutes: workoutMinutes!,
      exercises: selected,
      restSeconds: _restSeconds,
      isProgramWorkout: widget.isProgramWorkout,
      advanceProgramRestDayOnCompletion:
          widget.advanceProgramRestDayOnCompletion,
    );
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

  Future<_OngoingAction?> _showActiveSessionFoundDialog() {
    return showDialog<_OngoingAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ACTIVE SESSION FOUND'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Finish your current run or end it before starting new.',
            ),
            const SizedBox(height: 16),
            ArcadeDialogButtonColumn(
              children: [
                FilledButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_OngoingAction.continueOld),
                  child: const Text('CONTINUE OLD'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_OngoingAction.endOldAndStartNew),
                  style: FilledButton.styleFrom(
                    backgroundColor: kDanger,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('END OLD & START NEW'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: kBorderDark,
                    foregroundColor: kText,
                  ),
                  child: const Text('CANCEL'),
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Future<void> _continueOngoingSession(WorkoutSession session) async {
    final catalog = await safeExerciseCatalogFuture;
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

  Future<void> _abandonOngoingWithoutSummary(WorkoutSession session) async {
    final elapsedSeconds = _liveElapsedSeconds(session);
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

  int _liveElapsedSeconds(WorkoutSession session) {
    return session.elapsedSecondsForDisplay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final exerciseCount = recommendedExerciseCount;
    final canPickExercises =
        selectedMuscleGroups.isNotEmpty && exerciseCount != null;
    final selectedTargetLabel = targetMuscleGroupsLabel(
      selectedMuscleGroups,
      fallback: 'RUN',
    );
    final allTargetsSelected =
        selectedMuscleGroups.length == canonicalMuscleGroups.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Start Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(label: '1. CHOOSE TARGET'),
            const SizedBox(height: 8),
            if (_programMode)
              _ProgramTargetSummary(
                label: widget.programDayLabel ?? selectedTargetLabel,
                summary:
                    widget.programFocusSummary ?? 'Program workout selected.',
              )
            else ...[
              const Text(
                'Pick one or more muscle groups for this run.',
                style: TextStyle(color: Color(0xFF6B6B8A)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ArcadeChip(
                    label: 'All',
                    selected: allTargetsSelected,
                    onTap: toggleAllTargets,
                  ),
                  for (final muscleGroup in muscleGroups)
                    ArcadeChip(
                      label: muscleGroup,
                      selected: selectedMuscleGroups.contains(muscleGroup),
                      onTap: () => toggleMuscleGroup(muscleGroup),
                    ),
                ],
              ),
            ],

            if (selectedMuscleGroups.isNotEmpty) ...[
              const SizedBox(height: 28),
              const _StepHeader(label: '2. SET DURATION'),
              const SizedBox(height: 8),
              Text(
                '${workoutMinutes ?? 0} min target',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE8E8FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeStepper(
                      valueLabel:
                          '$selectedHour ${selectedHour == 1 ? 'hour' : 'hours'}',
                      onDecrease: selectedHour <= 0
                          ? null
                          : () => updateSelectedHour(selectedHour - 1),
                      onIncrease: selectedHour >= 9
                          ? null
                          : () => updateSelectedHour(selectedHour + 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeStepper(
                      valueLabel: '$selectedMinute min',
                      onDecrease: selectedMinute <= minuteOptions.first
                          ? null
                          : () {
                              final index = minuteOptions.indexOf(
                                selectedMinute,
                              );
                              updateSelectedMinute(minuteOptions[index - 1]);
                            },
                      onIncrease: selectedMinute >= minuteOptions.last
                          ? null
                          : () {
                              final index = minuteOptions.indexOf(
                                selectedMinute,
                              );
                              updateSelectedMinute(minuteOptions[index + 1]);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _StepHeader(label: '3. REST BETWEEN SETS'),
              const SizedBox(height: 8),
              Text(
                _fmtRest(_restSeconds),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE8E8FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: kNeon,
                  inactiveTrackColor: kBorder,
                  thumbColor: kNeon,
                  overlayColor: kNeon.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 30,
                  max: 300,
                  divisions: 18,
                  value: _restSeconds.toDouble(),
                  onChanged: (v) => setState(() => _restSeconds = v.round()),
                ),
              ),
              const SizedBox(height: 28),
              const _StepHeader(label: '4. PICK EXERCISES'),
              const SizedBox(height: 8),
              Text(
                exerciseCount == null
                    ? 'Set a duration to unlock exercise picks.'
                    : 'Recommended: $exerciseCount exercises',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B6B8A),
                ),
              ),
              const SizedBox(height: 12),
              PixelButton(
                label: 'PICK EXERCISES',
                onPressed: canPickExercises ? showExercisePicker : null,
              ),
            ],
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
          const SizedBox(width: 12),
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
                const SizedBox(height: 6),
                Text(
                  summary,
                  style: GoogleFonts.shareTechMono(
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

Future<List<Exercise>> _loadExerciseCatalog() async {
  return ExerciseCatalogService().getFullCatalog();
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    required this.muscleGroup,
    required this.targetMuscleGroups,
    required this.exerciseCatalogFuture,
    required this.curatedExerciseIds,
    required this.recommendedCount,
  });

  final String muscleGroup;
  final List<String> targetMuscleGroups;
  final Future<List<Exercise>> exerciseCatalogFuture;
  final List<String> curatedExerciseIds;
  final int recommendedCount;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final FavoriteService favoriteService = const FavoriteService();
  final TextEditingController _searchController = TextEditingController();

  Set<String> favoriteExerciseIds = {};
  Set<String> selectedExerciseIds = {};
  String _searchQuery = '';
  String? _levelFilter;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    loadFavoriteExerciseIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.muscleGroup} exercises',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF9C).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF00FF9C)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${selectedExerciseIds.length}/${widget.recommendedCount}',
                    style: const TextStyle(
                      color: Color(0xFF00FF9C),
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Search bar ───────────────────────────────────────────────
            TextField(
              controller: _searchController,
              onChanged: (q) => setState(() => _searchQuery = q),
              style: const TextStyle(color: Color(0xFFE8E8FF)),
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: const TextStyle(color: Color(0xFF6B6B8A)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: ImageIcon(
                    AssetImage('assets/icons/control/icon_search.png'),
                    color: Color(0xFF6B6B8A),
                    size: 20,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF00FF9C)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),

            // ── Filter chips ─────────────────────────────────────────────
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
                  const SizedBox(width: 8),
                  ArcadeChip(
                    label: 'Beginner',
                    selected: _levelFilter == 'beginner',
                    onTap: () => setState(
                      () => _levelFilter = _levelFilter == 'beginner'
                          ? null
                          : 'beginner',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ArcadeChip(
                    label: 'Intermediate',
                    selected: _levelFilter == 'intermediate',
                    onTap: () => setState(
                      () => _levelFilter = _levelFilter == 'intermediate'
                          ? null
                          : 'intermediate',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ArcadeChip(
                    label: 'Expert',
                    selected: _levelFilter == 'expert',
                    onTap: () => setState(
                      () => _levelFilter = _levelFilter == 'expert'
                          ? null
                          : 'expert',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ArcadeChip(
                    label: '\u2665 Favorites',
                    selected: _showFavoritesOnly,
                    onTap: () => setState(
                      () => _showFavoritesOnly = !_showFavoritesOnly,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Exercise list ────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<Exercise>>(
                future: widget.exerciseCatalogFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: PixelLoader());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load exercises.'),
                    );
                  }

                  var filtered = _curatedExercises(
                    snapshot.data ?? const [],
                    widget.curatedExerciseIds,
                  );

                  if (_levelFilter != null) {
                    filtered = filtered
                        .where((e) => e.level == _levelFilter)
                        .toList();
                  }

                  if (_showFavoritesOnly) {
                    filtered = filtered
                        .where((e) => favoriteExerciseIds.contains(e.id))
                        .toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    filtered = filtered
                        .where((e) => e.name.toLowerCase().contains(q))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No exercises found.'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final exercise = filtered[index];
                      return ExerciseCard(
                        exercise: exercise,
                        showInfoIcon: true,
                        showFavorite: false,
                        showCheckbox: true,
                        isFavorite: favoriteExerciseIds.contains(exercise.id),
                        isSelected: selectedExerciseIds.contains(exercise.id),
                        isCustom: exercise.isCustom,
                        onTap: () => toggleSelectedExercise(exercise.id),
                        onInfoPressed: () => _showExercisePreview(exercise),
                        onCheckboxToggle: () =>
                            toggleSelectedExercise(exercise.id),
                      );
                    },
                  );
                },
              ),
            ),

            _SelectionBar(
              count: selectedExerciseIds.length,
              total: widget.recommendedCount,
              onContinue: selectedExerciseIds.isEmpty
                  ? null
                  : showSelectionConfirmation,
            ),
          ],
        ),
      ),
    );
  }

  List<Exercise> _curatedExercises(
    List<Exercise> exercises,
    List<String> curatedIds,
  ) {
    final exerciseById = {
      for (final exercise in exercises) exercise.id: exercise,
    };

    // Custom exercises matching this muscle group go first
    final customForGroup = exercises.where((e) {
      if (!e.isCustom) return false;
      final group = e.muscleGroup;
      if (group == null) return false;
      return hasTargetMuscle(widget.targetMuscleGroups, group);
    }).toList();

    return [
      ...customForGroup,
      for (final id in curatedIds)
        if (exerciseById[id] != null) exerciseById[id]!,
    ];
  }

  void toggleSelectedExercise(String id) {
    setState(() {
      if (selectedExerciseIds.contains(id)) {
        selectedExerciseIds = {...selectedExerciseIds}..remove(id);
      } else {
        selectedExerciseIds = {...selectedExerciseIds, id};
      }
    });
  }

  Future<void> showSelectionConfirmation() async {
    if (!mounted) return;

    final catalog = await widget.exerciseCatalogFuture;
    final curated = _curatedExercises(catalog, widget.curatedExerciseIds);
    final selected = curated
        .where((e) => selectedExerciseIds.contains(e.id))
        .toList();

    if (!mounted) return;
    Navigator.of(context).pop(selected);
  }

  Future<void> loadFavoriteExerciseIds() async {
    final favoriteIds = await favoriteService.getFavoriteExerciseIds();
    if (!mounted) {
      return;
    }

    setState(() {
      favoriteExerciseIds = favoriteIds;
    });
  }

  Future<bool> toggleFavoriteExercise(Exercise exercise) async {
    final isFavorite = await favoriteService.toggleFavoriteExercise(
      exercise.id,
    );
    if (!mounted) {
      return isFavorite;
    }

    setState(() {
      if (isFavorite) {
        favoriteExerciseIds = {...favoriteExerciseIds, exercise.id};
      } else {
        favoriteExerciseIds = {...favoriteExerciseIds}..remove(exercise.id);
      }
    });
    return isFavorite;
  }

  void _showExercisePreview(Exercise exercise) {
    final isSelected = selectedExerciseIds.contains(exercise.id);
    var isFavorite = favoriteExerciseIds.contains(exercise.id);
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
                                const ColoredBox(
                                  color: Color(0xFF0D0D1A),
                                  child: Center(
                                    child: ImageIcon(
                                      AssetImage(
                                        'assets/icons/control/icon_sword.png',
                                      ),
                                      color: Color(0xFF2A2A4A),
                                      size: 40,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        Container(
                          color: const Color(0xFF0D0D1A).withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LevelBadge(exercise: exercise),
                const SizedBox(height: 8),
                Text(
                  'Muscles: ${targetMuscleGroupsLabel(widget.targetMuscleGroups, fallback: widget.muscleGroup)}',
                  style: const TextStyle(
                    color: Color(0xFF6B6B8A),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final next = await toggleFavoriteExercise(exercise);
                    if (context.mounted) {
                      setDialogState(() => isFavorite = next);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A3E),
                    foregroundColor: isFavorite
                        ? const Color(0xFFFF2D55)
                        : const Color(0xFF6B6B8A),
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
                backgroundColor: const Color(0xFF2A2A3E),
                foregroundColor: const Color(0xFFE8E8FF),
              ),
              child: const Text('CLOSE'),
            ),
            PixelButton(
              label: isSelected ? 'DESELECT' : 'SELECT',
              fullWidth: false,
              onPressed: () {
                Navigator.pop(context);
                toggleSelectedExercise(exercise.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.total,
    required this.onContinue,
  });

  final int count;
  final int total;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Color(0xFF2A2A4A))),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count / $total SELECTED',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: Color(0xFFE8E8FF),
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
    );
  }
}

class _TimeStepper extends StatelessWidget {
  const _TimeStepper({
    required this.valueLabel,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String valueLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _StepperArrow(
            icon: Icons.chevron_left_sharp,
            onPressed: onDecrease,
            tooltip: 'Decrease',
          ),
          Expanded(
            child: Text(
              valueLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.shareTechMono(
                color: kText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepperArrow(
            icon: Icons.chevron_right_sharp,
            onPressed: onIncrease,
            tooltip: 'Increase',
          ),
        ],
      ),
    );
  }
}

class _StepperArrow extends StatelessWidget {
  const _StepperArrow({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: onPressed == null ? kBorderDark : kNeon,
          foregroundColor: onPressed == null ? kDim : kBg,
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}
