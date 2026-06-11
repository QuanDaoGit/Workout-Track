import 'dart:async';

import 'package:flutter/material.dart';

import '../models/program_models.dart';
import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/loot_drop_service.dart';
import '../services/program_customization_service.dart';
import '../services/program_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/motion/hold_depress.dart';
import 'Workout session/active_workout.dart';
import 'Workout session/start_workout.dart';
import 'Workout session/workout_summary.dart';
import 'guild_page.dart';
import 'home.dart';
import 'profile_page.dart';
import 'quests_page.dart';
import 'shop_page.dart';
import 'workout_page.dart';

/// Builds the onboarding first-session starter from the program's current day.
/// A program **workout** day → a pre-filled program-mode [StartWorkoutPage]
/// (Day 1, lifts auto-selected); no program or a rest day → the generic picker.
/// Pure and synchronous so the launch decision is unit-testable without the
/// shell. Shares the program starter builder with the Home program-day start, so
/// both routes pre-fill the same full Day 1 loadout.
StartWorkoutPage buildFirstSessionStarter(ProgramDay? day) {
  if (day == null || !day.isWorkout) return const StartWorkoutPage();
  return programDayStarter(day);
}

class RootPage extends StatefulWidget {
  const RootPage({super.key, this.openWorkoutStarterOnLaunch = false});

  /// When true (onboarding "START WORKOUT" finale), open the first session on
  /// top of the shell right after first paint. This keeps RootPage as the
  /// navigation root so every workout exit — which funnels through
  /// `popUntil((r) => r.isFirst)` — returns to Home, not the exercise picker.
  final bool openWorkoutStarterOnLaunch;

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _dockTimer;
  WorkoutSession? _ongoingSession;
  bool _loadingOngoing = false;
  bool _showingExpiredPausedSummary = false;
  bool _hasUnviewedLootDrops = false;
  StreamSubscription<void>? _storageSubscription;

  final _homeKey = GlobalKey<HomePageState>();
  final _workoutKey = GlobalKey<WorkoutPageState>();
  final _questsKey = GlobalKey<QuestsPageState>();
  final _guildKey = GlobalKey<GuildPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOngoingSession();
    _loadLootBadge();
    _dockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ongoingSession != null && mounted) setState(() {});
      _loadOngoingSession();
    });
    _storageSubscription = WorkoutStorageService.changes.listen((_) {
      if (!mounted) return;
      setState(() => _ongoingSession = null);
      _reloadQuestAwarePages();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showExpiredPausedSummaryIfNeeded();
    });
    if (widget.openWorkoutStarterOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFirstSession());
    }
  }

  /// Onboarding "START WORKOUT" finale. If the user chose a program, drop them
  /// into a **pre-filled Day 1** (program-mode [StartWorkoutPage] auto-selects
  /// the day's curated lifts) instead of a blank picker — the activation spine.
  /// Manual-path users (no program) or the defensive rest-day case fall back to
  /// the generic picker. Always pushed on top of RootPage so exit → Home.
  Future<void> _openFirstSession() async {
    if (!mounted) return;
    final progress = await ProgramService().getActiveProgress();
    final day = await ProgramService().getTodayDay();
    if (!mounted) return;
    // Apply the program's permanent exercise swaps before pre-filling Day 1.
    final effective = (progress != null && day != null && day.isWorkout)
        ? await ProgramCustomizationService().effectiveDay(
            progress.programId,
            day,
          )
        : day;
    if (!mounted) return;
    final starter = buildFirstSessionStarter(effective);
    await Navigator.push(
      context,
      arcadeRoute((_) => starter, motion: ArcadeRouteMotion.flow),
    );
    if (!mounted) return;
    _loadOngoingSession();
    _reloadQuestAwarePages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dockTimer?.cancel();
    _storageSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showExpiredPausedSummaryIfNeeded();
    }
  }

  void _selectTab(int index) {
    if (index == 0) _homeKey.currentState?.reload();
    if (index == 1) _workoutKey.currentState?.reload();
    if (index == 2) _questsKey.currentState?.reload();
    if (index == 3) _guildKey.currentState?.reload();
    if (index == 4) _profileKey.currentState?.reload();
    _loadOngoingSession();
    setState(() => _currentIndex = index);
    _loadLootBadge();
  }

  void _reloadQuestAwarePages() {
    _homeKey.currentState?.reload();
    _workoutKey.currentState?.reload();
    _questsKey.currentState?.reload();
    _guildKey.currentState?.reload();
    _profileKey.currentState?.reload();
    _loadOngoingSession();
    _loadLootBadge();
  }

  Future<void> _loadLootBadge() async {
    final hasUnviewed = await LootDropService().hasUnviewedDrops();
    if (!mounted) return;
    if (_hasUnviewedLootDrops != hasUnviewed) {
      setState(() => _hasUnviewedLootDrops = hasUnviewed);
    }
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

  Future<void> _showExpiredPausedSummaryIfNeeded() async {
    if (_showingExpiredPausedSummary) return;
    final session = await WorkoutStorageService().getExpiredPausedSession();
    if (session == null || !mounted) return;
    _showingExpiredPausedSummary = true;
    await _loadOngoingSession();
    if (!mounted) {
      _showingExpiredPausedSummary = false;
      return;
    }
    await Navigator.push(
      context,
      arcadeRoute(
        (_) => WorkoutSummaryPage(
          muscleGroup: session.muscleGroup,
          targetMuscleGroups: session.targetMuscleGroups,
          durationMinutes: session.targetDurationMinutes,
          elapsedSeconds: session.actualDurationSeconds,
          exerciseLogs: const [],
          isPartial: true,
          isAbandoned: true,
          startedAt: session.startedAt,
          sessionDate: session.date,
          abandonedMessage:
              'Saved workout automatically ended after midnight. Time-only XP awarded.',
          resumeFromSession: session,
        ),
        motion: ArcadeRouteMotion.reveal,
      ),
    );
    if (!mounted) return;
    _showingExpiredPausedSummary = false;
    _loadOngoingSession();
    _reloadQuestAwarePages();
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

    // Carry the program flags so finishing a resumed PROGRAM session still
    // advances the day (mirrors start_workout._continueOngoingSession). Without
    // this, the dock resume would drop isProgramWorkout and the program would
    // stall on the same day.
    final programService = ProgramService();
    final isProgram = await programService.isOngoingProgramSession(session.id);
    final advanceRest = await programService.isOngoingProgramRestSession(
      session.id,
    );
    final prescriptions = await programService.prescriptionsForOngoingSession(
      session.id,
    );
    if (!mounted) return;

    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: session.muscleGroup,
          targetMuscleGroups: session.targetMuscleGroups,
          durationMinutes: session.targetDurationMinutes,
          exercises: exercises,
          resumeFromSession: session,
          isProgramWorkout: isProgram,
          advanceProgramRestDayOnCompletion: advanceRest,
          prescriptions: prescriptions,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    ).then((_) {
      _loadOngoingSession();
      _reloadQuestAwarePages();
    });
  }

  int _liveElapsedSeconds(WorkoutSession session) {
    return session.elapsedSecondsForDisplay(DateTime.now());
  }

  void _openShop() {
    Navigator.of(context).push(
      arcadeRoute((_) => const ShopPage(), motion: ArcadeRouteMotion.fade),
    );
  }

  late final List<Widget> _pages = [
    HomePage(
      key: _homeKey,
      onViewQuests: () => _selectTab(2),
      onViewProfile: () => _selectTab(4),
      onViewWorkouts: () => _selectTab(1),
      onOpenShop: _openShop,
      onViewGuild: () => _selectTab(3),
    ),
    WorkoutPage(key: _workoutKey),
    QuestsPage(key: _questsKey, onQuestChanged: _reloadQuestAwarePages),
    GuildPage(key: _guildKey),
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
          if (ongoing != null && !ongoing.isPausedForResume)
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
        items: [
          const BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_map.png')),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/icons/control/icon_sword.png')),
            label: 'Workout',
          ),
          const BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage('assets/icons/control/ui/icon_nav_quests.png'),
            ),
            activeIcon: ImageIcon(
              AssetImage('assets/icons/control/ui/icon_nav_quests_active.png'),
            ),
            label: 'Quests',
          ),
          const BottomNavigationBarItem(
            icon: ImageIcon(
              AssetImage('assets/icons/control/ui/icon_nav_guild.png'),
            ),
            activeIcon: ImageIcon(
              AssetImage('assets/icons/control/ui/icon_nav_guild_active.png'),
            ),
            label: 'Guild',
          ),
          BottomNavigationBarItem(
            icon: _LootBadgeIcon(
              showBadge: _hasUnviewedLootDrops,
              child: const ImageIcon(
                AssetImage('assets/icons/control/icon_character.png'),
              ),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _LootBadgeIcon extends StatelessWidget {
  const _LootBadgeIcon({required this.child, required this.showBadge});

  final Widget child;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showBadge)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: kAmber,
                border: Border.all(color: kBg),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
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
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
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
                      session.isPausedForResume
                          ? '${session.targetMuscleLabel.toUpperCase()} SAVED'
                          : session.targetMuscleLabel.toUpperCase(),
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
