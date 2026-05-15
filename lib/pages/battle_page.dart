import 'package:flutter/material.dart';

import 'loot_chest_page.dart';
import '../services/battle_engine.dart';
import '../services/battle_scheduler.dart';
import '../widgets/arcade_route.dart';
import '../widgets/battle_display.dart';
import '../widgets/pixel_loader.dart';

class BattlePage extends StatefulWidget {
  const BattlePage({super.key, this.replay});

  /// If provided, replays a past battle instead of resolving a new one.
  final BattleResult? replay;

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  BattleResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.replay != null) {
      _result = widget.replay;
      _loading = false;
    } else {
      _resolveBattle();
    }
  }

  Future<void> _resolveBattle() async {
    final result = await BattleScheduler().resolveBattle();
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  void _onBattleComplete() {
    final result = _result!;

    if (widget.replay != null) {
      Navigator.of(context).pop();
      return;
    }

    if (result.playerWon) {
      Navigator.of(
        context,
      ).pushReplacement(arcadeRoute((_) => const LootChestPage()));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    return BattleDisplay(
      result: _result!,
      onComplete: _onBattleComplete,
      instantReplay: widget.replay != null,
    );
  }
}
