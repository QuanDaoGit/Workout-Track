import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../arcade_filled.dart';

import '../../data/adventure_routes.dart';
import '../../services/adventure_service.dart';
import '../../services/stat_engine.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import 'energy_cell.dart';

/// In-room Expedition dispatch console — an arcade bottom sheet: pick a route and
/// SEND BIT (spends a workout-minted charge). Presentation only: the caller's
/// [onSend] performs `AdventureService.dispatchExpedition` and owns the
/// snackbar + reload (so the service stays the source of truth). SEND disables
/// on tap (no double-dispatch); the sheet is modal, so the Home auto-reveal is
/// blocked underneath while it's open (no reveal-beneath race).
Future<void> showExpeditionDispatchSheet(
  BuildContext context, {
  required int charges,
  required int vit,
  required Map<String, int> stats,
  String? selectedRouteId,
  required Future<bool> Function(String routeId) onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DispatchSheet(
      charges: charges,
      vit: vit,
      stats: stats,
      selectedRouteId: selectedRouteId,
      onSend: onSend,
    ),
  );
}

class _DispatchSheet extends StatefulWidget {
  const _DispatchSheet({
    required this.charges,
    required this.vit,
    required this.stats,
    required this.selectedRouteId,
    required this.onSend,
  });

  final int charges;
  final int vit;
  final Map<String, int> stats;
  final String? selectedRouteId;
  final Future<bool> Function(String routeId) onSend;

  @override
  State<_DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends State<_DispatchSheet> {
  late String _routeId = adventureRouteById(widget.selectedRouteId).id;
  bool _busy = false;

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onSend(_routeId); // owns snackbar + reload + room launch
    if (mounted) Navigator.of(context).pop();
  }

  /// The expected gem haul for a route, rounded to the nearest 10 — the base
  /// pay for the user's rank on the route's stat × the VIT duration multiplier.
  /// (The payout's ±variance averages out, so base×mult is the expected value.)
  /// This is the row's only at-a-glance "what do I get" cue now.
  int _approxGemsFor(AdventureRouteDef route) {
    final rank = StatEngine().getRank(widget.stats[route.statKey] ?? 0);
    final base = AdventureService.basePayoutForRank(rank);
    final expected = base * AdventureService.multiplierForVit(widget.vit);
    return (expected / 10).round() * 10;
  }

  @override
  Widget build(BuildContext context) {
    final route = adventureRouteById(_routeId);
    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(
          top: BorderSide(color: kBorder, width: kPrimaryCardBorderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'WHERE DOES BIT SCOUT?',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        height: 1.4,
                        color: kText,
                      ),
                    ),
                  ),
                  _ChargeReadout(charges: widget.charges),
                ],
              ),
              const SizedBox(height: kSpace3),
              for (final r in adventureRoutes) ...[
                _RouteRow(
                  route: r,
                  approxGems: _approxGemsFor(r),
                  selected: r.id == _routeId,
                  onTap: _busy ? null : () => setState(() => _routeId = r.id),
                ),
                const SizedBox(height: kSpace2),
              ],
              const SizedBox(height: kSpace2),
              SizedBox(
                height: kButtonHeight,
                child: ArcadeFilled(
                  onPressed: _busy ? null : _send,
                  // The launch whoosh (padDispatch, fired by the room's
                  // send-off animation) owns this commit's audio — no tick.
                  haptic: HapticIntent.success,
                  sound: false,
                  child: Text(_busy ? 'SENDING…' : 'SEND BIT · ${route.name}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable route row — accent dot + name + approximate gem haul.
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.route,
    required this.approxGems,
    required this.selected,
    required this.onTap,
  });

  final AdventureRouteDef route;
  final int approxGems;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace3,
          vertical: kSpace3,
        ),
        decoration: BoxDecoration(
          color: kBg,
          border: Border.all(
            color: selected ? route.accent : kBorder,
            width: selected ? kPrimaryCardBorderWidth : 1,
          ),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 8, color: route.accent),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Text(
                route.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  height: 1.4,
                  color: route.accent,
                ),
              ),
            ),
            // The only at-a-glance payoff cue: the approximate gem haul (a
            // multiple of 10), gem-magenta so it reads as currency.
            Semantics(
              label: 'about $approxGems gems',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/economy/icon_gem.png',
                    width: 14,
                    height: 14,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.diamond_sharp,
                      color: kGemMagenta,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: kSpace1),
                  Text(
                    '~$approxGems',
                    style: AppFonts.shareTechMono(
                      color: kGemMagenta,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

/// CHARGES — the energy-cell icon + the banked `N/3` count (cap 3). The cell is
/// static here (`glow: false`) so the console sheet has no perpetual ticker.
class _ChargeReadout extends StatelessWidget {
  const _ChargeReadout({required this.charges});

  final int charges;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const EnergyCell(scale: 1, glow: false),
        const SizedBox(width: 6),
        Text(
          '$charges/3',
          style: AppFonts.shareTechMono(color: kText, fontSize: 13, height: 1),
        ),
      ],
    );
  }
}
