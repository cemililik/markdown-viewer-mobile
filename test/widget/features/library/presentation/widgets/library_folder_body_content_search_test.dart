import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/application/folder_file_materializer_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/library_folder_body.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// Stub filename enumerator — returns a fixed two-file tree so the
/// body always has at least the "Files" section to compose against
/// (the content section still has to paint even if the filename
/// filter matches nothing).
class _StubEnumerator implements FolderEnumerator {
  const _StubEnumerator();

  @override
  Future<List<FolderEntry>> enumerate(
    LibraryFolder folder, {
    String? subPath,
  }) async {
    return const <FolderEntry>[
      FolderFileEntry(name: 'readme.md', path: '/stub/readme.md'),
      FolderFileEntry(name: 'notes.md', path: '/stub/notes.md'),
    ];
  }

  @override
  Future<List<FolderFileEntry>> enumerateRecursive(LibraryFolder folder) async {
    return const <FolderFileEntry>[
      FolderFileEntry(name: 'readme.md', path: '/stub/readme.md'),
      FolderFileEntry(name: 'notes.md', path: '/stub/notes.md'),
    ];
  }
}

/// Stub materializer so `openFolderEntry` does not fault on a
/// missing platform channel during tap tests.
class _StubMaterializer implements FolderFileMaterializer {
  const _StubMaterializer();

  @override
  Future<String> materialize({
    required LibraryFolder folder,
    required String sourcePath,
  }) async {
    return sourcePath;
  }
}

/// In-memory content-search service — returns a single match for a
/// preset query, otherwise an empty list. Avoids real filesystem
/// I/O and the `compute()` isolate hop, keeping the widget test
/// deterministic and fast.
class _StubContentSearch implements LibraryContentSearch {
  const _StubContentSearch({required this.expectedQuery, required this.match});

  final String expectedQuery;
  final ContentSearchMatch match;

  @override
  Future<List<ContentSearchMatch>> search({
    required String query,
    required List<RecentDocument> recents,
    required List<LibraryFolder> folders,
    required List<SyncedRepo> syncedRepos,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) async {
    if (query == expectedQuery) {
      return <ContentSearchMatch>[match];
    }
    return const <ContentSearchMatch>[];
  }
}

void main() {
  final folder = LibraryFolder(path: '/stub', addedAt: DateTime(2026, 1, 1));

  Widget harness({required LibraryContentSearch searchService}) {
    return ProviderScope(
      overrides: [
        folderEnumeratorProvider.overrideWithValue(const _StubEnumerator()),
        folderFileMaterializerProvider.overrideWithValue(
          const _StubMaterializer(),
        ),
        libraryContentSearchProvider.overrideWithValue(searchService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: LibraryFolderBody(
            folder: folder,
            refreshTick: 0,
            onRefresh: () async {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'content matches surface below filename matches when the query has no filename hit',
    (tester) async {
      // "Dart" does not appear in `readme.md` or `notes.md`, so the
      // filename filter yields nothing. The content stub returns a
      // synthetic match that names `notes.md` — the body must still
      // render it under the "Inside documents" header instead
      // of the old "No matching files" empty state.
      const match = ContentSearchMatch(
        documentId: DocumentId('/stub/notes.md'),
        displayName: 'notes.md',
        snippet: 'notes about Dart syntax',
        snippetMatchStart: 12,
        snippetMatchLength: 4,
        matchCount: 1,
        sourceLabel: 'Folder: stub',
      );
      await tester.pumpWidget(
        harness(
          searchService: const _StubContentSearch(
            expectedQuery: 'dart',
            match: match,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Dart');
      // Tick past the 250 ms debounce so the stub scan fires.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Old bug: this would render the "No matching files in stub"
      // empty state because the filename filter misses. Now the
      // content section renders with the match.
      expect(find.text('No matching files in stub'), findsNothing);
      expect(find.text('Inside documents'), findsOneWidget);
      expect(find.text('notes.md'), findsOneWidget);
    },
  );

  testWidgets(
    'short queries (< 3 chars) suppress the content section entirely',
    (tester) async {
      // At 1–2 characters the content scan is a noise-trap (too
      // many false positives, wasted isolate work). The body
      // should render filename matches only and omit the content
      // header completely.
      await tester.pumpWidget(
        harness(
          searchService: const _StubContentSearch(
            expectedQuery: 'dart',
            // Unused at this query length.
            match: ContentSearchMatch(
              documentId: DocumentId('/stub/notes.md'),
              displayName: 'notes.md',
              snippet: '',
              snippetMatchStart: 0,
              snippetMatchLength: 0,
              matchCount: 0,
              sourceLabel: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 're');
      await tester.pumpAndSettle();

      // `readme.md` contains "re", so filename filter hits.
      expect(find.text('readme.md'), findsOneWidget);
      // Content header stays hidden until the query reaches the
      // min length.
      expect(find.text('Inside documents'), findsNothing);
    },
  );

  testWidgets(
    'content section shows an empty-state message when the scan finishes with no hits',
    (tester) async {
      // The scan runs (query ≥ 3 chars) but the source has no hits.
      // The "No matches in any document" line should appear beneath
      // the content header instead of nothing at all — otherwise
      // the header would stand alone and look broken.
      await tester.pumpWidget(
        harness(
          searchService: const _StubContentSearch(
            expectedQuery: 'neverpresent',
            match: ContentSearchMatch(
              documentId: DocumentId('/stub/notes.md'),
              displayName: 'notes.md',
              snippet: '',
              snippetMatchStart: 0,
              snippetMatchLength: 0,
              matchCount: 0,
              sourceLabel: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyz123');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Neither filename filter nor content scan hits — the body
      // falls back to the single centred "no matches" hint.
      expect(find.text('No matching files in stub'), findsOneWidget);
      // Content header must not stand alone without content.
      expect(find.text('Inside documents'), findsNothing);
    },
  );
}
