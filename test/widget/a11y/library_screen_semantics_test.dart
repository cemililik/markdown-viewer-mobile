import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/library/presentation/screens/library_screen.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'semantics_audit.dart';

void main() {
  late SharedPreferences preferences;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget harness(List<RecentDocument> recents) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(path: '/sync', builder: (_, _) => const SizedBox.shrink()),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        recentDocumentsStoreProvider.overrideWithValue(_RecentStore(recents)),
        libraryFoldersStoreProvider.overrideWithValue(const _FoldersStore()),
        folderEnumeratorProvider.overrideWithValue(const _FolderEnumerator()),
        libraryContentSearchProvider.overrideWithValue(const _ContentSearch()),
        syncedReposProvider.overrideWith((_) async => const <SyncedRepo>[]),
        consentStoreProvider.overrideWithValue(ConsentStoreImpl(preferences)),
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
      ),
    );
  }

  testWidgets('should expose the empty LibraryScreen structure and actions', (
    tester,
  ) async {
    await withSemanticsAudit(tester, () async {
      await tester.pumpWidget(harness(const <RecentDocument>[]));
      await tester.pumpAndSettle();

      final title =
          tester
              .getSemantics(find.bySemanticsLabel(l10n.navLibrary))
              .getSemanticsData();
      expect(title.label, l10n.navLibrary);
      expect(title.flagsCollection.isHeader, isTrue);
      for (final label in [
        l10n.libraryFoldersOpenDrawerTooltip,
        l10n.navSettings,
        l10n.actionOpenFile,
        l10n.libraryActionMenuOpenFolder,
        l10n.actionSyncRepo,
      ]) {
        final finder = find.bySemanticsLabel(label);
        expect(
          finder,
          findsOneWidget,
          reason: 'Library action "$label" must have a semantics node.',
        );
        final data = tester.getSemantics(finder).getSemanticsData();
        expect(data.label, label);
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'Library action "$label" must expose a tap action.',
        );
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Library action "$label" must be labelled as a button.',
        );
      }
      expectEveryTapTargetLabeled(tester);
      expectTapTargetsAtLeast(tester);
    });
  });

  testWidgets('should expose pinned and chronological LibraryScreen headers', (
    tester,
  ) async {
    await withSemanticsAudit(tester, () async {
      final now = DateTime.now();
      await tester.pumpWidget(
        harness([
          RecentDocument(
            documentId: const DocumentId('/tmp/pinned.md'),
            openedAt: now,
            isPinned: true,
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/recent.md'),
            openedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      for (final label in [
        l10n.libraryRecentPinnedSection,
        l10n.libraryRecentGroupToday,
      ]) {
        final data =
            tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData();
        expect(data.label, label);
        expect(
          data.flagsCollection.isHeader,
          isTrue,
          reason: 'Library section "$label" must be a semantic header.',
        );
      }
      expectEveryTapTargetLabeled(tester);
      expectTapTargetsAtLeast(tester);
    });
  });
}

final class _RecentStore implements RecentDocumentsStore {
  _RecentStore(this._documents);

  List<RecentDocument> _documents;

  @override
  List<RecentDocument> read() => List.unmodifiable(_documents);

  @override
  Future<void> write(List<RecentDocument> documents) async {
    _documents = List.of(documents);
  }
}

final class _FoldersStore implements LibraryFoldersStore {
  const _FoldersStore();

  @override
  List<LibraryFolder> read() => const <LibraryFolder>[];

  @override
  Future<void> write(List<LibraryFolder> folders) async {}
}

final class _FolderEnumerator implements FolderEnumerator {
  const _FolderEnumerator();

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

final class _ContentSearch implements LibraryContentSearch {
  const _ContentSearch();

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
