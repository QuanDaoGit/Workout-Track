import 'dart:async';

import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import 'Workout session/active_workout.dart';
import 'home.dart';
import 'profile_page.dart';
import 'quests_page.dart';
import 'workout_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;
  Timer? _dockTimer;
  WorkoutSession? _ongoingSession;
  bool _loadingOngoing = false;

  final _homeKey = GlobalKey<HomePageState>();
  final _workoutKey = GlobalKey<WorkoutPageState>();
  final _questsKey = GlobalKey<QuestsPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  void initState() {
    super.initState();
    _loadOngoingSession();
    _dockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ongoingSession != null && mounted) setState(() {});
      _loadOngoingSession();
    });
  }

  @override
  void dispose() {
    _dockTimer?.cancel();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == 0) _homeKey.currentState?.reload();
    if (index == 1) _workoutKey.currentState?.reload();
    if (index == 2) _questsKey.currentState?.reload();
    if (index == 3) _profileKey.currentState?.reload();
    _loadOngoingSession();
    setState(() => _currentIndex = index);
  }

  void _reloadQuestAwarePages() {
    _homeKey.currentState?.reload();
    _workoutKey.currentState?.reload();
    _questsKey.currentState?.reload();
    _profileKey.currentState?.reload();
    _loadOngoingSession();
  }

  Future<void> _loadOngoingSession() async {
    if (_loadingOngoing) return;
    _loadingOngoing = true;
    final session = await WorkoutStorageService().getOngoingSession();
    _loadingOngoing = false;
    if (!mounted) return;
    if (_ongoingSession?.id != session?.id ||
        _ongoingSession?.actualDurationSeconds !=
            session?.actualDurationSeconds ||
        _ongoingSession?.exercises.length != session?.exercises.length) {
      setState(() => _ongoingSession = session);
    } else {
      _ongoingSession = session;
    }
  }

  Future<void> _resumeOngoingSession(WorkoutSession session) async {
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final byId = {for (final e in catalog) e.id: e};
    final exerciseIds = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds
        : session.exercises.map((log) => log.exerciseId).toList();
    final exercises = exerciseIds
        .map((id) => byId[id])
        .whereType<Exercise>()
        .toList();
    if (exercises.isEmpty || !mounted) return;

    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: session.muscleGroup,
          durationMinutes: session.targetDurationMinutes,
          exercises: exercises,
          resumeFromSession: session,
        ),
      ),
    ).then((_) {
      _loadOngoingSession();
      _reloadQuestAwarePages();
    });
  }

  int _liveElapsedSeconds(WorkoutSession session) {
    final live = DateTime.now().difference(session.startedAt).inSeconds;
    return live > session.actualDurationSeconds
        ? live
        : session.actualDurationSeconds;
  }

  late final List<Widget> _pages = [
    HomePage(
      key: _homeKey,
      onViewQuests: () => _selectTab(2),
      onViewProfile: () => _selectTab(3),
    ),
    WorkoutPage(key: _workoutKey),
    QuestsPage(key: _questsKey, onQuestChanged: _reloadQuestAwarePages),
    ProfilePage(key: _profileKey, onProfileChanged: _reloadQuestAwarePages),
  ];

  @override
  Widget build(BuildContext context) {
    final ongoing = _ongoingSession;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
          if (ongoing != null)
            _ActiveWorkoutDock(
              session: ongoing,
              elapsedSeconds: _liveElapsedSeconds(ongoing),
              onTap: () => _resumeOngoingSession(ongoing),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _selectTab,
        items: const [
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_map.png')),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_sword.png')),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_scroll.png')),
            label: 'Quests',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage('assets/icons/control/icon_character.png'),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutDock extends StatelessWidget {
  const _ActiveWorkoutDock({
    required this.session,
    required this.elapsedSeconds,
    required this.onTap,
  });

  final WorkoutSession session;
  final int elapsedSeconds;
  final VoidCallback onTap;

  int get _completedExercises =>
      session.exercises.where((log) => log.sets.isNotEmpty).length;

  int get _totalExercises {
    final total = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds.length
        : session.exercises.length;
    return total <= 0 ? 1 : total;
  }

  double get _progress => _totalExercises <= 0
      ? 0.0
      : (_completedExercises / _totalExercises).clamp(0.0, 1.0).toDouble();

  String _fmt(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBg,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            color: kCard,
            border: Border(top: BorderSide(color: kBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const ImageIcon(
                    AssetImage('assets/icons/control/icon_time.png'),
                    size: 20,
                    color: kNeon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      session.muscleGroup.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: kText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _fmt(elapsedSeconds),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: kNeon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ArcadeProgressBar(value: _progress, height: 6),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$_completedExercises/$_totalExercises CLEARED',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: kMutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
