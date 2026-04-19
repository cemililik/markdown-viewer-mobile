import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/folder_file_materializer_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/library_folder_body.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// Minimal enumerator that returns a fixed, non-empty tree so the
/// body actually renders its `ListView` instead of the loading /
/// error placeholders. The `RefreshIndicator` attaches to the
/// nearest `Scrollable` ancestor of the dragged gesture, so the
/// list has to be present before the gesture can fire.
class _StubEnumerator implements FolderEnumerator {
  const _StubEnumerator();

  @override
  Future<List<FolderEntry>> enumerate(
    LibraryFolder folder, {
    String? subPath,
  }) async {
    return const <FolderEntry>[
      FolderFileEntry(name: 'a.md', path: '/stub/a.md'),
      FolderFileEntry(name: 'b.md', path: '/stub/b.md'),
    ];
  }

  @override
  Future<List<FolderFileEntry>> enumerateRecursive(LibraryFolder folder) async {
    return const <FolderFileEntry>[
      FolderFileEntry(name: 'a.md', path: '/stub/a.md'),
      FolderFileEntry(name: 'b.md', path: '/stub/b.md'),
    ];
  }
}

/// No-op materializer so the body's file-open intent path does not
/// fault the widget test on a missing platform channel.
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

void main() {
  final folder = LibraryFolder(path: '/stub', addedAt: DateTime(2026, 1, 1));
  Widget harness({required Future<void> Function() onRefresh}) {
    return ProviderScope(
      overrides: [
        folderEnumeratorProvider.overrideWithValue(const _StubEnumerator()),
        folderFileMaterializerProvider.overrideWithValue(
          const _StubMaterializer(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: LibraryFolderBody(
            folder: folder,
            refreshTick: 0,
            onRefresh: onRefresh,
          ),
        ),
      ),
    );
  }

  testWidgets('wraps the body in a RefreshIndicator', (tester) async {
    await tester.pumpWidget(harness(onRefresh: () async {}));
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('swipe-down gesture invokes the provided onRefresh callback', (
    tester,
  ) async {
    var refreshCalls = 0;
    await tester.pumpWidget(
      harness(
        onRefresh: () async {
          refreshCalls += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Pull-to-refresh drag: start near the top of the list and
    // travel ~300 dp downward so the RefreshIndicator crosses its
    // trigger distance.
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(refreshCalls, 1);
  });

  testWidgets(
    'refreshTick bump during an active search does not crash the body',
    (tester) async {
      // Regression guard. An earlier version of `didUpdateWidget`
      // unconditionally nulled the cached recursive-walk future when
      // `refreshTick` changed, even if the user was mid-search. The
      // build side renders `_FolderSearchView(recursiveFuture: _recursiveFuture!)`
      // whenever the query is non-empty, so nulling the future from
      // under an active search hit a `!` null-check and red-screened
      // the entire library body with a bare
      // "Null check operator used on a null value" — the exact
      // message ErrorWidget prints when a widget throws during
      // build. The fix restarts the walk when the refresh lands
      // during an active search so the invariant stays intact.
      var tick = 0;
      late StateSetter setOuter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderEnumeratorProvider.overrideWithValue(const _StubEnumerator()),
            folderFileMaterializerProvider.overrideWithValue(
              const _StubMaterializer(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  setOuter = setState;
                  return LibraryFolderBody(
                    folder: folder,
                    refreshTick: tick,
                    onRefresh: () async {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter an active search — populates `_recursiveFuture` via
      // `_onSearchChanged`.
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      // Bump the tick to simulate a pull-to-refresh / sync completion
      // arriving while the search is still active.
      setOuter(() => tick += 1);
      await tester.pumpAndSettle();

      // No red-screen: the body still shows the search field and at
      // least one match from the stub enumerator.
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('a.md'), findsOneWidget);
    },
  );
}
