import 'dart:async';

import 'package:flutter/material.dart';

import '../models/program_models.dart';
import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/idle_session_guard.dart';
import '../services/loot_drop_service.dart';
import '../services/program_customization_service.dart';
import '../services/program_service.dart';
import '../services/workout_draft_controller.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/idle_session_dialog.dart';
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
  // Pre-start exercise-selection draft (in-shell). Survives tab nav, not kill.
  final WorkoutDraftController _draft = WorkoutDraftController();
  bool _viewingSelection = false;
  int _draftEpoch = 0;
  StreamSubscription<void>? _storageSubscription;

  final _homeKey = GlobalKey<HomePageState>();
  final _guildKey = GlobalKey<GuildPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft.addListener(_onDraftChanged);
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

  /// Onboarding "START WORKOUT" finale. If the user chose a program, open a
  /// **pre-filled Day 1** draft (the day's curated lifts pre-selected); manual or
  /// rest-day users get a blank draft. Routes through the same in-shell
  /// [openWorkoutDraft] entry as the center Train tap (Codex #3 — one entry API).
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
    openWorkoutDraft(
      (effective != null && effective.isWorkout)
          ? workoutDraftSeedForProgramDay(effective)
          : const WorkoutDraftSeed.manual(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dockTimer?.cancel();
    _storageSubscription?.cancel();
    _draft.removeListener(_onDraftChanged);
    _draft.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  /// Single entry point for opening exercise selection in-shell (manual Train
  /// tap, Home program day, onboarding finale). The draft surface replaces the
  /// body while the nav bar persists; the draft survives tab navigation.
  void openWorkoutDraft(WorkoutDraftSeed seed) {
    setState(() {
      _draftEpoch++;
      _viewingSelection = true;
    });
    _draft.begin(seed);
  }

  void _cancelDraft() {
    _draft.clear();
    setState(() => _viewingSelection = false);
  }

  /// Fired by the embedded selection right after it launches the live session.
  void _onDraftCommitted() {
    _draft.clear();
    setState(() => _viewingSelection = false);
    _loadOngoingSession();
  }

  TrainButtonMode _trainMode() {
    if (_ongoingSession != null) return TrainButtonMode.live;
    if (_draft.active) {
      return _draft.isValid
          ? TrainButtonMode.armedReady
          : TrainButtonMode.armedLocked;
    }
    return TrainButtonMode.idle;
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
    setState(() {
      _destination = destination;
      _viewingSelection = false; // leave the selection view; the draft persists
    });
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
    // A live/paused session takes precedence over a pre-start draft — drop the
    // draft so Train never shows armed on top of a real session (Codex #2).
    if (session != null && _draft.active) {
      _viewingSelection = false;
      _draft.clear();
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

  /// Center Train action. Re-reads session state at tap time (Codex #2):
  /// - any live/saved session → resume; a paused session past its auto-discard
  ///   deadline is force-summarized, never reopened (Codex post-impl #1);
  /// - a draft we are already viewing → commit (the embedded page's existing
  ///   confirm + launch; validity re-checked synchronously by the controller);
  /// - a draft on another tab → return to the selection surface;
  /// - otherwise → open **today's mission** (the active program day if any, else
  ///   a manual draft) in-shell. No front confirm — the single confirm is at the
  ///   commit. This is what makes the Home card's START button redundant.
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
      if (_draft.active) {
        if (_viewingSelection) {
          _draft.requestCommit();
        } else {
          setState(() => _viewingSelection = true);
        }
        return;
      }
      await _openFirstSession();
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
    final inSelection = _viewingSelection && _draft.active;
    return PopScope(
      // While viewing selection, back cancels the draft instead of leaving the
      // shell. The draft itself is kept alive offstage when on another tab.
      canPop: !inSelection,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inSelection) _cancelDraft();
      },
      child: Scaffold(
        body: IndexedStack(
          index: inSelection ? 1 : 0,
          children: [
            IndexedStack(index: _destination.index, children: _pages),
            // Kept mounted whenever a draft exists (even when a tab is shown) so
            // the in-progress selection survives tab navigation.
            _draft.active
                ? _SelectionSurface(
                    epoch: _draftEpoch,
                    draft: _draft,
                    onCancel: _cancelDraft,
                    onCommitted: _onDraftCommitted,
                  )
                : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _BottomNavBar(
          destination: _destination,
          trainMode: _trainMode(),
          elapsedLabel: ongoing == null ? null : _fmtElapsed(ongoing),
          showLootBadge: _hasUnviewedLootDrops,
          onSelect: goTo,
          onTrainTap: _onTrainTapped,
        ),
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

/// The in-shell exercise-selection surface: a slim header + the embedded
/// [StartWorkoutPage] (kept alive across tab nav by a stable epoch key) + the
/// ready hint. The shell's center Train button is the commit control.
class _SelectionSurface extends StatelessWidget {
  const _SelectionSurface({
    required this.epoch,
    required this.draft,
    required this.onCancel,
    required this.onCommitted,
  });

  final int epoch;
  final WorkoutDraftController draft;
  final VoidCallback onCancel;
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context) {
    final seed = draft.seed ?? const WorkoutDraftSeed.manual();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _SelectionHeader(onCancel: onCancel),
          Expanded(
            child: StartWorkoutPage(
              key: ValueKey('draft_$epoch'),
              embedded: true,
              draftController: draft,
              onCommitted: onCommitted,
              initialMuscleGroups: seed.initialMuscleGroups,
              initialSelectedExerciseIds: seed.initialSelectedExerciseIds,
              programDayLabel: seed.programDayLabel,
              programFocusSummary: seed.programFocusSummary,
              programCuratedExerciseIds: seed.programCuratedExerciseIds,
              programPrescriptions: seed.programPrescriptions,
              isProgramWorkout: seed.isProgramWorkout,
              advanceProgramRestDayOnCompletion:
                  seed.advanceProgramRestDayOnCompletion,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim header for the selection surface — title + a cancel ✕ that discards the
/// draft (the back gesture does the same via the shell PopScope).
class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(kSpace4, 12, kSpace2, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'SELECT WORKOUT',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: kText,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_sharp, color: kMutedText),
            tooltip: 'Discard',
          ),
        ],
      ),
    );
  }
}

/// The restructured bottom bar: four browseable corners flanking one elevated
/// center Train *action*. Tokens-only; reuses already-declared pixel icons.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.destination,
    required this.trainMode,
    required this.elapsedLabel,
    required this.showLootBadge,
    required this.onSelect,
    required this.onTrainTap,
  });

  final AppDestination destination;
  final TrainButtonMode trainMode;
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
                  mode: trainMode,
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
