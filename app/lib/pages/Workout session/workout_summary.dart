import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../data/muscle_groups.dart';
import '../../models/finish_result.dart';
import '../../models/adventure_models.dart';
import '../../models/loot_drop.dart';
import '../../models/program_models.dart';
import '../../models/unit_models.dart';
import '../../models/workout_models.dart';
import '../../models/xp_reward_models.dart';
import '../../models/gem_ledger_entry.dart';
import '../../services/adventure_service.dart';
import '../../services/analytics_service.dart';
import '../../services/calibration_service.dart';
import '../../services/gem_service.dart';
import '../../services/haptic_service.dart';
import '../../services/calorie_service.dart';
import '../../services/class_service.dart';
import '../../services/loot_drop_service.dart';
import '../../services/loot_service.dart';
import '../../services/milestone_service.dart';
import '../../services/program_service.dart';
import '../../services/progression_settings_service.dart';
import '../../services/rest_service.dart';
import '../../services/sfx_service.dart';
import '../../services/simple_mode_service.dart';
import '../../services/stat_engine.dart';
import '../../services/unit_settings_service.dart';
import '../../services/workout_storage_service.dart';
import '../../services/xp_boost_service.dart';
import '../../services/xp_service.dart';
import '../../data/companion_address.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_filled.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/companion/bit_companion.dart';
import '../../widgets/companion/bit_core_engine.dart' show BitMood;
import '../../widgets/companion/session_ceremony.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/floating_stat_number.dart';
import '../../widgets/glitch_text.dart';
import '../../widgets/level_up_burst.dart';
import '../../widgets/motion/power_on.dart';
import '../../widgets/pulse_color_text.dart';
import '../../widgets/room/energy_cell.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';
import '../../widgets/typewriter_text.dart';
import '../../widgets/xp_level_meter.dart';
import '../onboarding/rank_assessed_page.dart';
import 'program_completion_reveal.dart';
import '../../widgets/arcade_notice.dart';

class WorkoutSummaryPage extends StatefulWidget {
  const WorkoutSummaryPage({
    super.key,
    required this.muscleGroup,
    this.targetMuscleGroups = const [],
    required this.durationMinutes,
    required this.elapsedSeconds,
    required this.exerciseLogs,
    this.selectedExerciseIds = const [],
    this.sessionId,
    this.isPartial = false,
    this.isAbandoned = false,
    this.markMissionFinished = false,
    this.startedAt,
    this.sessionDate,
    this.abandonedMessage,
    this.resumeFromSession,
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
    this.isCalibration = false,
    this.autoSavedAfterIdle = false,
    this.debugShowcase = false,
  });

  final String muscleGroup;
  final List<String> targetMuscleGroups;
  final int durationMinutes;
  final int elapsedSeconds;
  final List<ExerciseLog> exerciseLogs;
  final List<String> selectedExerciseIds;
  final String? sessionId;
  final bool isPartial;
  final bool isAbandoned;
  final bool markMissionFinished;
  final DateTime? startedAt;
  final DateTime? sessionDate;
  final String? abandonedMessage;
  final WorkoutSession? resumeFromSession;
  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;

  /// Onboarding calibration run — record calibration after save and route to
  /// the rank reveal instead of returning home with the normal stat delta.
  final bool isCalibration;

  /// True when this summary was reached by the 30-minute idle auto-save (rather
  /// than a manual Finish). Shows a calm cutoff note so the trimmed duration is
  /// not a silent rewrite.
  final bool autoSavedAfterIdle;

  /// Debug-only: skip the real save/recompute and inject a synthetic "everything
  /// fires" finish (multi-level-up hero + stat gains + loot/title + cache +
  /// charge + warm-up) so the full finish arc — and all its new juice — can be
  /// previewed on demand. Test-only — no in-app entry point.
  final bool debugShowcase;

  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage> {
  bool _saving = false;
  bool _saved = false;
  late int _baseXP;
  int _earnedXP = 0;
  double _lckMultiplier = 1.0;
  double _potionMultiplier = 1.0;
  int _potionBonusXP = 0;
  int _lootBonusXP = 0;
  SessionRewardEligibility? _rewardEligibility;
  SessionXpBreakdown? _xpBreakdown;
  LootDrop? _cacheDrop;
  bool _chargeGranted = false;
  int _chargeBalance = 0;
  bool _chargeOnExpedition = false;
  bool _warmupBonusGranted = false;
  int _warmupBonusAmount = 0;
  Map<String, int> _statDelta = {};
  Map<String, int> _combatStats = {};
  Map<String, int> _calibratedStats = {};
  FinishResult? _finish;
  FinishSelection? _selection;

  /// Set when this save crosses the active program's session target. Drives the
  /// dedicated completion reveal pushed from [_goHome] before returning to root.
  ProgramCompletion? _programCompletion;

  // Staged reveal (the finish arc's timed cadence). Each beat shows when
  // `_reducedMotion || _stage >= k`. Started once the save/recompute is done.
  static const int _maxStage = 6;
  int _stage = 0;
  bool _revealStarted = false;
  final List<Timer> _revealTimers = [];

  // Level-up "juice": whole-screen shake + amber flash (dopamine pass). Skipped
  // under reduced motion.
  int _summaryShakeTrigger = 0;
  int _levelFlashTrigger = 0;

  // ── BIT Session-Complete ceremony (design_handoff_session_ceremony) ────────
  // BIT owns the screen for 2.55s, then flies into the 72px seat that replaced
  // the medal; the staged reveal starts at max(saveDone, touchdown).
  final GlobalKey _seatKey = GlobalKey();

  /// Whether this summary plays the ceremony at all. Resolved once (needs
  /// MediaQuery): abandoned sessions get no celebration (anti-guilt), the
  /// calibration path has its own rank reveal, and reduced motion goes straight
  /// to seated + revealed per the handoff.
  bool? _playCeremony;

  /// Touchdown delivered (or ceremony not played) — gates the reveal AND makes
  /// the seat visible.
  bool _ceremonyDone = false;

  /// Overlay fully inert and removed from the tree.
  bool _ceremonyGone = false;
  int _seatFlashTick = 0;
  int _ceremonyShakeTrigger = 0;

  // Fire the rolling-counter SFX exactly once, when the first stat number starts
  // rolling (hero stat-gain at stage 3, else the STAT GAINS row at stage 4).
  bool _statCounterSfxFired = false;

  List<String> get _targetMuscleGroups {
    final normalized = normalizeTargetMuscleGroups(widget.targetMuscleGroups);
    if (normalized.isNotEmpty) return normalized;
    return normalizeTargetMuscleGroups([widget.muscleGroup]);
  }

  /// The session's frozen bodyweight (calibration snapshot), resolved once in
  /// the save path and reused for the stored `bodyweightKgAtSave` AND the calorie
  /// estimate so the two never disagree. Null until resolved / if never entered.
  double? _bodyweightKg;

  /// Calorie estimate. Seeded at the MET reference bodyweight for the first
  /// paint, then recomputed once `_bodyweightKg` resolves so the reveal matches
  /// the value persisted on the session.
  late int _estimatedCalories = CalorieService.estimateCaloriesForGroups(
    _targetMuscleGroups,
    widget.elapsedSeconds,
  );

  late final WorkoutSession _baseSession = WorkoutSession(
    id:
        widget.sessionId ??
        widget.resumeFromSession?.id ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    date: widget.sessionDate ?? DateTime.now(),
    startedAt: widget.startedAt,
    muscleGroup: widget.muscleGroup,
    targetMuscleGroups: _targetMuscleGroups,
    targetDurationMinutes: widget.durationMinutes,
    actualDurationSeconds: widget.elapsedSeconds,
    exercises: widget.exerciseLogs,
    estimatedCalories: _estimatedCalories,
    isPartial: widget.isPartial,
    isAbandoned: widget.isAbandoned,
    selectedExerciseIds: widget.selectedExerciseIds,
  );

  @override
  void initState() {
    super.initState();
    _baseXP = XpService.calculateBaseSessionXP(_baseSession);
    _earnedXP = _baseXP;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // `kDebugMode` const-gates the whole showcase branch so `_loadShowcase`
      // (and its fixtures) tree-shake out of release builds — the flag is
      // test-only and true here only under `flutter test` / debug.
      if (kDebugMode && widget.debugShowcase) {
        _loadShowcase();
      } else {
        _saveAndExit();
      }
    });
  }

  @override
  void dispose() {
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  bool get _reducedMotion {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playCeremony ??=
        !_reducedMotion && !widget.isAbandoned && !widget.isCalibration;
    if (!_playCeremony!) {
      _ceremonyDone = true;
      _ceremonyGone = true;
    }
  }

  /// The seated BIT's mood — the handoff's session-hero rule: a level-up
  /// session holds the amber CHEER; a standard session settles to NEUTRAL.
  BitMood get _seatMood => _selection?.hero.kind == HeroKind.levelUp
      ? BitMood.cheer
      : BitMood.neutral;

  /// BIT's typed sign-off (the handoff's summary line, honorific register).
  String get _bitSignOffLine =>
      'Good haul today, ${bitAddress(BitRegister.honorific)}.';

  /// The reveal fires at max(saveDone, ceremony touchdown) — never earlier,
  /// and each caller is safe to invoke repeatedly (`_startReveal` is
  /// idempotent). A save that never completes leaves exactly the pre-ceremony
  /// behavior (the scrim still lifts at touchdown; the CTA stays "SAVING...").
  void _maybeStartReveal() {
    if (!_saved || !_ceremonyDone) return;
    _startReveal();
  }

  bool _lootViewedLogged = false;

  /// The loot-unlock hero reveal IS the collection-engagement moment
  /// (`loot_unlock_viewed`). Fired from every path the hero can become visible —
  /// the staged timer, the reduced-motion snap, AND tap-to-skip — and guarded so
  /// it lands at most once per summary regardless of which path wins.
  void _logLootUnlockViewedIfHero() {
    if (_lootViewedLogged) return;
    if (_selection?.hero.kind == HeroKind.lootUnlock) {
      _lootViewedLogged = true;
      unawaited(AnalyticsService.instance.logLootUnlockViewed());
    }
  }

  /// Kicks off the staged reveal once data is ready. Reduced motion snaps to the
  /// final state instantly. Not used on the calibration path (it navigates to
  /// the rank reveal instead).
  void _startReveal() {
    if (_revealStarted || !mounted) return;
    _revealStarted = true;
    if (_reducedMotion) {
      setState(() => _stage = _maxStage);
      _logLootUnlockViewedIfHero();
      return;
    }
    void at(int ms, int stage) {
      _revealTimers.add(
        Timer(Duration(milliseconds: ms), () {
          if (!mounted) return;
          setState(() => _stage = stage);
        }),
      );
    }

    // Cadence (ms from reveal start) — richer/slower than the first cut so each
    // beat lands: XP punch · XP/level meter (its ~1.6s fill+level-up) · hero ·
    // supporting · breakdown (cards stagger after) · receipts+CTA.
    at(300, 1);
    at(800, 2);
    // The hero beat: reveal it, and for a reserved Tier-3 hero (rank/level/
    // diamond) punch the whole screen (shake + amber flash).
    _revealTimers.add(
      Timer(const Duration(milliseconds: 2600), () {
        if (!mounted) return;
        setState(() => _stage = 3);
        _logLootUnlockViewedIfHero();
        // Level-ups already punched the screen from the meter (per level); only
        // the other Tier-3 heroes (rank/diamond) punch on their reveal here.
        if (_selection?.hero.tier == FinishTier.tier3 &&
            _selection?.hero.kind != HeroKind.levelUp) {
          _fireLevelUpJuice();
        }
        // A hero stat-gain rolls its number here — sound the tally.
        if (_selection?.hero.kind == HeroKind.statGain) {
          _fireStatCounterSfxOnce();
        }
      }),
    );
    // Stage 4 reveals the STAT GAINS row — sound the tally as it rolls (if the
    // hero beat didn't already).
    _revealTimers.add(
      Timer(const Duration(milliseconds: 3200), () {
        if (!mounted) return;
        setState(() => _stage = 4);
        final sel = _selection;
        if (sel != null && _supportingDeltas(sel.hero).isNotEmpty) {
          _fireStatCounterSfxOnce();
        }
      }),
    );
    at(3500, 5);
    at(3900, 6);
  }

  /// Plays the rolling-counter SFX at most once per summary. Only reached from
  /// the staged-reveal timers, which run only when not reduced motion — so the
  /// tally never plays over instantly-snapped numbers.
  void _fireStatCounterSfxOnce() {
    if (_statCounterSfxFired || !mounted) return;
    _statCounterSfxFired = true;
    SfxService.instance.playStatCounter();
  }

  /// "Tap to continue" — skip the wait and jump to the breakdown + CTA.
  void _skipReveal() {
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _revealTimers.clear();
    if (mounted) setState(() => _stage = _maxStage);
    // Skipping still reveals the loot hero — log it here too (idempotent), since
    // the staged stage-3 timer that normally logs it was just cancelled.
    _logLootUnlockViewedIfHero();
  }

  bool _show(int stage) => _reducedMotion || _stage >= stage;

  /// Text entrances TYPE (the app's one text idiom — title and BIT's sign-off
  /// already type); reduced motion renders the finished line.
  Widget _typedOrStatic(
    String text, {
    TextStyle? style,
    TextAlign textAlign = TextAlign.center,
  }) => _reducedMotion
      ? Text(text, style: style, textAlign: textAlign)
      : TypewriterText(text, charMs: 22, style: style, textAlign: textAlign);

  /// Debug-only: inject a synthetic "everything fires" finish and start the
  /// reveal without touching real storage. Level-up is the hero (so the meter
  /// owns the screen-level shake/burst) and every reward card is populated.
  void _loadShowcase() {
    final oldXP = XpService.xpForCurrentLevel(7) + 30;
    final newXP = XpService.xpForCurrentLevel(9) + 40; // crosses 7 → 9
    _statDelta = {'STR': 14, 'AGI': 9, 'END': 6};
    _combatStats = {'STR': 132, 'AGI': 88, 'END': 74, 'VIT': 60, 'LCK': 3};
    _xpBreakdown = XpService.buildBreakdown(
      session: _baseSession,
      baseXP: 120,
      lckMultiplier: 1.5,
      potionMultiplier: 2.0,
      lootBonusXP: 40,
    );
    _baseXP = _xpBreakdown!.baseXP;
    _earnedXP = _xpBreakdown!.finalXP;
    _potionBonusXP = _xpBreakdown!.potionBonusXP;
    _cacheDrop = LootDrop(
      id: 'debug_showcase',
      sessionId: _baseSession.id,
      tier: LootDropTier.rare,
      contentKind: LootDropContentKind.xpBonus,
      awardedAt: _baseSession.date,
      xpBonus: 40,
    );
    _chargeGranted = true;
    _chargeBalance = 2;
    _chargeOnExpedition = false;
    _warmupBonusGranted = true;
    _warmupBonusAmount = 5;
    _finish = FinishResult(
      completion: FinishCompletion.complete,
      earnedXP: _earnedXP,
      oldTotalXP: oldXP,
      newTotalXP: newXP,
      statDelta: _statDelta,
      afterStats: _combatStats,
      lckBefore: 0,
      lckAfter: 0,
      lootUnlocked: const ['iron'],
      elapsedSeconds: widget.elapsedSeconds,
      totalSets: _totalSets,
      exerciseCount: _exerciseCount,
      estimatedCalories: _estimatedCalories,
    );
    _selection = FinishSelection(
      hero: FinishHero(
        kind: HeroKind.levelUp,
        tier: FinishTier.tier3,
        amount: XpService.getLevel(newXP),
      ),
      secondaryBadges: const [
        FinishHero(
          kind: HeroKind.lootUnlock,
          tier: FinishTier.tier2,
          lootId: 'iron',
        ),
        FinishHero(
          kind: HeroKind.titleUnlock,
          tier: FinishTier.tier2,
          title: 'Squire',
        ),
      ],
    );
    setState(() {
      _saving = false;
      _saved = true;
    });
    _maybeStartReveal();
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _totalSets =>
      widget.exerciseLogs.fold<int>(0, (sum, log) => sum + log.sets.length);

  int get _exerciseCount =>
      widget.exerciseLogs.where((log) => log.sets.isNotEmpty).length;

  Future<void> _saveAndExit() async {
    if (_saving || _saved) return;

    if (_totalSets == 0 && !widget.isAbandoned) {
      showArcadeNotice(context, 'Save at least one set first.');
      return;
    }

    setState(() => _saving = true);
    if (widget.isAbandoned) {
      await WorkoutStorageService().replaceOngoingWithAbandoned(
        _baseSession,
        markMissionFinished: widget.markMissionFinished,
      );
      await ProgramService().clearOngoingProgramSession(_baseSession.id);
    } else {
      if (widget.resumeFromSession != null) {
        await WorkoutStorageService().deleteSession(
          widget.resumeFromSession!.id,
        );
      }
      final currentClass = await ClassService().getCurrentClass();
      // Snapshot bodyweight alongside class: frozen on the session so the
      // stat engine's bodyweight-set credit never changes retroactively.
      _bodyweightKg = await CalibrationService().bodyweightKg();
      // Recompute calories with the real bodyweight snapshot (the constructor
      // seeded a fixed 70 kg reference) and refresh the reveal so the shown
      // estimate matches the one persisted on the session.
      final realCalories = CalorieService.estimateCaloriesForGroups(
        _targetMuscleGroups,
        widget.elapsedSeconds,
        bodyweightKg: _bodyweightKg ?? CalorieService.referenceBodyweightKg,
      );
      if (mounted && realCalories != _estimatedCalories) {
        setState(() => _estimatedCalories = realCalories);
      } else {
        _estimatedCalories = realCalories;
      }
      final sessionWithClass = _sessionWithAward(
        classAtSave: currentClass.name,
        bodyweightKgAtSave: _bodyweightKg,
        estimatedCalories: _estimatedCalories,
      );
      final existingSessions = await WorkoutStorageService().getSessions();
      // LCK is the weekly consistency streak (rest-schedule aware). Load state
      // once and reuse it for both the after- and before-save snapshots.
      final restService = RestService();
      final restState = await restService.loadState(now: sessionWithClass.date);
      final lck = restService.consistencyWeeks(
        sessions: [
          for (final session in existingSessions)
            if (session.id != sessionWithClass.id) session,
          sessionWithClass,
        ],
        state: restState,
        now: sessionWithClass.date,
      );
      // Potion spend is deferred: peek the multiplier + survivor list now (no
      // write), then commit the spend only AFTER saveSession succeeds, so a crash
      // mid-save can never lose a charge (Codex F4). Multiplier and survivors come
      // from one read, so the stored value can't disagree with the charges spent.
      final xpBoost = XpBoostService();
      Future<void> Function()? commitPotionSpend;
      _rewardEligibility = XpService.rewardEligibility(sessionWithClass);
      if (_rewardEligibility!.eligible) {
        _lckMultiplier = XpService.lckXpMultiplier(lck);
        final potionPreview = await xpBoost.previewConsume();
        _potionMultiplier = potionPreview.multiplier;
        commitPotionSpend = () =>
            xpBoost.commitConsume(potionPreview.survivors);
        _cacheDrop = await LootDropService().rollForSession(
          session: sessionWithClass,
          lck: lck,
        );
        _lootBonusXP = _cacheDrop?.xpBonus ?? 0;
      } else {
        _baseXP = 0;
        _lckMultiplier = 1.0;
        _potionMultiplier = 1.0;
        _lootBonusXP = 0;
      }
      _xpBreakdown = XpService.buildBreakdown(
        session: sessionWithClass,
        baseXP: _baseXP,
        lckMultiplier: _lckMultiplier,
        potionMultiplier: _potionMultiplier,
        lootBonusXP: _lootBonusXP,
      );
      _baseXP = _xpBreakdown!.baseXP;
      _earnedXP = _xpBreakdown!.finalXP;
      _potionBonusXP = _xpBreakdown!.potionBonusXP;
      final awardedSession = _sessionWithAward(
        classAtSave: currentClass.name,
        bodyweightKgAtSave: _bodyweightKg,
        estimatedCalories: _estimatedCalories,
        baseXP: _baseXP,
        lckMultiplier: _lckMultiplier,
        potionMultiplier: _potionMultiplier,
        lootBonusXP: _lootBonusXP,
        awardedXP: _earnedXP,
      );
      // Adventure charge is granted inside saveSession — snapshot before/after
      // so the summary can surface "+1 CHARGE" as the instant workout payoff.
      final chargesBefore = (await AdventureService().loadState()).charges;
      // Warm-up bonus also lands inside saveSession (once/day). Isolate the
      // warmup-source ledger delta so an Adventure expedition settling on this
      // same save can't be mistaken for the warm-up bonus.
      final gemService = GemService();
      final warmupGemsBefore = _warmupGemTotal(await gemService.ledger());
      await WorkoutStorageService().saveSession(awardedSession);
      // Session is durably saved — now spend the potion charge(s) and record the
      // realized bonus (both deferred so a crash mid-save can't lose a charge).
      if (commitPotionSpend != null) await commitPotionSpend();
      await xpBoost.recordBonusXp(_potionBonusXP);
      final advState = await AdventureService().loadState();
      _chargeGranted = advState.charges > chargesBefore;
      _chargeBalance = advState.charges;
      // BIT is "on expedition" while an unsettled pending run is out (returned
      // ones were already settled inside saveSession) — gates the "ready to
      // deploy" tail, since you can't dispatch while one is in flight.
      _chargeOnExpedition = advState.pending != null;
      _warmupBonusAmount =
          _warmupGemTotal(await gemService.ledger()) - warmupGemsBefore;
      _warmupBonusGranted = _warmupBonusAmount > 0;
      final engine = StatEngine();
      if (widget.isCalibration) {
        // Convert this real workout into a calibration seed, then recompute so
        // the reveal shows the seeded ranks.
        await CalibrationService().recordCalibrationWorkout(awardedSession);
        _calibratedStats = await engine.calculateAllStats();
      }
      _statDelta = await engine.getLastSessionDelta();
      if (_statDelta.isNotEmpty) {
        await WorkoutStorageService().annotateSessionStatDelta(
          awardedSession.id,
          _statDelta,
        );
      }
      _combatStats = await engine.getStoredStats();
      final allSessions = await WorkoutStorageService().getSessions();
      final newLoot = await LootService().evaluateUnlocks(
        stats: _combatStats,
        sessions: allSessions,
      );
      // Earning loot is a reward beat — one tactile hit when this save unlocks
      // anything (the per-level reward fires separately as the XP bar climbs).
      if (newLoot.isNotEmpty) HapticService.instance.reward();

      // Build the finish-arc view model from a before-snapshot (stats/level/LCK
      // captured pre-save) + the recompute, then pick the single hero + tier.
      final priorSessions = existingSessions
          .where(
            (s) =>
                s.id != awardedSession.id &&
                s.id != widget.resumeFromSession?.id,
          )
          .toList();
      final oldTotalXP = XpService.calculateTotalXP(priorSessions);
      final lckBefore = restService.consistencyWeeks(
        sessions: priorSessions,
        state: restState,
        now: awardedSession.date,
      );
      final beforeStats = Map<String, int>.from(_combatStats);
      for (final entry in _statDelta.entries) {
        beforeStats[entry.key] = (beforeStats[entry.key] ?? 0) - entry.value;
      }
      final beforeMilestones = MilestoneService.snapshotFromSessions(
        sessions: priorSessions,
        stats: beforeStats,
        totalXP: oldTotalXP,
        lck: lckBefore,
      );
      final afterMilestones = MilestoneService.snapshotFromSessions(
        sessions: allSessions,
        stats: _combatStats,
        totalXP: oldTotalXP + _earnedXP,
        lck: lck,
      );
      final milestoneEvents = MilestoneService.milestonesCrossed(
        beforeMilestones,
        afterMilestones,
        lootUnlocked: newLoot,
      );
      _finish = FinishResult(
        completion: widget.isPartial
            ? FinishCompletion.partial
            : FinishCompletion.complete,
        earnedXP: _earnedXP,
        oldTotalXP: oldTotalXP,
        newTotalXP: oldTotalXP + _earnedXP,
        statDelta: _statDelta,
        afterStats: _combatStats,
        lckBefore: lckBefore,
        lckAfter: lck,
        lootUnlocked: newLoot,
        elapsedSeconds: widget.elapsedSeconds,
        totalSets: _totalSets,
        exerciseCount: _exerciseCount,
        estimatedCalories: _estimatedCalories,
        milestoneEvents: milestoneEvents,
      );
      _selection = selectHero(_finish!);
      await _maybeShowProgressionOptIn(allSessions);

      if (widget.isProgramWorkout || widget.advanceProgramRestDayOnCompletion) {
        await ProgramService().advanceDay();
        // Arc-completion check sits on top of the advance: records the finish
        // once, grants the title, and stages the reveal shown at _goHome.
        _programCompletion = await ProgramService().evaluateCompletion();
        if (widget.resumeFromSession != null) {
          await ProgramService().clearOngoingProgramSession(
            widget.resumeFromSession!.id,
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
      // Begin the staged finish-arc reveal (normal flow only; the calibration
      // path navigates to the rank reveal below instead). Gated on the
      // ceremony's touchdown when one is playing.
      if (!widget.isCalibration) _maybeStartReveal();
    }

    // Calibration run: show rank reveal, then pop this summary so the awaiting
    // ActiveWorkoutPage can pop and let OnboardingFlowPage enter the main app.
    if (mounted && widget.isCalibration && !widget.isAbandoned) {
      await Navigator.of(context).push<void>(
        arcadeRoute(
          (_) => RankAssessedPage(stats: _calibratedStats),
          motion: ArcadeRouteMotion.reveal,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  int _warmupGemTotal(List<GemLedgerEntry> ledger) => ledger
      .where((e) => e.sourceKind == GemLedgerSourceKind.warmup)
      .fold<int>(0, (sum, e) => sum + e.amount);

  WorkoutSession _sessionWithAward({
    String? classAtSave,
    double? bodyweightKgAtSave,
    int? estimatedCalories,
    int? baseXP,
    double? lckMultiplier,
    double? potionMultiplier,
    int? lootBonusXP,
    int? awardedXP,
  }) {
    return WorkoutSession(
      id: _baseSession.id,
      date: _baseSession.date,
      startedAt: _baseSession.startedAt,
      muscleGroup: _baseSession.muscleGroup,
      targetMuscleGroups: _baseSession.targetMuscleGroups,
      targetDurationMinutes: _baseSession.targetDurationMinutes,
      actualDurationSeconds: _baseSession.actualDurationSeconds,
      exercises: _baseSession.exercises,
      estimatedCalories: estimatedCalories ?? _baseSession.estimatedCalories,
      isPartial: _baseSession.isPartial,
      isAbandoned: _baseSession.isAbandoned,
      selectedExerciseIds: _baseSession.selectedExerciseIds,
      baseXP: baseXP,
      lckMultiplier: lckMultiplier,
      potionMultiplier: potionMultiplier,
      lootBonusXP: lootBonusXP,
      awardedXP: awardedXP,
      classAtSave: classAtSave,
      bodyweightKgAtSave: bodyweightKgAtSave,
    );
  }

  String get _xpMathLabel {
    if (_rewardEligibility?.eligible == false) return '+0 XP SAVED';
    // Just the headline total — the receipt card below carries the full
    // BASE × LCK + CACHE math, so repeating it here as big text is redundant.
    return '+$_earnedXP XP EARNED';
  }

  Future<void> _maybeShowProgressionOptIn(
    List<WorkoutSession> allSessions,
  ) async {
    if (!mounted || widget.isCalibration || widget.isAbandoned) return;
    // Simple Mode opted out of the suggestion scaffolding — don't nudge them
    // back into it.
    if (await SimpleModeService().isEnabled()) return;
    final service = ProgressionSettingsService();
    if (!await service.shouldShowOptInPrompt(sessions: allSessions)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ENABLE SUGGESTED LOADS?'),
          content: Text(
            'You have enough history now. Ironbit can show TRY loads, but only when you tap them.',
            style: AppFonts.shareTechMono(color: kText, fontSize: 13),
          ),
          actions: [
            ArcadeTextButton(
              onPressed: () async {
                await service.dismissOptInPrompt();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('NOT NOW'),
            ),
            ArcadeTextButton(
              onPressed: () async {
                await service.acceptOptInPrompt();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('ENABLE'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _goHome() async {
    final completion = _programCompletion;
    if (completion != null) {
      _programCompletion = null;
      await Navigator.of(context).push<void>(
        arcadeRoute(
          (_) => ProgramCompletionRevealScreen(completion: completion),
          motion: ArcadeRouteMotion.reveal,
        ),
      );
      // The reveal (or Home) consumes the staged fallback; clear it either way
      // so it can't replay after we return to root.
      await ProgramService().consumePendingCompletionReveal();
      if (!mounted) return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Visible capability gains shown as the labelled "STAT GAINS" row (pure
  /// logic lives in [supportingGains] so it's unit-testable).
  Map<String, int> _supportingDeltas(FinishHero hero) =>
      supportingGains(_statDelta, hero);

  /// Fired by the XP meter each time the bar crosses a level. The reward beat
  /// (haptic + chime) fires for EVERY level-up so a non-hero level-up is never
  /// silently swallowed; the whole-screen shake + CRT burst stay reserved for
  /// when level-up is the session hero (single-peak — they'd fight a rank/
  /// diamond hero's own beat). The meter's local bar surge + LV punch fire on
  /// their own for every crossing.
  void _fireLevelUpJuice() {
    if (!mounted) return;
    // Tactile + audible level-up, fired per level crossed. Neither is a
    // vestibular trigger, so both land even under reduced motion (which skips
    // the shake/flash below); each carries its own opt-out (Haptics / Sound).
    // The stamp (two firm bumps) replaces any lingering climb buzz.
    HapticService.instance.levelUp();
    SfxService.instance.playLevelUp();
    if (_reducedMotion) return;
    // Screen-level celebration only when level-up owns the screen.
    if (_selection?.hero.kind != HeroKind.levelUp) return;
    setState(() {
      _summaryShakeTrigger++;
      _levelFlashTrigger++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exerciseLogs = widget.exerciseLogs
        .where((log) => log.sets.isNotEmpty)
        .toList();
    final selection = _selection;

    final titleText = widget.isAbandoned
        ? 'SESSION ENDED EARLY'
        : 'SESSION COMPLETE';
    final titleColor = widget.isAbandoned ? kAmber : kNeon;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_goHome());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout Complete'),
          automaticallyImplyLeading: false,
        ),
        body: ScreenShake(
          trigger: _summaryShakeTrigger,
          // The ceremony's surge release — the handoff's ±2px × 120ms device
          // shake ("the haptic made visible"), separate from the level-up
          // shake above so the shipped juice stays untouched.
          child: ScreenShake(
            trigger: _ceremonyShakeTrigger,
            frames: 4,
            frameMs: 30,
            magnitude: 2,
            child: Stack(
              children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  // Add the system nav-bar inset so the "Back to Home" CTA
                  // clears edge-to-edge; the full-bleed overlays below stay
                  // full-bleed (so they aren't wrapped in SafeArea).
                  padding: EdgeInsets.fromLTRB(
                    kSpace4,
                    kSpace4,
                    kSpace4,
                    kSpace4 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: kSpace4),
                      // BIT's seat — the companion replaced the old medal
                      // (ceremony handoff): hidden but laid out until the
                      // flight touches down (the overlay measures its center),
                      // then it appears with a cheer flash + dust puff and
                      // idles forever. Tap = the press orbit reaction. The
                      // session-hero rule picks the mood.
                      Center(
                        child: Opacity(
                          opacity: _ceremonyDone ? 1 : 0,
                          child: SizedBox(
                            key: _seatKey,
                            width: 72,
                            height: 72,
                            child: ExcludeSemantics(
                              excluding: !_ceremonyDone,
                              child: BitCompanion(
                                size: 72,
                                mood: _seatMood,
                                flashTick: _seatFlashTick,
                                spamRestArmed: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpace3),
                      TypewriterText(
                        titleText,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.isAbandoned) ...[
                        const SizedBox(height: kSpace2),
                        Text(
                          widget.abandonedMessage ??
                              'Time XP only. No mission progress.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (!widget.isAbandoned && widget.autoSavedAfterIdle) ...[
                        const SizedBox(height: kSpace2),
                        Text(
                          'Auto-saved after 30 min idle — time counted up to '
                          'your last set.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      // Beat 1 — XP earned. The XP math label SLAMS in —
                      // instantly readable (the fact the user came for; Codex:
                      // never delay it behind a wipe) but landing with force.
                      // The secondary lines follow with the themed entrances,
                      // one moving edge at a time (80ms apart).
                      if (_show(1)) ...[
                        const SizedBox(height: kSpace3),
                        _SlamIn(
                          child: PulseColorText(
                            _xpMathLabel,
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_potionBonusXP > 0) ...[
                          const SizedBox(height: 12),
                          // Text types out (the app's one text idiom — the
                          // title and BIT's sign-off type too).
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const ImageIcon(
                                AssetImage(
                                  'assets/icons/control/icon_potion.png',
                                ),
                                color: kAmber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              _typedOrStatic(
                                '+$_potionBonusXP BONUS XP',
                                style: AppFonts.shareTechMono(
                                  color: kAmber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_xpBreakdown != null) ...[
                          const SizedBox(height: kSpace3),
                          // A ledger prints: rows tick out one-by-one, the
                          // TOTAL lands last with a flash.
                          _XpReceiptCard(
                            breakdown: _xpBreakdown!,
                            printIn: !_reducedMotion,
                          ),
                        ],
                      ],
                      // Beat 2 — XP / level meter: fills from old toward the next
                      // level, with an animated level-up (bar flash + number punch
                      // + whole-screen shake/flash via onLevelUp).
                      if (_finish != null && _show(2)) ...[
                        const SizedBox(height: kSpace4),
                        // Strict single-peak: the meter is the prominent level-up
                        // celebration (big headline + screen punch) only when
                        // level-up is the chosen hero. When a rank/diamond hero
                        // out-ranks it, the meter climbs quietly and fires no
                        // screen juice — the hero owns the single big beat.
                        XpLevelMeter(
                          oldTotalXP: _finish!.oldTotalXP,
                          newTotalXP: _finish!.newTotalXP,
                          play: _show(2),
                          prominent: selection?.hero.kind == HeroKind.levelUp,
                          // Every level-up earns its reward beat (chime + haptic
                          // + the meter's local surge/punch); the screen-level
                          // shake/burst inside _fireLevelUpJuice stay hero-gated.
                          onLevelUp: _fireLevelUpJuice,
                          // The rising sound + a continuous "bar running up"
                          // buzz for each fill segment, both matched to
                          // kXpBarFillDuration. Skipped under reduced motion (the
                          // bar snaps — nothing to ride).
                          onClimbStart: () {
                            if (_reducedMotion) return;
                            SfxService.instance.playXpRiser();
                            HapticService.instance.climbBuzz(
                              durationMs: kXpBarFillDuration.inMilliseconds,
                            );
                          },
                        ),
                      ],
                      // Beat 3 — the single hero beat (tiered). Level-ups are shown
                      // entirely by the XP meter above, so they render no separate
                      // beat here.
                      if (!widget.isAbandoned &&
                          selection != null &&
                          selection.hero.kind != HeroKind.levelUp &&
                          _show(3)) ...[
                        const SizedBox(height: 32),
                        _RevealBeat(child: _HeroBeat(hero: selection.hero)),
                      ],
                      // Beat 4 — secondary badges + supporting (non-hero) gains.
                      if (!widget.isAbandoned &&
                          selection != null &&
                          _show(4)) ...[
                        if (selection.secondaryBadges.isNotEmpty) ...[
                          const SizedBox(height: kSpace3),
                          _SecondaryBadges(badges: selection.secondaryBadges),
                        ],
                        if (_supportingDeltas(selection.hero).isNotEmpty) ...[
                          const SizedBox(height: kSpace3),
                          // Instant: the numbers' own count-up roll IS this
                          // row's entrance (a delayed clip was hiding it).
                          _SupportingStatRow(
                            deltas: _supportingDeltas(selection.hero),
                          ),
                        ],
                      ],
                      // Beat 5 — breakdown.
                      if (exerciseLogs.isNotEmpty && _show(5)) ...[
                        const SizedBox(height: kSpace5),
                        // Section header types out like an arcade menu title.
                        _typedOrStatic(
                          'BREAKDOWN',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: kSpace3),
                        // Rows pop in one-by-one with a hard phosphor strobe (the
                        // same binary blink as the segmented bar cells).
                        _BreakdownReveal(
                          rows: [
                            for (final log in exerciseLogs)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(log.exerciseName),
                                subtitle: Text(
                                  '${log.sets.length} sets - '
                                  '${weightValue(log.totalVolume, Units.weight, decimals: 0)} ${Units.weight.label} total',
                                  style: const TextStyle(color: kMutedText),
                                ),
                              ),
                          ],
                        ),
                      ],
                      // Beat 6 — demoted receipts + the ending CTA.
                      if (_show(6)) ...[
                        const SizedBox(height: kSpace4),
                        // The receipt facts type out; each reward card enters
                        // by its NATURE — loot drops, energy charges up,
                        // warmth kindles — staggered so each lands alone.
                        _ReceiptStrip(
                          elapsedSeconds: widget.elapsedSeconds,
                          totalSets: _totalSets,
                          moves: exerciseLogs.length,
                          estimatedCalories: _estimatedCalories,
                          durationLabel: _fmt(widget.elapsedSeconds),
                          typed: !_reducedMotion,
                        ),
                        if (_cacheDrop != null) ...[
                          const SizedBox(height: kSpace3),
                          _LootDropIn(
                            delayMs: 120,
                            color: _tierColor(_cacheDrop!.tier),
                            child: _CacheDropCard(drop: _cacheDrop!),
                          ),
                        ],
                        if (_chargeGranted) ...[
                          const SizedBox(height: kSpace3),
                          _ChargeUpIn(
                            delayMs: 280,
                            child: _ChargeGrantedCard(
                              balance: _chargeBalance,
                              onExpedition: _chargeOnExpedition,
                            ),
                          ),
                        ],
                        if (_warmupBonusGranted) ...[
                          const SizedBox(height: kSpace3),
                          _KindleIn(
                            delayMs: 440,
                            child: _WarmupBonusCard(amount: _warmupBonusAmount),
                          ),
                        ],
                        // BIT's sign-off line (ceremony handoff) — typed at
                        // 22ms/char; complete instantly under reduced motion.
                        // Fixed-height so the column doesn't shift as it types.
                        const SizedBox(height: kSpace5),
                        _RevealBeat(
                          delayMs: 40,
                          child: SizedBox(
                            height: 18,
                            child: _reducedMotion
                                ? Text(
                                    _bitSignOffLine,
                                    textAlign: TextAlign.center,
                                    style: AppFonts.shareTechMono(
                                      color: kMutedText,
                                      fontSize: 13,
                                    ),
                                  )
                                : TypewriterText(
                                    _bitSignOffLine,
                                    charMs: 22,
                                    textAlign: TextAlign.center,
                                    style: AppFonts.shareTechMono(
                                      color: kMutedText,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: kSpace4),
                        _RevealBeat(
                          delayMs: 80,
                          child: ArcadeFilled(
                            haptic: HapticIntent.selection,
                            onPressed: _saved
                                ? () {
                                    _goHome();
                                  }
                                : null,
                            child: Text(_saving ? 'SAVING...' : 'BACK TO HOME'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // "Tap to continue" — skip the staged wait (normal motion only).
              if (!_reducedMotion && _stage < _maxStage)
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('finish_skip_overlay'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticService.instance.selection();
                      _skipReveal();
                    },
                  ),
                ),
              // The Session-Complete ceremony: BIT owns the screen, then flies
              // into the seat above; touchdown gates the staged reveal. Above
              // the reveal's own skip catcher (the ceremony catches taps
              // first), below LevelUpBurst.
              if (_playCeremony == true && !_ceremonyGone)
                Positioned.fill(
                  child: SessionCeremony(
                    seatKey: _seatKey,
                    onSurge: () =>
                        setState(() => _ceremonyShakeTrigger++),
                    onSettled: () {
                      setState(() {
                        _ceremonyDone = true;
                        _seatFlashTick++;
                      });
                      _maybeStartReveal();
                    },
                    onFinished: () =>
                        setState(() => _ceremonyGone = true),
                  ),
                ),
              // The app's native level-up celebration — rising "+1 LV", amber
              // phosphor wash, and a CRT scanline surge (mirrors the onboarding
              // handoff). Driven by the same trigger as the screen shake.
              Positioned.fill(child: LevelUpBurst(trigger: _levelFlashTrigger)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single headline event for this session. Static here — Phase 2 wraps it
/// in the tiered count-up/ring-pulse beat. Tier 3 reads amber (reserved),
/// Tier 1/2 neon.
class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline({required this.hero});

  final FinishHero hero;

  @override
  Widget build(BuildContext context) {
    final color = hero.tier == FinishTier.tier3 ? kAmber : kNeon;
    final style = TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: hero.tier == FinishTier.tier3 ? 18 : 16,
      color: color,
    );
    final (label, sub) = _copy(hero);
    // Level-up slams in with a glitch; stat-gain counts up (longer for bigger
    // gains); other heroes are static labels.
    final Widget headline;
    if (hero.kind == HeroKind.levelUp) {
      headline = GlitchText(text: 'LEVEL ${hero.amount}', style: style);
    } else if (hero.kind == HeroKind.statGain) {
      headline = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${hero.stat} +', style: style),
          CountUpText(
            value: hero.amount,
            duration: FloatingStatNumber.durationFor(hero.amount),
            style: style,
          ),
        ],
      );
    } else {
      headline = Text(label, textAlign: TextAlign.center, style: style);
    }
    return Column(
      children: [
        headline,
        if (sub != null) ...[
          const SizedBox(height: kSpace2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
          ),
        ],
      ],
    );
  }

  (String, String?) _copy(FinishHero h) => switch (h.kind) {
    HeroKind.rankPromotion => (
      'RANK UP',
      '${h.stat}   ${h.fromRank} -> ${h.toRank}',
    ),
    HeroKind.levelUp => ('LEVEL ${h.amount}', null),
    HeroKind.diamondMilestone => (
      'LCK ${'◆' * h.amount}',
      'xp multiplier raised',
    ),
    HeroKind.lootUnlock => ('NEW LOOT', 'waiting in your inventory'),
    HeroKind.titleUnlock => ('NEW TITLE', h.title),
    HeroKind.statGain => ('${h.stat} +${h.amount}', null),
    HeroKind.recovery => ('RECOVERED', 'stats held — rest counts too'),
  };
}

/// Wraps the hero headline in its tiered beat. Tier 3 (reserved: rank/level/
/// diamond) gets an amber ring pulse + flash; Tier 2 a medium neon flash; Tier 1
/// a single soft phosphor flash. No screen shake, no confetti. Reduced motion
/// renders the static headline.
class _HeroBeat extends StatelessWidget {
  const _HeroBeat({required this.hero});

  final FinishHero hero;

  @override
  Widget build(BuildContext context) {
    // Full-width so the headline's internal centering takes effect. Tier-1/2
    // wrap in StrobeFlash, whose Stack pins a shrink-wrapped child top-left
    // (left-aligned) without this.
    final headline = SizedBox(
      width: double.infinity,
      child: _HeroHeadline(hero: hero),
    );
    if (MediaQuery.of(context).disableAnimations) return headline;
    switch (hero.tier) {
      case FinishTier.tier3:
        return Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: _RingPulse(color: kAmber)),
            ),
            StrobeFlash(
              trigger: 1,
              fireOnMount: true,
              toggles: 1,
              toggleMs: 110,
              color: kAmber,
              opacity: 0.30,
              child: headline,
            ),
          ],
        );
      case FinishTier.tier2:
        return StrobeFlash(
          trigger: 1,
          fireOnMount: true,
          toggles: 1,
          toggleMs: 90,
          color: kNeon,
          opacity: 0.22,
          child: headline,
        );
      case FinishTier.tier1:
        return StrobeFlash(
          trigger: 1,
          fireOnMount: true,
          toggles: 1,
          toggleMs: 80,
          color: kNeon,
          opacity: 0.16,
          child: headline,
        );
    }
  }
}

/// A single amber ring that expands outward and fades — the Tier-3 "ring pulse".
/// Plays once on mount.
class _RingPulse extends StatefulWidget {
  const _RingPulse({required this.color});

  final Color color;

  @override
  State<_RingPulse> createState() => _RingPulseState();
}

class _RingPulseState extends State<_RingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _RingPainter(
          progress: Curves.easeOut.transform(_controller.value),
          color: widget.color,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = ((1 - progress) * 0.5).clamp(0.0, 1.0).toDouble();
    if (alpha <= 0) return;
    final radius = size.shortestSide * (0.35 + progress * 0.65);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// The XP math label's **slam** — instantly readable (never delayed behind a
/// wipe: it is the fact the user opened the screen for) but landing with
/// force: a punch-scale settle (1.16→1.0) + a brief amber strobe + one subtle
/// tick. Reduced motion = the plain child.
class _SlamIn extends StatefulWidget {
  const _SlamIn({required this.child});

  final Widget child;

  @override
  State<_SlamIn> createState() => _SlamInState();
}

class _SlamInState extends State<_SlamIn> with SingleTickerProviderStateMixin {
  // Assigned in initState — a `late final _c = …` initializer is LAZY, and a
  // reduced-motion build that never reads it would first construct it inside
  // dispose() (the unsafe deactivated-ancestor TickerMode lookup).
  late final AnimationController _c;

  bool get _reduce {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: kMotionFast);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reduce) return;
      HapticService.instance.selection();
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce) return widget.child;
    // Center absorbs the stretch: StrobeFlash's Stack shrink-wraps its child
    // top-left (the same quirk _HeroBeat works around), which would yank the
    // centered XP label to the left edge.
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Transform.scale(scale: 1.16 - 0.16 * t, child: child);
        },
        child: StrobeFlash(
          fireOnMount: true,
          trigger: null,
          color: kAmber,
          opacity: 0.18,
          toggles: 3,
          toggleMs: 55,
          child: widget.child,
        ),
      ),
    );
  }
}

/// CRT power-on entrance for a reveal beat — a stepped pixel-arcade flicker
/// (0→0.3→0.8→1.0 brightness) rather than a generic fade+slide, so each element
/// comes up like a powering screen. Reuses [PowerOn]. Reduced motion = static.
class _RevealBeat extends StatefulWidget {
  const _RevealBeat({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<_RevealBeat> createState() => _RevealBeatState();
}

class _RevealBeatState extends State<_RevealBeat> {
  bool _on = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delayMs > 0) {
      _timer = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _on = true);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _on = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return PowerOn(
      enabled: _on,
      builder: (context, power) => Opacity(opacity: power, child: widget.child),
    );
  }
}

/// Breakdown reveal: rows appear one-by-one (~150ms apart), each popping in with
/// a hard phosphor strobe (no fade). Reduced motion renders the whole list at
/// once, solid.
class _BreakdownReveal extends StatefulWidget {
  const _BreakdownReveal({required this.rows});

  final List<Widget> rows;

  @override
  State<_BreakdownReveal> createState() => _BreakdownRevealState();
}

class _BreakdownRevealState extends State<_BreakdownReveal> {
  int _revealed = 0;
  // A capped handful of subtle ticks as the breakdown rows pop in — the
  // celebratory "stats landing" texture, not one buzz per row (Codex haptics
  // review: aggregate, don't machine-gun an automatic reveal).
  int _revealTicks = 0;
  static const _kMaxRevealTicks = 3;
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _revealed = widget.rows.length;
      return;
    }
    _revealed = widget.rows.isEmpty ? 0 : 1;
    _timer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (!mounted || _revealed >= widget.rows.length) {
        t.cancel();
        return;
      }
      if (_revealTicks < _kMaxRevealTicks) {
        _revealTicks++;
        HapticService.instance.selection();
      }
      setState(() => _revealed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.rows.length; i++)
          if (i < _revealed)
            _PhosphorReveal(
              key: ValueKey('breakdown_row_$i'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: kSpace2),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpace3,
                      vertical: kSpace2,
                    ),
                    child: widget.rows[i],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Hard-cut phosphor strobe entrance — the child blinks on/off a few times
/// (binary, no easing), then settles ON. The same blink idiom as the segmented
/// bar cells. Reserves its layout slot so the list doesn't jitter. Reduced
/// motion renders the child solid immediately.
class _PhosphorReveal extends StatefulWidget {
  const _PhosphorReveal({super.key, required this.child});

  final Widget child;

  static const int _toggles = 5;
  static const int _toggleMs = 55;

  @override
  State<_PhosphorReveal> createState() => _PhosphorRevealState();
}

class _PhosphorRevealState extends State<_PhosphorReveal> {
  bool _visible = false;
  int _count = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _visible = true;
      return;
    }
    _startStrobe();
  }

  void _startStrobe() {
    _timer = Timer.periodic(
      const Duration(milliseconds: _PhosphorReveal._toggleMs),
      (t) {
        _count++;
        if (_count >= _PhosphorReveal._toggles) {
          t.cancel();
          if (mounted) setState(() => _visible = true);
          return;
        }
        if (mounted) setState(() => _visible = !_visible);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _visible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: widget.child,
    );
  }
}

/// The **unlock stamp** — a reward badge slams down (scale 1.4→1.0 in hard
/// steps), fires a one-frame amber flash, and pops a 6-spark pixel burst with
/// a decaying glow flare. The arc's earn beat (NEW LOOT / NEW TITLE / LV),
/// speaking the same particle language as the ceremony's surge ring. Hidden
/// (layout reserved) until [delayMs]; reduced motion renders the badge still.
class _UnlockStamp extends StatefulWidget {
  const _UnlockStamp({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<_UnlockStamp> createState() => _UnlockStampState();
}

class _UnlockStampState extends State<_UnlockStamp>
    with SingleTickerProviderStateMixin {
  // Assigned in initState (a `late final _c = …` initializer is lazy — the
  // reduced-motion dispose crash).
  late final AnimationController _c;
  bool _started = false;

  bool get _reduce {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reduce) return;
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (!mounted || _reduce) return;
        setState(() => _started = true);
        _c.forward();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Stamp: 3 hard scale steps over the first ~25% (1.4 → 1.2 → 1.0).
        final scale = !_started
            ? 1.0
            : t < 0.12
            ? 1.4
            : t < 0.25
            ? 1.2
            : 1.0;
        final flashOn = _started && t >= 0.25 && t < 0.34;
        final glow = _started ? (1 - t).clamp(0.0, 1.0) * 0.45 : 0.0;
        return Visibility(
          visible: _started,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kCardRadius),
                    boxShadow: glow > 0.02
                        ? neonGlow(color: kAmber, opacity: glow, blur: 12)
                        : const [],
                  ),
                  child: child,
                ),
              ),
              if (flashOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kAmber.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(kCardRadius),
                      ),
                    ),
                  ),
                ),
              // Spark burst: 6 pixel squares flying outward from the center,
              // fading with age (the ceremony's particle language).
              if (_started && t >= 0.25)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _StampSparksPainter(
                        t: ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _StampSparksPainter extends CustomPainter {
  _StampSparksPainter({required this.t});

  /// Burst progress 0..1 from the stamp's impact frame.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final paint = Paint()..isAntiAlias = false;
    final c = size.center(Offset.zero);
    final dist = 10 + Curves.easeOutCubic.transform(t) * 18;
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * 2 * math.pi - math.pi / 2;
      // Alternate amber with a hot near-white amber for sparkle variety.
      final col = i.isEven ? kAmber : Color.lerp(kAmber, kText, 0.55)!;
      paint.color = col.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawRect(
        Rect.fromLTWH(
          (c.dx + math.cos(a) * dist).roundToDouble(),
          (c.dy + math.sin(a) * dist * 0.7).roundToDouble(),
          2,
          2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StampSparksPainter old) => old.t != t;
}

/// Loot **drops in**: the card falls from ~16px above in hard pixel steps,
/// lands with a one-frame squash + a tier-colored flash, and kicks up a tiny
/// dust pair at its bottom edge. Paint-only (translate/scale — the layout slot
/// is reserved); hidden until [delayMs]; reduced motion renders it settled.
class _LootDropIn extends StatefulWidget {
  const _LootDropIn({
    required this.child,
    required this.color,
    this.delayMs = 0,
  });

  final Widget child;
  final Color color;
  final int delayMs;

  @override
  State<_LootDropIn> createState() => _LootDropInState();
}

class _LootDropInState extends State<_LootDropIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c; // assigned in initState (lazy-init trap)
  bool _started = false;

  bool get _reduce {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reduce) return;
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (!mounted || _reduce) return;
        setState(() => _started = true);
        _c.forward();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Fall: 4 hard steps down over the first ~35%, then landed.
        const drop = 16.0;
        final dy = !_started
            ? 0.0
            : t < 0.35
            ? -drop * (1 - ((t / 0.35) * 4).floor() / 4)
            : 0.0;
        final landed = _started && t >= 0.35;
        // One-frame squash on impact.
        final squash = landed && t < 0.45 ? 0.94 : 1.0;
        final flashOn = landed && t < 0.43;
        return Visibility(
          visible: _started,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, dy),
                child: Transform(
                  transform: Matrix4.diagonal3Values(1, squash, 1),
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
              if (flashOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(kCardRadius),
                      ),
                    ),
                  ),
                ),
              // Impact dust: 4 pixel motes kicked out along the bottom edge.
              if (landed && t < 0.95)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ImpactDustPainter(
                        t: ((t - 0.35) / 0.6).clamp(0.0, 1.0),
                        color: widget.color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ImpactDustPainter extends CustomPainter {
  _ImpactDustPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final paint = Paint()..isAntiAlias = false;
    final e = Curves.easeOutCubic.transform(t);
    final y = size.height - 2 - e * 7;
    for (var i = 0; i < 4; i++) {
      final dir = i.isEven ? -1 : 1;
      final x = size.width / 2 + dir * (14 + (i ~/ 2) * 22 + e * 16);
      final col = i < 2 ? color : kMutedText;
      paint.color = col.withValues(alpha: (1 - t) * 0.8);
      canvas.drawRect(
        Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), 2, 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactDustPainter old) =>
      old.t != t || old.color != color;
}

/// Energy **charges up**: the card powers on in stepped brightness (the CRT
/// flicker — this is the one card whose nature IS powering on), then confirms
/// "fully charged" with a double neon blink. Hidden until [delayMs]; reduced
/// motion renders it charged.
class _ChargeUpIn extends StatefulWidget {
  const _ChargeUpIn({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<_ChargeUpIn> createState() => _ChargeUpInState();
}

class _ChargeUpInState extends State<_ChargeUpIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c; // assigned in initState (lazy-init trap)
  bool _started = false;

  bool get _reduce {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reduce) return;
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (!mounted || _reduce) return;
        setState(() => _started = true);
        _c.forward();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Charging: brightness steps 0 → .3 → .8 → 1 over the first ~40%.
        final power = !_started
            ? 0.0
            : t < 0.13
            ? 0.3
            : t < 0.27
            ? 0.8
            : 1.0;
        // Fully charged: two hard neon blinks once the power settles.
        final blinkOn =
            _started && ((t >= 0.55 && t < 0.66) || (t >= 0.78 && t < 0.89));
        return Visibility(
          visible: _started,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Opacity(opacity: power, child: child),
              if (blinkOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kNeon.withValues(alpha: 0.14),
                        border: Border.all(color: kNeon, width: 1.2),
                        borderRadius: BorderRadius.circular(kCardRadius),
                        boxShadow: neonGlow(opacity: 0.4, blur: 10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Warmth **kindles**: the card surfaces under a hot amber wash that cools
/// away while an ember glow flares then settles — heated metal cooling into
/// place. Hidden until [delayMs]; reduced motion renders it settled.
class _KindleIn extends StatefulWidget {
  const _KindleIn({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<_KindleIn> createState() => _KindleInState();
}

class _KindleInState extends State<_KindleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c; // assigned in initState (lazy-init trap)
  bool _started = false;

  bool get _reduce {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reduce) return;
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (!mounted || _reduce) return;
        setState(() => _started = true);
        _c.forward();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Quantized cool-down: the amber wash fades in 5 steps; the ember glow
        // peaks early then dies with the wash.
        final q = !_started ? 1.0 : ((t * 5).floor() / 5).clamp(0.0, 1.0);
        final wash = _started ? (1 - q) * 0.30 : 0.0;
        final glowT = !_started
            ? 0.0
            : t < 0.3
            ? t / 0.3
            : (1 - (t - 0.3) / 0.7);
        return Visibility(
          visible: _started,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kCardRadius),
                  boxShadow: glowT > 0.05
                      ? neonGlow(
                          color: kAmber,
                          opacity: glowT * 0.4,
                          blur: 14,
                        )
                      : const [],
                ),
                child: Opacity(
                  opacity: _started ? 0.55 + 0.45 * q : 1.0,
                  child: child,
                ),
              ),
              if (wash > 0.02)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kAmber.withValues(alpha: wash),
                        borderRadius: BorderRadius.circular(kCardRadius),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Smaller badges for the non-hero events that also fired this session.
class _SecondaryBadges extends StatelessWidget {
  const _SecondaryBadges({required this.badges});

  final List<FinishHero> badges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: kSpace2,
      runSpacing: kSpace2,
      children: [
        // Unlock stamps: each badge slams down with an amber flash + a pixel
        // spark burst — these are the arc's reward earns, not ordinary chips.
        for (var i = 0; i < badges.length; i++)
          _UnlockStamp(delayMs: i * 180, child: _badge(_label(badges[i]))),
      ],
    );
  }

  String _label(FinishHero h) => switch (h.kind) {
    HeroKind.rankPromotion => 'RANK ${h.stat} ${h.toRank}',
    HeroKind.levelUp => 'LV ${h.amount}',
    HeroKind.diamondMilestone => 'LCK ${'◆' * h.amount}',
    HeroKind.lootUnlock => 'NEW LOOT',
    HeroKind.titleUnlock => 'NEW TITLE: ${h.title}',
    HeroKind.statGain => '${h.stat} +${h.amount}',
    HeroKind.recovery => 'RECOVERED',
  };

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: kBorder),
      borderRadius: BorderRadius.circular(kCardRadius),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
        color: kAmber,
      ),
    ),
  );
}

/// The restrained non-hero capability gains row.
class _SupportingStatRow extends StatelessWidget {
  const _SupportingStatRow({required this.deltas});

  final Map<String, int> deltas;

  @override
  Widget build(BuildContext context) {
    final entries = deltas.entries.toList();
    return Column(
      children: [
        // A labelled section (not stray confetti) so the gains stay legible
        // even when a level-up/rank hero dominates the screen above.
        Text(
          'STAT GAINS',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
        ),
        const SizedBox(height: kSpace2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: kSpace4,
          runSpacing: kSpace2,
          children: [
            // Each gain counts up +0 → +N; the bigger gain ticks longer.
            for (final entry in entries)
              FloatingStatNumber(
                stat: entry.key,
                value: entry.value,
                color: kNeon,
                fontSize: 12,
              ),
          ],
        ),
      ],
    );
  }
}

/// The XP ledger. With [printIn] it enters like a dot-matrix receipt: rows
/// print one-by-one top-to-bottom (~90ms apart, hard cuts — no fades), and the
/// TOTAL line lands last with a brief neon flash. The card frame itself is
/// visible from the start (the paper); only the lines print. Layout is
/// reserved (`maintainSize`) so the column never shifts. `printIn: false`
/// (reduced motion) renders the finished receipt.
class _XpReceiptCard extends StatefulWidget {
  const _XpReceiptCard({required this.breakdown, this.printIn = false});

  final SessionXpBreakdown breakdown;
  final bool printIn;

  @override
  State<_XpReceiptCard> createState() => _XpReceiptCardState();
}

class _XpReceiptCardState extends State<_XpReceiptCard> {
  int _printed = 0;
  bool _totalFlash = false;
  Timer? _timer;

  List<(String, String)> get _rows => [
    ('BASE', '+${widget.breakdown.baseXP} XP'),
    ('LCK', XpService.multiplierLabel(widget.breakdown.lckMultiplier)),
    ('POTION', XpService.multiplierLabel(widget.breakdown.potionMultiplier)),
    if (widget.breakdown.lootBonusXP > 0)
      ('CACHE', '+${widget.breakdown.lootBonusXP} XP'),
    ('TOTAL', '+${widget.breakdown.finalXP} XP'),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.printIn) {
      _printed = _rows.length;
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) return;
      setState(() {
        _printed++;
        if (_printed >= _rows.length) {
          t.cancel();
          _totalFlash = true; // the TOTAL line just landed — flash it once
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Visibility(
              visible: i < _printed,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        color: kMutedText,
                      ),
                    ),
                    const Spacer(),
                    _maybeFlashTotal(
                      isTotal: rows[i].$1 == 'TOTAL',
                      child: Text(
                        rows[i].$2,
                        style: AppFonts.shareTechMono(
                          color: rows[i].$1 == 'TOTAL' ? kNeon : kText,
                          fontSize: 12,
                          fontWeight: rows[i].$1 == 'TOTAL'
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.breakdown.eligibility.eligible) ...[
            const SizedBox(height: kSpace2),
            Text(
              widget.breakdown.eligibility.reason,
              textAlign: TextAlign.center,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _maybeFlashTotal({required bool isTotal, required Widget child}) =>
      isTotal
      ? StrobeFlash(
          trigger: _totalFlash,
          color: kNeon,
          opacity: 0.3,
          toggles: 4,
          toggleMs: 60,
          child: child,
        )
      : child;
}

/// The instant Adventure payoff: a workout earned an expedition charge. The
/// expedition (gems) is the optional second layer the user spends later.
class _ChargeGrantedCard extends StatelessWidget {
  const _ChargeGrantedCard({required this.balance, required this.onExpedition});

  final int balance;

  /// True when BIT is currently out on a run — drops the "ready to deploy"
  /// tail, since a new dispatch is blocked until that one settles.
  final bool onExpedition;

  @override
  Widget build(BuildContext context) {
    final charges = '$balance/${AdventureState.chargeCap} charges';
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.10),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EnergyCell(scale: 1, glow: false),
              const SizedBox(width: kSpace2),
              Text(
                '+1 EXPEDITION CHARGE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: kNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            onExpedition ? charges : '$charges • ready to deploy',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// The warm-up payoff: the user did the opt-in warm-up before this session, so
/// it earned a small gem bonus (once/day). Calm and positive — its absence is
/// always silent (no "you skipped" framing anywhere).
class _WarmupBonusCard extends StatelessWidget {
  const _WarmupBonusCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.10),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/economy/icon_gem.png',
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: kSpace2),
              Text(
                'WARM-UP BONUS +$amount',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: kNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You warmed up before training — primed lifts, and a few gems for the ritual.',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CacheDropCard extends StatelessWidget {
  const _CacheDropCard({required this.drop});

  final LootDrop drop;

  @override
  Widget build(BuildContext context) {
    final (title, detail) = _copy(drop);
    final color = _tierColor(drop.tier);
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        children: [
          Text(
            'CACHE DROP',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: color,
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  (String, String) _copy(LootDrop drop) {
    switch (drop.contentKind) {
      case LootDropContentKind.xpBonus:
        return ('+${drop.xpBonus} XP', '${drop.tier.name.toUpperCase()} cache');
      case LootDropContentKind.frameFragment:
        final assembled = drop.assembledItemId != null
            ? ' Frame assembled.'
            : '';
        return ('FRAME FRAGMENT', '${drop.itemId ?? 'unknown'}$assembled');
      case LootDropContentKind.fullItem:
        return ('NEW LOOT', drop.itemId ?? 'inventory updated');
    }
  }
}

/// Loot-tier accent (shared by the card and its drop-in entrance).
Color _tierColor(LootDropTier tier) => switch (tier) {
  LootDropTier.common => kText,
  LootDropTier.uncommon => kNeon,
  LootDropTier.rare => kCyan,
  LootDropTier.epic => const Color(0xFFA66BFF),
};

/// Demoted receipt facts — context, not reward. One thin muted line, low in the
/// hierarchy. No per-exercise calories; at most one rough total.
class _ReceiptStrip extends StatelessWidget {
  const _ReceiptStrip({
    required this.elapsedSeconds,
    required this.totalSets,
    required this.moves,
    required this.estimatedCalories,
    required this.durationLabel,
    this.typed = false,
  });

  final int elapsedSeconds;
  final int totalSets;
  final int moves;
  final int estimatedCalories;
  final String durationLabel;

  /// Type the line out (the text idiom); false renders it finished.
  final bool typed;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (elapsedSeconds > 0) durationLabel,
      if (totalSets > 0) '$totalSets sets',
      if (moves > 0) '$moves moves',
      if (estimatedCalories > 0) '~$estimatedCalories kcal',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final text = parts.join('   ·   ');
    final style = AppFonts.shareTechMono(color: kMutedText, fontSize: 12);
    return typed
        ? TypewriterText(
            text,
            charMs: 22,
            style: style,
            textAlign: TextAlign.center,
          )
        : Text(text, textAlign: TextAlign.center, style: style);
  }
}
