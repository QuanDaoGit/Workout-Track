import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/battle_engine.dart';
import '../services/idle_battle_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/arcade_tap.dart';
import '../widgets/pixel_loader.dart';
import 'battle_page.dart';

class BattleHistoryPage extends StatefulWidget {
  const BattleHistoryPage({super.key});

  @override
  State<BattleHistoryPage> createState() => _BattleHistoryPageState();
}

class _BattleHistoryPageState extends State<BattleHistoryPage> {
  List<BattleResult>? _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await IdleBattleService().getHistory();
    if (!mounted) return;
    setState(() => _history = history.reversed.toList());
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _resultLabel(BattleResult r) {
    if (r.playerWon) return 'VICTORY';
    if (r.isDraw) return 'DRAW';
    return 'DEFEATED';
  }

  Color _resultColor(BattleResult r) {
    if (r.playerWon) return kNeon;
    if (r.isDraw) return kAmber;
    return kDanger;
  }

  @override
  Widget build(BuildContext context) {
    if (_history == null) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Combat History')),
      body: _history!.isEmpty
          ? Center(
              child: Text(
                'No battles fought yet.',
                style: GoogleFonts.shareTechMono(
                  fontSize: 14,
                  color: kMutedText,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(kSpace4),
              itemCount: _history!.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: kBorder, height: 1),
              itemBuilder: (context, index) {
                final result = _history![index];
                return _buildEntry(result);
              },
            ),
    );
  }

  Widget _buildEntry(BattleResult result) {
    return ArcadeTap(
      onTap: () {
        Navigator.push(
          context,
          arcadeRoute((_) => BattlePage(replay: result)),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: kSpace3),
        child: Row(
          children: [
            const ImageIcon(
              AssetImage('assets/icons/control/icon_sword.png'),
              size: 16,
              color: kMutedText,
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Floor ${result.floor} — ${result.enemy.name}',
                    style: GoogleFonts.shareTechMono(
                      fontSize: 14,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _resultLabel(result),
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: _resultColor(result),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _fmtDate(result.timestamp),
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                color: kMutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
