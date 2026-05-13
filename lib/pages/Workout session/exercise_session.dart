import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../widgets/pixel_button.dart';

class _SetRow {
  _SetRow() : weight = TextEditingController(), reps = TextEditingController();

  final TextEditingController weight;
  final TextEditingController reps;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class ExerciseSessionPage extends StatefulWidget {
  const ExerciseSessionPage({
    super.key,
    required this.exercise,
    this.initialSets = const [],
  });

  final Exercise exercise;
  final List<SetEntry> initialSets;

  @override
  State<ExerciseSessionPage> createState() => _ExerciseSessionPageState();
}

class _ExerciseSessionPageState extends State<ExerciseSessionPage> {
  final List<_SetRow> _rows = [];
  int? _flashIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialSets.isNotEmpty) {
      for (final s in widget.initialSets) {
        _rows.add(
          _SetRow()
            ..weight.text = s.weight.toString()
            ..reps.text = s.reps.toString(),
        );
      }
    } else {
      _rows.add(_SetRow());
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF6B6B8A)),
    filled: true,
    fillColor: const Color(0xFF1A1A2E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF00FF9C)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  );

  void _finish() {
    for (final row in _rows) {
      final w = double.tryParse(row.weight.text);
      final r = int.tryParse(row.reps.text);
      if (w == null || w <= 0 || r == null || r <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill in all sets before finishing')),
        );
        return;
      }
    }
    Navigator.of(context).pop([
      for (final row in _rows)
        SetEntry(
          weight: double.parse(row.weight.text),
          reps: int.parse(row.reps.text),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.asset(
                  widget.exercise.imageAssetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFF1A1A2E),
                    child: Center(
                      child: ImageIcon(
                        AssetImage('assets/icons/control/icon_sword.png'),
                        color: Color(0xFF2A2A4A),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              widget.exercise.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              widget.exercise.levelLabel,
              style: const TextStyle(color: Color(0xFF6B6B8A)),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    'Set',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Weight (kg)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reps',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              itemBuilder: (_, index) {
                final row = _rows[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  color: _flashIndex == index
                      ? const Color(0xFF00FF9C).withValues(alpha: 0.25)
                      : Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: row.weight,
                            decoration: _fieldDeco('0'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.reps,
                            decoration: _fieldDeco('0'),
                            keyboardType: TextInputType.number,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: () {
                final newIndex = _rows.length;
                setState(() {
                  _rows.add(_SetRow());
                  _flashIndex = newIndex;
                });
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) setState(() => _flashIndex = null);
                });
              },
              child: const Text('+ Add Set'),
            ),

            const SizedBox(height: 24),

            PixelButton(
              label: 'Finish Exercise',
              onPressed: _finish,
            ),
          ],
        ),
      ),
    );
  }
}
