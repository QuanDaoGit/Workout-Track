import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/curated_exercises.dart';
import '../data/muscle_groups.dart';
import '../data/programs_library.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../models/profile_models.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../services/calorie_service.dart';
import '../services/exercise_catalog_service.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/program_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/workout_defaults_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_dialog_button_column.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/arcade_tap.dart';
import '../widgets/active_session_found_dialog.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/pulse_color_text.dart';
import '../widgets/screen_shake.dart';
import '../widgets/strobe_flash.dart';
import '../widgets/rest_icon.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onViewQuests, this.onViewProfile});

  final VoidCallback? onViewQuests;
  final VoidCallback? onViewProfile;

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
  String? _suggestedMuscle;
  String? _selectedTitle;
  int? _suggestedMissionRewardXP;
  RestDayInfo? _todayRestInfo;
  ProfileData _profile = ProfileData.defaults();
  MissionFinishState _missionFinishStateToday = MissionFinishState.none;
  WorkoutSession? _endedEarlyToday;
  int? _preWorkoutXP;
  int? _preWorkoutLevel;
  bool _showXPGain = false;
  int _xpGainAmount = 0;
  double _lckMultiplier = 1.0;
  bool _showLevelUp = false;
  int _levelUpShakeTrigger = 0;
  int _missionFlashTrigger = 0;
  Map<LootCategory, LootItem> _equippedLoot = {};
  ProgramProgress? _programProgress;
  ProgramDay? _programDay;
  ProgramDaySnapshot? _programCompletedToday;
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
    final programCompletedToday = await programService
        .completedSnapshotForToday(now: today);
    final missionFinishState =
        await WorkoutStorageService.missionFinishStateToday();
    if (!mounted) return;

    final completed = all.where((s) => !s.isPartial).toList();
    final lckMultiplier = XpService.lckXpMultiplier(
      XpService.lckForSessions(completed, now: DateTime.now()),
    );
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

    int? suggestedMissionRewardXP;
    for (final quest in questSummary.dailyQuests) {
      if (quest.id == 'show_up' && !quest.claimed) {
        suggestedMissionRewardXP = quest.rewardXP;
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
      _completedWorkoutToday = completedToday.isEmpty
          ? null
          : completedToday.first;
      _suggestedMuscle = suggestedMuscle;
      _selectedTitle = questSummary.selectedTitle;
      _suggestedMissionRewardXP = suggestedMissionRewardXP;
      _todayRestInfo = todayRestInfo;
      _profile = profile;
      _missionFinishStateToday = missionFinishState;
      _endedEarlyToday = endedEarlyToday.isEmpty ? null : endedEarlyToday.first;
      _equippedLoot = equippedLoot;
      _programProgress = programProgress;
      _programDay = programDay;
      _programCompletedToday = programCompletedToday;
      _lckMultiplier = lckMultiplier;
      _loading = false;
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

  Color _themedCardColor(Color fallback) {
    final theme = _equippedLoot[LootCategory.homeTheme];
    if (theme == null || theme.id == 'theme_default') return fallback;
    return Color.lerp(fallback, theme.color, 0.32) ?? fallback;
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
        color: _themedCardColor(background).withValues(alpha: backgroundAlpha),
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
    String? supportText,
    Color? supportColor,
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
          if (supportText != null && supportText.isNotEmpty) ...[
            const SizedBox(height: kSpace4),
            Row(
              children: [
                ImageIcon(
                  const AssetImage('assets/icons/control/icon_star.png'),
                  size: 14,
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
        ),
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
      ),
    ).then((_) => _onReturnFromWorkout());
  }

  Future<void> _startProgramWorkout(ProgramDay day) async {
    final targetGroups = programDayTargetMuscleGroups(day);
    final exerciseIds = day.suggestedExerciseIds.isNotEmpty
        ? day.suggestedExerciseIds
        : curatedExerciseIdsForMuscleGroups(targetGroups);
    await _launchWorkoutFromExerciseIds(
      muscleGroup: programDayPrimaryMuscleGroup(day),
      targetMuscleGroups: targetGroups,
      exerciseIds: exerciseIds,
      isProgramWorkout: true,
    );
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

    final xp = _suggestedMissionRewardXP;
    if (xp == null) return null;
    return '+$xp XP';
  }

  int _liveElapsedSeconds(WorkoutSession session) {
    return session.elapsedSecondsForDisplay(DateTime.now());
  }

  // ── Character bar ──────────────────────────────────────────────────────────

  Widget _buildCharacterBar() {
    final xpProgress = XpService.progressForTotalXP(_totalXP);
    final rankColor = _rankColor();
    final titleItem = _equippedTitle;
    final titleLabel = titleItem?.name ?? _selectedTitle ?? 'untitled';
    final titleColor =
        titleItem?.color ?? (_selectedTitle == null ? kMutedText : kAmber);

    final card = _homeCard(
      background: kCard,
      borderColor: kBorder,
      borderAlpha: 0.85,
      child: Row(
        children: [
          LootAvatarFrame(
            avatarPath: _profile.avatarPath,
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
                      _LckMultiplierBadge(multiplier: _lckMultiplier),
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

  Widget _buildRepeatLastMissionPanel(WorkoutSession session) {
    final exerciseCount = session.selectedExerciseIds.isNotEmpty
        ? session.selectedExerciseIds.length
        : session.exercises.length;
    final title = session.targetMuscleLabel.toUpperCase();
    final primaryLabel = title.length <= 12 ? 'REPEAT $title' : 'REPEAT LAST';

    return _missionCard(
      accent: kNeon,
      trailing: _MissionRewardChip(
        label: _suggestedMissionRewardXP == null
            ? '+5 XP'
            : '+$_suggestedMissionRewardXP XP',
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
      meta:
          'PROGRAM DAY  \u2022  WEEK ${progress.currentWeek} - DAY ${progress.currentDayIndex + 1}',
      title: _programMissionTitle(day),
      detail: _targetLineFromSummary(programDayFocusSummary(day)),
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
      meta: 'PROGRAM DAY  \u2022  WEEK $week - DAY $dayNumber',
      title: _programMissionTitle(day),
      titleColor: kMutedText,
      detail: _targetLineFromSummary(programDayFocusSummary(day)),
      supportText: 'Mission complete. Next program day unlocks tomorrow.',
      supportColor: kNeon,
    );
  }

  Widget _buildProgramRecoveryMissionPanel({
    required ProgramDay day,
    required ProgramProgress progress,
    required RestDayInfo restInfo,
  }) {
    return _missionCard(
      accent: kCyan,
      trailing: _MissionRewardChip(label: '+${restInfo.recoveryXP} XP'),
      meta:
          'PROGRAM REST  \u2022  WEEK ${progress.currentWeek} - DAY ${progress.currentDayIndex + 1}',
      title: _programMissionTitle(day),
      detail: 'Stats protected. Recovery runs all day.',
      middle: Row(
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
      primaryLabel: 'KEEP RESTING',
      onPrimary: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recovery day in progress.')),
        );
      },
      secondaryLabel: 'Train anyway',
      onSecondary: () => _startWorkout(
        trainAnyway: false,
        advanceProgramRestDayOnCompletion: true,
      ),
    );
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
            color: _themedCardColor(kCard),
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

    return _homeCard(
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
  }

  Widget _buildHomeHeader() {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/branding/app_logo.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Ironbit',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: kNeon,
            fontSize: 19,
            height: 1.1,
          ),
        ),
        const Spacer(),
      ],
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            kHomeHorizontalPadding,
            kSpace3,
            kHomeHorizontalPadding,
            kSpace5 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHomeHeader(),
              const SizedBox(height: kSectionGap),
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
              const SizedBox(height: kSectionGap),
              _buildLastWorkoutStat(),
              const SizedBox(height: kSectionGap),
              _buildWeeklyQuestsCard(),
              const SizedBox(height: kSpace5),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.12),
        border: Border.all(color: kAmber),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: kAmber,
        ),
      ),
    );
  }
}

class _LckMultiplierBadge extends StatelessWidget {
  const _LckMultiplierBadge({required this.multiplier});

  final double multiplier;

  @override
  Widget build(BuildContext context) {
    final label = 'x${XpService.multiplierLabel(multiplier)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.12),
        border: Border.all(color: kAmber),
        borderRadius: BorderRadius.circular(4),
      ),
      child: PulseColorText(
        label,
        style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 7),
        colorA: kAmber,
        colorB: Colors.white,
        periodMs: 1000,
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
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) => setState(() => _pressing = false),
      onTapCancel: () => setState(() => _pressing = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _pressing ? kNeon : kBorder, width: 1),
        ),
        child: widget.child,
      ),
    );
  }
}
