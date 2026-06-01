import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_fonts.dart';

import '../data/curated_exercises.dart';
import '../data/muscle_groups.dart';
import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../services/exercise_catalog_service.dart';
import '../services/favorite_service.dart';
import '../services/quest_service.dart';
import '../services/rest_service.dart';
import '../services/workout_metric_service.dart';
import '../services/workout_storage_service.dart';
import '../services/xp_boost_service.dart';
import '../services/xp_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_chip.dart';
import '../widgets/arcade_progress_bar.dart';
import '../widgets/arcade_route.dart';
import '../widgets/calendar_day_marker.dart';
import '../widgets/exercise_card.dart';
import '../widgets/motion/arcade_text_field.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/motion/phosphor_tap.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_loader.dart';
import 'Workout session/session_detail.dart';
import 'Workout session/start_workout.dart';
import 'calendar_page.dart';
import 'create_exercise_page.dart';
import 'exercise_detail.dart';
import 'programs_library_page.dart';

String fmtVol(double v) {
  final rounded = v.round();
  if (rounded < 1000) return rounded.toString();
  final s = rounded.toString();
  final buf = StringBuffer();
  final start = s.length % 3;
  if (start > 0) buf.write(s.substring(0, start));
  for (int i = start; i < s.length; i += 3) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(s.substring(i, i + 3));
  }
  return buf.toString();
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  WorkoutPageState createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _reloadToken = 0;

  void reload() {
    if (!mounted) return;
    setState(() => _reloadToken++);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabSettled);
  }

  void _onTabSettled() {
    if (_tabController.indexIsChanging) return;
    _recordSubTabView(_tabController.index == 0 ? 'logs' : 'library');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'LOGS'),
            Tab(text: 'LIBRARY'),
          ],
          labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
          indicatorColor: kNeon,
          labelColor: kNeon,
          unselectedLabelColor: kMutedText,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LogsTab(reloadToken: _reloadToken),
                _LibraryTab(reloadToken: _reloadToken),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logs Tab (History ⇄ Trends) ──────────────────────────────────────────────

class _LogsTab extends StatefulWidget {
  const _LogsTab({required this.reloadToken});

  final int reloadToken;

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

enum _LogsView { history, trends }

class _LogsTabState extends State<_LogsTab> {
  _LogsView _view = _LogsView.history;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _SubTabToggle(
            labels: const ['HISTORY', 'TRENDS'],
            selectedIndex: _view == _LogsView.history ? 0 : 1,
            onChanged: (i) {
              setState(
                () => _view = i == 0 ? _LogsView.history : _LogsView.trends,
              );
              _recordSubTabView(i == 0 ? 'history' : 'trends');
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view == _LogsView.history ? 0 : 1,
            children: [
              _HistoryTab(reloadToken: widget.reloadToken),
              _StatsTab(reloadToken: widget.reloadToken),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Library Tab (Programs ⇄ Exercises) ───────────────────────────────────────

class _LibraryTab extends StatefulWidget {
  const _LibraryTab({required this.reloadToken});

  final int reloadToken;

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

enum _LibraryView { programs, exercises }

class _LibraryTabState extends State<_LibraryTab> {
  _LibraryView _view = _LibraryView.programs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _SubTabToggle(
            labels: const ['PROGRAMS', 'EXERCISES'],
            selectedIndex: _view == _LibraryView.programs ? 0 : 1,
            onChanged: (i) {
              setState(
                () => _view = i == 0
                    ? _LibraryView.programs
                    : _LibraryView.exercises,
              );
              _recordSubTabView(i == 0 ? 'programs' : 'exercises');
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view == _LibraryView.programs ? 0 : 1,
            children: [
              ProgramsLibraryBody(
                embedded: true,
                reloadToken: widget.reloadToken,
              ),
              const _ExercisesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

/// Local-only usage counter per Workout sub-view (no UI, no PII). Informs
/// future IA decisions about which sub-tabs are actually used.
Future<void> _recordSubTabView(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'workout_subtab_taps_$name';
  await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
}

void _openStartWorkout(BuildContext context, {VoidCallback? onReturn}) {
  Navigator.push(
    context,
    arcadeRoute(
      (_) => const StartWorkoutPage(),
      motion: ArcadeRouteMotion.flow,
    ),
  ).then((_) {
    if (onReturn != null) onReturn();
  });
}

/// Consistent empty-state block: pixel icon, verb-first headline, one-line body,
/// and an optional primary CTA. Used across Workout sub-tabs.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final String icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(AssetImage(icon), size: 48, color: kBorder),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 20),
              PixelButton(label: ctaLabel!, fullWidth: false, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}

// ── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({required this.reloadToken});

  final int reloadToken;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

enum _HistoryView { list, calendar }

class _HistoryTabState extends State<_HistoryTab> {
  List<WorkoutSession> _browsable = [];
  int _totalSessions = 0;
  int _thisMonth = 0;
  int _trainingDays = 0;
  RestState _restState = RestState.defaults();
  bool _loading = true;
  _HistoryView _view = _HistoryView.list;
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _load();
  }

  @override
  void didUpdateWidget(covariant _HistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final all = await WorkoutStorageService().getSessions();
    final restState = await RestService().loadState();
    if (!mounted) return;
    final completed = all.where((s) => !s.isPartial).toList();
    final browsable = all.where((s) => !s.isOngoing).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final thisMonth = completed
        .where((s) => s.date.year == now.year && s.date.month == now.month)
        .length;
    setState(() {
      _browsable = browsable;
      _totalSessions = completed.length;
      _thisMonth = thisMonth;
      _trainingDays = WorkoutMetricService.trainingDaysThisWeek(completed);
      _restState = restState;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: PixelLoader());
    }

    // Empty state: no zeros card, no view toggle — just the invitation to train.
    if (_browsable.isEmpty) {
      return _EmptyState(
        icon: 'assets/icons/control/icon_sword.png',
        title: 'READY TO LIFT?',
        body:
            'Your first workout starts here —\n'
            'log a session and your stats begin to climb.',
        ctaLabel: 'NEW WORKOUT',
        onCta: () => _openStartWorkout(context, onReturn: _load),
      );
    }

    final bottomPadding = 120 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow(label: 'Total Sessions', value: '$_totalSessions'),
                  const Divider(height: 24, color: kBorder),
                  _StatRow(label: 'This Month', value: '$_thisMonth'),
                  const Divider(height: 24, color: kBorder),
                  _StatRow(
                    label: 'Train Days',
                    value:
                        '$_trainingDays day${_trainingDays == 1 ? '' : 's'} this week',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _SubTabToggle(
              labels: const ['LIST', 'CALENDAR'],
              selectedIndex: _view == _HistoryView.list ? 0 : 1,
              onChanged: (i) => setState(
                () =>
                    _view = i == 0 ? _HistoryView.list : _HistoryView.calendar,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_view == _HistoryView.list)
            Column(
              children: [
                for (final session in _browsable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SessionListTile(
                      session: session,
                      onTap: () => Navigator.push(
                        context,
                        arcadeRoute((_) => SessionDetailPage(session: session)),
                      ).then((_) => _load()),
                    ),
                  ),
              ],
            )
          else
            _InlineHistoryCalendar(
              sessions: _browsable,
              restState: _restState,
              focusedMonth: _focusedMonth,
              selectedDay: _selectedDay,
              onPreviousMonth: () => setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                );
                _selectedDay = null;
              }),
              onNextMonth: () => setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                );
                _selectedDay = null;
              }),
              onSelectDay: (day) => setState(() => _selectedDay = day),
              onOpenSession: (session) => Navigator.push(
                context,
                arcadeRoute((_) => SessionDetailPage(session: session)),
              ).then((_) => _load()),
            ),
        ],
      ),
    );
  }
}

/// Generic 2+-segment pill toggle used for Workout sub-tab inner views
/// (LOGS: History/Trends, LIBRARY: Programs/Exercises) and History's
/// List/Calendar switch. Animated sliding indicator over labelled segments.
class _SubTabToggle extends StatelessWidget {
  const _SubTabToggle({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
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
                  for (int i = 0; i < labels.length; i++)
                    _SubTabSegment(
                      label: labels[i],
                      selected: selectedIndex == i,
                      onTap: () => onChanged(i),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubTabSegment extends StatelessWidget {
  const _SubTabSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PhosphorTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: selected ? kNeon : kMutedText,
              fontFamily: 'PressStart2P',
              fontSize: 8,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _InlineHistoryCalendar extends StatelessWidget {
  const _InlineHistoryCalendar({
    required this.sessions,
    required this.restState,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.onOpenSession,
  });

  final List<WorkoutSession> sessions;
  final RestState restState;
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<WorkoutSession> onOpenSession;

  static const _muscleColors = {
    'Chest': Color(0xFF00FF9C),
    'Back': Color(0xFFFFD700),
    'Shoulders': Color(0xFF9B59B6),
    'Arms': Color(0xFFFF2D55),
    'Legs': Color(0xFF00BFFF),
    'Core': Color(0xFFFF6B1A),
    'Full Body': Color(0xFFE8E8FF),
  };

  Map<DateTime, List<WorkoutSession>> get _sessionsByDay {
    final map = <DateTime, List<WorkoutSession>>{};
    for (final session in sessions) {
      final day = DateUtils.dateOnly(session.date);
      map.putIfAbsent(day, () => []).add(session);
    }
    return map;
  }

  List<DateTime?> _gridDays() {
    final leadingBlanks = (focusedMonth.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedMonth.year,
      focusedMonth.month,
    );
    final cells = <DateTime?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(focusedMonth.year, focusedMonth.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String _monthLabel() {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[focusedMonth.month - 1]} ${focusedMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionsByDay = _sessionsByDay;
    final gridDays = _gridDays();
    final selectedSessions = selectedDay == null
        ? null
        : sessionsByDay[DateUtils.dateOnly(selectedDay!)];
    final selectedRestInfo = selectedDay == null
        ? null
        : RestService().dayInfoForState(
            day: selectedDay!,
            sessions: selectedSessions ?? const [],
            state: restState,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: onPreviousMonth,
                      icon: Transform.scale(
                        scaleX: -1,
                        child: const ImageIcon(
                          AssetImage('assets/icons/control/icon_next.png'),
                          color: Color(0xFF00FF9C),
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: Color(0xFF00FF9C),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: onNextMonth,
                      icon: const ImageIcon(
                        AssetImage('assets/icons/control/icon_next.png'),
                        color: Color(0xFF00FF9C),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                      Expanded(
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kMutedText,
                            fontSize: 9,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: gridDays.length,
                  itemBuilder: (context, index) {
                    return _CalendarCell(
                      day: gridDays[index],
                      sessions: gridDays[index] == null
                          ? const []
                          : sessionsByDay[DateUtils.dateOnly(
                                  gridDays[index]!,
                                )] ??
                                const [],
                      selectedDay: selectedDay,
                      onSelectDay: onSelectDay,
                      restState: restState,
                    );
                  },
                ),
                const SizedBox(height: 12),
                const _CalendarLegend(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (selectedDay == null)
          Text(
            'Tap a day to inspect history',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          CalendarDayStatusCard(
            dateLabel: fmtDayDate(selectedDay!),
            restInfo: selectedRestInfo!,
            hasWorkout: selectedSessions?.isNotEmpty ?? false,
            abandonedOnly:
                selectedSessions?.isNotEmpty == true &&
                selectedSessions!.every((session) => session.isAbandoned),
            workoutColor: selectedSessions?.isNotEmpty == true
                ? _muscleColors[selectedSessions!.first.muscleGroup] ??
                      const Color(0xFF00FF9C)
                : null,
          ),
          const SizedBox(height: 8),
          if (selectedSessions != null && selectedSessions.isNotEmpty)
            for (final session in selectedSessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SessionListTile(
                  session: session,
                  onTap: () => onOpenSession(session),
                ),
              ),
        ],
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.sessions,
    required this.selectedDay,
    required this.onSelectDay,
    required this.restState,
  });

  final DateTime? day;
  final List<WorkoutSession> sessions;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final RestState restState;

  @override
  Widget build(BuildContext context) {
    final cellDay = day;
    if (cellDay == null) return const SizedBox.shrink();

    final today = DateUtils.dateOnly(DateTime.now());
    final normalized = DateUtils.dateOnly(cellDay);
    final isToday = normalized == today;
    final isSelected =
        selectedDay != null && normalized == DateUtils.dateOnly(selectedDay!);
    final hasWorkout = sessions.isNotEmpty;
    final abandonedOnly =
        hasWorkout && sessions.every((session) => session.isAbandoned);
    final isPast = normalized.isBefore(today);
    final restInfo = RestService().dayInfoForState(
      day: normalized,
      sessions: sessions,
      state: restState,
    );
    final markerKind = calendarMarkerKindFor(
      restInfo: restInfo,
      hasWorkout: hasWorkout,
      abandonedOnly: abandonedOnly,
      isToday: isToday,
      isSelected: isSelected,
    );
    final workoutColor = hasWorkout
        ? _InlineHistoryCalendar._muscleColors[sessions.first.muscleGroup] ??
              const Color(0xFF00FF9C)
        : null;

    return HoldDepress(
      onTap: () => onSelectDay(normalized),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FF9C).withValues(alpha: 0.18)
              : null,
          border: isSelected
              ? Border.all(color: const Color(0xFF00FF9C), width: 1.5)
              : isToday
              ? Border.all(color: const Color(0xFF00FF9C), width: 1)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${cellDay.day}',
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? const Color(0xFF00FF9C)
                    : isPast || isToday
                    ? const Color(0xFFE8E8FF)
                    : kMutedText,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (markerKind != null) ...[
              const SizedBox(height: 2),
              CalendarDayMarker(
                kind: markerKind,
                color: calendarMarkerColor(
                  markerKind,
                  workoutColor: workoutColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          CalendarLegendMarker(
            kind: CalendarMarkerKind.workout,
            label: 'Workout',
          ),
          SizedBox(width: 14),
          CalendarLegendMarker(
            kind: CalendarMarkerKind.protected,
            label: 'Protected',
          ),
          SizedBox(width: 14),
          CalendarLegendMarker(
            kind: CalendarMarkerKind.missed,
            label: 'Missed',
          ),
        ],
      ),
    );
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({required this.session, required this.onTap});

  final WorkoutSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mins = session.actualDurationSeconds ~/ 60;
    return HoldDepress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                color: session.isAbandoned
                    ? const Color(0xFFFF2D55)
                    : const Color(0xFF00FF9C),
              ),
              Expanded(
                child: ListTile(
                  title: Text(
                    session.isAbandoned
                        ? '${session.targetMuscleLabel} - ENDED EARLY'
                        : session.targetMuscleLabel,
                  ),
                  subtitle: Text(
                    '${fmtDayDate(session.date)} · '
                    '${session.isAbandoned ? 'Time XP only' : '${session.exercises.length} exercises'}',
                    style: const TextStyle(color: kMutedText),
                  ),
                  trailing: Text('$mins min'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF00FF9C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _PBRecord {
  const _PBRecord(this.volume, this.weight, this.reps, this.date);
  final double volume;
  final double weight;
  final int reps;
  final DateTime date;
}

class _MuscleData {
  const _MuscleData(this.muscle, this.volume, this.lastTrained);
  final String muscle;
  final double volume;
  final DateTime? lastTrained;
}

class _ExerciseTrend {
  const _ExerciseTrend({
    required this.name,
    required this.loads,
    required this.plateau,
  });

  final String name;
  final List<double> loads;
  final bool plateau;
}

class _StatsTab extends StatefulWidget {
  const _StatsTab({required this.reloadToken});

  final int reloadToken;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  List<WorkoutSession> _sessions = [];
  int _questXP = 0;
  int _recoveryXP = 0;
  int _potionBonusXP = 0;
  Map<String, String> _primaryBucketByExerciseId = {};
  bool _loading = true;
  bool _showRecords = false;

  static const Map<String, Color> _muscleColors = {
    'Chest': Color(0xFF00FF9C),
    'Back': Color(0xFFFFD700),
    'Shoulders': Color(0xFF9B59B6),
    'Arms': Color(0xFFFF2D55),
    'Legs': Color(0xFF00BFFF),
    'Core': Color(0xFFFF6B1A),
    'Full Body': Color(0xFFE8E8FF),
  };

  static const List<String> _muscles = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Full Body',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final all = await WorkoutStorageService().getSessions();
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final questXP = await QuestService().claimedRewardXP();
    final restService = RestService();
    final currentRecoveryXP = await restService.effectiveRecoveryXP(all);
    final potionBonusXP = await XpBoostService().getTotalBonusXP();
    await restService.ensureAutomaticRecoveryForToday(
      sessions: all,
      baseXP:
          XpService.calculateTotalXP(all) +
          questXP +
          currentRecoveryXP +
          potionBonusXP,
    );
    final recoveryXP = await restService.effectiveRecoveryXP(all);
    if (!mounted) return;
    setState(() {
      _sessions = all;
      _primaryBucketByExerciseId = {
        for (final exercise in catalog)
          if (exercise.primaryMuscle != null)
            exercise.id: muscleGroupForDetailed(exercise.primaryMuscle!) ?? '',
      }..removeWhere((_, bucket) => bucket.isEmpty);
      _questXP = questXP;
      _recoveryXP = recoveryXP;
      _potionBonusXP = potionBonusXP;
      _loading = false;
    });
  }

  String _fmtVol(double v) => fmtVol(v);

  Map<String, double> _sessionVolumeByMuscle(WorkoutSession session) {
    final volumes = <String, double>{};
    final targets = session.targetMuscleGroups;
    for (final log in session.exercises) {
      final bucket = _primaryBucketByExerciseId[log.exerciseId];
      if (bucket != null) {
        volumes[bucket] = (volumes[bucket] ?? 0) + log.totalVolume;
      } else if (targets.isNotEmpty) {
        final share = log.totalVolume / targets.length;
        for (final target in targets) {
          volumes[target] = (volumes[target] ?? 0) + share;
        }
      }
    }
    return volumes;
  }

  String _fmtDate(DateTime d) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  // Returns list of (totalVolume, dominantColor) for Mon–Sun of current week
  List<(double, Color)> _buildWeekData() {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final volumes = List<double>.filled(7, 0);
    // per day: track muscle → volume so we can pick dominant
    final muscleVols = List<Map<String, double>>.generate(7, (_) => {});

    for (final s in _sessions.where((s) => !s.isPartial)) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      final idx = day.difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      final vol = s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
      volumes[idx] += vol;
      for (final entry in _sessionVolumeByMuscle(s).entries) {
        muscleVols[idx][entry.key] =
            (muscleVols[idx][entry.key] ?? 0) + entry.value;
      }
    }

    return List.generate(7, (i) {
      if (volumes[i] == 0) return (0.0, Colors.transparent);
      final dominant = muscleVols[i].entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      return (volumes[i], _muscleColors[dominant] ?? const Color(0xFF00FF9C));
    });
  }

  // Returns (sessions count, total volume) for a date range
  (int, double) _rangeStats(DateTime from, DateTime to) {
    int count = 0;
    double vol = 0;
    for (final s in _sessions.where((s) => !s.isPartial)) {
      if (!s.date.isBefore(from) && s.date.isBefore(to)) {
        count++;
        vol += s.exercises.fold(0.0, (sum, e) => sum + e.totalVolume);
      }
    }
    return (count, vol);
  }

  List<_MuscleData> _buildMuscleBalance() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _muscles.map((muscle) {
      double vol = 0;
      DateTime? lastTrained;
      for (final s in _sessions.where((s) => !s.isPartial)) {
        final muscleVolumes = _sessionVolumeByMuscle(s);
        final muscleVolume = muscleVolumes[muscle] ?? 0;
        if (muscleVolume <= 0 && !s.targetMuscleGroups.contains(muscle)) {
          continue;
        }
        if (s.date.isAfter(cutoff)) {
          vol += muscleVolume;
        }
        if (lastTrained == null || s.date.isAfter(lastTrained)) {
          lastTrained = s.date;
        }
      }
      return _MuscleData(muscle, vol, lastTrained);
    }).toList();
  }

  int _suggestedIdx(List<_MuscleData> data) {
    int idx = 0;
    for (int i = 1; i < data.length; i++) {
      final curr = data[idx];
      final cand = data[i];
      if (cand.volume < curr.volume) {
        idx = i;
      } else if (cand.volume == curr.volume) {
        // Least recently trained wins
        final currDate = curr.lastTrained;
        final candDate = cand.lastTrained;
        if (currDate == null && candDate == null) {
          // both never trained → alphabetical
          if (cand.muscle.compareTo(curr.muscle) < 0) idx = i;
        } else if (currDate == null) {
          // curr never trained → keep curr (null = older)
        } else if (candDate == null) {
          // cand never trained → pick cand
          idx = i;
        } else if (candDate.isBefore(currDate)) {
          idx = i;
        } else if (candDate.isAtSameMomentAs(currDate)) {
          if (cand.muscle.compareTo(curr.muscle) < 0) idx = i;
        }
      }
    }
    return idx;
  }

  List<MapEntry<String, _PBRecord>> _buildPersonalBests() {
    final Map<String, _PBRecord> bests = {};
    for (final s in _sessions.where((s) => !s.isPartial)) {
      for (final e in s.exercises) {
        for (final set in e.sets) {
          final vol = set.weight * set.reps;
          if (!bests.containsKey(e.exerciseName) ||
              vol > bests[e.exerciseName]!.volume) {
            bests[e.exerciseName] = _PBRecord(
              vol,
              set.weight,
              set.reps,
              s.date,
            );
          }
        }
      }
    }
    final sorted = bests.entries.toList()
      ..sort((a, b) => b.value.volume.compareTo(a.value.volume));
    return sorted.take(5).toList();
  }

  List<_ExerciseTrend> _buildExerciseTrends() {
    final byExercise = <String, List<({DateTime date, double load})>>{};
    final names = <String, String>{};
    for (final session in _sessions.where((s) => !s.isPartial)) {
      for (final log in session.exercises) {
        final weightedSets = log.sets.where((set) => set.weight > 0).toList();
        if (weightedSets.isEmpty) continue;
        final topLoad = weightedSets.fold<double>(
          0,
          (best, set) => max(best, set.weight),
        );
        byExercise.putIfAbsent(log.exerciseId, () => []).add((
          date: session.date,
          load: topLoad,
        ));
        names[log.exerciseId] = log.exerciseName;
      }
    }

    final trends = <_ExerciseTrend>[];
    for (final entry in byExercise.entries) {
      if (entry.value.length < 5) continue;
      final points = entry.value.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final recent = points.length > 3
          ? points.sublist(points.length - 3)
          : points;
      final plateau =
          recent.length >= 3 &&
          recent.every((point) => point.load == recent.first.load);
      trends.add(
        _ExerciseTrend(
          name: names[entry.key] ?? entry.key,
          loads: [for (final point in points.take(10)) point.load],
          plateau: plateau,
        ),
      );
    }
    trends.sort((a, b) => b.loads.length.compareTo(a.loads.length));
    return trends.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: PixelLoader());
    }

    final completed = _sessions.where((s) => !s.isPartial).toList();

    if (completed.isEmpty) {
      return _EmptyState(
        icon: 'assets/icons/control/icon_graph.png',
        title: 'NO DATA YET',
        body: 'Log a workout to see your trends take shape.',
        ctaLabel: 'NEW WORKOUT',
        onCta: () => _openStartWorkout(context, onReturn: _load),
      );
    }

    // ── Computed values ──────────────────────────────────────────────────────
    final totalXP =
        XpService.calculateTotalXP(_sessions) +
        _questXP +
        _recoveryXP +
        _potionBonusXP;
    final xpProgress = XpService.progressForTotalXP(totalXP);
    final level = xpProgress.level;
    final rank = XpService.getRank(level);
    final trainingDays = WorkoutMetricService.trainingDaysThisWeek(_sessions);
    final questCount = completed.length;
    final totalVolume = completed.fold(
      0.0,
      (sum, s) => sum + s.exercises.fold(0.0, (s2, e) => s2 + e.totalVolume),
    );

    // Week data
    final weekData = _buildWeekData();
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final (thisWeekCount, thisWeekVol) = _rangeStats(
      thisMonday,
      now.add(const Duration(days: 1)),
    );
    final (lastWeekCount, lastWeekVol) = _rangeStats(lastMonday, thisMonday);
    final pct = lastWeekVol > 0
        ? ((thisWeekVol - lastWeekVol) / lastWeekVol * 100).round()
        : (thisWeekVol > 0 ? 100 : 0);

    // Muscle balance
    final muscleData = _buildMuscleBalance();
    final maxVol = muscleData.fold(0.0, (m, d) => max(m, d.volume));
    final suggestedIdx = _suggestedIdx(muscleData);

    // Personal bests
    final pbs = _buildPersonalBests();
    final exerciseTrends = _buildExerciseTrends();

    // Max bar height for chart
    final maxBarY = weekData.fold(0.0, (m, d) => max(m, d.$1));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Character Card ──────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rank + Level row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RankBadge(rank: rank),
                      Text(
                        'LV. $level',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 11,
                          color: Color(0xFFE8E8FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ArcadeProgressBar(value: xpProgress.fraction),
                  const SizedBox(height: 6),
                  Text(
                    xpProgress.label,
                    style: const TextStyle(color: kMutedText, fontSize: 10),
                  ),
                  const SizedBox(height: 16),

                  // Stats trio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatPip(
                        iconPath: 'assets/icons/control/icon_time.png',
                        label: 'TRAIN DAYS',
                        value: '$trainingDays',
                      ),
                      _StatPip(
                        iconPath: 'assets/icons/control/icon_trophy.png',
                        label: 'QUESTS',
                        value: '$questCount',
                      ),
                      _StatPip(
                        iconPath: 'assets/icons/control/icon_sword.png',
                        label: 'DAMAGE',
                        value: '${_fmtVol(totalVolume)} kg',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text('LOAD TRENDS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (exerciseTrends.isEmpty)
            Text(
              'Log 5 weighted sets on an exercise to unlock load trends.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final trend in exerciseTrends)
              Padding(
                padding: const EdgeInsets.only(bottom: kSpace3),
                child: _ExerciseTrendCard(trend: trend),
              ),

          const SizedBox(height: 24),
          const Divider(color: kBorder),
          const SizedBox(height: 16),

          // ── Section 2: This Week ───────────────────────────────────────
          Text('THIS WEEK', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                backgroundColor: Colors.transparent,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                maxY: maxBarY > 0 ? maxBarY * 1.2 : 10,
                barGroups: [
                  for (int i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: weekData[i].$1,
                          color: weekData[i].$1 > 0
                              ? weekData[i].$2
                              : Colors.transparent,
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Text(
                          days[value.toInt()],
                          style: const TextStyle(
                            color: kMutedText,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Week comparison
          Text(
            'This week: $thisWeekCount sessions · ${_fmtVol(thisWeekVol)} kg',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Last week: $lastWeekCount sessions · ${_fmtVol(lastWeekVol)} kg',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                pct > 0
                    ? '+$pct% ↑'
                    : pct < 0
                    ? '$pct% ↓'
                    : '→',
                style: TextStyle(
                  fontSize: 11,
                  color: pct > 0
                      ? const Color(0xFF00FF9C)
                      : pct < 0
                      ? const Color(0xFFFF2D55)
                      : kMutedText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: kBorder),
          const SizedBox(height: 16),

          // ── Section 3: Muscle Balance ──────────────────────────────────
          Text(
            'MUSCLE BALANCE',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Last 30 days',
            style: const TextStyle(color: kMutedText, fontSize: 12),
          ),
          const SizedBox(height: 16),

          for (int i = 0; i < muscleData.length; i++) ...[
            _MuscleBalanceRow(
              data: muscleData[i],
              color:
                  _muscleColors[muscleData[i].muscle] ??
                  const Color(0xFF00FF9C),
              maxVol: maxVol,
              fmtVol: _fmtVol,
            ),
            if (i == suggestedIdx)
              Padding(
                padding: const EdgeInsets.only(left: 64, bottom: 4),
                child: Text(
                  'Suggested next',
                  style: const TextStyle(color: kMutedText, fontSize: 10),
                ),
              ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),
          const Divider(color: kBorder),
          const SizedBox(height: 16),

          // ── Section 4: Personal Bests ──────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhosphorTap(
                onTap: () => setState(() => _showRecords = !_showRecords),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _showRecords ? '[ HIDE RECORDS ]' : '[ SHOW RECORDS ]',
                      style: AppFonts.shareTechMono(
                        color: const Color(0xFF00FF9C),
                        fontSize: 13,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _showRecords ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.keyboard_arrow_down_sharp,
                        color: Color(0xFF00FF9C),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: _showRecords
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          if (pbs.isEmpty)
                            Text(
                              'Complete your first quest to see records here',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            for (final entry in pbs)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        const ImageIcon(
                                          AssetImage(
                                            'assets/icons/control/icon_trophy.png',
                                          ),
                                          color: Color(0xFFFFD700),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.key,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                              Text(
                                                '${entry.value.weight}kg × ${entry.value.reps} reps',
                                                style: const TextStyle(
                                                  color: kMutedText,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _fmtDate(entry.value.date),
                                          style: const TextStyle(
                                            color: kMutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ExerciseTrendCard extends StatelessWidget {
  const _ExerciseTrendCard({required this.trend});

  final _ExerciseTrend trend;

  @override
  Widget build(BuildContext context) {
    final maxLoad = trend.loads.fold<double>(0, max);
    final minLoad = trend.loads.fold<double>(maxLoad, min);
    final range = max(1.0, maxLoad - minLoad);
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: trend.plateau ? kAmber : kBorder),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.shareTechMono(
                    color: kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trend.plateau)
                Text(
                  'PLATEAU',
                  style: AppFonts.shareTechMono(color: kAmber, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: kSpace2),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                minY: minLoad - range * 0.1,
                maxY: maxLoad + range * 0.1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < trend.loads.length; i++)
                        FlSpot(i.toDouble(), trend.loads[i]),
                    ],
                    isCurved: false,
                    barWidth: 2,
                    color: trend.plateau ? kAmber : kNeon,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final String rank;

  Color _borderColor() {
    switch (rank) {
      case 'Legend':
        return const Color(0xFFFF2D55);
      case 'Champion':
        return const Color(0xFFFF2D55);
      case 'Knight':
        return const Color(0xFFFFD700);
      case 'Squire':
        return const Color(0xFF00FF9C);
      default:
        return kMutedText;
    }
  }

  Color? _bgColor() {
    if (rank == 'Legend') {
      return const Color(0xFFFF2D55).withValues(alpha: 0.15);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor(),
        border: Border.all(color: _borderColor()),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rank.toUpperCase(),
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 9,
          color: _borderColor(),
        ),
      ),
    );
  }
}

class _StatPip extends StatelessWidget {
  const _StatPip({
    required this.iconPath,
    required this.label,
    required this.value,
  });
  final String iconPath;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageIcon(
          AssetImage(iconPath),
          size: 16,
          color: const Color(0xFF00FF9C),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: Color(0xFF00FF9C),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: kMutedText, fontSize: 9)),
      ],
    );
  }
}

class _MuscleBalanceRow extends StatelessWidget {
  const _MuscleBalanceRow({
    required this.data,
    required this.color,
    required this.maxVol,
    required this.fmtVol,
  });
  final _MuscleData data;
  final Color color;
  final double maxVol;
  final String Function(double) fmtVol;

  @override
  Widget build(BuildContext context) {
    final progress = maxVol > 0
        ? (data.volume / maxVol).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            data.muscle,
            style: const TextStyle(color: kMutedText, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ArcadeProgressBar(
            value: progress,
            height: 8,
            fillColor: color,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '${fmtVol(data.volume)} kg',
            style: const TextStyle(color: kMutedText, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── Exercises Tab ─────────────────────────────────────────────────────────────

class _ExercisesTab extends StatefulWidget {
  const _ExercisesTab();

  @override
  State<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<_ExercisesTab>
    with SingleTickerProviderStateMixin {
  static const _groups = ['All', ...canonicalMuscleGroups];

  String _selectedGroup = 'All';
  bool _favOnly = false;
  String _query = '';
  List<Exercise> _catalog = [];
  Set<String> _favoriteIds = {};
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late final Animation<double> _shimmerOpacity =
      Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
      );

  @override
  void initState() {
    super.initState();
    _shimmerController.repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final catalog = await ExerciseCatalogService().getFullCatalog();
    final favs = await FavoriteService().getFavoriteExerciseIds();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _favoriteIds = favs;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(String id) async {
    final isNowFav = await FavoriteService().toggleFavoriteExercise(id);
    if (isNowFav) {
      setState(() => _favoriteIds.add(id));
    } else {
      setState(() => _favoriteIds.remove(id));
    }
  }

  List<Exercise> get _filtered {
    final allowedIds = _selectedGroup == 'All'
        ? curatedExerciseIdsByMuscleGroup.values.expand((ids) => ids).toSet()
        : curatedExerciseIdsByMuscleGroup[_selectedGroup]?.toSet() ?? {};

    return _catalog.where((e) {
      final matchesQuery =
          _query.isEmpty || e.name.toLowerCase().contains(_query.toLowerCase());
      final matchesFav = !_favOnly || _favoriteIds.contains(e.id);
      if (!matchesQuery || !matchesFav) return false;

      if (e.isCustom) {
        if (_selectedGroup == 'All') return true;
        final group = e.muscleGroup;
        return group != null && hasTargetMuscle([group], _selectedGroup);
      }
      return allowedIds.contains(e.id);
    }).toList()..sort((a, b) {
      // Custom exercises first, then alphabetical
      if (a.isCustom != b.isCustom) return a.isCustom ? -1 : 1;
      return a.name.compareTo(b.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: ArcadeTextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            style: AppFonts.shareTechMono(
              color: const Color(0xFFE8E8FF),
              fontSize: 14,
            ),
            hintText: 'Search exercises',
            hintStyle: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search_sharp, color: kMutedText),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_sharp, color: kMutedText),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _groups.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == _groups.length) {
                return _FavChip(
                  selected: _favOnly,
                  onSelected: () => setState(() => _favOnly = !_favOnly),
                );
              }
              final group = _groups[i];
              final selected = group == _selectedGroup;
              return ArcadeChip(
                label: group,
                selected: selected,
                onTap: () => setState(() => _selectedGroup = group),
              );
            },
          ),
        ),

        // Create button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  arcadeRoute((_) => const CreateExercisePage()),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add_sharp, size: 16),
              label: const Text(
                'CREATE',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
              ),
            ),
          ),
        ),

        // Exercise list
        Expanded(
          child: _loading
              ? AnimatedBuilder(
                  animation: _shimmerOpacity,
                  builder: (context, _) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: 6,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) => Opacity(
                      opacity: _shimmerOpacity.value,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                )
              : _filtered.isEmpty
              ? Center(
                  child: Text(
                    _favOnly ? 'NO FAVORITES YET' : 'No exercises found',
                    style: _favOnly
                        ? AppFonts.shareTechMono(
                            color: kMutedText,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          )
                        : Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final ex = _filtered[i];
                    return ExerciseCard(
                      exercise: ex,
                      isFavorite: _favoriteIds.contains(ex.id),
                      isCustom: ex.isCustom,
                      showFavorite: true,
                      showArrow: true,
                      onTap: () => Navigator.push(
                        context,
                        arcadeRoute((_) => ExerciseDetailPage(exercise: ex)),
                      ),
                      onFavoriteToggle: () => _toggleFavorite(ex.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FavChip extends StatelessWidget {
  const _FavChip({required this.selected, required this.onSelected});

  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF2D55);
    const dark = kBg;
    final fg = selected ? dark : red;
    return HoldDepress(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? red : Colors.transparent,
          border: Border.all(color: red),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(
              const AssetImage('assets/icons/control/icon_heart.png'),
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text('Fav', style: TextStyle(color: fg, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
