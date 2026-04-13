import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/admonition.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // Same VisibilityDetector workaround as the other markdown_widget
  // tests: collapse the debounce to zero and restore it on tear-down
  // so a later test file does not inherit the mutation.
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  const parser = MarkdownParser();

  Document parseFixture(String name) {
    final bytes = File('test/fixtures/markdown/$name').readAsBytesSync();
    return parser.parse(
      id: DocumentId('test/fixtures/markdown/$name'),
      bytes: bytes,
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget standaloneHarness(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: child),
    );
  }

  Widget markdownHarness(
    Document document, {
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: MarkdownView(document: document)),
    );
  }

  group('AdmonitionView', () {
    testWidgets('shows the localized title and the matching icon for note', (
      tester,
    ) async {
      await tester.pumpWidget(
        standaloneHarness(
          const AdmonitionView(
            kind: AdmonitionKind.note,
            body: TextSpan(text: 'Body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.textContaining('Body', findRichText: true), findsOneWidget);
    });

    testWidgets('shows the warning icon and Turkish title under tr locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        standaloneHarness(
          locale: const Locale('tr'),
          const AdmonitionView(
            kind: AdmonitionKind.warning,
            body: TextSpan(text: 'Tehlikeli işlem'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uyarı'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('every kind renders its expected icon', (tester) async {
      // Regression guard: a future palette refactor must keep one
      // distinct icon per kind so users can recognise the alert
      // style at a glance.
      const expected = <AdmonitionKind, IconData>{
        AdmonitionKind.note: Icons.info_outline,
        AdmonitionKind.tip: Icons.lightbulb_outline,
        AdmonitionKind.important: Icons.star_outline,
        AdmonitionKind.warning: Icons.warning_amber_outlined,
        AdmonitionKind.caution: Icons.dangerous_outlined,
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(
          standaloneHarness(
            AdmonitionView(kind: entry.key, body: const TextSpan(text: 'body')),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byIcon(entry.value),
          findsOneWidget,
          reason: '${entry.key.name} must render ${entry.value} icon',
        );
      }
    });
  });

  group('MarkdownView admonition integration', () {
    testWidgets(
      'renders an AdmonitionView for every alert kind in the fixture',
      (tester) async {
        useTallSurface(tester);
        final doc = parseFixture('admonitions.md');

        await tester.pumpWidget(markdownHarness(doc));
        await tester.pumpAndSettle();

        final views = tester.widgetList<AdmonitionView>(
          find.byType(AdmonitionView),
        );
        final kinds = views.map((v) => v.kind).toList();

        expect(
          kinds,
          containsAll(<AdmonitionKind>[
            AdmonitionKind.note,
            AdmonitionKind.tip,
            AdmonitionKind.important,
            AdmonitionKind.warning,
            AdmonitionKind.caution,
          ]),
        );
      },
    );

    testWidgets('localized titles appear on the rendered admonitions', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('admonitions.md');

      await tester.pumpWidget(markdownHarness(doc));
      await tester.pumpAndSettle();

      for (final title in const [
        'Note',
        'Tip',
        'Important',
        'Warning',
        'Caution',
      ]) {
        expect(
          find.text(title),
          findsOneWidget,
          reason: '$title heading must be rendered exactly once',
        );
      }
    });

    testWidgets(
      'plain blockquotes without a kind marker keep default rendering',
      (tester) async {
        useTallSurface(tester);
        final doc = parseFixture('admonitions.md');

        await tester.pumpWidget(markdownHarness(doc));
        await tester.pumpAndSettle();

        // The plain blockquote section's text must still appear in
        // the rendered tree — meaning the parser left it as a real
        // blockquote and our admonition generator did not swallow it.
        expect(
          find.textContaining(
            'Just a normal quoted paragraph',
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('unknown kind markers fall back to a normal blockquote', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('admonitions.md');

      await tester.pumpWidget(markdownHarness(doc));
      await tester.pumpAndSettle();

      // The "[!UNKNOWN]" body text must still appear because the
      // alert syntax does not match — markdown_widget renders it
      // as a regular blockquote. The number of AdmonitionViews
      // must therefore be exactly 5 (the known kinds), not 6.
      expect(
        find.textContaining(
          'Should render as a normal blockquote',
          findRichText: true,
        ),
        findsOneWidget,
      );
      final views = tester.widgetList<AdmonitionView>(
        find.byType(AdmonitionView),
      );
      expect(views, hasLength(5));
    });

    testWidgets('nested inline markup inside an admonition body is preserved', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('admonitions.md');

      await tester.pumpWidget(markdownHarness(doc));
      await tester.pumpAndSettle();

      // The Tip fixture body has a bold phrase and a code span.
      // Both must still reach the rendered tree as text — proof
      // that AdmonitionView's body InlineSpan retained the parsed
      // children rather than collapsing them into a flat string.
      expect(
        find.textContaining('better way', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('code span', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
