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
import '../widgets/pixel_loader.dart';

/// The Adventure area (v1: pushed from Home). Live diorama of the standing
/// route, the three stat-keyed route order cards (rank → pay tier), the
/// weekly expedition count, and the report history.
class AdventurePage extends StatefulWidget {
  const AdventurePage({super.key});

  @override
  State<AdventurePage> createState() => _AdventurePageState();
}

class _AdventurePageState extends State<AdventurePage> {
  bool _loading = true;
  AdventureState _state = AdventureState();
  AvatarSpec _avatar = AvatarSpec.fallback;
  CharacterClass? _class;
  Map<String, int> _stats = const {};

  @override
  void initState() {
    super.initState();
    _load();
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
  }

  Future<void> _setOrders(AdventureRouteDef route) async {
    await AdventureService().setStandingOrder(route.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ORDERS SET: ${route.name}',
          style: AppFonts.shareTechMono(color: kBg, fontSize: 11),
        ),
        backgroundColor: route.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: PixelLoader()));
    }
    final activeRoute = adventureRouteById(_state.standingOrderRouteId);
    final out = _state.pending != null;
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
            ),
            const SizedBox(height: kSpace2),
            Text(
              out
                  ? 'CHARACTER IS OUT ON ${activeRoute.name} — '
                        'REPORT ON YOUR RETURN.'
                  : 'NEXT WORKOUT DISPATCHES TO ${activeRoute.name}.',
              style: AppFonts.shareTechMono(
                color: kMutedText,
                fontSize: 10,
                letterSpacing: 1.1,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kSpace4),
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
                Text(
                  'THIS WEEK: ${_weekCountLabel()}',
                  style: AppFonts.shareTechMono(
                    color: kMutedText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace2),
            Text(
              'One expedition per day — your first workout of the day '
              'sends your character out. Rank on the route\'s stat sets '
              'the pay.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: kMutedText, height: 1.4),
            ),
            const SizedBox(height: kSpace3),
            for (final route in adventureRoutes) ...[
              _RouteOrderCard(
                route: route,
                rank: StatEngine().getRank(_stats[route.statKey] ?? 0),
                selected: route.id == activeRoute.id,
                onSelect: () => _setOrders(route),
              ),
              const SizedBox(height: kSpace2),
            ],
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

  String _weekCountLabel() {
    final count = _state.weekCount.clamp(0, AdventureService.weeklyCap);
    return '$count/${AdventureService.weeklyCap}';
  }
}

class _RouteOrderCard extends StatelessWidget {
  const _RouteOrderCard({
    required this.route,
    required this.rank,
    required this.selected,
    required this.onSelect,
  });

  final AdventureRouteDef route;
  final String rank;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final base = AdventureService.basePayoutForRank(rank);
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: InkWell(
        onTap: selected ? null : onSelect,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? route.accent : kBorder,
              width: kPrimaryCardBorderWidth,
            ),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
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
                        color: selected ? route.accent : kText,
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
                selected ? 'ACTIVE' : 'SET',
                style: AppFonts.shareTechMono(
                  color: selected ? route.accent : kNeon,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
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
