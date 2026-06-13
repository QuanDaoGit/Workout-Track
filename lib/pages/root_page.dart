import 'dart:async';

import 'package:flutter/material.dart';

import '../models/program_models.dart';
import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/idle_session_guard.dart';
import '../services/loot_drop_service.dart';
import '../services/program_customization_service.dart';
import '../services/program_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/idle_session_dialog.dart';
import '../widgets/start_training_dialog.dart';
import '../widgets/train_nav_button.dart';
import 'Workout session/active_workout.dart';
import 'Workout session/start_workout.dart';
import 'Workout session/workout_summary.dart';
import 'guild_page.dart';
import 'home.dart';
import 'inventory_page.dart';
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

/// The four browseable destinations in the restructured shell. Train is NOT a
/// destination — it is the center *action* that launches (or resumes) a live
/// session. Persisted nowhere; the shell is the single source of truth.
enum AppDestination { home, inventory, guild, labs }

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
  AppDestination _destination = AppDestination.home;
  Timer? _dockTimer;
  WorkoutSession? _ongoingSession;
  bool _loadingOngoing = false;
  bool _showingExpiredPausedSummary = false;
  bool _showingIdleReveal = false;
  bool _hasUnviewedLootDrops = false;
  bool _trainTapInFlight = false;
  StreamSubscription<void>? _storageSubscription;

  final _homeKey = GlobalKey<HomePageState>();
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
      _showIdleRevealIfNeeded();
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
      _showIdleRevealIfNeeded();
    }
  }

  /// Switch the active destination. Semantic (not index-based) so callers never
  /// couple to a numeric slot — remapping the bar can't silently misroute.
  void goTo(AppDestination destination) {
    switch (destination) {
      case AppDestination.home:
        _homeKey.currentState?.reload();
      case AppDestination.inventory:
        break; // InventoryPage reloads itself on init.
      case AppDestination.guild:
        _guildKey.currentState?.reload();
      case AppDestination.labs:
        _profileKey.currentState?.reload();
    }
    _loadOngoingSession();
    setState(() => _destination = destination);
    _loadLootBadge();
  }

  void _reloadQuestAwarePages() {
    _homeKey.currentState?.reload();
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

  /// Cold-case idle auto-save: the app was killed/backgrounded mid-session and a
  /// live workout has gone past the idle window. The active page owns this while
  /// it is on top (the shell route is not current then); the shell only handles
  /// it once that page is gone. A timed-out session that logged nothing is
  /// dropped silently; one with sets offers save / resume / discard.
  Future<void> _showIdleRevealIfNeeded() async {
    if (_showingIdleReveal || IdleSessionGuard.instance.isHandling) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final session = await WorkoutStorageService().getIdleTimedOutSession();
    if (session == null || !mounted) return;

    final hasSets = session.exercises.any((log) => log.sets.isNotEmpty);
    if (!hasSets) {
      await WorkoutStorageService().deleteSession(session.id);
      if (!mounted) return;
      _loadOngoingSession();
      _reloadQuestAwarePages();
      return;
    }

    if (!IdleSessionGuard.instance.claim(session.id)) return;
    _showingIdleReveal = true;
    final last = session.lastActivityAt;
    final idleMinutes = last == null
        ? WorkoutStorageService.idleTimeout.inMinutes
        : DateTime.now()
              .difference(last)
              .inMinutes
              .clamp(WorkoutStorageService.idleTimeout.inMinutes, 1 << 30);
    final choice = await showIdleSessionDialog(
      context,
      hasSets: true,
      resumeLabel: 'RESUME WORKOUT',
      idleMinutes: idleMinutes,
    );
    IdleSessionGuard.instance.release(session.id);
    _showingIdleReveal = false;
    if (!mounted) return;
    switch (choice) {
      case IdleSessionChoice.save:
        await _saveIdleSession(session);
      case IdleSessionChoice.resume:
        await _resumeOngoingSession(session);
      case IdleSessionChoice.discard:
        await WorkoutStorageService().deleteSession(session.id);
        await ProgramService().clearOngoingProgramSession(session.id);
        if (!mounted) return;
        _loadOngoingSession();
        _reloadQuestAwarePages();
      case null:
        // Dismissed without choosing — leave it; the next open re-offers.
        break;
    }
  }

  /// Commits an idle-timed-out session as a completed workout through the normal
  /// summary path (single XP/mission award; `saveSession` clears its ongoing
  /// checkpoint row). Duration is the credited elapsed captured at the last set.
  Future<void> _saveIdleSession(WorkoutSession session) async {
    final programService = ProgramService();
    final isProgram = await programService.isOngoingProgramSession(session.id);
    final advanceRest = await programService.isOngoingProgramRestSession(
      session.id,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      arcadeRoute(
        (_) => WorkoutSummaryPage(
          muscleGroup: session.muscleGroup,
          targetMuscleGroups: session.targetMuscleGroups,
          durationMinutes: session.targetDurationMinutes,
          elapsedSeconds: session.actualDurationSeconds,
          exerciseLogs: session.exercises,
          selectedExerciseIds: session.selectedExerciseIds,
          sessionId: session.id,
          isPartial: false,
          startedAt: session.startedAt,
          sessionDate: session.date,
          resumeFromSession: session,
          isProgramWorkout: isProgram,
          advanceProgramRestDayOnCompletion: advanceRest,
          autoSavedAfterIdle: true,
        ),
        motion: ArcadeRouteMotion.reveal,
      ),
    );
    if (!mounted) return;
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

  void _openShop() {
    _pushFaded((_) => const ShopPage());
  }

  void _pushQuests() {
    _pushFaded((_) => QuestsPage(onQuestChanged: _reloadQuestAwarePages));
  }

  void _pushLogs() {
    _pushFaded((_) => const WorkoutLogsPage());
  }

  /// Push a top-level surface from the shell, then on return refresh the
  /// quest-aware destinations and re-arm the idle/expired reveals — pushed pages
  /// no longer get reload-on-tab-switch, and while one is open the shell route is
  /// not current so a reveal would otherwise be starved (Codex #4, #5).
  Future<void> _pushFaded(WidgetBuilder builder) async {
    await Navigator.of(
      context,
    ).push(arcadeRoute(builder, motion: ArcadeRouteMotion.fade));
    if (!mounted) return;
    _reloadQuestAwarePages();
    _showExpiredPausedSummaryIfNeeded();
    _showIdleRevealIfNeeded();
  }

  /// Center Train action. Re-reads the ongoing session at tap time so a tap that
  /// lands before the periodic refresh resolves can never misroute (Codex #2):
  /// - a paused session past its auto-discard deadline is force-summarized via
  ///   the shell's own handler, never reopened (Codex post-impl #1);
  /// - any other live/saved session resumes (mirrors Home's SAVED card and
  ///   `start_workout._continueOngoingSession`);
  /// - otherwise we confirm, then start fresh.
  Future<void> _onTrainTapped() async {
    if (_trainTapInFlight) return;
    _trainTapInFlight = true;
    try {
      final session = await WorkoutStorageService().getOngoingSession();
      if (!mounted) return;
      if (session != null) {
        final expired = await WorkoutStorageService().getExpiredPausedSession();
        if (!mounted) return;
        if (expired != null) {
          _showExpiredPausedSummaryIfNeeded();
        } else {
          _resumeOngoingSession(session);
        }
        return;
      }
      final start = await showStartTrainingDialog(context);
      if (start == true && mounted) await _openFirstSession();
    } finally {
      _trainTapInFlight = false;
    }
  }

  /// Indexed by [AppDestination] order: home, inventory, guild, labs.
  late final List<Widget> _pages = [
    HomePage(
      key: _homeKey,
      onViewQuests: _pushQuests,
      onViewProfile: () => goTo(AppDestination.labs),
      onViewWorkouts: _pushLogs,
      onOpenShop: _openShop,
      onViewGuild: () => goTo(AppDestination.guild),
    ),
    const InventoryPage(),
    GuildPage(key: _guildKey),
    ProfilePage(key: _profileKey, onProfileChanged: _reloadQuestAwarePages),
  ];

  @override
  Widget build(BuildContext context) {
    final ongoing = _ongoingSession;
    return Scaffold(
      body: IndexedStack(index: _destination.index, children: _pages),
      bottomNavigationBar: _BottomNavBar(
        destination: _destination,
        sessionLive: ongoing != null,
        elapsedLabel: ongoing == null ? null : _fmtElapsed(ongoing),
        showLootBadge: _hasUnviewedLootDrops,
        onSelect: goTo,
        onTrainTap: _onTrainTapped,
      ),
    );
  }

  String _fmtElapsed(WorkoutSession session) {
    final total = session.elapsedSecondsForDisplay(DateTime.now());
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

/// The restructured bottom bar: four browseable corners flanking one elevated
/// center Train *action*. Tokens-only; reuses already-declared pixel icons.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.destination,
    required this.sessionLive,
    required this.elapsedLabel,
    required this.showLootBadge,
    required this.onSelect,
    required this.onTrainTap,
  });

  final AppDestination destination;
  final bool sessionLive;
  final String? elapsedLabel;
  final bool showLootBadge;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onTrainTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                iconPath: 'assets/icons/control/icon_map.png',
                label: 'Home',
                active: destination == AppDestination.home,
                onTap: () => onSelect(AppDestination.home),
              ),
              _NavItem(
                iconPath: 'assets/icons/control/icon_bag.png',
                label: 'Items',
                active: destination == AppDestination.inventory,
                showBadge: showLootBadge,
                onTap: () => onSelect(AppDestination.inventory),
              ),
              Expanded(
                child: TrainNavButton(
                  live: sessionLive,
                  elapsedLabel: elapsedLabel,
                  onTap: onTrainTap,
                ),
              ),
              _NavItem(
                iconPath: 'assets/icons/control/ui/icon_nav_guild.png',
                label: 'Guild',
                active: destination == AppDestination.guild,
                onTap: () => onSelect(AppDestination.guild),
              ),
              _NavItem(
                iconPath: 'assets/icons/control/icon_character.png',
                label: 'Labs',
                active: destination == AppDestination.labs,
                onTap: () => onSelect(AppDestination.labs),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One corner destination: pixel icon + label, neon when active, with an
/// optional amber badge dot (the loot drop signal, relocated to Inventory).
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.iconPath,
    required this.label,
    required this.active,
    required this.onTap,
    this.showBadge = false,
  });

  final String iconPath;
  final String label;
  final bool active;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? kNeon : kMutedText;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LootBadgeIcon(
              showBadge: showBadge,
              child: ImageIcon(AssetImage(iconPath), size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 7,
                color: color,
              ),
            ),
          ],
        ),
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
