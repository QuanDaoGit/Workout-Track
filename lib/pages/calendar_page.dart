import 'package:flutter/material.dart';

import '../models/rest_models.dart';
import '../models/workout_models.dart';
import '../services/rest_service.dart';
import '../services/workout_storage_service.dart';
import '../theme/tokens.dart';
import '../widgets/arcade_route.dart';
import '../widgets/calendar_day_marker.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/pixel_loader.dart';
import 'Workout session/session_detail.dart';

String fmtDayDate(DateTime d) {
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
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
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

const _muscleColors = {
  'Chest': Color(0xFF00FF9C),
  'Back': Color(0xFFFFD700),
  'Shoulders': Color(0xFF9B59B6),
  'Arms': Color(0xFFFF2D55),
  'Legs': Color(0xFF00BFFF),
  'Core': Color(0xFFFF6B1A),
  'Full Body': Color(0xFFE8E8FF),
};

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  Map<DateTime, List<WorkoutSession>> _sessionsByDay = {};
  RestState _restState = RestState.defaults();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final all = await WorkoutStorageService().getSessions();
    final restState = await RestService().loadState();
    if (!mounted) return;
    final completed = all.where((s) => !s.isOngoing).toList();
    final map = <DateTime, List<WorkoutSession>>{};
    for (final s in completed) {
      final day = DateUtils.dateOnly(s.date);
      map.putIfAbsent(day, () => []).add(s);
    }
    setState(() {
      _sessionsByDay = map;
      _restState = restState;
      _loading = false;
    });
  }

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay = null;
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay = null;
  });

  String _fmtMonth(DateTime d) {
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
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fmtDayDate(DateTime d) => fmtDayDate(d);

  List<DateTime?> _buildGridDays() {
    // Week starts Monday (weekday 1). Find first Monday ≤ first of month.
    final firstOfMonth = _focusedMonth;
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    // firstOfMonth.weekday: 1=Mon … 7=Sun
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7;
    final cells = <DateTime?>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    // pad to full row
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  Widget _buildCell(DateTime? day) {
    if (day == null) return const SizedBox();

    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = day == today;
    final isSelected = _selectedDay != null && day == _selectedDay;
    final sessions = _sessionsByDay[day];
    final hasWorkout = sessions != null && sessions.isNotEmpty;
    final abandonedOnly =
        hasWorkout && sessions.every((session) => session.isAbandoned);
    final isPast = day.isBefore(today);
    final restInfo = RestService().dayInfoForState(
      day: day,
      sessions: sessions ?? const [],
      state: _restState,
    );
    final markerKind = calendarMarkerKindFor(
      restInfo: restInfo,
      hasWorkout: hasWorkout,
      abandonedOnly: abandonedOnly,
      isToday: isToday,
      isSelected: isSelected,
    );
    final workoutColor = hasWorkout
        ? _muscleColors[sessions.first.muscleGroup] ?? const Color(0xFF00FF9C)
        : null;

    // Determine icon
    BoxDecoration decoration = BoxDecoration(
      color: isSelected ? const Color(0xFF00FF9C).withValues(alpha: 0.2) : null,
      border: isSelected
          ? Border.all(color: const Color(0xFF00FF9C), width: 1.5)
          : isToday
          ? Border.all(color: const Color(0xFF00FF9C), width: 1)
          : null,
      borderRadius: BorderRadius.circular(4),
    );

    return HoldDepress(
      onTap: () => setState(() => _selectedDay = day),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: decoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
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

  @override
  Widget build(BuildContext context) {
    final gridDays = _buildGridDays();
    final selectedSessions = _selectedDay != null
        ? (_sessionsByDay[_selectedDay] ?? [])
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('WORKOUT HISTORY')),
      body: _loading
          ? const Center(child: PixelLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Month navigation ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _prevMonth,
                        icon: Transform.scale(
                          scaleX: -1,
                          child: const ImageIcon(
                            AssetImage('assets/icons/control/icon_next.png'),
                            color: Color(0xFF00FF9C),
                            size: 20,
                          ),
                        ),
                      ),
                      Text(
                        _fmtMonth(_focusedMonth),
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: Color(0xFF00FF9C),
                        ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const ImageIcon(
                          AssetImage('assets/icons/control/icon_next.png'),
                          color: Color(0xFF00FF9C),
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Weekday header ───────────────────────────────────
                  Row(
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                        .map(
                          (d) => Expanded(
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kMutedText,
                                fontSize: 11,
                                fontFamily: 'PressStart2P',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 4),

                  // ── Calendar grid ────────────────────────────────────
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: gridDays.length,
                    itemBuilder: (_, i) => _buildCell(gridDays[i]),
                  ),

                  const SizedBox(height: 16),

                  // ── Legend ───────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: SingleChildScrollView(
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
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: kBorder),
                  const SizedBox(height: 8),

                  // ── Session list ─────────────────────────────────────
                  if (selectedSessions == null)
                    Text(
                      'Tap a day to inspect history',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    CalendarDayStatusCard(
                      dateLabel: _fmtDayDate(_selectedDay!),
                      restInfo: RestService().dayInfoForState(
                        day: _selectedDay!,
                        sessions: selectedSessions,
                        state: _restState,
                      ),
                      hasWorkout: selectedSessions.isNotEmpty,
                      abandonedOnly:
                          selectedSessions.isNotEmpty &&
                          selectedSessions.every(
                            (session) => session.isAbandoned,
                          ),
                      workoutColor: selectedSessions.isNotEmpty
                          ? _muscleColors[selectedSessions.first.muscleGroup] ??
                                const Color(0xFF00FF9C)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    if (selectedSessions.isNotEmpty)
                      for (final session in selectedSessions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: HoldDepress(
                            onTap: () => Navigator.push(
                              context,
                              arcadeRoute(
                                (_) => SessionDetailPage(session: session),
                              ),
                            ),
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
                                          session.isAbandoned
                                              ? 'Time XP only'
                                              : '${session.exercises.length} exercises',
                                          style: const TextStyle(
                                            color: kMutedText,
                                          ),
                                        ),
                                        trailing: Text(
                                          '${session.actualDurationSeconds ~/ 60} min',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
    );
  }
}
