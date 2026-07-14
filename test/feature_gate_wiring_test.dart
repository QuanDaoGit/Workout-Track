import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/room/quest_board.dart';

/// Codex P3/P5: every route into a gated surface must pass through a guarded
/// entry. This scan enforces it structurally — constructing a gated page in a
/// NEW file fails here, forcing the new call site through a
/// `FeatureGateService.isUnlockedSync` guard (then add it to the allowlist).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gated-page constructor allowlist', () {
    // Gated page constructor → the files allowed to instantiate it. Each entry
    // is either the page's own file or a call site that guards the push.
    const allowed = <String, Set<String>>{
      'ShopPage(': {
        'lib/pages/shop_page.dart',
        'lib/pages/root_page.dart', // _openShop guards
        'lib/pages/profile_page.dart', // _openShop guards
      },
      'QuestsPage(': {
        'lib/pages/quests_page.dart',
        'lib/pages/root_page.dart', // _pushQuests guards
      },
      'GuildPage(': {
        'lib/pages/guild_page.dart',
        'lib/pages/root_page.dart', // goTo guards the destination
      },
      'InventoryPage(': {
        'lib/pages/inventory_page.dart',
        'lib/pages/root_page.dart', // goTo guards the destination
        'lib/pages/profile_page.dart', // _openInventory guards
      },
      'AdventurePage(': {
        'lib/pages/adventure_page.dart',
        'lib/pages/root_page.dart', // _pushAdventure guards
        'lib/pages/home.dart', // _openAdventure guards
        // Reachable only from an expedition report, which requires a dispatch
        // — impossible while the adventure gate is locked.
        'lib/pages/expedition_report_page.dart',
      },
    };

    test('no unguarded construction of a gated page', () {
      final libDir = Directory('lib');
      final violations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        final source = entity.readAsStringSync();
        for (final entry in allowed.entries) {
          if (!source.contains(entry.key)) continue;
          if (!entry.value.contains(path)) {
            violations.add('$path constructs ${entry.key}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'A gated page is constructed outside the guarded allowlist. '
            'Route the new call site through a FeatureGateService guard '
            '(show the locked notice when locked), then allowlist it here.',
      );
    });
  });

  group('unpowered quest board (quests gate locked)', () {
    testWidgets('offline label + golden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: QuestBoard(
                  width: 130,
                  height: 144,
                  total: 5,
                  filled: 3, // stale data must not leak through a dark screen
                  ready: 2,
                  powered: false,
                  onTap: () {},
                  semanticsLabel:
                      'Quest board, offline. '
                      'Complete your first workout to power the quest board.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Quest board, offline')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(QuestBoard),
        matchesGoldenFile('goldens/quest_board_unpowered.png'),
      );
    });
  });
}
