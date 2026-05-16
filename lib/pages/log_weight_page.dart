import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
import '../services/xp_boost_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_button.dart';
import 'log_weight_reward_page.dart';

class LogWeightPage extends StatefulWidget {
  const LogWeightPage({super.key});

  @override
  State<LogWeightPage> createState() => _LogWeightPageState();
}

class _LogWeightPageState extends State<LogWeightPage> {
  final _controller = TextEditingController();
  final _metricsService = BodyMetricsService();
  final _goalService = BodyGoalService();
  final _potionService = XpBoostService();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final value = double.tryParse(_controller.text.trim());
    return value != null && value > 0;
  }

  Future<void> _confirm() async {
    final kg = double.parse(_controller.text.trim());
    setState(() => _saving = true);

    // Get current goal and previous entry for direction alignment
    final goalState = await _goalService.getGoalState();
    final previousEntry = await _metricsService.getLastEntry();

    // Log the weight
    final entry = await _metricsService.logWeight(
      kg,
      currentGoal: goalState?.goal,
    );

    // Grant base XP Boost Potion (always)
    await _potionService.grantPotion();

    // Check direction-aligned bonus
    bool bonusGranted = false;
    if (goalState != null &&
        previousEntry != null &&
        BodyMetricsService.isDirectionAligned(
          entry,
          previousEntry,
          goalState.goal,
        )) {
      await _potionService.grantPotion(directionBonus: true);
      bonusGranted = true;
    }

    if (!mounted) return;

    // Navigate to reward reveal
    await Navigator.pushReplacement(
      context,
      arcadeRoute(
        (_) => LogWeightRewardPage(
          weightKg: kg,
          bonusPotionGranted: bonusGranted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LOG WEIGHT')),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          children: [
            const Spacer(),
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.shareTechMono(
                color: kText,
                fontSize: 24,
              ),
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: GoogleFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 24,
                ),
                suffixText: 'kg',
                suffixStyle: GoogleFonts.shareTechMono(
                  color: kMutedText,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: kCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: kNeon),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'morning. before food. before water.',
              style: GoogleFonts.shareTechMono(
                color: kMutedText,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            PixelButton(
              label: 'CONFIRM',
              onPressed: _isValid && !_saving ? _confirm : null,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
