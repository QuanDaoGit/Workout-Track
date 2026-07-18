import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/adventure_routes.dart';
import '../data/bit_room_copy.dart';
import '../data/muscle_groups.dart';
import '../data/programs_library.dart';
import '../models/adventure_models.dart';
import '../models/character_class.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../models/profile_models.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../services/adventure_service.dart';
import '../services/bit_advice_service.dart';
import '../services/calorie_service.dart';
import '../services/feature_gate_service.dart';
import '../services/haptic_service.dart';
import '../services/class_service.dart';
import '../services/exercise_catalog_service.dart';
import '../services/gem_service.dart';
import '../utils/iso_week.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/program_customization_service.dart';
import '../services/program_service.dart';
import '../services/quest_service.dart';
import '../services/recovery_insight_service.dart';
import '../services/rest_service.dart';
import '../services/stat_engine.dart';
import '../services/workout_defaults_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/adventure/adventure_card.dart';
import '../widgets/arcade_dialog_button_column.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/arcade_card.dart';
import '../widgets/arcade_route.dart';
import '../widgets/arcade_tap.dart';
import '../widgets/active_session_found_dialog.dart';
import '../widgets/arcade_notice.dart';
import '../widgets/feature_gate_notice.dart';
import '../widgets/home_section_header.dart';
import '../widgets/last_session_tag.dart';
import '../widgets/motion/crt_breathe.dart';
import '../widgets/motion/crt_flicker.dart';
import '../widgets/motion/crt_sweep.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/program_path_hud.dart';
import '../widgets/pulse_color_text.dart';
import '../widgets/radar_stat_icon.dart';
import '../widgets/recovery_insight_sheet.dart';
import '../widgets/room/expedition_dispatch_sheet.dart';
import '../widgets/room/room_scene.dart';
import '../widgets/screen_shake.dart';
import '../widgets/strobe_flash.dart';
import '../widgets/rest_icon.dart';
import 'adventure_page.dart';
import 'expedition_report_page.dart';
import 'Workout session/active_workout.dart';
import 'Workout session/start_workout.dart';

class CompletedMissionCopy {
  const CompletedMissionCopy({required this.title, required this.detail});

  final String title;
  final String detail;
}

/// The "TODAY'S MISSION" header's state register — drives its color + motion.
/// Defaults to [calm]; only an explicit pending or rest state opts into the
/// louder registers, so an unknown state never reads as active or recovery.
enum MissionHeaderMode { active, recovery, calm }

CompletedMissionCopy completedMissionCopy(WorkoutSession? session) {
  if (session == null) {
    return const CompletedMissionCopy(
      title: 'TODAY\'S MISSION',
      detail: 'Cleared',
    );
  }

  final totalExercises = session.selectedExerciseIds.isNotEmpty
      ? session.selectedExerciseIds.length
      : session.exercises.length;
  final exerciseLabel = totalExercises == 1
      ? '1 exercise'
      : '$totalExercises exercises';
  final minutes = session.actualDurationSeconds ~/ 60;

  return CompletedMissionCopy(
    title: session.targetMuscleLabel.toUpperCase(),
    detail: 'Today | $minutes min | $exerciseLabel',
  );
}

/// Whether a brand-new user's headline mission should be the program's **Day-1
/// card** (a program was chosen in onboarding) rather than the manual FIRST QUEST
/// free-pick card. Pure so the routing is unit-testable without pumping Home.
///
/// [firstSessionDay] is the program's weekday-agnostic active workout
/// (`ProgramService.activeWorkoutDay`) — always Day 1 for a fresh program — so a
/// seeded rest-day landing can no longer drop the user to a blank picker, and the
/// first workout reads as the program beginning rather than a separate quest.
bool newUserMissionShowsProgramDayOne(
  ProgramProgress? progress,
  ProgramDay? firstSessionDay,
) =>
    progress != null && firstSessionDay != null && firstSessionDay.isWorkout;

/// Whether tapping a start-workout entry on a planned-recovery day should pause
/// for the "TRAIN ANYWAY?" confirm. A brand-new user ([isNewUser] — no completed
/// workouts) is **exempt**: their first-ever session must never be gated as
/// recovery (there is no rest streak/build to protect yet), matching the
/// weekday-agnostic first-session routing in `RootPage._openFirstSession`. The
/// logged workout naturally takes no rest credit for the day
/// (`RestService.dayInfoForState` zeroes `recoveryXP` once `hasCompletedWorkout`),
/// so the bypass can't double-dip. Established users keep the gate. Pure so the
/// rule is unit-testable without pumping Home.
bool showsRestDayTrainPrompt({
  required bool trainAnyway,
  required bool isNewUser,
  required RestDayInfo? restInfo,
}) =>
    !trainAnyway &&
    !isNewUser &&
    restInfo != null &&
    restInfo.isPlannedRestDay &&
    !restInfo.hasCompletedWorkout;

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onViewQuests,
    this.onViewProfile,
    this.onViewWorkouts,
    this.onOpenShop,
  });

  final VoidCallback? onViewQuests;
  final VoidCallback? onViewProfile;

  /// Streak/LCK metric → workout history (Workout tab).
  final VoidCallback? onViewWorkouts;

  /// Gem metric → the gem store.
  final VoidCallback? onOpenShop;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _loading = true;
  List<WorkoutSession> _ongoingSessions = [];
  int _totalXP = 0;
  int _level = 1;
  String _rank = 'Recruit';
  int _todayXP = 0;
  int _weeklyQuestCompleted = 0;
  int _weeklyQuestTotal = 5;
  int _questClaimable = 0;
  WorkoutSession? _lastWorkout;
  WorkoutSession? _completedWorkoutToday;
  bool _isNewUser = false;
  String? _suggestedMuscle;
  int? _suggestedMissionRewardGems;
  RestDayInfo? _todayRestInfo;
  ProfileData _profile = ProfileData.defaults();
  MissionFinishState _missionFinishStateToday = MissionFinishState.none;
  WorkoutSession? _endedEarlyToday;
  int? _preWorkoutXP;
  int? _preWorkoutLevel;
  bool _showXPGain = false;
  int _xpGainAmount = 0;
  // The "changed Home" closing beat — last session's visible stat gains.
  bool _showLastSessionDelta = false;
  Map<String, int> _lastSessionDelta = const {};
  Map<String, int> _lastSessionStats = const {};
  double _lckMultiplier = 1.0;
  int _lck = 0;
  int _gemBalance = 0;
  int _vitality = 10;
  bool _showLevelUp = false;
  int _levelUpShakeTrigger = 0;
  int _missionFlashTrigger = 0;
  Map<LootCategory, LootItem> _equippedLoot = {};
  ProgramProgress? _programProgress;
  ProgramDay? _programDay;
  // The program's weekday-agnostic Day-1 (active workout) — drives the new-user
  // headline mission so the first workout is the program's, never a blank picker.
  ProgramDay? _firstSessionDay;
  ProgramDaySnapshot? _programCompletedToday;
  // Training weekdays in effect this week — drives the program "NEXT ▸" teaser's
  // days-away under the weekday-anchored schedule.
  Set<int> _trainingWeekdays = const {1, 3, 5};
  AdventureState? _adventureState;
  CharacterClass? _characterClass;
  Map<String, int> _combatStats = const {};
  // BIT's home-room voice: a rotating advice cursor (advanced on Home re-entry,
  // no immediate repeat) + the expedition whose "I'm back" greeting was shown
  // (persisted, so it fires once when the hologram first appears). _lastVoice*
  // record the line the last build showed, so a re-entry can consume a shown
  // greeting (flip to the away status) without recomputing phase.
  final Random _adviceRng = Random();
  // Two rotating cursors — one per advice pool — plus the line resolved for the
  // current build. The wildcard pool draws ~5% of rotations and is capped to one
  // hit per day (_wildcardUsedToday, seeded from BitAdviceService on load).
  int _regularAdviceIndex = 0;
  int _wildcardAdviceIndex = 0;
  String _adviceLine = '';
  bool _wildcardUsedToday = false;
  String? _greetedExpeditionId;
  BitRoomVoiceKind? _lastVoiceKind;
  String? _lastVoicePendingId;
  // Single-flight guard for the on-open expedition reveal (Home can load
  // twice in quick succession: initState + the storage-change listener).
  bool _expeditionRevealInFlight = false;
  // Single-flight guard for the silent settle-on-open/resume/timer routine.
  bool _expeditionSettleInFlight = false;
  // Monotonic one-shot homecoming token: bumped only when a pending settles
  // *this* refresh, so the room animates the arrival once (backlog = static).
  int _homecomingTick = 0;
  // Fires the homecoming the moment a pending returns while Home stays open.
  Timer? _expeditionReturnTimer;
  StreamSubscription<void>? _storageSubscription;

  // Drives the room's subtle background parallax: the scroll offset feeds a
  // ValueListenable the room reads (a tiny scoped rebuild, no setState on scroll).
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _roomScroll = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    // Cold open shows a regular line (never a wildcard — those only surface via
    // a rotation draw), picked at random so it isn't always the same greeting.
    if (bitRoomRegularAdvice.isNotEmpty) {
      _regularAdviceIndex = _adviceRng.nextInt(bitRoomRegularAdvice.length);
      _adviceLine = bitRoomRegularAdvice[_regularAdviceIndex];
    }
    WidgetsBinding.instance.addObserver(this);
    // The earned-unlock gates flip mid-session (a ceremony on the shell) —
    // rebuild so the quest card / wall board / expedition section power on the
    // moment their gate opens, not on the next data reload.
    FeatureGateService.revision.addListener(_onGateRevision);
    _scrollController.addListener(
      () => _roomScroll.value = _scrollController.offset,
    );
    _storageSubscription = WorkoutStorageService.changes.listen((_) {
      if (!mounted) return;
      setState(() => _ongoingSessions = []);
      _loadData();
    });
    _loadData();
  }

  Future<void> reload() => _loadData();

  /// Home became the active surface again (app foregrounded or the Home tab
  /// re-selected) — rotate BIT's advice line + consume a shown greeting, then
  /// settle/refresh. Distinct from [reload]: quest-claim refreshes reload data
  /// but must NOT churn BIT's line.
  void onReenter() {
    if (!mounted) return;
    // The greeting was on screen → consume it so this return shows the away
    // status, not "I'm back" again. Commit locally + rotate in one setState,
    // then persist the flag BEFORE reload re-reads it (else the re-read resets
    // it and the greeting re-shows — a fire-and-forget write race).
    final consumeGreetingId = (_lastVoiceKind == BitRoomVoiceKind.greeting &&
            _lastVoicePendingId != null &&
            _greetedExpeditionId != _lastVoicePendingId)
        ? _lastVoicePendingId
        : null;
    setState(() {
      if (consumeGreetingId != null) _greetedExpeditionId = consumeGreetingId;
      _rotateAdvice();
    });
    _persistGreetingThenReload(consumeGreetingId);
  }

  Future<void> _persistGreetingThenReload(String? greetedId) async {
    if (greetedId != null) {
      await AdventureService().setGreetedExpeditionId(greetedId);
    }
    if (mounted) await reload(); // re-reads the flag + settles a returned haul
  }

  /// Resolve a fresh advice line for a real Home re-entry. Advances each pool's
  /// cursor (no immediate repeat within a pool), then draws regular-vs-wildcard
  /// via [pickRoomAdvice] — wildcard ~5% and only if today's slot is unspent. A
  /// wildcard hit spends the slot (local flag + a fire-and-forget persist so the
  /// cap survives a restart). Caller wraps this in setState.
  void _rotateAdvice() {
    _regularAdviceIndex =
        _nextAdviceIndex(_regularAdviceIndex, bitRoomRegularAdvice.length);
    _wildcardAdviceIndex =
        _nextAdviceIndex(_wildcardAdviceIndex, bitRoomWildcardAdvice.length);
    final pick = pickRoomAdvice(
      roll: _adviceRng.nextDouble(),
      wildcardAllowedToday: !_wildcardUsedToday,
      regularIndex: _regularAdviceIndex,
      wildcardIndex: _wildcardAdviceIndex,
    );
    _adviceLine = pick.line;
    if (pick.isWildcard) {
      _wildcardUsedToday = true;
      BitAdviceService().markWildcardShown();
    }
  }

  /// Next cursor for a pool of [n] lines: a random index that isn't the current
  /// one (so no line repeats back-to-back). 0 for an empty/singleton pool.
  int _nextAdviceIndex(int current, int n) {
    if (n <= 1) return 0;
    var next = _adviceRng.nextInt(n);
    if (next == current) next = (next + 1) % n;
    return next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // An expedition can return while Home is backgrounded — settle + play the
    // homecoming on the way back in (the deterministic foreground path; the
    // in-foreground due-time is covered by _expeditionReturnTimer). A resume is
    // a Home re-entry → rotate BIT's advice too.
    if (state == AppLifecycleState.resumed) onReenter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FeatureGateService.revision.removeListener(_onGateRevision);
    _expeditionReturnTimer?.cancel();
    _scrollController.dispose();
    _roomScroll.dispose();
    _storageSubscription?.cancel();
    super.dispose();
  }

  void _onGateRevision() {
    if (mounted) setState(() {});
  }

  bool get _questsUnlocked =>
      FeatureGateService.isUnlockedSync(FeatureGate.quests);
  bool get _adventureUnlocked =>
      FeatureGateService.isUnlockedSync(FeatureGate.adventure);

  Future<void> _loadData() async {
    final all = await WorkoutStorageService().getSessions();
    final restService = RestService();
    final programService = ProgramService();
    final programProgress = await programService.getActiveProgress();
    final programDay = await programService.getTodayDay();
    // Weekday-agnostic Day-1 for the new-user headline mission (the program's
    // first workout regardless of which weekday onboarding finished on).
    final firstSessionDay = await programService.activeWorkoutDay();
    final today = DateUtils.dateOnly(DateTime.now());
    // Under the weekday-anchored schedule the program no longer stamps today as
    // training/rest: a training weekday is a training day natively, and a
    // non-training weekday is planned rest — both via RestService.trainingWeekdays.
    // Off-anchor (forgiveness) training is credited by the completed session
    // itself, never an extra obligation.
    var restState = await restService.refreshWeeklyShieldProgress(all);
    final questClaimedXP = await QuestService().claimedRewardXP();
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    final currentRecoveryXP = restService.effectiveRecoveryXPForState(
      sessions: all,
      state: restState,
    );
    restState = await restService.ensureAutomaticRecoveryForToday(
      sessions: all,
      baseXP:
          XpService.calculateTotalXP(all) +
          questClaimedXP +
          currentRecoveryXP +
          potionBonusXP,
      state: restState,
    );
    final recoveryXP = restService.effectiveRecoveryXPForState(
      sessions: all,
      state: restState,
    );
    final questSummary = await QuestService().getSummary(all);
    final profile = await ProfileService().loadProfile();
    final equippedLoot = await LootService().getEquippedLoot();
    final gemBalance = await GemService().balance();
    final storedStats = await StatEngine().getStoredStats();
    final vitality = storedStats['VIT'] ?? 10;
    final programCompletedToday = await programService
        .completedSnapshotForToday(now: today);
    final missionFinishState =
        await WorkoutStorageService.missionFinishStateToday();
    final adventureState = await _loadAdventureStateSafely();
    final greetedExpeditionId = await AdventureService().loadGreetedExpeditionId();
    final wildcardUsedToday = await BitAdviceService().wasWildcardShownToday();
    final characterClass = await ClassService().getCurrentClass();
    if (!mounted) return;

    final completed = all.where((s) => !s.isPartial).toList();
    // LCK is the weekly consistency streak, refreshed inside getStoredStats.
    final lck = storedStats['LCK'] ?? 0;
    final lckMultiplier = XpService.lckXpMultiplier(lck);
    final partial = all.where((s) => s.isOngoing).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final endedEarlyToday =
        all
            .where((s) => s.isAbandoned && DateUtils.dateOnly(s.date) == today)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final completedToday =
        all
            .where(
              (s) =>
                  !s.isPartial &&
                  !s.isAbandoned &&
                  DateUtils.dateOnly(s.date) == today,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final lastCompleted = completed.isEmpty
        ? null
        : completed.reduce((a, b) => a.date.isAfter(b.date) ? a : b);

    final totalXP =
        XpService.calculateTotalXP(all) +
        questSummary.claimedRewardXP +
        recoveryXP +
        potionBonusXP;
    final level = XpService.getLevel(totalXP);
    final rank = XpService.getRank(level);

    final todayRestInfo = restService.dayInfoForState(
      day: today,
      sessions: all,
      state: restState,
      now: today,
    );
    final todayXP =
        all
            .where((s) => !s.isOngoing && DateUtils.dateOnly(s.date) == today)
            .fold(0, (sum, s) => sum + XpService.calculateSessionXP(s)) +
        questSummary.todayClaimedXP +
        todayRestInfo.recoveryXP;

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));
    const muscles = canonicalMuscleGroups;
    String? suggestedMuscle;

    if (completed.isNotEmpty) {
      final vols = {for (final m in muscles) m: 0.0};
      final lastDate = <String, DateTime>{};
      for (final s in completed) {
        final targets = s.targetMuscleGroups;
        if (s.date.isAfter(cutoff)) {
          final volume = s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
          final share = targets.isEmpty ? 0.0 : volume / targets.length;
          for (final target in targets) {
            vols[target] = (vols[target] ?? 0) + share;
          }
        }
        for (final target in targets) {
          if (!lastDate.containsKey(target) ||
              s.date.isAfter(lastDate[target]!)) {
            lastDate[target] = s.date;
          }
        }
      }
      suggestedMuscle = muscles.reduce((a, b) {
        final va = vols[a]!;
        final vb = vols[b]!;
        if (va != vb) return va < vb ? a : b;
        final da = lastDate[a];
        final db = lastDate[b];
        if (da == null && db == null) return a.compareTo(b) <= 0 ? a : b;
        if (da == null) return a;
        if (db == null) return b;
        return da.isBefore(db) ? a : b;
      });
    }

    int? suggestedMissionRewardGems;
    for (final quest in questSummary.dailyQuests) {
      if (quest.id == 'show_up' && !quest.claimed) {
        suggestedMissionRewardGems = quest.rewardGems;
        break;
      }
    }

    setState(() {
      _ongoingSessions = partial;
      _totalXP = totalXP;
      _level = level;
      _rank = rank;
      _todayXP = todayXP;
      _weeklyQuestCompleted = questSummary.weeklyCompleted;
      _weeklyQuestTotal = questSummary.weeklyTotal;
      _questClaimable = questSummary.claimableCount;
      _lastWorkout = lastCompleted;
      // Home only renders post-onboarding, so no completed sessions == new user.
      _isNewUser = completed.isEmpty;
      _completedWorkoutToday = completedToday.isEmpty
          ? null
          : completedToday.first;
      _suggestedMuscle = suggestedMuscle;
      _suggestedMissionRewardGems = suggestedMissionRewardGems;
      _todayRestInfo = todayRestInfo;
      _profile = profile;
      _missionFinishStateToday = missionFinishState;
      _endedEarlyToday = endedEarlyToday.isEmpty ? null : endedEarlyToday.first;
      _equippedLoot = equippedLoot;
      _programProgress = programProgress;
      _programDay = programDay;
      _firstSessionDay = firstSessionDay;
      _programCompletedToday = programCompletedToday;
      _trainingWeekdays = restService.trainingWeekdaysForDate(today, restState);
      _adventureState = adventureState;
      _greetedExpeditionId = greetedExpeditionId;
      // OR in the persisted flag — never un-set a wildcard already shown this
      // session (a fire-and-forget markWildcardShown may not have landed before
      // this re-read), so the daily cap can't be re-opened by a race.
      _wildcardUsedToday = _wildcardUsedToday || wildcardUsedToday;
      _characterClass = characterClass;
      _combatStats = storedStats;
      _lckMultiplier = lckMultiplier;
      _lck = lck;
      _gemBalance = gemBalance;
      _vitality = vitality;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleAndRefreshExpedition();
    });
  }

  /// On-open ceremony precedence (one per load, never stacked): the
  /// idle-session dialog and any other modal win — this only fires when
  /// Home is the current route and no ongoing session needs attention.
  /// Settlement is only consumed once the reveal can actually show.
  Future<AdventureState?> _loadAdventureStateSafely() async {
    try {
      return await AdventureService().loadState();
    } catch (_) {
      return null;
    }
  }

  bool _pendingRevealable(Expedition p, DateTime now) {
    final r = p.returnsAtIso == null ? null : DateTime.tryParse(p.returnsAtIso!);
    return r == null || !now.isBefore(r);
  }

  /// Settle a returned expedition **silently** (gems are durable on open) and
  /// refresh the room — the report is NOT pushed here. The coffer shows itself
  /// (driven by the persisted `haulReady`), and the user collects by tapping it.
  /// Bumps [_homecomingTick] only when a pending actually settles this pass, so
  /// the descent animation plays once for a fresh arrival (a backlog/already-
  /// waiting haul stays a static coffer — Codex). Called on open, on app resume,
  /// and by the due-time timer.
  Future<void> _settleAndRefreshExpedition() async {
    if (!mounted || _expeditionSettleInFlight || _expeditionRevealInFlight) {
      return;
    }
    _expeditionSettleInFlight = true;
    try {
      final before = _adventureState;
      final pending = before?.pending;
      final willSettle =
          pending != null && _pendingRevealable(pending, DateTime.now());
      // Durable: awards gems + moves a returned pending to unviewed history.
      // No push — the coffer + COLLECT tap own the reveal now.
      await AdventureService().settleAndPeekReport();
      final fresh = await _loadAdventureStateSafely();
      if (!mounted) return;
      setState(() {
        if (fresh != null) _adventureState = fresh;
        if (willSettle) _homecomingTick++;
      });
      _scheduleExpeditionReturnTimer();
    } catch (_) {
      // Adventure is optional Home chrome; a settle failure must never break the
      // dashboard. The coffer derivation is fail-open (re-derived next refresh).
    } finally {
      _expeditionSettleInFlight = false;
    }
  }

  /// While Home stays open, fire the homecoming the instant a pending returns
  /// (rather than waiting for an unrelated reload). One-shot, re-armed each
  /// refresh; harmless if it never fires (resume/open also settle).
  void _scheduleExpeditionReturnTimer() {
    _expeditionReturnTimer?.cancel();
    final p = _adventureState?.pending;
    if (p?.returnsAtIso == null) return;
    final r = DateTime.tryParse(p!.returnsAtIso!);
    if (r == null) return;
    final delay = r.difference(DateTime.now());
    if (delay <= Duration.zero) return; // already due — settled on next refresh
    _expeditionReturnTimer = Timer(delay + const Duration(seconds: 1), () {
      if (mounted) _settleAndRefreshExpedition();
    });
  }

  /// The COLLECT path — a user tap on the coffer. Re-peeks the (already-settled)
  /// report and runs the single full-screen reveal, then acknowledges + reloads.
  /// [fromUserTap] keeps the signature for the pad callback; the on-open auto-
  /// push was removed (the coffer is the curtain now).
  Future<void> _maybeRevealExpeditionReport({bool fromUserTap = false}) async {
    if (!mounted || _expeditionRevealInFlight) return;
    if (!fromUserTap && _ongoingSessions.isNotEmpty) return; // idle-session first
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    _expeditionRevealInFlight = true;
    try {
      // Peek only — settlement (gems + history) is durable, but the report
      // stays unviewed until we've actually shown the ceremony, so bailing
      // here never burns it.
      final report = await AdventureService().settleAndPeekReport();
      if (report == null || !mounted) return;
      final currentRoute = ModalRoute.of(context);
      if (currentRoute == null || !currentRoute.isCurrent) return;
      await Navigator.of(context).push(
        arcadeRoute(
          (_) => ExpeditionReportPage(
            report: report,
          ),
          motion: ArcadeRouteMotion.fade,
        ),
      );
      // Acknowledge only now that the report was presented and dismissed.
      await AdventureService().acknowledgeReport(report.expedition.id);
      if (mounted) await _loadData();
    } catch (_) {
      // Adventure is optional Home chrome; a report failure must never hide
      // the dashboard after the primary data has loaded.
    } finally {
      _expeditionRevealInFlight = false;
    }
  }

  void _openAdventure() {
    if (!_adventureUnlocked) {
      showFeatureLockedNotice(context, FeatureGate.adventure);
      return;
    }
    Navigator.of(context)
        .push(
          arcadeRoute(
            (_) => const AdventurePage(),
            motion: ArcadeRouteMotion.fade,
          ),
        )
        .then((_) {
          if (mounted) _loadData();
        });
  }

  // ── Expedition dock (the home-room pad) ────────────────────────────────────

  /// The room's dock view-model, derived fresh from the authoritative service
  /// state (never cached) so the pad can't disagree with the report flow.
  RoomAdventureView? _buildRoomAdventure() {
    // Locked expedition system → the bare dormant pad (no meter, no
    // affordance); the pad's dormant tap shows the invitation notice.
    if (!_adventureUnlocked) return null;
    final state = _adventureState;
    if (state == null) return null;
    final now = DateTime.now();
    final ui = adventureUiStateOf(
      state,
      now,
      currentWeekIso: isoWeekKey(now),
    );
    final route = adventureRouteById(
      state.pending?.routeId ?? state.standingOrderRouteId,
    );
    int? backInHours;
    final pending = state.pending;
    if (ui.phase == AdventurePhase.out && pending?.returnsAtIso != null) {
      final returnsAt = DateTime.tryParse(pending!.returnsAtIso!);
      if (returnsAt != null) {
        backInHours = (returnsAt.difference(now).inMinutes / 60).ceil();
        if (backInHours < 1) backInHours = 1;
      }
    }
    // haulReady is the persisted authority for the coffer (Codex) and also
    // blocks dispatch while a haul sits uncollected (single-track pad).
    final haulReady = hasUncollectedHaul(state, now);
    // BIT's voice line — a pure function of the room state. greeted: this
    // expedition's "I'm back" was already consumed. _lastVoice* are recorded so
    // a re-entry can flip a shown greeting to the away status.
    final pendingId = state.pending?.id;
    final greeted = pendingId != null && _greetedExpeditionId == pendingId;
    final voice = BitRoomVoice.select(
      phase: ui.phase,
      haulReady: haulReady,
      greeted: greeted,
      adviceLine: _adviceLine,
      routeName: route.name,
      backInHours: backInHours,
      // A locked quest board must never draw a BIT nudge toward it.
      claimableCount: _questsUnlocked ? _questClaimable : 0,
    );
    _lastVoiceKind = voice.kind;
    _lastVoicePendingId = pendingId;
    return RoomAdventureView(
      phase: ui.phase,
      charges: ui.charges,
      canDispatch: ui.canDispatch && !haulReady,
      haulReady: haulReady,
      homecomingTick: _homecomingTick,
      routeName: route.name,
      routeAccent: route.accent,
      backInHours: backInHours,
      voice: voice,
    );
  }

  /// Pad tapped while idle: open the console if a charge is ready, else nudge.
  void _onPadDispatch() {
    final state = _adventureState;
    if (state == null) return;
    final now = DateTime.now();
    // Centralized guard (Codex): never open the console while an uncollected
    // haul sits — collect it first (the dispatch entry must check this too, not
    // just the room's canDispatch flag).
    if (hasUncollectedHaul(state, now)) {
      _showArcadeSnack('COLLECT YOUR HAUL FIRST');
      return;
    }
    final ui = adventureUiStateOf(
      state,
      now,
      currentWeekIso: isoWeekKey(now),
    );
    if (!ui.canDispatch) {
      _showArcadeSnack(
        ui.weeklyCapped
            ? 'WEEKLY EXPEDITION LIMIT REACHED'
            : 'TRAIN TO EARN A CHARGE',
      );
      return;
    }
    final defaultRoute =
        state.standingOrderRouteId ??
        (_characterClass != null
            ? defaultRouteForClass(_characterClass!).id
            : adventureRoutes.first.id);
    showExpeditionDispatchSheet(
      context,
      charges: ui.charges,
      vit: _vitality,
      stats: _combatStats,
      selectedRouteId: defaultRoute,
      onSend: _dispatchExpedition,
    );
  }

  /// Spend a charge. The service's null return is the source of truth; reloading
  /// flips the room to `out`, which plays the launch overlay.
  Future<bool> _dispatchExpedition(String routeId) async {
    final expedition = await AdventureService().dispatchExpedition(routeId);
    if (!mounted) return expedition != null;
    if (expedition == null) _showArcadeSnack('CANNOT DISPATCH RIGHT NOW');
    await _loadData();
    return expedition != null;
  }

  void _showArcadeSnack(String message) {
    showArcadeNotice(context, message);
  }

  Widget _homeCard({
    required Widget child,
    Color background = kCard,
    Color borderColor = kBorder,
    double borderAlpha = 1.0,
    double backgroundAlpha = 1.0,
    double borderWidth = 1.0,
    EdgeInsetsGeometry? padding,
    List<BoxShadow>? boxShadow,
  }) {
    return ArcadeCard(
      background: background,
      borderColor: borderColor,
      borderAlpha: borderAlpha,
      backgroundAlpha: backgroundAlpha,
      borderWidth: borderWidth,
      padding: padding,
      boxShadow: boxShadow,
      child: child,
    );
  }

  Widget _missionHeader({
    required Color accent,
    Widget? trailing,
    MissionHeaderMode mode = MissionHeaderMode.calm,
  }) {
    // The "TODAY'S MISSION" header row has three registers — each pairs a color
    // with a motion that *means* the card's state (defaults to calm; an unknown
    // state never reads as active or recovery):
    //  • active (a workout still to be done today) → neon-green + a live glint
    //    sweep ("this is on, act now").
    //  • recovery (a protected rest day) → cyan + a slow breathing glow ("rest,
    //    you're protected") — the calm opposite of the sweep.
    //  • calm (done / finished / arc-complete) → muted + a rare phosphor flicker;
    //    neon stays reserved for the border + progress bar.
    final (headerColor, label) = switch (mode) {
      MissionHeaderMode.active => (
        kNeon,
        const CrtSweep(
          text: 'TODAY\'S MISSION',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kNeon,
          ),
        ),
      ),
      MissionHeaderMode.recovery => (
        kRecoveryAccent,
        const CrtBreathe(
          text: 'TODAY\'S MISSION',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kRecoveryAccent,
          ),
        ),
      ),
      MissionHeaderMode.calm => (
        kMutedText,
        const CrtFlicker(
          text: 'TODAY\'S MISSION',
          highlightColor: kText,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kMutedText,
          ),
        ),
      ),
    };
    return Row(
      children: [
        ImageIcon(
          const AssetImage('assets/icons/control/icon_play.png'),
          size: 18,
          color: headerColor,
        ),
        const SizedBox(width: kSpace2),
        label,
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _missionCard({
    required Color accent,
    Widget? trailing,
    MissionHeaderMode headerMode = MissionHeaderMode.calm,
    String? meta,
    required String title,
    String? detail,
    Widget? middle,
    Widget? nextUp,
    String? supportText,
    Color? supportColor,
    String? supportIconPath,
    String? primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    Color? borderColor,
    Color titleColor = kText,
  }) {
    final titleSize = title.length > 18 ? 14.0 : 18.0;

    return _homeCard(
      background: kSurface2,
      borderColor: borderColor ?? accent,
      borderWidth: kPrimaryCardBorderWidth,
      // Gentle bloom — the neon border reads as structure (the "today" frame),
      // not a shout; the interior progress bar stays the brighter focal point.
      boxShadow: neonGlow(color: borderColor ?? accent, opacity: 0.12, blur: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _missionHeader(accent: accent, trailing: trailing, mode: headerMode),
          if (meta != null && meta.isNotEmpty) ...[
            const SizedBox(height: kSpace5),
            Text(
              meta,
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ] else
            const SizedBox(height: kSpace5),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: titleSize,
              color: titleColor,
              height: 1.35,
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            // Tight to the title — the detail is a hero sub-label (tier 1), not a
            // peer of the zones below; the bigger gap before `middle` separates
            // the tiers.
            const SizedBox(height: kSpace2),
            Text(
              detail,
              style: AppFonts.shareTechMono(
                color: kText.withValues(alpha: 0.78),
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ],
          if (middle != null) ...[const SizedBox(height: kSpace4), middle],
          if (nextUp != null) ...[const SizedBox(height: kSpace3), nextUp],
          if (supportText != null && supportText.isNotEmpty) ...[
            const SizedBox(height: kSpace4),
            Row(
              children: [
                ImageIcon(
                  AssetImage(
                    supportIconPath ??
                        'assets/icons/control/ui/icon_mission_star.png',
                  ),
                  size: 16,
                  color: supportColor ?? kAmber,
                ),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Text(
                    supportText,
                    style: AppFonts.shareTechMono(
                      color: supportColor ?? kAmber,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: kSpace5),
            PixelButton(
              label: primaryLabel,
              color: accent,
              minHeight: 56,
              onPressed: onPrimary,
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: kSpace2),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: kMutedText,
                ),
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _targetLineFromSummary(String summary) {
    return summary.replaceAll(' - ', ' \u2022 ').toLowerCase();
  }

  String _programMissionTitle(ProgramDay day) {
    return switch (day.label) {
      'UPPER' => 'UPPER BODY',
      'LOWER' => 'LOWER BODY',
      'REST' => 'RECOVERY DAY',
      _ => day.label,
    };
  }

  LootItem? get _equippedTitle => _equippedLoot[LootCategory.titleBadge];

  void _confirmDelete(WorkoutSession session) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('This cannot be undone.'),
            const SizedBox(height: kSpace4),
            ArcadeDialogButtonColumn(
              children: [
                PixelButton(
                  label: 'Cancel',
                  secondary: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                PixelButton(
                  label: 'Delete',
                  color: kDanger,
                  haptic: HapticIntent.warning,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await WorkoutStorageService().deleteSession(session.id);
                    _loadData();
                  },
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Future<void> _continueWorkout(WorkoutSession session) async {
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final byId = {for (final e in catalog) e.id: e};
    final exerciseIds = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds
        : session.exercises.map((log) => log.exerciseId).toList();
    final exercises = exerciseIds
        .map((id) => byId[id])
        .whereType<Exercise>()
        .toList();
    if (exercises.isEmpty) return;
    if (!mounted) return;
    _preWorkoutXP = _totalXP;
    _preWorkoutLevel = _level;
    final programService = ProgramService();
    final isProgramWorkout = await programService.isOngoingProgramSession(
      session.id,
    );
    final isProgramRestWorkout = await programService
        .isOngoingProgramRestSession(session.id);
    final prescriptions = await programService.prescriptionsForOngoingSession(
      session.id,
    );
    final restSeconds = await WorkoutDefaultsService().getRestSeconds();
    if (!mounted) return;
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: session.muscleGroup,
          targetMuscleGroups: session.targetMuscleGroups,
          durationMinutes: session.targetDurationMinutes,
          exercises: exercises,
          restSeconds: restSeconds,
          resumeFromSession: session,
          isProgramWorkout: isProgramWorkout,
          advanceProgramRestDayOnCompletion: isProgramRestWorkout,
          prescriptions: prescriptions,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    ).then((_) => _onReturnFromWorkout());
  }

  Future<bool> _prepareNewWorkoutLaunch() async {
    final ongoing = await WorkoutStorageService().getOngoingSession();
    if (!mounted) return false;
    if (ongoing == null) return true;

    final action = await showActiveSessionFoundDialog(context);
    if (!mounted || action == null) return false;
    if (action == ActiveSessionAction.continueOld) {
      await _continueWorkout(ongoing);
      return false;
    }

    await _endOngoingWithoutSummary(ongoing);
    return mounted;
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

  Future<void> _launchWorkoutFromExerciseIds({
    required String muscleGroup,
    required List<String> targetMuscleGroups,
    required List<String> exerciseIds,
    bool isProgramWorkout = false,
    bool advanceProgramRestDayOnCompletion = false,
  }) async {
    final shouldLaunch = await _prepareNewWorkoutLaunch();
    if (!mounted || !shouldLaunch) return;

    final catalog = await ExerciseCatalogService().getFullCatalog();
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    final exercises = exerciseIds
        .map((id) => byId[id])
        .whereType<Exercise>()
        .toList();
    if (!mounted) return;
    if (exercises.isEmpty) {
      showArcadeNotice(context, 'Could not load workout exercises.');
      return;
    }

    final defaults = WorkoutDefaultsService();
    final durationMinutes = await defaults.getDurationMinutes();
    final restSeconds = await defaults.getRestSeconds();
    if (!mounted) return;

    _preWorkoutXP = _totalXP;
    _preWorkoutLevel = _level;
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: muscleGroup,
          targetMuscleGroups: targetMuscleGroups,
          durationMinutes: durationMinutes,
          exercises: exercises,
          restSeconds: restSeconds,
          isProgramWorkout: isProgramWorkout,
          advanceProgramRestDayOnCompletion: advanceProgramRestDayOnCompletion,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    ).then((_) => _onReturnFromWorkout());
  }

  void _startWorkout({
    bool trainAnyway = false,
    bool advanceProgramRestDayOnCompletion = false,
  }) {
    final restInfo = _todayRestInfo;
    if (showsRestDayTrainPrompt(
      trainAnyway: trainAnyway,
      isNewUser: _isNewUser,
      restInfo: restInfo,
    )) {
      _showTrainOnRestDialog(
        advanceProgramRestDayOnCompletion: advanceProgramRestDayOnCompletion,
      );
      return;
    }

    _preWorkoutXP = _totalXP;
    _preWorkoutLevel = _level;
    Navigator.push(
      context,
      arcadeRoute(
        (_) => StartWorkoutPage(
          advanceProgramRestDayOnCompletion: advanceProgramRestDayOnCompletion,
        ),
        motion: ArcadeRouteMotion.flow,
      ),
    ).then((_) => _onReturnFromWorkout());
  }

  /// First-ever workout launcher for the empty last-workout card. Mirrors the
  /// hero mission so the two first-run entries can't diverge: a program user
  /// gets the pre-filled Day-1 (weekday-agnostic, via [_startProgramWorkout]); a
  /// manual (no-program) user gets the now-ungated blank start. Stops the empty
  /// card from dropping a fresh program user into the manual exercise picker.
  void _startFirstWorkout() {
    if (newUserMissionShowsProgramDayOne(_programProgress, _firstSessionDay)) {
      _startProgramWorkout(_firstSessionDay!);
    } else {
      _startWorkout();
    }
  }

  // Program day start: route through the pre-filled review screen (today's
  // lifts pre-selected, focus locked) so the user can add/remove before the
  // confirm + live session — instead of dropping straight into ActiveWorkoutPage.
  // StartWorkoutPage owns the ongoing-session + start-confirm gates at CONTINUE.
  Future<void> _startProgramWorkout(ProgramDay day) async {
    _preWorkoutXP = _totalXP;
    _preWorkoutLevel = _level;
    final programId = _programProgress?.programId;
    final effective = programId == null
        ? day
        : await ProgramCustomizationService().effectiveDay(programId, day);
    if (!mounted) return;
    await Navigator.push(
      context,
      arcadeRoute(
        (_) => programDayStarter(effective),
        motion: ArcadeRouteMotion.flow,
      ),
    );
    await _onReturnFromWorkout();
  }

  Future<void> _repeatLastWorkout(WorkoutSession session) async {
    final exerciseIds = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds
        : session.exercises.map((log) => log.exerciseId).toList();
    await _launchWorkoutFromExerciseIds(
      muscleGroup: session.muscleGroup,
      targetMuscleGroups: session.targetMuscleGroups,
      exerciseIds: exerciseIds,
    );
  }

  Future<void> _onReturnFromWorkout() async {
    final oldXP = _preWorkoutXP;
    final oldLevel = _preWorkoutLevel;
    _preWorkoutXP = null;
    _preWorkoutLevel = null;

    await _loadData();

    if (oldXP == null || oldLevel == null) return;
    final xpDelta = _totalXP - oldXP;
    if (xpDelta <= 0) return;

    // Step 1: XP gain display (the ArcadeBar lights cells on increase)
    setState(() {
      _showXPGain = true;
      _xpGainAmount = xpDelta;
    });

    // The "changed Home" closing beat: surface the session's visible stat gains.
    final delta = await StatEngine().getLastSessionDelta();
    final stats = await StatEngine().getStoredStats();
    if (!mounted) return;
    final hasVisibleGain = const [
      'STR',
      'AGI',
      'END',
    ].any((stat) => (delta[stat] ?? 0) > 0);
    if (hasVisibleGain) {
      setState(() {
        _showLastSessionDelta = true;
        _lastSessionDelta = delta;
        _lastSessionStats = stats;
      });
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (!mounted) return;
        setState(() => _showLastSessionDelta = false);
      });
    }

    // Step 2: Level up (after 600ms, if level changed)
    if (_level > oldLevel) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _showLevelUp = true;
          _levelUpShakeTrigger++;
        });
      });
    }

    // Step 3: Mission card flash (after 1000ms, if completed today)
    if (_missionFinishStateToday != MissionFinishState.none) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() => _missionFlashTrigger++);
      });
    }

    // Settle XP gain text after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _showXPGain = false);
    });

    // Hide level up text after 2.6 seconds
    if (_level > oldLevel) {
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (!mounted) return;
        setState(() => _showLevelUp = false);
      });
    }
  }

  void _showTrainOnRestDialog({
    bool advanceProgramRestDayOnCompletion = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TRAIN ANYWAY?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Today is planned recovery. Training is allowed, but the workout will replace rest XP for today.',
            ),
            const SizedBox(height: kSpace4),
            ArcadeDialogButtonColumn(
              children: [
                PixelButton(
                  label: 'KEEP RESTING',
                  color: kCyan,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                PixelButton(
                  label: 'TRAIN ANYWAY',
                  secondary: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startWorkout(
                      trainAnyway: true,
                      advanceProgramRestDayOnCompletion:
                          advanceProgramRestDayOnCompletion,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    return '$m min';
  }

  String _sessionProgressLabel(WorkoutSession session) {
    final exerciseCount = session.exercises.length;
    final elapsedSeconds = _liveElapsedSeconds(session);
    final minutes = elapsedSeconds ~/ 60;
    if (exerciseCount == 0 && minutes == 0) return 'Ready to continue';

    final exerciseLabel = exerciseCount == 1
        ? '1 exercise'
        : '$exerciseCount exercises';
    final prefix = session.isPausedForResume ? 'Saved' : exerciseLabel;
    return '$prefix | ${_fmtDuration(elapsedSeconds)}';
  }

  int _sessionCompletedExerciseCount(WorkoutSession session) {
    return session.exercises.where((log) => log.sets.isNotEmpty).length;
  }

  int _sessionTotalExerciseCount(WorkoutSession session) {
    final total = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds.length
        : session.exercises.length;
    return total <= 0 ? 1 : total;
  }

  double _sessionExerciseProgress(WorkoutSession session) {
    final total = _sessionTotalExerciseCount(session);
    return (_sessionCompletedExerciseCount(session) / total)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String? _missionRewardLabel(WorkoutSession? session) {
    if (session != null) {
      if (session.isPausedForResume) return 'SAVED';
      final emptySession =
          session.exercises.isEmpty && _liveElapsedSeconds(session) == 0;
      final xp = emptySession ? 0 : XpService.calculateLiveSessionXP(session);
      return '+$xp XP';
    }

    final gems = _suggestedMissionRewardGems;
    if (gems == null) return null;
    return '+$gems gems';
  }

  int _liveElapsedSeconds(WorkoutSession session) {
    return session.elapsedSecondsForDisplay(DateTime.now());
  }


  // ── Weekly Quests card ─────────────────────────────────────────────────────

  Widget _buildWeeklyQuestsCard() {
    if (!_questsUnlocked) {
      // The earned-unlock locked card: receded, all cells dark, the invitation
      // line where the count would be. The tap routes through the shell's
      // guard (→ the floating notice), so the card never feels dead.
      return ArcadeTap(
        onTap: widget.onViewQuests,
        haptic: HapticIntent.selection,
        borderRadius: BorderRadius.circular(4),
        child: Semantics(
          button: true,
          label:
              'Weekly quests — locked. '
              '${featureGateSpecs[FeatureGate.quests]!.lockedNotice}.',
          excludeSemantics: true,
          child: _homeCard(
            background: kCard,
            backgroundAlpha: 0.6,
            borderColor: kBorder,
            borderAlpha: 0.45,
            padding: const EdgeInsets.all(kSpace3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WEEKLY QUESTS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: kDim,
                  ),
                ),
                const SizedBox(height: 10),
                ArcadeBar.segments(
                  litCells: 0,
                  totalCells: _weeklyQuestTotal,
                  height: 10,
                ),
                const SizedBox(height: 10),
                Text(
                  featureGateSpecs[FeatureGate.quests]!.lockedNotice,
                  style: const TextStyle(fontSize: 12, color: kMutedText),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ArcadeTap(
      onTap: widget.onViewQuests,
      haptic: HapticIntent.selection,
      borderRadius: BorderRadius.circular(4),
      child: _homeCard(
        background: kCard,
        backgroundAlpha: 0.86,
        borderColor: kBorder,
        borderAlpha: 0.8,
        padding: const EdgeInsets.all(kSpace3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'WEEKLY QUESTS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: kMutedText,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_weeklyQuestCompleted / $_weeklyQuestTotal',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: kText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ArcadeBar.segments(
              litCells: _weeklyQuestCompleted,
              totalCells: _weeklyQuestTotal,
              height: 10,
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Mission panel ─────────────────────────────────────────────────────

  Widget _buildMainMissionPanel() {
    final session = _ongoingSessions.isNotEmpty ? _ongoingSessions.first : null;

    if (_missionFinishStateToday == MissionFinishState.endedEarly) {
      return _buildEndedEarlyMissionPanel();
    }

    // New user (onboarded, no completed workouts) → the headline mission until
    // the first workout lands. An in-progress session still falls through to
    // CONTINUE below. A program chosen in onboarding makes the first workout the
    // program's Day 1 (weekday-agnostic) — one unified "your path begins" card,
    // not a FIRST QUEST that reads as separate from the program. Manual-path
    // users (no program) keep the FIRST QUEST free-pick card.
    if (session == null && _isNewUser) {
      if (newUserMissionShowsProgramDayOne(_programProgress, _firstSessionDay)) {
        return _buildProgramMissionPanel(
          day: _firstSessionDay!,
          progress: _programProgress!,
        );
      }
      return _buildFirstQuestMissionPanel();
    }

    if (session == null &&
        _programProgress != null &&
        _programProgress!.completedArc) {
      return _buildProgramArcCompletePanel(_programProgress!);
    }

    if (session == null && _programProgress != null && _programDay != null) {
      final completedSnapshot = _programCompletedToday;
      if (completedSnapshot != null &&
          completedSnapshot.programId == _programProgress!.programId) {
        final program = programById(completedSnapshot.programId);
        final completedDay = program?.weekSchedule[completedSnapshot.dayIndex];
        if (completedDay != null) {
          return _buildProgramCompletedMissionPanel(
            day: completedDay,
            week: completedSnapshot.week,
            dayNumber: completedSnapshot.dayIndex + 1,
          );
        }
      }

      if (!_programDay!.isWorkout) {
        final restInfo = _todayRestInfo;
        if (restInfo != null) {
          return _buildProgramRecoveryMissionPanel(
            day: _programDay!,
            progress: _programProgress!,
            restInfo: restInfo,
          );
        }
      }

      return _buildProgramMissionPanel(
        day: _programDay!,
        progress: _programProgress!,
      );
    }

    if (session == null &&
        _missionFinishStateToday == MissionFinishState.completed) {
      return _buildCompletedMissionPanel();
    }

    final restInfo = _todayRestInfo;
    if (session == null &&
        restInfo != null &&
        restInfo.isPlannedRestDay &&
        !restInfo.hasCompletedWorkout) {
      return _buildRecoveryMissionPanel(restInfo);
    }

    if (session == null && _programProgress == null && _lastWorkout != null) {
      return _buildRepeatLastMissionPanel(_lastWorkout!);
    }

    final muscle = session?.targetMuscleLabel ?? _suggestedMuscle;
    final title = session != null
        ? session.isPausedForResume
              ? '${session.targetMuscleLabel} saved'
              : '${session.targetMuscleLabel} in progress'
        : muscle != null
        ? 'Train $muscle'
        : 'Choose your first workout';
    final detail = session != null
        ? _sessionProgressLabel(session)
        : muscle != null
        ? muscle.toLowerCase()
        : 'Pick a muscle group and start small';
    final rewardLabel = _missionRewardLabel(session);
    final savedProgress = session != null && session.isPausedForResume
        ? Row(
            children: [
              Expanded(
                child: ArcadeBar(
                  value: _sessionExerciseProgress(session),
                  height: 6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_sessionCompletedExerciseCount(session)}/'
                '${_sessionTotalExerciseCount(session)} CLEARED',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: kMutedText,
                ),
              ),
            ],
          )
        : null;

    final panel = _missionCard(
      accent: kNeon,
      headerMode: MissionHeaderMode.active,
      trailing: rewardLabel == null
          ? null
          : _MissionRewardChip(label: rewardLabel),
      title: title.toUpperCase(),
      detail: detail,
      middle: savedProgress,
      supportText: session != null
          ? session.isPausedForResume
                ? 'Saved until midnight'
                : 'Pick up where you left off'
          : 'Balance your build',
      primaryLabel: session != null ? 'CONTINUE' : 'START WORKOUT',
      onPrimary: session == null
          ? _startWorkout
          : () => _continueWorkout(session),
    );

    if (session == null) return panel;
    return Semantics(
      label: session.isPausedForResume
          ? '${session.targetMuscleLabel} saved workout'
          : '${session.targetMuscleLabel} ongoing workout',
      hint: 'Long press to delete this session.',
      child: GestureDetector(
        onLongPress: () => _confirmDelete(session),
        child: panel,
      ),
    );
  }

  Widget _buildFirstQuestMissionPanel() {
    // Manual-path new user only (no program chosen in onboarding): the first
    // workout is a free pick. Program users get the merged Day-1 program card
    // upstream (see _buildMainMissionPanel / newUserMissionShowsProgramDayOne),
    // so the first workout reads as their program beginning, not a separate quest.
    const detail = 'Save your first workout to begin.';
    final card = _missionCard(
      accent: kNeon,
      headerMode: MissionHeaderMode.active,
      trailing: const _MissionRewardChip(label: '+1 XP'),
      meta: 'WEEKLY QUEST',
      title: 'FIRST QUEST',
      detail: detail,
      middle: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '0 / 1',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
        ),
      ),
    );

    return Semantics(
      button: true,
      label:
          "Today's mission, First Quest, "
          '$detail plus one XP, '
          'zero of one complete, tap to start workout',
      child: PhosphorTap(
        onTap: () => _startWorkout(),
        borderRadius: BorderRadius.circular(kCardRadius),
        child: HoldDepress(
          onTap: () => _startWorkout(),
          haptic: HapticIntent.selection,
          borderRadius: BorderRadius.circular(kCardRadius),
          child: card,
        ),
      ),
    );
  }

  Widget _buildRepeatLastMissionPanel(WorkoutSession session) {
    final exerciseCount = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds.length
        : session.exercises.length;
    final title = session.targetMuscleLabel.toUpperCase();
    final primaryLabel = title.length <= 12 ? 'REPEAT $title' : 'REPEAT LAST';

    return _missionCard(
      accent: kNeon,
      headerMode: MissionHeaderMode.active,
      trailing: _MissionRewardChip(
        label: _suggestedMissionRewardGems == null
            ? '+5 gems'
            : '+$_suggestedMissionRewardGems gems',
      ),
      meta: 'REPEAT LAST',
      title: title,
      detail: '$exerciseCount exercises ready',
      supportText: 'Same loadout. Empty sets.',
      primaryLabel: primaryLabel,
      onPrimary: () => _repeatLastWorkout(session),
      secondaryLabel: 'Manual workout',
      onSecondary: () => _startWorkout(trainAnyway: true),
    );
  }

  Widget _buildProgramMissionPanel({
    required ProgramDay day,
    required ProgramProgress progress,
  }) {
    final rewardLabel = _missionRewardLabel(null);

    return _missionCard(
      accent: kNeon,
      headerMode: MissionHeaderMode.active,
      trailing: rewardLabel == null
          ? null
          : _MissionRewardChip(label: rewardLabel),
      title: _programMissionTitle(day),
      detail: _targetLineFromSummary(programDayFocusSummary(day)),
      middle: _programArcMeter(progress),
      nextUp: _programNextUp(progress, todayWorkoutPending: true),
      // The card owns its primary action again — START TRAINING funnels through
      // the same `_startProgramWorkout` launcher as the first-quest panel + the
      // center Train button (one entry API). Manual-workout stays the escape.
      primaryLabel: 'START TRAINING',
      onPrimary: () => _startProgramWorkout(day),
      secondaryLabel: 'Manual workout',
      onSecondary: () => _startWorkout(trainAnyway: true),
    );
  }

  Widget _buildProgramCompletedMissionPanel({
    required ProgramDay day,
    required int week,
    required int dayNumber,
  }) {
    return _missionCard(
      accent: kNeon,
      borderColor: kMutedText,
      trailing: const _MissionClearedChip(),
      title: _programMissionTitle(day),
      titleColor: kMutedText,
      detail: _targetLineFromSummary(programDayFocusSummary(day)),
      middle: _programProgress == null
          ? null
          : _programArcMeter(_programProgress!),
      nextUp: _programProgress == null
          ? null
          : _programNextUp(_programProgress!, todayWorkoutPending: false),
      // No "Session logged." footnote — the CLEARED chip top-right already says it.
    );
  }

  Widget _buildProgramRecoveryMissionPanel({
    required ProgramDay day,
    required ProgramProgress progress,
    required RestDayInfo restInfo,
  }) {
    return _missionCard(
      accent: kRecoveryAccent,
      headerMode: MissionHeaderMode.recovery,
      trailing: _MissionRewardChip(label: '+${restInfo.recoveryXP} XP'),
      // No eyebrow \u2014 like the training-day card. The title (RECOVERY DAY) and
      // detail (the path is protected) already carry the framing; an eyebrow
      // here only re-stated it and crowded the card's densest text stack.
      title: _programMissionTitle(day),
      detail: 'Rest day. The path is protected.',
      middle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _programArcMeter(progress),
          const SizedBox(height: kSpace3),
          Row(
            children: [
              const RestIcon(
                assetPath: RestAssets.recoveryShield,
                fallbackAssetPath: 'assets/icons/control/icon_shield.png',
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                '${restInfo.shieldCharges} / ${RestService.maxShieldCharges} shields ready',
                style: AppFonts.shareTechMono(color: kAmber, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      nextUp: _programNextUp(progress, todayWorkoutPending: false),
      primaryLabel: 'RECOVERY BRIEFING',
      onPrimary: _openRecoveryInsight,
      secondaryLabel: 'TRAIN ANYWAY',
      onSecondary: () => _startWorkout(
        trainAnyway: false,
        advanceProgramRestDayOnCompletion: true,
      ),
    );
  }

  /// The recovery cards' primary action: peek today's briefing (async, pure
  /// read), present BIT's sheet, then commit it as shown only once the route
  /// is pushed (Codex F1: never burn an insight the user never saw). No
  /// reward, no streak, no nudge.
  Future<void> _openRecoveryInsight() async {
    final service = RecoveryInsightService();
    final pick = await service.peekToday();
    if (!mounted) return;
    final sheet = showRecoveryInsightSheet(context, pick);
    unawaited(service.commitShown(pick));
    await sheet;
  }

  /// Goal-gradient meter for the active arc: a real progress bar + honest
  /// `X / N • P%` count. At arc 0 it reads "CURRENT PATH" over an honest "0 / N"
  /// (no fabricated bricks — the bar and count are the only truth).
  Widget _programArcMeter(ProgramProgress progress) {
    final program = programById(progress.programId);
    if (program == null) return const SizedBox.shrink();
    // The framed "PATH" panel — one common-region box grouping the bar + count +
    // locked reward, a deliberate zone inside the mission card.
    return ProgramPathHud(program: program, progress: progress, compact: true);
  }

  /// Forward `NEXT ▸ <label> · <when>` cue for the program mission cards.
  /// [todayWorkoutPending] is true only on the active-workout panel, where today
  /// still shows an undone workout, so the teaser points at the following one.
  Widget? _programNextUp(
    ProgramProgress progress, {
    required bool todayWorkoutPending,
  }) {
    final program = programById(progress.programId);
    if (program == null) return null;
    final lookahead = nextWorkoutLookahead(
      program,
      progress.workoutIndex,
      trainingWeekdays: _trainingWeekdays,
      today: DateUtils.dateOnly(DateTime.now()),
      todayWorkoutPending: todayWorkoutPending,
    );
    if (lookahead == null) return null;
    // A teaser, not a detail dump — the label + when carry the forward pull
    // (Zeigarnik); the focus line is dropped (it repeated today's for same-split
    // days and stacked a redundant band). Full detail is seen on arrival.
    return _NextUpPeek(
      label: lookahead.workout.label,
      whenText: relativeWhen(lookahead.daysAway),
    );
  }

  /// Shown once an arc reaches its target: the next-path prompt. Granting the
  /// title + recording the completion already happened at save time, so this is
  /// purely the BEGIN NEXT PATH / STAY WITH THIS PROGRAM decision surface (and
  /// the graceful fallback if the dedicated reveal was missed).
  Widget _buildProgramArcCompletePanel(ProgramProgress progress) {
    final program = programById(progress.programId);
    final next = nextProgramInChain(progress.programId);
    return _missionCard(
      accent: kAmber,
      trailing: const _MissionClearedChip(),
      meta: 'PROGRAM COMPLETE',
      title: 'PATH COMPLETE',
      titleColor: kAmber,
      detail: program == null
          ? '${progress.arcSessions} sessions forged'
          : '${program.name} • ${progress.arcSessions} sessions forged',
      middle: program == null
          ? ArcadeBar(value: 1, accent: kAmber, height: 6)
          : ProgramPathHud(program: program, progress: progress, compact: true),
      supportText: next == null
          ? 'Path complete. Choose how to continue.'
          : 'Next path ready: ${next.name}',
      supportColor: kAmber,
      primaryLabel: 'BEGIN NEXT PATH',
      onPrimary: _beginNextPath,
      secondaryLabel: 'Stay with this program',
      onSecondary: _stayWithProgram,
    );
  }

  Future<void> _beginNextPath() async {
    await ProgramService().beginNextPath();
    await ProgramService().consumePendingCompletionReveal();
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _stayWithProgram() async {
    await ProgramService().stayWithProgram();
    await ProgramService().consumePendingCompletionReveal();
    if (!mounted) return;
    await _loadData();
  }

  Widget _buildCompletedMissionPanel() {
    final copy = completedMissionCopy(_completedWorkoutToday);

    return _missionCard(
      accent: kNeon,
      borderColor: kMutedText,
      trailing: const _MissionClearedChip(),
      meta: 'CLEARED',
      title: copy.title,
      titleColor: kMutedText,
      detail: copy.detail,
      supportText: 'Mission complete. Tomorrow brings a new challenge.',
      supportColor: kNeon,
    );
  }

  Widget _buildEndedEarlyMissionPanel() {
    final session = _endedEarlyToday;
    final title = session?.targetMuscleLabel ?? 'Today\'s mission';
    final detail = session == null
        ? ''
        : '${_fmtDuration(session.actualDurationSeconds)} saved';

    return _missionCard(
      accent: kAmber,
      borderColor: kAmber,
      trailing: const _MissionFinishedChip(),
      title: title.toUpperCase(),
      titleColor: kMutedText,
      detail: detail,
      supportText: 'Time-only XP awarded. Tomorrow brings a new run.',
      supportColor: kAmber,
    );
  }

  Widget _buildRecoveryMissionPanel(RestDayInfo restInfo) {
    final rewardLabel = '+${restInfo.recoveryXP} XP';

    return _missionCard(
      accent: kRecoveryAccent,
      headerMode: MissionHeaderMode.recovery,
      trailing: _MissionRewardChip(label: rewardLabel),
      meta: 'RECOVERY DAY',
      title: 'RECOVERY DAY',
      detail: 'Stats protected. Recovery runs all day.',
      middle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RestScene(height: 68),
          const SizedBox(height: kSpace3),
          Row(
            children: [
              const RestIcon(
                assetPath: RestAssets.recoveryShield,
                fallbackAssetPath: 'assets/icons/control/icon_shield.png',
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                '${restInfo.shieldCharges} / ${RestService.maxShieldCharges} shields ready',
                style: AppFonts.shareTechMono(color: kAmber, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      primaryLabel: 'RECOVERY BRIEFING',
      onPrimary: _openRecoveryInsight,
      secondaryLabel: 'Train anyway',
      onSecondary: () => _startWorkout(trainAnyway: false),
    );
  }

  Widget _buildSecondaryOngoingSessions() {
    final sessions = _ongoingSessions.skip(1).toList();
    if (sessions.isEmpty) return const SizedBox.shrink();
    final allPaused = sessions.every((session) => session.isPausedForResume);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          allPaused ? 'SAVED' : 'ONGOING',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: allPaused ? kCyan : kAmber,
          ),
        ),
        const SizedBox(height: 8),
        for (final session in sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSecondaryOngoingRow(session),
          ),
      ],
    );
  }

  Widget _buildSecondaryOngoingRow(WorkoutSession session) {
    return Semantics(
      label: session.isPausedForResume
          ? '${session.targetMuscleLabel} saved workout'
          : '${session.targetMuscleLabel} ongoing workout',
      hint: 'Long press to delete this session.',
      child: _PressableCard(
        onLongPress: () => _confirmDelete(session),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_sword.png'),
                size: 18,
                color: kNeon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.targetMuscleLabel,
                      style: const TextStyle(
                        fontFamily: 'ShareTechMono',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sessionProgressLabel(session),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kMutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PixelButton(
                label: 'Continue',
                fullWidth: false,
                onPressed: () => _continueWorkout(session),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  String _compactSessionDate(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final sessionDay = DateUtils.dateOnly(date);
    final daysAgo = today.difference(sessionDay).inDays;
    if (daysAgo <= 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _lastWorkoutSubtitle(WorkoutSession session) {
    final exerciseCount = session.exercises.length;
    final exerciseLabel = exerciseCount == 1
        ? '1 exercise'
        : '$exerciseCount exercises';
    return '${_compactSessionDate(session.date)} | '
        '${_fmtDuration(session.actualDurationSeconds)} | $exerciseLabel';
  }

  Widget _buildLastWorkoutStat() {
    final session = _lastWorkout;
    final title = session?.targetMuscleLabel ?? 'No completed workouts yet';
    final subtitle = session == null
        ? 'Start your first run today'
        : _lastWorkoutSubtitle(session);
    // Once there is a completed session, this card stops being a dead stat and
    // becomes the discoverable gate to the full training log (history, calendar,
    // stats). Before, the only door was the LCK pip — an unlabelled luck tap no
    // one could guess. The "LAST WORKOUT / ANALYSIS >" section header above is
    // now the visible signifier (the whole card stays the tap target).
    final onOpenLog = widget.onViewWorkouts;
    final isLogGate = session != null && onOpenLog != null;

    final card = _homeCard(
      background: kCard,
      backgroundAlpha: 0.78,
      borderColor: kBorder,
      borderAlpha: 0.72,
      // 12px inset to match the sibling cards (Weekly Quests, Expedition).
      padding: const EdgeInsets.all(kSpace3),
      child: Row(
        children: [
          const ImageIcon(
            AssetImage('assets/icons/control/icon_time.png'),
            size: 18,
            color: kMutedText,
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: kSpace1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // No completed workouts yet → the whole card is a first-workout entry. Route
    // through _startFirstWorkout (pre-filled program Day-1 for program users),
    // not the manual+rest-gated _startWorkout, so it matches the hero mission.
    if (session == null) {
      return Semantics(
        button: true,
        label: 'No completed workouts yet, tap to start your first workout',
        child: PhosphorTap(
          onTap: _startFirstWorkout,
          borderRadius: BorderRadius.circular(kCardRadius),
          child: HoldDepress(
            onTap: _startFirstWorkout,
            haptic: HapticIntent.selection,
            borderRadius: BorderRadius.circular(kCardRadius),
            child: card,
          ),
        ),
      );
    }

    // Completed session → the card opens the full training log.
    if (!isLogGate) return card;
    return Semantics(
      button: true,
      label: 'Last workout: $title, $subtitle. Opens your training log.',
      child: PhosphorTap(
        key: const ValueKey('home_training_log_gate'),
        onTap: onOpenLog,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: HoldDepress(
          onTap: onOpenLog,
          haptic: HapticIntent.selection,
          borderRadius: BorderRadius.circular(kCardRadius),
          child: card,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Measured scroll-viewport height (RootPage reserves the bottom
            // nav). The room is the hero; below it we reserve space for the
            // level strip + a peek of the mission card — glanceable progress on
            // open plus a scroll cue.
            final viewportH = constraints.maxHeight;
            final belowFold = (viewportH * 0.18).clamp(120.0, 200.0);
            final roomHeight =
                (viewportH - _HomeStatusHudSliverDelegate._height - belowFold)
                    .clamp(HomeRoomScene.minHeight, viewportH);
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeStatusHudSliverDelegate(
                lck: _lck,
                lckMultiplier: _lckMultiplier,
                gemBalance: _gemBalance,
                vitality: _vitality,
                // LCK is a combat stat → the stat board explains it (same home
                // as VIT). History now has its own discoverable doors (the Home
                // last-workout card + the Labs "Training Log" row), so the luck
                // pip is no longer a hidden gate to the log.
                onLckTap: widget.onViewProfile,
                onGemTap: widget.onOpenShop,
                onVitTap: widget.onViewProfile,
              ),
            ),
            SliverToBoxAdapter(
              child: HomeRoomScene(
                height: roomHeight,
                name: _profile.displayName,
                level: _level,
                title: _equippedTitle?.name ?? _rank,
                titleColor: _equippedTitle?.color ?? kAmber,
                scrollOffset: _roomScroll,
                adventure: _buildRoomAdventure(),
                onDispatchTap: _onPadDispatch,
                onStatusTap: _openAdventure,
                onCollect: () => _maybeRevealExpeditionReport(fromUserTap: true),
                questWeeklyFilled: _questsUnlocked ? _weeklyQuestCompleted : 0,
                questWeeklyTotal: _questsUnlocked ? _weeklyQuestTotal : 0,
                questClaimable: _questsUnlocked ? _questClaimable : 0,
                onViewQuests: widget.onViewQuests,
                questBoardPowered: _questsUnlocked,
                questBoardOfflineLabel:
                    'Quest board, offline. '
                    '${featureGateSpecs[FeatureGate.quests]!.lockedNotice}.',
                onDormantPadTap: _adventureUnlocked
                    ? null
                    : () =>
                          showFeatureLockedNotice(context, FeatureGate.adventure),
                dormantPadLabel: _adventureUnlocked
                    ? null
                    : 'Expedition pad, offline. '
                          '${featureGateSpecs[FeatureGate.adventure]!.lockedNotice}.',
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                kHomeHorizontalPadding,
                kSpace2,
                kHomeHorizontalPadding,
                kSpace5 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  HomeLevelStrip(
                    level: _level,
                    totalXP: _totalXP,
                    todayXP: _todayXP,
                    showXPGain: _showXPGain,
                    xpGainAmount: _xpGainAmount,
                    showLevelUp: _showLevelUp,
                    levelUpShakeTrigger: _levelUpShakeTrigger,
                    onTap: widget.onViewProfile,
                  ),
                  const SizedBox(height: kSpace1),
                  StrobeFlash(
                    trigger: _missionFlashTrigger,
                    borderRadius: BorderRadius.circular(kCardRadius),
                    toggles: 2,
                    toggleMs: 16,
                    child: _buildMainMissionPanel(),
                  ),
                  _buildSecondaryOngoingSessions(),
                  if (_showLastSessionDelta) ...[
                    const SizedBox(height: kSpace2),
                    LastSessionTag(
                      delta: _lastSessionDelta,
                      stats: _lastSessionStats,
                    ),
                  ],
                  // The expedition section appears only once the system is
                  // earned — the room's dormant pad is the locked-state teaser
                  // (a full locked card here would just be day-0 clutter).
                  if (_adventureState != null && _adventureUnlocked) ...[
                    const SizedBox(height: kSectionGap),
                    HomeSectionHeader(
                      title: 'EXPEDITION',
                      actionLabel: 'MAP >',
                      onAction: _openAdventure,
                    ),
                    AdventureCard(
                      state: _adventureState!,
                      onTap: _openAdventure,
                    ),
                  ],
                  const SizedBox(height: kSectionGap),
                  // The header is always present so the section stays labelled
                  // even before the first workout. The ANALYSIS link only
                  // appears once there is a log to open — a new user's card is a
                  // "start your first run" CTA, so a link to an empty log would
                  // be a dead end (HomeSectionHeader hides the link when
                  // onAction is null).
                  HomeSectionHeader(
                    title: 'LAST WORKOUT',
                    actionLabel: 'ANALYSIS >',
                    onAction: _lastWorkout != null ? widget.onViewWorkouts : null,
                  ),
                  _buildLastWorkoutStat(),
                  const SizedBox(height: kSectionGap),
                  HomeSectionHeader(
                    title: 'QUESTS',
                    actionLabel: 'DETAILS >',
                    // Locked: the header stays (the section keeps its name on
                    // the map) but the details link hides — a link into a
                    // locked page would be a dead end.
                    onAction: _questsUnlocked ? widget.onViewQuests : null,
                  ),
                  _buildWeeklyQuestsCard(),
                  const SizedBox(height: kSpace5),
                ]),
              ),
            ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeStatusHudSliverDelegate extends SliverPersistentHeaderDelegate {
  const _HomeStatusHudSliverDelegate({
    required this.lck,
    required this.lckMultiplier,
    required this.gemBalance,
    required this.vitality,
    required this.onLckTap,
    required this.onGemTap,
    required this.onVitTap,
  });

  // Constant, non-morphing sticky bar — the chamber's lit ceiling. min==max so
  // it pins without collapsing (a resource HUD is persistent key UI, not
  // reading content).
  static const double _height = 52;

  final int lck;
  final double lckMultiplier;
  final int gemBalance;
  final int vitality;
  final VoidCallback? onLckTap;
  final VoidCallback? onGemTap;
  final VoidCallback? onVitTap;

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Solid, edge-to-edge ceiling strip — the same dark plane as the room
    // background, so the metrics float on the chamber's ceiling. The key-light
    // line is always on; the room's top glow always receives it.
    return DecoratedBox(
      decoration: const BoxDecoration(color: kBg),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kHomeHorizontalPadding,
            ),
            child: Center(
              child: HomeStatusHud(
                lck: lck,
                lckMultiplier: lckMultiplier,
                gemBalance: gemBalance,
                vitality: vitality,
                onLckTap: onLckTap,
                onGemTap: onGemTap,
                onVitTap: onVitTap,
              ),
            ),
          ),
          // Ceiling fixture key-light at the bottom edge — the resource bar
          // reads as the chamber's lit ceiling, and the room below receives this
          // glow. It sits below the metrics, so it never reduces their contrast.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      kCyan.withValues(alpha: 0.45),
                      kText.withValues(alpha: 0.65),
                      kCyan.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0.06, 0.32, 0.5, 0.68, 0.94],
                  ),
                  boxShadow: neonGlow(color: kCyan, opacity: 0.22, blur: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeStatusHudSliverDelegate oldDelegate) {
    return oldDelegate.lck != lck ||
        oldDelegate.lckMultiplier != lckMultiplier ||
        oldDelegate.gemBalance != gemBalance ||
        oldDelegate.vitality != vitality ||
        oldDelegate.onLckTap != onLckTap ||
        oldDelegate.onGemTap != onGemTap ||
        oldDelegate.onVitTap != onVitTap;
  }
}

/// Home's single competence surface — level + XP progress placed right above
/// the primary action (goal-gradient). Hosts the post-workout XP-gain and
/// level-up reveal that used to live on the character bar; tapping it opens the
/// profile (Labs), the identity destination per the app IA. Quiet by design
/// (amber/reward, never the neon CTA) so it never out-shouts the mission card.
class HomeLevelStrip extends StatelessWidget {
  const HomeLevelStrip({
    super.key,
    required this.level,
    required this.totalXP,
    required this.todayXP,
    this.showXPGain = false,
    this.xpGainAmount = 0,
    this.showLevelUp = false,
    this.levelUpShakeTrigger = 0,
    this.onTap,
  });

  final int level;
  final int totalXP;
  final int todayXP;
  final bool showXPGain;
  final int xpGainAmount;
  final bool showLevelUp;
  final int levelUpShakeTrigger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final xpProgress = XpService.progressForTotalXP(totalXP);
    final pct = (xpProgress.fraction.clamp(0.0, 1.0) * 100).round();

    final strip = Row(
      key: const ValueKey('home_level_strip'),
      children: [
        // LV badge — shakes + strobes on level-up (frozen under reduced motion).
        ScreenShake(
          trigger: levelUpShakeTrigger,
          magnitude: 2,
          frames: 4,
          child: StrobeFlash(
            trigger: levelUpShakeTrigger,
            color: kAmber,
            opacity: 0.3,
            borderRadius: BorderRadius.circular(kCardRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: kCard,
                // Neutral chip border — the amber XP fill is the strip's single
                // accent, so the chip doesn't add a second competing colour.
                border: Border.all(color: kBorder, width: 1),
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Text(
                'LV.$level',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: kText,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ArcadeBar(
                value: xpProgress.fraction,
                // Chunky enough to carry the beveled console volume; amber keeps
                // it the reward/XP read, not the neon action.
                height: 12,
                accent: kAmber,
                flashOnIncrease: true,
                increaseSignal: totalXP,
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      xpProgress.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // One trailing signal, by priority: level-up → XP gain → today.
                  if (showLevelUp)
                    const Text(
                      'LEVEL UP!',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: kAmber,
                      ),
                    )
                  else if (showXPGain)
                    PulseColorText(
                      '+$xpGainAmount XP',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                      ),
                      colorA: kAmber,
                      colorB: kText,
                      periodMs: 500,
                    )
                  else if (todayXP > 0)
                    Text(
                      // Calm info, not an action — muted so it doesn't add neon.
                      '+$todayXP today',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 10,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Semantics(
        label: 'Level $level, $pct percent to next level',
        child: strip,
      );
    }
    return Semantics(
      button: true,
      label: 'Level $level, $pct percent to next level, open profile',
      child: ArcadeTap(
        onTap: onTap,
        haptic: HapticIntent.selection,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: strip,
      ),
    );
  }
}

class HomeStatusHud extends StatelessWidget {
  const HomeStatusHud({
    super.key,
    required this.lck,
    required this.lckMultiplier,
    required this.gemBalance,
    required this.vitality,
    this.onLckTap,
    this.onGemTap,
    this.onVitTap,
  });

  final int lck;
  final double lckMultiplier;
  final int gemBalance;
  final int vitality;
  final VoidCallback? onLckTap;
  final VoidCallback? onGemTap;
  final VoidCallback? onVitTap;

  @override
  Widget build(BuildContext context) {
    // No card chrome — the delegate paints the solid ceiling plane behind us.
    // Per-metric tap padding supplies the spacing and the ≥44px-wide hit area.
    const brandGap = 16.0;
    const metricGap = 4.0;
    const lckIconSize = 17.0;
    const gemIconSize = 16.0;
    const vitIconSize = 17.0;
    const valueFontSize = 9.0;
    final content = Container(
      key: const ValueKey('home_status_hud'),
      child: Row(
        children: [
          const _HomeHudBrand(),
          const SizedBox(width: brandGap),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HomeHudMetric(
                      semanticLabel:
                          'Luck multiplier ${XpService.multiplierLabel(lckMultiplier)}',
                      icon: RadarStatIcon(
                        key: const ValueKey('home_status_lck_icon'),
                        assetPath: RadarStatIcons.lckForValue(lck),
                        size: lckIconSize,
                        semanticLabel: 'Luck streak',
                      ),
                      value: XpService.multiplierLabel(lckMultiplier),
                      valueKey: const ValueKey('home_status_lck_multiplier'),
                      valueColor: lckMultiplier > 1.0 ? kAmber : kMutedText,
                      valueFontSize: valueFontSize,
                      onTap: onLckTap,
                      navHint: 'Opens your stat board',
                    ),
                    SizedBox(width: metricGap),
                    _HomeHudMetric(
                      semanticLabel: 'Gems $gemBalance',
                      icon: Image.asset(
                        'assets/icons/economy/icon_gem.png',
                        key: const ValueKey('home_status_gem_icon'),
                        width: gemIconSize,
                        height: gemIconSize,
                        filterQuality: FilterQuality.none,
                        semanticLabel: 'Gems',
                      ),
                      value: '$gemBalance',
                      valueKey: const ValueKey('home_status_gem_balance'),
                      valueColor: kText,
                      valueFontSize: valueFontSize,
                      onTap: onGemTap,
                      navHint: 'Opens the gem store',
                    ),
                    SizedBox(width: metricGap),
                    _HomeHudMetric(
                      semanticLabel: 'Vitality $vitality',
                      icon: RadarStatIcon(
                        key: const ValueKey('home_status_vit_icon'),
                        assetPath: RadarStatIcons.vitalityForValue(vitality),
                        size: vitIconSize,
                        semanticLabel: 'Vitality',
                      ),
                      value: '$vitality',
                      valueKey: const ValueKey('home_status_vit_value'),
                      valueColor: kText,
                      valueFontSize: valueFontSize,
                      onTap: onVitTap,
                      navHint: 'Opens your stat board',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // The three metrics each own their tap (see _HomeHudMetric); the bar itself
    // is no longer a single button.
    return content;
  }
}

class _HomeHudBrand extends StatelessWidget {
  const _HomeHudBrand();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ironbit',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        // Quiet wordmark, not an action — neon is reserved for the primary
        // action (TRAIN / mission / nav), so the bar reads calm.
        color: kText,
        fontSize: 16,
        height: 1.1,
      ),
    );
  }
}

class _HomeHudMetric extends StatelessWidget {
  const _HomeHudMetric({
    required this.icon,
    required this.value,
    required this.valueKey,
    required this.valueColor,
    required this.semanticLabel,
    required this.valueFontSize,
    this.onTap,
    this.navHint,
  });

  final Widget icon;
  final String value;
  final Key valueKey;
  final Color valueColor;
  final String semanticLabel;
  final double valueFontSize;

  /// When set, the metric is a chrome-free nav button to its destination.
  final VoidCallback? onTap;
  final String? navHint;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            height: 1,
          ).copyWith(color: valueColor, fontSize: valueFontSize),
        ),
      ],
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel, child: row);
    }

    // Chrome-free nav: nothing drawn at rest (no chip/border per the design) —
    // just a widened transparent hit area plus the app's transient press
    // feedback (PhosphorTap flash + HoldDepress) so the tap reveals itself on
    // touch. Height is capped by the thin pinned header by design.
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: navHint,
      child: PhosphorTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: HoldDepress(
          onTap: onTap,
          haptic: HapticIntent.selection,
          borderRadius: BorderRadius.circular(kCardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: row,
          ),
        ),
      ),
    );
  }
}

class _MissionClearedChip extends StatelessWidget {
  const _MissionClearedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.15),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '\u2713 CLEARED',
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8, color: kNeon),
      ),
    );
  }
}

class _MissionFinishedChip extends StatelessWidget {
  const _MissionFinishedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.12),
        border: Border.all(color: kAmber),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'FINISHED',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: kAmber,
        ),
      ),
    );
  }
}

class _MissionRewardChip extends StatelessWidget {
  const _MissionRewardChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isGemReward = label.toLowerCase().contains('gem');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.12),
        border: Border.all(color: kAmber),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGemReward) ...[
            Image.asset(
              'assets/icons/economy/icon_gem.png',
              key: const ValueKey('home_mission_gem_reward_icon'),
              width: 12,
              height: 12,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kAmber,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact forward cue on the program mission card: "NEXT ▸ LOWER · tomorrow".
/// Surfaces what's next + when (relative) without leaving Home — an open-loop
/// glance, never a guilt/appointment. Static (reduced-motion safe), no red.
class _NextUpPeek extends StatelessWidget {
  const _NextUpPeek({required this.label, required this.whenText});

  final String label;
  final String whenText;

  @override
  Widget build(BuildContext context) {
    // The NEXT zone — a *secondary* common-region panel, lighter than the PATH
    // zone (dimmer border + fainter fill + tighter padding) so PATH leads while
    // the two read as one system (section-consistency within the tier).
    return ArcadeCard(
      background: kCard,
      backgroundAlpha: 0.28,
      borderColor: kBorder,
      borderAlpha: 0.45,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace3,
        vertical: kSpace2,
      ),
      child: Row(
        children: [
          const ImageIcon(
            AssetImage('assets/icons/control/ui/icon_next_program.png'),
            size: 14,
            color: kMutedText,
          ),
          const SizedBox(width: kSpace2),
          const Text(
            'NEXT',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kMutedText,
              height: 1.35,
            ),
          ),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Text(
              '$label · $whenText',
              overflow: TextOverflow.ellipsis,
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.child, required this.onLongPress});

  final Widget child;
  final VoidCallback onLongPress;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  @override
  Widget build(BuildContext context) {
    return HoldDepress(
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: widget.child,
      ),
    );
  }
}
