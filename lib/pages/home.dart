import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../models/profile_models.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../services/idle_battle_service.dart';
import '../services/class_service.dart';
import '../services/exercise_catalog_service.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/program_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_dialog_button_column.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/arcade_tap.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/pulse_color_text.dart';
import '../widgets/screen_shake.dart';
import '../widgets/strobe_flash.dart';
import '../widgets/rest_icon.dart';
import 'Workout session/active_workout.dart';
import 'Workout session/start_workout.dart';
import 'live_dungeon_page.dart';
import 'ultimate_unlock_page.dart';

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
  DateTime? _lastWorkoutDate;
  String? _suggestedMuscle;
  String? _selectedTitle;
  int? _suggestedMissionRewardXP;
  RestDayInfo? _todayRestInfo;
  ProfileData _profile = ProfileData.defaults();
  bool _missionCompletedToday = false;
  int? _preWorkoutXP;
  int? _preWorkoutLevel;
  bool _showXPGain = false;
  int _xpGainAmount = 0;
  bool _showLevelUp = false;
  int _levelUpShakeTrigger = 0;
  int _missionFlashTrigger = 0;
  int _dungeonFloor = 1;
  bool _isRestDay = false;
  Map<LootCategory, LootItem> _equippedLoot = {};
  ProgramProgress? _programProgress;
  ProgramDay? _programDay;
  ProgramDaySnapshot? _programCompletedToday;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> reload() => _loadData();

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
          XpService.calculateTotalXP(all) + questClaimedXP + currentRecoveryXP + potionBonusXP,
      state: restState,
    );
    final recoveryXP = restService.effectiveRecoveryXPForState(
      sessions: all,
      state: restState,
    );
    final questSummary = await QuestService().getSummary(all);
    final profile = await ProfileService().loadProfile();
    final idleService = IdleBattleService();
    final dungeonFloor = await idleService.getCurrentFloor();
    final equippedLoot = await LootService().getEquippedLoot();
    final programCompletedToday = await programService
        .completedSnapshotForToday(now: today);
    final missionCompleted =
        await WorkoutStorageService.isMissionCompletedToday();
    if (!mounted) return;

    final completed = all.where((s) => !s.isPartial).toList();
    final partial = all.where((s) => s.isOngoing).toList()
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
    const muscles = ['Chest', 'Back', 'Arms', 'Legs'];
    String? suggestedMuscle;

    if (completed.isNotEmpty) {
      final vols = {for (final m in muscles) m: 0.0};
      final lastDate = <String, DateTime>{};
      for (final s in completed) {
        if (s.date.isAfter(cutoff)) {
          vols[s.muscleGroup] =
              (vols[s.muscleGroup] ?? 0) +
              s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
        }
        if (!lastDate.containsKey(s.muscleGroup) ||
            s.date.isAfter(lastDate[s.muscleGroup]!)) {
          lastDate[s.muscleGroup] = s.date;
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
      if (quest.id == 'suggested_muscle' && !quest.claimed) {
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
      _lastWorkoutDate = lastCompleted?.date;
      _suggestedMuscle = suggestedMuscle;
      _selectedTitle = questSummary.selectedTitle;
      _suggestedMissionRewardXP = suggestedMissionRewardXP;
      _todayRestInfo = todayRestInfo;
      _profile = profile;
      _missionCompletedToday = missionCompleted;
      _dungeonFloor = dungeonFloor;
      _isRestDay = todayRestInfo.isPlannedRestDay;
      _equippedLoot = equippedLoot;
      _programProgress = programProgress;
      _programDay = programDay;
      _programCompletedToday = programCompletedToday;
      _loading = false;
    });

    // Check for pending ultimate reveal.
    final ultimatePending = await ClassService().hasPendingUltimateReveal();
    if (ultimatePending && mounted) {
      Navigator.push(context, arcadeRoute((_) => const UltimateUnlockPage()));
    }
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
                  color: kBorderDark,
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
    if (!mounted) return;
    Navigator.push(
      context,
      arcadeRoute(
        (_) => ActiveWorkoutPage(
          muscleGroup: session.muscleGroup,
          durationMinutes: session.targetDurationMinutes,
          exercises: exercises,
          resumeFromSession: session,
          isProgramWorkout: isProgramWorkout,
          advanceProgramRestDayOnCompletion: isProgramRestWorkout,
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

  void _startProgramWorkout(ProgramDay day) {
    _preWorkoutXP = _totalXP;
    _preWorkoutLevel = _level;
    Navigator.push(
      context,
      arcadeRoute(
        (_) => StartWorkoutPage(
          initialMuscleGroup: programDayPrimaryMuscleGroup(day),
          programDayLabel: day.label,
          programFocusSummary: programDayFocusSummary(day),
          programCuratedExerciseIds: day.suggestedExerciseIds,
          isProgramWorkout: true,
        ),
      ),
    ).then((_) => _onReturnFromWorkout());
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
    if (_missionCompletedToday) {
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
                  color: kBorderDark,
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
    final minutes = _liveElapsedSeconds(session) ~/ 60;
    if (exerciseCount == 0 && minutes == 0) return 'Ready to continue';

    final exerciseLabel = exerciseCount == 1
        ? '1 exercise'
        : '$exerciseCount exercises';
    return '$exerciseLabel · ${_fmtDuration(session.actualDurationSeconds)}';
  }

  String? _missionRewardLabel(WorkoutSession? session) {
    if (session != null) {
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
    if (!session.isOngoing) return session.actualDurationSeconds;
    final live = DateTime.now().difference(session.startedAt).inSeconds;
    return live > session.actualDurationSeconds
        ? live
        : session.actualDurationSeconds;
  }

  String _lastWorkoutLabel() {
    final lastDate = _lastWorkoutDate;
    if (lastDate == null) return 'No completed workouts yet';

    final today = DateUtils.dateOnly(DateTime.now());
    final last = DateUtils.dateOnly(lastDate);
    final daysAgo = today.difference(last).inDays;

    if (daysAgo <= 0) return 'Last workout: Today';
    if (daysAgo == 1) return 'Last workout: Yesterday';
    return 'Last workout: $daysAgo days ago';
  }

  // ── Character bar ──────────────────────────────────────────────────────────

  Widget _buildCharacterBar() {
    final xpProgress = XpService.progressForTotalXP(_totalXP);
    final rankColor = _rankColor();
    final titleItem = _equippedTitle;
    final titleLabel = titleItem?.name ?? _selectedTitle ?? 'untitled';
    final titleColor =
        titleItem?.color ??
        (_selectedTitle == null ? const Color(0xFF6B6B8A) : kAmber);

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF121225)),
        borderRadius: BorderRadius.circular(4),
      ),
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
                  style: GoogleFonts.shareTechMono(
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
                  style: GoogleFonts.shareTechMono(
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
                ArcadeProgressBar(
                  value: xpProgress.fraction,
                  height: 10,
                  flashOnIncrease: true,
                  increaseSignal: _totalXP,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      xpProgress.label,
                      style: GoogleFonts.shareTechMono(
                        color: const Color(0xFF6B6B8A),
                        fontSize: 10,
                      ),
                    ),
                    if (_todayXP > 0) ...[
                      const Spacer(),
                      Text(
                        '+$_todayXP today',
                        style: GoogleFonts.shareTechMono(
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
        color: const Color(0xFF151529),
        border: Border.all(color: const Color(0xFF3D3A68), width: 1),
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _themedCardColor(const Color(0xFF121225)),
          borderRadius: BorderRadius.circular(4),
        ),
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
                    color: Color(0xFF555577),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_weeklyQuestCompleted / $_weeklyQuestTotal',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Color(0xFFE8E8FF),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'VIEW ALL >',
                  style: GoogleFonts.shareTechMono(
                    color: const Color(0xFF00FF9C),
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
                        color: i < _weeklyQuestCompleted
                            ? const Color(0xFF00FF9C)
                            : const Color(0xFF2A2A4A),
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

    if (session == null && _missionCompletedToday) {
      return _buildCompletedMissionPanel();
    }
    final restInfo = _todayRestInfo;
    if (session == null &&
        restInfo != null &&
        restInfo.isPlannedRestDay &&
        !restInfo.hasCompletedWorkout) {
      return _buildRecoveryMissionPanel(restInfo);
    }

    final muscle = session?.muscleGroup ?? _suggestedMuscle;
    final title = session != null
        ? '${session.muscleGroup} in progress'
        : muscle != null
        ? 'Train $muscle'
        : 'Choose your first workout';
    final detail = session != null
        ? _sessionProgressLabel(session)
        : muscle != null
        ? 'Suggested: $muscle'
        : 'Pick a muscle group and start small';
    final rewardLabel = _missionRewardLabel(session);

    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF17172C)),
        border: Border.all(color: const Color(0xFF00FF9C), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_play.png'),
                size: 14,
                color: Color(0xFF00FF9C),
              ),
              const SizedBox(width: 8),
              const Text(
                'MAIN MISSION',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: Color(0xFF00FF9C),
                ),
              ),
              if (rewardLabel != null) ...[
                const Spacer(),
                _MissionRewardChip(label: rewardLabel),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.shareTechMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE8E8FF),
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: GoogleFonts.shareTechMono(
                  color: const Color(0xFF6B6B8A),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_star.png'),
                size: 14,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(width: 8),
              Text(
                session != null
                    ? 'Pick up where you left off'
                    : 'Balance your build',
                style: GoogleFonts.shareTechMono(
                  color: const Color(0xFFFFD700),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PixelButton(
            label: session != null ? 'CONTINUE' : 'BEGIN WORKOUT!',
            color: const Color(0xFF00FF9C),
            onPressed: session == null
                ? _startWorkout
                : () => _continueWorkout(session),
          ),
        ],
      ),
    );

    if (session == null) return panel;
    return Semantics(
      label: '${session.muscleGroup} ongoing workout',
      hint: 'Long press to delete this session.',
      child: GestureDetector(
        onLongPress: () => _confirmDelete(session),
        child: panel,
      ),
    );
  }

  Widget _buildProgramMissionPanel({
    required ProgramDay day,
    required ProgramProgress progress,
  }) {
    final rewardLabel = _missionRewardLabel(null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF17172C)),
        border: Border.all(color: kNeon, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_play.png'),
                size: 14,
                color: kNeon,
              ),
              const SizedBox(width: 8),
              const Text(
                'PROGRAM DAY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kNeon,
                ),
              ),
              if (rewardLabel != null) ...[
                const Spacer(),
                _MissionRewardChip(label: rewardLabel),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'WEEK ${progress.currentWeek} - DAY ${progress.currentDayIndex + 1}',
            style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            day.label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 16,
              color: kNeon,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            programDayFocusSummary(day),
            style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          PixelButton(
            label: 'START WORKOUT',
            color: kNeon,
            onPressed: () => _startProgramWorkout(day),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _startWorkout(trainAnyway: true),
              child: const Text(
                'skip to manual',
                style: TextStyle(color: kMutedText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCompletedMissionPanel({
    required ProgramDay day,
    required int week,
    required int dayNumber,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF17172C)),
        border: Border.all(color: kMutedText, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_play.png'),
                size: 14,
                color: kNeon,
              ),
              const SizedBox(width: 8),
              const Text(
                'PROGRAM DAY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kNeon,
                ),
              ),
              const Spacer(),
              const _MissionClearedChip(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'WEEK $week - DAY $dayNumber',
            style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            day.label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 16,
              color: kMutedText,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '\u2713 CLEARED',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: kNeon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Next program day unlocks after today.',
            style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramRecoveryMissionPanel({
    required ProgramDay day,
    required ProgramProgress progress,
    required RestDayInfo restInfo,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF17172C)),
        border: Border.all(color: kCyan, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_play.png'),
                size: 14,
                color: kCyan,
              ),
              const SizedBox(width: 8),
              const Text(
                'PROGRAM REST',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kCyan,
                ),
              ),
              const Spacer(),
              _MissionRewardChip(label: '+${restInfo.recoveryXP} XP'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'WEEK ${progress.currentWeek} - DAY ${progress.currentDayIndex + 1}',
            style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            day.label,
            style: GoogleFonts.shareTechMono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kText,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stats protected. Recovery runs all day.',
            style: GoogleFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
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
                style: GoogleFonts.shareTechMono(color: kAmber, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PixelButton(
            label: 'KEEP RESTING',
            color: kCyan,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recovery day in progress.')),
              );
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _startWorkout(
                trainAnyway: false,
                advanceProgramRestDayOnCompletion: true,
              ),
              child: Text(
                'Train anyway',
                style: GoogleFonts.shareTechMono(color: kMutedText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedMissionPanel() {
    final muscle = _suggestedMuscle;
    final title = muscle != null ? 'Train $muscle' : 'Today\'s mission';
    final detail = muscle != null ? 'Suggested: $muscle' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF17172C)),
        border: Border.all(color: kMutedText, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_play.png'),
                size: 14,
                color: Color(0xFF00FF9C),
              ),
              const SizedBox(width: 8),
              const Text(
                'MAIN MISSION',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: Color(0xFF00FF9C),
                ),
              ),
              const Spacer(),
              const _MissionClearedChip(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.shareTechMono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kMutedText,
              height: 1.05,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            '\u2713 MISSION COMPLETE',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: Color(0xFF00FF9C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rest up. Tomorrow brings\na new challenge.',
            style: GoogleFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryMissionPanel(RestDayInfo restInfo) {
    final rewardLabel = '+${restInfo.recoveryXP} XP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themedCardColor(const Color(0xFF17172C)),
        border: Border.all(color: kCyan, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_play.png'),
                size: 14,
                color: kCyan,
              ),
              const SizedBox(width: 8),
              const Text(
                'RECOVERY DAY',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kCyan,
                ),
              ),
              const Spacer(),
              _MissionRewardChip(label: rewardLabel),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: RestScene(height: 68)),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recovery day',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: kText,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stats protected. Recovery runs all day.',
                      style: GoogleFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                style: GoogleFonts.shareTechMono(color: kAmber, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PixelButton(
            label: 'KEEP RESTING',
            color: kCyan,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recovery day in progress.')),
              );
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _startWorkout(trainAnyway: false),
              child: Text(
                'Train anyway',
                style: GoogleFonts.shareTechMono(color: kMutedText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryOngoingSessions() {
    final sessions = _ongoingSessions.skip(1).toList();
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'ONGOING',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: Color(0xFFFFD700),
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
      label: '${session.muscleGroup} ongoing workout',
      hint: 'Long press to delete this session.',
      child: _PressableCard(
        onLongPress: () => _confirmDelete(session),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _themedCardColor(const Color(0xFF121225)),
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
                      session.muscleGroup,
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
                        color: const Color(0xFF6B6B8A),
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

  // ── Dungeon card ─────────────────────────────────────────────────────────

  void _openDungeon() {
    Navigator.push(
      context,
      arcadeRoute((_) => const LiveDungeonPage()),
    ).then((_) => _loadData());
  }

  Widget _buildBossRewardPreview() {
    if (_dungeonFloor % 10 != 0) return const SizedBox.shrink();
    final reward = bossLootForFloor(_dungeonFloor);
    return Padding(
      padding: const EdgeInsets.only(top: kSpace2),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.shareTechMono(fontSize: 12),
          children: [
            const TextSpan(
              text: 'REWARD: ',
              style: TextStyle(color: kMutedText),
            ),
            TextSpan(
              text: '★ ${reward.name}',
              style: TextStyle(
                color: reward.rarity.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: ' (${reward.rarity.label})',
              style: TextStyle(color: reward.rarity.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDungeonCard() {
    return ArcadeTap(
      onTap: _openDungeon,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _themedCardColor(kCard),
          border: Border.all(color: _isRestDay ? kMutedText : kNeon, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ImageIcon(
                  const AssetImage('assets/icons/control/icon_sword.png'),
                  size: 14,
                  color: _isRestDay ? kMutedText : kAmber,
                ),
                const SizedBox(width: kSpace2),
                Text(
                  'DUNGEON — FLOOR $_dungeonFloor',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: _isRestDay ? kMutedText : kAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace2),
            if (_isRestDay)
              Text(
                'RESTING',
                style: GoogleFonts.shareTechMono(
                  fontSize: 12,
                  color: kMutedText,
                ),
              )
            else
              const PulseColorText(
                'FIGHTING',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8),
                colorA: kNeon,
                colorB: kNeonDark,
                periodMs: 500,
              ),
            _buildBossRewardPreview(),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  Widget _buildLastWorkoutStat() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _themedCardColor(
          const Color(0xFF121225),
        ).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const ImageIcon(
            AssetImage('assets/icons/control/icon_time.png'),
            size: 16,
            color: Color(0xFF6B6B8A),
          ),
          const SizedBox(width: 8),
          Text(
            _lastWorkoutLabel(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B6B8A),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Tracker',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF00FF9C),
              ),
            ),
            const SizedBox(height: 16),
            _buildCharacterBar(),
            const SizedBox(height: 18),
            StrobeFlash(
              trigger: _missionFlashTrigger,
              borderRadius: BorderRadius.circular(4),
              toggles: 2,
              toggleMs: 16,
              child: _buildMainMissionPanel(),
            ),
            _buildSecondaryOngoingSessions(),
            const SizedBox(height: 16),
            _buildLastWorkoutStat(),
            const SizedBox(height: 14),
            _buildWeeklyQuestsCard(),
            const SizedBox(height: 14),
            _buildDungeonCard(),
            const SizedBox(height: 24),
          ],
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
