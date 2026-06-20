/// Models for "Adventure" — workout-fueled expeditions that pay gems scaled
/// by stat rank. An expedition's entire outcome (payout roll, find, flavor
/// line) is rolled ONCE at dispatch and stored — settlement and reveal only
/// read it (reconstructed-value rule: never re-derive a reward later).
///
/// Lifecycle: dispatched (pending) → settled (gems awarded, moved to history,
/// unviewed) → viewed (report ceremony shown). Settlement is data, reveal is
/// presentation — a pending expedition can never block a workout's dispatch
/// because dispatch auto-settles first.
library;

/// One expedition, from dispatch through history.
class Expedition {
  const Expedition({
    required this.id,
    required this.routeId,
    required this.day,
    this.bootId,
    required this.rank,
    required this.payout,
    this.findId,
    required this.flavorIdx,
    this.dispatchedAtIso,
    this.returnsAtIso,
    this.durationMinutes = 0,
    this.multiplier = 1.0,
    this.vitAtDispatch = 0,
    this.settledAtIso,
    this.viewed = false,
  });

  final String id;
  final String routeId;

  /// Dispatch day, `yyyy-mm-dd` (date-only).
  final String day;

  /// Per-process boot UUID at dispatch (v1) — retained for forensic parity
  /// only; the v2 revealable rule is wall-clock ([returnsAtIso]), not boot.
  final String? bootId;

  /// Rank letter (D/C/B/A/S) on the route's stat, captured at dispatch.
  final String rank;

  /// Gems, rolled at dispatch (base × VIT multiplier × ±30% roll).
  final int payout;

  /// Find registry id, or null (most expeditions find nothing).
  final String? findId;

  /// Index into the route's flavor-line pool (rolled at dispatch).
  final int flavorIdx;

  /// Dispatch wall-clock (ISO-8601), set when the party is sent out.
  final String? dispatchedAtIso;

  /// When the expedition returns (ISO-8601) = dispatch + [durationMinutes].
  /// Null on a legacy v1 pending ⇒ treated as already returned (revealable).
  final String? returnsAtIso;

  /// Expedition length in minutes (VIT-scaled), captured at dispatch.
  final int durationMinutes;

  /// Payout multiplier from VIT at dispatch (1.0–1.4), captured & frozen.
  final double multiplier;

  /// VIT (recovery meter) at dispatch — shown in the report for legibility.
  final int vitAtDispatch;

  /// Set when gems were awarded and the expedition moved to history.
  final String? settledAtIso;

  /// True once the report ceremony has been shown.
  final bool viewed;

  Expedition copyWith({
    String? returnsAtIso,
    String? settledAtIso,
    bool? viewed,
  }) => Expedition(
    id: id,
    routeId: routeId,
    day: day,
    bootId: bootId,
    rank: rank,
    payout: payout,
    findId: findId,
    flavorIdx: flavorIdx,
    dispatchedAtIso: dispatchedAtIso,
    returnsAtIso: returnsAtIso ?? this.returnsAtIso,
    durationMinutes: durationMinutes,
    multiplier: multiplier,
    vitAtDispatch: vitAtDispatch,
    settledAtIso: settledAtIso ?? this.settledAtIso,
    viewed: viewed ?? this.viewed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'routeId': routeId,
    'day': day,
    'bootId': bootId,
    'rank': rank,
    'payout': payout,
    'findId': findId,
    'flavorIdx': flavorIdx,
    'dispatchedAtIso': dispatchedAtIso,
    'returnsAtIso': returnsAtIso,
    'durationMinutes': durationMinutes,
    'multiplier': multiplier,
    'vitAtDispatch': vitAtDispatch,
    'settledAtIso': settledAtIso,
    'viewed': viewed,
  };

  /// Defensive per-field decode; returns null when the record is unusable
  /// (a malformed expedition is dropped, never crashes the store).
  static Expedition? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'];
    final routeId = json['routeId'];
    final day = json['day'];
    if (id is! String || id.isEmpty) return null;
    if (routeId is! String || routeId.isEmpty) return null;
    if (day is! String || day.isEmpty) return null;
    return Expedition(
      id: id,
      routeId: routeId,
      day: day,
      bootId: json['bootId'] is String ? json['bootId'] as String : null,
      rank: json['rank'] is String ? json['rank'] as String : 'D',
      payout: json['payout'] is num ? (json['payout'] as num).toInt() : 0,
      findId: json['findId'] is String ? json['findId'] as String : null,
      flavorIdx: json['flavorIdx'] is num
          ? (json['flavorIdx'] as num).toInt()
          : 0,
      dispatchedAtIso: json['dispatchedAtIso'] is String
          ? json['dispatchedAtIso'] as String
          : null,
      returnsAtIso: json['returnsAtIso'] is String
          ? json['returnsAtIso'] as String
          : null,
      durationMinutes: json['durationMinutes'] is num
          ? (json['durationMinutes'] as num).toInt()
          : 0,
      multiplier: json['multiplier'] is num
          ? (json['multiplier'] as num).toDouble()
          : 1.0,
      vitAtDispatch: json['vitAtDispatch'] is num
          ? (json['vitAtDispatch'] as num).toInt()
          : 0,
      settledAtIso: json['settledAtIso'] is String
          ? json['settledAtIso'] as String
          : null,
      viewed: json['viewed'] is bool ? json['viewed'] as bool : false,
    );
  }
}

/// Persisted Adventure state (`adventure_state_v1`). Missing/malformed
/// decodes to a fresh state (legacy rule: null = never dispatched).
class AdventureState {
  AdventureState({
    this.version = currentVersion,
    this.standingOrderRouteId,
    this.ordersConfirmed = false,
    this.pending,
    this.charges = 0,
    this.lastChargeDay,
    this.lastDispatchDay,
    this.maxSeenAtIso,
    this.weekIso,
    this.weekCount = 0,
    List<Expedition>? history,
  }) : history = history ?? [];

  static const currentVersion = 2;

  /// Max banked, user-spendable charges. The storage cap; the service grant
  /// path clamps to this.
  static const chargeCap = 3;

  final int version;

  /// Active route id; null until first dispatch resolves a default.
  final String? standingOrderRouteId;

  /// True once the user has explicitly set orders (first report shows the
  /// class-default explainer until then).
  final bool ordersConfirmed;

  /// The expedition currently out, if any (unsettled).
  final Expedition? pending;

  /// Banked, user-spendable expedition charges (0–[chargeCap]).
  final int charges;

  /// Max-anchored one-charge-per-day grant guard (`yyyy-mm-dd`).
  final String? lastChargeDay;

  /// Max-anchored last manual dispatch day (legacy v1 field; retained).
  final String? lastDispatchDay;

  /// Highest wall-clock ever observed (ISO-8601) — the rollback guard for the
  /// expedition return check (a returned expedition can't un-return).
  final String? maxSeenAtIso;

  /// ISO week of [weekCount].
  final String? weekIso;

  /// Dispatches this ISO week (cap enforced by the service).
  final int weekCount;

  /// Settled expeditions, newest first, capped by the service.
  final List<Expedition> history;

  AdventureState copyWith({
    String? standingOrderRouteId,
    bool? ordersConfirmed,
    Expedition? pending,
    bool clearPending = false,
    int? charges,
    String? lastChargeDay,
    String? lastDispatchDay,
    String? maxSeenAtIso,
    String? weekIso,
    int? weekCount,
    List<Expedition>? history,
  }) => AdventureState(
    version: version,
    standingOrderRouteId: standingOrderRouteId ?? this.standingOrderRouteId,
    ordersConfirmed: ordersConfirmed ?? this.ordersConfirmed,
    pending: clearPending ? null : (pending ?? this.pending),
    charges: charges ?? this.charges,
    lastChargeDay: lastChargeDay ?? this.lastChargeDay,
    lastDispatchDay: lastDispatchDay ?? this.lastDispatchDay,
    maxSeenAtIso: maxSeenAtIso ?? this.maxSeenAtIso,
    weekIso: weekIso ?? this.weekIso,
    weekCount: weekCount ?? this.weekCount,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'standingOrderRouteId': standingOrderRouteId,
    'ordersConfirmed': ordersConfirmed,
    'pending': pending?.toJson(),
    'charges': charges,
    'lastChargeDay': lastChargeDay,
    'lastDispatchDay': lastDispatchDay,
    'maxSeenAtIso': maxSeenAtIso,
    'weekIso': weekIso,
    'weekCount': weekCount,
    'history': [for (final e in history) e.toJson()],
  };

  factory AdventureState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AdventureState();
    final history = <Expedition>[];
    final rawHistory = json['history'];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        final decoded = Expedition.fromJson(item);
        if (decoded != null) history.add(decoded);
      }
    }
    return AdventureState(
      version: json['version'] is num
          ? (json['version'] as num).toInt()
          : currentVersion,
      standingOrderRouteId: json['standingOrderRouteId'] is String
          ? json['standingOrderRouteId'] as String
          : null,
      ordersConfirmed: json['ordersConfirmed'] is bool
          ? json['ordersConfirmed'] as bool
          : false,
      pending: Expedition.fromJson(json['pending']),
      charges: json['charges'] is num
          ? (json['charges'] as num).toInt().clamp(0, chargeCap)
          : 0,
      lastChargeDay: json['lastChargeDay'] is String
          ? json['lastChargeDay'] as String
          : null,
      lastDispatchDay: json['lastDispatchDay'] is String
          ? json['lastDispatchDay'] as String
          : null,
      maxSeenAtIso: json['maxSeenAtIso'] is String
          ? json['maxSeenAtIso'] as String
          : null,
      weekIso: json['weekIso'] is String ? json['weekIso'] as String : null,
      weekCount: json['weekCount'] is num
          ? (json['weekCount'] as num).toInt()
          : 0,
      history: history,
    );
  }
}

/// Immutable payload handed to the report reveal — everything the ceremony
/// needs, already settled.
class ExpeditionReport {
  const ExpeditionReport({
    required this.expedition,
    required this.classDefaultOrders,
  });

  final Expedition expedition;

  /// True when the orders were the silent class default (first report shows
  /// the explainer + CHANGE ORDERS CTA).
  final bool classDefaultOrders;
}

/// Presentation phase of the Adventure surface, derived purely from state +
/// clock. `armed` is page-local UI on top of `idle` and is not modeled here.
enum AdventurePhase { idle, out, returned }

/// One shared UI view-model consumed by BOTH the Home card and the Adventure
/// page (Codex: a bare 3-value phase would collapse the blocked states into
/// `idle` at the call sites, re-enabling dispatch UI for users who should only
/// inspect). Same inputs + same clock ⇒ the two surfaces can never disagree,
/// especially in the returned-but-unsettled window.
class AdventureUiState {
  const AdventureUiState({
    required this.phase,
    required this.charges,
    required this.weeklyCapped,
  });

  final AdventurePhase phase;
  final int charges;
  final bool weeklyCapped;

  /// True only when a fresh expedition may be dispatched right now.
  bool get canDispatch =>
      phase == AdventurePhase.idle && charges > 0 && !weeklyCapped;
}

/// Pure derivation of [AdventureUiState]. [currentWeekIso] is supplied by the
/// caller (`GuildService.weekIso(now)`) so this model stays service-free; a
/// stale stored `weekIso` (last week's) therefore reads as not-capped.
AdventureUiState adventureUiStateOf(
  AdventureState state,
  DateTime now, {
  required String currentWeekIso,
  int weeklyCap = 5,
}) {
  final pending = state.pending;
  final AdventurePhase phase;
  if (pending == null) {
    phase = AdventurePhase.idle;
  } else {
    final returnsAt = pending.returnsAtIso == null
        ? null
        : DateTime.tryParse(pending.returnsAtIso!);
    // Null returnsAt (legacy v1 pending) ⇒ already returned (collectable).
    phase = (returnsAt == null || !now.isBefore(returnsAt))
        ? AdventurePhase.returned
        : AdventurePhase.out;
  }
  final cappedThisWeek =
      state.weekIso == currentWeekIso && state.weekCount >= weeklyCap;
  return AdventureUiState(
    phase: phase,
    charges: state.charges,
    weeklyCapped: cappedThisWeek,
  );
}

/// True when a haul is waiting to be collected — the **single persisted
/// authority** for the home-room coffer (Codex: never a volatile held report).
/// Two equivalent sources, both durable: an already-settled report still
/// unviewed in [AdventureState.history], or a [pending] whose return time has
/// passed (which `settleAndPeekReport` will move to unviewed history on the next
/// touch). Derived fresh from persisted state every load, so it survives
/// kill/reopen and the service auto-settling a pending between opens. The
/// `returns-at` test mirrors [adventureUiStateOf] exactly so the coffer and the
/// phase can never disagree.
bool hasUncollectedHaul(AdventureState state, DateTime now) {
  if (state.history.any((e) => !e.viewed)) return true;
  final pending = state.pending;
  if (pending == null) return false;
  final returnsAt = pending.returnsAtIso == null
      ? null
      : DateTime.tryParse(pending.returnsAtIso!);
  return returnsAt == null || !now.isBefore(returnsAt);
}
