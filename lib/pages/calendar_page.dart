import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../widgets/pixel_loader.dart';
import '../services/workout_storage_service.dart';
import 'Workout session/session_detail.dart';

const _muscleIcon = {
  'Chest': 'assets/icons/control/icon_sword.png',
  'Back': 'assets/icons/control/icon_shield.png',
  'Arms': 'assets/icons/control/icon_hand.png',
  'Legs': 'assets/icons/control/icon_boots.png',
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
    if (!mounted) return;
    final completed = all.where((s) => !s.isPartial).toList();
    final map = <DateTime, List<WorkoutSession>>{};
    for (final s in completed) {
      final day = DateUtils.dateOnly(s.date);
      map.putIfAbsent(day, () => []).add(s);
    }
    setState(() {
      _sessionsByDay = map;
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

  String _fmtDayDate(DateTime d) {
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
    final isPast = day.isBefore(today);

    // Determine icon
    String? iconPath;
    if (hasWorkout) {
      iconPath = _muscleIcon[sessions.first.muscleGroup];
    } else if (isToday) {
      iconPath = 'assets/icons/control/icon_visibility_off.png';
    }

    BoxDecoration decoration = BoxDecoration(
      color: isSelected ? const Color(0xFF00FF9C).withValues(alpha: 0.2) : null,
      border: isToday
          ? Border.all(color: const Color(0xFF00FF9C), width: 1.5)
          : null,
      borderRadius: BorderRadius.circular(4),
    );

    final canTap = hasWorkout;

    return GestureDetector(
      onTap: canTap ? () => setState(() => _selectedDay = day) : null,
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
                    : const Color(0xFF6B6B8A),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (iconPath != null) ...[
              const SizedBox(height: 2),
              ImageIcon(
                AssetImage(iconPath),
                size: hasWorkout ? 16 : 12,
                color: hasWorkout
                    ? const Color(0xFF00FF9C)
                    : const Color(0xFF6B6B8A),
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
                                color: Color(0xFF6B6B8A),
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
                          children: [
                            ..._muscleIcon.entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ImageIcon(
                                      AssetImage(e.value),
                                      size: 14,
                                      color: const Color(0xFF00FF9C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      e.key,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B6B8A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                ImageIcon(
                                  AssetImage(
                                    'assets/icons/control/icon_visibility_off.png',
                                  ),
                                  size: 14,
                                  color: Color(0xFF6B6B8A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Rest',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B6B8A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF2A2A4A)),
                  const SizedBox(height: 8),

                  // ── Session list ─────────────────────────────────────
                  if (selectedSessions == null)
                    Text(
                      'Tap a workout day to see sessions',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (selectedSessions.isEmpty)
                    Text(
                      'No workouts on this day',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    Text(
                      _fmtDayDate(_selectedDay!),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final session in selectedSessions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SessionDetailPage(session: session),
                            ),
                          ),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    color: const Color(0xFF00FF9C),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      title: Text(session.muscleGroup),
                                      subtitle: Text(
                                        '${session.exercises.length} exercises',
                                        style: const TextStyle(
                                          color: Color(0xFF6B6B8A),
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
