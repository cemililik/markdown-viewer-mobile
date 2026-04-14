import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/mermaid_block.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// 1×1 transparent PNG (base64-decoded) — the smallest payload
/// that `Image.memory` will accept without complaining. Tests do
/// not inspect pixels; they only need a real PNG-shaped buffer
/// that round-trips through the cache and the widget.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgAAIAAAUAAen63/AAAAAASUVORK5CYII=',
);

MermaidRenderSuccess _successResult({double width = 200, double height = 60}) {
  return MermaidRenderSuccess(pngBytes: _tinyPng, width: width, height: height);
}

void main() {
  Widget harness({
    required MermaidRenderer renderer,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    String code = 'flowchart LR; A-->B',
  }) {
    return ProviderScope(
      overrides: [mermaidRendererProvider.overrideWithValue(renderer)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          brightness: brightness,
          colorSchemeSeed: Colors.blue,
        ),
        home: Scaffold(body: MermaidBlock(code: code)),
      ),
    );
  }

  group('MermaidBlock', () {
    testWidgets('shows the loading placeholder while the future is pending', (
      tester,
    ) async {
      final renderer = _PendingMermaidRenderer();

      await tester.pumpWidget(harness(renderer: renderer));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Rendering diagram…'), findsOneWidget);

      // Resolve the pending future so the dispose path doesn't leak
      // a microtask into the next test run.
      renderer.completeWith(_successResult());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'renders an Image when the renderer returns a successful result',
      (tester) async {
        final renderer = _CannedMermaidRenderer(_successResult());

        await tester.pumpWidget(harness(renderer: renderer));
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'renders the localized error placeholder when the renderer fails',
      (tester) async {
        final renderer = _CannedMermaidRenderer(
          const MermaidRenderFailure('mermaid parse error'),
        );

        await tester.pumpWidget(harness(renderer: renderer));
        await tester.pumpAndSettle();

        // Both the title and body of the error placeholder must be
        // present, looked up by their localized text. Using
        // find.text here is acceptable because the test pins the
        // locale to English explicitly via the harness.
        expect(find.text('Diagram could not be rendered'), findsOneWidget);
        expect(
          find.text('Check the diagram syntax and try again.'),
          findsOneWidget,
        );
        // The renderer's failure message is surfaced as a small
        // monospace detail line so on-device debugging has
        // something concrete to read.
        expect(find.text('mermaid parse error'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets(
      'renders Turkish localized strings on the error placeholder when '
      'locale is tr',
      (tester) async {
        final renderer = _CannedMermaidRenderer(
          const MermaidRenderFailure('boom'),
        );

        await tester.pumpWidget(
          harness(renderer: renderer, locale: const Locale('tr')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Diyagram görüntülenemedi'), findsOneWidget);
      },
    );

    testWidgets(
      'threads a Material 3 themeVariables init directive into render() '
      'when the source has no init of its own',
      (tester) async {
        final renderer = _CannedMermaidRenderer(_successResult());

        await tester.pumpWidget(harness(renderer: renderer));
        await tester.pumpAndSettle();

        expect(renderer.observedDirectives, isNotEmpty);
        final directive = renderer.observedDirectives.first;
        expect(directive, contains('"theme":"base"'));
        expect(directive, contains('"themeVariables"'));
        expect(directive, contains('"primaryColor"'));
      },
    );

    testWidgets(
      'differentiates light and dark renders via different init directives',
      (tester) async {
        final lightRenderer = _CannedMermaidRenderer(_successResult());
        await tester.pumpWidget(
          harness(renderer: lightRenderer, brightness: Brightness.light),
        );
        await tester.pumpAndSettle();

        final darkRenderer = _CannedMermaidRenderer(_successResult());
        await tester.pumpWidget(
          harness(renderer: darkRenderer, brightness: Brightness.dark),
        );
        await tester.pumpAndSettle();

        expect(lightRenderer.observedDirectives, isNotEmpty);
        expect(darkRenderer.observedDirectives, isNotEmpty);
        expect(
          lightRenderer.observedDirectives.first,
          isNot(equals(darkRenderer.observedDirectives.first)),
          reason:
              'Light and dark ColorSchemes must produce different '
              'init directives so the renderer cache buckets them '
              'separately.',
        );
      },
    );

    testWidgets(
      'passes an empty init directive when the user source already has one',
      (tester) async {
        final renderer = _CannedMermaidRenderer(_successResult());

        await tester.pumpWidget(
          harness(
            renderer: renderer,
            code: "%%{init: {'theme':'forest'}}%%\nflowchart LR; A-->B",
          ),
        );
        await tester.pumpAndSettle();

        expect(renderer.observedDirectives, isNotEmpty);
        expect(
          renderer.observedDirectives.first,
          isEmpty,
          reason:
              'A user-authored init directive must be respected — the '
              'MermaidBlock must NOT prepend its own ColorScheme '
              'override.',
        );
      },
    );

    testWidgets(
      'wraps the rendered image in an InteractiveViewer with a SizedBox '
      'parent whose dimensions preserve the renderer-supplied aspect ratio',
      (tester) async {
        final renderer = _CannedMermaidRenderer(
          _successResult(width: 200, height: 50),
        );

        await tester.pumpWidget(harness(renderer: renderer));
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveViewer), findsOneWidget);

        final sized = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byType(InteractiveViewer),
            matching: find.byType(SizedBox),
          ),
        );
        final computedRatio = sized.width! / sized.height!;
        expect(
          computedRatio,
          closeTo(4.0, 1e-3),
          reason: 'width 200 / height 50 should produce aspectRatio 4.0',
        );
      },
    );

    testWidgets('falls back to a 16:9 aspect ratio when the renderer reports a '
        'zero-sized bitmap', (tester) async {
      final renderer = _CannedMermaidRenderer(
        _successResult(width: 0, height: 0),
      );

      await tester.pumpWidget(harness(renderer: renderer));
      await tester.pumpAndSettle();

      final sized = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(InteractiveViewer),
          matching: find.byType(SizedBox),
        ),
      );
      final computedRatio = sized.width! / sized.height!;
      expect(computedRatio, closeTo(16 / 9, 1e-3));
    });

    testWidgets(
      'caps the displayed diagram height at 60% of the screen height for '
      'tall diagrams so the outer scroll always has room to catch gestures',
      (tester) async {
        // 200×2000 is a ~1:10 aspect ratio — the classic tall
        // flowchart that used to eat the whole viewport.
        final renderer = _CannedMermaidRenderer(
          _successResult(width: 200, height: 2000),
        );

        await tester.pumpWidget(harness(renderer: renderer));
        await tester.pumpAndSettle();

        final sized = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byType(InteractiveViewer),
            matching: find.byType(SizedBox),
          ),
        );
        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(
          sized.height!,
          lessThanOrEqualTo(screenHeight * 0.6 + 1),
          reason:
              'Tall diagrams must be clipped to 60% of viewport height so '
              'the outer ListView can catch scroll gestures around them.',
        );
      },
    );

    testWidgets(
      'rebuilds and re-renders when the MermaidBlock.code prop changes',
      (tester) async {
        final renderer = _CodeAwareMermaidRenderer({
          'flowchart LR; A-->B': _successResult(width: 100, height: 60),
          'flowchart LR; C-->D': _successResult(width: 120, height: 40),
        });

        await tester.pumpWidget(
          harness(renderer: renderer, code: 'flowchart LR; A-->B'),
        );
        await tester.pumpAndSettle();

        expect(renderer.observedSources, ['flowchart LR; A-->B']);
        expect(find.byType(Image), findsOneWidget);

        await tester.pumpWidget(
          harness(renderer: renderer, code: 'flowchart LR; C-->D'),
        );
        await tester.pumpAndSettle();

        expect(
          renderer.observedSources,
          ['flowchart LR; A-->B', 'flowchart LR; C-->D'],
          reason:
              'didUpdateWidget must call render() again with the new '
              'code so the displayed image reflects the updated source.',
        );
      },
    );
  });
}

class _CannedMermaidRenderer implements MermaidRenderer {
  _CannedMermaidRenderer(this.result);

  final MermaidRenderResult result;
  final List<String> observedDirectives = [];
  final List<String> observedSources = [];

  @override
  Future<void> prewarm() async {}

  @override
  Future<MermaidRenderResult> render(
    String source, {
    String initDirective = '',
  }) async {
    observedDirectives.add(initDirective);
    observedSources.add(source);
    return result;
  }

  @override
  Future<void> dispose() async {}
}

class _PendingMermaidRenderer implements MermaidRenderer {
  final List<Completer<MermaidRenderResult>> _pending = [];

  void completeWith(MermaidRenderResult result) {
    for (final completer in _pending) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
    _pending.clear();
  }

  @override
  Future<void> prewarm() async {}

  @override
  Future<MermaidRenderResult> render(
    String source, {
    String initDirective = '',
  }) {
    final completer = Completer<MermaidRenderResult>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> dispose() async {}
}

/// Fake [MermaidRenderer] that returns a scripted result keyed by
/// source string and records every observed source. Used by the
/// didUpdateWidget test to prove a `MermaidBlock.code` change
/// re-enters the renderer with the new source.
class _CodeAwareMermaidRenderer implements MermaidRenderer {
  _CodeAwareMermaidRenderer(this._scripted);

  final Map<String, MermaidRenderResult> _scripted;
  final List<String> observedSources = <String>[];

  @override
  Future<void> prewarm() async {}

  @override
  Future<MermaidRenderResult> render(
    String source, {
    String initDirective = '',
  }) async {
    observedSources.add(source);
    final scripted = _scripted[source];
    if (scripted == null) {
      return const MermaidRenderFailure('no scripted result for source');
    }
    return scripted;
  }

  @override
  Future<void> dispose() async {}
}
