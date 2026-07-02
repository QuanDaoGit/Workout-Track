import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/data/bit_room_copy.dart';
import 'package:workout_track/models/adventure_models.dart';
import 'package:workout_track/theme/tokens.dart';
import 'package:workout_track/widgets/companion/bit_companion.dart';
import 'package:workout_track/widgets/room/room_scene.dart';
import 'package:workout_track/widgets/room/world_window.dart';

/// Rendered proof for BIT's home-room voice bubble across its states — advice
/// (home), "I'm back" (away first), scouting status (away later), the haul
/// prompt — plus a tight viewport + large text to confirm the bubble doesn't
/// crowd the hologram (Codex #3). Reduced motion (deterministic).
/// Regenerate with `flutter test --update-goldens`.
void main() {
  RoomAdventureView view({
    required AdventurePhase phase,
    bool haulReady = false,
    bool greeted = false,
    int charges = 0,
    bool canDispatch = false,
    String? adviceLine,
    String? routeName,
    Color? routeAccent,
    int? backInHours,
  }) {
    final voice = BitRoomVoice.select(
      phase: phase,
      haulReady: haulReady,
      greeted: greeted,
      adviceLine: adviceLine ?? bitRoomRegularAdvice.first,
      routeName: routeName,
      backInHours: backInHours,
    );
    return RoomAdventureView(
      phase: phase,
      charges: charges,
      canDispatch: canDispatch,
      haulReady: haulReady,
      routeName: routeName,
      routeAccent: routeAccent,
      backInHours: backInHours,
      voice: voice,
    );
  }

  Future<void> pumpScene(
    WidgetTester t,
    RoomAdventureView adv, {
    double w = 390,
    double h = 700,
    double textScale = 1.0,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: SizedBox(
                width: w,
                child: HomeRoomScene(
                  height: h,
                  name: 'VALEN',
                  level: 7,
                  title: 'KNIGHT',
                  timeOfDay: RoomTimeOfDay.evening,
                  adventure: adv,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  Future<void> shot(
    WidgetTester t,
    RoomAdventureView adv,
    String file, {
    double w = 390,
    double h = 700,
    double textScale = 1.0,
  }) async {
    await pumpScene(t, adv, w: w, h: h, textScale: textScale);
    await expectLater(
      find.byType(HomeRoomScene),
      matchesGoldenFile('goldens/$file'),
    );
  }

  // No charge here: a ready charge now shows the dispatch hint (which suppresses
  // the advice bubble), so the advice state is "home, no charge ready".
  testWidgets('advice (home)', (t) => shot(t,
      view(phase: AdventurePhase.idle, charges: 0),
      'room_voice_advice.png'));
  testWidgets('advice short ("67")', (t) => shot(t,
      view(phase: AdventurePhase.idle, adviceLine: '67'),
      'room_voice_advice_short.png'));
  testWidgets('advice longest line', (t) => shot(t,
      view(phase: AdventurePhase.idle,
          adviceLine: 'Sleeping is the cheat code to muscle growth'),
      'room_voice_advice_long.png'));
  testWidgets('greeting (away first)', (t) => shot(t,
      view(phase: AdventurePhase.out, routeName: 'IRON VAULT',
          routeAccent: const Color(0xFFFF6A3D), backInHours: 2),
      'room_voice_greeting.png'));
  testWidgets('scouting (away later)', (t) => shot(t,
      view(phase: AdventurePhase.out, greeted: true, routeName: 'IRON VAULT',
          routeAccent: const Color(0xFFFF6A3D), backInHours: 2),
      'room_voice_scouting.png'));
  testWidgets('haul prompt', (t) => shot(t,
      view(phase: AdventurePhase.returned, haulReady: true),
      'room_voice_haul.png'));
  testWidgets('scouting tight + large text', (t) => shot(t,
      view(phase: AdventurePhase.out, greeted: true, routeName: 'INFINI MAZE',
          routeAccent: kCyan, backInHours: 7),
      'room_voice_scouting_tight.png', w: 360, h: 420, textScale: 1.3));

  // Spam-tap easter egg: poke BIT five times fast at home → he slumps to REST
  // and sighs "I guess bro...". Reduced motion makes the slump instant + the
  // bubble swap deterministic for the golden.
  testWidgets('spam-tap rest sigh (idle home)', (t) async {
    await pumpScene(
      t,
      view(phase: AdventurePhase.idle, charges: 0),
    );
    for (var i = 0; i < 5; i++) {
      await t.tap(find.byType(BitCompanion));
      await t.pump();
    }
    // Flush the reduced-motion cheer-flash timers from taps 1–4; BIT is now in
    // the (instant, under reduced motion) rest slump.
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(bitRoomRestQuip), findsOneWidget);
    await expectLater(
      find.byType(HomeRoomScene),
      matchesGoldenFile('goldens/room_voice_rest.png'),
    );
    // Let the 3s recovery fire so no timer is left pending at teardown.
    await t.pump(const Duration(seconds: 3));
    expect(find.text(bitRoomRestQuip), findsNothing);
  });
}
