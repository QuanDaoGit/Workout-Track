import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/loot_registry.dart';
import '../data/programs_library.dart';
import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';
import '../models/loot_item.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';

import '../models/profile_models.dart';
import '../models/program_models.dart';
import '../models/quest_models.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../models/character_class.dart';
import '../models/class_state.dart';
import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
import '../services/class_service.dart';
import '../services/profile_service.dart';
import '../services/program_service.dart';
import '../services/progression_settings_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/stat_engine.dart';
import '../services/loot_service.dart';
import '../services/workout_metric_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/rest_icon.dart';
import '../widgets/class_sprite.dart';
import '../widgets/stat_card.dart';
import 'body_metrics_chart_page.dart';
import 'body_metrics_onboarding_page.dart';
import 'class_select_page.dart';
import 'goal_selection_page.dart';
import 'inventory_page.dart';
import 'log_weight_page.dart';
import 'programs_library_page.dart';

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
  final StatEngine _statEngine = StatEngine();
  final RestService _restService = RestService();
  final LootService _lootService = LootService();
  final ProgramService _programService = ProgramService();
  final TextEditingController _nameController = TextEditingController();

  bool _loading = true;
  bool _editingName = false;
  int _selectedTab = 0;
  List<WorkoutSession> _sessions = [];
  QuestSummary? _summary;
  RestState _restState = RestState.defaults();
  int _recoveryXP = 0;
  int _potionBonusXP = 0;
  bool _bodyMetricsEnabled = false;
  bool _progressionEnabled = true;
  BodyGoalState? _bodyGoalState;
  WeightEntry? _lastWeightEntry;
  bool _canLogWeight = false;
  int _daysUntilNextLog = 0;
  String? _activeBoostLabel;
  Map<String, int> _combatStats = {
    for (final stat in StatEngine.stats) stat: 0,
  };
  ProfileData _profile = ProfileData.defaults();
  Map<LootCategory, LootItem> _equippedLoot = {};
  int _ownedLootCount = 0;
  ProgramProgress? _programProgress;
  ClassState? _classState;

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
    final combatStats = await _statEngine.getStoredStats();
    final restState = await _restService.refreshWeeklyShieldProgress(sessions);
    final recoveryXP = _restService.effectiveRecoveryXPForState(
      sessions: sessions,
      state: restState,
    );
    final equippedLoot = await _lootService.getEquippedLoot();
    final ownedLootCount = await _lootService.getOwnedCount();
    final programProgress = await _programService.getActiveProgress();
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    final classService = ClassService();
    final classState = await classService.getState();
    final metricsService = BodyMetricsService();
    final bodyMetricsEnabled = await metricsService.isEnabled();
    final progressionEnabled = await ProgressionSettingsService().isEnabled();
    BodyGoalState? bodyGoalState;
    WeightEntry? lastWeightEntry;
    bool canLogWeight = false;
    int daysUntilNextLog = 0;
    String? activeBoostLabel;
    if (bodyMetricsEnabled) {
      bodyGoalState = await BodyGoalService().getGoalState();
      lastWeightEntry = await metricsService.getLastEntry();
      canLogWeight = await metricsService.canLogWeight();
      daysUntilNextLog = await metricsService.daysUntilNextLog();
      activeBoostLabel = await XpBoostService().getActiveBoostLabel();
    }
    if (!mounted) return;

    if (!_editingName) {
      _nameController.text = profile.displayName;
    }

    setState(() {
      _sessions = sessions;
      _summary = summary;
      _restState = restState;
      _recoveryXP = recoveryXP;
      _combatStats = combatStats;
      _profile = profile;
      _equippedLoot = equippedLoot;
      _ownedLootCount = ownedLootCount;
      _programProgress = programProgress;
      _potionBonusXP = potionBonusXP;
      _classState = classState;
      _bodyMetricsEnabled = bodyMetricsEnabled;
      _progressionEnabled = progressionEnabled;
      _bodyGoalState = bodyGoalState;
      _lastWeightEntry = lastWeightEntry;
      _canLogWeight = canLogWeight;
      _daysUntilNextLog = daysUntilNextLog;
      _activeBoostLabel = activeBoostLabel;
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

  LootItem? get _equippedTitle => _equippedLoot[LootCategory.titleBadge];

  LootItem? get _equippedFrame => _equippedLoot[LootCategory.avatarFrame];

  Future<void> _openInventory() async {
    await Navigator.of(context).push(arcadeRoute((_) => const InventoryPage()));
    await reload();
    widget.onProfileChanged?.call();
  }

  Future<void> _openPrograms() async {
    await Navigator.of(
      context,
    ).push(arcadeRoute((_) => const ProgramsLibraryPage()));
    await reload();
    widget.onProfileChanged?.call();
  }

  Future<void> _toggleBodyMetrics(bool value) async {
    if (value) {
      final onboarded = await BodyMetricsService().isOnboardingComplete();
      if (!onboarded) {
        if (!mounted) return;
        final result = await Navigator.push<bool>(
          context,
          arcadeRoute((_) => const BodyMetricsOnboardingPage()),
        );
        if (result != true) return;
      }
      await BodyMetricsService().setEnabled(true);
    } else {
      await BodyMetricsService().setEnabled(false);
    }
    await reload();
  }

  Future<void> _toggleProgression(bool value) async {
    await ProgressionSettingsService().setEnabled(value);
    if (!mounted) return;
    setState(() => _progressionEnabled = value);
  }

  Future<void> _openLogWeight() async {
    await Navigator.push(context, arcadeRoute((_) => const LogWeightPage()));
    await reload();
  }

  Future<void> _openBodyMetricsChart() async {
    await Navigator.push(
      context,
      arcadeRoute((_) => const BodyMetricsChartPage()),
    );
    await reload();
  }

  Future<void> _changeGoal() async {
    final result = await Navigator.push<GoalSelectionResult>(
      context,
      arcadeRoute((_) => const GoalSelectionPage()),
    );
    if (result != null) await reload();
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

  String _weekdaySummary(Set<int> weekdays) {
    const labels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final ordered = weekdays.toList()..sort();
    return ordered.map((day) => labels[day]!).join(' / ');
  }

  void _showTrainingGoalsSheet() {
    var selected = Set<int>.from(
      _restState.pendingTrainingWeekdays ?? _restState.trainingWeekdays,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121225),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final valid = selected.isNotEmpty && selected.length < 7;
            final pendingStart = _restState.pendingStartWeekKey;
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
                      const RestIcon(
                        assetPath: RestAssets.recoveryShield,
                        fallbackAssetPath:
                            'assets/icons/control/icon_shield.png',
                        size: 22,
                        color: Color(0xFF00FF9C),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'TRAINING GOALS',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: Color(0xFF00FF9C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pick training days. The other days become planned recovery and protect your stats.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  _ScheduleInfoRow(
                    label: 'ACTIVE',
                    value: _weekdaySummary(_restState.trainingWeekdays),
                  ),
                  const SizedBox(height: 8),
                  _ScheduleInfoRow(
                    label: 'SHIELDS',
                    value:
                        '${_restState.shieldCharges} / ${RestService.maxShieldCharges}',
                  ),
                  if (pendingStart != null &&
                      _restState.pendingTrainingWeekdays != null) ...[
                    const SizedBox(height: 8),
                    _ScheduleInfoRow(
                      label: 'NEXT',
                      value:
                          '${_weekdaySummary(_restState.pendingTrainingWeekdays!)} on $pendingStart',
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final day in const [
                        (1, 'MON'),
                        (2, 'TUE'),
                        (3, 'WED'),
                        (4, 'THU'),
                        (5, 'FRI'),
                        (6, 'SAT'),
                        (7, 'SUN'),
                      ])
                        _WeekdayToggle(
                          label: day.$2,
                          selected: selected.contains(day.$1),
                          onTap: () {
                            setSheetState(() {
                              if (selected.contains(day.$1)) {
                                selected.remove(day.$1);
                              } else {
                                selected.add(day.$1);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    valid
                        ? 'Changes start next Monday.'
                        : 'Choose at least one training day and one rest day.',
                    style: TextStyle(
                      color: valid
                          ? const Color(0xFF6B6B8A)
                          : const Color(0xFFFFD700),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PixelButton(
                    label: 'SAVE FOR NEXT WEEK',
                    onPressed: valid
                        ? () async {
                            await _restService.saveTrainingWeekdays(selected);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            await reload();
                            widget.onProfileChanged?.call();
                          }
                        : null,
                  ),
                ],
              ),
            );
          },
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedTab),
              child: switch (_selectedTab) {
                0 => _buildGuildCard(),
                1 => _buildLoadout(),
                _ => _buildSettings(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuildCard() {
    final summary = _summary!;
    final totalXP =
        XpService.calculateTotalXP(_sessions) +
        summary.claimedRewardXP +
        _recoveryXP +
        _potionBonusXP;
    final level = XpService.getLevel(totalXP);
    final rank = XpService.getRank(level);
    final xpProgress = XpService.progressForTotalXP(totalXP);
    final trainingDays = WorkoutMetricService.trainingDaysThisWeek(_sessions);
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
                  LootAvatarFrame(
                    avatarPath: _profile.avatarPath,
                    framePath: _equippedFrame?.assetPath,
                    size: 86,
                  ),
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
                            _StatusBadge(
                              label:
                                  'BAG $_ownedLootCount/${lootRegistry.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ArcadeProgressBar(value: xpProgress.fraction),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    xpProgress.label,
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
        StatCard(stats: _combatStats),
        const SizedBox(height: 12),
        _buildClassSection(),
        const SizedBox(height: 12),
        _buildProgramsSection(),
        if (_bodyMetricsEnabled) ...[
          const SizedBox(height: 12),
          _buildBodyMetricsSection(),
        ],
        const SizedBox(height: 12),
        PixelButton(label: 'LOOT INVENTORY', onPressed: _openInventory),
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
                iconPath: 'assets/icons/control/icon_time.png',
                label: 'TRAIN DAYS',
                value: '$trainingDays this wk',
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
        const SizedBox(height: 8),
        _StatTile(
          iconPath: 'assets/icons/control/icon_trophy.png',
          label: 'LIFETIME XP',
          value: '$totalXP XP',
        ),
      ],
    );
  }

  Widget _buildClassSection() {
    final cls = _classState?.currentClass ?? CharacterClass.bruiser;
    final color = cls.themeColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClassSprite(
                assetPath: 'assets/classes/icons/${cls.name}.png',
                placeholderTint: color,
                size: 36,
                placeholderLabel: cls.displayName[0],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls.displayName,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PATH OF THE ${cls.bodyGoalLabel}',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        color: const Color(0xFF6B6B8A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  arcadeRoute(
                    (_) => const ClassSelectPage(isFirstSelection: false),
                  ),
                );
                reload();
              },
              child: Text(
                'CHANGE CLASS',
                style: GoogleFonts.shareTechMono(
                  fontSize: 11,
                  color: const Color(0xFF6B6B8A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramsSection() {
    final progress = _programProgress;
    final program = progress == null ? null : programById(progress.programId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'PROGRAMS'),
        const SizedBox(height: 10),
        if (progress == null || program == null)
          _InfoPanel(
            iconPath: 'assets/icons/control/icon_scroll.png',
            title: 'No active program',
            subtitle: 'Pick a weekly plan and follow one day at a time.',
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121225),
              border: Border.all(color: const Color(0xFF2A2A4A)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const ImageIcon(
                  AssetImage('assets/icons/control/icon_scroll.png'),
                  size: 20,
                  color: Color(0xFF00FF9C),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                          color: Color(0xFFE8E8FF),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'WEEK ${progress.currentWeek} - DAY ${progress.currentDayIndex + 1}/7',
                        style: GoogleFonts.shareTechMono(
                          color: const Color(0xFF6B6B8A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MiniTextBadge(label: '${progress.completedSessions} DONE'),
              ],
            ),
          ),
        const SizedBox(height: 10),
        PixelButton(
          label: progress == null ? 'BROWSE PROGRAMS' : 'MANAGE',
          onPressed: _openPrograms,
        ),
      ],
    );
  }

  Widget _buildBodyMetricsSection() {
    final goal = _bodyGoalState;
    final lastEntry = _lastWeightEntry;

    String lastLoggedLabel = 'No entries yet';
    if (lastEntry != null) {
      final daysAgo = DateTime.now().difference(lastEntry.loggedAt).inDays;
      final timeLabel = daysAgo == 0
          ? 'today'
          : daysAgo == 1
          ? 'yesterday'
          : '$daysAgo days ago';
      lastLoggedLabel =
          '$timeLabel · ${lastEntry.weightKg.toStringAsFixed(1)} kg';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'BODY METRICS'),
        const SizedBox(height: 10),
        if (goal != null)
          GestureDetector(
            onTap: _changeGoal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF121225),
                border: Border.all(color: const Color(0xFF00BFFF)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${goal.goalLabel} \u2192 ${goal.futureClassName}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Color(0xFF00BFFF),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          lastLoggedLabel,
          style: GoogleFonts.shareTechMono(
            color: const Color(0xFF6B6B8A),
            fontSize: 11,
          ),
        ),
        if (goal?.targetWeight != null) ...[
          const SizedBox(height: 4),
          Text(
            'heading toward ${goal!.targetWeight!.toStringAsFixed(1)} kg',
            style: GoogleFonts.shareTechMono(
              color: const Color(0xFF6B6B8A),
              fontSize: 11,
            ),
          ),
        ],
        if (_activeBoostLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_potion.png'),
                color: Color(0xFFFFD700),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _activeBoostLabel!,
                style: GoogleFonts.shareTechMono(
                  color: const Color(0xFFFFD700),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        PixelButton(
          label: _canLogWeight
              ? 'LOG WEIGHT'
              : 'NEXT LOG IN $_daysUntilNextLog DAYS',
          onPressed: _canLogWeight ? _openLogWeight : null,
        ),
        const SizedBox(height: 8),
        PixelButton(label: 'VIEW TREND', onPressed: _openBodyMetricsChart),
      ],
    );
  }

  Widget _buildNameBlock() {
    final titleItem = _equippedTitle;
    final title = titleItem?.name ?? _summary!.selectedTitle ?? 'untitled';
    final titleColor =
        titleItem?.color ??
        (_summary!.selectedTitle == null
            ? const Color(0xFF6B6B8A)
            : const Color(0xFFFFD700));
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
          style: GoogleFonts.shareTechMono(color: titleColor, fontSize: 13),
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
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_stat.png',
          title: 'Body Metrics',
          subtitle: _bodyMetricsEnabled
              ? 'Weekly weight log active.'
              : 'Opt-in weekly weight tracking.',
          value: _bodyMetricsEnabled,
          onChanged: _toggleBodyMetrics,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_trophy.png',
          title: 'Suggested loads',
          subtitle: _progressionEnabled
              ? 'TRY: prompts on Set 1 of each exercise.'
              : 'No suggestions — every set entry blank.',
          value: _progressionEnabled,
          onChanged: _toggleProgression,
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_target.png',
          title: 'Training Goals',
          subtitle:
              'Train ${_weekdaySummary(_restState.trainingWeekdays)} · ${_restState.shieldCharges}/${RestService.maxShieldCharges} shields',
          onTap: _showTrainingGoalsSheet,
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
      child: SizedBox(
        height: 36,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / _labels.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF9C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < _labels.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => onSelect(i),
                          borderRadius: BorderRadius.circular(4),
                          child: Center(
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
              ],
            );
          },
        ),
      ),
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

class _ScheduleInfoRow extends StatelessWidget {
  const _ScheduleInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: const Color(0xFF2A2A4A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.shareTechMono(
                color: const Color(0xFFE8E8FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayToggle extends StatelessWidget {
  const _WeekdayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00FF9C) : const Color(0xFF1A1A2E),
          border: Border.all(
            color: selected ? const Color(0xFF00FF9C) : const Color(0xFF2A2A4A),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: selected ? const Color(0xFF0D0D1A) : const Color(0xFF6B6B8A),
          ),
        ),
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

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF00FF9C),
              activeTrackColor: const Color(0xFF00FF9C).withValues(alpha: 0.3),
              inactiveThumbColor: const Color(0xFF6B6B8A),
              inactiveTrackColor: const Color(0xFF2A2A4A),
            ),
          ],
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
