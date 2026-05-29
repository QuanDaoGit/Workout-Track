import 'package:flutter/material.dart';

import '../models/guild_models.dart';
import '../models/workout_models.dart';
import '../services/class_service.dart';
import '../services/guild_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

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
    if (!mounted) return;
    setState(() {
      _guildData = view.guild;
      _members = view.members;
      _recap = recap;
      _nodsReceived = _guild.nodsReceivedThisWeek(now: now);
      _nodded
        ..clear()
        ..addAll(nodded);
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
            '${guild.weeklyVolumeKg} kg this week',
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

  Widget _recapCard() {
    final recap = _recap!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.lerp(kSurface2, kAmber, 0.05),
        border: Border.all(color: kAmber.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY RECAP',
            style: AppFonts.shareTechMono(
              color: kAmber,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${recap.guildName} lifted ${recap.weeklyVolumeKg} kg this week. '
            'You: ${recap.playerVolumeKg} kg. '
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
              style: AppFonts.shareTechMono(
                color: kNeon,
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
    required this.nodded,
    required this.onNod,
  });

  final GuildMember member;
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
                    '${member.weeklyVolumeKg} kg · ${member.weeklySessions} '
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
    final path = member.avatarPath;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kBg,
        border: Border.all(color: member.isPlayer ? kNeon : kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? const Icon(Icons.person_sharp, color: kMutedText, size: 22)
          : Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person_sharp, color: kMutedText, size: 22),
            ),
    );
  }
}
