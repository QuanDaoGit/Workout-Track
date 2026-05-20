import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/programs_library.dart';
import '../models/program_models.dart';
import '../services/program_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_button.dart';
import 'program_detail_page.dart';

class ProgramsLibraryPage extends StatefulWidget {
  const ProgramsLibraryPage({super.key});

  @override
  State<ProgramsLibraryPage> createState() => _ProgramsLibraryPageState();
}

class _ProgramsLibraryPageState extends State<ProgramsLibraryPage> {
  final ProgramService _programService = ProgramService();
  ProgramProgress? _activeProgress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: kSpace2),
            PixelButton(
              label: 'CANCEL',
              color: kBorderDark,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                kSpace4,
                kSpace4,
                kSpace4,
                kSpace5 + MediaQuery.of(context).padding.bottom,
              ),
              itemBuilder: (context, index) {
                final program = programsLibrary[index];
                return _ProgramCard(
                  program: program,
                  active: _activeProgress?.programId == program.id,
                  onTap: () => _openDetail(program),
                  onStart: () => _startProgram(program),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: kSpace3),
              itemCount: programsLibrary.length,
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
    final tierColor = programTierColor(program.tier);
    return InkWell(
      onTap: onTap,
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
                _TierBadge(label: program.tier, color: tierColor),
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
  const _TierBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = label.replaceAll('/ADVANCED', '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        normalized,
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 7, color: color),
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
