import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/presentation/screens/library_screen.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// In-memory store so each test can seed the library in whatever
/// state the scenario needs without touching SharedPreferences.
class _InMemoryStore implements RecentDocumentsStore {
  _InMemoryStore([List<RecentDocument>? seed])
    : _state = <RecentDocument>[...?seed];

  List<RecentDocument> _state;

  @override
  List<RecentDocument> read() => List.unmodifiable(_state);

  @override
  Future<void> write(List<RecentDocument> documents) async {
    _state = List<RecentDocument>.from(documents);
  }
}

class _InMemoryFoldersStore implements LibraryFoldersStore {
  _InMemoryFoldersStore([List<LibraryFolder>? seed])
    : _state = <LibraryFolder>[...?seed];

  List<LibraryFolder> _state;

  @override
  List<LibraryFolder> read() => List.unmodifiable(_state);

  @override
  Future<void> write(List<LibraryFolder> folders) async {
    _state = List<LibraryFolder>.from(folders);
  }
}

class _NoopEnumerator implements FolderEnumerator {
  const _NoopEnumerator();

  @override
  Future<List<FolderEntry>> enumerate(String folderPath) async =>
      const <FolderEntry>[];
}

Widget _harness(
  RecentDocumentsStore store, {
  LibraryFoldersStore? foldersStore,
  FolderEnumerator? enumerator,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LibraryScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('__settings__')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      recentDocumentsStoreProvider.overrideWithValue(store),
      libraryFoldersStoreProvider.overrideWithValue(
        foldersStore ?? _InMemoryFoldersStore(),
      ),
      folderEnumeratorProvider.overrideWithValue(
        enumerator ?? const _NoopEnumerator(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
    ),
  );
}

void main() {
  group('LibraryScreen', () {
    testWidgets(
      'empty state shows the welcome icon plus three onboarding buttons',
      (tester) async {
        await tester.pumpWidget(_harness(_InMemoryStore()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
        expect(find.text('No documents yet'), findsOneWidget);
        expect(find.text('Open file'), findsOneWidget);
        expect(find.text('Open folder'), findsOneWidget);
        expect(find.text('Sync repository'), findsOneWidget);
        expect(
          find.byType(FloatingActionButton),
          findsNothing,
          reason: 'The FAB only shows in the populated state.',
        );
      },
    );

    testWidgets('AppBar hamburger opens the folder explorer drawer', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_InMemoryStore()));
      await tester.pumpAndSettle();

      // Drawer is closed → its empty-state title is not on screen yet.
      expect(find.text('No folders yet'), findsNothing);

      await tester.tap(find.byTooltip('Open folders'));
      await tester.pumpAndSettle();

      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('No folders yet'), findsOneWidget);
    });

    testWidgets('drawer renders a tile for every persisted library folder', (
      tester,
    ) async {
      final foldersStore = _InMemoryFoldersStore([
        LibraryFolder(path: '/tmp/notes', addedAt: DateTime.utc(2026, 4, 14)),
        LibraryFolder(path: '/tmp/blog', addedAt: DateTime.utc(2026, 4, 13)),
      ]);

      await tester.pumpWidget(
        _harness(_InMemoryStore(), foldersStore: foldersStore),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open folders'));
      await tester.pumpAndSettle();

      expect(find.text('notes'), findsOneWidget);
      expect(find.text('blog'), findsOneWidget);
      expect(find.text('No folders yet'), findsNothing);
    });

    testWidgets(
      'populated state shows a + FAB that expands the speed dial menu',
      (tester) async {
        final store = _InMemoryStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/alpha.md'),
            openedAt: DateTime.now(),
          ),
        ]);

        await tester.pumpWidget(_harness(store));
        await tester.pumpAndSettle();

        // Closed: primary FAB is visible, mini-FAB labels are not
        // exposed because the menu has not been opened yet.
        expect(find.byTooltip('Add documents'), findsOneWidget);

        await tester.tap(find.byTooltip('Add documents'));
        await tester.pumpAndSettle();

        // Three speed dial labels are now on screen — Open file
        // appears twice (mini-FAB tooltip + label chip).
        expect(find.text('Open folder'), findsOneWidget);
        expect(find.text('Sync repository'), findsOneWidget);
      },
    );

    testWidgets(
      'populated state shows greeting + search + Today group + tile + FAB',
      (tester) async {
        final now = DateTime.now();
        final store = _InMemoryStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/alpha.md'),
            openedAt: now.subtract(const Duration(seconds: 5)),
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/beta.md'),
            openedAt: now.subtract(const Duration(minutes: 30)),
          ),
        ]);

        await tester.pumpWidget(_harness(store));
        await tester.pumpAndSettle();

        // Greeting header: one of three salutations based on hour.
        final greetingCandidates = {
          'Good morning',
          'Good afternoon',
          'Good evening',
        };
        expect(
          greetingCandidates.any((g) => find.text(g).evaluate().isNotEmpty),
          isTrue,
          reason:
              'Greeting header must render one of the three time-of-day '
              'salutations.',
        );
        expect(find.text('2 recent documents'), findsOneWidget);

        // Search field.
        expect(find.text('Search recents'), findsOneWidget);

        // Today group header (both alpha.md and beta.md were touched
        // within the current day).
        expect(find.text('Today'), findsOneWidget);

        // Tiles.
        expect(find.text('alpha.md'), findsOneWidget);
        expect(find.text('beta.md'), findsOneWidget);

        // Primary speed-dial FAB (mini-FABs remain collapsed and
        // off-screen until the menu opens, so we verify the
        // primary one is present by its tooltip).
        expect(find.byTooltip('Add documents'), findsOneWidget);

        // Old empty state is gone.
        expect(find.text('No documents yet'), findsNothing);
      },
    );

    testWidgets(
      'pinned entries appear in their own section above the time groups',
      (tester) async {
        final now = DateTime.now();
        final store = _InMemoryStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/pinned.md'),
            openedAt: now.subtract(const Duration(minutes: 2)),
            isPinned: true,
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/regular.md'),
            openedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ]);

        await tester.pumpWidget(_harness(store));
        await tester.pumpAndSettle();

        expect(find.text('Pinned'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('pinned.md'), findsOneWidget);
        expect(find.text('regular.md'), findsOneWidget);
      },
    );

    testWidgets(
      'search filters tiles by basename and shows the empty state when no match',
      (tester) async {
        final now = DateTime.now();
        final store = _InMemoryStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/alpha.md'),
            openedAt: now.subtract(const Duration(minutes: 1)),
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/beta.md'),
            openedAt: now.subtract(const Duration(minutes: 2)),
          ),
        ]);

        await tester.pumpWidget(_harness(store));
        await tester.pumpAndSettle();

        // Substring match: only alpha should remain.
        await tester.enterText(find.byType(TextField), 'alph');
        await tester.pumpAndSettle();
        expect(find.text('alpha.md'), findsOneWidget);
        expect(find.text('beta.md'), findsNothing);

        // No-match path: empty state copy appears.
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(find.text('No matching documents'), findsOneWidget);
        expect(find.text('alpha.md'), findsNothing);
        expect(find.text('beta.md'), findsNothing);
      },
    );

    testWidgets(
      'preview snippet appears as a third subtitle line when set on the entry',
      (tester) async {
        final store = _InMemoryStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/alpha.md'),
            openedAt: DateTime.now(),
            preview: 'This is the opening paragraph.',
          ),
        ]);

        await tester.pumpWidget(_harness(store));
        await tester.pumpAndSettle();

        expect(find.text('This is the opening paragraph.'), findsOneWidget);
      },
    );

    testWidgets('Clear all opens a confirmation dialog and wipes the list', (
      tester,
    ) async {
      final store = _InMemoryStore([
        RecentDocument(
          documentId: const DocumentId('/tmp/alpha.md'),
          openedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(_harness(store));
      await tester.pumpAndSettle();

      // Scroll the trailing Clear all button into view — it sits
      // below the tiles and may be off-screen on the default test
      // surface.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'Clear all'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Clear recent documents?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('alpha.md'), findsNothing);
      expect(find.text('No documents yet'), findsOneWidget);
    });
  });

  group('library helpers', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('greetingFor picks morning/afternoon/evening by hour', () {
      expect(greetingFor(5, l10n), 'Good morning');
      expect(greetingFor(11, l10n), 'Good morning');
      expect(greetingFor(12, l10n), 'Good afternoon');
      expect(greetingFor(17, l10n), 'Good afternoon');
      expect(greetingFor(18, l10n), 'Good evening');
      expect(greetingFor(4, l10n), 'Good evening');
    });

    test('formatRelativeOpenedAt returns Just now for sub-minute deltas', () {
      final now = DateTime.now().subtract(const Duration(seconds: 10));
      expect(formatRelativeOpenedAt(l10n, now), 'Just now');
    });

    test('formatRelativeOpenedAt returns minutes-ago plural', () {
      final now = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeOpenedAt(l10n, now), '5 minutes ago');
    });

    test('formatRelativeOpenedAt returns hours-ago plural', () {
      final now = DateTime.now().subtract(const Duration(hours: 3));
      expect(formatRelativeOpenedAt(l10n, now), '3 hours ago');
    });

    test('formatRelativeOpenedAt returns Yesterday for one day ago', () {
      final now = DateTime.now().subtract(const Duration(days: 1, hours: 1));
      expect(formatRelativeOpenedAt(l10n, now), 'Yesterday');
    });

    test('formatRelativeOpenedAt returns days-ago plural below one week', () {
      final now = DateTime.now().subtract(const Duration(days: 4));
      expect(formatRelativeOpenedAt(l10n, now), '4 days ago');
    });

    test('formatRelativeOpenedAt falls through to long-ago after a week', () {
      final now = DateTime.now().subtract(const Duration(days: 30));
      expect(formatRelativeOpenedAt(l10n, now), 'A while back');
    });
  });
}
