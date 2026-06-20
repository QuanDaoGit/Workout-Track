import 'package:flutter/material.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/avatar_spec.dart';
import '../models/character_class.dart';
import '../models/guild_models.dart';
import '../models/loot_item.dart';
import '../models/program_models.dart';
import '../models/unit_models.dart';
import '../models/workout_models.dart';
import '../services/character_service.dart';
import '../services/class_service.dart';
import '../services/guild_service.dart';
import '../services/loot_service.dart';
import '../services/profile_service.dart';
import '../services/program_service.dart';
import '../services/unit_settings_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/avatar/ironbit_avatar.dart';

/// Weekly volume tonnage (stored kg) rendered in the active unit.
String _vol(int kg) =>
    '${fmtVol(kgToDisplay(kg.toDouble(), Units.weight))} ${Units.weight.label}';

class GuildPage extends StatefulWidget {
  const GuildPage({super.key});

  @override
  GuildPageState createState() => GuildPageState();
}

class GuildPageState extends State<GuildPage> {
  final GuildService _guild = GuildService();

  bool _loading = true;
  Guild? _guildData;
  List<GuildMember> _members = const [];
  GuildRecap? _recap;
  int _nodsReceived = 0;
  final Set<String> _nodded = {};

  CharacterClass? _playerClass;
  String _playerName = '';
  AvatarSpec _playerAvatar = AvatarSpec.fallback;
  LootItem? _equippedTitle;
  List<ProgramCompletion> _completions = const [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final classFocus = await ClassService().getCurrentClass();
    final sessions = await WorkoutStorageService().getSessions();
    final now = DateTime.now();
    final week = GuildService.weekIso(now);

    var volume = 0;
    var count = 0;
    for (final s in sessions) {
      if (s.isPartial || s.isAbandoned) continue;
      if (GuildService.weekIso(s.date) != week) continue;
      volume += _sessionVolume(s).round();
      count += 1;
    }

    final view = await _guild.loadGuildView(
      classFocus: classFocus,
      playerWeeklyVolumeKg: volume,
      playerWeeklySessions: count,
      now: now,
    );
    final recap = await _guild.recap(
      classFocus: classFocus,
      playerWeeklyVolumeKg: volume,
      playerWeeklySessions: count,
      now: now,
    );
    final nodded = <String>{};
    for (final m in view.members) {
      if (!m.isPlayer && await _guild.hasNodded(m.userId, now: now)) {
        nodded.add(m.userId);
      }
    }
    final character = await CharacterService().loadActiveCharacter();
    final profile = await ProfileService().loadProfile();
    final equippedTitle = await LootService().getEquippedItem(
      LootCategory.titleBadge,
    );
    final completions = await ProgramService().completedPrograms();
    if (!mounted) return;
    setState(() {
      _guildData = view.guild;
      _members = view.members;
      _recap = recap;
      _nodsReceived = _guild.nodsReceivedThisWeek(now: now);
      _nodded
        ..clear()
        ..addAll(nodded);
      _playerClass = classFocus;
      _playerName = character?.name ?? '';
      _playerAvatar = profile.avatarSpec;
      _equippedTitle = equippedTitle;
      _completions = completions;
      _loading = false;
    });
  }

  double _sessionVolume(WorkoutSession s) =>
      s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);

  Future<void> _sendNod(GuildMember member) async {
    final ok = await _guild.sendForgeNod(member.userId);
    if (!mounted) return;
    if (ok) {
      setState(() => _nodded.add(member.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forge nod sent to ${member.displayName}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kNeon)),
      );
    }
    final guild = _guildData!;
    return Scaffold(
      appBar: AppBar(title: const Text('Guild')),
      body: RefreshIndicator(
        color: kNeon,
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(guild),
            const SizedBox(height: 16),
            _guildCard(),
            const SizedBox(height: 16),
            _recapCard(),
            const SizedBox(height: 16),
            Text(
              'MEMBERS',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final m in _members) ...[
              _MemberTile(
                member: m,
                // Player row mirrors the live profile face; NPCs wear their
                // own stored spec.
                avatarSpec: m.isPlayer ? _playerAvatar : m.avatarSpec,
                nodded: _nodded.contains(m.userId),
                onNod: m.isPlayer ? null : () => _sendNod(m),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(
              'Members other than you are simulated — this build is offline, so '
              'forge nods stay on your device.',
              style: AppFonts.shareTechMono(
                color: kDim,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Guild guild) {
    return Container(
      key: const ValueKey('guild_header_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kNeon),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guild.name.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kNeon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_members.length}/${GuildService.maxMembers} members · '
            '${_vol(guild.weeklyVolumeKg)} this week',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          if (_nodsReceived > 0) ...[
            const SizedBox(height: 4),
            Text(
              'You received $_nodsReceived nods this week.',
              style: AppFonts.shareTechMono(color: kAmber, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guildCard() {
    final clazz = _playerClass;
    final accent = clazz?.themeColor ?? kNeon;
    final title = _equippedTitle;
    return Container(
      key: const ValueKey('guild_player_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GUILD CARD',
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _playerName.isEmpty ? 'RECRUIT' : _playerName.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: kText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            clazz == null ? 'NO CLASS' : clazz.displayName.toUpperCase(),
            style: AppFonts.shareTechMono(color: accent, fontSize: 12),
          ),
          if (title != null) ...[
            const SizedBox(height: 4),
            Text(
              'TITLE · ${title.name}',
              style: AppFonts.shareTechMono(color: title.color, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'PATHS FORGED',
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (_completions.isEmpty)
            Text(
              'No paths forged yet. Finish a program to forge your first.',
              style: AppFonts.shareTechMono(
                color: kDim,
                fontSize: 12,
                height: 1.4,
              ),
            )
          else
            for (final c in _completions) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- ${programById(c.programId)?.name ?? c.programId}'
                  '  ·  ${lootItemById(c.titleId)?.name ?? ''}',
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _recapCard() {
    final recap = _recap!;
    return Container(
      key: const ValueKey('guild_weekly_recap_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY RECAP',
            style: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${recap.guildName} lifted ${_vol(recap.weeklyVolumeKg)} this week. '
            'You: ${_vol(recap.playerVolumeKg)}. '
            'Top 3 received a frame fragment.',
            style: AppFonts.shareTechMono(
              color: kText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (recap.playerInTopThree) ...[
            const SizedBox(height: 6),
            Text(
              'You finished top 3 — fragment earned.',
              key: const ValueKey('guild_fragment_earned_text'),
              style: AppFonts.shareTechMono(
                color: kAmber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.avatarSpec,
    required this.nodded,
    required this.onNod,
  });

  final GuildMember member;
  final AvatarSpec? avatarSpec;
  final bool nodded;
  final VoidCallback? onNod;

  String _lastActive(DateTime now) {
    final diff = now.difference(member.lastActiveAt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final inactive = member.inactiveAsOf(now);
    final tint = member.isPlayer ? kNeon : kBorder;
    return Opacity(
      opacity: inactive ? 0.45 : 1.0,
      child: Container(
        key: ValueKey(
          member.isPlayer
              ? 'guild_member_player'
              : 'guild_member_${member.userId}',
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: tint),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            _avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.displayName,
                        style: AppFonts.shareTechMono(
                          color: member.isPlayer ? kNeon : kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (inactive) ...[
                        const SizedBox(width: 6),
                        Text(
                          'INACTIVE',
                          style: AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_vol(member.weeklyVolumeKg)} · ${member.weeklySessions} '
                    'sessions · ${_lastActive(now)}',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onNod != null && !inactive)
              Semantics(
                button: true,
                label: 'Send forge nod to ${member.displayName}',
                child: IconButton(
                  onPressed: nodded ? null : onNod,
                  icon: Icon(
                    Icons.bolt_sharp,
                    color: nodded ? kMutedText : kAmber,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final spec = avatarSpec;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kBg,
        border: Border.all(color: member.isPlayer ? kNeon : kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: spec == null
          ? const Icon(Icons.person_sharp, color: kMutedText, size: 22)
          // Rosters render many faces — isolate each sprite's repaints.
          : RepaintBoundary(
              child: Center(child: IronbitAvatar(spec: spec, size: 36)),
            ),
    );
  }
}
