import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../data/muscle_groups.dart';
import '../../models/finish_result.dart';
import '../../models/loot_drop.dart';
import '../../models/workout_models.dart';
import '../../models/xp_reward_models.dart';
import '../../services/calibration_service.dart';
import '../../services/calorie_service.dart';
import '../../services/class_service.dart';
import '../../services/loot_drop_service.dart';
import '../../services/loot_service.dart';
import '../../services/milestone_service.dart';
import '../../services/program_service.dart';
import '../../services/progression_settings_service.dart';
import '../../services/stat_engine.dart';
import '../../services/workout_storage_service.dart';
import '../../services/xp_boost_service.dart';
import '../../services/xp_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_route.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/floating_stat_number.dart';
import '../../widgets/glitch_text.dart';
import '../../widgets/level_up_burst.dart';
import '../../widgets/motion/power_on.dart';
import '../../widgets/pulse_color_text.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';
import '../../widgets/typewriter_text.dart';
import '../../widgets/xp_level_meter.dart';
import '../onboarding/rank_assessed_page.dart';

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
  Map<String, int> _statDelta = {};
  Map<String, int> _combatStats = {};
  Map<String, int> _calibratedStats = {};
  FinishResult? _finish;
  FinishSelection? _selection;

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

  List<String> get _targetMuscleGroups {
    final normalized = normalizeTargetMuscleGroups(widget.targetMuscleGroups);
    if (normalized.isNotEmpty) return normalized;
    return normalizeTargetMuscleGroups([widget.muscleGroup]);
  }

  late final int _estimatedCalories = CalorieService.estimateCaloriesForGroups(
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
      _saveAndExit();
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

  /// Kicks off the staged reveal once data is ready. Reduced motion snaps to the
  /// final state instantly. Not used on the calibration path (it navigates to
  /// the rank reveal instead).
  void _startReveal() {
    if (_revealStarted || !mounted) return;
    _revealStarted = true;
    if (_reducedMotion) {
      setState(() => _stage = _maxStage);
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
        // Level-ups already punched the screen from the meter (per level); only
        // the other Tier-3 heroes (rank/diamond) punch on their reveal here.
        if (_selection?.hero.tier == FinishTier.tier3 &&
            _selection?.hero.kind != HeroKind.levelUp) {
          _fireLevelUpJuice();
        }
      }),
    );
    at(3200, 4);
    at(3500, 5);
    at(3900, 6);
  }

  /// "Tap to continue" — skip the wait and jump to the breakdown + CTA.
  void _skipReveal() {
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _revealTimers.clear();
    if (mounted) setState(() => _stage = _maxStage);
  }

  bool _show(int stage) => _reducedMotion || _stage >= stage;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log at least one set before saving.')),
      );
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
      final sessionWithClass = _sessionWithAward(
        classAtSave: currentClass.name,
      );
      final existingSessions = await WorkoutStorageService().getSessions();
      final lck = XpService.lckForSessions([
        for (final session in existingSessions)
          if (session.id != sessionWithClass.id) session,
        sessionWithClass,
      ], now: sessionWithClass.date);
      _rewardEligibility = XpService.rewardEligibility(sessionWithClass);
      if (_rewardEligibility!.eligible) {
        _lckMultiplier = XpService.lckXpMultiplier(lck);
        _potionMultiplier = await XpBoostService().consumeActivePotions();
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
        baseXP: _baseXP,
        lckMultiplier: _lckMultiplier,
        potionMultiplier: _potionMultiplier,
        lootBonusXP: _lootBonusXP,
        awardedXP: _earnedXP,
      );
      await WorkoutStorageService().saveSession(awardedSession);
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
      final lckBefore = XpService.lckForSessions(
        priorSessions,
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
      // path navigates to the rank reveal below instead).
      if (!widget.isCalibration) _startReveal();
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

  WorkoutSession _sessionWithAward({
    String? classAtSave,
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
      estimatedCalories: _baseSession.estimatedCalories,
      isPartial: _baseSession.isPartial,
      isAbandoned: _baseSession.isAbandoned,
      selectedExerciseIds: _baseSession.selectedExerciseIds,
      baseXP: baseXP,
      lckMultiplier: lckMultiplier,
      potionMultiplier: potionMultiplier,
      lootBonusXP: lootBonusXP,
      awardedXP: awardedXP,
      classAtSave: classAtSave,
    );
  }

  String get _xpMathLabel {
    if (widget.isAbandoned) return '+$_earnedXP XP EARNED';
    if (_rewardEligibility?.eligible == false) return '+0 XP SAVED';
    final lckLabel = XpService.multiplierLabel(_lckMultiplier);
    final potionLabel = XpService.multiplierLabel(_potionMultiplier);
    if (_lckMultiplier <= 1.0 &&
        _potionMultiplier <= 1.0 &&
        _lootBonusXP <= 0) {
      return '+$_earnedXP XP EARNED';
    }
    final parts = <String>['+$_baseXP XP'];
    if (_lckMultiplier > 1.0) parts.add('× $lckLabel LCK');
    if (_potionMultiplier > 1.0) parts.add('× $potionLabel BOOST');
    if (_lootBonusXP > 0) parts.add('+ $_lootBonusXP CACHE');
    return '${parts.join(' ')} = +$_earnedXP XP';
  }

  Future<void> _maybeShowProgressionOptIn(
    List<WorkoutSession> allSessions,
  ) async {
    if (!mounted || widget.isCalibration || widget.isAbandoned) return;
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
            TextButton(
              onPressed: () async {
                await service.dismissOptInPrompt();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('NOT NOW'),
            ),
            TextButton(
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

  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Non-hero visible capability gains (STR/AGI/END that weren't the hero),
  /// shown as the small "supporting" row.
  Map<String, int> _supportingDeltas(FinishHero hero) => {
    for (final stat in kHeroStatCandidates)
      if (stat != hero.stat && (_statDelta[stat] ?? 0) > 0)
        stat: _statDelta[stat]!,
  };

  /// Fired by the XP meter each time the bar crosses a level — shakes and
  /// flashes the whole screen. No-op under reduced motion.
  void _fireLevelUpJuice() {
    if (!mounted || _reducedMotion) return;
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
        if (!didPop) _goHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout Complete'),
          automaticallyImplyLeading: false,
        ),
        body: ScreenShake(
          trigger: _summaryShakeTrigger,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(kSpace4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: kSpace4),
                      const _RevealBeat(
                        child: ImageIcon(
                          AssetImage('assets/icons/control/icon_star.png'),
                          color: kNeon,
                          size: 72,
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
                      // Beat 1 — XP earned.
                      if (_show(1)) ...[
                        const SizedBox(height: kSpace3),
                        PulseColorText(
                          _xpMathLabel,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_potionBonusXP > 0) ...[
                          const SizedBox(height: 12),
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
                              Text(
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
                          _XpReceiptCard(breakdown: _xpBreakdown!),
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
                          onLevelUp: selection?.hero.kind == HeroKind.levelUp
                              ? _fireLevelUpJuice
                              : null,
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
                          _SupportingStatRow(
                            deltas: _supportingDeltas(selection.hero),
                          ),
                        ],
                      ],
                      // Beat 5 — breakdown.
                      if (exerciseLogs.isNotEmpty && _show(5)) ...[
                        const SizedBox(height: kSpace5),
                        Text(
                          'BREAKDOWN',
                          style: Theme.of(context).textTheme.headlineSmall,
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
                                  '${log.totalVolume.toStringAsFixed(0)} kg total',
                                  style: const TextStyle(color: kMutedText),
                                ),
                              ),
                          ],
                        ),
                      ],
                      // Beat 6 — demoted receipts + the ending CTA.
                      if (_show(6)) ...[
                        const SizedBox(height: kSpace4),
                        _RevealBeat(
                          child: _ReceiptStrip(
                            elapsedSeconds: widget.elapsedSeconds,
                            totalSets: _totalSets,
                            moves: exerciseLogs.length,
                            estimatedCalories: _estimatedCalories,
                            durationLabel: _fmt(widget.elapsedSeconds),
                          ),
                        ),
                        if (_cacheDrop != null) ...[
                          const SizedBox(height: kSpace3),
                          _RevealBeat(
                            delayMs: 120,
                            child: _CacheDropCard(drop: _cacheDrop!),
                          ),
                        ],
                        const SizedBox(height: kSpace5),
                        _RevealBeat(
                          delayMs: 80,
                          child: FilledButton(
                            onPressed: _saved ? _goHome : null,
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
                    onTap: _skipReveal,
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
    final headline = _HeroHeadline(hero: hero);
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
  const _PhosphorReveal({super.key, required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  static const int _toggles = 5;
  static const int _toggleMs = 55;

  @override
  State<_PhosphorReveal> createState() => _PhosphorRevealState();
}

class _PhosphorRevealState extends State<_PhosphorReveal> {
  bool _visible = false;
  int _count = 0;
  Timer? _timer;
  Timer? _delayTimer;
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
    if (widget.delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _startStrobe();
      });
    } else {
      _startStrobe();
    }
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
    _delayTimer?.cancel();
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
        // Chips strobe in one-by-one (same idiom as the breakdown rows).
        for (var i = 0; i < badges.length; i++)
          _PhosphorReveal(delayMs: i * 140, child: _badge(_label(badges[i]))),
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
    return Wrap(
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
            fontSize: 10,
          ),
      ],
    );
  }
}

class _XpReceiptCard extends StatelessWidget {
  const _XpReceiptCard({required this.breakdown});

  final SessionXpBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('BASE', '+${breakdown.baseXP} XP'),
      ('LCK', XpService.multiplierLabel(breakdown.lckMultiplier)),
      ('POTION', XpService.multiplierLabel(breakdown.potionMultiplier)),
      if (breakdown.lootBonusXP > 0) ('CACHE', '+${breakdown.lootBonusXP} XP'),
      ('TOTAL', '+${breakdown.finalXP} XP'),
    ];
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(
                    row.$1,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: kMutedText,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    row.$2,
                    style: AppFonts.shareTechMono(
                      color: row.$1 == 'TOTAL' ? kNeon : kText,
                      fontSize: 12,
                      fontWeight: row.$1 == 'TOTAL'
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          if (!breakdown.eligibility.eligible) ...[
            const SizedBox(height: kSpace2),
            Text(
              breakdown.eligibility.reason,
              textAlign: TextAlign.center,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
          ],
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

  Color _tierColor(LootDropTier tier) => switch (tier) {
    LootDropTier.common => kText,
    LootDropTier.uncommon => kCyan,
    LootDropTier.rare => kAmber,
    LootDropTier.epic => kNeon,
  };
}

/// Demoted receipt facts — context, not reward. One thin muted line, low in the
/// hierarchy. No per-exercise calories; at most one rough total.
class _ReceiptStrip extends StatelessWidget {
  const _ReceiptStrip({
    required this.elapsedSeconds,
    required this.totalSets,
    required this.moves,
    required this.estimatedCalories,
    required this.durationLabel,
  });

  final int elapsedSeconds;
  final int totalSets;
  final int moves;
  final int estimatedCalories;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (elapsedSeconds > 0) durationLabel,
      if (totalSets > 0) '$totalSets sets',
      if (moves > 0) '$moves moves',
      if (estimatedCalories > 0) '~$estimatedCalories kcal',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('   ·   '),
      textAlign: TextAlign.center,
      style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
    );
  }
}
