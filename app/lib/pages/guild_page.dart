import 'package:flutter/material.dart';

import '../models/character_class.dart';
import '../models/guild_models.dart';
import '../models/loot_item.dart';
import '../services/character_service.dart';
import '../services/class_service.dart';
import '../services/gem_service.dart';
import '../services/guild_service.dart';
import '../services/haptic_service.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/workout_metric_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/arcade_card.dart';
import '../widgets/companion/bit_mood_core.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/guild/guild_bit_strip.dart';
import '../widgets/guild/guild_crest.dart';
import '../widgets/guild/guild_crest_editor.dart';
import '../widgets/guild/guild_hall_backdrop.dart';
import '../widgets/guild/guild_legends_card.dart';
import '../widgets/guild/guild_roster.dart';
import '../widgets/guild/weekly_cache_card.dart';

/// The Guild surface — rebuilt from scratch. The living **Guild Hall** backdrop
/// sits at the top with the craftable **crest** in its centre bay; below it the
/// identity header (BIT · guild level · XP bar · customize) and the **roster**
/// (you + OPEN slots). Weekly Cache and Legends layer in over later steps.
///
/// The hall animates only while this tab is active (RootPage drives
/// [GuildPageState.setActive]); off-tab it freezes to a clean static frame.
class GuildPage extends StatefulWidget {
  const GuildPage({super.key});

  @override
  GuildPageState createState() => GuildPageState();
}

class GuildPageState extends State<GuildPage> {
  bool _active = false;
  Guild? _guild;
  GuildMember? _player;
  Color _classColor = kCyan;
  int _level = 1;
  (int, int)? _progress;
  int _cacheActiveDays = 0;
  int _cacheTarget = 3;
  bool _cacheBanked = false;
  bool _cacheJustBanked = false;
  int _streak = 0;
  int _improvedDelta = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// RootPage calls this when the Guild tab gains/loses focus.
  void setActive(bool value) {
    if (value == _active) return;
    setState(() => _active = value);
  }

  /// Creates the guild on first visit and refreshes identity + roster.
  Future<void> reload() async {
    final now = DateTime.now();
    final guild = await GuildService().ensureGuild();
    final classFocus = await ClassService().getCurrentClass();
    final character = await CharacterService().loadActiveCharacter();
    final profile = await ProfileService().loadProfile();
    final sessions = await WorkoutStorageService().getSessions();
    final completed = GuildService.completedSessions(sessions);
    final activeDays = WorkoutMetricService.trainingDaysThisWeek(
      sessions,
      now: now,
    );

    // Weekly Cache — auto-bank the reward the instant it completes. One captured
    // `now` drives BOTH the active-days window and the reward week key (Codex F2),
    // so they can never disagree across a Sunday/Monday boundary.
    final target = GuildService.cacheTarget(1); // solo v1
    final weekKey = GuildService.cacheWeekKey(now);
    final gem = GemService();
    var banked = await gem.isGuildCacheBanked(weekKey);
    var justBanked = false;
    if (activeDays >= target && !banked) {
      final credited = await gem.awardGuildCacheGems(
        weekKey: weekKey,
        amount: GuildService.cacheRewardGems,
        label: 'Weekly Cache',
        now: now,
      );
      banked = true;
      justBanked = credited > 0;
      // A real 20-gem earn — fire the reward beat (one-shot, guarded/muted by the
      // service). Lands ~with the card's chest-open on the next rebuild.
      if (justBanked) HapticService.instance.reward();
    }

    final streak = WorkoutMetricService.currentStreak(sessions, now: now);
    final lastWeekDays = WorkoutMetricService.trainingDaysThisWeek(
      sessions,
      now: now.subtract(const Duration(days: 7)),
    );
    final rank = GuildService.guildRank(GuildService.guildLevel(completed));
    final frame = await LootService().getEquippedItem(LootCategory.avatarFrame);

    if (!mounted) return;
    setState(() {
      _guild = guild;
      _classColor = classFocus.themeColor;
      _level = GuildService.guildLevel(completed);
      _progress = GuildService.guildLevelProgress(completed);
      _cacheActiveDays = activeDays;
      _cacheTarget = target;
      _cacheBanked = banked;
      _cacheJustBanked = justBanked;
      _streak = streak;
      _improvedDelta = activeDays - lastWeekDays;
      _player = GuildMember(
        name: character?.name ?? '',
        avatarSpec: profile.avatarSpec,
        activeDays: activeDays,
        rank: rank,
        framePath: frame?.assetPath,
        frameCount: frame?.frameCount ?? 1,
      );
    });
  }

  Future<void> _editCrest() async {
    final guild = _guild;
    if (guild == null) return;
    final result = await showModalBottomSheet<GuildCrest>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GuildCrestEditorSheet(
        initial: guild.crest,
        classColor: _classColor,
      ),
    );
    if (result != null) {
      await GuildService().updateCrest(result);
      await reload();
    }
  }

  /// BIT's state-derived line — anti-guilt by design (rest is always fine).
  String get _bitLine {
    if (_cacheJustBanked) return 'The cache cracked — solid week, warrior.';
    if (_cacheBanked) return 'Cache banked. The guild holds steady.';
    if (_cacheActiveDays == 0) {
      return 'New week. No rush — show up when you can.';
    }
    return '$_cacheActiveDays ${_cacheActiveDays == 1 ? 'day' : 'days'} in. '
        'Rest when you need it.';
  }

  BitPose get _bitPose => _cacheBanked
      ? BitPose.cheer
      : (_cacheActiveDays == 0 ? BitPose.rest : BitPose.neutral);

  @override
  Widget build(BuildContext context) {
    final guild = _guild;
    final player = _player;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                GuildHallBackdrop(animate: _active),
                if (guild != null)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        // Crest hung COMPACT in the upper bay — box width =
                        // 95/540 of the hall width, rod near the top, hem ~at the
                        // torch-sconce level. A user-directed, more-compact
                        // placement than the handoff's floor-reaching ~60%
                        // (`placement.png` measured hem at 67% — too low).
                        // Sway pauses off-tab (rides _active) + reduced-motion.
                        return Align(
                          alignment: const Alignment(0, -0.79),
                          child: GuildCrestBadge(
                            crest: guild.crest,
                            fallbackColor: _classColor,
                            size: c.maxWidth * 95 / 540,
                            animate: _active,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            Expanded(
              child: (guild == null || player == null)
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GuildBitStrip(line: _bitLine, pose: _bitPose),
                          const SizedBox(height: 16),
                          _IdentityHeader(
                            level: _level,
                            progress: _progress,
                            accent: _classColor,
                            onCustomize: _editCrest,
                          ),
                          const SizedBox(height: 16),
                          WeeklyCacheCard(
                            activeDays: _cacheActiveDays,
                            target: _cacheTarget,
                            banked: _cacheBanked,
                            reward: GuildService.cacheRewardGems,
                            justBanked: _cacheJustBanked,
                          ),
                          const SizedBox(height: 16),
                          GuildLegendsCard(
                            activeDays: _cacheActiveDays,
                            streak: _streak,
                            improvedDelta: _improvedDelta,
                          ),
                          const SizedBox(height: 16),
                          GuildRoster(
                            player: player,
                            openSlots: GuildService.rosterSize - 1,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.level,
    required this.progress,
    required this.accent,
    required this.onCustomize,
  });

  final int level;
  final (int, int)? progress;
  final Color accent;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final frac = p == null || p.$2 == 0 ? 1.0 : p.$1 / p.$2;
    return ArcadeCard(
      key: const ValueKey('guild_identity_header'),
      borderColor: accent, // the identity anchor wears the class hue
      borderAlpha: 0.7,
      borderWidth: kPrimaryCardBorderWidth,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'BIT',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: kText, // identity, NOT the action colour
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LV.$level',
                style: AppFonts.shareTechMono(color: accent, fontSize: 12),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Customize guild crest',
                child: HoldDepress(
                  onTap: onCustomize,
                  haptic: HapticIntent.selection,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_sharp,
                        color: kActionPrimary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CUSTOMIZE',
                        style: AppFonts.shareTechMono(
                          color: kActionPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ArcadeBar(value: frac.clamp(0.0, 1.0), accent: accent, height: 8),
          const SizedBox(height: 4),
          Text(
            p == null
                ? 'MAX GUILD LEVEL'
                : '${p.$1}/${p.$2} sessions to LV.${level + 1}',
            style: AppFonts.shareTechMono(color: kDim, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
