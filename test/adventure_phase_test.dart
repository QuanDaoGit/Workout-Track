import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/adventure_models.dart';

/// The shared presentation predicate both the Home card and the Adventure page
/// consume (Codex #6) — so they can never disagree, especially in the
/// returned-but-unsettled window. Pure function; the clock is an input.
void main() {
  const week = '2026-W24';

  Expedition pending({String? returnsAtIso}) => Expedition(
    id: 'e1',
    routeId: 'iron_vault',
    day: '2026-06-12',
    rank: 'D',
    payout: 8,
    flavorIdx: 0,
    returnsAtIso: returnsAtIso,
  );

  final now = DateTime(2026, 6, 12, 18);

  test('no pending → idle', () {
    final ui = adventureUiStateOf(
      AdventureState(charges: 2),
      now,
      currentWeekIso: week,
    );
    expect(ui.phase, AdventurePhase.idle);
    expect(ui.charges, 2);
    expect(ui.canDispatch, isTrue);
  });

  test('pending with future returnsAt → out', () {
    final ui = adventureUiStateOf(
      AdventureState(
        pending: pending(
          returnsAtIso: now.add(const Duration(hours: 5)).toIso8601String(),
        ),
      ),
      now,
      currentWeekIso: week,
    );
    expect(ui.phase, AdventurePhase.out);
    expect(ui.canDispatch, isFalse);
  });

  test('pending with past returnsAt → returned', () {
    final ui = adventureUiStateOf(
      AdventureState(
        pending: pending(
          returnsAtIso: now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        ),
      ),
      now,
      currentWeekIso: week,
    );
    expect(ui.phase, AdventurePhase.returned);
  });

  test('legacy pending (null returnsAt) → returned (collectable)', () {
    final ui = adventureUiStateOf(
      AdventureState(pending: pending()),
      now,
      currentWeekIso: week,
    );
    expect(ui.phase, AdventurePhase.returned);
  });

  test('canDispatch is false at 0 charges even when idle', () {
    final ui = adventureUiStateOf(
      AdventureState(charges: 0),
      now,
      currentWeekIso: week,
    );
    expect(ui.phase, AdventurePhase.idle);
    expect(ui.canDispatch, isFalse);
  });

  test('weeklyCapped only when the stored week matches the current week', () {
    // Capped this week → blocked.
    final capped = adventureUiStateOf(
      AdventureState(charges: 1, weekIso: week, weekCount: 5),
      now,
      currentWeekIso: week,
    );
    expect(capped.weeklyCapped, isTrue);
    expect(capped.canDispatch, isFalse);

    // A stale week's count must NOT cap the new week.
    final staleWeek = adventureUiStateOf(
      AdventureState(charges: 1, weekIso: '2026-W23', weekCount: 5),
      now,
      currentWeekIso: week,
    );
    expect(staleWeek.weeklyCapped, isFalse);
    expect(staleWeek.canDispatch, isTrue);
  });
}
