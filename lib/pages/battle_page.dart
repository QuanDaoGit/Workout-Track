import 'package:flutter/material.dart';

import '../services/battle_engine.dart';
import '../widgets/battle_display.dart';

/// Replay-only battle page. Always requires a [replay] result.
class BattlePage extends StatelessWidget {
  const BattlePage({super.key, required this.replay});

  final BattleResult replay;

  @override
  Widget build(BuildContext context) {
    return BattleDisplay(
      result: replay,
      onComplete: () => Navigator.of(context).pop(),
      instantReplay: true,
    );
  }
}
