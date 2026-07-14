import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_track/models/avatar_spec.dart';
import 'package:workout_track/pages/avatar_customizer_page.dart';
import 'package:workout_track/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Hosts the page behind a launcher button so pop behavior is observable.
  Future<void> Function() pumpCustomizer(WidgetTester tester) {
    return () async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AvatarCustomizerPage()),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
    };
  }

  testWidgets('renders the five groups and the live combo line', (
    tester,
  ) async {
    await pumpCustomizer(tester)();

    expect(find.text('EDIT AVATAR'), findsOneWidget);
    for (final group in [
      'SKIN',
      'EYES',
      'HAIR STYLE',
      'HAIR COLOR',
      'EXPRESSION',
    ]) {
      expect(find.text(group), findsOneWidget);
    }
    expect(
      find.text('TONE 02 | BROWN | BUZZ | BLACK | READY'),
      findsOneWidget,
    );
    expect(find.text('SAVE'), findsOneWidget);
    expect(find.text('RANDOMIZE'), findsOneWidget);
  });

  testWidgets('chip tap applies instantly; SAVE persists and pops', (
    tester,
  ) async {
    final open = pumpCustomizer(tester);
    await open();

    await tester.tap(find.text('CURLY'));
    await tester.pump();
    expect(
      find.text('TONE 02 | BROWN | CURLY | BLACK | READY'),
      findsOneWidget,
    );

    // Nothing persisted until SAVE.
    expect(
      (await ProfileService().loadProfile()).avatarSpec.hair,
      AvatarHair.buzz,
    );

    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarCustomizerPage), findsNothing);
    expect(
      (await ProfileService().loadProfile()).avatarSpec.hair,
      AvatarHair.curly,
    );
  });

  testWidgets('backing out of edits asks before discarding', (tester) async {
    await pumpCustomizer(tester)();

    await tester.tap(find.text('BALD'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('avatar_customizer_back')));
    await tester.pumpAndSettle();

    expect(find.text('DISCARD CHANGES?'), findsOneWidget);
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarCustomizerPage), findsNothing);
    // The edit was thrown away.
    expect(
      (await ProfileService().loadProfile()).avatarSpec.hair,
      AvatarSpec.fallback.hair,
    );
  });

  testWidgets('back without edits pops straight out', (tester) async {
    await pumpCustomizer(tester)();

    await tester.tap(find.byKey(const ValueKey('avatar_customizer_back')));
    await tester.pumpAndSettle();

    expect(find.text('DISCARD CHANGES?'), findsNothing);
    expect(find.byType(AvatarCustomizerPage), findsNothing);
  });
}
