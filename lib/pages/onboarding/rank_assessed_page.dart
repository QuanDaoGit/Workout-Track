import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/stat_engine.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pixel_button.dart';
import '../../widgets/screen_shake.dart';
import '../../widgets/strobe_flash.dart';

/// Screen 9 — Rank Assessed. Reveals the character's calibrated stats after the
/// first workout. Binds to stat RANK (D→S), not character level. Stats come
/// from [StatEngine.calculateAllStats] (seeded by the calibration run).
class RankAssessedPage extends StatefulWidget {
  const RankAssessedPage({super.key, required this.stats});

  final Map<String, int> stats;

  @override
  State<RankAssessedPage> createState() => _RankAssessedPageState();
}

class _RankAssessedPageState extends State<RankAssessedPage> {
  final _engine = StatEngine();
  int _shake = 0;
  int _strobe = 0;
  bool _revealed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _revealed = true;
        _shake++;
        _strobe++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: ScreenShake(
          trigger: _shake,
          magnitude: 4,
          frames: 6,
          child: Padding(
            padding: const EdgeInsets.all(kSpace5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kSpace5),
                const Text(
                  'RANK ASSESSED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 16,
                    color: kAmber,
                  ),
                ),
                const SizedBox(height: kSpace2),
                Text(
                  'Your first mission set your starting rank.',
                  textAlign: TextAlign.center,
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: kSpace5),
                if (_revealed)
                  StrobeFlash(
                    trigger: _strobe,
                    fireOnMount: true,
                    color: kNeon,
                    opacity: 0.25,
                    child: Column(children: _statRows()),
                  ),
                const Spacer(),
                PixelButton(
                  label: 'ENTER',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _statRows() {
    return [
      // DEF is hidden legacy storage only (see CLAUDE.md Combat Stats) — never
      // surface it as a graded stat. The other output stats stay.
      for (final stat in StatEngine.outputStats.where((s) => s != 'DEF'))
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace3),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  stat,
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${widget.stats[stat] ?? 0}',
                  style: AppFonts.shareTechMono(color: kText, fontSize: 14),
                ),
              ),
              Text(
                _engine.getRank(widget.stats[stat] ?? 0),
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: _engine.getRankColor(widget.stats[stat] ?? 0),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
