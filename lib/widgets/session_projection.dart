import 'package:flutter/material.dart';

import '../models/program_models.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// A live "which session lands on which day" preview for the weekday-anchored
/// schedule. Given the chosen training weekdays + the active [program], it shows
/// the program's workouts dealt onto those days in calendar order (cycling when
/// there are more training days than workouts) — the legibility win that makes
/// picking weekdays visibly drive *which* workout happens *when*.
///
/// Teaching view, not a live "today": it always starts the cycle at the
/// program's first workout, so the split reads as a stable shape the user is
/// choosing. Rest is everything else (a non-training weekday).
class SessionProjection extends StatelessWidget {
  const SessionProjection({
    super.key,
    required this.selected,
    required this.program,
  });

  final Set<int> selected;
  final Program program;

  static const _abbrev = {
    1: 'MON',
    2: 'TUE',
    3: 'WED',
    4: 'THU',
    5: 'FRI',
    6: 'SAT',
    7: 'SUN',
  };

  @override
  Widget build(BuildContext context) {
    final days = selected.toList()..sort();
    final workouts = program.workouts;
    if (days.isEmpty || workouts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: kBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR SPLIT',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kMutedText,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _ProjectionRow(
              weekday: _abbrev[days[i]] ?? '',
              session: workouts[i % workouts.length].label,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Other days · recovery holds the path.',
            style: TextStyle(color: kMutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ProjectionRow extends StatelessWidget {
  const _ProjectionRow({required this.weekday, required this.session});

  final String weekday;
  final String session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            weekday,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
        ),
        // A pixel session-pip + a short rail reads as "this day → this session".
        Container(width: 6, height: 6, color: kNeon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            session,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.shareTechMono(
              color: kNeon,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
