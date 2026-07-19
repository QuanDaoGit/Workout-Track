import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
import '../services/haptic_service.dart';
import '../services/program_service.dart';
import '../services/ui_sound.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/pixel_button.dart';
import 'program_detail_page.dart';

class ProgramsLibraryBody extends StatefulWidget {
  const ProgramsLibraryBody({
    super.key,
    this.embedded = false,
    this.reloadToken = 0,
  });

  final bool embedded;
  final int reloadToken;

  @override
  State<ProgramsLibraryBody> createState() => _ProgramsLibraryBodyState();
}

class _ProgramsLibraryBodyState extends State<ProgramsLibraryBody> {
  final ProgramService _programService = ProgramService();
  ProgramProgress? _activeProgress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProgramsLibraryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final active = await _programService.getActiveProgress();
    if (!mounted) return;
    setState(() {
      _activeProgress = active;
      _loading = false;
    });
  }

  Future<void> _startProgram(Program program) async {
    final active = _activeProgress;
    if (active != null && active.programId != program.id) {
      final current = programById(active.programId);
      final confirmed = await _confirmSwitch(current?.name ?? 'CURRENT');
      if (confirmed != true) return;
    }

    await _programService.startProgram(program.id);
    await _load();
  }

  Future<bool?> _confirmSwitch(String currentName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SWITCH FROM $currentName?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Progress will reset. Workout history stays saved.'),
            const SizedBox(height: kSpace4),
            PixelButton(
              label: 'CONFIRM',
              haptic: HapticIntent.warning,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: kSpace2),
            PixelButton(
              label: 'CANCEL',
              secondary: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Future<void> _openDetail(Program program) async {
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => ProgramDetailPage(
          program: program,
          activeProgramId: _activeProgress?.programId,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bottomPadding = widget.embedded
        ? kSpace5
        : kSpace5 + MediaQuery.of(context).padding.bottom;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, bottomPadding),
      itemBuilder: (context, index) {
        if (index == 0 && _activeProgress != null) {
          return _ActiveProgramSummary(progress: _activeProgress!);
        }

        final programIndex = _activeProgress == null ? index : index - 1;
        final program = programsLibrary[programIndex];
        return _ProgramCard(
          program: program,
          active: _activeProgress?.programId == program.id,
          onTap: () => _openDetail(program),
          onStart: () => _startProgram(program),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: kSpace3),
      itemCount: programsLibrary.length + (_activeProgress == null ? 0 : 1),
    );
  }
}

class _ActiveProgramSummary extends StatelessWidget {
  const _ActiveProgramSummary({required this.progress});

  final ProgramProgress progress;

  @override
  Widget build(BuildContext context) {
    final program = programById(progress.programId);
    if (program == null) return const SizedBox.shrink();

    final target = program.targetSessions;
    final done = progress.arcSessions;
    final pct = target == 0 ? 0 : ((done / target) * 100).round();

    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_scroll.png'),
                color: kNeon,
                size: 20,
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.completedArc
                          ? 'PATH COMPLETE'
                          : 'ACTIVE PROGRAM',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        color: progress.completedArc ? kAmber : kMutedText,
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    Text(
                      program.name,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: kText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    Text(
                      'WEEK ${progress.currentWeek}',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniTextBadge(label: '${progress.completedSessions} DONE'),
            ],
          ),
          const SizedBox(height: kSpace3),
          Row(
            children: [
              Expanded(
                child: ArcadeBar(
                  value: target == 0 ? 0 : done / target,
                  height: 6,
                  accent: progress.completedArc ? kAmber : kNeon,
                ),
              ),
              const SizedBox(width: kSpace3),
              Text(
                '$done / $target • $pct%',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.active,
    required this.onTap,
    required this.onStart,
  });

  final Program program;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return HoldDepress(
      onTap: onTap,
      haptic: HapticIntent.selection,
      sound: UiSound.tick,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(kSpace4),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: active ? kNeon : kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: kNeon,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: kSpace2),
                _TierBadge(label: program.tier),
              ],
            ),
            const SizedBox(height: kSpace3),
            Text(
              program.description,
              style: AppFonts.shareTechMono(
                color: kText,
                fontSize: 13,
                height: 1.25,
              ),
            ),
            const SizedBox(height: kSpace3),
            _SchedulePreview(program: program),
            const SizedBox(height: kSpace4),
            PixelButton(
              label: active ? 'ACTIVE' : 'START PROGRAM',
              onPressed: active ? null : onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.replaceAll('/ADVANCED', '');
    return Container(
      key: ValueKey('program_library_tier_badge_$normalized'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.35),
        border: Border.all(color: kBorderVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        normalized,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: kMutedText,
        ),
      ),
    );
  }
}

class _MiniTextBadge extends StatelessWidget {
  const _MiniTextBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.12),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: kNeon,
        ),
      ),
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in program.weekSchedule) ...[
          Expanded(
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: day.isWorkout ? kBorderDark : kBg,
                border: Border.all(color: day.isWorkout ? kNeon : kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                programDayAbbreviation(day),
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: day.isWorkout ? kNeon : kMutedText,
                ),
              ),
            ),
          ),
          if (day.dayNumber < 7) const SizedBox(width: kSpace1),
        ],
      ],
    );
  }
}
