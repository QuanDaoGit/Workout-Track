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
    required this.bootId,
    required this.rank,
    required this.payout,
    this.findId,
    required this.flavorIdx,
    this.settledAtIso,
    this.viewed = false,
  });

  final String id;
  final String routeId;

  /// Dispatch day, `yyyy-mm-dd` (date-only).
  final String day;

  /// Per-process boot UUID at dispatch — drives the revealable rule
  /// (a report never pops in the same app sitting that dispatched it).
  final String bootId;

  /// Rank letter (D/C/B/A/S) on the route's stat, captured at dispatch.
  final String rank;

  /// Gems, already rolled (base ±30%) at dispatch.
  final int payout;

  /// Find registry id, or null (most expeditions find nothing).
  final String? findId;

  /// Index into the route's flavor-line pool (rolled at dispatch).
  final int flavorIdx;

  /// Set when gems were awarded and the expedition moved to history.
  final String? settledAtIso;

  /// True once the report ceremony has been shown.
  final bool viewed;

  Expedition copyWith({String? settledAtIso, bool? viewed}) => Expedition(
    id: id,
    routeId: routeId,
    day: day,
    bootId: bootId,
    rank: rank,
    payout: payout,
    findId: findId,
    flavorIdx: flavorIdx,
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
      bootId: json['bootId'] is String ? json['bootId'] as String : '',
      rank: json['rank'] is String ? json['rank'] as String : 'D',
      payout: json['payout'] is num ? (json['payout'] as num).toInt() : 0,
      findId: json['findId'] is String ? json['findId'] as String : null,
      flavorIdx: json['flavorIdx'] is num
          ? (json['flavorIdx'] as num).toInt()
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
    this.lastDispatchDay,
    this.weekIso,
    this.weekCount = 0,
    List<Expedition>? history,
  }) : history = history ?? [];

  static const currentVersion = 1;

  final int version;

  /// Active route id; null until first dispatch resolves a default.
  final String? standingOrderRouteId;

  /// True once the user has explicitly set orders (first report shows the
  /// class-default explainer until then).
  final bool ordersConfirmed;

  /// The expedition currently out, if any (unsettled).
  final Expedition? pending;

  /// Max-anchored one-per-day guard (`yyyy-mm-dd`).
  final String? lastDispatchDay;

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
    String? lastDispatchDay,
    String? weekIso,
    int? weekCount,
    List<Expedition>? history,
  }) => AdventureState(
    version: version,
    standingOrderRouteId: standingOrderRouteId ?? this.standingOrderRouteId,
    ordersConfirmed: ordersConfirmed ?? this.ordersConfirmed,
    pending: clearPending ? null : (pending ?? this.pending),
    lastDispatchDay: lastDispatchDay ?? this.lastDispatchDay,
    weekIso: weekIso ?? this.weekIso,
    weekCount: weekCount ?? this.weekCount,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'standingOrderRouteId': standingOrderRouteId,
    'ordersConfirmed': ordersConfirmed,
    'pending': pending?.toJson(),
    'lastDispatchDay': lastDispatchDay,
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
      lastDispatchDay: json['lastDispatchDay'] is String
          ? json['lastDispatchDay'] as String
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
