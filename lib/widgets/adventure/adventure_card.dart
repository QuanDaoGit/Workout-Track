import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/adventure_routes.dart';
import '../../models/adventure_models.dart';
import '../../services/guild_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';

/// Compact Home callout for Adventure — deliberately static except for a
/// single subtle "Ongoing expedition…" ellipsis while out. Shows a generic
/// emblem + "no expedition" when idle, the crafted route emblem when an
/// expedition is live, and a collect prompt on return. Taps through to the
/// AdventurePage. Phase is derived from the shared [adventureUiStateOf] so it
/// never disagrees with the page.
class AdventureCard extends StatelessWidget {
  const AdventureCard({super.key, required this.state, this.onTap});

  final AdventureState state;
  final VoidCallback? onTap;

  static const _genericEmblem = 'assets/adventure/emblem_adventure_mode.png';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ui = adventureUiStateOf(
      state,
      now,
      currentWeekIso: GuildService.weekIso(now),
    );
    final route = adventureRouteById(state.standingOrderRouteId);
    final pending = state.pending;
    final live = ui.phase != AdventurePhase.idle;

    // Per-phase title + subtitle.
    final Widget title;
    final String subtitle;
    switch (ui.phase) {
      case AdventurePhase.returned:
        title = Text(
          'RETURNED',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            height: 1.5,
            color: kNeon,
          ),
        );
        subtitle = 'Tap to collect the haul.';
      case AdventurePhase.out:
        title = _OngoingTitle(color: route.accent);
        final returnsAt = pending?.returnsAtIso == null
            ? null
            : DateTime.tryParse(pending!.returnsAtIso!);
        final hrs = returnsAt == null
            ? null
            : (returnsAt.difference(now).inMinutes / 60).ceil();
        subtitle = hrs == null
            ? '${route.name} — on expedition.'
            : '${route.name} — back in ~${hrs}h';
      case AdventurePhase.idle:
        title = Text(
          'NO EXPEDITION',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            height: 1.5,
            color: kMutedText,
          ),
        );
        subtitle = ui.weeklyCapped
            ? 'Weekly limit reached — back next week.'
            : ui.charges > 0
            ? '${ui.charges} charge${ui.charges == 1 ? '' : 's'} ready · tap to dispatch'
            : 'No expedition is going on · train to earn a charge';
    }

    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            border: Border.all(color: kBorder, width: kPrimaryCardBorderWidth),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Row(
            children: [
              live
                  ? _Emblem(route: route)
                  : const _GenericEmblem(asset: _genericEmblem),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADVENTURE',
                      style: AppFonts.shareTechMono(
                        color: kMutedText,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: kSpace1),
                    title,
                    const SizedBox(height: kSpace1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: kMutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpace2),
              const Icon(Icons.chevron_right_sharp, color: kMutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// "ONGOING EXPEDITION" with a subtle cycling ellipsis (·/··/···). NOT a
/// marquee — the dots are the only motion, and they freeze under reduced
/// motion (a documented alternative to scrolling text).
class _OngoingTitle extends StatefulWidget {
  const _OngoingTitle({required this.color});

  final Color color;

  @override
  State<_OngoingTitle> createState() => _OngoingTitleState();
}

class _OngoingTitleState extends State<_OngoingTitle> {
  Timer? _timer;
  int _dots = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _timer?.cancel();
    if (reduceMotion) {
      _dots = 3; // static "…" — no ticking
    } else {
      _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
        if (!mounted) return;
        setState(() => _dots = (_dots + 1) % 4);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'ONGOING EXPEDITION${'.' * _dots}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 8,
        height: 1.5,
        color: widget.color,
      ),
    );
  }
}

/// Route emblem with a code-drawn fallback (route initial in the accent)
/// so a missing PNG can never break the Home card.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.route, this.size = 40});

  final AdventureRouteDef route;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        route.emblemAsset,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: kBg,
            border: Border.all(color: kBorder, width: 1.2),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: Center(
            child: Text(
              route.name.substring(0, 1),
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: size * 0.4,
                color: route.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The generic "no expedition" emblem, with a muted code-drawn fallback.
class _GenericEmblem extends StatelessWidget {
  const _GenericEmblem({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Image.asset(
        asset,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: kBg,
            border: Border.all(color: kBorder, width: 1.2),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: const Center(
            child: Icon(Icons.explore_sharp, color: kMutedText, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Public emblem widget for other Adventure surfaces.
class AdventureEmblem extends StatelessWidget {
  const AdventureEmblem({super.key, required this.route, this.size = 48});

  final AdventureRouteDef route;
  final double size;

  @override
  Widget build(BuildContext context) => _Emblem(route: route, size: size);
}
