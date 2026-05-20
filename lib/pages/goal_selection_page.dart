import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/body_goal_models.dart';
import '../services/body_goal_service.dart';
import '../theme/tokens.dart';
import '../widgets/pixel_button.dart';

/// Result returned from GoalSelectionPage.
class GoalSelectionResult {
  const GoalSelectionResult({required this.goal, this.targetWeight});
  final BodyGoal goal;
  final double? targetWeight;
}

class GoalSelectionPage extends StatefulWidget {
  const GoalSelectionPage({super.key});

  @override
  State<GoalSelectionPage> createState() => _GoalSelectionPageState();
}

class _GoalSelectionPageState extends State<GoalSelectionPage> {
  final BodyGoalService _service = BodyGoalService();
  BodyGoal? _selectedGoal;
  bool _showTargetWeight = false;
  final _weightController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _confirmGoal(BodyGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(
          'CONFIRM PATH: ${goal.name.toUpperCase()}?',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kNeon,
          ),
        ),
        content: Text(
          'YOU CAN CHANGE ANYTIME. NO PENALTY.',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'CONFIRM',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _selectedGoal = goal;
      _showTargetWeight = true;
    });
  }

  Future<void> _saveAndReturn({bool skip = false}) async {
    if (_selectedGoal == null) return;
    setState(() => _saving = true);

    double? weight;
    if (!skip && _weightController.text.trim().isNotEmpty) {
      weight = double.tryParse(_weightController.text.trim());
    }

    await _service.setGoal(_selectedGoal!, targetWeight: weight);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(GoalSelectionResult(goal: _selectedGoal!, targetWeight: weight));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHOOSE YOUR PATH')),
      body: _showTargetWeight ? _buildTargetWeight() : _buildGoalCards(),
    );
  }

  Widget _buildGoalCards() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Text(
          'CHOOSE YOUR PATH',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: kNeon,
          ),
        ),
        const SizedBox(height: 24),
        _GoalCard(
          goal: BodyGoal.cut,
          icon: '\u25BC', // ▼
          label: 'CUT',
          className: 'ASSASSIN',
          description: 'lean down. preserve strength.',
          borderColor: kDanger,
          onTap: () => _confirmGoal(BodyGoal.cut),
        ),
        const SizedBox(height: 12),
        _GoalCard(
          goal: BodyGoal.recomp,
          icon: '\u2500', // ─
          label: 'RECOMP',
          className: 'BRUISER',
          description: 'hold weight. gain strength.',
          borderColor: kAmber,
          onTap: () => _confirmGoal(BodyGoal.recomp),
        ),
        const SizedBox(height: 12),
        _GoalCard(
          goal: BodyGoal.bulk,
          icon: '\u25B2', // ▲
          label: 'BULK',
          className: 'TANK',
          description: 'build mass. accept the gain.',
          borderColor: kNeon,
          onTap: () => _confirmGoal(BodyGoal.bulk),
        ),
      ],
    );
  }

  Widget _buildTargetWeight() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TARGET WEIGHT',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '(OPTIONAL)',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: AppFonts.shareTechMono(color: kText, fontSize: 24),
            decoration: InputDecoration(
              hintText: 'kg',
              hintStyle: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 24,
              ),
              suffixText: 'kg',
              suffixStyle: AppFonts.shareTechMono(
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
          const SizedBox(height: 8),
          Text(
            "where you'd like to head. no deadline.",
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
          const Spacer(),
          PixelButton(
            label: 'SAVE',
            onPressed: _saving ? null : () => _saveAndReturn(),
            isLoading: _saving,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _saving ? null : () => _saveAndReturn(skip: true),
              child: Text(
                'SKIP',
                style: AppFonts.shareTechMono(color: kMutedText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.icon,
    required this.label,
    required this.className,
    required this.description,
    required this.borderColor,
    required this.onTap,
  });

  final BodyGoal goal;
  final String icon;
  final String label;
  final String className;
  final String description;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  icon,
                  style: AppFonts.shareTechMono(
                    color: borderColor,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '\u2192 $className',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
