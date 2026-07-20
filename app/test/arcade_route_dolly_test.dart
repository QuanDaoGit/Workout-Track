import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/widgets/arcade_route.dart';

void main() {
  testWidgets('dolly holds the incoming page back for the travel beat',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('HOME')),
    ));
    navKey.currentState!.push(arcadeRoute(
      (_) => const Scaffold(body: Text('QUESTS')),
      motion: ArcadeRouteMotion.dolly,
    ));
    // 80ms in (t ≈ 0.29 < the 0.42 reveal gate): the incoming page must be
    // fully transparent — the room's dolly owns the frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final fade = tester.widget<FadeTransition>(find
        .ancestor(
            of: find.text('QUESTS'), matching: find.byType(FadeTransition))
        .last);
    expect(fade.opacity.value, 0.0,
        reason: 'travel beat: nothing may cover the dollying room yet');
    // At the end the page is fully in.
    await tester.pump(const Duration(milliseconds: 220));
    final fadeEnd = tester.widget<FadeTransition>(find
        .ancestor(
            of: find.text('QUESTS'), matching: find.byType(FadeTransition))
        .last);
    expect(fadeEnd.opacity.value, 1.0);
  });

  testWidgets('dolly under reduced motion is the plain fade', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const Scaffold(body: Text('HOME')),
    ));
    navKey.currentState!.push(arcadeRoute(
      (_) => const Scaffold(body: Text('QUESTS')),
      motion: ArcadeRouteMotion.dolly,
    ));
    await tester.pumpAndSettle();
    expect(find.text('QUESTS'), findsOneWidget);
  });
}
