import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../models/body_metrics_models.dart';
import '../services/body_metrics_service.dart';
import '../theme/tokens.dart';
import '../widgets/motion/hold_depress.dart';
import '../widgets/pixel_loader.dart';

class BodyMetricsHistoryPage extends StatefulWidget {
  const BodyMetricsHistoryPage({super.key});

  @override
  State<BodyMetricsHistoryPage> createState() => _BodyMetricsHistoryPageState();
}

class _BodyMetricsHistoryPageState extends State<BodyMetricsHistoryPage> {
  List<WeightEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await BodyMetricsService().getEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries.reversed.toList(); // newest first
      _loading = false;
    });
  }

  Future<void> _confirmDelete(WeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'DELETE ENTRY?',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: kDanger,
          ),
        ),
        content: Text(
          '${_formatDate(entry.loggedAt)} \u00B7 ${entry.weightKg.toStringAsFixed(1)} kg',
          style: AppFonts.shareTechMono(color: kText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.shareTechMono(color: kMutedText),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: kDanger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: kBg,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await BodyMetricsService().deleteEntry(entry.loggedAt);
    _load();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Returns a neutral arrow character for direction from previous entry.
  /// Never red/green colored — always muted.
  String _directionArrow(int index) {
    // _entries is newest-first, so index+1 is the older entry
    if (index >= _entries.length - 1) return '';
    final current = _entries[index].weightKg;
    final previous = _entries[index + 1].weightKg;
    if (current > previous) return '\u25B2'; // ▲ up
    if (current < previous) return '\u25BC'; // ▼ down
    return '\u2500'; // ─ same
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WEIGHT LOG')),
      body: _loading
          ? const Center(child: PixelLoader())
          : _entries.isEmpty
          ? Center(
              child: Text(
                'NO ENTRIES',
                style: AppFonts.shareTechMono(color: kMutedText, fontSize: 13),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final entry = _entries[i];
                final arrow = _directionArrow(i);
                return HoldDepress(
                  onLongPress: () => _confirmDelete(entry),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDate(entry.loggedAt),
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.weightKg.toStringAsFixed(1)} kg',
                          style: AppFonts.shareTechMono(
                            color: kText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (arrow.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            arrow,
                            style: AppFonts.shareTechMono(
                              color: kMutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
