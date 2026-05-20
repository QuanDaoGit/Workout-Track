import 'package:flutter/material.dart';

import '../models/quest_models.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../models/workout_models.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../widgets/arcade_progress_bar.dart';

class QuestsPage extends StatefulWidget {
  const QuestsPage({super.key, this.onQuestChanged});

  final VoidCallback? onQuestChanged;

  @override
  QuestsPageState createState() => QuestsPageState();
}

class QuestsPageState extends State<QuestsPage> {
  final QuestService _questService = QuestService();
  bool _loading = true;
  List<WorkoutSession> _sessions = [];
  QuestSummary? _summary;
  int _recoveryXP = 0;
  int _potionBonusXP = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final sessions = await WorkoutStorageService().getSessions();
    final summary = await _questService.getSummary(sessions);
    final recoveryXP = await RestService().effectiveRecoveryXP(sessions);
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _summary = summary;
      _recoveryXP = recoveryXP;
      _potionBonusXP = potionBonusXP;
      _loading = false;
    });
  }

  Future<void> _claim(QuestItem quest) async {
    final xp = await _questService.claimReward(quest.claimKey, _sessions);
    await reload();
    widget.onQuestChanged?.call();
    if (!mounted || xp <= 0) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Claimed +$xp XP')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    final summary = _summary!;
    final totalXP =
        XpService.calculateTotalXP(_sessions) +
        summary.claimedRewardXP +
        _recoveryXP +
        _potionBonusXP;
    final xpProgress = XpService.progressForTotalXP(totalXP);
    final level = xpProgress.level;
    final rank = XpService.getRank(level);

    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RewardsBar(
              rank: rank,
              level: level,
              xpLabel: xpProgress.label,
              xpFraction: xpProgress.fraction,
              claimableCount: summary.claimableCount,
            ),
            const SizedBox(height: 24),
            _QuestSection(
              title: 'DAILY QUESTS',
              subtitle: 'Resets at 00:00',
              quests: summary.dailyQuests,
              onClaim: _claim,
            ),
            const SizedBox(height: 24),
            _QuestSection(
              title: 'WEEKLY QUESTS',
              subtitle: 'Resets Monday',
              quests: summary.weeklyQuests,
              header: _SegmentedProgressBar(
                total: summary.weeklyTotal,
                completed: summary.weeklyCompleted,
              ),
              onClaim: _claim,
            ),
            const SizedBox(height: 24),
            _QuestSection(
              title: 'SIDE QUESTS',
              subtitle: 'Permanent milestones',
              quests: summary.sideQuests,
              onClaim: _claim,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RewardsBar extends StatelessWidget {
  const _RewardsBar({
    required this.rank,
    required this.level,
    required this.xpLabel,
    required this.xpFraction,
    required this.claimableCount,
  });

  final String rank;
  final int level;
  final String xpLabel;
  final double xpFraction;
  final int claimableCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ImageIcon(
                  AssetImage('assets/icons/control/icon_scroll.png'),
                  size: 22,
                  color: Color(0xFF00FF9C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rank.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 11,
                      color: Color(0xFF00FF9C),
                    ),
                  ),
                ),
                Text(
                  'LV. $level',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: Color(0xFFE8E8FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ArcadeProgressBar(value: xpFraction),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  xpLabel,
                  style: const TextStyle(
                    color: Color(0xFF6B6B8A),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '$claimableCount rewards ready',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestSection extends StatelessWidget {
  const _QuestSection({
    required this.title,
    required this.subtitle,
    required this.quests,
    required this.onClaim,
    this.header,
  });

  final String title;
  final String subtitle;
  final List<QuestItem> quests;
  final Widget? header;
  final ValueChanged<QuestItem> onClaim;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              '${quests.where((quest) => quest.completed).length} / ${quests.length}',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: Color(0xFFE8E8FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 11),
        ),
        if (header != null) ...[const SizedBox(height: 12), header!],
        const SizedBox(height: 12),
        for (final quest in quests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QuestCard(quest: quest, onClaim: () => onClaim(quest)),
          ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onClaim});

  final QuestItem quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImageIcon(
              AssetImage(_iconPath()),
              color: quest.completed
                  ? const Color(0xFF00FF9C)
                  : const Color(0xFF6B6B8A),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: const TextStyle(
                      color: Color(0xFFE8E8FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quest.description,
                    style: const TextStyle(
                      color: Color(0xFF6B6B8A),
                      fontSize: 12,
                    ),
                  ),
                  if (quest.rewardTitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Title: ${quest.rewardTitle}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (quest.progressLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      quest.progressLabel!,
                      style: const TextStyle(
                        color: Color(0xFF6B6B8A),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _QuestAction(quest: quest, onClaim: onClaim),
          ],
        ),
      ),
    );
  }

  String _iconPath() {
    return switch (quest.category) {
      QuestCategory.daily => 'assets/icons/control/icon_star.png',
      QuestCategory.weekly => 'assets/icons/control/icon_trophy.png',
      QuestCategory.side => 'assets/icons/control/icon_shield.png',
    };
  }
}

class _QuestAction extends StatelessWidget {
  const _QuestAction({required this.quest, required this.onClaim});

  final QuestItem quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    if (quest.claimed) {
      return _StatusBadge(label: 'CLAIMED', color: const Color(0xFF6B6B8A));
    }
    if (quest.claimable) {
      return PixelButton(
        label: '+${quest.rewardXP} XP',
        fullWidth: false,
        onPressed: onClaim,
      );
    }
    return _StatusBadge(
      label: '+${quest.rewardXP} XP',
      color: const Color(0xFFFFD700),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'PressStart2P', color: color, fontSize: 8),
      ),
    );
  }
}

class _SegmentedProgressBar extends StatelessWidget {
  const _SegmentedProgressBar({required this.total, required this.completed});

  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < total; i++) ...[
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: i < completed
                    ? const Color(0xFF00FF9C)
                    : const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
