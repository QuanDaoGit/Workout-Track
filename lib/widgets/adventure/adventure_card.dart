import 'package:flutter/material.dart';

import '../../data/adventure_routes.dart';
import '../../models/adventure_models.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';

/// Compact Home callout for Adventure — deliberately static (no perpetual
/// animation on Home). Shows the standing orders and whether the character
/// is currently out; taps through to the AdventurePage.
class AdventureCard extends StatelessWidget {
  const AdventureCard({super.key, required this.state, this.onTap});

  final AdventureState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final route = adventureRouteById(state.standingOrderRouteId);
    final out = state.pending != null;
    final title = out ? 'CHARACTER IS OUT' : 'EXPEDITION ORDERS';
    final subtitle = out
        ? '${route.name} — report on your return.'
        : '${route.name} · ${route.statKey} route';
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
              _Emblem(route: route, dimmed: out),
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
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        height: 1.5,
                        color: out ? kCyan : route.accent,
                      ),
                    ),
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

/// Route emblem with a code-drawn fallback (route initial in the accent)
/// so a missing PNG can never break the Home card.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.route, this.dimmed = false, this.size = 40});

  final AdventureRouteDef route;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: SizedBox(
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
