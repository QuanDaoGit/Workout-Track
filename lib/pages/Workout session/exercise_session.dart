import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/overload_models.dart';
import '../../models/workout_models.dart';
import '../../services/progressive_overload_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/segmented_progress_bar.dart';
import '../../widgets/strobe_flash.dart';

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
  static const int _restCells = 6;
  static const int _restSecondsPerCell = 15;

  final List<_SetRow> _rows = [];
  final List<GlobalKey> _rowKeys = [];
  final Map<int, int> _rowFlashTriggers = {};
  List<SetEntry>? _previousSets;
  final Set<int> _lockedSets = {};
  int _restCellsRemaining = 0;
  bool _restActive = false;
  Timer? _restTimer;

  ProgressiveOverloadService? _overloadService;
  final Map<int, OverloadDelta?> _deltas = {};
  final Set<int> _prSets = {};
  final Map<int, int> _prFlashTriggers = {};
  double _sessionBest1RM = 0.0;
  final Set<int> _interactedRows = {};

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
        _rowKeys.add(GlobalKey());
      }
    } else {
      _rows.add(_SetRow());
      _rowKeys.add(GlobalKey());
    }
    _loadOverloadService();
  }

  Future<void> _loadOverloadService() async {
    final service = ProgressiveOverloadService();
    await service.load();
    if (!mounted) return;
    setState(() {
      _overloadService = service;
      _previousSets = service.getLastSessionSets(widget.exercise.id);
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kMutedText),
    filled: true,
    fillColor: kCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: kNeon),
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

  void _startRest() {
    _restTimer?.cancel();
    setState(() {
      _restActive = true;
      _restCellsRemaining = _restCells;
    });
    _restTimer = Timer.periodic(const Duration(seconds: _restSecondsPerCell), (
      t,
    ) {
      if (!mounted) return;
      if (_restCellsRemaining <= 1) {
        t.cancel();
        setState(() {
          _restActive = false;
          _restCellsRemaining = 0;
        });
        return;
      }
      setState(() => _restCellsRemaining--);
    });
  }

  void _logSet(int index) {
    final row = _rows[index];
    final w = double.tryParse(row.weight.text);
    final r = int.tryParse(row.reps.text);
    if (w == null || w < 0 || r == null || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in weight and reps before logging')),
      );
      return;
    }

    OverloadDelta? delta;
    bool isPR = false;
    final svc = _overloadService;
    if (svc != null) {
      delta = svc.getDelta(widget.exercise.id, index, w, r);
      final isBodyweight = w == 0;
      if (svc.checkPR(widget.exercise.id, w, r, isBodyweight)) {
        final rm = ProgressiveOverloadService.epley1RM(w, r, isBodyweight);
        if (rm > _sessionBest1RM) {
          isPR = true;
          _sessionBest1RM = rm;
        }
      }
    }

    setState(() {
      _lockedSets.add(index);
      _deltas[index] = delta;
      if (isPR) {
        _prSets.add(index);
        _prFlashTriggers[index] = (_prFlashTriggers[index] ?? 0) + 1;
      }
    });
    _startRest();
  }

  void _unlockSet(int index) {
    setState(() => _lockedSets.remove(index));
  }

  void _dismissRest() {
    _restTimer?.cancel();
    setState(() {
      _restActive = false;
      _restCellsRemaining = 0;
    });
  }

  void _addSet() {
    final newIndex = _rows.length;
    setState(() {
      _rows.add(_SetRow());
      _rowKeys.add(GlobalKey());
      _rowFlashTriggers[newIndex] = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _rowFlashTriggers[newIndex] = 1;
      });
    });
  }

  Widget _buildRestBar() {
    return GestureDetector(
      onTap: _dismissRest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: SegmentedProgressBar(
          totalCells: _restCells,
          litCells: _restCellsRemaining,
          height: 8,
        ),
      ),
    );
  }

  String _fmtWeight(double w) {
    return w == w.roundToDouble() ? w.toInt().toString() : w.toString();
  }

  String _suggestionText(OverloadSuggestion s) {
    if (s.weight == null && s.reps != null) return '\u2191 +1 rep';
    if (s.weight != null && s.reps != null) {
      return '\u2191 ${_fmtWeight(s.weight!)} kg \u00b7 ${s.reps} reps';
    }
    return '';
  }

  Widget _buildDeltaWidget(OverloadDelta d) {
    if (d.weightDiff == 0 && d.repsDiff == 0) return const SizedBox.shrink();
    final spans = <InlineSpan>[];
    if (d.weightDiff != 0) {
      final sign = d.weightDiff > 0 ? '+' : '';
      final color = d.weightDiff > 0 ? kNeon : kDanger;
      spans.add(TextSpan(
        text: '$sign${_fmtWeight(d.weightDiff)} kg',
        style: GoogleFonts.shareTechMono(fontSize: 11, color: color),
      ));
    }
    if (d.weightDiff != 0 && d.repsDiff != 0) {
      spans.add(TextSpan(
        text: ' \u00b7 ',
        style: GoogleFonts.shareTechMono(fontSize: 11, color: kMutedText),
      ));
    }
    if (d.repsDiff != 0) {
      final sign = d.repsDiff > 0 ? '+' : '';
      final color = d.repsDiff > 0 ? kNeon : kDanger;
      spans.add(TextSpan(
        text: '$sign${d.repsDiff} rep${d.repsDiff.abs() == 1 ? '' : 's'}',
        style: GoogleFonts.shareTechMono(fontSize: 11, color: color),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildPRBadge(int index) {
    final trigger = _prFlashTriggers[index] ?? 0;
    return StrobeFlash(
      trigger: trigger,
      color: kAmber,
      toggles: 3,
      toggleMs: 80,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kAmber.withValues(alpha: 0.15),
          border: Border.all(color: kAmber),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'PR',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: kAmber,
          ),
        ),
      ),
    );
  }

  void _finish() {
    for (final row in _rows) {
      final w = double.tryParse(row.weight.text);
      final r = int.tryParse(row.reps.text);
      if (w == null || w < 0 || r == null || r <= 0) {
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
              padding: const EdgeInsets.all(kSpace4),
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
                          color: kCard,
                          child: Center(
                            child: ImageIcon(
                              AssetImage('assets/icons/control/icon_sword.png'),
                              color: kBorder,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: kSpace4),

                  Text(
                    widget.exercise.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: kSpace1),
                  Text(
                    widget.exercise.levelLabel,
                    style: const TextStyle(color: kMutedText),
                  ),

                  const SizedBox(height: kSpace5),

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
                      const SizedBox(width: kSpace2),
                      Expanded(
                        child: Text(
                          'Reps',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),

                  const SizedBox(height: kSpace2),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rows.length,
                    itemBuilder: (_, index) => _buildRow(index),
                  ),

                  const SizedBox(height: kSpace2),

                  SizedBox(
                    width: 132,
                    child: FilledButton(
                      onPressed: _addSet,
                      style: FilledButton.styleFrom(
                        backgroundColor: kCard,
                        foregroundColor: kNeon,
                        side: const BorderSide(color: kNeon),
                      ),
                      child: const Text('+ ADD SET'),
                    ),
                  ),

                  const SizedBox(height: kSpace5),

                  PixelButton(label: 'Finish Exercise', onPressed: _finish),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index) {
    final row = _rows[index];
    final prevSet = _previousSets != null && index < _previousSets!.length
        ? _previousSets![index]
        : null;
    final weightHint = prevSet != null ? prevSet.weight.toString() : '0';
    final repsHint = prevSet != null ? prevSet.reps.toString() : '0';
    final isLocked = _lockedSets.contains(index);
    final flashTrigger = _rowFlashTriggers[index] ?? 0;

    final svc = _overloadService;
    final isBodyweight = prevSet != null && prevSet.weight == 0;
    final suggestion = svc?.getSuggestion(
      widget.exercise.id,
      index,
      isBodyweight,
    );
    final showSuggestion = suggestion != null &&
        !isLocked &&
        !_interactedRows.contains(index) &&
        row.weight.text.isEmpty &&
        row.reps.text.isEmpty;

    final delta = _deltas[index];
    final hasPR = _prSets.contains(index);

    return Padding(
      key: _rowKeys[index],
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: StrobeFlash(
        trigger: flashTrigger,
        borderRadius: BorderRadius.circular(4),
        child: GestureDetector(
          onTap: isLocked ? () => _unlockSet(index) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace2,
              vertical: 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        onTap: () {
                          _interactedRows.add(index);
                          _scrollToRow(index);
                        },
                      ),
                    ),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: TextField(
                        controller: row.reps,
                        decoration: _fieldDeco(repsHint),
                        keyboardType: TextInputType.number,
                        style: Theme.of(context).textTheme.bodyMedium,
                        enabled: !isLocked,
                        onTap: () {
                          _interactedRows.add(index);
                          _scrollToRow(index);
                        },
                      ),
                    ),
                    const SizedBox(width: kSpace2),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: isLocked
                          ? const Icon(
                              Icons.check_circle_sharp,
                              color: kNeon,
                              size: 20,
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.save_sharp,
                                color: Color(0xFFAAA8C0),
                                size: 22,
                              ),
                              onPressed: () => _logSet(index),
                            ),
                    ),
                  ],
                ),
                if (showSuggestion)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      _suggestionText(suggestion),
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        color: kMutedText,
                      ),
                    ),
                  ),
                if (isLocked && (delta != null || hasPR))
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Row(
                      children: [
                        if (hasPR) ...[
                          _buildPRBadge(index),
                          const SizedBox(width: kSpace2),
                        ],
                        if (delta != null) _buildDeltaWidget(delta),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
