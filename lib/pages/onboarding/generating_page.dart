import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pixel_loader.dart';

/// Screen 6 — Generating beat. An honest ≤3s pause that assembles the
/// character shell (class, sigil, frame) from prior choices, making the reveal
/// feel earned. No stats are computed here — those come from the first workout.
class GeneratingView extends StatefulWidget {
  const GeneratingView({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<GeneratingView> {
  static const _flavor = [
    'ASSIGNING RANK...',
    'FORGING SIGIL...',
    'BINDING CLASS...',
  ];
  int _line = 0;
  Timer? _flavorTimer;
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    _flavorTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      setState(() => _line = (_line + 1) % _flavor.length);
    });
    // Hard cap at the 3s ethics threshold for honest theater.
    _doneTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _flavorTimer?.cancel();
    _doneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kSpace5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const PixelLoader(size: 56),
          const SizedBox(height: kSpace5),
          const Text(
            'GENERATING\nYOUR CHARACTER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: kNeon,
              height: 2.0,
            ),
          ),
          const SizedBox(height: kSpace4),
          Text(
            _flavor[_line],
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
