import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/exercise_demos.dart';
import '../../models/overload_models.dart';
import '../../models/program_models.dart';
import '../../models/unit_models.dart';
import '../../models/workout_models.dart';
import '../../services/progression_settings_service.dart';
import '../../services/progressive_overload_service.dart';
import '../../services/rest_timer_service.dart';
import '../../services/unit_settings_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/exercise_demo_cabinet.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/plate_calculator_sheet.dart';
import '../../widgets/rest_timer_bar.dart';
import '../../widgets/strobe_flash.dart';

class _SetRow {
  _SetRow()
    : weight = TextEditingController(),
      reps = TextEditingController(),
      weightFocus = FocusNode() {
    weightFocus.addListener(_snapWeightOnBlur);
  }

  final TextEditingController weight;
  final TextEditingController reps;
  final FocusNode weightFocus;

  /// Snaps a free-typed weight to the nearest 0.5 (in the active display unit)
  /// once the field loses focus, so logged loads stay gym-plausible.
  void _snapWeightOnBlur() {
    if (weightFocus.hasFocus) return;
    final raw = weight.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null) return;
    final snapped = roundToStep(v, 0.5);
    final text = fmtNum(snapped);
    if (text != weight.text) weight.text = text;
  }

  void dispose() {
    weightFocus.removeListener(_snapWeightOnBlur);
    weightFocus.dispose();
    weight.dispose();
    reps.dispose();
  }
}

/// Suggested (TRY) loads render and apply rounded to the nearest 2.5 in the
/// active display unit, so a clean stored kg never shows as e.g. `159.8 lbs`.
String _suggestedLoadText(double kg) =>
    fmtNum(roundToStep(kgToDisplay(kg, Units.weight), 2.5));

class ExerciseSessionPage extends StatefulWidget {
  const ExerciseSessionPage({
    super.key,
    required this.exercise,
    this.initialSets = const [],
    this.restSeconds = 90,
    this.prescription,
  });

  final Exercise exercise;
  final List<SetEntry> initialSets;
  final int restSeconds;

  /// Program sets × reps target for this exercise, or null for free logging.
  final SetRepScheme? prescription;

  @override
  State<ExerciseSessionPage> createState() => _ExerciseSessionPageState();
}

class _ExerciseSessionPageState extends State<ExerciseSessionPage> {
  final List<_SetRow> _rows = [];
  final List<GlobalKey> _rowKeys = [];
  final Map<int, int> _rowFlashTriggers = {};
  List<SetEntry>? _previousSets;
  final Set<int> _lockedSets = {};
  bool _plateCalcSeen = true;
  bool _progressionEnabled = false;
  OverloadSuggestion? _set1Suggestion;
  final Set<int> _prefilledRows = {};

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
            ..weight.text = weightValue(s.weight, Units.weight)
            ..reps.text = s.reps.toString(),
        );
        _rowKeys.add(GlobalKey());
      }
    } else {
      // A program prescription pre-builds its set count; manual logging starts
      // with a single row.
      final count = widget.prescription?.sets ?? 1;
      for (var i = 0; i < count; i++) {
        _rows.add(_SetRow());
        _rowKeys.add(GlobalKey());
      }
    }
    _loadOverloadService();
    _loadPlateCalcFlag();
    _loadProgressionSetting();
  }

  Future<void> _loadOverloadService() async {
    final service = ProgressiveOverloadService();
    await service.load();
    final prescription = widget.prescription;
    final suggestion = await service.suggestNext(
      widget.exercise,
      targetRepMin: prescription?.repMin,
      targetRepMax: prescription?.repMax,
    );
    if (!mounted) return;
    setState(() {
      _overloadService = service;
      _previousSets = service.getLastSessionSets(widget.exercise.id);
      _set1Suggestion = suggestion;
    });
  }

  Future<void> _loadProgressionSetting() async {
    final enabled = await ProgressionSettingsService().isEnabled();
    if (!mounted) return;
    setState(() => _progressionEnabled = enabled);
  }

  /// Applies the suggested weight + reps only after an explicit TRY tap.
  void _applySuggestionToSet1() {
    if (!_progressionEnabled) return;
    final suggestion = _set1Suggestion;
    if (suggestion == null) return;
    if (_rows.isEmpty) return;
    if (_lockedSets.contains(0)) return;
    final row = _rows[0];
    final weight = suggestion.weight;
    final reps = suggestion.reps;
    if (weight == null || reps == null) return;
    // Fill exactly what the TRY chip shows (2.5-rounded display value).
    row.weight.text = _suggestedLoadText(weight);
    row.reps.text = reps.toString();
    if (!mounted) return;
    setState(() => _prefilledRows.add(0));
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlateCalcFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('plate_calc_seen') ?? false;
    if (!mounted) return;
    setState(() => _plateCalcSeen = seen);
  }

  Future<void> _markPlateCalcSeen() async {
    if (!_plateCalcSeen && mounted) {
      setState(() => _plateCalcSeen = true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plate_calc_seen', true);
  }

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
    RestTimerService.instance.start(widget.restSeconds);
  }

  void _logSet(int index) {
    final row = _rows[index];
    // Entered in the active unit; store/compute in canonical kg.
    final w = parseWeightToKg(row.weight.text, Units.weight);
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
      if (index == 0) {
        // Linear progression: copy Set 1's load into all empty subsequent
        // rows so the user only has to enter the top set. Pyramid / dropset
        // users override by tapping into the row.
        final weightText = row.weight.text;
        final repsText = row.reps.text;
        for (int i = 1; i < _rows.length; i++) {
          if (_lockedSets.contains(i)) continue;
          final r = _rows[i];
          if (r.weight.text.isEmpty && r.reps.text.isEmpty) {
            r.weight.text = weightText;
            r.reps.text = repsText;
            _prefilledRows.add(i);
          }
        }
      }
    });
    _startRest();
  }

  void _unlockSet(int index) {
    setState(() => _lockedSets.remove(index));
  }

  void _addSet() {
    final newIndex = _rows.length;
    final newRow = _SetRow();
    // If Set 1 is logged, inherit its values into the new row (linear
    // progression). User overrides by tapping the field.
    if (_rows.isNotEmpty && _lockedSets.contains(0)) {
      newRow.weight.text = _rows[0].weight.text;
      newRow.reps.text = _rows[0].reps.text;
    }
    setState(() {
      _rows.add(newRow);
      _rowKeys.add(GlobalKey());
      _rowFlashTriggers[newIndex] = 0;
      if (newRow.weight.text.isNotEmpty || newRow.reps.text.isNotEmpty) {
        _prefilledRows.add(newIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _rowFlashTriggers[newIndex] = 1;
      });
    });
  }

  Widget _buildDeltaWidget(OverloadDelta d) {
    if (d.weightDiff == 0 && d.repsDiff == 0) return const SizedBox.shrink();
    final spans = <InlineSpan>[];
    if (d.weightDiff != 0) {
      final sign = d.weightDiff > 0 ? '+' : '';
      final color = d.weightDiff > 0 ? kNeon : kDanger;
      spans.add(
        TextSpan(
          text:
              '$sign${weightValue(d.weightDiff, Units.weight)} ${Units.weight.label}',
          style: AppFonts.shareTechMono(fontSize: 11, color: color),
        ),
      );
    }
    if (d.weightDiff != 0 && d.repsDiff != 0) {
      spans.add(
        TextSpan(
          text: ' \u00b7 ',
          style: AppFonts.shareTechMono(fontSize: 11, color: kMutedText),
        ),
      );
    }
    if (d.repsDiff != 0) {
      final sign = d.repsDiff > 0 ? '+' : '';
      final color = d.repsDiff > 0 ? kNeon : kDanger;
      spans.add(
        TextSpan(
          text: '$sign${d.repsDiff} rep${d.repsDiff.abs() == 1 ? '' : 's'}',
          style: AppFonts.shareTechMono(fontSize: 11, color: color),
        ),
      );
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
      final w = parseWeightToKg(row.weight.text, Units.weight);
      final r = int.tryParse(row.reps.text);
      if (w == null || w < 0 || r == null || r <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill in all sets before finishing')),
        );
        return;
      }
    }
    RestTimerService.instance.start(widget.restSeconds);
    Navigator.of(context).pop([
      for (final row in _rows)
        SetEntry(
          // Stored canonical in kg regardless of the entry unit.
          weight: parseWeightToKg(row.weight.text, Units.weight)!,
          reps: int.parse(row.reps.text),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const RestTimerBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpace4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exerciseDemoFor(widget.exercise.id) case final demo?)
                      ExerciseDemoCabinet(
                        demo: demo,
                        exerciseName: widget.exercise.name,
                        height: 200,
                      )
                    else
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
                                  AssetImage(
                                    'assets/icons/control/icon_sword.png',
                                  ),
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

                    if (widget.prescription != null) ...[
                      const SizedBox(height: kSpace3),
                      _PrescriptionBanner(scheme: widget.prescription!),
                    ],

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
                            'Weight (${Units.weight.label})',
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
      ),
    );
  }

  Widget _buildRow(int index) {
    final row = _rows[index];
    final prevSet = _previousSets != null && index < _previousSets!.length
        ? _previousSets![index]
        : null;
    final weightHint = prevSet != null
        ? weightValue(prevSet.weight, Units.weight)
        : '0';
    final repsHint = prevSet != null ? prevSet.reps.toString() : '0';
    final isLocked = _lockedSets.contains(index);
    final flashTrigger = _rowFlashTriggers[index] ?? 0;
    final isPrefilled = _prefilledRows.contains(index);
    final fieldStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: isPrefilled ? kMutedText : null);

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
                if (index == 0 &&
                    _progressionEnabled &&
                    _set1Suggestion != null &&
                    !isLocked)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, bottom: 4),
                    child: _TryLine(
                      suggestion: _set1Suggestion!,
                      onTap: _applySuggestionToSet1,
                    ),
                  ),
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
                      child: ArcadeTextField(
                        controller: row.weight,
                        focusNode: row.weightFocus,
                        hintText: weightHint,
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: TooltipTheme(
                            data: TooltipTheme.of(context).copyWith(
                              decoration: BoxDecoration(
                                color: kCard,
                                border: Border.all(color: kCyan),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              textStyle: AppFonts.shareTechMono(
                                color: kText,
                                fontSize: 12,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              waitDuration: const Duration(milliseconds: 400),
                              showDuration: const Duration(seconds: 2),
                            ),
                            child: IconButton(
                              tooltip: 'Plate calculator',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              icon: Image.asset(
                                'assets/icons/control/ui/icon_load_calc_pad.png',
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                              ),
                              onPressed: () async {
                                await _markPlateCalcSeen();
                                if (!mounted) return;
                                final entered = parseWeightToKg(
                                  row.weight.text,
                                  Units.weight,
                                );
                                final fallback = prevSet?.weight;
                                final resultKg =
                                    await PlateCalculatorSheet.show(
                                      context,
                                      initialTargetKg: entered ?? fallback,
                                    );
                                if (resultKg != null && mounted) {
                                  setState(() {
                                    row.weight.text = weightValue(
                                      resultKg,
                                      Units.weight,
                                    );
                                    _interactedRows.add(index);
                                    _prefilledRows.remove(index);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: fieldStyle,
                        enabled: !isLocked,
                        height: 48,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        enableEcho: false,
                        onTap: () {
                          _interactedRows.add(index);
                          _scrollToRow(index);
                          if (_prefilledRows.contains(index)) {
                            setState(() => _prefilledRows.remove(index));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: ArcadeTextField(
                        controller: row.reps,
                        hintText: repsHint,
                        keyboardType: TextInputType.number,
                        style: fieldStyle,
                        enabled: !isLocked,
                        height: 48,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        enableEcho: false,
                        onTap: () {
                          _interactedRows.add(index);
                          _scrollToRow(index);
                          if (_prefilledRows.contains(index)) {
                            setState(() => _prefilledRows.remove(index));
                          }
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
                if (prevSet != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(
                      'last: ${weightValue(prevSet.weight, Units.weight)} ${Units.weight.label} × ${prevSet.reps}',
                      style: AppFonts.shareTechMono(
                        fontSize: 11,
                        color: kMutedText,
                      ),
                    ),
                  ),
                if (index == 0 && !_plateCalcSeen)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'plate calc \u2192',
                          style: AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _markPlateCalcSeen,
                          child: const Icon(
                            Icons.close_sharp,
                            size: 12,
                            color: kMutedText,
                          ),
                        ),
                      ],
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

/// Program target banner shown above the set table: "TARGET  3 sets × 8 reps".
class _PrescriptionBanner extends StatelessWidget {
  const _PrescriptionBanner({required this.scheme});

  final SetRepScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace3,
        vertical: kSpace2,
      ),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.10),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ImageIcon(
            AssetImage('assets/icons/control/icon_target.png'),
            size: 14,
            color: kNeon,
          ),
          const SizedBox(width: kSpace2),
          const Text(
            'TARGET',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: kNeon,
            ),
          ),
          const SizedBox(width: kSpace3),
          Text(
            scheme.verboseLabel(),
            style: AppFonts.shareTechMono(color: kText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _TryLine extends StatelessWidget {
  const _TryLine({required this.suggestion, required this.onTap});

  final OverloadSuggestion suggestion;
  final VoidCallback onTap;

  Color _color() {
    switch (suggestion.reason) {
      case OverloadReason.deload:
        return kAmber;
      case OverloadReason.detrained:
        return kMutedText;
      case OverloadReason.weightIncrease:
      case OverloadReason.repTarget:
      case null:
        return kNeon.withValues(alpha: 0.7);
    }
  }

  String _suffix() {
    switch (suggestion.reason) {
      case OverloadReason.deload:
        return ' (lighter)';
      case OverloadReason.detrained:
        return ' (welcome back)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = suggestion.weight;
    final r = suggestion.reps;
    final core = w == null
        ? '—'
        : w == 0
        ? '${r ?? 0} reps'
        : '${_suggestedLoadText(w)} ${Units.weight.label} × ${r ?? 0}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: _color().withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'TRY: $core${_suffix()}',
          style: AppFonts.shareTechMono(
            fontSize: 11,
            color: _color(),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
