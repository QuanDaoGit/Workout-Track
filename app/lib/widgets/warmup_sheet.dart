import 'package:flutter/material.dart';

import '../data/muscle_groups.dart';
import '../data/warmup_routines.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// Optional general (pre-session) mobility guide: a brief, muscle-tailored RAMP
/// routine. Pure reference — unrewarded (the rewarded warm-up is the warm-up
/// *sets* logged in-session). `show` resolves `true` on dismiss; callers ignore
/// the result.
class WarmupSheet extends StatelessWidget {
  const WarmupSheet({super.key, required this.targets});

  final List<String> targets;

  static Future<bool> show(BuildContext context, {required List<String> targets}) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      builder: (_) => WarmupSheet(targets: targets),
    );
    return done ?? false;
  }

  String get _label {
    final groups = normalizeTargetMuscleGroups(targets);
    return groups.isEmpty ? 'today' : groups.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final plan = warmupPlanForTargets(targets);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          kSpace5,
          kSpace4,
          kSpace5,
          kSpace4 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.local_fire_department_sharp,
                  size: 18,
                  color: kNeon,
                ),
                SizedBox(width: kSpace2),
                Expanded(
                  child: Text(
                    'WARM-UP GUIDE',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: kNeon,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace2),
            Text(
              'Prime your $_label — better lifts, fewer tweaks.',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
            const SizedBox(height: kSpace4),
            // The routine as a single console "readout" panel — RAISE then the
            // tailored MOBILIZE block — set apart from the sheet chrome.
            Container(
              padding: const EdgeInsets.all(kSpace3),
              decoration: BoxDecoration(
                color: kBg,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StepHeader(index: 1, label: 'RAISE'),
                  const SizedBox(height: kSpace2),
                  Text(
                    plan.raise,
                    style: AppFonts.shareTechMono(color: kText, fontSize: 13),
                  ),
                  const SizedBox(height: kSpace4),
                  _StepHeader(index: 2, label: 'MOBILIZE · ${_label.toUpperCase()}'),
                  const SizedBox(height: kSpace3),
                  for (var i = 0; i < plan.drills.length; i++) ...[
                    if (i > 0) const SizedBox(height: kSpace2),
                    _DrillRow(drill: plan.drills[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: kSpace4),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('GOT IT'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$index · $label',
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
        color: kMutedText,
      ),
    );
  }
}

class _DrillRow extends StatelessWidget {
  const _DrillRow({required this.drill});

  final WarmupDrill drill;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, right: kSpace2),
          child: Icon(Icons.chevron_right_sharp, size: 14, color: kNeon),
        ),
        Expanded(
          child: Text(
            drill.name,
            style: AppFonts.shareTechMono(color: kText, fontSize: 13),
          ),
        ),
        const SizedBox(width: kSpace2),
        Text(
          drill.detail,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
      ],
    );
  }
}
