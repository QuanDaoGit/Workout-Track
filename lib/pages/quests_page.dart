import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quest_models.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../models/workout_models.dart';
import '../services/gem_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/sfx_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/count_up_text.dart';
import '../widgets/gem_claim_burst.dart';

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
  int _gemBalance = 0;
  final Set<String> _claimingKeys = {};

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
    final gemBalance = await GemService().balance();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _summary = summary;
      _recoveryXP = recoveryXP;
      _potionBonusXP = potionBonusXP;
      _gemBalance = gemBalance;
      _loading = false;
    });
  }

  Future<void> _claim(QuestItem quest) async {
    if (!_claimingKeys.add(quest.claimKey)) return;
    // Optimistic count-up: bump the header balance immediately so the gem
    // counter animates old→new while the (fast, local) persist runs. `reload()`
    // then settles to the authoritative ledger balance (same value).
    setState(() => _gemBalance += quest.rewardGems);
    try {
      await _questService.claimReward(quest.claimKey, _sessions);
      await reload();
      widget.onQuestChanged?.call();
    } finally {
      _claimingKeys.remove(quest.claimKey);
    }
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
            _GemRewardsBar(
              gemBalance: _gemBalance,
              todayGems: summary.todayClaimedGems,
              earnedGems: summary.claimedRewardGems,
              claimableCount: summary.claimableCount,
              level: level,
              rank: rank,
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

/// Quest header — the gem economy at a glance. The gem balance is the hero
/// (it count-ups + overshoots on claim); rank/level is a small identity tag
/// (the player's XP/level bar lives on Home). A sub-stats strip keeps the card
/// from feeling empty: today's haul, rewards ready, and lifetime quest gems.
class _GemRewardsBar extends StatelessWidget {
  const _GemRewardsBar({
    required this.gemBalance,
    required this.todayGems,
    required this.earnedGems,
    required this.claimableCount,
    required this.level,
    required this.rank,
  });

  final int gemBalance;
  final int todayGems;
  final int earnedGems;
  final int claimableCount;
  final int level;
  final String rank;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('quests_gem_header'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity tag.
            Row(
              children: [
                const ImageIcon(
                  AssetImage('assets/icons/control/icon_scroll.png'),
                  size: 20,
                  color: kNeon,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rank.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: kNeon,
                    ),
                  ),
                ),
                Text(
                  'LV. $level',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Hero — the gem balance.
            Row(
              children: [
                Image.asset(
                  'assets/icons/economy/icon_gem.png',
                  key: ValueKey('quests_gem_balance_icon'),
                  width: 30,
                  height: 30,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 12),
                _GemBalanceCounter(
                  key: const ValueKey('quests_gem_balance_counter'),
                  value: gemBalance,
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'GEMS',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Sub-stats strip.
            Row(
              children: [
                Expanded(
                  child: _GemStat(label: 'TODAY', value: '+$todayGems'),
                ),
                Expanded(
                  child: _GemStat(
                    label: 'READY',
                    value: '$claimableCount',
                    highlight: claimableCount > 0,
                  ),
                ),
                Expanded(
                  child: _GemStat(label: 'EARNED', value: '$earnedGems'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single labelled stat in the header strip.
class _GemStat extends StatelessWidget {
  const _GemStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: kMutedText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppFonts.shareTechMono(
            color: highlight ? kAmber : kText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The big gem-balance number: counts up old→new and scale-overshoots with an
/// amber glow whenever the balance rises (the "bar overshoot" analog for a
/// counter). Reduced motion snaps to the final value with no pulse.
class _GemBalanceCounter extends StatefulWidget {
  const _GemBalanceCounter({super.key, required this.value});

  final int value;

  @override
  State<_GemBalanceCounter> createState() => _GemBalanceCounterState();
}

class _GemBalanceCounterState extends State<_GemBalanceCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void didUpdateWidget(covariant _GemBalanceCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > oldWidget.value &&
        !MediaQuery.of(context).disableAnimations) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: 22,
      color: kText,
    );
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final pulse = math.sin(math.pi * _pulse.value);
        return Transform.scale(
          scale: 1 + 0.18 * pulse,
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: kNeon.withValues(alpha: 0.35 * pulse),
                  blurRadius: 14 * pulse,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: CountUpText(value: widget.value, style: textStyle),
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
        Text(subtitle, style: const TextStyle(color: kMutedText, fontSize: 11)),
        if (header != null) ...[const SizedBox(height: 12), header!],
        const SizedBox(height: 12),
        for (final quest in quests)
          Padding(
            key: ValueKey(quest.claimKey),
            padding: const EdgeInsets.only(bottom: 8),
            child: _QuestCard(quest: quest, onClaim: () => onClaim(quest)),
          ),
      ],
    );
  }
}

/// A quest row with a juicy claim: tap → button squash → flip to CLAIMED →
/// gem-shard burst + "+N" float (and chime + haptic from [_handleClaim]) →
/// settle to a dimmed claimed state. Optimistic: it flips locally on tap and
/// reports up via [onClaim]; the page persists + reloads in the background. The
/// stable `ValueKey(claimKey)` on the list element keeps this State across that
/// reload, so the animation never restarts. Reduced motion flips instantly.
class _QuestCard extends StatefulWidget {
  const _QuestCard({required this.quest, required this.onClaim});

  final QuestItem quest;
  final VoidCallback onClaim;

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard>
    with SingleTickerProviderStateMixin {
  bool _claimed = false;
  bool _dim = false;
  bool _squash = false;
  int _burstTrigger = 0;
  int _floatTrigger = 0;
  final List<Timer> _timers = [];

  // The claim "pop": a subtle squash → overshoot → settle bounce on the whole
  // card, with an amber border that lights up then fades (g = sin(pi·t)).
  late final AnimationController _pop;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _claimed = widget.quest.claimed;
    _dim = widget.quest.claimed;
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_pop);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _pop.dispose();
    super.dispose();
  }

  bool get _isClaimed => _claimed || widget.quest.claimed;

  void _handleClaim() {
    if (_isClaimed || !widget.quest.claimable) return;
    // Reaction beat — sound + haptic fire regardless of motion settings.
    SfxService.instance.playQuestClaim();
    HapticFeedback.mediumImpact();
    widget.onClaim();

    if (MediaQuery.of(context).disableAnimations) {
      setState(() {
        _claimed = true;
        _dim = true;
      });
      return;
    }

    // Anticipation → action → reaction → settle.
    setState(() => _squash = true);
    _timers.add(
      Timer(const Duration(milliseconds: 90), () {
        if (!mounted) return;
        setState(() {
          _squash = false;
          _claimed = true; // flip to CLAIMED
          _burstTrigger++; // shard burst
          _floatTrigger++; // rising "+N"
        });
        _pop.forward(from: 0); // card bounce + border glow
      }),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 560), () {
        if (!mounted) return;
        setState(() => _dim = true); // settle to claimed
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    return AnimatedOpacity(
      opacity: _dim ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final glow = math.sin(math.pi * _pop.value);
          return Transform.scale(
            scale: _bounce.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kCardRadius),
                border: glow > 0
                    ? Border.all(
                        color: kAmber.withValues(alpha: glow),
                        width: 1.5,
                      )
                    : null,
                boxShadow: glow > 0
                    ? neonGlow(
                        color: kAmber,
                        opacity: 0.5 * glow,
                        blur: 18 * glow,
                      )
                    : null,
              ),
              child: child,
            ),
          );
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImageIcon(
                  AssetImage(_iconPath()),
                  color: (quest.completed || _isClaimed) ? kNeon : kMutedText,
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
                          color: kText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quest.description,
                        style: const TextStyle(color: kMutedText, fontSize: 12),
                      ),
                      if (quest.rewardTitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Title: ${quest.rewardTitle}',
                          style: const TextStyle(color: kAmber, fontSize: 11),
                        ),
                      ],
                      if (quest.progressLabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          quest.progressLabel!,
                          style: const TextStyle(
                            color: kMutedText,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _action(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _actionControl(),
        // Shards + rising "+N", emanating from the reward control.
        Positioned.fill(child: GemClaimBurst(trigger: _burstTrigger)),
        Positioned(
          top: -4,
          left: 0,
          right: 0,
          child: _GemFloat(
            trigger: _floatTrigger,
            gems: widget.quest.rewardGems,
          ),
        ),
      ],
    );
  }

  Widget _actionControl() {
    if (_isClaimed) {
      return _StatusBadge(
        key: const ValueKey('quest_status_claimed'),
        label: 'CLAIMED',
        color: kMutedText,
      );
    }
    if (widget.quest.claimable) {
      return AnimatedScale(
        scale: _squash ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: PixelButton(
          label: '+${widget.quest.rewardGems} GEMS',
          fullWidth: false,
          onPressed: _handleClaim,
        ),
      );
    }
    return _StatusBadge(
      key: ValueKey('quest_reward_badge_${widget.quest.rewardGems}'),
      label: '+${widget.quest.rewardGems}',
      color: kAmber,
      iconPath: 'assets/icons/economy/icon_gem_reward.png',
    );
  }

  String _iconPath() {
    return switch (widget.quest.category) {
      // Daily quests use the check-slot bullet; it fills in once the quest
      // hits its target (the row also tints it neon at that point).
      QuestCategory.daily => (widget.quest.completed || _isClaimed)
          ? 'assets/icons/control/ui/icon_quest_bullet_done.png'
          : 'assets/icons/control/ui/icon_quest_bullet.png',
      QuestCategory.weekly => 'assets/icons/control/icon_trophy.png',
      QuestCategory.side => 'assets/icons/control/icon_shield.png',
    };
  }
}

/// A single rising "+N" that floats up from the claimed button and fades, once
/// per [trigger] bump. Inert under reduced motion.
class _GemFloat extends StatefulWidget {
  const _GemFloat({required this.trigger, required this.gems});

  final int trigger;
  final int gems;

  @override
  State<_GemFloat> createState() => _GemFloatState();
}

class _GemFloatState extends State<_GemFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant _GemFloat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      if (!MediaQuery.of(context).disableAnimations) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        if (v <= 0 || v >= 1) return const SizedBox.shrink();
        final t = Curves.easeOut.transform(v);
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -t * 26),
            child: Text(
              '+${widget.gems}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: kAmber,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.iconPath,
  });

  final String label;
  final Color color;
  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null) ...[
            Image.asset(
              iconPath!,
              width: 12,
              height: 12,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              color: color,
              fontSize: 8,
            ),
          ),
        ],
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
                color: i < completed ? const Color(0xFF00FF9C) : kBorder,
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
