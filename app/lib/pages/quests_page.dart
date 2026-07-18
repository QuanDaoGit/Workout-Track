import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bit_quest_copy.dart';
import '../models/quest_models.dart';
import '../models/workout_models.dart';
import '../services/gem_service.dart';
import '../services/haptic_service.dart';
import '../services/quest_service.dart';
import '../services/sfx_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/chest_open_animation.dart';
import '../widgets/companion/bit_mood_core.dart';
import '../widgets/companion/bit_speech_bubble.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/quest_claim_flight.dart';

class QuestsPage extends StatefulWidget {
  const QuestsPage({super.key, this.onQuestChanged, this.nowProvider});

  final VoidCallback? onQuestChanged;

  /// Injectable clock. The daily/weekly board is a deterministic-per-DATE
  /// rotation (an FNV hash of the period key seeds the pick), so tests pin this
  /// to keep the rendered board — and its golden — stable across runs. Defaults
  /// to the wall clock in production.
  final DateTime Function()? nowProvider;

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

  // Section-completion celebration: which section chest(s) are mid-open (a Set so
  // claim-all clearing BOTH daily and weekly opens both), the bonus gems pending
  // their chest-open flight, and per-chest keys (the flight origin). Driven ONLY
  // by a claim result carrying a NEW section bonus (Codex F2 — no replay on
  // reload); the timer settles the chest back to its static open frame.
  final Set<QuestCategory> _celebrating = {};
  final Map<QuestCategory, int> _pendingBonus = {};
  final GlobalKey _dailyChestKey = GlobalKey();
  final GlobalKey _weeklyChestKey = GlobalKey();
  final GlobalKey _claimAllKey = GlobalKey();
  final List<Timer> _celebrateTimers = [];

  GlobalKey _chestKeyFor(QuestCategory c) =>
      c == QuestCategory.weekly ? _weeklyChestKey : _dailyChestKey;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _bitCheerTimer?.cancel();
    for (final t in _celebrateTimers) {
      t.cancel();
    }
    super.dispose();
  }

  // The page's clock — injectable so the date-seeded quest rotation (and its
  // golden) stay deterministic in tests. Production reads the wall clock.
  DateTime get _now => (widget.nowProvider ?? DateTime.now)();

  Future<void> reload() async {
    final sessions = await WorkoutStorageService().getSessions();
    final summary = await _questService.getSummary(sessions, now: _now);
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

    // The claim "impact" lands at t0 — sound + haptic fire here (synced with the
    // card's flash/shard burst), once per claim, not per gem-landing (a big
    // payout would otherwise machine-gun the chime). BIT cheers as gems land.
    SfxService.instance.playQuestClaim();
    HapticService.instance.reward();

    if (MediaQuery.of(context).disableAnimations || walletBox == null) {
      // No travel: the counter snaps, BIT shows a static cheer.
      wallet?.land(reward, snap: true, big: big);
      _triggerBitCheer(big);
    } else {
      _gemFlightTicks = 0; // fresh streaming-tick budget for this burst
      final walletRect = walletBox.localToGlobal(Offset.zero) & walletBox.size;
      wallet?.showDelta(reward); // the single per-claim "+N" reveal
      _flightKey.currentState?.fly(
        originGlobal: originRect,
        walletGlobal: walletRect,
        reward: reward,
        big: big,
      );
    }

    final reduce = MediaQuery.of(context).disableAnimations;
    try {
      final result =
          await _questService.claimReward(quest.claimKey, _sessions, now: _now);
      // Arm the section chest BEFORE reload so it animates straight from closed
      // (no static-open flash): reload's setState then renders the chest play=true.
      final cat = result.sectionBonusCategory;
      if (cat != null && result.sectionBonusGems > 0 && !reduce) {
        _pendingBonus[cat] = result.sectionBonusGems;
        _celebrating.add(cat);
      }
      await reload();
      widget.onQuestChanged?.call();
      _settleSectionBonus(result, reduce);
    } finally {
      _claimingKeys.remove(quest.claimKey);
    }
  }

  /// Claim every claimable quest in one tap. Sequential awaited claims (serialised
  /// by the gem ledger's per-key lock) so a section bonus only fires after its
  /// completing claim is durably persisted (Codex F1); the per-quest gem-flights
  /// pool onto one running clock, so it reads as one satisfying burst, not N.
  Future<void> _claimAll() async {
    final summary = _summary;
    if (summary == null) return;
    final claimables = [
      ...summary.dailyQuests,
      ...summary.weeklyQuests,
      ...summary.sideQuests,
    ].where((q) => q.claimable && !_claimingKeys.contains(q.claimKey)).toList();
    if (claimables.isEmpty) return;
    final box = _claimAllKey.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box != null ? (box.localToGlobal(Offset.zero) & box.size) : Rect.zero;
    for (final quest in claimables) {
      await _claim(quest, origin);
    }
  }

  /// After a claim that cleared a section: under reduced motion just bank the
  /// bonus (the chest is already a static open frame); otherwise schedule the
  /// chest to settle back to its static open frame once the one-shot finishes.
  void _settleSectionBonus(QuestClaimResult result, bool reduce) {
    final cat = result.sectionBonusCategory;
    final gems = result.sectionBonusGems;
    if (cat == null || gems <= 0 || !mounted) return;
    if (reduce) {
      _pendingBonus.remove(cat);
      _walletKey.currentState
          ?.land(gems, snap: true, big: gems >= kBigRewardThreshold);
      _triggerBitCheer(true);
      return;
    }
    final timer = Timer(
      ChestOpenAnimation.playDuration + const Duration(milliseconds: 250),
      () {
        if (mounted) setState(() => _celebrating.remove(cat));
      },
    );
    _celebrateTimers.add(timer);
  }

  /// The section chest popped open — fly its bonus gems from the chest up to the
  /// wallet (the same homecoming as a quest claim, just sourced from the chest).
  void _onChestOpened(QuestCategory cat) {
    final gems = _pendingBonus.remove(cat) ?? 0;
    if (gems <= 0 || !mounted) return;
    final big = gems >= kBigRewardThreshold;
    final chestBox =
        _chestKeyFor(cat).currentContext?.findRenderObject() as RenderBox?;
    final walletBox =
        _walletKey.currentContext?.findRenderObject() as RenderBox?;
    SfxService.instance.playQuestClaim();
    HapticService.instance.reward();
    if (chestBox == null || walletBox == null) {
      _walletKey.currentState?.land(gems, snap: true, big: big);
      _triggerBitCheer(big);
      return;
    }
    final chestRect = chestBox.localToGlobal(Offset.zero) & chestBox.size;
    final walletRect = walletBox.localToGlobal(Offset.zero) & walletBox.size;
    _gemFlightTicks = 0;
    _walletKey.currentState?.showDelta(gems);
    _flightKey.currentState?.fly(
      originGlobal: chestRect,
      walletGlobal: walletRect,
      reward: gems,
      big: big,
    );
  }

  // Budget for the soft "gems streaming in" ticks (the claim reward already fired
  // at t0). Capped so a big multi-gem payout can't machine-gun the motor — a
  // couple of subtle ticks as they land, not one per gem (Codex haptics review).
  static const _kMaxGemFlightTicks = 2;
  int _gemFlightTicks = 0;

  // Each gem arrival raises the wallet + refreshes BIT's cheer. The chime + the
  // reward haptic fired once at the claim impact (t0); here a *capped* couple of
  // subtle selection ticks ride the stream so the gems feel like they land.
  void _onGemLand(int amt, bool isLast, bool big) {
    _walletKey.currentState?.land(amt, big: big);
    if (_gemFlightTicks < _kMaxGemFlightTicks) {
      _gemFlightTicks++;
      HapticService.instance.selection();
    }
    _triggerBitCheer(big);
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
              // CLAIM ALL — a friction-reducer shown only when something is
              // claimable. The pinned BIT line already announces the count, so
              // this strip carries the action alone (no redundant restatement).
              if (summary.claimableCount > 0)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: const BoxDecoration(
                    color: kBg,
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PixelButton(
                        key: _claimAllKey,
                        label: 'CLAIM ALL',
                        fullWidth: false,
                        minHeight: 36,
                        // The claim handler plays the quest-claim burst — a tap
                        // tick underneath it would stack (keep the tap haptic).
                        sound: false,
                        onPressed: _claimAll,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _QuestSection(
                        title: 'DAILY QUESTS',
                        subtitleWidget: ResetCountdown(
                          kind: ResetKind.daily,
                          nowProvider: widget.nowProvider,
                        ),
                        quests: summary.dailyQuests,
                        header: QuestProgressBar(
                          litCells: summary.dailyCompleted,
                          totalCells: summary.dailyTotal,
                          bonusGems: QuestService.dailySectionBonusGems,
                          chestKey: _dailyChestKey,
                          play: _celebrating.contains(QuestCategory.daily),
                          onChestOpened: () => _onChestOpened(QuestCategory.daily),
                        ),
                        onClaim: _claim,
                      ),
                      const SizedBox(height: 24),
                      _QuestSection(
                        title: 'WEEKLY QUESTS',
                        subtitleWidget: ResetCountdown(
                          kind: ResetKind.weekly,
                          nowProvider: widget.nowProvider,
                        ),
                        quests: summary.weeklyQuests,
                        header: QuestProgressBar(
                          litCells: summary.weeklyCompleted,
                          totalCells: summary.weeklyTotal,
                          bonusGems: QuestService.weeklySectionBonusGems,
                          chestKey: _weeklyChestKey,
                          play: _celebrating.contains(QuestCategory.weekly),
                          onChestOpened: () =>
                              _onChestOpened(QuestCategory.weekly),
                        ),
                        onClaim: _claim,
                      ),
                      const SizedBox(height: 24),
                      _QuestSection(
                        title: 'ACHIEVEMENTS',
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
    required this.quests,
    required this.onClaim,
    this.subtitle,
    this.subtitleWidget,
    this.header,
  }) : assert(subtitle != null || subtitleWidget != null,
            'a section needs either a static subtitle or a live one');

  final String title;

  /// Static muted caption (e.g. side quests' "Permanent milestones").
  final String? subtitle;

  /// Live caption override (the daily/weekly reset countdown). Takes precedence
  /// over [subtitle] when supplied.
  final Widget? subtitleWidget;
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
            // Sections with a progress bar move the count above the bar's end
            // (see [QuestProgressBar]); only the bar-less Achievements section
            // keeps the count in the header.
            if (header == null)
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
        subtitleWidget ??
            Text(
              subtitle!,
              style: const TextStyle(color: kMutedText, fontSize: 11),
            ),
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

/// Which bucket a [ResetCountdown] tracks (its reset cadence differs).
enum ResetKind { daily, weekly }

/// Formats a "time until reset" interval for the section caption. Seconds always
/// tick (the "something is running" signal); a `Nd ` day prefix appears only
/// once at least a full day remains, so the weekly's multi-day horizon reads
/// `5d 14:23:51` while the daily stays a clean `14:23:51`. Clamps a past/zero
/// interval to `00:00:00`. Pure + public so it can be unit/mutation-tested.
String formatResetRemaining(Duration remaining) {
  final d = remaining.isNegative ? Duration.zero : remaining;
  String two(int n) => n.toString().padLeft(2, '0');
  final hms = '${two(d.inHours % 24)}:${two(d.inMinutes % 60)}'
      ':${two(d.inSeconds % 60)}';
  return d.inDays > 0 ? '${d.inDays}d $hms' : hms;
}

/// The live "Resets in HH:MM:SS" caption. A leaf widget: its 1-second
/// [Timer.periodic] rebuilds only itself (the heavy quest list never repaints).
/// Under reduced motion (`disableAnimations || accessibleNavigation`) it starts
/// NO timer and shows a single frozen value — a still, legible signal, and the
/// reason a `pumpAndSettle` test of this page still settles. The reset target is
/// recomputed fresh each tick from [nowProvider], so it auto-rolls at the
/// boundary instead of ticking into negatives.
///
/// Public + self-contained so the reduced-motion gate can be unit-tested in
/// isolation (the full page can't `pumpAndSettle` — BIT's idle never settles).
class ResetCountdown extends StatefulWidget {
  const ResetCountdown({super.key, required this.kind, this.nowProvider});

  final ResetKind kind;
  final DateTime Function()? nowProvider;

  @override
  State<ResetCountdown> createState() => _ResetCountdownState();
}

class _ResetCountdownState extends State<ResetCountdown> {
  Timer? _timer;
  bool _reduce = false;

  DateTime get _now => (widget.nowProvider ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    // The app's documented reduced-presentation trigger is the UNION — gating on
    // disableAnimations alone would leave a screen-reader/switch user with a
    // ticking timer (and hang their pumpAndSettle harness). (Codex review #1.)
    _reduce = mq.disableAnimations || mq.accessibleNavigation;
    _timer?.cancel();
    if (!_reduce) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _target(DateTime now) => switch (widget.kind) {
        ResetKind.daily => QuestService.nextDailyReset(now),
        ResetKind.weekly => QuestService.nextWeeklyReset(now),
      };

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final remaining = _target(now).difference(now);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Resets in '),
          TextSpan(
            text: formatResetRemaining(remaining),
            // Mono so the digits keep fixed columns — a proportional font would
            // jitter the row horizontally every second as digit widths change.
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
        ],
      ),
      style: const TextStyle(color: kMutedText, fontSize: 11),
    );
  }
}

/// A section's progress meter: the canonical segmented [ArcadeBar] filling
/// toward a reward [ChestOpenAnimation] end-cap (closed while unfinished, opening
/// once the section is cleared). One shared widget for both the daily (3-seg) and
/// weekly (5-seg) sections so their treatment can't drift. Public so its chest
/// states can be golden-tested on the real dark theme.
class QuestProgressBar extends StatelessWidget {
  const QuestProgressBar({
    super.key,
    required this.litCells,
    required this.totalCells,
    required this.bonusGems,
    this.play = false,
    this.chestKey,
    this.onChestOpened,
  });

  final int litCells;
  final int totalCells;

  /// The section-completion bonus the chest pays out — shown in the bubble above
  /// the still-closed chest as a "what's inside" hint.
  final int bonusGems;

  /// One-shot: flip true to play the chest-open (the section was just cleared).
  final bool play;

  /// Global key on the chest so the page can launch the bonus gem-flight from it.
  final Key? chestKey;

  /// Fired at the lid-pop — the page launches the bonus gem-flight here.
  final VoidCallback? onChestOpened;

  /// Chest slot height — roomier than the bar (the user's "more space"); the
  /// open-burst reads modestly here while the gem-flight carries the spectacle.
  static const double _chestHeight = 30;

  /// Fixed column the chest + its bubble share, so the (wider) bubble can centre
  /// over the chest and its tail lands on the chest centre.
  static const double _chestColW = 56;

  @override
  Widget build(BuildContext context) {
    final complete = totalCells > 0 && litCells >= totalCells;
    final count = '$litCells / $totalCells';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top strip: the count right-aligned above the bar's end, and (while the
        // chest is still closed) the gem bubble centred over the chest.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    count,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: kText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: kSpace3),
            SizedBox(
              width: _chestColW,
              child: Center(
                child: (!complete && bonusGems > 0)
                    ? _ChestBonusBubble(gems: bonusGems)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // The bar fills toward the chest end-cap (chest centred in the same column
        // as the bubble above, so the tail points at it).
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ArcadeBar.segments(
                litCells: litCells,
                totalCells: totalCells,
              ),
            ),
            const SizedBox(width: kSpace3),
            SizedBox(
              width: _chestColW,
              child: Center(
                child: Semantics(
                  label: complete
                      ? 'Reward chest, opened'
                      : 'Reward chest, locked. Holds $bonusGems gems',
                  child: ExcludeSemantics(
                    child: ChestOpenAnimation(
                      key: chestKey,
                      height: _chestHeight,
                      open: complete,
                      play: play,
                      onOpened: onChestOpened,
                    ),
                  ),
                ),
              ),
            ),
          ],
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

class _QuestCardState extends State<_QuestCard>
    with SingleTickerProviderStateMixin {
  bool _claimed = false;
  bool _dim = false;
  bool _squash = false;
  final List<Timer> _timers = [];
  final GlobalKey _claimKey = GlobalKey();

  // The claim "loud-pixel" burst — a flash + chunky pixel shards + a small shake,
  // fired once at t0 and scaled by whether the payout is a landmark (big). It is
  // decorative (IgnorePointer, no Semantics): the legible state is the CLAIMED
  // badge, so reduced motion just skips the burst and snaps to CLAIMED.
  late final AnimationController _burst;
  List<_BurstShard> _shards = const [];
  bool _bursting = false;
  bool _big = false;

  @override
  void initState() {
    super.initState();
    _claimed = widget.quest.claimed;
    _dim = widget.quest.claimed;
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _bursting = false);
        }
      });
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _burst.dispose();
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
    // Beat 1 (t0) — anticipation squash + the loud-pixel burst (flash + chunky
    // shards + a small shake), scaled by a landmark (big) payout. The burst is
    // the launch impact the gems then fly from.
    _big = widget.quest.rewardGems >= kBigRewardThreshold;
    _shards = _BurstShard.spawn(big: _big);
    setState(() {
      _squash = true;
      _bursting = true;
    });
    _burst.forward(from: 0);
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
    final card = AnimatedOpacity(
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
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, child) {
        final t = _burst.value;
        return Transform.translate(
          offset: _shakeOffset(t),
          child: Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              child!,
              if (_bursting)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _ClaimBurstPainter(t: t, shards: _shards),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: card,
    );
  }

  // Horizontal shake, decaying over the first ~260ms of the burst (off otherwise).
  Offset _shakeOffset(double t) {
    if (!_bursting) return Offset.zero;
    const window = 260 / 700;
    if (t >= window) return Offset.zero;
    final p = t / window;
    final amp = (_big ? 8.0 : 3.0) * (1 - p);
    return Offset(math.sin(p * math.pi * 6) * amp, 0);
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
          // The claim handler fires reward() after its re-tap guard — opt the
          // button out of the default tap() so the claim doesn't double-buzz.
          haptic: HapticIntent.none,
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
      QuestCategory.weekly => 'assets/icons/control/icon_shield.png',
      QuestCategory.side => 'assets/icons/control/icon_trophy.png',
    };
  }
}

/// A small speech bubble that floats above a still-locked reward chest and points
/// down at it: just the gem glyph + the bonus amount the chest pays out when the
/// section is cleared (no label — the chest below is the subject). Hidden once the
/// chest is opened (the gems have already flown). The currency magenta ties it to
/// the wallet; kept small so it reads as a quiet hint, not a price tag.
class _ChestBonusBubble extends StatelessWidget {
  const _ChestBonusBubble({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/economy/icon_gem.png',
                width: 11,
                height: 11,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.diamond_sharp,
                  size: 11,
                  color: kGemMagenta,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$gems',
                style: AppFonts.shareTechMono(color: kText, fontSize: 11),
              ),
            ],
          ),
        ),
        // The tail — a small downward notch pointing at the chest below.
        CustomPaint(
          size: const Size(10, 5),
          painter: _BubbleTailPainter(),
        ),
      ],
    );
  }
}

/// A downward speech-tail: a [kCard] triangle with [kBorder] sides (no top edge,
/// so it reads continuous with the bubble box above it).
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w / 2, h)
      ..close();
    canvas.drawPath(path, Paint()..color = kCard..isAntiAlias = false);
    final edge = Paint()
      ..color = kBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    canvas.drawLine(const Offset(0, 0), Offset(w / 2, h), edge);
    canvas.drawLine(Offset(w, 0), Offset(w / 2, h), edge);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) => false;
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

/// One chunky pixel shard in the claim burst — a square flung from the card
/// centre, gravity-pulled, fading out. No rotation/trail (a trail reads as a
/// smooth particle; these stay crisp pixels).
class _BurstShard {
  const _BurstShard({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;

  static List<_BurstShard> spawn({required bool big}) {
    final rng = math.Random();
    final count = big ? 20 : 14;
    const palette = [kWhite, kNeon, kCyan];
    return List<_BurstShard>.generate(count, (i) {
      return _BurstShard(
        angle: rng.nextDouble() * math.pi * 2,
        speed: (big ? 130.0 : 95.0) + rng.nextDouble() * 90,
        size: big ? 7.0 : 5.0,
        color: palette[i % palette.length],
      );
    });
  }
}

/// The claim burst painter: a hard white phosphor flash over the card (gone in
/// ~110ms) then chunky pixel shards radiating out, gravity-pulled and fading.
/// Tokens-only colour, `isAntiAlias = false` for crisp pixel edges. Reduced
/// motion never instantiates this (the card snaps straight to CLAIMED).
class _ClaimBurstPainter extends CustomPainter {
  _ClaimBurstPainter({required this.t, required this.shards});

  final double t;
  final List<_BurstShard> shards;

  @override
  void paint(Canvas canvas, Size size) {
    const flashWindow = 110 / 700;
    if (t < flashWindow) {
      final fo = (1 - t / flashWindow) * 0.8;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kWhite.withValues(alpha: fo.clamp(0.0, 1.0)),
      );
    }
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..isAntiAlias = false;
    for (final s in shards) {
      final opacity = (1 - t).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final dist = s.speed * t;
      final drop = 60 * t * t;
      final pos = center +
          Offset(math.cos(s.angle) * dist, math.sin(s.angle) * dist + drop);
      final sz = s.size * (1 - 0.35 * t);
      paint.color = s.color.withValues(alpha: opacity);
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: sz, height: sz),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClaimBurstPainter old) =>
      old.t != t || !identical(old.shards, shards);
}
