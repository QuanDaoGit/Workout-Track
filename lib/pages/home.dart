import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/muscle_groups.dart';
import '../data/programs_library.dart';
import '../models/adventure_models.dart';
import '../models/character_class.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../models/profile_models.dart';
import '../models/rest_models.dart';
import '../models/shadow_models.dart';
import '../models/workout_models.dart';
import '../services/adventure_service.dart';
import '../services/calorie_service.dart';
import '../services/class_service.dart';
import '../services/exercise_catalog_service.dart';
import '../services/gem_service.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/program_customization_service.dart';
import '../services/program_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/shadow_service.dart';
import '../services/stat_engine.dart';
import '../services/workout_defaults_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/adventure/adventure_card.dart';
import '../widgets/arcade_dialog_button_column.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/arcade_tap.dart';
import '../widgets/active_session_found_dialog.dart';
import '../widgets/last_session_tag.dart';
import '../widgets/lck_buff_badge.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/program_path_hud.dart';
import '../widgets/pulse_color_text.dart';
import '../widgets/radar_stat_icon.dart';
import '../widgets/screen_shake.dart';
import '../widgets/shadow/shadow_card.dart';
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

/// What the new-user FIRST QUEST mission should do when tapped.
class FirstQuestMissionPlan {
  const FirstQuestMissionPlan({
    required this.launchesProgramDay,
    required this.detail,
  });

  /// True → launch the pre-filled program Day 1; false → the blank manual
  /// picker (manual-path users, or the defensive rest-day-first case).
  final bool launchesProgramDay;
  final String detail;
}

/// Decides the FIRST QUEST mission's behavior + copy. A user who chose a program
/// in onboarding lands on Home as a new user, where FIRST QUEST is the headline;
/// it must launch their program's pre-filled Day 1, not a blank picker. Pure so
/// the routing decision is unit-testable without pumping Home.
FirstQuestMissionPlan firstQuestMissionPlan(ProgramDay? programDay) {
  final launchesProgramDay = programDay != null && programDay.isWorkout;
  return FirstQuestMissionPlan(
    launchesProgramDay: launchesProgramDay,
    detail: launchesProgramDay
        ? 'Begin Day 1 · ${programDay.label}.'
        : 'Log your first workout to begin.',
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onViewQuests,
    this.onViewProfile,
    this.onViewWorkouts,
    this.onOpenShop,
    this.onViewGuild,
  });

  final VoidCallback? onViewQuests;
  final VoidCallback? onViewProfile;

  /// Streak/LCK metric → workout history (Workout tab).
  final VoidCallback? onViewWorkouts;

  /// Gem metric → the gem store.
  final VoidCallback? onOpenShop;

  /// Shadow callout → the Guild tab (where the Shadow arena lives).
  final VoidCallback? onViewGuild;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _loading = true;
  List<WorkoutSession> _ongoingSessions = [];
  int _totalXP = 0;
  int _level = 1;
  String _rank = 'Recruit';
  int _todayXP = 0;
  int _weeklyQuestCompleted = 0;
  int _weeklyQuestTotal = 5;
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
  ProgramDaySnapshot? _programCompletedToday;
  ShadowEvaluation? _shadowEval;
  AdventureState? _adventureState;
  CharacterClass? _characterClass;
  // Single-flight guard for the on-open expedition reveal (Home can load
  // twice in quick succession: initState + the storage-change listener).
  bool _expeditionRevealInFlight = false;
  StreamSubscription<void>? _storageSubscription;

  @override
  void initState() {
    super.initState();
    _storageSubscription = WorkoutStorageService.changes.listen((_) {
      if (!mounted) return;
      setState(() => _ongoingSessions = []);
      _loadData();
    });
    _loadData();
  }

  Future<void> reload() => _loadData();

  @override
  void dispose() {
    _storageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final all = await WorkoutStorageService().getSessions();
    final restService = RestService();
    final programService = ProgramService();
    final programProgress = await programService.getActiveProgress();
    final programDay = await programService.getTodayDay();
    final today = DateUtils.dateOnly(DateTime.now());
    var restState = await restService.refreshWeeklyShieldProgress(all);
    if (programDay != null) {
      if (programDay.isWorkout) {
        restState = await restService.addProgramTrainingDate(
          today,
          state: restState,
        );
      } else {
        restState = await restService.addProgramPlannedRestDate(
          today,
          state: restState,
        );
        await programService.creditRestDayForToday(now: today);
      }
    }
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
    final shadowEval = await ShadowService().evaluate();
    final adventureState = await _loadAdventureStateSafely();
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
      _programCompletedToday = programCompletedToday;
      _shadowEval = shadowEval;
      _adventureState = adventureState;
      _characterClass = characterClass;
      _lckMultiplier = lckMultiplier;
      _lck = lck;
      _gemBalance = gemBalance;
      _vitality = vitality;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRevealExpeditionReport();
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

  Future<void> _maybeRevealExpeditionReport() async {
    if (!mounted || _expeditionRevealInFlight) return;
    if (_ongoingSessions.isNotEmpty) return; // idle-session flow first
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
            avatarSpec: _profile.avatarSpec,
            characterClass: _characterClass,
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

  Color _rankColor() {
    return switch (_rank) {
      'Legend' => kDanger,
      'Champion' => kDanger,
      'Knight' => kAmber,
      'Squire' => kNeon,
      _ => kMutedText,
    };
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
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(kCardPadding),
      decoration: BoxDecoration(
        color: background.withValues(alpha: backgroundAlpha),
        border: Border.all(
          color: borderColor.withValues(alpha: borderAlpha),
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }

  Widget _missionHeader({required Color accent, Widget? trailing}) {
    return Row(
      children: [
        ImageIcon(
          const AssetImage('assets/icons/control/icon_play.png'),
          size: 18,
          color: accent,
        ),
        const SizedBox(width: kSpace2),
        Text(
          'TODAY\'S MISSION',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: accent,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _missionCard({
    required Color accent,
    Widget? trailing,
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
      boxShadow: neonGlow(color: borderColor ?? accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _missionHeader(accent: accent, trailing: trailing),
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
            const SizedBox(height: kSpace3),
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

  LootItem? get _equippedFrame => _equippedLoot[LootCategory.avatarFrame];

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load workout exercises.')),
      );
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
    if (!trainAnyway &&
        restInfo != null &&
        restInfo.isPlannedRestDay &&
        !restInfo.hasCompletedWorkout) {
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

    // Step 1: XP gain display (ArcadeProgressBar handles fill animation)
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

  // ── Character bar ──────────────────────────────────────────────────────────

  Widget _buildCharacterBar() {
    final xpProgress = XpService.progressForTotalXP(_totalXP);
    final rankColor = _rankColor();
    final titleItem = _equippedTitle;
    final titleLabel = titleItem?.name ?? 'untitled';
    final titleColor = titleItem?.color ?? kMutedText;

    final card = _homeCard(
      background: kCard,
      borderColor: kBorder,
      borderAlpha: 0.85,
      child: Row(
        children: [
          LootAvatarFrame(
            avatarSpec: _profile.avatarSpec,
            framePath: _equippedFrame?.assetPath,
            size: 64,
            borderColor: rankColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE8E8FF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  titleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(
                    fontSize: 11,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: rankColor, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _rank.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                          color: rankColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ArcadeProgressBar(
                        value: xpProgress.fraction,
                        height: 10,
                        flashOnIncrease: true,
                        increaseSignal: _totalXP,
                      ),
                    ),
                    if (_lckMultiplier > 1.0) ...[
                      const SizedBox(width: 8),
                      LckBuffBadge(multiplier: _lckMultiplier, lck: _lck),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      xpProgress.label,
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 10,
                      ),
                    ),
                    if (_todayXP > 0) ...[
                      const Spacer(),
                      Text(
                        '+$_todayXP today',
                        style: AppFonts.shareTechMono(
                          color: const Color(0xFF00FF9C),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_showXPGain) ...[
                  const SizedBox(height: 4),
                  PulseColorText(
                    '+$_xpGainAmount XP',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                    ),
                    colorA: kAmber,
                    colorB: Colors.white,
                    periodMs: 500,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildLevelBadge(),
        ],
      ),
    );

    if (widget.onViewProfile == null) return card;
    return Semantics(
      button: true,
      label: 'Open profile guild card',
      child: ArcadeTap(
        onTap: widget.onViewProfile,
        borderRadius: BorderRadius.circular(4),
        child: card,
      ),
    );
  }

  Widget _buildLevelBadge() {
    final badge = Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorderVariant, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'LV.$_level',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: Color(0xFFE8E8FF),
              height: 1,
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScreenShake(
          trigger: _levelUpShakeTrigger,
          magnitude: 2,
          frames: 4,
          child: StrobeFlash(
            trigger: _levelUpShakeTrigger,
            color: kAmber,
            opacity: 0.3,
            borderRadius: BorderRadius.circular(4),
            child: badge,
          ),
        ),
        if (_showLevelUp) ...[
          const SizedBox(height: 4),
          const Text(
            'LEVEL UP!',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: kAmber,
            ),
          ),
        ],
      ],
    );
  }

  // ── Weekly Quests card ─────────────────────────────────────────────────────

  Widget _buildWeeklyQuestsCard() {
    return ArcadeTap(
      onTap: widget.onViewQuests,
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
                const SizedBox(width: 12),
                Text(
                  'VIEW ALL >',
                  style: AppFonts.shareTechMono(
                    color: kNeon,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (int i = 0; i < _weeklyQuestTotal; i++) ...[
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < _weeklyQuestCompleted ? kNeon : kBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i < _weeklyQuestTotal - 1) const SizedBox(width: 4),
                ],
              ],
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

    // New user (onboarded, no completed workouts) → FIRST QUEST stays the
    // featured mission until the first workout lands. An in-progress session
    // still falls through to CONTINUE below.
    if (session == null && _isNewUser) {
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
                child: ArcadeProgressBar(
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
    // Honor a program chosen in onboarding: when today is a program workout day,
    // the first quest launches the pre-filled Day 1 (identical to every other
    // Home program day) instead of a blank manual picker. Manual-path users (no
    // active program) and the defensive rest-day-first case keep the blank
    // picker — mirroring buildFirstSessionStarter's own `!day.isWorkout` guard.
    final programDay = _programDay;
    final plan = firstQuestMissionPlan(programDay);
    final VoidCallback onTap = (programDay != null && programDay.isWorkout)
        ? () => _startProgramWorkout(programDay)
        : () => _startWorkout();

    final card = _missionCard(
      accent: kNeon,
      trailing: const _MissionRewardChip(label: '+1 XP'),
      meta: 'WEEKLY QUEST',
      title: 'FIRST QUEST',
      detail: plan.detail,
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
          '${plan.detail} plus one XP, '
          'zero of one complete, tap to start workout',
      child: PhosphorTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: HoldDepress(
          onTap: onTap,
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
      trailing: rewardLabel == null
          ? null
          : _MissionRewardChip(label: rewardLabel),
      title: _programMissionTitle(day),
      detail: _targetLineFromSummary(programDayFocusSummary(day)),
      middle: _programArcMeter(progress),
      nextUp: _programNextUp(progress, todayConsumed: false),
      primaryLabel: 'START WORKOUT',
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
          : _programNextUp(_programProgress!, todayConsumed: true),
      supportText: 'Session logged.',
      supportColor: kNeon,
      supportIconPath: 'assets/icons/control/ui/icon_session_logged.png',
    );
  }

  Widget _buildProgramRecoveryMissionPanel({
    required ProgramDay day,
    required ProgramProgress progress,
    required RestDayInfo restInfo,
  }) {
    return _missionCard(
      accent: kNeon,
      trailing: _MissionRewardChip(label: '+${restInfo.recoveryXP} XP'),
      meta:
          'RECOVERY HOLDS THE PATH  \u2022  WEEK ${progress.currentWeek} - DAY ${progress.currentDayIndex + 1}',
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
      nextUp: _programNextUp(progress, todayConsumed: false),
      primaryLabel: 'KEEP RESTING',
      onPrimary: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recovery day in progress.')),
        );
      },
      secondaryLabel: 'TRAIN ANYWAY',
      onSecondary: () => _startWorkout(
        trainAnyway: false,
        advanceProgramRestDayOnCompletion: true,
      ),
    );
  }

  /// Goal-gradient meter for the active arc: a real progress bar + honest
  /// `X / N • P%` count. At arc 0 it shows the endowed "PATH SET" framing with
  /// decorative boot pips that are never counted as completed sessions.
  Widget _programArcMeter(ProgramProgress progress) {
    final program = programById(progress.programId);
    if (program == null) return const SizedBox.shrink();
    return ProgramPathHud(program: program, progress: progress, compact: true);
  }

  /// Forward `NEXT ▸ <label> · <when>` cue for the program mission cards.
  /// [todayConsumed] is true only on the completed-today panel, where
  /// `advanceDay` has already moved `currentDayIndex` onto the next slot.
  Widget? _programNextUp(
    ProgramProgress progress, {
    required bool todayConsumed,
  }) {
    final program = programById(progress.programId);
    if (program == null) return null;
    final lookahead = nextWorkoutLookahead(
      program,
      progress.currentDayIndex,
      todayConsumed: todayConsumed,
    );
    if (lookahead == null) return null;
    return _NextUpPeek(
      label: lookahead.workout.label,
      whenText: relativeWhen(lookahead.daysAway),
      focus: _targetLineFromSummary(programDayFocusSummary(lookahead.workout)),
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
          ? ArcadeProgressBar(value: 1, fillColor: kAmber, height: 6)
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
        : '${_fmtDuration(session.actualDurationSeconds)} logged';

    return _missionCard(
      accent: kAmber,
      borderColor: kAmber,
      trailing: const _MissionFinishedChip(),
      meta: 'FINISHED',
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
      accent: kCyan,
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
            color: allPaused ? kCyan : const Color(0xFFFFD700),
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
                color: Color(0xFF00FF9C),
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
                        color: Color(0xFFE8E8FF),
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

    final card = _homeCard(
      background: kCard,
      backgroundAlpha: 0.78,
      borderColor: kBorder,
      borderAlpha: 0.72,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace3,
      ),
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

    // No completed workouts yet → make the whole card a Start Workout entry.
    if (session != null) return card;
    return Semantics(
      button: true,
      label: 'No completed workouts yet, tap to start your first workout',
      child: PhosphorTap(
        onTap: _startWorkout,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: HoldDepress(
          onTap: _startWorkout,
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
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeStatusHudSliverDelegate(
                lck: _lck,
                lckMultiplier: _lckMultiplier,
                gemBalance: _gemBalance,
                vitality: _vitality,
                onLckTap: widget.onViewWorkouts,
                onGemTap: widget.onOpenShop,
                onVitTap: widget.onViewProfile,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                kHomeHorizontalPadding,
                kSectionGap,
                kHomeHorizontalPadding,
                kSpace5 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  StrobeFlash(
                    trigger: _missionFlashTrigger,
                    borderRadius: BorderRadius.circular(kCardRadius),
                    toggles: 2,
                    toggleMs: 16,
                    child: _buildMainMissionPanel(),
                  ),
                  _buildSecondaryOngoingSessions(),
                  const SizedBox(height: kSectionGap),
                  _buildCharacterBar(),
                  if (_showLastSessionDelta) ...[
                    const SizedBox(height: kSpace2),
                    LastSessionTag(
                      delta: _lastSessionDelta,
                      stats: _lastSessionStats,
                    ),
                  ],
                  if (_shadowEval != null) ...[
                    const SizedBox(height: kSectionGap),
                    ShadowCard(
                      evaluation: _shadowEval!,
                      avatarSpec: _profile.avatarSpec,
                      onTap: widget.onViewGuild,
                    ),
                  ],
                  if (_adventureState != null) ...[
                    const SizedBox(height: kSpace2),
                    AdventureCard(
                      state: _adventureState!,
                      onTap: _openAdventure,
                    ),
                  ],
                  const SizedBox(height: kSectionGap),
                  _buildLastWorkoutStat(),
                  const SizedBox(height: kSectionGap),
                  _buildWeeklyQuestsCard(),
                  const SizedBox(height: kSpace5),
                ]),
              ),
            ),
          ],
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

  static const double _maxHeight = 58;
  static const double _minHeight = 42;

  final int lck;
  final double lckMultiplier;
  final int gemBalance;
  final int vitality;
  final VoidCallback? onLckTap;
  final VoidCallback? onGemTap;
  final VoidCallback? onVitTap;

  @override
  double get maxExtent => _maxHeight;

  @override
  double get minExtent => _minHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseT = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final topInset = lerpDouble(kSpace3, 0, collapseT)!;
    final sideInset = lerpDouble(kHomeHorizontalPadding, 0, collapseT)!;
    final innerSideInset = lerpDouble(0, kHomeHorizontalPadding, collapseT)!;
    final ruleAlpha = collapseT <= 0.01
        ? 0.0
        : (0.35 + collapseT * 0.45).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(Colors.transparent, kBg, collapseT),
        border: Border(
          bottom: BorderSide(
            color: kBorder.withValues(alpha: ruleAlpha),
            width: collapseT <= 0.01 ? 0 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(sideInset, topInset, sideInset, 0),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: innerSideInset),
          child: Align(
            alignment: Alignment.topCenter,
            child: HomeStatusHud(
              lck: lck,
              lckMultiplier: lckMultiplier,
              gemBalance: gemBalance,
              vitality: vitality,
              onLckTap: onLckTap,
              onGemTap: onGemTap,
              onVitTap: onVitTap,
              collapseT: collapseT,
            ),
          ),
        ),
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
    this.collapseT = 0,
  });

  final int lck;
  final double lckMultiplier;
  final int gemBalance;
  final int vitality;
  final VoidCallback? onLckTap;
  final VoidCallback? onGemTap;
  final VoidCallback? onVitTap;
  final double collapseT;

  @override
  Widget build(BuildContext context) {
    final t = collapseT.clamp(0.0, 1.0);
    final shellAlpha = (1 - t).clamp(0.0, 1.0);
    final borderRadius = BorderRadius.circular(lerpDouble(kCardRadius, 0, t)!);
    final horizontalPadding = lerpDouble(12, 0, t)!;
    final verticalPadding = lerpDouble(7, 6, t)!;
    final brandGap = lerpDouble(16, 8, t)!;
    // Small gap; per-metric tap padding (below) supplies most of the spacing
    // and the ≥44px-wide hit area.
    final metricGap = lerpDouble(4, 2, t)!;
    final lckIconSize = lerpDouble(17, 14, t)!;
    final gemIconSize = lerpDouble(16, 14, t)!;
    final vitIconSize = lerpDouble(17, 14, t)!;
    final valueFontSize = lerpDouble(9, 7.5, t)!;
    final content = Container(
      key: const ValueKey('home_status_hud'),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: shellAlpha),
        border: Border.all(
          color: kBorder.withValues(alpha: shellAlpha),
          width: shellAlpha <= 0.01 ? 0 : 1,
        ),
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          _HomeHudBrand(collapseT: t),
          SizedBox(width: brandGap),
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
                      navHint: 'Opens your workout history',
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
  const _HomeHudBrand({required this.collapseT});

  final double collapseT;

  @override
  Widget build(BuildContext context) {
    final fontSize = lerpDouble(16, 13.5, collapseT)!;
    return Text(
      'Ironbit',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: kNeon,
        fontSize: fontSize,
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
              'assets/icons/economy/icon_gem_reward.png',
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
  const _NextUpPeek({required this.label, required this.whenText, this.focus});

  final String label;
  final String whenText;
  final String? focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ImageIcon(
              AssetImage('assets/icons/control/ui/icon_next_program.png'),
              size: 14,
              color: kNeon,
            ),
            const SizedBox(width: kSpace2),
            const Text(
              'NEXT',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kNeon,
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
        if (focus != null && focus!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              focus!,
              style: AppFonts.shareTechMono(
                color: kMutedText.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
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
