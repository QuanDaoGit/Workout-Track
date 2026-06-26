import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_track/theme/tokens.dart';

/// Shared render harness for the `/audit` skill.
///
/// Renders a real app surface to a truthful PNG under `test/audit/_shots/`
/// (gitignored) for an auditor to `Read` during the Presentation / Journey
/// tracks. See `.claude/skills/audit/references/scenarios.md`.
///
/// Honesty guards (Codex-hardened):
///  - **real fonts** (PressStart2P + ShareTechMono) so type/measurement is honest;
///  - **reduced motion** forced, fixed size + dpr → deterministic;
///  - [smokeText] MUST be present after pump or the capture FAILS — a broken or
///    empty-state render cannot masquerade as a polished one;
///  - any `RenderFlex`/overflow `FlutterError` during pump is collected into
///    [AuditCaptureResult.overflowErrors] for the deterministic lint track
///    instead of aborting the capture.
class AuditCaptureResult {
  AuditCaptureResult({required this.pngPath, required this.overflowErrors});

  /// Repo-relative path of the written PNG.
  final String pngPath;

  /// One line per overflow/layout error caught during pump (lint-track input).
  final List<String> overflowErrors;
}

bool _fontsLoaded = false;

Future<void> _loadRealFonts() async {
  if (_fontsLoaded) return;
  Future<ByteData> bytes(String path) async =>
      ByteData.view((await File(path).readAsBytes()).buffer);
  // Load only fonts whose files exist so a missing optional face can't crash the
  // harness. Gotham (body) has no clean regular .ttf in-repo → falls back to the
  // test default face, exactly as the proven golden tests do.
  const specs = <String, String>{
    'PressStart2P': 'fonts/pressstart2p/PressStart2P-Regular.ttf',
    'ShareTechMono': 'fonts/sharetechmono/ShareTechMono-Regular.ttf',
  };
  for (final entry in specs.entries) {
    if (!File(entry.value).existsSync()) continue;
    await (FontLoader(entry.key)..addFont(bytes(entry.value))).load();
  }
  _fontsLoaded = true;
}

/// Render [builder]'s surface and write `test/audit/_shots/<name>.png`.
///
/// [smokeText] is a string that MUST appear once the page has rendered its real
/// content (a header, a known label). Pass the most load-bearing visible text.
Future<AuditCaptureResult> captureSurface(
  WidgetTester tester, {
  required String name,
  required WidgetBuilder builder,
  String? smokeText,
  Size size = const Size(390, 844),
  bool precache = true,
  bool settle = false,
}) async {
  // Load real fonts via runAsync: reading the .ttf is real disk I/O, which never
  // completes inside the testWidgets FakeAsync zone. Safe here — no widget/ticker
  // exists yet. (The proven golden tests do this in setUpAll, i.e. the real zone.)
  await tester.runAsync(_loadRealFonts);

  // Collect overflow/layout errors rather than failing the pump; re-raise
  // everything else through the binding so genuine errors still fail the test.
  final overflow = <String>[];
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final s = details.exceptionAsString();
    if (s.contains('overflowed') || s.contains('A RenderFlex')) {
      overflow.add(s.split('\n').first.trim());
    } else {
      priorOnError?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = priorOnError);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final captureKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Match the app's theme essentials: mono default font (the app sets
      // fontFamily=ShareTechMono globally) + a kBg scaffold. The app's real
      // scaffolds are transparent over a global dark backdrop, so we also paint a
      // kBg ColoredBox behind the page — otherwise transparent scaffolds render
      // over default-white and light-on-light text vanishes.
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'ShareTechMono',
        scaffoldBackgroundColor: kBg,
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: RepaintBoundary(
            key: captureKey,
            child: ColoredBox(
              color: kBg,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    ),
  );

  // Flush the page's async initState load (SharedPreferences/services → setState)
  // with PLAIN pumps. We avoid both pumpAndSettle (the app has ambient perpetual
  // animations that never settle) and, here, runAsync — a loading spinner's
  // forever-spinning Ticker DEADLOCKS runAsync. Plain pumps flush the microtask
  // queue, completing the load and dismissing the spinner. Heavy pages (profile,
  // logs, adventure) have deep await chains / Future.delayed gates — pump enough
  // fake time (40×50ms = 2s) to settle them; cheap since each pump is bounded.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // For pages whose initState load chain doesn't fully drain under fake-time pumps
  // (deep sequential prefs awaits, real plugin init), let it complete in the REAL
  // event loop, then apply the resulting setState with another pump pass.
  if (settle) {
    // Real time for deep load chains + deliberate min-display loaders (adventure's
    // "generating" ceremony, the coverage-map compute). Interleave pumps so timers
    // fired across the window get applied.
    for (var r = 0; r < 6; r++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }
  // Now in the loaded state (no spinner ticker), precache the images it added so
  // real assets paint. runAsync is safe here (load finished); each precache is
  // bounded so a never-completing stream can't stall the capture. Skip via
  // `precache: false` for pages with a reduced-motion-ignoring perpetual ticker
  // (runAsync can deadlock against a live ticker) — CustomPainter UI still paints.
  if (precache) {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        try {
          await precacheImage((element.widget as Image).image, element)
              .timeout(const Duration(seconds: 2));
        } catch (_) {
          // missing/slow asset — fall through; the page still renders.
        }
      }
    });
  }
  // Advance a few bounded frames so precached images + one-shot intros reach a
  // representative resting state, without waiting for perpetual animations.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }

  // Rasterize the current frame to the PNG via the proven golden path — the same
  // mechanism the repo's *_golden_test.dart files use (no hand-rolled toImage,
  // which deadlocks inside runAsync against the test binding). Audit captures MUST
  // run with `flutter test --update-goldens`, which (re)writes the file; without
  // the flag matchesGoldenFile compares and a first run fails by design.
  final pngPath = 'test/audit/_shots/$name.png';
  await expectLater(find.byKey(captureKey), matchesGoldenFile('_shots/$name.png'));

  // Smoke: a broken/empty render must fail (the AppBar title alone is not enough).
  // Optional — for a bulk screen pass where the exact on-screen string is unknown,
  // pass null and inspect the written PNG instead.
  if (smokeText != null) {
    expect(
      find.textContaining(smokeText, findRichText: true),
      findsWidgets,
      reason:
          'audit capture "$name": smokeText "$smokeText" not found — the surface '
          'did not render its real content (empty-state / missing-dependency bug?). '
          'PNG written to $pngPath for inspection.',
    );
  }

  return AuditCaptureResult(pngPath: pngPath, overflowErrors: overflow);
}
