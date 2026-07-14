import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/models/guild_models.dart';
import 'package:workout_track/widgets/guild/guild_roster.dart';

void main() {
  GuildMember player(int days, {String name = 'Quan', String rank = 'RECRUIT'}) =>
      GuildMember(
        name: name,
        avatarSpec: AvatarSpec.fallback,
        activeDays: days,
        rank: rank,
      );

  testWidgets('renders the player tile + N OPEN slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GuildRoster(player: player(3), openSlots: 5)),
      ),
    );
    expect(find.byKey(const ValueKey('guild_roster_player')), findsOneWidget);
    expect(find.text('QUAN'), findsOneWidget);
    expect(find.text('RECRUIT'), findsOneWidget); // earned rank chip
    expect(find.text('3 active days this week'), findsOneWidget);
    expect(find.text('OPEN'), findsNWidgets(5));
  });

  testWidgets('singular day copy + empty name falls back to YOU', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuildRoster(player: player(1, name: ''), openSlots: 0),
        ),
      ),
    );
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('1 active day this week'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);
  });
}
