import 'package:flutter/material.dart';

import '../models/rest_models.dart';
import '../theme/tokens.dart';

enum CalendarMarkerKind { workout, abandoned, protected, missed, rest }

const Color calendarMarkerMuted = kSlate;
const Color calendarMarkerNeon = kNeon;
const Color calendarMarkerRed = kDanger;
const Color calendarMarkerGold = kAmber;
const Color calendarMarkerCyan = kCyan;

CalendarMarkerKind? calendarMarkerKindFor({
  required RestDayInfo restInfo,
  required bool hasWorkout,
  required bool abandonedOnly,
  required bool isToday,
  required bool isSelected,
  bool suppressMissed = false,
}) {
  if (hasWorkout) {
    return abandonedOnly
        ? CalendarMarkerKind.abandoned
        : CalendarMarkerKind.workout;
  }

  return switch (restInfo.kind) {
    RestDayKind.protectedMiss => CalendarMarkerKind.protected,
    // Days before the user's first-ever session aren't "missed" — there was
    // no habit to miss yet. Callers suppress to keep a new user's calendar
    // from opening as a wall of failures.
    RestDayKind.unplannedMiss when suppressMissed => null,
    RestDayKind.unplannedMiss => CalendarMarkerKind.missed,
    RestDayKind.abandonedOnly => CalendarMarkerKind.abandoned,
    RestDayKind.plannedRest when isToday || isSelected =>
      CalendarMarkerKind.rest,
    _ => null,
  };
}

Color calendarMarkerColor(CalendarMarkerKind? kind, {Color? workoutColor}) {
  return switch (kind) {
    CalendarMarkerKind.workout => workoutColor ?? calendarMarkerNeon,
    CalendarMarkerKind.abandoned => calendarMarkerRed,
    CalendarMarkerKind.protected => calendarMarkerNeon,
    // Muted, not red: a missed day is information, not an alarm. Red also
    // collided with the Arms muscle color on workout markers. Red stays
    // reserved for abandoned sessions (a deliberate end, not an absence).
    CalendarMarkerKind.missed => calendarMarkerMuted,
    CalendarMarkerKind.rest => calendarMarkerCyan,
    null => calendarMarkerMuted,
  };
}

String calendarStatusTitle(
  RestDayInfo info, {
  required bool hasWorkout,
  required bool abandonedOnly,
}) {
  if (hasWorkout) {
    return abandonedOnly ? 'Ended early' : 'Workout completed';
  }

  return switch (info.kind) {
    RestDayKind.plannedRest => 'Planned recovery',
    RestDayKind.protectedMiss => 'Protected missed day',
    RestDayKind.unplannedMiss => 'Missed training day',
    RestDayKind.abandonedOnly => 'Ended early',
    RestDayKind.trainingDay => 'Scheduled training day',
    RestDayKind.workoutComplete => 'Workout completed',
  };
}

String calendarStatusBody(
  RestDayInfo info, {
  required bool hasWorkout,
  required bool abandonedOnly,
}) {
  if (hasWorkout) {
    return abandonedOnly
        ? 'Time XP only. Not counted toward missions.'
        : 'Open the session below for exercise details.';
  }

  return switch (info.kind) {
    RestDayKind.plannedRest => 'Stats protected. Recovery runs all day.',
    RestDayKind.protectedMiss => 'Recovery shield protected this training day.',
    RestDayKind.unplannedMiss => 'Scheduled training was missed.',
    RestDayKind.abandonedOnly => 'Time XP only. Not counted toward missions.',
    RestDayKind.trainingDay => 'No workout logged yet.',
    RestDayKind.workoutComplete =>
      'Open the session below for exercise details.',
  };
}

class CalendarDayMarker extends StatelessWidget {
  const CalendarDayMarker({
    super.key,
    required this.kind,
    this.color,
    this.compact = true,
  });

  final CalendarMarkerKind kind;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markerColor = color ?? calendarMarkerColor(kind);

    return SizedBox(
      width: compact ? 18 : 22,
      height: compact ? 10 : 14,
      child: Center(child: _buildMarker(markerColor)),
    );
  }

  Widget _buildMarker(Color markerColor) {
    return switch (kind) {
      CalendarMarkerKind.workout => Container(
        width: compact ? 16 : 18,
        height: compact ? 4 : 5,
        color: markerColor,
      ),
      CalendarMarkerKind.abandoned => Container(
        width: compact ? 16 : 18,
        height: compact ? 4 : 5,
        color: markerColor,
      ),
      CalendarMarkerKind.protected => Container(
        width: compact ? 9 : 11,
        height: compact ? 9 : 11,
        decoration: BoxDecoration(
          border: Border.all(color: markerColor, width: 1.5),
        ),
      ),
      CalendarMarkerKind.missed => Transform.rotate(
        angle: -0.7,
        child: Container(
          width: compact ? 15 : 18,
          height: compact ? 3 : 4,
          color: markerColor,
        ),
      ),
      CalendarMarkerKind.rest => Container(
        width: compact ? 8 : 10,
        height: compact ? 5 : 6,
        color: markerColor,
      ),
    };
  }
}

class CalendarLegendMarker extends StatelessWidget {
  const CalendarLegendMarker({
    super.key,
    required this.kind,
    this.color,
    required this.label,
  });

  final CalendarMarkerKind kind;
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CalendarDayMarker(kind: kind, color: color, compact: false),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: calendarMarkerMuted),
        ),
      ],
    );
  }
}

class CalendarDayStatusCard extends StatelessWidget {
  const CalendarDayStatusCard({
    super.key,
    required this.dateLabel,
    required this.restInfo,
    required this.hasWorkout,
    required this.abandonedOnly,
    this.workoutColor,
  });

  final String dateLabel;
  final RestDayInfo restInfo;
  final bool hasWorkout;
  final bool abandonedOnly;
  final Color? workoutColor;

  @override
  Widget build(BuildContext context) {
    final markerKind = calendarMarkerKindFor(
      restInfo: restInfo,
      hasWorkout: hasWorkout,
      abandonedOnly: abandonedOnly,
      isToday: true,
      isSelected: true,
    );
    final markerColor = calendarMarkerColor(
      markerKind,
      workoutColor: workoutColor,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: markerKind == null
                  ? Container(width: 16, height: 4, color: calendarMarkerMuted)
                  : CalendarDayMarker(
                      kind: markerKind,
                      color: markerColor,
                      compact: false,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: calendarMarkerGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    calendarStatusTitle(
                      restInfo,
                      hasWorkout: hasWorkout,
                      abandonedOnly: abandonedOnly,
                    ),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    calendarStatusBody(
                      restInfo,
                      hasWorkout: hasWorkout,
                      abandonedOnly: abandonedOnly,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: calendarMarkerMuted,
                      height: 1.3,
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
