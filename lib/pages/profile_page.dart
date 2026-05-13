import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';

import '../models/profile_models.dart';
import '../models/quest_models.dart';
import '../models/workout_models.dart';
import '../services/profile_service.dart';
import '../services/quest_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onProfileChanged});

  final VoidCallback? onProfileChanged;

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  static const List<String> _avatarPaths = [
    ProfileData.defaultAvatarPath,
    'assets/avatar/1.png',
    'assets/avatar/3.png',
    'assets/avatar/4.png',
    'assets/avatar/5.png',
    'assets/avatar/6.png',
    'assets/avatar/7.png',
    'assets/avatar/8.png',
  ];

  final QuestService _questService = QuestService();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _nameController = TextEditingController();

  bool _loading = true;
  bool _editingName = false;
  int _selectedTab = 0;
  List<WorkoutSession> _sessions = [];
  QuestSummary? _summary;
  ProfileData _profile = ProfileData.defaults();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final sessions = await WorkoutStorageService().getSessions();
    final summary = await _questService.getSummary(sessions);
    final profile = await _profileService.loadProfile();
    if (!mounted) return;

    if (!_editingName) {
      _nameController.text = profile.displayName;
    }

    setState(() {
      _sessions = sessions;
      _summary = summary;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _saveDisplayName() async {
    await _profileService.saveDisplayName(_nameController.text);
    if (!mounted) return;
    setState(() => _editingName = false);
    await reload();
    widget.onProfileChanged?.call();
  }

  void _cancelDisplayNameEdit() {
    _nameController.text = _profile.displayName;
    setState(() => _editingName = false);
  }

  Future<void> _selectAvatar(String avatarPath) async {
    if (_profile.avatarPath == avatarPath) return;
    await _profileService.saveAvatarPath(avatarPath);
    await reload();
    widget.onProfileChanged?.call();
  }

  Future<void> _selectTitle(String title) async {
    await _questService.selectTitle(title);
    await reload();
    widget.onProfileChanged?.call();
  }

  void _toggleEditMode() {
    setState(() {
      _selectedTab = 0;
      _editingName = !_editingName;
      _nameController.text = _profile.displayName;
    });
  }

  void _showComingSoon({
    required String title,
    required String description,
    required String iconPath,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121225),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ImageIcon(
                    AssetImage(iconPath),
                    size: 22,
                    color: const Color(0xFF00FF9C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: Color(0xFFE8E8FF),
                      ),
                    ),
                  ),
                  const _StatusBadge(label: 'SOON'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: GoogleFonts.shareTechMono(
                  color: const Color(0xFF6B6B8A),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              PixelButton(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: _editingName ? 'Stop editing' : 'Edit guild card',
            onPressed: _toggleEditMode,
            icon: ImageIcon(
              const AssetImage('assets/icons/control/icon_hammer.png'),
              color: _editingName
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF00FF9C),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _ProfileTabs(
            selectedIndex: _selectedTab,
            onSelect: (index) => setState(() => _selectedTab = index),
          ),
          const SizedBox(height: 16),
          if (_selectedTab == 0) _buildGuildCard(),
          if (_selectedTab == 1) _buildLoadout(),
          if (_selectedTab == 2) _buildSettings(),
        ],
      ),
    );
  }

  Widget _buildGuildCard() {
    final summary = _summary!;
    final totalXP =
        XpService.calculateTotalXP(_sessions) + summary.claimedRewardXP;
    final level = XpService.getLevel(totalXP);
    final rank = XpService.getRank(level);
    final xpBase = XpService.xpForCurrentLevel(level);
    final xpNext = XpService.xpForNextLevel(level);
    final xpFraction = xpNext > xpBase
        ? ((totalXP - xpBase) / (xpNext - xpBase)).clamp(0.0, 1.0)
        : 1.0;
    final streak = XpService.calculateStreak(_sessions);
    final quests = [
      ...summary.dailyQuests,
      ...summary.weeklyQuests,
      ...summary.sideQuests,
    ];
    final completedQuests = quests.where((quest) => quest.completed).length;
    final titleCount = summary.earnedTitles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF17172C),
            border: Border.all(color: const Color(0xFF00FF9C), width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarFrame(path: _profile.avatarPath, size: 76),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _editingName ? _buildNameEditor() : _buildNameBlock(),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _RankBadge(label: rank),
                            _StatusBadge(label: 'LV. $level'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: xpFraction,
                  minHeight: 9,
                  backgroundColor: const Color(0xFF2A2A4A),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00FF9C),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalXP / $xpNext XP',
                    style: const TextStyle(
                      color: Color(0xFF6B6B8A),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${summary.claimableCount} rewards ready',
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
        const SizedBox(height: 18),
        const _SectionHeader(title: 'RPG CORE'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                iconPath: 'assets/icons/control/icon_star.png',
                label: 'LEVEL',
                value: '$level',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                iconPath: 'assets/icons/control/icon_thunder.png',
                label: 'STREAK',
                value: '${streak}d',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                iconPath: 'assets/icons/control/icon_scroll.png',
                label: 'QUESTS',
                value: '$completedQuests/${quests.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                iconPath: 'assets/icons/control/icon_shield.png',
                label: 'TITLES',
                value: '$titleCount',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameBlock() {
    final title = _summary!.selectedTitle ?? 'untitled';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.shareTechMono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE8E8FF),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.shareTechMono(
            color: _summary!.selectedTitle == null
                ? const Color(0xFF6B6B8A)
                : const Color(0xFFFFD700),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildNameEditor() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            maxLength: 20,
            onSubmitted: (_) => _saveDisplayName(),
            style: GoogleFonts.shareTechMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE8E8FF),
            ),
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3D3A68)),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00FF9C)),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _SmallIconButton(
          iconPath: 'assets/icons/control/icon_save.png',
          color: const Color(0xFF00FF9C),
          onPressed: _saveDisplayName,
        ),
        _SmallIconButton(
          iconPath: 'assets/icons/control/icon_clear.png',
          color: const Color(0xFF6B6B8A),
          onPressed: _cancelDisplayNameEdit,
        ),
      ],
    );
  }

  Widget _buildLoadout() {
    final summary = _summary!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'AVATAR'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final avatarPath in _avatarPaths)
              _AvatarChoice(
                path: avatarPath,
                selected: _profile.avatarPath == avatarPath,
                onTap: () => _selectAvatar(avatarPath),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionHeader(title: 'TITLES'),
        const SizedBox(height: 10),
        if (summary.earnedTitles.isEmpty)
          _InfoPanel(
            iconPath: 'assets/icons/control/icon_lock.png',
            title: 'No titles unlocked',
            subtitle: 'Claim Side Quest rewards to unlock titles.',
          )
        else
          for (final title in summary.earnedTitles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TitleRow(
                title: title,
                selected: summary.selectedTitle == title,
                onTap: () => _selectTitle(title),
              ),
            ),
        const SizedBox(height: 14),
        const _SectionHeader(title: 'COSMETICS'),
        const SizedBox(height: 10),
        _LockedFeatureRow(
          iconPath: 'assets/icons/control/icon_shield.png',
          title: 'Badge Frame',
          subtitle: 'Decorative borders for your Guild Card.',
          onTap: () => _showComingSoon(
            title: 'Badge Frame',
            description: 'Future cosmetic frames will let you style your card.',
            iconPath: 'assets/icons/control/icon_shield.png',
          ),
        ),
        _LockedFeatureRow(
          iconPath: 'assets/icons/control/icon_flag.png',
          title: 'Guild Banner',
          subtitle: 'A profile banner for milestone themes.',
          onTap: () => _showComingSoon(
            title: 'Guild Banner',
            description: 'Banners will unlock more profile personality later.',
            iconPath: 'assets/icons/control/icon_flag.png',
          ),
        ),
        _LockedFeatureRow(
          iconPath: 'assets/icons/control/icon_brush.png',
          title: 'Profile Theme',
          subtitle: 'Alternate color kits for your RPG profile.',
          onTap: () => _showComingSoon(
            title: 'Profile Theme',
            description:
                'Theme choices will arrive after the core app is stable.',
            iconPath: 'assets/icons/control/icon_brush.png',
          ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'PLAYER SETUP'),
        const SizedBox(height: 10),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_stat.png',
          title: 'Personal Stats',
          subtitle: 'Height, weight, age, and body context.',
          onTap: () => _showComingSoon(
            title: 'Personal Stats',
            description:
                'This will hold optional body stats once goals and privacy are designed.',
            iconPath: 'assets/icons/control/icon_stat.png',
          ),
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_target.png',
          title: 'Training Goals',
          subtitle: 'Strength, consistency, or muscle focus.',
          onTap: () => _showComingSoon(
            title: 'Training Goals',
            description:
                'Goal setup will help missions and quests adapt to your training.',
            iconPath: 'assets/icons/control/icon_target.png',
          ),
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_gear.png',
          title: 'Preferences',
          subtitle: 'Units, defaults, and workout behavior.',
          onTap: () => _showComingSoon(
            title: 'Preferences',
            description:
                'App preferences will be added after the core flows settle.',
            iconPath: 'assets/icons/control/icon_gear.png',
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'APP SUPPORT'),
        const SizedBox(height: 10),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_bell.png',
          title: 'Notifications',
          subtitle: 'Workout nudges and quest reminders.',
          onTap: () => _showComingSoon(
            title: 'Notifications',
            description:
                'Reminder controls will appear here when notification support exists.',
            iconPath: 'assets/icons/control/icon_bell.png',
          ),
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_lock.png',
          title: 'Privacy',
          subtitle: 'Local data, visibility, and safety controls.',
          onTap: () => _showComingSoon(
            title: 'Privacy',
            description:
                'Privacy controls will matter more once sharing or cloud sync exists.',
            iconPath: 'assets/icons/control/icon_lock.png',
          ),
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_save.png',
          title: 'Data Export & Backup',
          subtitle: 'Export local workout history later.',
          onTap: () => _showComingSoon(
            title: 'Data Export & Backup',
            description:
                'Export and backup tools are planned, but this version stays local-only.',
            iconPath: 'assets/icons/control/icon_save.png',
          ),
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_interrogation.png',
          title: 'Help',
          subtitle: 'Guides, FAQ, and workout entry tips.',
          onTap: () => _showComingSoon(
            title: 'Help',
            description:
                'Help content will explain workouts, quests, XP, titles, and profile setup.',
            iconPath: 'assets/icons/control/icon_interrogation.png',
          ),
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_scroll.png',
          title: 'About',
          subtitle: 'Version, credits, and app notes.',
          onTap: () => _showComingSoon(
            title: 'About',
            description: 'Version details and credits will live here later.',
            iconPath: 'assets/icons/control/icon_scroll.png',
          ),
        ),
      ],
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _labels = ['Guild Card', 'Loadout', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF121225),
        border: Border.all(color: const Color(0xFF2A2A4A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? const Color(0xFF00FF9C)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _labels[i].toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 7,
                      color: selectedIndex == i
                          ? const Color(0xFF0D0D1A)
                          : const Color(0xFF6B6B8A),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFrame extends StatelessWidget {
  const _AvatarFrame({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border.all(color: const Color(0xFF3D3A68)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Image.asset(path, filterQuality: FilterQuality.none),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.path,
    required this.selected,
    required this.onTap,
  });

  final String path;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF121225),
          border: Border.all(
            color: selected ? const Color(0xFF00FF9C) : const Color(0xFF2A2A4A),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Center(child: Image.asset(path, filterQuality: FilterQuality.none)),
            if (selected)
              const Positioned(
                right: 0,
                top: 0,
                child: ImageIcon(
                  AssetImage('assets/icons/control/icon_star.png'),
                  size: 14,
                  color: Color(0xFFFFD700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 10),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF00FF9C)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: Color(0xFF00FF9C),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF9C).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFF00FF9C)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: Color(0xFF00FF9C),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.iconPath,
    required this.label,
    required this.value,
  });

  final String iconPath;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121225),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          ImageIcon(
            AssetImage(iconPath),
            size: 18,
            color: const Color(0xFF00FF9C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    color: Color(0xFF6B6B8A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFE8E8FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121225),
          border: Border.all(
            color: selected ? const Color(0xFF00FF9C) : const Color(0xFF2A2A4A),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            ImageIcon(
              AssetImage(
                selected
                    ? 'assets/icons/control/icon_star.png'
                    : 'assets/icons/control/icon_shield.png',
              ),
              color: selected
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF6B6B8A),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFE8E8FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Side Quest title',
                    style: TextStyle(color: Color(0xFF6B6B8A), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected) const _StatusBadge(label: 'ACTIVE'),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.iconPath,
    required this.title,
    required this.subtitle,
  });

  final String iconPath;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121225),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          ImageIcon(
            AssetImage(iconPath),
            size: 20,
            color: const Color(0xFF6B6B8A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE8E8FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B6B8A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedFeatureRow extends StatelessWidget {
  const _LockedFeatureRow({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SettingsRow(
        iconPath: iconPath,
        title: title,
        subtitle: subtitle,
        trailingLabel: 'LOCKED',
        onTap: onTap,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF121225),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ImageIcon(
                AssetImage(iconPath),
                size: 20,
                color: const Color(0xFF00FF9C),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFE8E8FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B6B8A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailingLabel != null)
                _MiniTextBadge(label: trailingLabel!)
              else
                const ImageIcon(
                  AssetImage('assets/icons/control/icon_next.png'),
                  size: 16,
                  color: Color(0xFF6B6B8A),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTextBadge extends StatelessWidget {
  const _MiniTextBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        color: Color(0xFF6B6B8A),
        fontSize: 7,
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.iconPath,
    required this.color,
    required this.onPressed,
  });

  final String iconPath;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: ImageIcon(AssetImage(iconPath), color: color, size: 18),
      ),
    );
  }
}
