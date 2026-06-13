import 'package:flutter/material.dart';

import '../data/adventure_routes.dart';
import '../models/adventure_models.dart';
import '../models/avatar_spec.dart';
import '../models/character_class.dart';
import '../models/loot_item.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import '../widgets/adventure/route_diorama.dart';
import '../widgets/arcade_route.dart';
import '../widgets/count_up_text.dart';
import '../widgets/pixel_button.dart';
import 'adventure_page.dart';

/// The expedition report ceremony — greets the user on the app sitting
/// after a dispatch. Diorama up top (the journey), staged report below
/// (route, flavor, gem count-up, find). Settlement already happened in the
/// service; this screen is pure presentation and is always skippable.
class ExpeditionReportPage extends StatefulWidget {
  const ExpeditionReportPage({
    super.key,
    required this.report,
    required this.avatarSpec,
    this.characterClass,
  });

  final ExpeditionReport report;
  final AvatarSpec avatarSpec;
  final CharacterClass? characterClass;

  @override
  State<ExpeditionReportPage> createState() => _ExpeditionReportPageState();
}

class _ExpeditionReportPageState extends State<ExpeditionReportPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stage;

  @override
  void initState() {
    super.initState();
    _stage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _stage.value = 1;
      } else {
        _stage.forward();
      }
    });
  }

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  /// Staggered opacity for report row [index] of [total].
  Widget _staged(int index, int total, Widget child) {
    return AnimatedBuilder(
      animation: _stage,
      builder: (context, _) {
        final start = index / (total + 1);
        final end = (index + 1) / (total + 1);
        final t = ((_stage.value - start) / (end - start)).clamp(0.0, 1.0);
        return Opacity(opacity: t, child: child);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expedition = widget.report.expedition;
    final route = adventureRouteById(expedition.routeId);
    final find = adventureFindById(expedition.findId);
    final flavor =
        route.flavorLines[expedition.flavorIdx % route.flavorLines.length];

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RouteDiorama(
              route: route,
              avatarSpec: widget.avatarSpec,
              characterClass: widget.characterClass,
              height: 220,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpace4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _staged(
                      0,
                      5,
                      Text(
                        'EXPEDITION REPORT',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: route.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    _staged(
                      1,
                      5,
                      Text(
                        '${route.name} · ${route.statKey} ROUTE · '
                        'RANK ${expedition.rank}',
                        style: AppFonts.shareTechMono(
                          color: kMutedText,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace3),
                    _staged(
                      2,
                      5,
                      Text(
                        flavor,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kText,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace4),
                    _staged(
                      3,
                      5,
                      Row(
                        children: [
                          Image.asset(
                            'assets/icons/economy/icon_gem.png',
                            width: 22,
                            height: 22,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.diamond_sharp, color: kCyan),
                          ),
                          const SizedBox(width: kSpace2),
                          CountUpText(
                            value: expedition.payout,
                            prefix: '+',
                            suffix: ' GEMS',
                            style: AppFonts.shareTechMono(
                              color: kNeon,
                              fontSize: 20,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (find != null) ...[
                      const SizedBox(height: kSpace3),
                      _staged(4, 5, _FindRow(find: find)),
                    ],
                    if (widget.report.classDefaultOrders) ...[
                      const SizedBox(height: kSpace4),
                      _staged(
                        4,
                        5,
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(kSpace2),
                          decoration: BoxDecoration(
                            color: kBg.withValues(alpha: 0.5),
                            border: Border.all(
                              color: kMutedText.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(kCardRadius),
                          ),
                          child: Text(
                            'ORDERS: CLASS DEFAULT — ${route.name} '
                            '(${route.statKey} ROUTE). '
                            'Your character follows your class until you '
                            'set your own orders.',
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: kSpace5),
                    PixelButton(
                      label: 'CONTINUE',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (widget.report.classDefaultOrders) ...[
                      const SizedBox(height: kSpace2),
                      PixelButton(
                        label: 'CHANGE ORDERS',
                        secondary: true,
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            arcadeRoute(
                              (_) => const AdventurePage(),
                              motion: ArcadeRouteMotion.fade,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindRow extends StatelessWidget {
  const _FindRow({required this.find});

  final AdventureFindDef find;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: kBg,
            border: Border.all(color: find.rarity.color, width: 1.2),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          padding: const EdgeInsets.all(3),
          child: Image.asset(
            find.iconAsset,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) =>
                Icon(Icons.help_outline_sharp, size: 18, color: kMutedText),
          ),
        ),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FOUND: ${find.name.toUpperCase()}',
                style: AppFonts.shareTechMono(
                  color: kText,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                find.rarity.label,
                style: AppFonts.shareTechMono(
                  color: find.rarity.color,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
