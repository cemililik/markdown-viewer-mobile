import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/mermaid_block.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  Widget harness({
    required MermaidRenderer renderer,
    Locale locale = const Locale('en'),
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
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: MermaidBlock(code: 'flowchart LR; A-->B')),
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

      // Resolve the pending future so the dispose path doesn't leak a
      // microtask into the next test run.
      renderer.completeWith(const MermaidRenderSuccess('<svg/>'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'renders an SvgPicture when the renderer returns a successful result',
      (tester) async {
        final renderer = _CannedMermaidRenderer(
          const MermaidRenderSuccess(
            '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>',
          ),
        );

        await tester.pumpWidget(harness(renderer: renderer));
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsOneWidget);
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
        expect(find.byType(SvgPicture), findsNothing);
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
  });
}

class _CannedMermaidRenderer implements MermaidRenderer {
  _CannedMermaidRenderer(this.result);

  final MermaidRenderResult result;

  @override
  Future<void> prewarm() async {}

  @override
  Future<MermaidRenderResult> render(String source) async => result;

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
  Future<MermaidRenderResult> render(String source) {
    final completer = Completer<MermaidRenderResult>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> dispose() async {}
}
