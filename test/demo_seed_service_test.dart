import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/workout_models.dart';
import 'package:workout_track/services/character_service.dart';
import 'package:workout_track/services/demo_seed_service.dart';
import 'package:workout_track/services/profile_service.dart';
import 'package:workout_track/services/program_service.dart';
import 'package:workout_track/services/stat_engine.dart';
import 'package:workout_track/services/xp_service.dart';

/// Guards the marketing seeder: the derived state must read "solid
/// intermediate" (Knight rank, a streak buff, B/A-band capability stats) so a
/// shoot isn't wasted on numbers that came out wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 6, 10, 9);

  Future<List<WorkoutSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonDecode(prefs.getString('workout_sessions')!) as List;
    return [
      for (final s in raw) WorkoutSession.fromJson(s as Map<String, dynamic>),
    ];
  }

  test('persona, profile face, and active program are seeded', () async {
    await DemoSeedService.seedIntermediate(now: now);

    final character = await CharacterService().loadActiveCharacter();
    expect(character?.name, 'VANTA');

    final profile = await ProfileService().loadProfile();
    expect(profile.displayName, 'VANTA');
    expect(profile.avatarSpec, isNot(AvatarSpec.fallback));

    final progress = await ProgramService().getActiveProgress(now: now);
    expect(progress?.programId, 'full_body_3x');
    expect(progress?.arcSessions, greaterThan(0));
  });

  test('history reads as a committed-but-intermediate Knight', () async {
    await DemoSeedService.seedIntermediate(now: now);
    final sessions = await loadSessions();

    // A populated calendar, all real completed sessions.
    expect(sessions.length, greaterThanOrEqualTo(28));
    expect(sessions.every((s) => !s.isPartial && !s.isAbandoned), isTrue);

    final totalXp = XpService.calculateTotalXP(sessions);
    final level = XpService.getLevel(totalXp);
    // Knight band is level 10–19; not yet Champion (20).
    expect(level, inInclusiveRange(10, 19));
    expect(XpService.getRank(level), 'Knight');
  });

  test('streak earns at least one LCK diamond', () async {
    await DemoSeedService.seedIntermediate(now: now);

    // LCK is the weekly consistency streak; the dense Mon–Fri seed history
    // yields several clean weeks → at least one diamond.
    final lck = await StatEngine(nowProvider: () => now).calculateLuck();
    expect(lck, greaterThanOrEqualTo(1));
    expect(XpService.lckDiamondCount(lck), greaterThanOrEqualTo(1));
    expect(XpService.lckXpMultiplier(lck), greaterThanOrEqualTo(1.5));
  });

  test('capability stats land in the B/A band', () async {
    await DemoSeedService.seedIntermediate(now: now);

    final stats = await StatEngine().getStoredStats();
    // B starts at 300; intermediate should clear it on the trained lifts.
    expect(stats['STR'], greaterThanOrEqualTo(300));
    expect(stats['AGI'], greaterThanOrEqualTo(200));
    // Still believable, not maxed.
    expect(stats['STR'], lessThan(900));
  });
}
