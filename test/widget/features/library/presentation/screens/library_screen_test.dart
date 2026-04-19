import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/services/library_content_search_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/library/presentation/screens/library_screen.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Returns no matches synchronously. Keeps the content-search
/// `Timer` debounce in play (the notifier still transitions
/// through `isLoading: true` → `isLoading: false`) but skips the
/// real file walk that would otherwise make `pumpAndSettle` time
/// out on a filesystem stub with missing paths.
class _NoopContentSearch implements LibraryContentSearchService {
  const _NoopContentSearch();

  @override
  Future<List<ContentSearchMatch>> search({
    required String query,
    required List<RecentDocument> recents,
    required List<LibraryFolder> folders,
    required List<SyncedRepo> syncedRepos,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) async => const <ContentSearchMatch>[];
}

class _NoopEnumerator implements FolderEnumerator {
  const _NoopEnumerator();

  @override
  Future<List<FolderEntry>> enumerate(
    LibraryFolder folder, {
    String? subPath,
  }) async => const <FolderEntry>[];

  @override
  Future<List<FolderFileEntry>> enumerateRecursive(
    LibraryFolder folder,
  ) async => const <FolderFileEntry>[];
}

/// Shared prefs instance, initialized once in the file's setUp.
late SharedPreferences _testPrefs;

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
  // GoRouter owns a delegate, parser, and information provider that all
  // hold listener subscriptions. Without this teardown leak_tracker
  // reports them as `notDisposed` because the harness creates a fresh
  // router per test and the widget tree alone never triggers dispose.
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      recentDocumentsStoreProvider.overrideWithValue(store),
      libraryFoldersStoreProvider.overrideWithValue(
        foldersStore ?? _InMemoryFoldersStore(),
      ),
      folderEnumeratorProvider.overrideWithValue(
        enumerator ?? const _NoopEnumerator(),
      ),
      // Bypass the filesystem-walking content-search impl so the
      // screen's debounced `_dispatchContentSearch` resolves
      // instantly inside pumpAndSettle. The stubbed service
      // preserves the loading→idle state transitions the search
      // field relies on without touching any real file I/O.
      libraryContentSearchServiceProvider.overrideWithValue(
        const _NoopContentSearch(),
      ),
      consentStoreProvider.overrideWithValue(ConsentStoreImpl(_testPrefs)),
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
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _testPrefs = await SharedPreferences.getInstance();
  });

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

    testWidgets(
      'AppBar hamburger opens the source picker drawer with Recents + Add source',
      (tester) async {
        await tester.pumpWidget(_harness(_InMemoryStore()));
        await tester.pumpAndSettle();

        // Drawer closed — the header and the drawer-exclusive
        // "Recents" tile are not on screen yet. (The "Recents"
        // text may appear in other places like Recents body
        // headers when a folder has recent documents; in the
        // empty harness that is not a worry.)
        expect(find.text('Folders'), findsNothing);

        await tester.tap(find.byTooltip('Open folders'));
        await tester.pumpAndSettle();

        expect(find.text('Folders'), findsOneWidget);
        expect(find.text('Recents'), findsOneWidget);
        expect(find.text('Add source'), findsOneWidget);
      },
    );

    testWidgets(
      'drawer renders a tile for every persisted library folder under Sources',
      (tester) async {
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

        // Scope to the Drawer because _RecentsEmptyWithSources also renders
        // folder basenames in the main body behind the open drawer.
        final inDrawer = find.byType(Drawer);
        expect(
          find.descendant(of: inDrawer, matching: find.text('Sources')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: inDrawer, matching: find.text('notes')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: inDrawer, matching: find.text('blog')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'selecting a folder in the drawer switches the body to its tree view',
      (tester) async {
        final foldersStore = _InMemoryFoldersStore([
          LibraryFolder(path: '/tmp/notes', addedAt: DateTime.utc(2026, 4, 14)),
        ]);

        await tester.pumpWidget(
          _harness(_InMemoryStore(), foldersStore: foldersStore),
        );
        await tester.pumpAndSettle();

        // Open drawer, tap the folder tile inside the drawer specifically
        // (the body also renders a "notes" tile in _RecentsEmptyWithSources).
        await tester.tap(find.byTooltip('Open folders'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(Drawer),
            matching: find.text('notes'),
          ),
        );
        await tester.pumpAndSettle();

        // AppBar title now shows the folder basename; the
        // folder-scoped search placeholder appears in the body.
        expect(find.text('Search in notes'), findsOneWidget);
        // Greeting no longer shows because we left the Recents
        // source.
        expect(find.text('Good morning'), findsNothing);
        expect(find.text('Good afternoon'), findsNothing);
        expect(find.text('Good evening'), findsNothing);
      },
    );

    testWidgets('populated Recents source shows an extended Open file FAB', (
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

      expect(
        find.widgetWithText(FloatingActionButton, 'Open file'),
        findsOneWidget,
      );
    });

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

        // Extended Open file FAB on the populated Recents source.
        expect(
          find.widgetWithText(FloatingActionButton, 'Open file'),
          findsOneWidget,
        );

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
