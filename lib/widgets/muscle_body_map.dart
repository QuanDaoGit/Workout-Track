import 'package:flutter/material.dart';

import '../data/body_map_regions.dart';
import '../pages/exercise_history_page.dart';
import '../pages/strength_index_page.dart';
import '../services/muscle_coverage_service.dart';
import '../services/strength_trend_service.dart';
import '../theme/app_fonts.dart';
import '../theme/tokens.dart';
import 'arcade_chip.dart';
import 'arcade_route.dart';
import 'strength_momentum_row.dart';

String _fmtSets(double v) =>
    v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

const _zoneWord = {
  BodyZone.rest: 'RESTED',
  BodyZone.building: 'LIGHT',
  BodyZone.optimal: 'ON TRACK',
  BodyZone.high: 'PLENTY',
};

Color _zoneColor(BodyZone zone) => switch (zone) {
  BodyZone.rest => kMutedText,
  BodyZone.building => kZoneBuilding,
  BodyZone.optimal || BodyZone.high => kNeon,
};

/// Muscle-coverage body map — an anatomical pixel body whose muscles brighten by
/// how many weekly sets they got, over a read-only per-side meter. The body is
/// also the **strength browser** (Concept #1): tapping a muscle opens its
/// *strength dossier* — the lifts that train it + their estimated-max momentum
/// (with a this-week coverage verdict in the header) → each lift's history. A
/// quiet "ALL LIFTS" route covers the "show me everything" intent.
///
/// Plain-language read (zone word, not jargon); "alive" via a one-shot scan
/// reveal (muscle brightness — your data — is never pulsed); reduced motion →
/// instant full state.
class MuscleBodyMap extends StatefulWidget {
  const MuscleBodyMap({
    super.key,
    required this.contributors,
    this.strengthByMuscle = const {},
    this.window = CoverageWindow.week,
    this.effectiveWeeks = 1,
    this.onWindowChanged,
  });

  /// Per-detailed-muscle contributing exercises, **already normalized** to the
  /// selected [window] (`averagedContributors` output) — the meter total and the
  /// drill list both read these, so they can't diverge.
  final Map<String, List<MuscleContributor>> contributors;

  /// Per-body-muscle strength roster (`strengthByMuscle` output) — the lifts
  /// that train each muscle + their estimated-max momentum. Tapping a muscle
  /// opens this as the muscle's "strength dossier" (Concept #1, the body is the
  /// strength browser). Empty → the dossier shows a calm no-weighted-lifts state.
  final Map<String, List<StrengthTrend>> strengthByMuscle;

  /// The selected lookback. Drives only the unit label + copy — the *math* was
  /// done by the parent (this widget stays presentational, the single
  /// calculation boundary lives in `MuscleCoverageService`).
  final CoverageWindow window;

  /// Real span the average covered (≥1), for honest "last N wk" copy.
  final double effectiveWeeks;

  /// Tapping a range chip asks the parent to recompute + swap in new
  /// [contributors]. Null → the selector is hidden (a pure renderer for
  /// embeds/tests that don't wire a window).
  final ValueChanged<CoverageWindow>? onWindowChanged;

  @override
  State<MuscleBodyMap> createState() => _MuscleBodyMapState();
}

class _MuscleBodyMapState extends State<MuscleBodyMap>
    with SingleTickerProviderStateMixin {
  BodySide _side = BodySide.front;
  bool _reduce = false;
  bool _started = false;

  /// Group titles currently expanded. Empty by default → the page opens to the
  /// body + the group titles only; the detailed meter rows are revealed on tap
  /// (keyed by title, so a section's state carries across the FRONT/BACK toggle).
  final Set<String> _expandedGroups = {};

  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  static const _frontGroups = <(String, List<String>)>[
    ('SHOULDERS · ARMS', ['front_delt', 'biceps', 'forearms']),
    ('CHEST · CORE', ['chest', 'rectus', 'obliques']),
    ('LEGS', ['quads', 'adductors', 'calves']),
  ];
  static const _backGroups = <(String, List<String>)>[
    ('SHOULDERS · ARMS', ['rear_delt', 'triceps', 'forearms']),
    ('BACK', ['traps', 'lats', 'lower_back']),
    ('LEGS', ['glutes', 'hamstrings', 'calves']),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.maybeOf(context);
    _reduce =
        (mq?.disableAnimations ?? false) || (mq?.accessibleNavigation ?? false);
    if (_reduce) {
      _scan.value = 1;
    } else if (!_started) {
      _started = true;
      _scan.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(MuscleBodyMap old) {
    super.didUpdateWidget(old);
    // The parent swapped in a new window's contributors → re-sweep the reveal
    // (same one-shot, reduced-motion-safe gate as the side toggle).
    if (old.window != widget.window && !_reduce) _scan.forward(from: 0);
  }

  void _setSide(BodySide side) {
    if (_side == side) return;
    setState(() => _side = side);
    if (!_reduce) _scan.forward(from: 0);
  }

  /// What the per-muscle numbers mean for the selected window — stated once
  /// (the rows stay clean) and honestly (the *real* span, not the nominal one).
  String get _unitCaption {
    if (!widget.window.isAverage) return 'SETS · LAST 7 DAYS';
    final wk = widget.effectiveWeeks.round().clamp(1, 99);
    return 'AVG SETS/WK · LAST $wk WK';
  }

  /// Tap a muscle → its **strength dossier** (the lifts that train it + their
  /// momentum) → (F3) close the sheet, then push the picked lift's history from
  /// this page's context so back returns to the map.
  Future<void> _openDrill(
    BodyMuscle muscle,
    double coverageSets,
    List<StrengthTrend> roster,
  ) async {
    final picked = await showModalBottomSheet<StrengthTrend>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MuscleDossierSheet(
        muscle: muscle,
        coverageSets: coverageSets,
        roster: roster,
      ),
    );
    if (picked == null || !mounted) return;
    Navigator.of(context).push(
      arcadeRoute(
        (_) => ExerciseHistoryPage(
          exerciseId: picked.exerciseId,
          exerciseName: picked.exerciseName,
        ),
      ),
    );
  }

  void _openAllLifts() {
    Navigator.of(context).push(
      arcadeRoute((_) => const StrengthIndexPage()),
    );
  }

  /// A group's detailed meter rows when expanded; a zero-height filler when
  /// collapsed (so the default page is body + titles only).
  Widget _groupBody(
    String title,
    List<String> ids,
    Map<String, MuscleBreakdown> breakdown,
  ) {
    if (!_expandedGroups.contains(title)) {
      return const SizedBox(width: double.infinity);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: kSpace3),
        for (final id in ids)
          _MeterRow(
            muscle: muscleById(id),
            sets: breakdown[id]?.total ?? 0,
            isAverage: widget.window.isAverage,
            onTap: () => _openDrill(
              muscleById(id),
              breakdown[id]?.total ?? 0,
              widget.strengthByMuscle[id] ?? const [],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = muscleBreakdown(widget.contributors);
    final values = {for (final e in breakdown.entries) e.key: e.value.total};
    final groups = _side == BodySide.front ? _frontGroups : _backGroups;
    final anyTrained = values.values.any((v) => v > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'VIEW',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
            ),
            const SizedBox(width: kSpace2),
            ArcadeChip(
              label: 'FRONT',
              selected: _side == BodySide.front,
              onTap: () => _setSide(BodySide.front),
            ),
            const SizedBox(width: kSpace1),
            ArcadeChip(
              label: 'BACK',
              selected: _side == BodySide.back,
              onTap: () => _setSide(BodySide.back),
            ),
          ],
        ),
        if (widget.onWindowChanged != null) ...[
          const SizedBox(height: kSpace2),
          _RangeSelector(
            window: widget.window,
            onChanged: widget.onWindowChanged!,
          ),
          const SizedBox(height: kSpace1),
          Text(
            _unitCaption,
            style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
          ),
        ],
        const SizedBox(height: kSpace3),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _BodyFrame(side: _side, values: values, scan: _scan),
          ),
        ),
        if (!anyTrained) ...[
          const SizedBox(height: kSpace2),
          Center(
            child: Text(
              'Save a workout to light up your map.',
              style: AppFonts.shareTechMono(color: kMutedText, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: kSpace4),
        for (final (title, ids) in groups) ...[
          _GroupHeader(
            title: title,
            expanded: _expandedGroups.contains(title),
            onTap: () => setState(() {
              if (!_expandedGroups.remove(title)) _expandedGroups.add(title);
            }),
          ),
          // Reduced motion renders the section instantly — `AnimatedSize` with a
          // zero duration re-dirties itself during layout (Flutter assertion).
          if (_reduce)
            _groupBody(title, ids, breakdown)
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _groupBody(title, ids, breakdown),
            ),
          const SizedBox(height: kSpace4),
        ],
        if (widget.strengthByMuscle.isNotEmpty)
          _AllLiftsButton(onTap: _openAllLifts),
      ],
    );
  }
}

/// Section anchor — bright label + neon tick + hairline rule + an
/// expand/collapse chevron. Collapsed by default (the page opens to titles
/// only); tapping toggles its detailed meter rows. The chevron is a static
/// icon swap (reduced-motion-safe by construction).
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, ${expanded ? 'expanded, tap to collapse' : 'collapsed, tap to expand'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpace1),
          child: Row(
            children: [
              Container(width: 3, height: 13, color: kNeon),
              const SizedBox(width: kSpace2),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: kText,
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(child: Container(height: 1, color: kBorder)),
              const SizedBox(width: kSpace2),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_sharp
                    : Icons.keyboard_arrow_down_sharp,
                size: 18,
                color: kMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The averaging-window selector — a `RANGE` label + three chips. A [Wrap] so a
/// narrow phone flows the longer labels to a second line instead of overflowing.
/// Each chip carries its `selected` state into Semantics (the chip primitive
/// only paints it).
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.window, required this.onChanged});

  final CoverageWindow window;
  final ValueChanged<CoverageWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'RANGE',
          style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
        ),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Wrap(
            spacing: kSpace1,
            runSpacing: kSpace1,
            children: [
              for (final w in CoverageWindow.values)
                Semantics(
                  selected: w == window,
                  child: ArcadeChip(
                    label: w.chipLabel,
                    selected: w == window,
                    onTap: () => onChanged(w),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyFrame extends StatelessWidget {
  const _BodyFrame({
    required this.side,
    required this.values,
    required this.scan,
  });

  final BodySide side;
  final Map<String, double> values;
  final Animation<double> scan;

  String get _dir => side == BodySide.front ? 'front' : 'back';
  Map<String, String> get _maskMuscle =>
      side == BodySide.front ? frontMaskMuscle : backMaskMuscle;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1024 / 1536,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kBg,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kCardRadius),
            child: AnimatedBuilder(
              animation: scan,
              builder: (context, _) {
                final reveal = Curves.easeOut.transform(scan.value);
                final sweeping = scan.value > 0 && scan.value < 1;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/body_diagram/render/base_$_dir.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    Positioned.fill(
                      child: ColoredBox(
                        color: kCoverageScrim.withValues(alpha: 0.50),
                      ),
                    ),
                    for (final entry in _maskMuscle.entries)
                      _maskLayer(entry.key, entry.value, reveal),
                    if (sweeping)
                      Align(
                        alignment: Alignment(0, scan.value * 2 - 1),
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: kNeon.withValues(alpha: 0.55),
                            boxShadow: [
                              BoxShadow(
                                color: kNeon.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ..._corners(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _maskLayer(String maskStem, String muscleId, double reveal) {
    final m = muscleById(muscleId);
    final target = maskOpacityFor(values[muscleId] ?? 0, m.mev, m.mav);
    final op = target * reveal;
    if (op <= 0) return const SizedBox.shrink();
    // `srcIn` repaints the region with `kCoverageLit` using the PNG's alpha as the
    // mask — the baked per-muscle hue is discarded, so every region reads one
    // uniform color. The tint and the layer opacity compose: final α = op × alpha.
    return Positioned.fill(
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(kCoverageLit, BlendMode.srcIn),
        child: Image.asset(
          'assets/body_diagram/render/$_dir/$maskStem.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          opacity: AlwaysStoppedAnimation(op),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const len = 14.0;
    Widget bracket({bool left = false, bool top = false}) => SizedBox(
      width: len,
      height: len,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: left ? const BorderSide(color: kNeon, width: 2) : BorderSide.none,
            right: !left ? const BorderSide(color: kNeon, width: 2) : BorderSide.none,
            top: top ? const BorderSide(color: kNeon, width: 2) : BorderSide.none,
            bottom: !top ? const BorderSide(color: kNeon, width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
    return [
      Positioned(top: 6, left: 6, child: Opacity(opacity: 0.6, child: bracket(left: true, top: true))),
      Positioned(top: 6, right: 6, child: Opacity(opacity: 0.6, child: bracket(top: true))),
      Positioned(bottom: 6, left: 6, child: Opacity(opacity: 0.6, child: bracket(left: true))),
      Positioned(bottom: 6, right: 6, child: Opacity(opacity: 0.6, child: bracket())),
    ];
  }
}

/// A read-only row — the plain verdict; tap opens the drill sheet.
class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.muscle,
    required this.sets,
    required this.isAverage,
    required this.onTap,
  });

  final BodyMuscle muscle;
  final double sets;
  final bool isAverage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zone = zoneFor(sets, muscle.mev, muscle.mav);
    final unit = isAverage ? 'average weekly sets' : 'weekly sets';
    final fill = switch (zone) {
      BodyZone.rest => Colors.transparent,
      BodyZone.building => kZoneBuildingFill,
      BodyZone.optimal || BodyZone.high => kNeon,
    };
    final word = _zoneWord[zone]!;
    final pct = (sets.clamp(0, muscle.mav) / muscle.mav).clamp(0.0, 1.0);
    final mevPct = (muscle.mev / muscle.mav).clamp(0.0, 1.0);

    return Semantics(
      label: '${muscle.label}, ${_fmtSets(sets)} $unit, $word',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: kSpace3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    muscle.label,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: kText,
                    ),
                  ),
                  Text(
                    _fmtSets(sets),
                    style: AppFonts.shareTechMono(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 9,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: kMeterTrack,
                          border: Border.all(color: kBorder),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Positioned(
                            left: c.maxWidth * mevPct,
                            top: 0,
                            bottom: 0,
                            right: 0,
                            child: ColoredBox(
                              color: kNeon.withValues(alpha: 0.12),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: c.maxWidth * pct,
                            child: ColoredBox(color: fill),
                          ),
                          Positioned(
                            left: c.maxWidth * mevPct,
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: ColoredBox(
                              color: kText.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        word,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                          letterSpacing: 1,
                          color: _zoneColor(zone),
                        ),
                      ),
                      if (zone == BodyZone.high) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_up_sharp,
                          size: 14,
                          color: kMutedText,
                        ),
                      ],
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right_sharp,
                    size: 16,
                    color: kMutedText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The muscle's **strength dossier** — a one-line coverage verdict for *this
/// week* (header, so the coverage glance isn't lost) plus the lifts that train
/// the muscle and their estimated-max **momentum** (all-time): the body is the
/// strength browser (Concept #1). Two clearly-scoped reads, not a muddle (Codex
/// F2). Returns the picked lift's trend to the caller, which pushes its history.
class _MuscleDossierSheet extends StatelessWidget {
  const _MuscleDossierSheet({
    required this.muscle,
    required this.coverageSets,
    required this.roster,
  });

  final BodyMuscle muscle;

  /// This-window working sets for the muscle — drives the header coverage zone.
  final double coverageSets;

  /// The muscle's strength roster (its primary lifts + momentum), recency-sorted.
  final List<StrengthTrend> roster;

  @override
  Widget build(BuildContext context) {
    final zone = zoneFor(coverageSets, muscle.mev, muscle.mav);

    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder), left: BorderSide(color: kBorder), right: BorderSide(color: kBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: kSpace3),
                  color: kBorder,
                ),
              ),
              // Header: the muscle + its coverage verdict THIS WEEK (a labelled
              // glance — coverage isn't lost when the body becomes the browser).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    muscle.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${_zoneWord[zone]!} · THIS WEEK',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      letterSpacing: 1,
                      color: _zoneColor(zone),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpace3),
              Text(
                'STRENGTH',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 11),
              ),
              const SizedBox(height: kSpace2),
              const Divider(color: kBorder, height: 1),
              const SizedBox(height: kSpace2),
              if (roster.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: kSpace3),
                  child: Text(
                    'No weighted lifts here yet.\n'
                    'Train ${muscle.label.toLowerCase()} with weights to track strength.',
                    style: AppFonts.shareTechMono(
                      color: kMutedText,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                for (final trend in roster)
                  Padding(
                    padding: const EdgeInsets.only(bottom: kSpace2),
                    child: StrengthMomentumRow(
                      trend: trend,
                      onTap: () => Navigator.of(context).pop(trend),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The secondary completeness net (Codex F1): a quiet route from the body to a
/// roster of *every* tracked lift's strength, for the "show me all my lifts"
/// intent the body-grouped view alone can't serve. Not the hero — the body is.
class _AllLiftsButton extends StatelessWidget {
  const _AllLiftsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'All lifts — strength progress',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpace2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALL LIFTS — STRENGTH',
                style: AppFonts.shareTechMono(color: kNeon, fontSize: 13),
              ),
              const Icon(Icons.chevron_right_sharp, color: kNeon),
            ],
          ),
        ),
      ),
    );
  }
}
