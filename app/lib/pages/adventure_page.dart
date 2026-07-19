import 'dart:async';

import 'package:flutter/material.dart';

import '../data/adventure_routes.dart';
import '../models/adventure_models.dart';
import '../services/adventure_service.dart';
import '../utils/iso_week.dart';
import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../services/stat_engine.dart';
import '../services/ui_sound.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/adventure/route_diorama.dart';
import '../widgets/arcade_filled.dart';
import '../widgets/arcade_route.dart';
import '../widgets/pixel_loader.dart';
import 'expedition_report_page.dart';
import '../widgets/arcade_notice.dart';

/// The Adventure area (v3): a console **stage-select**. Three framed route
/// backdrops stack vertically. With a charge you tap one to arm it (it dims,
/// shows its payout, and comes alive — no sprite yet); GO ON ADVENTURE spends
/// the charge and the chosen route brightens with your walking character while
/// the other two lock. The report greets you on return — collected here or on
/// the next Home open. Presentation only: the service/state machine is v2.
class AdventurePage extends StatefulWidget {
  const AdventurePage({super.key});

  @override
  State<AdventurePage> createState() => _AdventurePageState();
}

/// The role a single backdrop plays in the current screen state — drives its
/// animate / sprite / darken / tap behavior so exactly one tile ever animates.
enum _TileRole { selectable, armed, activeOut, activeReturned, locked }

class _AdventurePageState extends State<AdventurePage> {
  bool _loading = true;
  bool _busy = false;
  bool _showBreakdown = false;
  AdventureState _state = AdventureState();
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
    final stats = await StatEngine().getStoredStats();
    if (!mounted) return;
    setState(() {
      _state = state;
      _stats = stats;
      _loading = false;
    });
    _syncTicker();
  }

  AdventureUiState get _ui => adventureUiStateOf(
    _state,
    DateTime.now(),
    currentWeekIso: isoWeekKey(DateTime.now()),
  );

  /// A coarse logic timer (NOT an animation) that recomputes the phase so an
  /// expedition flips out→returned even under reduced motion, where the
  /// diorama clock is frozen. Only runs while genuinely out.
  void _syncTicker() {
    _ticker?.cancel();
    if (_ui.phase == AdventurePhase.out) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});
        if (_ui.phase != AdventurePhase.out) _ticker?.cancel();
      });
    }
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
      _showBreakdown = false;
    });
    if (expedition == null) {
      showArcadeNotice(context, 'CANNOT DISPATCH RIGHT NOW');
    }
    await _load();
  }

  Future<void> _collect() async {
    if (_busy) return;
    setState(() => _busy = true);
    final report = await AdventureService().settleAndPeekReport();
    if (!mounted) return;
    if (report != null) {
      await Navigator.of(context).push(
        arcadeRoute(
          (_) => ExpeditionReportPage(
            report: report,
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

  _TileRole _roleFor(AdventureRouteDef route) {
    final ui = _ui;
    final pendingRouteId = _state.pending?.routeId;
    if (ui.phase == AdventurePhase.out || ui.phase == AdventurePhase.returned) {
      if (route.id == pendingRouteId) {
        return ui.phase == AdventurePhase.out
            ? _TileRole.activeOut
            : _TileRole.activeReturned;
      }
      return _TileRole.locked;
    }
    return _armedRouteId == route.id ? _TileRole.armed : _TileRole.selectable;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }
    final ui = _ui;

    return Scaffold(
      appBar: AppBar(title: const Text('Adventure')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            _header(ui),
            const SizedBox(height: kSpace2),
            _statusLine(ui),
            const SizedBox(height: kSpace3),
            for (final route in adventureRoutes) ...[
              _RouteBackdrop(
                route: route,
                role: _roleFor(route),
                rank: StatEngine().getRank(_stats[route.statKey] ?? 0),
                vit: _vit,
                pending: _state.pending,
                showBreakdown: _showBreakdown,
                onToggleBreakdown: () =>
                    setState(() => _showBreakdown = !_showBreakdown),
                onTap: ui.phase == AdventurePhase.idle
                    ? () => setState(() {
                        _armedRouteId = _armedRouteId == route.id
                            ? null
                            : route.id;
                        _showBreakdown = false;
                      })
                    : null,
                onCollect: _busy ? null : _collect,
              ),
              const SizedBox(height: kSpace3),
            ],
            if (ui.phase == AdventurePhase.idle && _armedRouteId != null)
              _dispatchBar(ui),
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

  Widget _header(AdventureUiState ui) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'EXPEDITION ROUTES',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: kText,
            ),
          ),
        ),
        if (ui.phase == AdventurePhase.idle) _ChargePips(charges: ui.charges),
      ],
    );
  }

  Widget _statusLine(AdventureUiState ui) {
    final String text;
    switch (ui.phase) {
      case AdventurePhase.out:
        text = 'Your character is out on an expedition.';
      case AdventurePhase.returned:
        text = 'Your character has returned — collect the haul.';
      case AdventurePhase.idle:
        text = ui.weeklyCapped
            ? 'Weekly expedition limit reached — your charges bank for next '
                  'week.'
            : ui.charges > 0
            ? 'Pick a route and GO. Higher recovery (VIT) means a longer, '
                  'richer haul.'
            : 'Do a workout to earn a charge.';
    }
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: kMutedText, height: 1.4),
    );
  }

  Widget _dispatchBar(AdventureUiState ui) {
    final route = adventureRouteById(_armedRouteId);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ArcadeFilled(
            onPressed: (ui.canDispatch && !_busy) ? () => _dispatch(route) : null,
            child: Text('GO ON ADVENTURE · ${route.name}'),
          ),
        ),
        if (!ui.canDispatch) ...[
          const SizedBox(height: kSpace1),
          Text(
            ui.weeklyCapped
                ? 'Weekly limit reached.'
                : 'Do a workout to earn a charge.',
            style: AppFonts.shareTechMono(color: kAmber, fontSize: 10),
          ),
        ],
        const SizedBox(height: kSpace1),
        ArcadeTextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _armedRouteId = null;
                  _showBreakdown = false;
                }),
          child: Text(
            '✕ CANCEL',
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

/// A framed route backdrop tile that plays one of the [_TileRole]s. Hosts the
/// diorama (animate/sprite/darken per role) plus the role-appropriate overlay.
class _RouteBackdrop extends StatelessWidget {
  const _RouteBackdrop({
    required this.route,
    required this.role,
    required this.rank,
    required this.vit,
    required this.pending,
    required this.showBreakdown,
    required this.onToggleBreakdown,
    required this.onTap,
    required this.onCollect,
  });

  final AdventureRouteDef route;
  final _TileRole role;
  final String rank;
  final int vit;
  final Expedition? pending;
  final bool showBreakdown;
  final VoidCallback onToggleBreakdown;
  final VoidCallback? onTap;
  final VoidCallback? onCollect;

  bool get _animate => role == _TileRole.armed || role == _TileRole.activeOut;
  bool get _showWalker =>
      role == _TileRole.activeOut || role == _TileRole.activeReturned;
  bool get _darkened => role == _TileRole.armed || role == _TileRole.locked;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null &&
        (role == _TileRole.selectable || role == _TileRole.armed);
    // haptic-ok: feedback fired inline below (arm/disarm select tick)
    return GestureDetector(
      onTap: tappable
          ? () {
              HapticService.instance.fireCoalesced(HapticIntent.selection);
              SfxService.instance.playUi(UiSound.select);
              onTap!();
            }
          : null,
      child: SizedBox(
        height: 132,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RouteDiorama(
              route: route,
              height: 132,
              animate: _animate,
              showWalker: _showWalker,
              framed: true,
              darkened: _darkened,
            ),
            Positioned.fill(child: _overlay(context)),
          ],
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    switch (role) {
      case _TileRole.selectable:
        return _selectableOverlay();
      case _TileRole.armed:
        return _armedOverlay();
      case _TileRole.activeOut:
        return _ongoingOverlay(context);
      case _TileRole.activeReturned:
        return _returnedOverlay();
      case _TileRole.locked:
        return _lockedOverlay();
    }
  }

  // Bottom name strip + SELECT hint (no reward numbers — anticipation).
  Widget _selectableOverlay() {
    return Padding(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _pill('TAP TO SELECT', kNeon),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _routeTitle(),
              const SizedBox(height: 2),
              _pill('${route.statKey} ROUTE · RANK $rank', kMutedText),
            ],
          ),
        ],
      ),
    );
  }

  // Centered inspect card: duration + a qualitative "how it works" — never the
  // gem math (anticipation; the exact payout is revealed only in the report).
  Widget _armedOverlay() {
    final durH = (AdventureService.durationForVit(vit) / 60).round();
    return Padding(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _routeTitle(center: true),
          const SizedBox(height: kSpace1),
          Text(
            'RANK $rank · ~${durH}H',
            style: AppFonts.shareTechMono(
              color: kText,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: kSpace1),
          _detailToggle(),
          if (showBreakdown) ...[
            const SizedBox(height: 2),
            Text(
              'Higher VIT → higher rewards',
              style: AppFonts.shareTechMono(color: kCyan, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  // Ongoing: just the state + countdown. No "?" — the user committed to the
  // route already; details belong before dispatch, not mid-expedition.
  Widget _ongoingOverlay(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final returnsAt = pending?.returnsAtIso == null
        ? null
        : DateTime.tryParse(pending!.returnsAtIso!);
    final remaining = returnsAt == null
        ? Duration.zero
        : returnsAt.difference(DateTime.now());
    final back = reduceMotion
        ? 'BACK IN ~${(remaining.inMinutes / 60).ceil()}H'
        : 'BACK IN ${_fmtCountdown(remaining)}';
    return Padding(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _pill('ON EXPEDITION', route.accent),
          _pill(back, kText),
        ],
      ),
    );
  }

  Widget _returnedOverlay() {
    return Padding(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RETURNED',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: kNeon,
            ),
          ),
          const SizedBox(height: kSpace2),
          ArcadeFilled(
            onPressed: onCollect,
            child: const Text('COLLECT'),
          ),
        ],
      ),
    );
  }

  Widget _lockedOverlay() {
    return Padding(
      padding: const EdgeInsets.all(kSpace3),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: _pill(route.name, kMutedText),
      ),
    );
  }

  Widget _routeTitle({bool center = false}) => Text(
    route.name,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: 9,
      height: 1.4,
      color: route.accent,
    ),
  );

  // haptic-ok: feedback fired inline below (breakdown toggle tick)
  Widget _detailToggle() => GestureDetector(
    onTap: () {
      HapticService.instance.fireCoalesced(HapticIntent.selection);
      SfxService.instance.playUi(UiSound.tick);
      onToggleBreakdown();
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qmark(),
        const SizedBox(width: 4),
        Text(
          showBreakdown ? 'HIDE' : 'HOW IT WORKS',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 9),
        ),
      ],
    ),
  );

  Widget _qmark() => Container(
    width: 16,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: kBg.withValues(alpha: 0.6),
      border: Border.all(color: kMutedText, width: 1),
      borderRadius: BorderRadius.circular(kCardRadius),
    ),
    child: Text(
      '?',
      style: AppFonts.shareTechMono(color: kMutedText, fontSize: 10),
    ),
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: kBg.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(kCardRadius),
    ),
    child: Text(
      text,
      style: AppFonts.shareTechMono(
        color: color,
        fontSize: 10,
        letterSpacing: 1.1,
      ),
    ),
  );

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
