import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/guild_models.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/gem_service.dart';
import 'package:workout_track/services/guild_service.dart';

WorkoutSession _session({bool partial = false, bool abandoned = false}) =>
    WorkoutSession(
      id: 's',
      date: DateTime(2026, 6, 29),
      muscleGroup: 'Chest',
      targetMuscleGroups: const ['Chest'],
      targetDurationMinutes: 30,
      actualDurationSeconds: 1800,
      estimatedCalories: 0,
      exercises: const [],
      isPartial: partial,
      isAbandoned: abandoned,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('guild entity', () {
    test('ensureGuild creates a "BIT" guild stamped at founding time', () async {
      final svc = GuildService(nowProvider: () => DateTime(2026, 6, 29, 10));
      final g = await svc.ensureGuild();
      expect(g.name, 'BIT');
      expect(g.createdAt, DateTime(2026, 6, 29, 10));
      expect(g.id, isNotEmpty);
      expect(g.crest, isA<GuildCrest>()); // default crest present
    });

    test('ensureGuild is idempotent — same id, never re-stamped', () async {
      final first = await GuildService(
        nowProvider: () => DateTime(2026, 6, 29, 10),
      ).ensureGuild();
      final second = await GuildService(
        nowProvider: () => DateTime(2026, 7, 15, 8),
      ).ensureGuild();
      expect(second.id, first.id);
      expect(second.createdAt, first.createdAt);
    });

    test('getGuild is null before creation, the guild after', () async {
      final svc = GuildService(nowProvider: () => DateTime(2026, 6, 29));
      expect(await svc.getGuild(), isNull);
      await svc.ensureGuild();
      expect((await svc.getGuild())!.name, 'BIT');
    });

    test('roster is the player + 5 OPEN slots', () {
      expect(GuildService.rosterSize, 6);
    });
  });

  group('crest persistence', () {
    test('updateCrest persists and round-trips', () async {
      final svc = GuildService(nowProvider: () => DateTime(2026, 6, 29));
      await svc.updateCrest(
        const GuildCrest(
          shape: 1,
          emblem: 2,
          bannerColor: 0xFF00FF9C,
          emblemColor: 0xFFFF2D55,
        ),
      );
      final reloaded = (await svc.getGuild())!.crest;
      expect(reloaded.shape, 1);
      expect(reloaded.emblem, 2);
      expect(reloaded.bannerColor, 0xFF00FF9C);
      expect(reloaded.emblemColor, 0xFFFF2D55);
    });

    test('a guild blob without a crest decodes to the default crest', () {
      final g = Guild.fromJson({
        'id': '1',
        'name': 'BIT',
        'createdAt': DateTime(2026, 6, 29).toIso8601String(),
      });
      expect(g.crest.shape, 0);
      expect(g.crest.emblem, 0); // default sword
      expect(g.crest.bannerColor, 0); // 0 = auto/class
      expect(g.crest.emblemColor, 0);
    });

    test('a legacy {shape, charge, color} crest blob decodes gracefully', () {
      // The old code-drawn placeholder stored a charge glyph + one colour.
      final crest = GuildCrest.fromJson({
        'shape': 2,
        'charge': 4, // dropped — no longer an emblem concept
        'color': 0xFFB14DFF,
      });
      expect(crest.shape, 2); // carries over (clamped to the 4 banners)
      expect(crest.emblem, 0); // defaults to sword
      expect(crest.bannerColor, 0xFFB14DFF); // legacy colour seeds both layers
      expect(crest.emblemColor, 0xFFB14DFF);
    });
  });

  group('guild level (body-neutral: sessions, not volume)', () {
    test('completedSessions excludes partial + abandoned', () {
      final sessions = [
        _session(),
        _session(partial: true),
        _session(abandoned: true),
        _session(),
      ];
      expect(GuildService.completedSessions(sessions), 2);
    });

    test('level climbs across the session thresholds', () {
      expect(GuildService.guildLevel(0), 1);
      expect(GuildService.guildLevel(4), 1);
      expect(GuildService.guildLevel(5), 2);
      expect(GuildService.guildLevel(14), 2);
      expect(GuildService.guildLevel(15), 3);
      expect(GuildService.guildLevel(29), 3);
      expect(GuildService.guildLevel(30), 4);
      expect(GuildService.guildLevel(51), 4);
      expect(GuildService.guildLevel(52), 5);
      expect(GuildService.guildLevel(500), 5);
    });

    test('progress is within the current level span; null at max', () {
      expect(GuildService.guildLevelProgress(0), (0, 5));
      expect(GuildService.guildLevelProgress(7), (2, 10));
      expect(GuildService.guildLevelProgress(20), (5, 15));
      expect(GuildService.guildLevelProgress(52), isNull);
    });

    test('rank ladder maps to the guild level (clamped)', () {
      expect(GuildService.guildRank(1), 'RECRUIT');
      expect(GuildService.guildRank(2), 'MEMBER');
      expect(GuildService.guildRank(3), 'VETERAN');
      expect(GuildService.guildRank(4), 'OFFICER');
      expect(GuildService.guildRank(5), 'LEADER');
      expect(GuildService.guildRank(99), 'LEADER');
    });
  });

  group('weekly cache', () {
    test('target is 3 solo, scales with members', () {
      expect(GuildService.cacheTarget(0), 3);
      expect(GuildService.cacheTarget(1), 3);
      expect(GuildService.cacheTarget(2), 6);
    });

    test('week key is the Monday-of-week date, stable within the week', () {
      // 2026-05-25 is a Monday.
      expect(GuildService.cacheWeekKey(DateTime(2026, 5, 25)), '2026-05-25');
      expect(GuildService.cacheWeekKey(DateTime(2026, 5, 31, 23)), '2026-05-25');
      expect(GuildService.cacheWeekKey(DateTime(2026, 6, 1)), '2026-06-01');
    });

    test('reward auto-banks once per week, re-arms next week', () async {
      final gem = GemService();
      final wk = GuildService.cacheWeekKey(DateTime(2026, 5, 25));
      expect(await gem.isGuildCacheBanked(wk), isFalse);
      final first = await gem.awardGuildCacheGems(
        weekKey: wk,
        amount: GuildService.cacheRewardGems,
        label: 'Weekly Cache',
      );
      expect(first, GuildService.cacheRewardGems);
      expect(await gem.isGuildCacheBanked(wk), isTrue);
      // replay is a no-op (idempotent one-shot)
      expect(
        await gem.awardGuildCacheGems(
          weekKey: wk,
          amount: GuildService.cacheRewardGems,
          label: 'Weekly Cache',
        ),
        0,
      );
      // next week is a fresh cache
      final wk2 = GuildService.cacheWeekKey(DateTime(2026, 6, 1));
      expect(await gem.isGuildCacheBanked(wk2), isFalse);
    });
  });
}
