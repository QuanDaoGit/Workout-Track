import 'dart:async';

import 'package:flutter/material.dart';

import '../data/adventure_routes.dart';
import '../models/adventure_models.dart';
import '../models/avatar_spec.dart';
import '../models/character_class.dart';
import '../services/adventure_service.dart';
import '../services/class_service.dart';
import '../services/profile_service.dart';
import '../services/stat_engine.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/adventure/adventure_card.dart';
import '../widgets/adventure/route_diorama.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_loader.dart';
import 'expedition_report_page.dart';

/// The Adventure area (v2): a console-style stage-select. With a charge in
/// hand you arm one of the three stat-keyed routes (the other two dim and
/// lock), confirm with DISPATCH, and the diorama comes alive while your
/// character is out on a VIT-scaled 4–8h haul. The report greets you on
/// return — collected here or on the next Home open.
class AdventurePage extends StatefulWidget {
  const AdventurePage({super.key});

  @override
  State<AdventurePage> createState() => _AdventurePageState();
}

class _AdventurePageState extends State<AdventurePage> {
  bool _loading = true;
  bool _busy = false;
  AdventureState _state = AdventureState();
  AvatarSpec _avatar = AvatarSpec.fallback;
  CharacterClass? _class;
  Map<String, int> _stats = const {};
  String? _armedRouteId;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final state = await AdventureService().loadState();
    final profile = await ProfileService().loadProfile();
    final cls = await ClassService().getCurrentClass();
    final stats = await StatEngine().getStoredStats();
    if (!mounted) return;
    setState(() {
      _state = state;
      _avatar = profile.avatarSpec;
      _class = cls;
      _stats = stats;
      _loading = false;
    });
    _syncTicker();
  }

  /// A coarse 30s tick refreshes the countdown and catches the return
  /// transition; only runs while an expedition is genuinely out.
  void _syncTicker() {
    _ticker?.cancel();
    final pending = _state.pending;
    if (pending != null && !_isReturned(pending)) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});
        if (_state.pending != null && _isReturned(_state.pending!)) {
          _ticker?.cancel();
        }
      });
    }
  }

  DateTime? _returnsAt(Expedition e) =>
      e.returnsAtIso == null ? null : DateTime.tryParse(e.returnsAtIso!);

  bool _isReturned(Expedition e) {
    final returnsAt = _returnsAt(e);
    if (returnsAt == null) return true;
    return !DateTime.now().isBefore(returnsAt);
  }

  int get _vit => _stats['VIT'] ?? 0;

  Future<void> _dispatch(AdventureRouteDef route) async {
    if (_busy) return;
    setState(() => _busy = true);
    final expedition = await AdventureService().dispatchExpedition(route.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _armedRouteId = null;
    });
    if (expedition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CANNOT DISPATCH RIGHT NOW',
            style: AppFonts.shareTechMono(color: kBg, fontSize: 11),
          ),
          backgroundColor: kAmber,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await _load();
  }

  Future<void> _collect() async {
    if (_busy) return;
    setState(() => _busy = true);
    final report = await AdventureService().settleAndPeekReport();
    if (!mounted) {
      return;
    }
    if (report != null) {
      await Navigator.of(context).push(
        arcadeRoute(
          (_) => ExpeditionReportPage(
            report: report,
            avatarSpec: _avatar,
            characterClass: _class,
          ),
          motion: ArcadeRouteMotion.fade,
        ),
      );
      await AdventureService().acknowledgeReport(report.expedition.id);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }
    final pending = _state.pending;
    final out = pending != null && !_isReturned(pending);
    final returned = pending != null && _isReturned(pending);

    final armedRoute = _armedRouteId == null
        ? null
        : adventureRouteById(_armedRouteId);
    final activeRoute = armedRoute ??
        (pending != null
            ? adventureRouteById(pending.routeId)
            : adventureRouteById(_state.standingOrderRouteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Adventure')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            RouteDiorama(
              route: activeRoute,
              avatarSpec: _avatar,
              characterClass: _class,
              height: 200,
              animate: out,
            ),
            const SizedBox(height: kSpace2),
            if (out)
              _outPanel(pending)
            else if (returned)
              _returnedPanel(pending)
            else
              _stageSelect(activeRoute),
            const SizedBox(height: kSpace3),
            if (_state.history.isNotEmpty) ...[
              Text(
                'PAST EXPEDITIONS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kText,
                ),
              ),
              const SizedBox(height: kSpace2),
              for (final expedition in _state.history)
                _HistoryRow(expedition: expedition),
            ],
            const SizedBox(height: kSpace5),
          ],
        ),
      ),
    );
  }

  // ---- OUT (counting down) ------------------------------------------------

  Widget _outPanel(Expedition pending) {
    final route = adventureRouteById(pending.routeId);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final returnsAt = _returnsAt(pending);
    final remaining = returnsAt == null
        ? Duration.zero
        : returnsAt.difference(DateTime.now());
    final flavor = route
        .flavorLines[pending.flavorIdx % route.flavorLines.length];
    final back = reduceMotion
        ? 'BACK IN ~${(remaining.inMinutes / 60).ceil()}H'
        : 'BACK IN ${_fmtCountdown(remaining)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ON ADVENTURE · ${route.name}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            height: 1.5,
            color: route.accent,
          ),
        ),
        const SizedBox(height: kSpace2),
        Text(
          flavor,
          style: AppFonts.shareTechMono(
            color: kMutedText,
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: kSpace3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: kSpace3,
            horizontal: kSpace3,
          ),
          decoration: BoxDecoration(
            color: kBg.withValues(alpha: 0.5),
            border: Border.all(color: route.accent.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule_sharp, size: 16, color: route.accent),
              const SizedBox(width: kSpace2),
              Text(
                back,
                style: AppFonts.shareTechMono(
                  color: kText,
                  fontSize: 16,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpace2),
        const _DisabledCollect(),
      ],
    );
  }

  // ---- RETURNED (collectable) ---------------------------------------------

  Widget _returnedPanel(Expedition pending) {
    final route = adventureRouteById(pending.routeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RETURNED FROM ${route.name}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            height: 1.5,
            color: kNeon,
          ),
        ),
        const SizedBox(height: kSpace1),
        Text(
          'Your character is back with the haul.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: kMutedText, height: 1.4),
        ),
        const SizedBox(height: kSpace3),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _collect,
            child: const Text('COLLECT REPORT'),
          ),
        ),
      ],
    );
  }

  // ---- IDLE (stage select) ------------------------------------------------

  Widget _stageSelect(AdventureRouteDef activeRoute) {
    final charges = _state.charges;
    final weekCount = _state.weekCount;
    final capHit = weekCount >= AdventureService.weeklyCap;
    final canDispatch = charges > 0 && !capHit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'EXPEDITION ORDERS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: kText,
                ),
              ),
            ),
            _ChargePips(charges: charges),
          ],
        ),
        const SizedBox(height: kSpace2),
        Text(
          canDispatch
              ? 'Pick a route and DISPATCH to spend a charge. Recovery (VIT) '
                    'sets how long the haul runs and how rich it pays.'
              : capHit
              ? 'Weekly expedition limit reached — your charges bank for next '
                    'week.'
              : 'Log a workout to earn an expedition charge.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: kMutedText, height: 1.4),
        ),
        const SizedBox(height: kSpace3),
        for (final route in adventureRoutes) ...[
          _RouteStageCard(
            route: route,
            rank: StatEngine().getRank(_stats[route.statKey] ?? 0),
            vit: _vit,
            armed: _armedRouteId == route.id,
            dimmed: _armedRouteId != null && _armedRouteId != route.id,
            enabled: canDispatch,
            onTap: !canDispatch
                ? null
                : () => setState(
                    () => _armedRouteId =
                        _armedRouteId == route.id ? null : route.id,
                  ),
          ),
          const SizedBox(height: kSpace2),
        ],
        if (_armedRouteId != null && canDispatch) ...[
          const SizedBox(height: kSpace1),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () => _dispatch(adventureRouteById(_armedRouteId)),
              child: Text('DISPATCH · ${adventureRouteById(_armedRouteId).name}'),
            ),
          ),
          const SizedBox(height: kSpace1),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => setState(() => _armedRouteId = null),
              child: Text(
                'CHANGE ROUTE',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
              ),
            ),
          ),
        ],
        const SizedBox(height: kSpace2),
        Text(
          'THIS WEEK: ${weekCount.clamp(0, AdventureService.weeklyCap)}/'
          '${AdventureService.weeklyCap}',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
        ),
      ],
    );
  }

  String _fmtCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return '0M';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}H ${m}M' : '${m}M';
  }
}

/// A charge meter — filled pips up to the cap ("CHARGES ▮▮▯").
class _ChargePips extends StatelessWidget {
  const _ChargePips({required this.charges});

  final int charges;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CHARGES ',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
        ),
        for (var i = 0; i < AdventureState.chargeCap; i++)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Container(
              width: 8,
              height: 12,
              color: i < charges ? kNeon : kBorder,
            ),
          ),
        const SizedBox(width: kSpace1),
        Text(
          '$charges/${AdventureState.chargeCap}',
          style: AppFonts.shareTechMono(color: kText, fontSize: 10),
        ),
      ],
    );
  }
}

class _DisabledCollect extends StatelessWidget {
  const _DisabledCollect();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: null,
        child: Text(
          'OUT ON EXPEDITION',
          style: AppFonts.shareTechMono(
            color: kMutedText,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// A selectable route stage tile. When armed it expands to a payout preview
/// (rank → pay, VIT → duration + multiplier, est total); the other tiles dim
/// and lock. Reuses [AdventureEmblem] with its code-drawn fallback.
class _RouteStageCard extends StatelessWidget {
  const _RouteStageCard({
    required this.route,
    required this.rank,
    required this.vit,
    required this.armed,
    required this.dimmed,
    required this.enabled,
    required this.onTap,
  });

  final AdventureRouteDef route;
  final String rank;
  final int vit;
  final bool armed;
  final bool dimmed;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = AdventureService.basePayoutForRank(rank);
    final multiplier = AdventureService.multiplierForVit(vit);
    final durationMin = AdventureService.durationForVit(vit);
    final est = (base * multiplier).round();
    final borderColor = armed ? route.accent : kBorder;

    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: IgnorePointer(
        ignoring: dimmed,
        child: Material(
          color: kCard,
          borderRadius: BorderRadius.circular(kCardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kCardRadius),
            child: Container(
              padding: const EdgeInsets.all(kSpace3),
              decoration: BoxDecoration(
                border: Border.all(
                  color: borderColor,
                  width: armed
                      ? kPrimaryCardBorderWidth + 0.6
                      : kPrimaryCardBorderWidth,
                ),
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AdventureEmblem(route: route, size: 44),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.name,
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 8,
                                height: 1.4,
                                color: armed ? route.accent : kText,
                              ),
                            ),
                            const SizedBox(height: kSpace1),
                            Text(
                              '${route.statKey} ROUTE · RANK $rank · ~$base GEMS',
                              style: AppFonts.shareTechMono(
                                color: kMutedText,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpace2),
                      Text(
                        armed ? 'ARMED' : 'SELECT',
                        style: AppFonts.shareTechMono(
                          color: armed ? route.accent : kNeon,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  if (armed) ...[
                    const SizedBox(height: kSpace2),
                    Container(height: 1, color: kBorder),
                    const SizedBox(height: kSpace2),
                    _previewRow(
                      'BACK IN',
                      '~${(durationMin / 60).round()}H',
                      route.accent,
                    ),
                    _previewRow(
                      'VIT $vit',
                      '×${multiplier.toStringAsFixed(2)}',
                      kCyan,
                    ),
                    _previewRow('EST PAYOUT', '~$est GEMS', kNeon),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
            ),
          ),
          Text(
            value,
            style: AppFonts.shareTechMono(
              color: valueColor,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.expedition});

  final Expedition expedition;

  @override
  Widget build(BuildContext context) {
    final route = adventureRouteById(expedition.routeId);
    final find = adventureFindById(expedition.findId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace1),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              expedition.day.substring(5), // mm-dd
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              find == null ? route.name : '${route.name} · ${find.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.shareTechMono(color: kText, fontSize: 10),
            ),
          ),
          Text(
            '+${expedition.payout}',
            style: AppFonts.shareTechMono(color: kNeon, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
