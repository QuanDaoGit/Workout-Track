import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../data/curated_exercises.dart';
import '../../models/workout_models.dart';
import '../../services/favorite_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/exercise_card.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/pixel_loader.dart';
import 'active_workout.dart';

class StartWorkoutPage extends StatefulWidget {
  const StartWorkoutPage({super.key});

  @override
  State<StartWorkoutPage> createState() => _StartWorkoutPageState();
}

class _StartWorkoutPageState extends State<StartWorkoutPage> {
  static const List<String> muscleGroups = ['Chest', 'Back', 'Arms', 'Legs'];

  String? selectedMuscleGroup;
  int selectedHour = 1;
  int selectedMinute = 30;
  FixedExtentScrollController? hourPickerController;
  FixedExtentScrollController? minutePickerController;
  Future<List<Exercise>>? exerciseCatalogFuture;

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

  FixedExtentScrollController get safeHourPickerController {
    return hourPickerController ??= FixedExtentScrollController(
      initialItem: selectedHour,
    );
  }

  FixedExtentScrollController get safeMinutePickerController {
    return minutePickerController ??= FixedExtentScrollController(
      initialItem: minuteOptions.indexOf(selectedMinute),
    );
  }

  Future<List<Exercise>> get safeExerciseCatalogFuture {
    return exerciseCatalogFuture ??= _loadExerciseCatalog();
  }

  @override
  void dispose() {
    hourPickerController?.dispose();
    minutePickerController?.dispose();
    super.dispose();
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

  void selectMuscleGroup(String muscleGroup) {
    setState(() {
      selectedMuscleGroup = muscleGroup;
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
    final muscleGroup = selectedMuscleGroup;
    final exerciseCount = recommendedExerciseCount;
    if (muscleGroup == null || exerciseCount == null) return;

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
            muscleGroup: muscleGroup,
            exerciseCatalogFuture: safeExerciseCatalogFuture,
            curatedExerciseIds:
                curatedExerciseIdsByMuscleGroup[muscleGroup] ?? const [],
            recommendedCount: exerciseCount,
          ),
        );
      },
    );

    if (selected == null || selected.isEmpty) return;

    if (!mounted) return;
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: muscleGroup,
          durationMinutes: workoutMinutes!,
          exercises: selected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exerciseCount = recommendedExerciseCount;
    final canPickExercises =
        selectedMuscleGroup != null && exerciseCount != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Start Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(label: '1. CHOOSE TARGET'),
            const SizedBox(height: 8),
            const Text(
              'Pick the muscle group for this run.',
              style: TextStyle(color: Color(0xFF6B6B8A)),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final muscleGroup in muscleGroups)
                  ArcadeChip(
                    label: muscleGroup,
                    selected: selectedMuscleGroup == muscleGroup,
                    onTap: () => selectMuscleGroup(muscleGroup),
                  ),
              ],
            ),

            if (selectedMuscleGroup != null) ...[
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
                    child: _TimePickerColumn(
                      controller: safeHourPickerController,
                      itemCount: 10,
                      labelBuilder: (index) {
                        final unit = index == 1 ? 'hour' : 'hours';
                        return '$index $unit';
                      },
                      onSelectedItemChanged: (index) {
                        updateSelectedHour(index % 10);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerColumn(
                      controller: safeMinutePickerController,
                      itemCount: minuteOptions.length,
                      labelBuilder: (index) => '${minuteOptions[index]} min',
                      onSelectedItemChanged: (index) {
                        final minuteIndex = index % minuteOptions.length;
                        updateSelectedMinute(minuteOptions[minuteIndex]);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _StepHeader(label: '3. PICK EXERCISES'),
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

Future<List<Exercise>> _loadExerciseCatalog() async {
  final jsonText = await rootBundle.loadString('assets/exercises.json');
  final rawExercises = jsonDecode(jsonText) as List<dynamic>;

  return [
    for (final rawExercise in rawExercises)
      Exercise.fromJson(rawExercise as Map<String, dynamic>),
  ];
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    required this.muscleGroup,
    required this.exerciseCatalogFuture,
    required this.curatedExerciseIds,
    required this.recommendedCount,
  });

  final String muscleGroup;
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

    return [
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
                        Image.asset(
                          exercise.imageAssetPath,
                          fit: BoxFit.cover,
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
                        Container(
                          color: const Color(0xFF0D0D1A).withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2A2A4A)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    exercise.levelLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B6B8A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Muscles: ${widget.muscleGroup}',
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

class _TimePickerColumn extends StatelessWidget {
  const _TimePickerColumn({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          border: Border.all(color: const Color(0xFF00FF9C), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CupertinoTheme(
          data: CupertinoThemeData(
            textTheme: CupertinoTextThemeData(
              pickerTextStyle: GoogleFonts.shareTechMono(
                color: kText,
                fontSize: 18,
              ),
            ),
          ),
          child: CupertinoPicker(
            backgroundColor: const Color(0xFF1A1A2E),
            scrollController: controller,
            itemExtent: 40,
            looping: true,
            magnification: 1.08,
            useMagnifier: true,
            selectionOverlay: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onSelectedItemChanged: onSelectedItemChanged,
            children: [
              for (var index = 0; index < itemCount; index++)
                Center(
                  child: Text(
                    labelBuilder(index),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFE8E8FF),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
