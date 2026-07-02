import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_fonts.dart';

import '../data/class_definitions.dart';
import '../data/loot_registry.dart';
import '../models/body_goal_models.dart';
import '../models/body_metrics_models.dart';
import '../models/weight_trend.dart';
import '../models/loot_item.dart';
import '../models/unit_models.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import '../widgets/session_projection.dart';
import '../widgets/weekday_picker.dart';

import '../data/programs_library.dart';
import '../models/profile_models.dart';
import '../models/quest_models.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../models/character_class.dart';
import '../models/class_state.dart';
import '../services/analytics_consent_service.dart';
import '../services/analytics_service.dart';
import '../services/body_goal_service.dart';
import '../services/body_metrics_service.dart';
import '../services/calibration_service.dart';
import '../services/class_service.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../services/profile_service.dart';
import '../services/program_service.dart';
import '../services/progression_settings_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/haptic_service.dart';
import '../services/haptic_settings_service.dart';
import '../services/sfx_service.dart';
import '../services/simple_mode_service.dart';
import '../services/sound_settings_service.dart';
import '../services/stat_engine.dart';
import '../services/loot_service.dart';
import '../services/unit_settings_service.dart';
import '../services/workout_defaults_service.dart';
import '../services/workout_metric_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_bar.dart';
import '../widgets/arcade_badge.dart';
import '../widgets/identity_stamp_line.dart';
import '../widgets/arcade_route.dart';
import '../widgets/lck_buff_badge.dart';
import '../widgets/loot_avatar_frame.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/rest_icon.dart';
import '../widgets/class_sprite.dart';
import '../widgets/stat_card.dart';
import 'avatar_customizer_page.dart';
import 'body_metrics_chart_page.dart';
import 'body_metrics_onboarding_page.dart';
import 'goal_selection_page.dart';
import 'inventory_page.dart';
import 'log_weight_page.dart';
import 'shop_page.dart';
import 'workout_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onProfileChanged});

  final VoidCallback? onProfileChanged;

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
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
  bool _simpleMode = false;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _restAlertEnabled = true;
  bool _trainingReminderEnabled = false;
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = false;
  int _trainingReminderMinutes =
      NotificationSettingsService.defaultTrainingReminderMinutes;
  BodyGoalState? _bodyGoalState;
  WeightEntry? _lastWeightEntry;
  List<WeightEntry> _weightEntries = const [];
  bool _canEarnReward = false;
  int _daysUntilNextReward = 0;
  String? _activeBoostLabel;
  double? _heightCm;
  Map<String, int> _combatStats = {
    for (final stat in StatEngine.stats) stat: 0,
  };
  ProfileData _profile = ProfileData.defaults();
  Map<LootCategory, LootItem> _equippedLoot = {};
  int _ownedLootCount = 0;
  int _ownedTitleCount = 0;
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
    final restState = await _restService.refreshWeeklyShieldProgress(sessions);
    final recoveryXP = _restService.effectiveRecoveryXPForState(
      sessions: sessions,
      state: restState,
    );
    final equippedLoot = await _lootService.getEquippedLoot();
    final ownedLootCount = await _lootService.getOwnedCount();
    final ownedTitleCount = (await _lootService.getInventory())
        .where((i) => i.category == LootCategory.titleBadge && !i.isDefault)
        .length;
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    final classService = ClassService();
    final classState = await classService.getState();
    final respecStatus = await classService.respecStatus();
    final metricsService = BodyMetricsService();
    final bodyMetricsEnabled = await metricsService.isEnabled();
    final progressionEnabled = await ProgressionSettingsService().isEnabled();
    final simpleModeEnabled = await SimpleModeService().isEnabled();
    final soundEnabled = await SoundSettingsService().isEnabled();
    final hapticsEnabled = await HapticSettingsService().isEnabled();
    final restAlertEnabled = await NotificationSettingsService()
        .isRestTimerAlertEnabled();
    final trainingReminderEnabled = await NotificationSettingsService()
        .isTrainingReminderEnabled();
    final trainingReminderMinutes = await NotificationSettingsService()
        .trainingReminderMinutes();
    final analyticsEnabled = await AnalyticsConsentService().analyticsEnabled();
    final crashReportingEnabled = await AnalyticsConsentService()
        .crashReportingEnabled();
    final heightCm = await CalibrationService().heightCm();
    BodyGoalState? bodyGoalState;
    WeightEntry? lastWeightEntry;
    List<WeightEntry> weightEntries = const [];
    bool canEarnReward = false;
    int daysUntilNextReward = 0;
    String? activeBoostLabel;
    if (bodyMetricsEnabled) {
      bodyGoalState = await BodyGoalService().getGoalState();
      weightEntries = await metricsService.getEntries();
      lastWeightEntry = weightEntries.isEmpty ? null : weightEntries.last;
      canEarnReward = await metricsService.canEarnReward();
      daysUntilNextReward = await metricsService.daysUntilNextReward();
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
      _ownedTitleCount = ownedTitleCount;
      _potionBonusXP = potionBonusXP;
      _classState = classState;
      _respecStatus = respecStatus;
      _bodyMetricsEnabled = bodyMetricsEnabled;
      _progressionEnabled = progressionEnabled;
      _simpleMode = simpleModeEnabled;
      _soundEnabled = soundEnabled;
      _hapticsEnabled = hapticsEnabled;
      _restAlertEnabled = restAlertEnabled;
      _trainingReminderEnabled = trainingReminderEnabled;
      _trainingReminderMinutes = trainingReminderMinutes;
      _analyticsEnabled = analyticsEnabled;
      _crashReportingEnabled = crashReportingEnabled;
      _bodyGoalState = bodyGoalState;
      _lastWeightEntry = lastWeightEntry;
      _weightEntries = weightEntries;
      _canEarnReward = canEarnReward;
      _daysUntilNextReward = daysUntilNextReward;
      _activeBoostLabel = activeBoostLabel;
      _heightCm = heightCm;
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

  Future<void> _openAvatarCustomizer() async {
    final saved = await Navigator.of(context).push<bool>(
      arcadeRoute(
        (_) => const AvatarCustomizerPage(),
        motion: ArcadeRouteMotion.fade,
      ),
    );
    if (saved == true) {
      await reload();
      widget.onProfileChanged?.call();
    }
  }

  /// The identity frame doubles as the avatar-edit entry — tap to open the
  /// customizer. A small brush chip keeps the affordance discoverable.
  Widget _buildAvatarEntry({double size = 130}) {
    // No equipped frame falls back to the default iron frame, so the identity
    // tile always has exactly one border source (never a bare box).
    final frame = _equippedFrame ?? lootItemById('frame_iron');
    return Semantics(
      button: true,
      label: 'Edit avatar',
      child: HoldDepress(
        onTap: _openAvatarCustomizer,
        haptic: HapticIntent.selection,
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            LootAvatarFrame(
              avatarSpec: _profile.avatarSpec,
              framePath: frame?.assetPath,
              frameCount: frame?.frameCount ?? 1,
              animate: true,
              size: size,
              // Seat the face ~1 grid row lower so it reads optically centred in
              // the hero well (the sprite is top-biased — see avatarDropPx).
              avatarDropPx: size * 0.76 / 20,
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                key: const ValueKey('profile_avatar_edit_chip'),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kBg,
                  border: Border.all(color: kBorderVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const ImageIcon(
                  AssetImage('assets/icons/control/icon_brush.png'),
                  size: 12,
                  color: kNeon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      arcadeRoute((_) => const ShopPage(), motion: ArcadeRouteMotion.fade),
    );
    await reload();
    widget.onProfileChanged?.call();
  }

  /// Programs + Exercise library, re-homed under Labs from the dropped Workout
  /// tab (the area restructure). Reused wholesale via [WorkoutLibraryPage].
  Future<void> _openLibrary() async {
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => const WorkoutLibraryPage(),
        motion: ArcadeRouteMotion.fade,
      ),
    );
    await reload();
    widget.onProfileChanged?.call();
  }

  /// Workout history / calendar / analytics — the second discoverable door to
  /// the log (the first is Home's last-workout card). Both routes land on the
  /// same [WorkoutLogsPage]; before this, the log was reachable only via an
  /// unlabelled tap on Home's LCK pip.
  Future<void> _openLogs() async {
    await Navigator.of(context).push(
      arcadeRoute(
        (_) => const WorkoutLogsPage(),
        motion: ArcadeRouteMotion.fade,
      ),
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

  Future<void> _toggleSimpleMode(bool value) async {
    await SimpleModeService().setEnabled(value);
    if (!mounted) return;
    setState(() => _simpleMode = value);
  }

  Future<void> _toggleAnalytics(bool value) async {
    // The toggle reads as "analytics ON"; the stored flag is the inverse
    // (opt-out). The facade also flips SDK collection immediately.
    await AnalyticsService.instance.setAnalyticsOptedOut(!value);
    if (!mounted) return;
    setState(() => _analyticsEnabled = value);
  }

  Future<void> _toggleCrashReporting(bool value) async {
    // Opt-in; Sentry initializes in main(), so a change applies next launch.
    await AnalyticsConsentService().setCrashReportingOptedIn(value);
    if (!mounted) return;
    setState(() => _crashReportingEnabled = value);
  }

  Future<void> _openPrivacyPolicy() async {
    const url = 'https://quandaogit.github.io/ironbit-privacy/';
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Fall through to the in-app fallback below.
    }
    if (!mounted) return;
    _showComingSoon(
      title: 'Privacy Policy',
      description: 'Open it in your browser:\n$url',
      iconPath: 'assets/icons/control/icon_lock.png',
    );
  }

  Future<void> _toggleSound(bool value) async {
    await SoundSettingsService().setEnabled(value);
    SfxService.enabled = value;
    if (!mounted) return;
    setState(() => _soundEnabled = value);
  }

  Future<void> _toggleHaptics(bool value) async {
    await HapticSettingsService().setEnabled(value);
    HapticService.enabled = value;
    // Turning ON: the row's own selection() tick fired while haptics were still
    // off (muted), so play a confirmation tick now that the flag is live.
    if (value) HapticService.instance.selection();
    if (!mounted) return;
    setState(() => _hapticsEnabled = value);
  }

  Future<void> _toggleRestAlert(bool value) async {
    await NotificationSettingsService().setRestTimerAlertEnabled(value);
    // Enabling is the contextual moment to ask the OS for permission (never a
    // cold launch-time ask). A denial is respected silently — the toggle still
    // reflects the user's intent and is simply inert until permission is granted.
    // Mark the one-time ask done so the first-workout prompt won't re-fire.
    if (value) {
      await NotificationSettingsService().setRestPermAsked(true);
      await NotificationService.instance.requestPermissions();
    }
    if (!mounted) return;
    setState(() => _restAlertEnabled = value);
  }

  Future<void> _toggleTrainingReminder(bool value) async {
    await NotificationSettingsService().setTrainingReminderEnabled(value);
    // Enabling is the contextual moment to ask the OS for permission. The
    // reconcile then schedules (or, if denied / turned off, clears) the weekly
    // reminders to match the new state.
    if (value) {
      await NotificationService.instance.requestPermissions();
    }
    await NotificationService.instance.syncTrainingReminders();
    if (!mounted) return;
    setState(() => _trainingReminderEnabled = value);
  }

  Future<void> _pickReminderTime() async {
    final current = TimeOfDay(
      hour: _trainingReminderMinutes ~/ 60,
      minute: _trainingReminderMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await NotificationSettingsService().setTrainingReminderMinutes(minutes);
    await NotificationService.instance.syncTrainingReminders();
    if (!mounted) return;
    setState(() => _trainingReminderMinutes = minutes);
  }

  String _formatReminderTime(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final period = h24 < 12 ? 'AM' : 'PM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
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
                  ImageIcon(AssetImage(iconPath), size: 22, color: kNeon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: kText,
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

  Future<void> _showTrainingGoalsSheet() async {
    var selected = Set<int>.from(
      _restState.pendingTrainingWeekdays ?? _restState.trainingWeekdays,
    );
    // The active program (if any) lets the sheet show which session lands on
    // each chosen weekday — the legibility win that makes the picker feel wired.
    final progress = await ProgramService().getActiveProgress();
    final program = progress == null ? null : programById(progress.programId);
    if (!mounted) return;

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
                        color: kNeon,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'TRAINING GOALS',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: kNeon,
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
                  WeekdayPicker(
                    selected: selected,
                    onToggle: (weekday) {
                      setSheetState(() {
                        if (selected.contains(weekday)) {
                          selected.remove(weekday);
                        } else {
                          selected.add(weekday);
                        }
                      });
                    },
                  ),
                  if (program != null && valid) ...[
                    const SizedBox(height: 18),
                    SessionProjection(selected: selected, program: program),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    valid
                        ? 'Changes start next Monday.'
                        : 'Choose at least one training day and one rest day.',
                    style: TextStyle(
                      color: valid ? kMutedText : kAmber,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PixelButton(
                    label: 'SAVE FOR NEXT WEEK',
                    onPressed: valid
                        ? () async {
                            await _restService.saveTrainingWeekdays(selected);
                            // Re-arm training reminders against the new schedule
                            // (reconcile clears stale weekdays first).
                            await NotificationService.instance
                                .syncTrainingReminders();
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

  Future<void> _showUnitsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) => const _UnitsSheet(),
    );
    if (!mounted) return;
    await reload(); // re-render every converted display in the new unit
  }

  Future<void> _showHeightSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) => const _HeightSheet(),
    );
    if (!mounted) return;
    await reload();
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
            onPressed: () {
              HapticService.instance.selection();
              _toggleEditMode();
            },
            icon: ImageIcon(
              const AssetImage('assets/icons/control/icon_hammer.png'),
              color: _editingName ? kAmber : kNeon,
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
    final lck = _combatStats['LCK'] ?? 0;
    final lckMultiplier = XpService.lckXpMultiplier(lck);
    final trainingDays = WorkoutMetricService.trainingDaysThisWeek(_sessions);
    final quests = [
      ...summary.dailyQuests,
      ...summary.weeklyQuests,
      ...summary.sideQuests,
    ];
    final completedQuests = quests.where((quest) => quest.completed).length;
    final titleCount = _ownedTitleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('profile_guild_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace4),
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: kBorderVariant.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The character is the hero: the framed pixel-face avatar, large
              // and centred in its own recessed `kBg` well (figure-ground), is
              // the single focal element — hierarchy by size + position, not
              // colour (neon stays the action/meter, never the identity frame).
              Center(child: _buildAvatarEntry(size: 150)),
              const SizedBox(height: kSpace3),
              // Name (white identity hero) + equipped title epithet directly
              // beneath it, centred under the avatar.
              _editingName
                  ? _buildNameEditor()
                  : _buildNameBlock(centered: true),
              const SizedBox(height: kSpace2),
              // One typographic competence line: the earned RANK as the colour-
              // laddered headline + the quieter muted LEVEL detail — replaces the
              // two stacked filled chips so rank stays the single identity cue.
              Center(
                child: IdentityStampLine(level: level, rank: rank),
              ),
              const SizedBox(height: kSpace4),
              Row(
                children: [
                  Expanded(child: ArcadeBar(value: xpProgress.fraction)),
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
                  // Flexible + ellipsis so the dual readout never overflows at a
                  // narrow width × large text (320dp × 1.3 matrix).
                  Flexible(
                    child: Text(
                      xpProgress.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMutedText, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  Flexible(
                    child: Text(
                      '${summary.claimableCount} rewards ready',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: summary.claimableCount > 0 ? kAmber : kMutedText,
                        fontSize: 11,
                      ),
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
        StatCard(stats: _combatStats),
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
      key: const ValueKey('profile_class_section'),
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: kBorder.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                key: const ValueKey('profile_class_accent_rail'),
                width: 4,
                height: 58,
                color: color,
              ),
              const SizedBox(width: kSpace3),
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
            child: _buildChangeClassButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeClassButton() {
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
      onPressed: enabled
          ? () {
              HapticService.instance.selection();
              _openRespec();
            }
          : null,
      style: TextButton.styleFrom(
        foregroundColor: kNeon,
        disabledForegroundColor: kMutedText,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppFonts.shareTechMono(
          color: enabled ? kNeon : kMutedText,
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
      CharacterClass.tank => 'STAT BONUS: +20% END gain from legs training.',
    };
  }

  Widget _buildLootInventoryEntry() {
    return PhosphorTap(
      borderRadius: BorderRadius.circular(4),
      child: HoldDepress(
        onTap: _openInventory,
        haptic: HapticIntent.selection,
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
                      'LOADOUT INVENTORY · $_ownedLootCount/${lootRegistry.length}',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: kText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    Text(
                      'Owned frames and titles live here.',
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
      ),
    );
  }

  Widget _buildGemShopEntry() {
    return PhosphorTap(
      borderRadius: BorderRadius.circular(4),
      child: HoldDepress(
        onTap: _openShop,
        haptic: HapticIntent.selection,
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
              Image.asset(
                'assets/icons/economy/icon_gem.png',
                width: 24,
                height: 24,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GEM SHOP',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: kNeon,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    Text(
                      'Spend earned gems on locked frames and themes.',
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
      ),
    );
  }

  Widget _buildBodyMetricsSection() {
    final goal = _bodyGoalState;
    final lastEntry = _lastWeightEntry;

    String checkInLabel = 'No check-ins yet';
    if (lastEntry != null) {
      final daysAgo = DateTime.now().difference(lastEntry.loggedAt).inDays;
      final timeLabel = daysAgo == 0
          ? 'today'
          : daysAgo == 1
          ? 'yesterday'
          : '$daysAgo days ago';
      checkInLabel =
          'Last check-in · $timeLabel · ${formatWeight(lastEntry.weightKg, Units.weight)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'BODY METRICS'),
        const SizedBox(height: 10),
        // Act-first status: a calm "ready" chip while the weekly reward window
        // is open, otherwise a muted countdown. Never weight-change framing.
        if (_canEarnReward)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: kNeon),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'CHECK-IN READY',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: kNeon,
              ),
            ),
          )
        else
          Text(
            'Next reward in $_daysUntilNextReward '
            '${_daysUntilNextReward == 1 ? 'day' : 'days'}',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
        const SizedBox(height: 10),
        Text(
          checkInLabel,
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
        if (trendIsReady(_weightEntries)) ...[
          const SizedBox(height: 12),
          _TrendSparkline(_weightEntries),
        ],
        if (goal != null) ...[
          const SizedBox(height: 8),
          HoldDepress(
            onTap: _changeGoal,
            haptic: HapticIntent.selection,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'GOAL \u00b7 ${goal.goalLabel}'
                    '${goal.targetWeight != null ? ' \u00b7 heading toward ${formatWeight(goal.targetWeight!, Units.weight)}' : ''}',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_sharp, size: 12, color: kMutedText),
              ],
            ),
          ),
        ],
        if (_activeBoostLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const ImageIcon(
                AssetImage('assets/icons/control/icon_potion.png'),
                color: kAmber,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _activeBoostLabel!,
                style: AppFonts.shareTechMono(
                  color: kAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        PixelButton(label: 'LOG WEIGHT', onPressed: _openLogWeight),
        const SizedBox(height: 8),
        PixelButton(
          label: 'VIEW TREND',
          secondary: true,
          onPressed: _openBodyMetricsChart,
        ),
      ],
    );
  }

  Widget _buildNameBlock({bool centered = false}) {
    final titleItem = _equippedTitle;
    final title = titleItem?.name ?? 'untitled';
    final titleColor = titleItem?.color ?? kMutedText;
    final align = centered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          _profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: AppFonts.shareTechMono(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: kText,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
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
            maxLength: ProfileData.maxNameLength,
            onSubmitted: (_) => _saveDisplayName(),
            style: AppFonts.shareTechMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kText,
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
          color: kNeon,
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
        const _SectionHeader(title: 'COSMETICS'),
        const SizedBox(height: kSpace3),
        _buildLootInventoryEntry(),
        const SizedBox(height: kSpace3),
        _buildGemShopEntry(),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'TRAINING'),
        const SizedBox(height: 10),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_timeline.png',
          title: 'Training Log',
          subtitle: 'History, calendar, and stats.',
          onTap: _openLogs,
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_sword.png',
          title: 'Training Library',
          subtitle: 'Programs and exercises.',
          onTap: _openLibrary,
        ),
        const SizedBox(height: kSpace4),
        const _SectionHeader(title: 'PLAYER SETUP'),
        const SizedBox(height: 10),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/ui/icon_body_metrics.png',
          title: 'Body Metrics',
          subtitle: _bodyMetricsEnabled
              ? 'Weight tracking active.'
              : 'Opt-in weight tracking.',
          value: _bodyMetricsEnabled,
          onChanged: _toggleBodyMetrics,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_visibility_off.png',
          title: 'Simple Mode',
          subtitle: _simpleMode
              ? 'Streamlined — warm-up tips, suggestions, and curated defaults hidden.'
              : 'Hide warm-up tips, load suggestions, and curated defaults.',
          value: _simpleMode,
          onChanged: _toggleSimpleMode,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/ui/icon_suggested_loads.png',
          title: 'Suggested loads',
          subtitle: _simpleMode
              ? 'Off while Simple Mode is on.'
              : _progressionEnabled
              ? 'TRY: prompts on Set 1 of each exercise.'
              : 'No suggestions — every set entry blank.',
          value: _progressionEnabled,
          onChanged: _toggleProgression,
          enabled: !_simpleMode,
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
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_stat.png',
          title: 'Units',
          subtitle:
              'Weight in ${Units.weight.labelUpper} · height in ${Units.height.labelUpper}.',
          onTap: _showUnitsSheet,
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_stat.png',
          title: 'Height',
          subtitle: _heightCm != null
              ? formatHeight(_heightCm!, Units.height)
              : 'Not set — tap to add.',
          onTap: _showHeightSheet,
        ),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'APP SUPPORT'),
        const SizedBox(height: 10),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_sound.png',
          title: 'Sound',
          subtitle: _soundEnabled
              ? 'Arcade sound effects on.'
              : 'Muted — no sound effects.',
          value: _soundEnabled,
          onChanged: _toggleSound,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/ui/sound-haptic-ring.png',
          title: 'Haptics',
          subtitle: _hapticsEnabled
              ? 'Buttons and rewards give a tactile buzz.'
              : 'Off — no vibration feedback.',
          value: _hapticsEnabled,
          onChanged: _toggleHaptics,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_bell.png',
          title: 'Rest Timer Alert',
          subtitle: _restAlertEnabled
              ? 'Pings you when a rest ends, even in another app.'
              : 'Off — no rest-end alert.',
          value: _restAlertEnabled,
          onChanged: _toggleRestAlert,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_bell.png',
          title: 'Training Reminders',
          subtitle: _trainingReminderEnabled
              ? 'A gentle nudge on your training days.'
              : 'Off — no training-day reminders.',
          value: _trainingReminderEnabled,
          onChanged: _toggleTrainingReminder,
        ),
        if (_trainingReminderEnabled)
          _SettingsRow(
            iconPath: 'assets/icons/control/icon_time.png',
            title: 'Reminder Time',
            subtitle: _formatReminderTime(_trainingReminderMinutes),
            onTap: _pickReminderTime,
          ),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'DATA & PRIVACY'),
        const SizedBox(height: 10),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_graph.png',
          title: 'Usage Analytics',
          subtitle: _analyticsEnabled
              ? 'Anonymous — no workouts, names, or weights leave your device.'
              : 'Off — no usage data is collected.',
          value: _analyticsEnabled,
          onChanged: _toggleAnalytics,
        ),
        _SettingsToggleRow(
          iconPath: 'assets/icons/control/icon_beetle.png',
          title: 'Crash Reports',
          subtitle: _crashReportingEnabled
              ? 'Anonymous crash diagnostics on (takes effect next launch).'
              : 'Off — opt in to send anonymous crash reports.',
          value: _crashReportingEnabled,
          onChanged: _toggleCrashReporting,
        ),
        _SettingsRow(
          iconPath: 'assets/icons/control/icon_lock.png',
          title: 'Privacy Policy',
          subtitle: 'How your data is handled. Opens in your browser.',
          onTap: _openPrivacyPolicy,
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
        const SizedBox(height: 18),
        const _SectionHeader(title: 'ABOUT'),
        const SizedBox(height: 10),
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
          iconPath: 'assets/icons/control/ui/icon_about.png',
          title: 'About',
          subtitle: 'Version, credits, and app notes.',
          onTap: () => _showComingSoon(
            title: 'About',
            description: 'Version details and credits will live here later.',
            iconPath: 'assets/icons/control/ui/icon_about.png',
          ),
        ),
      ],
    );
  }
}

/// Settings sheet to pick the app-wide weight + height units. Selections apply
/// live (persist to [Units]); the caller reloads on close to re-render displays.
class _UnitsSheet extends StatefulWidget {
  const _UnitsSheet();

  @override
  State<_UnitsSheet> createState() => _UnitsSheetState();
}

class _UnitsSheetState extends State<_UnitsSheet> {
  WeightUnit _weight = Units.weight;
  LengthUnit _height = Units.height;

  Future<void> _setWeight(WeightUnit u) async {
    await Units.setWeight(u);
    if (!mounted) return;
    setState(() => _weight = u);
  }

  Future<void> _setHeight(LengthUnit u) async {
    await Units.setHeight(u);
    if (!mounted) return;
    setState(() => _height = u);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ImageIcon(
                AssetImage('assets/icons/control/icon_stat.png'),
                size: 22,
                color: kNeon,
              ),
              SizedBox(width: 10),
              Text(
                'UNITS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: kNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'WEIGHT',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _SheetToggle(
            options: const ['KG', 'LBS'],
            selectedIndex: _weight == WeightUnit.kg ? 0 : 1,
            onSelect: (i) =>
                _setWeight(i == 0 ? WeightUnit.kg : WeightUnit.lbs),
          ),
          const SizedBox(height: 18),
          Text(
            'HEIGHT',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _SheetToggle(
            options: const ['CM', 'FT-IN'],
            selectedIndex: _height == LengthUnit.cm ? 0 : 1,
            onSelect: (i) =>
                _setHeight(i == 0 ? LengthUnit.cm : LengthUnit.ftIn),
          ),
          const SizedBox(height: 20),
          PixelButton(
            label: 'DONE',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Two-option segmented toggle styled with theme tokens (selected = neon fill).
class _SheetToggle extends StatelessWidget {
  const _SheetToggle({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedIndex == i ? kNeon : kCard,
                  border: Border.all(
                    color: selectedIndex == i ? kNeon : kBorder,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  options[i],
                  style: AppFonts.shareTechMono(
                    color: selectedIndex == i ? kBg : kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Settings sheet to view/edit body height, entered in the active length unit
/// and stored canonical in centimetres via [CalibrationService].
class _HeightSheet extends StatefulWidget {
  const _HeightSheet();

  @override
  State<_HeightSheet> createState() => _HeightSheetState();
}

class _HeightSheetState extends State<_HeightSheet> {
  final CalibrationService _service = CalibrationService();
  final TextEditingController _cmCtrl = TextEditingController();
  final TextEditingController _feetCtrl = TextEditingController();
  final TextEditingController _inchCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cm = await _service.heightCm();
    if (!mounted) return;
    setState(() {
      if (cm != null) {
        if (Units.height == LengthUnit.cm) {
          _cmCtrl.text = cm.round().toString();
        } else {
          final h = cmToFeetInches(cm);
          _feetCtrl.text = h.feet.toString();
          _inchCtrl.text = h.inches.toString();
        }
      }
      _loading = false;
    });
  }

  double? get _heightCm {
    if (Units.height == LengthUnit.cm) {
      final v = double.tryParse(_cmCtrl.text.trim());
      return (v != null && v > 0) ? v : null;
    }
    final ft = int.tryParse(_feetCtrl.text.trim()) ?? 0;
    final inch = int.tryParse(_inchCtrl.text.trim()) ?? 0;
    if (ft <= 0 && inch <= 0) return null;
    return feetInchesToCm(ft, inch);
  }

  @override
  void dispose() {
    _cmCtrl.dispose();
    _feetCtrl.dispose();
    _inchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _service.saveHeightCm(_heightCm);
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
        20 +
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: _loading
          ? const SizedBox(height: 140, child: Center(child: PixelLoader()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ImageIcon(
                      AssetImage('assets/icons/control/icon_stat.png'),
                      size: 22,
                      color: kNeon,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'HEIGHT (${Units.height.labelUpper})',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: kNeon,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildField(),
                const SizedBox(height: 18),
                PixelButton(
                  label: _saving ? 'SAVING...' : 'SAVE',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }

  Widget _buildField() {
    if (Units.height == LengthUnit.cm) {
      return ArcadeTextField(
        controller: _cmCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppFonts.shareTechMono(color: kText, fontSize: 18),
        hintText: 'e.g. 180',
        suffixText: 'cm',
        suffixStyle: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
      );
    }
    return Row(
      children: [
        Expanded(
          child: ArcadeTextField(
            controller: _feetCtrl,
            keyboardType: TextInputType.number,
            style: AppFonts.shareTechMono(color: kText, fontSize: 18),
            hintText: 'e.g. 5',
            suffixText: 'ft',
            suffixStyle: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArcadeTextField(
            controller: _inchCtrl,
            keyboardType: TextInputType.number,
            style: AppFonts.shareTechMono(color: kText, fontSize: 18),
            hintText: 'e.g. 11',
            suffixText: 'in',
            suffixStyle: AppFonts.shareTechMono(
              color: kMutedText,
              fontSize: 12,
            ),
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
                      color: kNeon,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WORKOUT DEFAULTS',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 11,
                          color: kNeon,
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
                    color: kAmber,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: AppFonts.shareTechMono(
                    color: kText,
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
        backgroundColor: onPressed == null ? kBorderDark : kNeon,
        foregroundColor: onPressed == null ? kDim : kBg,
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
                          haptic: HapticIntent.selection,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      ArcadeBadge(label: label, color: kNeon, filled: true);
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
              color: kMutedText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppFonts.shareTechMono(
                color: kText,
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
        haptic: HapticIntent.selection,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ImageIcon(AssetImage(iconPath), size: 20, color: kNeon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kText,
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
    this.enabled = true,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// When false the row dims and its switch is inert — used to show a setting
  /// that another toggle (Simple Mode) is currently overriding.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ImageIcon(AssetImage(iconPath), size: 20, color: kNeon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kText,
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
                // Every settings toggle ticks on flip (the Haptics toggle's own
                // enable-confirmation is handled in its setter). Inert when the
                // row is overridden by another setting.
                onChanged: enabled
                    ? (v) {
                        HapticService.instance.selection();
                        onChanged(v);
                      }
                    : null,
                activeThumbColor: kNeon,
                activeTrackColor: kNeon.withValues(alpha: 0.3),
                inactiveThumbColor: kMutedText,
                inactiveTrackColor: kBorder,
              ),
            ],
          ),
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
        onPressed: () {
          HapticService.instance.selection();
          onPressed();
        },
        icon: ImageIcon(AssetImage(iconPath), color: color, size: 18),
      ),
    );
  }
}

/// Bottom sheet listing the classes a user may respec into (the [options]
/// computed upstream, excluding the current class).
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
      haptic: HapticIntent.selection,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        key: ValueKey('profile_respec_option_${cls.name}'),
        padding: const EdgeInsets.all(kSpace3),
        decoration: BoxDecoration(
          color: kSurface3,
          border: Border.all(color: kBorder.withValues(alpha: 0.85)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(width: 3, height: 44, color: color),
            const SizedBox(width: kSpace3),
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

/// A tiny, muted preview of the body-weight trend for the Profile Body card.
/// Shown only once [trendIsReady]; the full neon chart lives behind VIEW TREND.
class _TrendSparkline extends StatelessWidget {
  const _TrendSparkline(this.entries);

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final trend = computeTrend(entries);
    if (trend.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(trend)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.trend);

  final List<TrendPoint> trend;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = [for (final p in trend) p.at.millisecondsSinceEpoch.toDouble()];
    final ys = [for (final p in trend) p.trendKg];
    final minX = xs.first;
    final maxX = xs.last;
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final spanX = maxX - minX == 0 ? 1.0 : maxX - minX;
    final spanY = maxY - minY == 0 ? 1.0 : maxY - minY;

    final path = Path();
    for (var i = 0; i < trend.length; i++) {
      final dx = (xs[i] - minX) / spanX * size.width;
      // Inset vertically so the 1.5px stroke is never clipped at the edges.
      final dy = size.height - 1.5 - (ys[i] - minY) / spanY * (size.height - 3);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = kMutedText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.trend != trend;
}
