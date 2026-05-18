import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/workout_models.dart';
import '../../services/calorie_service.dart';
import '../../services/loot_service.dart';
import '../../services/program_service.dart';
import '../../services/stat_engine.dart';
import '../../services/workout_storage_service.dart';
import '../../services/xp_boost_service.dart';
import '../../services/xp_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/pulse_color_text.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';
import '../../widgets/typewriter_text.dart';

class WorkoutSummaryPage extends StatefulWidget {
  const WorkoutSummaryPage({
    super.key,
    required this.muscleGroup,
    required this.durationMinutes,
    required this.elapsedSeconds,
    required this.exerciseLogs,
    this.isPartial = false,
    this.isAbandoned = false,
    this.startedAt,
    this.resumeFromSession,
    this.isProgramWorkout = false,
    this.advanceProgramRestDayOnCompletion = false,
  });

  final String muscleGroup;
  final int durationMinutes;
  final int elapsedSeconds;
  final List<ExerciseLog> exerciseLogs;
  final bool isPartial;
  final bool isAbandoned;
  final DateTime? startedAt;
  final WorkoutSession? resumeFromSession;
  final bool isProgramWorkout;
  final bool advanceProgramRestDayOnCompletion;

  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage> {
  bool _saving = false;
  bool _saved = false;
  int _shakeTrigger = 0;
  int _potionBonusXP = 0;
  Map<String, int> _statDelta = {};
  Map<String, int> _combatStats = {};

  late final int _estimatedCalories = CalorieService.estimateCalories(
    widget.muscleGroup,
    widget.elapsedSeconds,
  );

  late final WorkoutSession _savedSession = WorkoutSession(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    date: DateTime.now(),
    startedAt: widget.startedAt,
    muscleGroup: widget.muscleGroup,
    targetDurationMinutes: widget.durationMinutes,
    actualDurationSeconds: widget.elapsedSeconds,
    exercises: widget.exerciseLogs,
    estimatedCalories: _estimatedCalories,
    isPartial: widget.isPartial,
    isAbandoned: widget.isAbandoned,
  );

  late final int _earnedXP = XpService.calculateSessionXP(_savedSession);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _shakeTrigger++);
      _saveAndExit();
    });
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _totalSets =>
      widget.exerciseLogs.fold<int>(0, (sum, log) => sum + log.sets.length);

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
      await WorkoutStorageService().replaceOngoingWithAbandoned(_savedSession);
      if (widget.resumeFromSession != null) {
        await ProgramService().clearOngoingProgramSession(
          widget.resumeFromSession!.id,
        );
      }
    } else {
      if (widget.resumeFromSession != null) {
        await WorkoutStorageService().deleteSession(
          widget.resumeFromSession!.id,
        );
      }
      await WorkoutStorageService().saveSession(_savedSession);
      _potionBonusXP = await XpBoostService().consumeForSession(_earnedXP);
      final engine = StatEngine();
      _statDelta = await engine.getLastSessionDelta();
      _combatStats = await engine.getStoredStats();
      final allSessions = await WorkoutStorageService().getSessions();
      await LootService().evaluateUnlocks(
        stats: _combatStats,
        sessions: allSessions,
      );
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
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = _totalSets;
    final exerciseLogs = widget.exerciseLogs
        .where((log) => log.sets.isNotEmpty)
        .toList();
    final statBoxes = [
      if (widget.elapsedSeconds > 0)
        _StatBox(label: 'Time', value: _fmt(widget.elapsedSeconds)),
      if (totalSets > 0) _StatBox(label: 'Sets', value: totalSets.toString()),
      if (exerciseLogs.isNotEmpty)
        _StatBox(label: 'Moves', value: exerciseLogs.length.toString()),
      if (_estimatedCalories > 0)
        _StatBox(label: 'kcal', value: _estimatedCalories.toString()),
    ];

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
          trigger: _shakeTrigger,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kSpace4),
                const ImageIcon(
                  AssetImage('assets/icons/control/icon_star.png'),
                  color: kNeon,
                  size: 72,
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
                    'Time XP only. No mission progress.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: kSpace3),
                PulseColorText(
                  '+$_earnedXP XP EARNED',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_potionBonusXP > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ImageIcon(
                        AssetImage('assets/icons/control/icon_potion.png'),
                        color: kAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$_potionBonusXP BONUS XP',
                        style: GoogleFonts.shareTechMono(
                          color: kAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                if (statBoxes.isNotEmpty)
                  Row(
                    children: [
                      for (var i = 0; i < statBoxes.length; i++) ...[
                        statBoxes[i],
                        if (i < statBoxes.length - 1)
                          const SizedBox(width: kSpace2),
                      ],
                    ],
                  ),
                if (exerciseLogs.isNotEmpty) ...[
                  if (!widget.isAbandoned && _statDelta.isNotEmpty) ...[
                    const SizedBox(height: kSpace5),
                    _StatDeltaSection(
                      delta: _statDelta,
                      currentStats: _combatStats,
                    ),
                  ],
                  const SizedBox(height: kSpace5),
                  Text(
                    'BREAKDOWN',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: kSpace3),
                  for (final log in exerciseLogs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: kSpace2),
                      child: Card(
                        child: ListTile(
                          title: Text(log.exerciseName),
                          subtitle: Text(
                            '${log.sets.length} sets - '
                            '${log.totalVolume.toStringAsFixed(0)} kg total',
                            style: const TextStyle(color: kMutedText),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/control/icon_particle.png',
                                width: 16,
                                height: 16,
                                color: kNeon,
                              ),
                              const SizedBox(width: kSpace1),
                              Text(
                                '${CalorieService.exerciseCalories(log, _estimatedCalories, widget.exerciseLogs)} calories',
                                style: const TextStyle(
                                  color: kNeon,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: kSpace5),
                FilledButton(
                  onPressed: _saved ? _goHome : null,
                  child: Text(_saving ? 'SAVING...' : 'BACK TO HOME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatDeltaSection extends StatelessWidget {
  const _StatDeltaSection({required this.delta, required this.currentStats});

  final Map<String, int> delta;
  final Map<String, int> currentStats;

  List<String> get _rankUps {
    final engine = StatEngine();
    return [
      for (final entry in delta.entries)
        if (StatEngine.volumeStats.contains(entry.key) && entry.value > 0)
          if (engine.getRank((currentStats[entry.key] ?? 0) - entry.value) !=
              engine.getRank(currentStats[entry.key] ?? 0))
            entry.key,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rankUps = _rankUps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            ImageIcon(
              AssetImage('assets/icons/control/icon_sword.png'),
              size: 16,
              color: kAmber,
            ),
            SizedBox(width: kSpace2),
            Text(
              'STAT GAINS',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpace3),
        Wrap(
          spacing: kSpace4,
          runSpacing: kSpace2,
          children: [
            for (final entry in delta.entries)
              _StatDeltaText(
                stat: entry.key,
                delta: entry.value,
                rankUp: rankUps.contains(entry.key),
              ),
          ],
        ),
        if (rankUps.isNotEmpty) ...[
          const SizedBox(height: kSpace2),
          for (final stat in rankUps)
            Text(
              'RANK UP! $stat [${StatEngine().getRank(currentStats[stat] ?? 0)}]',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kAmber,
              ),
            ),
        ],
      ],
    );
  }
}

class _StatDeltaText extends StatelessWidget {
  const _StatDeltaText({
    required this.stat,
    required this.delta,
    required this.rankUp,
  });

  final String stat;
  final int delta;
  final bool rankUp;

  @override
  Widget build(BuildContext context) {
    final color = delta > 0 ? kNeon : kMutedText;
    final statLabel = Text(
      stat,
      style: GoogleFonts.shareTechMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+$delta ',
          style: GoogleFonts.shareTechMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (rankUp)
          StrobeFlash(
            trigger: stat,
            fireOnMount: true,
            color: kAmber,
            opacity: 0.35,
            child: statLabel,
          )
        else
          statLabel,
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: kSpace4,
            horizontal: kSpace2,
          ),
          child: Column(
            children: [
              Text(
                value,
                style: GoogleFonts.shareTechMono(
                  fontSize: 18,
                  color: kNeon,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpace1),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
