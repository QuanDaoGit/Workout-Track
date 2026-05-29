import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../data/class_definitions.dart';
import '../data/loot_registry.dart';
import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';
import '../models/loot_item.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';

import '../models/profile_models.dart';
import '../models/quest_models.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../models/character_class.dart';
import '../models/class_state.dart';
import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
import '../services/class_service.dart';
import '../services/profile_service.dart';
import '../services/progression_settings_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/stat_engine.dart';
import '../services/loot_service.dart';
import '../services/workout_defaults_service.dart';
import '../services/workout_metric_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/lck_buff_badge.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/rest_icon.dart';
import '../widgets/class_sprite.dart';
import '../widgets/stat_card.dart';
import 'body_metrics_chart_page.dart';
import 'body_metrics_onboarding_page.dart';
import 'goal_selection_page.dart';
import 'inventory_page.dart';
import 'log_weight_page.dart';

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
  bool _showEndBackfillNotice = false;
  ProfileData _profile = ProfileData.defaults();
  Map<LootCategory, LootItem> _equippedLoot = {};
  int _ownedLootCount = 0;
  ClassState? _classState;
  RespecStatus _respecStatus = const RespecStatus(
    RespecAvailability.available,
    0,
  );

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
    final showEndBackfillNotice =
        _showEndBackfillNotice || await StatEngine.consumeEndBackfillNotice();
    final restState = await _restService.refreshWeeklyShieldProgress(sessions);
    final recoveryXP = _restService.effectiveRecoveryXPForState(
      sessions: sessions,
      state: restState,
    );
    final equippedLoot = await _lootService.getEquippedLoot();
    final ownedLootCount = await _lootService.getOwnedCount();
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    final classService = ClassService();
    final classState = await classService.getState();
    final respecStatus = await classService.respecStatus();
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
      _showEndBackfillNotice = showEndBackfillNotice;
      _profile = profile;
      _equippedLoot = equippedLoot;
      _ownedLootCount = ownedLootCount;
      _potionBonusXP = potionBonusXP;
      _classState = classState;
      _respecStatus = respecStatus;
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

  LootItem? get _equippedTitle => _equippedLoot[LootCategory.titleBadge];

  LootItem? get _equippedFrame => _equippedLoot[LootCategory.avatarFrame];

  Future<void> _openInventory() async {
    await Navigator.of(context).push(
      arcadeRoute((_) => const InventoryPage(), motion: ArcadeRouteMotion.fade),
    );
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
          arcadeRoute(
            (_) => const BodyMetricsOnboardingPage(),
            motion: ArcadeRouteMotion.fade,
          ),
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
    await Navigator.push(
      context,
      arcadeRoute((_) => const LogWeightPage(), motion: ArcadeRouteMotion.fade),
    );
    await reload();
  }

  Future<void> _openBodyMetricsChart() async {
    await Navigator.push(
      context,
      arcadeRoute(
        (_) => const BodyMetricsChartPage(),
        motion: ArcadeRouteMotion.fade,
      ),
    );
    await reload();
  }

  Future<void> _changeGoal() async {
    final result = await Navigator.push<GoalSelectionResult>(
      context,
      arcadeRoute(
        (_) => const GoalSelectionPage(),
        motion: ArcadeRouteMotion.fade,
      ),
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
      backgroundColor: kCard,
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
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 14),
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
      backgroundColor: kCard,
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
                      color: valid ? kMutedText : const Color(0xFFFFD700),
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

  void _showWorkoutDefaultsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) => const _WorkoutDefaultsSheet(),
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
    final cls = _classState?.currentClass ?? CharacterClass.bruiser;
    final classColor = cls.themeColor;
    final totalXP =
        XpService.calculateTotalXP(_sessions) +
        summary.claimedRewardXP +
        _recoveryXP +
        _potionBonusXP;
    final level = XpService.getLevel(totalXP);
    final rank = XpService.getRank(level);
    final xpProgress = XpService.progressForTotalXP(totalXP);
    final lck = _combatStats['LCK'] ?? 0;
    final lckMultiplier = XpService.lckXpMultiplier(lck);
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
          padding: const EdgeInsets.all(kSpace4),
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: classColor.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(4),
            boxShadow: neonGlow(color: classColor, opacity: 0.16, blur: 18),
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
                    size: 130,
                    borderColor: classColor,
                    glowColor: classColor,
                  ),
                  const SizedBox(width: kSpace4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _editingName ? _buildNameEditor() : _buildNameBlock(),
                        const SizedBox(height: kSpace3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _RankBadge(label: rank),
                            _StatusBadge(label: 'LV. $level'),
                          ],
                        ),
                        if (_classState?.mostRecentFormerClass != null) ...[
                          const SizedBox(height: kSpace2),
                          Text(
                            'Former path: '
                            '${_classState!.mostRecentFormerClass!.clazz.displayName}',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpace4),
              Row(
                children: [
                  Expanded(
                    child: ArcadeProgressBar(value: xpProgress.fraction),
                  ),
                  if (lckMultiplier > 1.0) ...[
                    const SizedBox(width: 8),
                    LckBuffBadge(multiplier: lckMultiplier, lck: lck),
                  ],
                ],
              ),
              const SizedBox(height: kSpace2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    xpProgress.label,
                    style: const TextStyle(color: kMutedText, fontSize: 11),
                  ),
                  Text(
                    '${summary.claimableCount} rewards ready',
                    style: TextStyle(
                      color: summary.claimableCount > 0 ? kAmber : kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpace3),
        _GlanceMetricsStrip(
          trainingDays: trainingDays,
          completedQuests: completedQuests,
          totalQuests: quests.length,
          titleCount: titleCount,
        ),
        const SizedBox(height: kSpace4),
        StatCard(
          stats: _combatStats,
          showEndBackfillNotice: _showEndBackfillNotice,
        ),
        const SizedBox(height: kSpace3),
        _buildClassSection(),
        const SizedBox(height: kSpace3),
        _buildLootInventoryEntry(),
        if (_bodyMetricsEnabled) ...[
          const SizedBox(height: kSpace3),
          _buildBodyMetricsSection(),
        ],
      ],
    );
  }

  Widget _buildClassSection() {
    final cls = _classState?.currentClass ?? CharacterClass.bruiser;
    final color = cls.themeColor;

    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: Color.lerp(kSurface2, color, 0.08),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: neonGlow(color: color, opacity: 0.12, blur: 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClassSprite(
                assetPath: 'assets/classes/icons/${cls.name}.png',
                placeholderTint: color,
                size: 58,
                placeholderLabel: cls.displayName[0],
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls.displayName,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: color,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    Text(
                      'PATH OF THE ${cls.bodyGoalLabel}',
                      style: AppFonts.shareTechMono(
                        fontSize: 11,
                        color: kMutedText,
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    Text(
                      _classBonusLabel(cls),
                      style: AppFonts.shareTechMono(
                        fontSize: 11,
                        color: kText,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildChangeClassButton(color),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeClassButton(Color color) {
    final status = _respecStatus;
    final (label, enabled) = switch (status.availability) {
      RespecAvailability.locked => (
        'CLASS LOCKED — ${status.daysRemaining} DAYS LEFT',
        false,
      ),
      RespecAvailability.cooldown => (
        'CHANGE CLASS — ${status.daysRemaining} DAYS LEFT',
        false,
      ),
      RespecAvailability.available => ('CHANGE CLASS', true),
    };
    return TextButton(
      onPressed: enabled ? _openRespec : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: kMutedText,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppFonts.shareTechMono(
          color: enabled ? color : kMutedText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  int _currentLevel() {
    final summary = _summary;
    final totalXP =
        XpService.calculateTotalXP(_sessions) +
        (summary?.claimedRewardXP ?? 0) +
        _recoveryXP +
        _potionBonusXP;
    return XpService.getLevel(totalXP);
  }

  Future<void> _openRespec() async {
    final level = _currentLevel();
    final options = await ClassService().availableRespecClasses(level);
    if (!mounted) return;
    final picked = await showModalBottomSheet<CharacterClass>(
      context: context,
      backgroundColor: kSurface2,
      builder: (sheetContext) => _RespecPickerSheet(options: options),
    );
    if (picked == null || !mounted) return;

    final current = _classState?.currentClass ?? CharacterClass.bruiser;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurface3,
        title: const Text(
          'CHANGE CLASS',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: kNeon,
          ),
        ),
        content: Text(
          'Your former path: ${current.displayName} will be recorded on your '
          'guild card. Continue?',
          style: AppFonts.shareTechMono(
            color: kText,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'CONFIRM',
              style: AppFonts.shareTechMono(
                color: picked.themeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ClassService().respec(picked);
    // Quests are derived live from the current class, so reloading recomputes
    // the current week against the new class; past completions are preserved
    // (they're derived from logged sessions, untouched here).
    if (mounted) reload();
  }

  String _classBonusLabel(CharacterClass cls) {
    return switch (cls) {
      CharacterClass.bruiser =>
        'STAT BONUS: +20% STR gain from chest, back, arms training.',
      CharacterClass.assassin =>
        'STAT BONUS: +20% AGI gain from shoulders, core training.',
      CharacterClass.tank => 'STAT BONUS: +20% VIT gain from legs training.',
      CharacterClass.vanguard => 'STAT BONUS: +20% gain on whatever you train.',
    };
  }

  Widget _buildLootInventoryEntry() {
    return HoldDepress(
      onTap: _openInventory,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kSpace4),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const ImageIcon(
              AssetImage('assets/icons/control/icon_bag.png'),
              size: 24,
              color: kAmber,
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOOT INVENTORY · $_ownedLootCount/${lootRegistry.length}',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: kText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: kSpace1),
                  Text(
                    'Frames, titles, and themes live here.',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpace2),
            const Text(
              '>',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: kNeon,
              ),
            ),
          ],
        ),
      ),
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
          HoldDepress(
            onTap: _changeGoal,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kCard,
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
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
        if (goal?.targetWeight != null) ...[
          const SizedBox(height: 4),
          Text(
            'heading toward ${goal!.targetWeight!.toStringAsFixed(1)} kg',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
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
                style: AppFonts.shareTechMono(
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
        PixelButton(
          label: 'VIEW TREND',
          secondary: true,
          onPressed: _openBodyMetricsChart,
        ),
      ],
    );
  }

  Widget _buildNameBlock() {
    final titleItem = _equippedTitle;
    final title = titleItem?.name ?? _summary!.selectedTitle ?? 'untitled';
    final titleColor =
        titleItem?.color ??
        (_summary!.selectedTitle == null
            ? kMutedText
            : const Color(0xFFFFD700));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.shareTechMono(
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
          style: AppFonts.shareTechMono(color: titleColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildNameEditor() {
    return Row(
      children: [
        Expanded(
          child: ArcadeTextField(
            controller: _nameController,
            maxLength: 20,
            onSubmitted: (_) => _saveDisplayName(),
            style: AppFonts.shareTechMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE8E8FF),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
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
          color: kMutedText,
          onPressed: _cancelDisplayNameEdit,
        ),
      ],
    );
  }

  Widget _buildLoadout() {
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
        const SizedBox(height: kSpace5),
        const _SectionHeader(title: 'COSMETICS'),
        const SizedBox(height: kSpace3),
        _buildLootInventoryEntry(),
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
          title: 'Workout Defaults',
          subtitle: 'Duration target and rest timer.',
          onTap: _showWorkoutDefaultsSheet,
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

class _WorkoutDefaultsSheet extends StatefulWidget {
  const _WorkoutDefaultsSheet();

  @override
  State<_WorkoutDefaultsSheet> createState() => _WorkoutDefaultsSheetState();
}

class _WorkoutDefaultsSheetState extends State<_WorkoutDefaultsSheet> {
  final WorkoutDefaultsService _service = WorkoutDefaultsService();
  int _durationMinutes = WorkoutDefaultsService.defaultDurationMinutes;
  int _restSeconds = 90;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final duration = await _service.getDurationMinutes();
    final rest = await _service.getRestSeconds();
    if (!mounted) return;
    setState(() {
      _durationMinutes = duration;
      _restSeconds = rest;
      _loading = false;
    });
  }

  String _fmtRest(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _service.setDurationMinutes(_durationMinutes);
    await _service.setRestSeconds(_restSeconds);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: _loading
          ? const SizedBox(height: 140, child: Center(child: PixelLoader()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    ImageIcon(
                      AssetImage('assets/icons/control/icon_gear.png'),
                      size: 22,
                      color: Color(0xFF00FF9C),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WORKOUT DEFAULTS',
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
                  'Used for quick starts. You can still stop whenever the workout is done.',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                _DefaultStepper(
                  label: 'DURATION TARGET',
                  value: '$_durationMinutes min',
                  onDecrease:
                      _durationMinutes <=
                          WorkoutDefaultsService.minDurationMinutes
                      ? null
                      : () => setState(() => _durationMinutes -= 15),
                  onIncrease:
                      _durationMinutes >=
                          WorkoutDefaultsService.maxDurationMinutes
                      ? null
                      : () => setState(() => _durationMinutes += 15),
                ),
                const SizedBox(height: 10),
                _DefaultStepper(
                  label: 'REST BETWEEN SETS',
                  value: _fmtRest(_restSeconds),
                  onDecrease: _restSeconds <= 30
                      ? null
                      : () => setState(() => _restSeconds -= 15),
                  onIncrease: _restSeconds >= 300
                      ? null
                      : () => setState(() => _restSeconds += 15),
                ),
                const SizedBox(height: 18),
                PixelButton(
                  label: _saving ? 'SAVING...' : 'SAVE DEFAULTS',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }
}

class _DefaultStepper extends StatelessWidget {
  const _DefaultStepper({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: AppFonts.shareTechMono(
                    color: const Color(0xFFE8E8FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _DefaultStepButton(icon: Icons.remove_sharp, onPressed: onDecrease),
          const SizedBox(width: 8),
          _DefaultStepButton(icon: Icons.add_sharp, onPressed: onIncrease),
        ],
      ),
    );
  }
}

class _DefaultStepButton extends StatelessWidget {
  const _DefaultStepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: onPressed == null
            ? const Color(0xFF2A2A3E)
            : const Color(0xFF00FF9C),
        foregroundColor: onPressed == null ? const Color(0xFF555577) : kBg,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Icon(icon, size: 20),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _labels = ['Character', 'Loadout', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
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
                      color: kNeon.withValues(alpha: 0.18),
                      border: Border.all(color: kNeon),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < _labels.length; i++)
                      Expanded(
                        child: PhosphorTap(
                          onTap: () => onSelect(i),
                          borderRadius: BorderRadius.circular(4),
                          child: Center(
                            child: Text(
                              _labels[i].toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 7,
                                color: selectedIndex == i ? kNeon : kMutedText,
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
    return HoldDepress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kCard,
          border: Border.all(
            color: selected ? const Color(0xFF00FF9C) : kBorder,
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

class _GlanceMetricsStrip extends StatelessWidget {
  const _GlanceMetricsStrip({
    required this.trainingDays,
    required this.completedQuests,
    required this.totalQuests,
    required this.titleCount,
  });

  final int trainingDays;
  final int completedQuests;
  final int totalQuests;
  final int titleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace2,
        vertical: kSpace3,
      ),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _GlanceMetricCell(
              iconPath: 'assets/icons/control/icon_time.png',
              label: 'TRAINING',
              value: '$trainingDays',
              caption: 'DAYS THIS WK',
              semanticsLabel: 'Training, $trainingDays days this week',
            ),
          ),
          const _GlanceMetricDivider(),
          Expanded(
            child: _GlanceMetricCell(
              iconPath: 'assets/icons/control/icon_scroll.png',
              label: 'QUESTS',
              value: '$completedQuests/$totalQuests',
              caption: 'CLEARED',
              semanticsLabel:
                  'Quests, $completedQuests of $totalQuests cleared',
            ),
          ),
          const _GlanceMetricDivider(),
          Expanded(
            child: _GlanceMetricCell(
              iconPath: 'assets/icons/control/icon_shield.png',
              label: 'TITLES',
              value: '$titleCount',
              caption: 'EARNED',
              semanticsLabel: 'Titles, $titleCount earned',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlanceMetricDivider extends StatelessWidget {
  const _GlanceMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace1),
      child: SizedBox(
        width: 1,
        height: 56,
        child: ColoredBox(color: kBorder.withValues(alpha: 0.45)),
      ),
    );
  }
}

class _GlanceMetricCell extends StatelessWidget {
  const _GlanceMetricCell({
    required this.iconPath,
    required this.label,
    required this.value,
    required this.caption,
    required this.semanticsLabel,
  });

  final String iconPath;
  final String label;
  final String value;
  final String caption;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ImageIcon(AssetImage(iconPath), size: 14, color: kNeon),
                  const SizedBox(width: kSpace1),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        color: kMutedText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpace2),
              SizedBox(
                height: 22,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: AppFonts.shareTechMono(
                      color: kText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kSpace1),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
              ),
            ],
          ),
        ),
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
        color: kCard,
        border: Border.all(color: kBorder),
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
              style: AppFonts.shareTechMono(
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
    return HoldDepress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00FF9C) : kCard,
          border: Border.all(
            color: selected ? const Color(0xFF00FF9C) : kBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: selected ? kBg : kMutedText,
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
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoldDepress(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: kCard,
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
                      style: const TextStyle(color: kMutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ImageIcon(
                AssetImage('assets/icons/control/icon_next.png'),
                size: 16,
                color: kMutedText,
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
          color: kCard,
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
                    style: const TextStyle(color: kMutedText, fontSize: 12),
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
              inactiveThumbColor: kMutedText,
              inactiveTrackColor: kBorder,
            ),
          ],
        ),
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

/// Bottom sheet listing the classes a user may respec into. Vanguard appears
/// only when [options] includes it (gated by level upstream).
class _RespecPickerSheet extends StatelessWidget {
  const _RespecPickerSheet({required this.options});

  final List<CharacterClass> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CHOOSE NEW CLASS',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: kNeon,
              ),
            ),
            const SizedBox(height: kSpace3),
            for (final cls in options) ...[
              _RespecOption(cls: cls),
              const SizedBox(height: kSpace2),
            ],
          ],
        ),
      ),
    );
  }
}

class _RespecOption extends StatelessWidget {
  const _RespecOption({required this.cls});

  final CharacterClass cls;

  @override
  Widget build(BuildContext context) {
    final color = cls.themeColor;
    return HoldDepress(
      onTap: () => Navigator.of(context).pop(cls),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(kSpace3),
        decoration: BoxDecoration(
          color: Color.lerp(kSurface3, color, 0.08),
          border: Border.all(color: color.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            ClassSprite(
              assetPath: 'assets/classes/icons/${cls.name}.png',
              placeholderTint: color,
              size: 44,
              placeholderLabel: cls.displayName[0],
            ),
            const SizedBox(width: kSpace3),
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
                  const SizedBox(height: kSpace1),
                  Text(
                    focusMusclesLabel(cls),
                    style: AppFonts.shareTechMono(
                      fontSize: 11,
                      color: kMutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
