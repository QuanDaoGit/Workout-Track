import 'package:flutter/material.dart';

import '../../models/workout_models.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(_fmtDate(session.date))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

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

            const SizedBox(height: 24),

            Text('BREAKDOWN', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),

            for (final log in session.exercises)
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
                                      color: Color(0xFF6B6B8A),
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
                        const Divider(height: 16, color: Color(0xFF2A2A4A)),
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
