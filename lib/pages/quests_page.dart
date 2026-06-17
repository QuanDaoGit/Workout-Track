import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bit_quest_copy.dart';
import '../models/quest_models.dart';
import '../models/workout_models.dart';
import '../services/gem_service.dart';
import '../services/quest_service.dart';
import '../services/sfx_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/companion/bit_mood_core.dart';
import '../widgets/companion/bit_speech_bubble.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/quest_claim_flight.dart';

class QuestsPage extends StatefulWidget {
  const QuestsPage({super.key, this.onQuestChanged});

  final VoidCallback? onQuestChanged;

  @override
  QuestsPageState createState() => QuestsPageState();
}

class QuestsPageState extends State<QuestsPage> {
  final QuestService _questService = QuestService();
  final GlobalKey<GemWalletState> _walletKey = GlobalKey<GemWalletState>();
  final GlobalKey<GemFlightLayerState> _flightKey =
      GlobalKey<GemFlightLayerState>();
  bool _loading = true;
  bool _walletSeeded = false;
  List<WorkoutSession> _sessions = [];
  QuestSummary? _summary;
  int _gemBalance = 0;
  final Set<String> _claimingKeys = {};

  // BIT cheers as gems land (refreshed per arrival), then settles. Lives on the
  // page State so the optimistic-claim reload() never restarts it.
  bool _bitCheer = false;
  Timer? _bitCheerTimer;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _bitCheerTimer?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    final sessions = await WorkoutStorageService().getSessions();
    final summary = await _questService.getSummary(sessions);
    final gemBalance = await GemService().balance();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _summary = summary;
      _gemBalance = gemBalance;
      _loading = false;
    });
    // Seed the wallet once; thereafter claims drive its count-up (re-seeding
    // would snap it mid-flight). The pill builds after this setState, so defer a
    // frame before reaching into its state.
    if (!_walletSeeded) {
      _walletSeeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _walletKey.currentState?.setInitial(_gemBalance);
      });
    }
  }

  /// Claim [quest]: the reward gems fly from the tapped CLAIM button
  /// ([originRect]) up into the pinned wallet, which counts up as they land.
  /// Reduced motion snaps the counter instead (audio + haptic still fire).
  Future<void> _claim(QuestItem quest, Rect originRect) async {
    if (!_claimingKeys.add(quest.claimKey)) return;
    final reward = quest.rewardGems;
    final big = reward >= kBigRewardThreshold;
    final wallet = _walletKey.currentState;
    final walletBox =
        _walletKey.currentContext?.findRenderObject() as RenderBox?;

    if (MediaQuery.of(context).disableAnimations || walletBox == null) {
      // No travel: the counter snaps, BIT shows a static cheer, audio still fires.
      wallet?.land(reward, snap: true, big: big);
      SfxService.instance.playQuestClaim();
      HapticFeedback.mediumImpact();
      _triggerBitCheer(big);
    } else {
      final walletRect = walletBox.localToGlobal(Offset.zero) & walletBox.size;
      wallet?.showDelta(reward); // the single per-claim "+N" reveal
      _flightKey.currentState?.fly(
        originGlobal: originRect,
        walletGlobal: walletRect,
        reward: reward,
        big: big,
      );
    }

    try {
      await _questService.claimReward(quest.claimKey, _sessions);
      await reload();
      widget.onQuestChanged?.call();
    } finally {
      _claimingKeys.remove(quest.claimKey);
    }
  }

  // Each gem arrival: raise the wallet, refresh BIT's cheer, and on the last gem
  // fire the chime + haptic (one satisfying "landed" beat, not a machine-gun).
  void _onGemLand(int amt, bool isLast, bool big) {
    _walletKey.currentState?.land(amt, big: big);
    _triggerBitCheer(big);
    if (isLast) {
      SfxService.instance.playQuestClaim();
      HapticFeedback.mediumImpact();
    }
  }

  void _triggerBitCheer(bool big) {
    if (!mounted) return;
    _bitCheerTimer?.cancel();
    setState(() => _bitCheer = true);
    // Under reduced motion BitMoodCore snaps to a static cheer frame; a brief
    // hold then snaps back. With motion, the cheer holds longer for big payouts.
    final hold =
        MediaQuery.of(context).disableAnimations ? 900 : (big ? 1800 : 1400);
    _bitCheerTimer = Timer(Duration(milliseconds: hold), () {
      if (mounted) setState(() => _bitCheer = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    final summary = _summary!;
    final bitLine = BitQuestCopy.briefing(
      claimable: summary.claimableCount,
      todayClaimed: summary.todayClaimedGems,
      weeklyDone: summary.weeklyCompleted,
      weeklyTotal: summary.weeklyTotal,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      body: Stack(
        children: [
          Column(
            children: [
              _PinnedHeader(
                line: bitLine,
                cheer: _bitCheer,
                walletKey: _walletKey,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
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
                        header: ArcadeBar.segments(
                          litCells: summary.weeklyCompleted,
                          totalCells: summary.weeklyTotal,
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
              ),
            ],
          ),
          // Flight overlay — spans the screen so gems fly from any row (even the
          // bottom of the scroll) up to the pinned wallet. Paints nothing idle.
          Positioned.fill(
            child: GemFlightLayer(key: _flightKey, onLand: _onGemLand),
          ),
        ],
      ),
    );
  }
}

/// The pinned quest header (does NOT scroll): BIT + his state line on the left,
/// the slim magenta gem wallet (the flight destination) on the right. Ported
/// from the Quest Claim handoff's `Header`; replaces the old scrolling briefing
/// + the richer `_GemRewardsBar` (the "slim wallet pill" call drops the rank tag
/// + the TODAY/READY/EARNED sub-stats). BIT is the real painted `BitMoodCore`.
class _PinnedHeader extends StatelessWidget {
  const _PinnedHeader({
    required this.line,
    required this.cheer,
    required this.walletKey,
  });

  final String line;
  final bool cheer;
  final GlobalKey<GemWalletState> walletKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          BitMoodCore(
            key: const ValueKey('quests_bit_core'),
            pose: cheer ? BitPose.cheer : BitPose.neutral,
            size: 44,
            reveal: 1,
            idleAmp: 0.55,
          ),
          const SizedBox(width: 4),
          Expanded(child: BitSpeechBubble(text: line)),
          const SizedBox(width: 10),
          GemWallet(key: walletKey),
        ],
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
  final void Function(QuestItem quest, Rect originRect) onClaim;

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
                color: kText,
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
            child: _QuestCard(
              quest: quest,
              onClaim: (rect) => onClaim(quest, rect),
            ),
          ),
      ],
    );
  }
}

/// A quest row. Tap CLAIM → button squash (anticipation) → the reward gems fly
/// from the button up into the pinned wallet (the page's flight engine) → the
/// row settles to a dimmed CLAIMED state. The card no longer hosts a reward
/// burst or quotes the gem amount — the reward travels to the wallet (the Quest
/// Claim handoff). The stable `ValueKey(claimKey)` keeps this State across the
/// optimistic reload, so the row never re-animates. Reduced motion flips instantly.
class _QuestCard extends StatefulWidget {
  const _QuestCard({required this.quest, required this.onClaim});

  final QuestItem quest;
  final void Function(Rect originRect) onClaim;

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard> {
  bool _claimed = false;
  bool _dim = false;
  bool _squash = false;
  final List<Timer> _timers = [];
  final GlobalKey _claimKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _claimed = widget.quest.claimed;
    _dim = widget.quest.claimed;
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  bool get _isClaimed => _claimed || widget.quest.claimed;

  void _handleClaim() {
    if (_isClaimed || !widget.quest.claimable) return;
    // The CLAIM button's rect is the flight origin — read it before the flip.
    final box = _claimKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : Rect.zero;
    widget.onClaim(origin); // page fires the flight / chime / haptic / cheer

    if (MediaQuery.of(context).disableAnimations) {
      setState(() {
        _claimed = true;
        _dim = true;
      });
      return;
    }
    // Beat 1 — anticipation: button squash, then flip + settle to dimmed CLAIMED.
    setState(() => _squash = true);
    _timers.add(Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(() {
        _squash = false;
        _claimed = true;
      });
    }));
    _timers.add(Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() => _dim = true);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    return AnimatedOpacity(
      opacity: _dim ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
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
                        style: const TextStyle(color: kMutedText, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _actionControl(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionControl() {
    if (_isClaimed) {
      return const _StatusBadge(
        key: ValueKey('quest_status_claimed'),
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
          key: _claimKey,
          label: 'CLAIM',
          fullWidth: false,
          onPressed: _handleClaim,
        ),
      );
    }
    // In progress — a quiet, dim marker. Quest cards never quote the gem payout;
    // the reward is something you earn, not a price tag.
    return const _StatusBadge(
      key: ValueKey('quest_status_in_progress'),
      label: 'IN PROGRESS',
      color: kMutedText,
    );
  }

  String _iconPath() {
    return switch (widget.quest.category) {
      // Daily quests use the check-slot bullet; it fills in once the quest hits
      // its target (the row also tints it neon at that point).
      QuestCategory.daily => (widget.quest.completed || _isClaimed)
          ? 'assets/icons/control/ui/icon_quest_bullet_done.png'
          : 'assets/icons/control/ui/icon_quest_bullet.png',
      QuestCategory.weekly => 'assets/icons/control/icon_trophy.png',
      QuestCategory.side => 'assets/icons/control/icon_shield.png',
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

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
        style: TextStyle(
          fontFamily: 'PressStart2P',
          color: color,
          fontSize: 8,
        ),
      ),
    );
  }
}
