import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';

/// End-to-end mermaid renderer test against a real
/// `HeadlessInAppWebView` running the bundled `mermaid.min.js`.
///
/// Unlike the unit tests under `test/unit/.../mermaid/`, this file
/// drives the **production** `MermaidRendererImpl` with its real
/// `HeadlessMermaidJsChannel`. It must run on a device or simulator
/// (`flutter test integration_test/mermaid_render_test.dart -d <id>`)
/// because `flutter_inappwebview` needs a platform binding to spin
/// up its native WebView.
///
/// What we lock in here:
///
/// 1. The bundled mermaid asset loads and the sandbox initialises
///    cleanly.
/// 2. A real flowchart source renders to a non-empty PNG bitmap and
///    the output is validated by checking the PNG signature bytes.
/// 3. A deliberately broken diagram surfaces as a typed
///    [MermaidRenderFailure] without crashing the renderer.
/// 4. The cache short-circuits a repeat render — the second call
///    completes in a fraction of the cold-render time.
/// 5. End-to-end (`prewarm + first render`) stays under the 800 ms
///    budget from `docs/rendering-pipeline.md` and the Phase 1.6
///    roadmap entry.
///
/// All five together cover the two checklist items the unit + widget
/// tests intentionally could not (real WebView round-trip and the
/// performance budget) so Phase 1.6 can close out as ✅.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MermaidRendererImpl renderer;
  late Duration prewarmAndFirstRender;

  setUpAll(() async {
    final mermaidJs = await rootBundle.loadString(
      'assets/mermaid/mermaid.min.js',
    );
    renderer = MermaidRendererImpl.production(mermaidJs: mermaidJs);

    // Measure prewarm + first render together — the first render is
    // what users actually wait for when they open a mermaid-heavy
    // document for the first time, so the budget covers both legs
    // of the cold path.
    final stopwatch = Stopwatch()..start();
    await renderer.prewarm();
    await renderer.render('flowchart LR\n  A --> B');
    stopwatch.stop();
    prewarmAndFirstRender = stopwatch.elapsed;
  });

  tearDownAll(() async {
    await renderer.dispose();
  });

  group('MermaidRendererImpl (real WebView)', () {
    testWidgets(
      'renders a flowchart source to a non-empty PNG bitmap with natural '
      'pixel dimensions',
      (tester) async {
        final result = await renderer.render('flowchart TD\n  Start --> Stop');

        expect(result, isA<MermaidRenderSuccess>());
        final success = result as MermaidRenderSuccess;
        expect(
          success.pngBytes,
          isNotEmpty,
          reason:
              'The native takeScreenshot path must return decoded PNG bytes',
        );
        // First 8 bytes of a PNG are the fixed signature
        // 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A.
        expect(success.pngBytes.length, greaterThan(8));
        expect(success.pngBytes[0], 0x89);
        expect(success.pngBytes[1], 0x50);
        expect(success.pngBytes[2], 0x4E);
        expect(success.pngBytes[3], 0x47);
        expect(success.pngBytes[4], 0x0D);
        expect(success.pngBytes[5], 0x0A);
        expect(success.pngBytes[6], 0x1A);
        expect(success.pngBytes[7], 0x0A);
        expect(success.width, greaterThan(0));
        expect(success.height, greaterThan(0));
      },
    );

    testWidgets(
      'returns MermaidRenderFailure for a deliberately broken diagram '
      'without crashing the renderer',
      (tester) async {
        final result = await renderer.render('flowchart LR\n  A -->');

        expect(result, isA<MermaidRenderFailure>());
        expect(
          (result as MermaidRenderFailure).message,
          isNotEmpty,
          reason: 'mermaid parse errors must surface a non-empty message',
        );

        // The renderer must keep working after a broken render —
        // this is the inline-error contract from ADR-0005.
        final recovery = await renderer.render('flowchart LR\n  X --> Y');
        expect(recovery, isA<MermaidRenderSuccess>());
      },
    );

    testWidgets('cache short-circuits a repeated identical render', (
      tester,
    ) async {
      const source = 'flowchart LR\n  Cached --> Hit';

      final coldStopwatch = Stopwatch()..start();
      await renderer.render(source);
      coldStopwatch.stop();

      final warmStopwatch = Stopwatch()..start();
      await renderer.render(source);
      warmStopwatch.stop();

      expect(
        warmStopwatch.elapsedMicroseconds,
        lessThan(coldStopwatch.elapsedMicroseconds),
        reason:
            'Warm render hit the LRU cache and must come back faster '
            'than the cold render that paid the JS eval cost.',
      );
    });

    testWidgets('every diagram type from the fixture renders without throwing', (
      tester,
    ) async {
      // Mirrors the kinds enumerated in
      // `test/fixtures/markdown/mermaid.md`. Anything that fails
      // here would break a real reading session.
      const sources = <String, String>{
        'flowchart': 'flowchart LR\n  A --> B',
        'sequence': 'sequenceDiagram\n  Alice->>Bob: hi\n  Bob-->>Alice: hello',
        'class': 'classDiagram\n  class Foo { +bar() }',
        'state': 'stateDiagram-v2\n  [*] --> Idle\n  Idle --> [*]',
        'er': 'erDiagram\n  USER ||--o{ DOCUMENT : owns',
        'gantt':
            'gantt\n  title T\n  dateFormat YYYY-MM-DD\n  section S\n  Task :a, 2026-04-01, 1d',
      };

      for (final entry in sources.entries) {
        final result = await renderer.render(entry.value);
        expect(
          result,
          isA<MermaidRenderSuccess>(),
          reason: '${entry.key} diagram must render successfully',
        );
      }
    });

    testWidgets('cold prewarm + first render stays under the 800 ms budget', (
      tester,
    ) async {
      // Captured in setUpAll before any other render warmed the
      // cache. The 800 ms budget comes from
      // docs/rendering-pipeline.md and the Phase 1.6 roadmap.
      // Logged unconditionally so a future regression has an
      // easy data point to inspect, even if the assertion stays
      // green.
      // ignore: avoid_print
      print(
        'mermaid cold path (prewarm + first render): '
        '${prewarmAndFirstRender.inMilliseconds} ms',
      );
      expect(
        prewarmAndFirstRender.inMilliseconds,
        lessThan(800),
        reason:
            'Cold path budget from docs/rendering-pipeline.md and '
            'Phase 1.6 — see roadmap.md for the contract.',
      );
    });
  });
}
