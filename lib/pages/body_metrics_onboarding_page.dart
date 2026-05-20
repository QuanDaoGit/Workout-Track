import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/body_metrics_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_button.dart';
import 'goal_selection_page.dart';

class BodyMetricsOnboardingPage extends StatefulWidget {
  const BodyMetricsOnboardingPage({super.key});

  @override
  State<BodyMetricsOnboardingPage> createState() =>
      _BodyMetricsOnboardingPageState();
}

class _BodyMetricsOnboardingPageState extends State<BodyMetricsOnboardingPage> {
  int _step = 0;
  bool _pledgeReady = false;
  Timer? _pledgeTimer;

  @override
  void initState() {
    super.initState();
    _pledgeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pledgeReady = true);
    });
  }

  @override
  void dispose() {
    _pledgeTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    setState(() => _step++);
  }

  Future<void> _openGoalSelection() async {
    final result = await Navigator.push<GoalSelectionResult>(
      context,
      arcadeRoute((_) => const GoalSelectionPage()),
    );
    if (result != null && mounted) {
      // Goal has been set via GoalSelectionPage
      _nextStep(); // Move to logging guidance
    }
  }

  Future<void> _completeOnboarding() async {
    await BodyMetricsService().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BODY METRICS')),
      body: switch (_step) {
        0 => _buildPledge(),
        1 => _buildGoalPrompt(),
        _ => _buildGuidance(),
      },
    );
  }

  Widget _buildPledge() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        48,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          const Spacer(),
          Text(
            "A WARRIOR CAN'T BE\nJUDGED BY NUMBERS,\nBUT HIS SPIRIT.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
              height: 2.0,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'this log is private.',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'the app does not judge what you weigh.',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'you log when you want.',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'rewards come for showing up.',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const Spacer(),
          PixelButton(
            label: 'I UNDERSTAND',
            onPressed: _pledgeReady ? () => setState(() => _step = 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPrompt() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        48,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          const Spacer(),
          const Text(
            "WHAT'S YOUR\nDIRECTION?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
              height: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'this helps tailor your rewards.\nyou can change anytime.',
            textAlign: TextAlign.center,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const Spacer(),
          PixelButton(label: 'CHOOSE PATH', onPressed: _openGoalSelection),
        ],
      ),
    );
  }

  Widget _buildGuidance() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        48,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHEN TO LOG',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
            ),
          ),
          const SizedBox(height: 32),
          _guidanceLine('log once per week.'),
          _guidanceLine('morning is best. before food. before water.'),
          _guidanceLine('wear the same thing each time.'),
          _guidanceLine('weekly cadence smooths the noise.'),
          const Spacer(),
          PixelButton(label: 'GOT IT', onPressed: _completeOnboarding),
        ],
      ),
    );
  }

  Widget _guidanceLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
      ),
    );
  }
}
