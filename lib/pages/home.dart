import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/profile_models.dart';
import '../models/workout_models.dart';
import '../services/profile_service.dart';
import '../services/quest_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_service.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import 'Workout session/active_workout.dart';
import 'Workout session/start_workout.dart';

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
  int _streak = 0;
  int _todayXP = 0;
  int _weeklyQuestCompleted = 0;
  int _weeklyQuestTotal = 5;
  DateTime? _lastWorkoutDate;
  String? _suggestedMuscle;
  String? _selectedTitle;
  int? _suggestedMissionRewardXP;
  ProfileData _profile = ProfileData.defaults();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final all = await WorkoutStorageService().getSessions();
    final questSummary = await QuestService().getSummary(all);
    final profile = await ProfileService().loadProfile();
    if (!mounted) return;

    final completed = all.where((s) => !s.isPartial).toList();
    final partial = all.where((s) => s.isPartial).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final lastCompleted = completed.isEmpty
        ? null
        : completed.reduce((a, b) => a.date.isAfter(b.date) ? a : b);

    final totalXP =
        XpService.calculateTotalXP(all) + questSummary.claimedRewardXP;
    final level = XpService.getLevel(totalXP);
    final rank = XpService.getRank(level);
    final streak = XpService.calculateStreak(all);

    final today = DateUtils.dateOnly(DateTime.now());
    final todayXP =
        all
            .where((s) => !s.isPartial && DateUtils.dateOnly(s.date) == today)
            .fold(0, (sum, s) => sum + XpService.calculateSessionXP(s)) +
        questSummary.todayClaimedXP;

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
      _streak = streak;
      _todayXP = todayXP;
      _weeklyQuestCompleted = questSummary.weeklyCompleted;
      _weeklyQuestTotal = questSummary.weeklyTotal;
      _lastWorkoutDate = lastCompleted?.date;
      _suggestedMuscle = suggestedMuscle;
      _selectedTitle = questSummary.selectedTitle;
      _suggestedMissionRewardXP = suggestedMissionRewardXP;
      _profile = profile;
      _loading = false;
    });
  }

  Color _rankColor() {
    return switch (_rank) {
      'Legend' => const Color(0xFFFF2D55),
      'Champion' => const Color(0xFFFF2D55),
      'Knight' => const Color(0xFFFFD700),
      'Squire' => const Color(0xFF00FF9C),
      _ => const Color(0xFF6B6B8A),
    };
  }

  void _confirmDelete(WorkoutSession session) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          PixelButton(
            label: 'Delete',
            fullWidth: false,
            color: const Color(0xFFFF2D55),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await WorkoutStorageService().deleteSession(session.id);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _continueWorkout(WorkoutSession session) async {
    final jsonStr = await rootBundle.loadString('assets/exercises.json');
    final data = jsonDecode(jsonStr) as List<dynamic>;
    final catalog = [
      for (final e in data) Exercise.fromJson(e as Map<String, dynamic>),
    ];
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutPage(
          muscleGroup: session.muscleGroup,
          durationMinutes: session.targetDurationMinutes,
          exercises: exercises,
          resumeFromSession: session,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _startWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StartWorkoutPage()),
    ).then((_) => _loadData());
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    return '$m min';
  }

  String _sessionProgressLabel(WorkoutSession session) {
    final exerciseCount = session.exercises.length;
    final minutes = session.actualDurationSeconds ~/ 60;
    if (exerciseCount == 0 && minutes == 0) return 'Ready to continue';

    final exerciseLabel = exerciseCount == 1
        ? '1 exercise'
        : '$exerciseCount exercises';
    return '$exerciseLabel · ${_fmtDuration(session.actualDurationSeconds)}';
  }

  String? _missionRewardLabel(WorkoutSession? session) {
    if (session != null) {
      final emptySession =
          session.exercises.isEmpty && session.actualDurationSeconds == 0;
      final xp = emptySession ? 0 : XpService.calculateSessionXP(session);
      return '+$xp XP';
    }

    final xp = _suggestedMissionRewardXP;
    if (xp == null) return null;
    return '+$xp XP';
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
    final xpBase = XpService.xpForCurrentLevel(_level);
    final xpNext = XpService.xpForNextLevel(_level);
    final xpFraction = xpNext > xpBase
        ? ((_totalXP - xpBase) / (xpNext - xpBase)).clamp(0.0, 1.0)
        : 1.0;
    final rankColor = _rankColor();

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121225),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border.all(color: rankColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Image.asset(
              _profile.avatarPath,
              filterQuality: FilterQuality.none,
            ),
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
                  style: const TextStyle(
                    fontFamily: 'ShareTechMono',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8E8FF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _rank,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: Colors.white,
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
                    if (_selectedTitle != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTitle!.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 7,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpFraction,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF2A2A4A),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00FF9C),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '$_totalXP / $xpNext XP',
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
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildLevelStreakBadge(),
        ],
      ),
    );

    if (widget.onViewProfile == null) return card;
    return Semantics(
      button: true,
      label: 'Open profile guild card',
      child: InkWell(
        onTap: widget.onViewProfile,
        borderRadius: BorderRadius.circular(4),
        child: card,
      ),
    );
  }

  Widget _buildLevelStreakBadge() {
    return Container(
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
          Container(
            width: 1,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color(0xFF4A4778),
          ),
          const ImageIcon(
            AssetImage('assets/icons/control/icon_star.png'),
            size: 12,
            color: Color(0xFFFFD700),
          ),
          const SizedBox(width: 3),
          Text(
            '$_streak',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: Color(0xFFFFD700),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Quests card ─────────────────────────────────────────────────────

  Widget _buildWeeklyQuestsCard() {
    return InkWell(
      onTap: widget.onViewQuests,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121225),
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
        color: const Color(0xFF17172C),
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
          const SizedBox(height: 6),
          Container(width: 72, height: 2, color: const Color(0xFF00FF9C)),
          const SizedBox(height: 18),
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
            color: const Color(0xFF121225),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  Widget _buildLastWorkoutStat() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121225).withValues(alpha: 0.72),
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
            _buildMainMissionPanel(),
            _buildSecondaryOngoingSessions(),
            const SizedBox(height: 16),
            _buildLastWorkoutStat(),
            const SizedBox(height: 14),
            _buildWeeklyQuestsCard(),
            const SizedBox(height: 24),
          ],
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
        color: const Color(0xFFFFD700).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFFFD700)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: Color(0xFFFFD700),
        ),
      ),
    );
  }
}

// ── Pressable card (unchanged) ─────────────────────────────────────────────

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
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) => setState(() => _pressing = false),
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _pressing
                  ? const Color(0xFF00FF9C)
                  : const Color(0xFF2A2A4A),
              width: _pressing ? 1.5 : 0.5,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
