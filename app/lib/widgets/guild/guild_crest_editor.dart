import 'package:flutter/material.dart';

import '../../models/guild_models.dart';
import '../../services/guild_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../motion/hold_depress.dart';
import '../pixel_button.dart';
import 'guild_color_picker.dart';
import 'guild_crest.dart';

/// Bottom-sheet **Crest Forge** (ported) — pick the banner shape, stamp an emblem
/// (or none), and set the banner + emblem colours **independently** (an AUTO =
/// class-colour option, the 6 curated Ironbit swatches, or a free custom picker),
/// over a live **swaying** preview. Pops the chosen [GuildCrest] on SAVE.
class GuildCrestEditorSheet extends StatefulWidget {
  const GuildCrestEditorSheet({
    super.key,
    required this.initial,
    required this.classColor,
  });

  final GuildCrest initial;

  /// Resolves the "auto" (0) tint and is the AUTO swatch's colour.
  final Color classColor;

  @override
  State<GuildCrestEditorSheet> createState() => _GuildCrestEditorSheetState();
}

/// The handoff's 6 curated Ironbit swatches (`COLORS`), as ARGB ints — crest tint
/// data (the palette, like the old placeholder's `_colorOptions`).
const List<int> _curated = [
  0xFF37D2CF, // teal (the art's authored hue)
  0xFF00FF9C, // neon green
  0xFFFFD700, // amber
  0xFF00BFFF, // cyan
  0xFFFF4DCD, // magenta
  0xFFFF2D55, // red
];

class _GuildCrestEditorSheetState extends State<GuildCrestEditorSheet> {
  late GuildCrest _crest = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GuildCrestBadge(
                crest: _crest,
                fallbackColor: widget.classColor,
                size: 116,
              ),
            ),
            const SizedBox(height: 16),
            _label('BANNER SHAPE'),
            _thumbRow(
              count: GuildService.crestShapeCount,
              isSelected: (i) => _crest.shape == i,
              crestFor: (i) => _crest.copyWith(shape: i),
              onTap: (i) => setState(() => _crest = _crest.copyWith(shape: i)),
            ),
            const SizedBox(height: 14),
            _label('EMBLEM'),
            _thumbRow(
              count: GuildService.crestEmblemCount + 1, // + NONE
              isSelected: (i) => _emblemAt(i) == _crest.emblem,
              crestFor: (i) => _crest.copyWith(emblem: _emblemAt(i)),
              onTap: (i) =>
                  setState(() => _crest = _crest.copyWith(emblem: _emblemAt(i))),
            ),
            const SizedBox(height: 18),
            _label('BANNER COLOR'),
            _colorRow(
              current: _crest.bannerColor,
              title: 'BANNER COLOR',
              onPick: (v) =>
                  setState(() => _crest = _crest.copyWith(bannerColor: v)),
            ),
            const SizedBox(height: 16),
            _label('EMBLEM COLOR'),
            _colorRow(
              current: _crest.emblemColor,
              title: 'EMBLEM COLOR',
              onPick: (v) =>
                  setState(() => _crest = _crest.copyWith(emblemColor: v)),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'CANCEL',
                    secondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PixelButton(
                    label: 'SAVE',
                    onPressed: () => Navigator.of(context).pop(_crest),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Picker index → emblem value (the trailing index is NONE).
  int _emblemAt(int i) =>
      i >= GuildService.crestEmblemCount ? GuildCrest.noEmblem : i;

  Widget _label(String text) => Text(
    text,
    style: AppFonts.shareTechMono(
      color: kMutedText,
      fontSize: 11,
    ).copyWith(letterSpacing: 1),
  );

  Widget _thumbRow({
    required int count,
    required bool Function(int) isSelected,
    required GuildCrest Function(int) crestFor,
    required void Function(int) onTap,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: HoldDepress(
                onTap: () => onTap(i),
                haptic: HapticIntent.selection,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kCard,
                    border: Border.all(
                      color: isSelected(i) ? kNeon : kBorder,
                      width: isSelected(i) ? 1.4 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  // Thumbnails render at the art's native teal (explicit → no
                  // recolour pass) — the chooser is about shape/emblem, not hue.
                  child: GuildCrestBadge(
                    crest: crestFor(i).copyWith(
                      bannerColor: 0xFF37D2CF,
                      emblemColor: 0xFF37D2CF,
                    ),
                    fallbackColor: kCyan,
                    size: 40,
                    animate: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _colorRow({
    required int current,
    required String title,
    required void Function(int) onPick,
  }) {
    final isCustom = current != 0 && !_curated.contains(current);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _swatch(
            color: widget.classColor,
            selected: current == 0,
            label: 'A',
            onTap: () => onPick(0),
          ),
          for (final hex in _curated)
            _swatch(
              color: Color(hex),
              selected: current == hex,
              onTap: () => onPick(hex),
            ),
          _swatch(
            color: isCustom ? Color(current) : kCard,
            selected: isCustom,
            label: isCustom ? null : '+',
            labelColor: kMutedText,
            onTap: () async {
              final picked = await showModalBottomSheet<Color>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => CrestColorPickerSheet(
                  initial: isCustom ? Color(current) : widget.classColor,
                  title: title,
                ),
              );
              if (picked != null) onPick(picked.toARGB32());
            },
          ),
        ],
      ),
    );
  }

  Widget _swatch({
    required Color color,
    required bool selected,
    String? label,
    Color labelColor = kBg,
    required VoidCallback onTap,
  }) {
    return HoldDepress(
      onTap: onTap,
      haptic: HapticIntent.selection,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: selected ? kText : kBorder,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: label == null
            ? null
            : Text(
                label,
                style: AppFonts.shareTechMono(color: labelColor, fontSize: 12),
              ),
      ),
    );
  }
}
