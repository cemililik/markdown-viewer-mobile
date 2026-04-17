import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/reading_position_store.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // `markdown_widget` renders its content through `visibility_detector`,
  // which schedules a 500 ms debounce timer on paint to batch
  // visibility callbacks. Under `flutter_test`'s fake clock that timer
  // is never drained and the test framework then reports it as a
  // pending-timer leak at teardown. Collapsing the debounce interval
  // to zero here makes the callback fire synchronously on each paint,
  // which avoids the leak without changing any production behaviour.
  //
  // The controller is a process-wide singleton, so we save the
  // original interval before mutating it and restore it in
  // `tearDownAll` — otherwise a later test file that loaded this one
  // would inherit `Duration.zero` and lose visibility-detector
  // behaviour it relies on.
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  const id = DocumentId('/tmp/example.md');

  const sampleDocument = Document(
    id: id,
    source: '# Example\n\nBody text.',
    headings: [
      HeadingRef(level: 1, text: 'Example', anchor: 'example', blockIndex: 0),
    ],
    lineCount: 3,
    byteSize: 22,
    topLevelBlockCount: 2,
  );

  Future<Widget> harness(
    DocumentRepository repo, {
    ReadingPositionStore? readingPositionStore,
    Map<String, Object>? settingsPrefs,
    RecentDocumentsStore? recentsStore,
  }) async {
    // Seed a fresh mocked SharedPreferences per test so the
    // one-shot bookmark hint flag starts in its "unseen" state
    // (the default) unless a test deliberately seeds it true.
    SharedPreferences.setMockInitialValues(settingsPrefs ?? <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repo),
        readingPositionStoreProvider.overrideWithValue(
          readingPositionStore ?? _InMemoryReadingPositionStore(),
        ),
        settingsStoreProvider.overrideWithValue(SettingsStoreImpl(prefs)),
        recentDocumentsStoreProvider.overrideWithValue(
          recentsStore ?? _InMemoryRecentDocumentsStore(),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ViewerScreen(documentId: id),
      ),
    );
  }

  group('ViewerScreen', () {
    testWidgets('shows the loading view while the repository is pending', (
      tester,
    ) async {
      final completer = Completer<Document>();
      await tester.pumpWidget(
        await harness(_CompleterDocumentRepository(completer.future)),
      );

      // No settle — we want to freeze the provider in the pending state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading document…'), findsOneWidget);

      // Complete the future so the test can tear down cleanly. The
      // provider transitions to its data state, ViewerScreen rebuilds
      // with MarkdownView, and because we collapsed the
      // `visibility_detector` debounce to zero at the top of main(),
      // the debounce timer fires synchronously and does not leak.
      completer.complete(sampleDocument);
      await tester.pumpAndSettle();
    });

    testWidgets('renders the document body after a successful load', (
      tester,
    ) async {
      await tester.pumpWidget(
        await harness(const _ImmediateDocumentRepository(sampleDocument)),
      );
      await tester.pumpAndSettle();

      // `markdown_widget` renders the source into real text nodes so a
      // substring match on "Body text." is enough to prove the data
      // branch was taken.
      expect(find.textContaining('Body text.'), findsOneWidget);
      // The app bar shows the basename, never the full path.
      expect(find.text('example.md'), findsOneWidget);
    });

    testWidgets('maps a Failure to the localized error view', (tester) async {
      await tester.pumpWidget(
        await harness(
          const _ThrowingDocumentRepository(
            FileNotFoundFailure(message: 'gone'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This file no longer exists. It may have been moved or deleted.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Retry button is present and labelled per the actionRetry ARB
      // key — tapping it would invalidate the provider.
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'wraps a non-Failure exception in UnknownFailure and still shows an error',
      (tester) async {
        await tester.pumpWidget(
          await harness(_ThrowingNonFailureRepository(StateError('boom'))),
        );
        await tester.pumpAndSettle();

        // errorUnknown ARB key content
        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'bookmark icon is outlined on first build when no position is saved',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
        expect(find.byIcon(Icons.bookmark), findsNothing);
      },
    );

    testWidgets(
      'bookmark icon flips to filled after the user taps the AppBar action',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.bookmark_outline));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark), findsOneWidget);
        expect(find.text('Reading position saved'), findsOneWidget);
      },
    );

    testWidgets(
      'bookmark icon shows filled on first build when a position is already '
      'saved for this document',
      (tester) async {
        final store = _InMemoryReadingPositionStore();
        await store.write(
          ReadingPosition(
            documentId: id,
            // Offset 0 keeps _maybeRestoreReadingPosition from running an
            // animation that scrolls the SliverAppBar offscreen before
            // the assertion runs.
            offset: 0,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );

        await tester.pumpWidget(
          await harness(
            const _ImmediateDocumentRepository(sampleDocument),
            readingPositionStore: store,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_outline), findsNothing);
      },
    );

    testWidgets('shows the back-to-top FAB tooltip widget on the data state', (
      tester,
    ) async {
      await tester.pumpWidget(
        await harness(const _ImmediateDocumentRepository(sampleDocument)),
      );
      await tester.pumpAndSettle();

      // FloatingActionButton.small is rendered (always present, but
      // wrapped in AnimatedScale that starts at scale 0 — the widget
      // itself is in the tree).
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets(
      'tapping bookmark on an already-saved doc updates the snackbar copy '
      'rather than clearing the bookmark',
      (tester) async {
        final store = _InMemoryReadingPositionStore();
        await store.write(
          ReadingPosition(
            documentId: id,
            // Offset 0 prevents the restore animation from scrolling the
            // SliverAppBar offscreen before the assertion runs.
            offset: 0,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );

        await tester.pumpWidget(
          await harness(
            const _ImmediateDocumentRepository(sampleDocument),
            readingPositionStore: store,
            // Hint flag already seen so the snackbar stays on the
            // one-line "Updated" copy for this test.
            settingsPrefs: const <String, Object>{
              'settings.bookmarkHintSeen': true,
            },
          ),
        );
        await tester.pumpAndSettle();

        // Filled on mount (position is pre-seeded).
        expect(find.byIcon(Icons.bookmark), findsOneWidget);

        await tester.tap(find.byIcon(Icons.bookmark));
        await tester.pumpAndSettle();

        // Still filled — tap is save/update, not toggle.
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
        expect(find.text('Reading position updated'), findsOneWidget);
        // And the store still carries a position (not cleared).
        expect(store.read(id), isNotNull);
      },
    );

    testWidgets(
      'first ever bookmark save appends the long-press hint to the snackbar',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.bookmark_outline));
        await tester.pumpAndSettle();

        expect(find.text('Reading position saved'), findsOneWidget);
        expect(
          find.text('Long-press the bookmark icon for options.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the long-press hint does not repeat once the settings flag is seen',
      (tester) async {
        await tester.pumpWidget(
          await harness(
            const _ImmediateDocumentRepository(sampleDocument),
            settingsPrefs: const <String, Object>{
              'settings.bookmarkHintSeen': true,
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.bookmark_outline));
        await tester.pumpAndSettle();

        expect(find.text('Reading position saved'), findsOneWidget);
        expect(
          find.text('Long-press the bookmark icon for options.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'AppBar shows search, TOC, reading-panel and bookmark actions in the data state',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Search in document'), findsOneWidget);
        expect(find.byTooltip('Table of contents'), findsOneWidget);
        expect(find.byTooltip('Reading settings'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the reading settings action opens the Aa bottom sheet',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Reading settings'));
        await tester.pumpAndSettle();

        // Sheet header + the All settings affordance both appear.
        expect(find.text('Reading'), findsOneWidget);
        expect(find.text('All settings'), findsOneWidget);
        expect(find.text('Reset reading defaults'), findsOneWidget);
      },
    );

    testWidgets(
      'AppBar title falls back to the recents display name for folder-sourced files',
      (tester) async {
        // Seed the recents store with a folder-sourced entry
        // whose path is an opaque sha256 cache blob and whose
        // display name carries the original filename. The
        // viewer should pick the display name even though the
        // route documentId points at the cache path.
        final recentsStore = _InMemoryRecentDocumentsStore();
        await recentsStore.write([
          RecentDocument(
            documentId: const DocumentId('/tmp/example.md'),
            openedAt: DateTime.utc(2026, 4, 14),
            displayName: 'pretty-name.md',
          ),
        ]);

        await tester.pumpWidget(
          await harness(
            const _ImmediateDocumentRepository(sampleDocument),
            recentsStore: recentsStore,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('pretty-name.md'), findsOneWidget);
        // The basename of the route documentId must NOT show
        // — the lookup should override it.
        expect(find.text('example.md'), findsNothing);
      },
    );

    testWidgets('tapping the search action opens the bottom search bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        await harness(const _ImmediateDocumentRepository(sampleDocument)),
      );
      await tester.pumpAndSettle();

      // Title shows the basename before search opens.
      expect(find.text('example.md'), findsOneWidget);

      await tester.tap(find.byTooltip('Search in document'));
      await tester.pumpAndSettle();

      // The AppBar title stays; the bottom search bar slides in
      // with a close button and a search hint in the text field.
      expect(find.text('example.md'), findsOneWidget);
      expect(find.byTooltip('Close search'), findsOneWidget);
    });

    testWidgets(
      'typing a query that matches the source shows the 1-based counter',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Search in document'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Body');
        await tester.pumpAndSettle();

        // The sample source is '# Example\n\nBody text.' — one
        // match for 'Body', so the counter reads '1 / 1'.
        expect(find.text('1 / 1'), findsOneWidget);
      },
    );

    testWidgets(
      'typing a query that matches nothing shows the localized empty label',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Search in document'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();

        expect(find.text('No matches'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the TOC action opens the right drawer with the heading',
      (tester) async {
        await tester.pumpWidget(
          await harness(const _ImmediateDocumentRepository(sampleDocument)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Table of contents'));
        await tester.pumpAndSettle();

        // Drawer header + the single heading from the sample
        // document are visible now.
        expect(find.text('Contents'), findsOneWidget);
        expect(find.text('Example'), findsWidgets);
      },
    );

    testWidgets(
      'long-press on a saved bookmark opens the Go to / Remove menu',
      (tester) async {
        final store = _InMemoryReadingPositionStore();
        await store.write(
          ReadingPosition(
            documentId: id,
            // Offset 0 prevents the restore animation from scrolling the
            // SliverAppBar offscreen before the assertion runs.
            offset: 0,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );

        await tester.pumpWidget(
          await harness(
            const _ImmediateDocumentRepository(sampleDocument),
            readingPositionStore: store,
            settingsPrefs: const <String, Object>{
              'settings.bookmarkHintSeen': true,
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.byIcon(Icons.bookmark));
        await tester.pumpAndSettle();

        expect(find.text('Go to saved position'), findsOneWidget);
        expect(find.text('Remove bookmark'), findsOneWidget);

        // Tap Remove → the bookmark is cleared and the icon
        // flips back to outlined.
        await tester.tap(find.text('Remove bookmark'));
        await tester.pumpAndSettle();

        expect(store.read(id), isNull);
        expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
        expect(find.text('Bookmark cleared'), findsOneWidget);
      },
    );
  });
}

final class _ImmediateDocumentRepository implements DocumentRepository {
  const _ImmediateDocumentRepository(this._document);
  final Document _document;

  @override
  Future<Document> load(DocumentId path) async => _document;
}

final class _CompleterDocumentRepository implements DocumentRepository {
  const _CompleterDocumentRepository(this._future);
  final Future<Document> _future;

  @override
  Future<Document> load(DocumentId path) => _future;
}

final class _ThrowingDocumentRepository implements DocumentRepository {
  const _ThrowingDocumentRepository(this._failure);
  final Failure _failure;

  @override
  Future<Document> load(DocumentId path) async => throw _failure;
}

final class _ThrowingNonFailureRepository implements DocumentRepository {
  const _ThrowingNonFailureRepository(this._error);
  final Object _error;

  @override
  Future<Document> load(DocumentId path) async => throw _error;
}

/// In-memory [ReadingPositionStore] for tests that don't care about
/// the bookmark feature itself but still need a store that can be
/// `read` synchronously without throwing.
final class _InMemoryReadingPositionStore implements ReadingPositionStore {
  final Map<String, ReadingPosition> _positions = {};

  @override
  ReadingPosition? read(DocumentId documentId) => _positions[documentId.value];

  @override
  Future<void> write(ReadingPosition position) async {
    _positions[position.documentId.value] = position;
  }

  @override
  Future<void> clear(DocumentId documentId) async {
    _positions.remove(documentId.value);
  }
}

/// In-memory [RecentDocumentsStore] so the viewer's
/// `ref.listen` → `touch` hop does not crash when the
/// document provider transitions to its data state.
final class _InMemoryRecentDocumentsStore implements RecentDocumentsStore {
  List<RecentDocument> _state = const <RecentDocument>[];

  @override
  List<RecentDocument> read() => List.unmodifiable(_state);

  @override
  Future<void> write(List<RecentDocument> documents) async {
    _state = List<RecentDocument>.from(documents);
  }
}
