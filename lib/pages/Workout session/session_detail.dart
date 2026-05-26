import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../services/stat_engine.dart';
import '../../services/xp_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../workout_page.dart' show fmtVol;

class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({super.key, required this.session});

  final WorkoutSession session;

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime date) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = session.exercises.fold<int>(
      0,
      (sum, log) => sum + log.sets.length,
    );
    final totalVolume = session.exercises.fold<double>(
      0,
      (sum, log) => sum + log.totalVolume,
    );
    final earnedXP = XpService.calculateSessionXP(session);
    final exerciseLogs = session.exercises
        .where((log) => log.sets.isNotEmpty)
        .toList();
    final statDelta = {
      for (final entry in session.statDelta.entries)
        if (entry.value > 0 && StatEngine.stats.contains(entry.key))
          entry.key: entry.value,
    };

    return Scaffold(
      appBar: AppBar(title: Text(_fmtDate(session.date))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            if (session.isAbandoned) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'ENDED EARLY - ${XpService.calculateSessionXP(session)} XP earned from time. No mission progress.',
                    style: const TextStyle(color: Color(0xFFFFD700)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                _StatBox(
                  label: 'Time',
                  value: _fmtDuration(session.actualDurationSeconds),
                ),
                const SizedBox(width: 8),
                _StatBox(label: 'Sets', value: totalSets.toString()),
                const SizedBox(width: 8),
                _StatBox(
                  label: 'Moves',
                  value: session.exercises.length.toString(),
                ),
                const SizedBox(width: 8),
                _StatBox(
                  label: 'kcal',
                  value: session.estimatedCalories.toString(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatBox(label: 'Volume', value: '${fmtVol(totalVolume)} kg'),
                const SizedBox(width: 8),
                _StatBox(label: 'XP', value: earnedXP.toString()),
              ],
            ),

            if (exerciseLogs.isNotEmpty) ...[
              if (statDelta.isNotEmpty) ...[
                const SizedBox(height: 24),
                _StatDeltaCard(delta: statDelta),
              ],
              const SizedBox(height: 24),

              Text(
                'BREAKDOWN',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              for (final log in exerciseLogs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.exerciseName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (int i = 0; i < log.sets.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      'Set ${i + 1}',
                                      style: const TextStyle(
                                        color: kMutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${log.sets[i].weight} kg',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '${log.sets[i].reps} reps',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 16, color: kBorder),
                          Text(
                            'Volume: ${log.totalVolume.toStringAsFixed(0)} kg',
                            style: const TextStyle(
                              color: Color(0xFF00FF9C),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatDeltaCard extends StatelessWidget {
  const _StatDeltaCard({required this.delta});

  final Map<String, int> delta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ImageIcon(
                  AssetImage('assets/icons/control/icon_star.png'),
                  color: kAmber,
                  size: 16,
                ),
                SizedBox(width: 8),
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final entry in delta.entries)
                  Text(
                    '+${entry.value} ${entry.key}',
                    style: AppFonts.shareTechMono(
                      color: kNeon,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF00FF9C),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
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
