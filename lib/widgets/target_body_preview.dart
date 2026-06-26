import 'package:flutter/material.dart';

import '../data/body_map_regions.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';

/// A compact, static **"today's targets"** body preview for the exercise-selection
/// surface: the muscles the currently-selected lifts will train, lit on a pixel
/// body — **PRIMARY bright, SECONDARY dim** (mirroring the coverage analyzer's
/// 1.0/0.5 credit so a synergist is never overstated as a main target).
///
/// A plan PREVIEW, not a coverage verdict: no volume ramp, no MEV/MAV, no zone
/// words. Presentational — it takes the already-resolved target sets (from
/// [targetedBodyMuscles]) so it can't disagree with the history map and is
/// trivially testable. Only the side(s) with a target render (a push day shows no
/// all-dark back — body-neutral). Reduced-motion-safe by construction (fully
/// static). The **TARGETS text line is the screen-reader source** (the body is
/// decorative / excluded), so meaning never rides on color alone.
class TargetBodyPreview extends StatelessWidget {
  const TargetBodyPreview({
    super.key,
    required this.primaryMuscles,
    required this.secondaryMuscles,
  });

  /// Body-muscle ids a selected lift trains as its primary muscle.
  final Set<String> primaryMuscles;

  /// Body-muscle ids hit only as a synergist (primary already removed).
  final Set<String> secondaryMuscles;

  static const double _primaryOpacity = 1.0;
  static const double _secondaryOpacity = 0.45;
  static const double _bodyMaxWidth = 132;

  /// Lit opacity for a muscle id (primary wins; null → not lit).
  double? _opacityFor(String muscleId) {
    if (primaryMuscles.contains(muscleId)) return _primaryOpacity;
    if (secondaryMuscles.contains(muscleId)) return _secondaryOpacity;
    return null;
  }

  Set<String> get _lit => {...primaryMuscles, ...secondaryMuscles};

  bool _sideHasTarget(Map<String, String> maskMuscle) =>
      maskMuscle.values.any(_lit.contains);

  /// Primary-muscle labels for the TARGETS line, in body order, deduped.
  String get _targetsLabel => [
    for (final m in bodyMuscles)
      if (primaryMuscles.contains(m.id)) m.label,
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final showFront = _sideHasTarget(frontMaskMuscle);
    final showBack = _sideHasTarget(backMaskMuscle);
    final anyLit = showFront || showBack;

    return Semantics(
      container: true,
      label: anyLit
          ? "Today's targets: $_targetsLabel"
          : 'No targets yet. Pick exercises to light your targets.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(kSpace3),
        decoration: BoxDecoration(
          color: kBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TODAY'S TARGETS",
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
            const SizedBox(height: kSpace2),
            if (!anyLit)
              const Center(child: _SideBody(side: BodySide.front, opacityFor: _none))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showFront)
                    Flexible(
                      child: _SideBody(
                        side: BodySide.front,
                        opacityFor: _opacityFor,
                      ),
                    ),
                  if (showFront && showBack) const SizedBox(width: kSpace3),
                  if (showBack)
                    Flexible(
                      child: _SideBody(
                        side: BodySide.back,
                        opacityFor: _opacityFor,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: kSpace2),
            Text(
              anyLit
                  ? 'TARGETS: $_targetsLabel'
                  : 'Pick exercises to light your targets.',
              style: AppFonts.shareTechMono(
                color: anyLit ? kNeon : kMutedText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The empty-state body lights nothing (a calm dimmed silhouette).
  static double? _none(String _) => null;
}

/// One side's pixel body: base + base-dim scrim + the lit muscle masks, tinted to
/// the one [kCoverageLit] via `srcIn` (alpha-only masks), at the per-muscle
/// opacity. Static and `RepaintBoundary`-isolated — it only repaints when the
/// selection changes, never per frame.
class _SideBody extends StatelessWidget {
  const _SideBody({required this.side, required this.opacityFor});

  final BodySide side;
  final double? Function(String muscleId) opacityFor;

  @override
  Widget build(BuildContext context) {
    final dir = side == BodySide.front ? 'front' : 'back';
    final maskMuscle = side == BodySide.front ? frontMaskMuscle : backMaskMuscle;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: TargetBodyPreview._bodyMaxWidth,
      ),
      child: AspectRatio(
        aspectRatio: 1024 / 1536,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kCardRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/body_diagram/render/base_$dir.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: kCoverageScrim.withValues(alpha: 0.50),
                  ),
                ),
                for (final entry in maskMuscle.entries)
                  if (opacityFor(entry.value) case final op?)
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          kCoverageLit,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/body_diagram/render/$dir/${entry.key}.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          opacity: AlwaysStoppedAnimation(op),
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
