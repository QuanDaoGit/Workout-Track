import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/unit_models.dart';
import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
import '../services/unit_settings_service.dart';
import '../services/xp_boost_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/motion/arcade_text_field.dart';
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
    // Parse in the active unit; bound to a plausible bodyweight (canonical kg)
    // so a fat-finger value (e.g. 9999) can't be saved and wreck the chart.
    final kg = parseWeightToKg(_controller.text, Units.weight);
    return kg != null && isPlausibleWeightKg(kg);
  }

  Future<void> _confirm() async {
    // Entered in the active unit; persist canonical kg.
    final kg = parseWeightToKg(_controller.text, Units.weight);
    if (kg == null || !isPlausibleWeightKg(kg)) return;
    setState(() => _saving = true);

    // Snapshot the goal onto the entry; logging itself is always allowed.
    final goalState = await _goalService.getGoalState();
    await _metricsService.logWeight(kg, currentGoal: goalState?.goal);

    // One weekly act-reward: a single potion for showing up, granted at most
    // once per rolling 7-day window. The reward is for the act of tracking, not
    // the number — absence of a reward is silent, never framed as a miss.
    bool rewarded = false;
    if (await _metricsService.canEarnReward()) {
      await _potionService.grantPotion();
      await _metricsService.markRewardGranted();
      rewarded = true;
    }

    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      arcadeRoute(
        (_) => LogWeightRewardPage(weightKg: kg, rewarded: rewarded),
        motion: ArcadeRouteMotion.reveal,
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
            ArcadeTextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              style: AppFonts.shareTechMono(color: kText, fontSize: 24),
              hintText: '0.0',
              hintStyle: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 24,
              ),
              suffixText: Units.weight.label,
              suffixStyle: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'morning. before food. before water.',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
            const Spacer(),
            PixelButton(
              label: 'CONFIRM',
              powerOn: true,
              onPressed: _isValid && !_saving ? _confirm : null,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
