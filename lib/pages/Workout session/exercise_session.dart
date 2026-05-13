import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../widgets/pixel_button.dart';
import '../../services/workout_storage_service.dart';

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

class _ExerciseSessionPageState extends State<ExerciseSessionPage>
    with SingleTickerProviderStateMixin {
  static const int _restDurationSeconds = 90;

  final List<_SetRow> _rows = [];
  final List<GlobalKey> _rowKeys = [];
  int? _flashIndex;
  List<SetEntry>? _previousSets;
  final Set<int> _lockedSets = {};
  late final AnimationController _restController;
  late final Animation<double> _restAnimation;
  bool _restActive = false;

  @override
  void initState() {
    super.initState();
    _restController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _restDurationSeconds),
    );
    _restAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_restController);
    _restController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _restActive = false);
      }
    });

    if (widget.initialSets.isNotEmpty) {
      for (final s in widget.initialSets) {
        _rows.add(
          _SetRow()
            ..weight.text = s.weight.toString()
            ..reps.text = s.reps.toString(),
        );
        _rowKeys.add(GlobalKey());
      }
    } else {
      _rows.add(_SetRow());
      _rowKeys.add(GlobalKey());
    }
    _loadPreviousSets();
  }

  Future<void> _loadPreviousSets() async {
    final sessions = await WorkoutStorageService().getSessions();
    // Sort newest first
    sessions.sort((a, b) => b.date.compareTo(a.date));
    for (final session in sessions) {
      for (final log in session.exercises) {
        if (log.exerciseId == widget.exercise.id && log.sets.isNotEmpty) {
          if (mounted) {
            setState(() => _previousSets = log.sets);
          }
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _restController.dispose();
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

  void _scrollToRow(int index) {
    final key = _rowKeys[index];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _logSet(int index) {
    final row = _rows[index];
    final w = double.tryParse(row.weight.text);
    final r = int.tryParse(row.reps.text);
    if (w == null || w <= 0 || r == null || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in weight and reps before logging')),
      );
      return;
    }
    setState(() {
      _lockedSets.add(index);
      _restActive = true;
    });
    _restController
      ..reset()
      ..forward();
  }

  void _unlockSet(int index) {
    setState(() => _lockedSets.remove(index));
  }

  void _dismissRest() {
    _restController.reset();
    setState(() => _restActive = false);
  }

  Widget _buildRestBar() {
    return GestureDetector(
      onTap: _dismissRest,
      child: AnimatedBuilder(
        animation: _restAnimation,
        builder: (context, _) => Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(0),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _restAnimation.value,
            child: Container(
              height: 6,
              color: const Color(0xFF00FF9C),
            ),
          ),
        ),
      ),
    );
  }

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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: Column(
        children: [
          if (_restActive) _buildRestBar(),
          Expanded(
            child: SingleChildScrollView(
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
                  width: 32,
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
                const SizedBox(width: 48),
              ],
            ),

            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              itemBuilder: (_, index) {
                final row = _rows[index];
                final prevSet = _previousSets != null &&
                        index < _previousSets!.length
                    ? _previousSets![index]
                    : null;
                final weightHint = prevSet != null
                    ? prevSet.weight.toString()
                    : '0';
                final repsHint = prevSet != null
                    ? prevSet.reps.toString()
                    : '0';
                final isLocked = _lockedSets.contains(index);
                return GestureDetector(
                  key: _rowKeys[index],
                  onTap: isLocked ? () => _unlockSet(index) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    color: _flashIndex == index
                        ? const Color(0xFF00FF9C).withValues(alpha: 0.25)
                        : Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: row.weight,
                              decoration: _fieldDeco(weightHint),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                              enabled: !isLocked,
                              onTap: () => _scrollToRow(index),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.reps,
                              decoration: _fieldDeco(repsHint),
                              keyboardType: TextInputType.number,
                              style: Theme.of(context).textTheme.bodyMedium,
                              enabled: !isLocked,
                              onTap: () => _scrollToRow(index),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: isLocked
                                ? const Icon(
                                    Icons.check_circle_sharp,
                                    color: Color(0xFF00FF9C),
                                    size: 20,
                                  )
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.save_sharp,
                                      color: Color(0xFFAAA8C0),
                                      size: 20,
                                    ),
                                    onPressed: () => _logSet(index),
                                  ),
                          ),
                        ],
                      ),
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
                  _rowKeys.add(GlobalKey());
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
          ),
        ],
      ),
    );
  }
}
