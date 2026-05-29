import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_profile_sex.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/arcade_chip.dart';
import '../../widgets/motion/arcade_text_field.dart';
import '../../widgets/pixel_button.dart';

/// Screen 4 — Calibration Data. Collects the two values strength math needs:
/// bodyweight (skippable) and sex. Kept distinct from weekly body-metrics
/// tracking; used once to calibrate the first workout's rank.
class CalibrationDataView extends StatefulWidget {
  const CalibrationDataView({super.key, required this.onSubmit});

  final void Function(double? bodyweightKg, UserProfileSex sex) onSubmit;

  @override
  State<CalibrationDataView> createState() => _CalibrationDataViewState();
}

class _CalibrationDataViewState extends State<CalibrationDataView> {
  final _weightController = TextEditingController();
  UserProfileSex _sex = UserProfileSex.preferNotToSay;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _weightController.text.trim();
    final parsed = double.tryParse(raw);
    final bw = (parsed != null && parsed > 0) ? parsed : null;
    widget.onSubmit(bw, _sex);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kSpace5,
        kSpace5,
        kSpace5,
        kSpace4 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: kSpace4),
          const Text(
            'TWO STATS TO\nCALIBRATE YOUR\nCHARACTER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: kNeon,
              height: 2.0,
            ),
          ),
          const SizedBox(height: kSpace5),
          Text(
            'BODYWEIGHT (KG)',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: kSpace2),
          ArcadeTextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: AppFonts.shareTechMono(color: kText, fontSize: 16),
            hintText: 'e.g. 75',
          ),
          const SizedBox(height: kSpace1),
          Text(
            'Used once to set your rank — not stored for tracking. '
            'Skip and we calibrate conservatively.',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const SizedBox(height: kSpace5),
          Text(
            'SEX',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: [
              for (final s in UserProfileSex.values)
                ArcadeChip(
                  label: s.label,
                  selected: _sex == s,
                  onTap: () => setState(() => _sex = s),
                ),
            ],
          ),
          const Spacer(),
          PixelButton(label: 'CONTINUE', onPressed: _submit),
        ],
      ),
    );
  }
}
