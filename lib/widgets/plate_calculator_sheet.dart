import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';

import '../models/unit_models.dart';
import '../services/plate_calculator.dart';
import '../services/unit_settings_service.dart';
import '../theme/tokens.dart';
import 'motion/arcade_text_field.dart';
import 'motion/phosphor_tap.dart';

// Display helper for the sheet's display-unit numbers. Delegates to fmtNum so a
// unit round-trip (e.g. 150 lbs → kg → 149.99999999 lbs) reads clean. 2 decimals
// preserves the smallest fractional plate (1.25) without re-exposing FP noise.
String _fmtKg(double v) => fmtNum(v, decimals: 2);

enum _CalcMode { target, plates }

/// A plate instance on the reverse-mode bar. The id keys the widget so only
/// newly added plates animate in and equal weights stay distinguishable.
class _LoadedPlate {
  const _LoadedPlate(this.id, this.weight);

  final int id;
  final double weight;
}

/// Bottom sheet with two modes: TARGET > PLATES (given a target weight + bar
/// weight, lists the plate stack to load on ONE side of the bar) and
/// PLATES > TOTAL (tap plates onto the bar, get the total weight back).
///
/// Resolves with the reverse mode's total in canonical kg when the user taps
/// USE WEIGHT; null on any other dismissal.
class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key, this.initialTargetKg});

  /// Optional pre-fill — typically the current weight field value.
  final double? initialTargetKg;

  static Future<double?> show(BuildContext context, {double? initialTargetKg}) {
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (_) => PlateCalculatorSheet(initialTargetKg: initialTargetKg),
    );
  }

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late final TextEditingController _targetCtrl;
  late final TextEditingController _barCtrl;
  _CalcMode _mode = _CalcMode.target;

  /// Reverse-mode stack: plates loaded per side, kept sorted descending.
  final List<_LoadedPlate> _stack = [];
  int _nextPlateId = 0;

  /// Plates mid pop-off animation: excluded from the total, taps ignored,
  /// removed from [_stack] when the animation ends.
  final Set<int> _removingIds = {};

  @override
  void initState() {
    super.initState();
    // The caller passes a canonical kg value; the sheet works natively in the
    // active unit (lb plates + lb bar when imperial).
    _targetCtrl = TextEditingController(
      text: widget.initialTargetKg != null
          ? _fmtKg(kgToDisplay(widget.initialTargetKg!, Units.weight))
          : '',
    );
    _barCtrl = TextEditingController(
      text: _fmtKg(defaultBarFor(Units.weight)),
    );
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  double? _parse(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _addPlate(double plate) {
    setState(() {
      _stack
        ..add(_LoadedPlate(_nextPlateId++, plate))
        // Descending by weight; insertion order breaks ties so equal plates
        // keep a stable position.
        ..sort(
          (a, b) => a.weight != b.weight
              ? b.weight.compareTo(a.weight)
              : a.id.compareTo(b.id),
        );
    });
  }

  void _beginRemove(int id) {
    if (_removingIds.contains(id)) return;
    if (MediaQuery.of(context).disableAnimations) {
      setState(() => _stack.removeWhere((p) => p.id == id));
      return;
    }
    setState(() => _removingIds.add(id));
    Future.delayed(kMotionFast, () {
      if (!mounted) return;
      setState(() {
        _stack.removeWhere((p) => p.id == id);
        _removingIds.remove(id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final unit = Units.weight;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SafeArea(
      // Scrollable so the grown layout + keyboard never overflow on short
      // screens.
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
            const Text(
              'PLATE CALCULATOR',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kNeon,
              ),
            ),
            const SizedBox(height: kSpace3),
            _ModeToggle(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(height: kSpace3),
            _buildBody(unit, reduceMotion: reduceMotion),
          ],
        ),
      ),
    );
  }

  /// The mode bodies cross-fade with a slide in the direction of travel while
  /// AnimatedSize eases the sheet height between them. Reduced motion renders
  /// the active body directly (AnimatedSize misbehaves at zero duration).
  Widget _buildBody(WeightUnit unit, {required bool reduceMotion}) {
    final body = Column(
      key: ValueKey(_mode),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _mode == _CalcMode.target
          ? _buildTargetMode(unit)
          : _buildPlatesMode(unit, reduceMotion: reduceMotion),
    );
    if (reduceMotion) return body;
    return ClipRect(
      child: AnimatedSize(
        duration: kMotionBase,
        curve: kMotionCurve,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: kMotionBase,
          switchInCurve: kMotionCurve,
          switchOutCurve: kMotionCurve,
          transitionBuilder: (child, animation) {
            final fromLeft = child.key == const ValueKey(_CalcMode.target);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(fromLeft ? -0.06 : 0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: body,
        ),
      ),
    );
  }

  List<Widget> _buildTargetMode(WeightUnit unit) {
    final plateSet = plateSetFor(unit);
    final target = _parse(_targetCtrl.text);
    final bar = _parse(_barCtrl.text) ?? defaultBarFor(unit);
    final plates = target == null
        ? const <double>[]
        : PlateCalculator.platesPerSide(target, barKg: bar, plates: plateSet);
    final cannotLoad = target != null && target > bar && plates.isEmpty;
    final belowBar = target != null && target <= bar;
    final perSideTotal = plates.fold<double>(0, (sum, plate) => sum + plate);

    return [
      Row(
        children: [
          Expanded(
            child: _NumberField(
              label: 'TARGET',
              suffix: unit.label,
              controller: _targetCtrl,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: _NumberField(
              label: 'BAR',
              suffix: unit.label,
              controller: _barCtrl,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      const SizedBox(height: kSpace4),
      if (plates.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BarbellView(plates: plates),
            const SizedBox(height: kSpace2),
            Text(
              '${_fmtKg(perSideTotal)} ${unit.label} per side',
              textAlign: TextAlign.center,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
          ],
        )
      else if (cannotLoad)
        Text(
          'Cannot load this weight with standard plates.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
        )
      else if (belowBar)
        Text(
          'Target is at or below the bar weight.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
        )
      else
        Text(
          'Enter a target weight above the bar.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
        ),
      const SizedBox(height: kSpace4),
      FilledButton(
        onPressed: target == null
            ? null
            : () => Navigator.of(context).pop(displayToKg(target, unit)),
        child: const Text('APPLY'),
      ),
    ];
  }

  List<Widget> _buildPlatesMode(WeightUnit unit, {required bool reduceMotion}) {
    final plateSet = plateSetFor(unit);
    final bar = _parse(_barCtrl.text) ?? defaultBarFor(unit);
    // Plates animating off no longer count — the total updates on tap, not
    // when the pop-off animation finishes.
    final effective = [
      for (final p in _stack)
        if (!_removingIds.contains(p.id)) p.weight,
    ];
    final total = PlateCalculator.totalWeight(effective, barKg: bar);

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _NumberField(
              label: 'BAR',
              suffix: unit.label,
              controller: _barCtrl,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: effective.isNotEmpty
                    ? PhosphorTap(
                        onTap: () => setState(() {
                          _stack.clear();
                          _removingIds.clear();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpace2,
                            vertical: 2,
                          ),
                          child: Text(
                            'CLEAR',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: kSpace4),
      Text(
        'TAP TO ADD · PER SIDE',
        style: AppFonts.shareTechMono(
          color: kMutedText,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: kSpace2),
      Wrap(
        spacing: kSpace2,
        runSpacing: kSpace2,
        children: [
          for (final plate in plateSet)
            _PlateChip(
              label: _fmtKg(plate),
              onTap: () => _addPlate(plate),
            ),
        ],
      ),
      const SizedBox(height: kSpace3),
      _BarbellView.removable(
        entries: _stack,
        removingIds: _removingIds,
        onTapPlate: _beginRemove,
      ),
      if (effective.isNotEmpty) ...[
        const SizedBox(height: kSpace2),
        Text(
          'tap a plate to remove it',
          textAlign: TextAlign.center,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
      ],
      const SizedBox(height: kSpace4),
      // Keyed by value so each change replays the 1.12 -> 1.0 pop.
      TweenAnimationBuilder<double>(
        key: ValueKey(total),
        tween: Tween(begin: reduceMotion ? 1.0 : 1.12, end: 1.0),
        duration: reduceMotion ? Duration.zero : kMotionFast,
        curve: kMotionCurve,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'TOTAL  ',
                style: AppFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              TextSpan(
                text: _fmtKg(total),
                style: AppFonts.shareTechMono(color: kNeon, fontSize: 28),
              ),
              TextSpan(
                text: ' ${unit.label}',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 14),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: kSpace4),
      FilledButton(
        onPressed: () =>
            Navigator.of(context).pop(displayToKg(total, unit)),
        child: const Text('USE WEIGHT'),
      ),
    ];
  }
}

/// Single bordered track with a neon thumb that slides under the selected
/// mode label.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _CalcMode mode;
  final ValueChanged<_CalcMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: mode == _CalcMode.target
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: reduceMotion ? Duration.zero : kMotionPop,
            curve: kMotionCurve,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kNeon,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ModeSegmentLabel(
                  label: 'TARGET>PLATES',
                  selected: mode == _CalcMode.target,
                  reduceMotion: reduceMotion,
                  onTap: () => onChanged(_CalcMode.target),
                ),
              ),
              Expanded(
                child: _ModeSegmentLabel(
                  label: 'PLATES>TOTAL',
                  selected: mode == _CalcMode.plates,
                  reduceMotion: reduceMotion,
                  onTap: () => onChanged(_CalcMode.plates),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentLabel extends StatelessWidget {
  const _ModeSegmentLabel({
    required this.label,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PhosphorTap(
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: reduceMotion ? Duration.zero : kMotionPop,
          curve: kMotionCurve,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7,
            color: selected ? kBg : kMutedText,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PhosphorTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kNeon.withValues(alpha: 0.08),
          border: Border.all(color: kNeon),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppFonts.shareTechMono(color: kNeon, fontSize: 14),
        ),
      ),
    );
  }
}


class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.suffix,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.shareTechMono(
            color: kMutedText,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        ArcadeTextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
          ],
          style: AppFonts.shareTechMono(color: kText, fontSize: 18),
          suffixText: suffix,
          suffixStyle: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ],
    );
  }
}

class _BarbellView extends StatelessWidget {
  /// Forward mode: static, render-only (hidden while there are no plates).
  _BarbellView({required List<double> plates})
    : entries = [
        for (var i = 0; i < plates.length; i++) _LoadedPlate(i, plates[i]),
      ],
      removingIds = const {},
      onTapPlate = null;

  /// Reverse mode: always visible (bare bar when empty), plates are animated
  /// tap targets that report their entry id for removal.
  const _BarbellView.removable({
    required this.entries,
    required this.removingIds,
    required this.onTapPlate,
  });

  /// Plates per side, descending.
  final List<_LoadedPlate> entries;
  final Set<int> removingIds;
  final ValueChanged<int>? onTapPlate;

  static const double _height = 96;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && onTapPlate == null) return const SizedBox.shrink();
    final narrow = MediaQuery.of(context).size.width < 360;
    return SizedBox(
      height: _height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: _BarbellBar()),
          if (entries.isEmpty)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_GhostPlateSlot(), _BarbellSleeve(), _GhostPlateSlot()],
            )
          else if (narrow)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlateStack(
                  entries: entries,
                  removingIds: removingIds,
                  onTapPlate: onTapPlate,
                ),
                const SizedBox(width: 10),
                Text(
                  'per side',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlateStack(
                  entries: entries,
                  removingIds: removingIds,
                  onTapPlate: onTapPlate,
                  mirrored: true,
                ),
                const _BarbellSleeve(),
                _PlateStack(
                  entries: entries,
                  removingIds: removingIds,
                  onTapPlate: onTapPlate,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlateStack extends StatelessWidget {
  const _PlateStack({
    required this.entries,
    this.removingIds = const {},
    this.onTapPlate,
    this.mirrored = false,
  });

  final List<_LoadedPlate> entries;
  final Set<int> removingIds;
  final ValueChanged<int>? onTapPlate;

  /// Render in reversed order (the left half of the bar) while still
  /// reporting ids from the original [entries] list.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final ordered = mirrored ? entries.reversed.toList() : entries;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final plate in ordered)
          if (onTapPlate == null)
            _PlateVisual(weight: plate.weight)
          else
            _AnimatedPlate(
              key: ValueKey(plate.id),
              weight: plate.weight,
              removing: removingIds.contains(plate.id),
              // Slide in from the sleeve side: the mirrored (left) stack sits
              // left of the sleeve, so its plates arrive from the right.
              slideSign: mirrored ? 1 : -1,
              onTap: () => onTapPlate!(plate.id),
            ),
      ],
    );
  }
}

/// A removable plate on the reverse-mode bar: slides in from the sleeve when
/// added (scale + fade, [kMotionBase]), pops off when tapped (scale + fade
/// out, [kMotionFast] — the owner deletes the entry when that ends). Renders
/// statically under reduced motion.
class _AnimatedPlate extends StatelessWidget {
  const _AnimatedPlate({
    super.key,
    required this.weight,
    required this.removing,
    required this.slideSign,
    required this.onTap,
  });

  final double weight;
  final bool removing;

  /// +1 slides in from the right, -1 from the left.
  final double slideSign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Widget plate = _PlateVisual(weight: weight);
    if (!reduceMotion) {
      plate = AnimatedOpacity(
        opacity: removing ? 0 : 1,
        duration: kMotionFast,
        curve: kMotionCurve,
        child: AnimatedScale(
          scale: removing ? 0.5 : 1,
          duration: kMotionFast,
          curve: kMotionCurve,
          child: plate,
        ),
      );
      plate = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: kMotionBase,
        curve: kMotionCurve,
        child: plate,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(slideSign * 8 * (1 - t), 0),
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: removing ? null : onTap,
      child: Container(
        // Small plates render 8-14px wide; keep them tappable. Transparent
        // paint makes the whole hit area itself hit-testable.
        color: Colors.transparent,
        constraints: const BoxConstraints(minWidth: 24),
        height: _BarbellView._height,
        alignment: Alignment.center,
        child: plate,
      ),
    );
  }
}

class _PlateVisual extends StatelessWidget {
  const _PlateVisual({required this.weight});

  final double weight;

  @override
  Widget build(BuildContext context) {
    final fraction = (weight / plateSetFor(Units.weight).first)
        .clamp(0.0, 1.0)
        .toDouble();
    final height = 40 + (fraction * 34);
    final width = 16 + (fraction * 6);

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.12),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
      // Weight printed vertically — the bar describes itself.
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          _fmtKg(weight),
          style: AppFonts.shareTechMono(color: kNeon, fontSize: 9),
        ),
      ),
    );
  }
}

/// Dashed plate outline shown beside the sleeve when the reverse-mode bar is
/// empty — hints where plates land (and keeps the bare bar from reading as a
/// slider).
class _GhostPlateSlot extends StatelessWidget {
  const _GhostPlateSlot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: CustomPaint(
        size: Size(18, 52),
        painter: _DashedSlotPainter(),
      ),
    );
  }
}

class _DashedSlotPainter extends CustomPainter {
  const _DashedSlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = kBorder;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(4),
        ),
      );
    const dash = 4.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarbellSleeve extends StatelessWidget {
  const _BarbellSleeve();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 20,
      decoration: BoxDecoration(
        color: kBorder,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kMutedText.withValues(alpha: 0.45)),
      ),
    );
  }
}

class _BarbellBar extends StatelessWidget {
  const _BarbellBar();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BarbellBarPainter());
  }
}

class _BarbellBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barPaint = Paint()..color = kBorder;
    final scanPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final rect = Rect.fromLTWH(0, centerY - 3, size.width, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      barPaint,
    );

    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, centerY - 3),
        Offset(x, centerY + 3),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
