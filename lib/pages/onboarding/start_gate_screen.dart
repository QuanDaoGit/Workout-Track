import 'package:flutter/material.dart';

import '../../models/character.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';

class StartGateScreen extends StatelessWidget {
  const StartGateScreen({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final result = character.calibration;
    final lines = [
      'name: ${character.name}',
      'goal: ${result.goal.name}',
      'freq: ${result.freq.name}',
      'exp: ${result.exp.name}',
      'bodyWeightKg: ${result.bodyWeightKg?.toStringAsFixed(1) ?? 'skipped'}',
      'sex: ${result.sex.name}',
      'class: ${result.clazz.name}',
      'classConfirmedAt: ${character.classConfirmedAt.toIso8601String()}',
      'selectedAvatarId: ${character.selectedAvatarId}',
      'characterName: ${character.characterName}',
      'createdAt: ${character.createdAt.toIso8601String()}',
    ];

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Start Gate')),
      body: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Text(
          lines.join('\n'),
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
