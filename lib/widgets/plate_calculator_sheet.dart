import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';

import '../services/plate_calculator.dart';
import '../theme/tokens.dart';
import 'motion/arcade_text_field.dart';

String _fmtKg(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// Bottom sheet that, given a target weight + bar weight, lists the plate
/// stack to load on ONE side of the bar.
class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key, this.initialTargetKg});

  /// Optional pre-fill — typically the current weight field value.
  final double? initialTargetKg;

  static Future<void> show(BuildContext context, {double? initialTargetKg}) {
    return showModalBottomSheet<void>(
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

  @override
  void initState() {
    super.initState();
    _targetCtrl = TextEditingController(
      text: widget.initialTargetKg != null
          ? _fmtKg(widget.initialTargetKg!)
          : '',
    );
    _barCtrl = TextEditingController(
      text: _fmtKg(PlateCalculator.defaultBarKg),
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

  @override
  Widget build(BuildContext context) {
    final target = _parse(_targetCtrl.text);
    final bar = _parse(_barCtrl.text) ?? PlateCalculator.defaultBarKg;
    final plates = target == null
        ? const <double>[]
        : PlateCalculator.platesPerSide(target, barKg: bar);
    final cannotLoad = target != null && target > bar && plates.isEmpty;
    final belowBar = target != null && target <= bar;
    final perSideTotal = plates.fold<double>(0, (sum, plate) => sum + plate);

    return SafeArea(
      child: Padding(
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
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'TARGET',
                    suffix: 'kg',
                    controller: _targetCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: _NumberField(
                    label: 'BAR',
                    suffix: 'kg',
                    controller: _barCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace4),
            const Text(
              'LOAD PER SIDE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                color: kNeon,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: kSpace2),
            if (plates.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BarbellView(plates: plates),
                  const SizedBox(height: kSpace2),
                  Text(
                    '${plates.map((p) => '${_fmtKg(p)} kg').join(' + ')} = ${_fmtKg(perSideTotal)} kg per side',
                    textAlign: TextAlign.center,
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 12,
                    ),
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
          ],
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
  const _BarbellView({required this.plates});

  final List<double> plates;

  static const double _height = 96;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 360;
    return SizedBox(
      height: _height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: _BarbellBar()),
          if (narrow)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlateStack(plates: plates),
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
                _PlateStack(plates: plates.reversed.toList()),
                const _BarbellSleeve(),
                _PlateStack(plates: plates),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlateStack extends StatelessWidget {
  const _PlateStack({required this.plates});

  final List<double> plates;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [for (final plate in plates) _PlateVisual(weight: plate)],
    );
  }
}

class _PlateVisual extends StatelessWidget {
  const _PlateVisual({required this.weight});

  final double weight;

  @override
  Widget build(BuildContext context) {
    final fraction = (weight / PlateCalculator.defaultPlates.first)
        .clamp(0.0, 1.0)
        .toDouble();
    final height = 24 + (fraction * 48);
    final width = 8 + (fraction * 6);

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: kNeon.withValues(alpha: 0.12),
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
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
