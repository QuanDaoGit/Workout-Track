import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/character_class.dart';
import 'package:workout_track/services/guild_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('weekIso', () {
    test('formats ISO week and is stable across a Mon–Sun week', () {
      // 2026-05-25 is a Monday.
      final mon = DateTime(2026, 5, 25);
      final sun = DateTime(2026, 5, 31);
      expect(GuildService.weekIso(mon), GuildService.weekIso(sun));
      expect(GuildService.weekIso(mon), matches(RegExp(r'^\d{4}-W\d{2}$')));
      // Next Monday rolls the week.
      expect(
        GuildService.weekIso(DateTime(2026, 6, 1)),
        isNot(GuildService.weekIso(mon)),
      );
    });
  });

  group('ensureAssigned', () {
    test('creates a guild with player + seeded NPCs, idempotent', () async {
      final svc = GuildService();
      final g1 = await svc.ensureAssigned(classFocus: CharacterClass.bruiser);
      final g2 = await svc.ensureAssigned(classFocus: CharacterClass.tank);
      expect(g1.id, g2.id); // idempotent — same guild
      expect(g1.classFocus, CharacterClass.bruiser);

      final view = await svc.loadGuildView(
        classFocus: CharacterClass.bruiser,
        playerWeeklyVolumeKg: 0,
        playerWeeklySessions: 0,
      );
      expect(view.members.where((m) => m.isPlayer).length, 1);
      expect(view.members.length, greaterThan(1)); // NPCs present
      expect(view.members.length, lessThanOrEqualTo(GuildService.maxMembers));
    });
  });

  group('loadGuildView', () {
    test(
      'syncs player numbers and sorts members by weekly volume desc',
      () async {
        final svc = GuildService();
        final now = DateTime(2026, 5, 25, 9);
        final view = await svc.loadGuildView(
          classFocus: CharacterClass.assassin,
          playerWeeklyVolumeKg: 999999, // dominate the board
          playerWeeklySessions: 5,
          now: now,
        );
        expect(view.members.first.isPlayer, isTrue);
        // Sorted descending.
        for (var i = 1; i < view.members.length; i++) {
          expect(
            view.members[i - 1].weeklyVolumeKg >=
                view.members[i].weeklyVolumeKg,
            isTrue,
          );
        }
        // Guild total equals the sum of member volumes.
        final sum = view.members.fold<int>(0, (s, m) => s + m.weeklyVolumeKg);
        expect(view.guild.weeklyVolumeKg, sum);
      },
    );

    test(
      'NPC weekly volume is stable within a week, changes across weeks',
      () async {
        final svc = GuildService();
        final wk1 = DateTime(2026, 5, 25);
        final wk1b = DateTime(2026, 5, 27);
        final wk2 = DateTime(2026, 6, 1);

        Future<int> npcVol(DateTime now) async {
          final v = await svc.loadGuildView(
            classFocus: CharacterClass.tank,
            playerWeeklyVolumeKg: 0,
            playerWeeklySessions: 0,
            now: now,
          );
          return v.members.firstWhere((m) => !m.isPlayer).weeklyVolumeKg;
        }

        // Same NPC ordering isn't guaranteed; compare the guild's NPC-only total.
        Future<int> npcTotal(DateTime now) async {
          final v = await svc.loadGuildView(
            classFocus: CharacterClass.tank,
            playerWeeklyVolumeKg: 0,
            playerWeeklySessions: 0,
            now: now,
          );
          return v.members
              .where((m) => !m.isPlayer)
              .fold<int>(0, (s, m) => s + m.weeklyVolumeKg);
        }

        await npcVol(wk1);
        final a = await npcTotal(wk1);
        final b = await npcTotal(wk1b);
        final c = await npcTotal(wk2);
        expect(a, b); // stable within the week
        expect(a, isNot(c)); // changes next week
      },
    );
  });

  group('forge nod uniqueness', () {
    test('one nod per recipient per week, resets next week', () async {
      final svc = GuildService();
      await svc.ensureAssigned(classFocus: CharacterClass.bruiser);
      final now = DateTime(2026, 5, 25);

      expect(await svc.sendForgeNod('npc_0', now: now), isTrue);
      expect(await svc.sendForgeNod('npc_0', now: now), isFalse); // dup
      expect(await svc.hasNodded('npc_0', now: now), isTrue);
      // Different recipient same week is allowed.
      expect(await svc.sendForgeNod('npc_1', now: now), isTrue);
      // Next week the same recipient is allowed again.
      final nextWeek = DateTime(2026, 6, 1);
      expect(await svc.hasNodded('npc_0', now: nextWeek), isFalse);
      expect(await svc.sendForgeNod('npc_0', now: nextWeek), isTrue);
    });
  });

  group('recap', () {
    test('reports guild name, totals, and top three', () async {
      final svc = GuildService();
      final recap = await svc.recap(
        classFocus: CharacterClass.tank,
        playerWeeklyVolumeKg: 5000,
        playerWeeklySessions: 3,
        now: DateTime(2026, 5, 25),
      );
      expect(recap.guildName, isNotEmpty);
      expect(recap.playerVolumeKg, 5000);
      expect(recap.topThreeUserIds.length, 3);
      expect(recap.weeklyVolumeKg, greaterThanOrEqualTo(5000));
    });
  });
}
