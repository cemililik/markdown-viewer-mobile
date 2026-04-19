import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/services/library_content_search_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:path/path.dart' as p;

/// Service binding. Overridden in `main.dart` — see the
/// composition-root note in `docs/standards/architecture-standards.md`.
final libraryContentSearchServiceProvider =
    Provider<LibraryContentSearchService>((ref) {
      return const LibraryContentSearchService();
    });

/// Immutable UI payload for a pending / completed content search.
///
/// The library screen watches this provider directly — exposing the
/// query alongside the results lets the UI tell the difference
/// between "still typing" and "query complete but no matches"
/// without threading extra state.
class ContentSearchState {
  const ContentSearchState({
    required this.query,
    required this.results,
    required this.isLoading,
  });

  const ContentSearchState.idle()
    : query = '',
      results = const <ContentSearchMatch>[],
      isLoading = false;

  final String query;
  final List<ContentSearchMatch> results;
  final bool isLoading;
}

/// Debounced content-search controller.
///
/// Why a custom debounce instead of `Future.delayed`: widget-level
/// debouncers reset on rebuild and leak timers across hot reloads.
/// A Riverpod notifier binds the timer to the provider lifecycle,
/// so `ref.onDispose` cancels it cleanly when the provider is torn
/// down (e.g. test harness ProviderContainer dispose).
///
/// The notifier also snapshots the recents / folders / synced-repos
/// providers at query time — running them as watched state would
/// re-fire the search on every unrelated library-state change
/// (opening a file updates recents, adding a folder ticks the
/// folders provider, …). Users expect search to re-run only when
/// they type; everything else should not burn a corpus walk.
class ContentSearchController extends Notifier<ContentSearchState> {
  static const _debounce = Duration(milliseconds: 250);

  Timer? _debounceTimer;
  int _dispatchSeq = 0;

  @override
  ContentSearchState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const ContentSearchState.idle();
  }

  /// Entry point wired to the library search field's `onChanged`.
  ///
  /// Accepts the per-query labels (Recents / Folder: name /
  /// Repo: owner/repo) because the domain service has no access to
  /// AppLocalizations; the UI resolves them and passes them in.
  void submitQuery({
    required String raw,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) {
    final normalised = raw.trim().toLowerCase();
    _debounceTimer?.cancel();
    if (normalised.isEmpty) {
      state = const ContentSearchState.idle();
      return;
    }

    // Show the spinner immediately so the search field feels
    // responsive while the debounce window runs — the actual scan
    // fires only once typing settles.
    state = ContentSearchState(
      query: normalised,
      results: state.results,
      isLoading: true,
    );

    _debounceTimer = Timer(_debounce, () {
      _runSearch(
        normalised: normalised,
        recentsSourceLabel: recentsSourceLabel,
        folderSourceLabelBuilder: folderSourceLabelBuilder,
        syncedRepoSourceLabelBuilder: syncedRepoSourceLabelBuilder,
      );
    });
  }

  /// Public reset for the library's "clear search" IconButton.
  void clear() {
    _debounceTimer?.cancel();
    state = const ContentSearchState.idle();
  }

  Future<void> _runSearch({
    required String normalised,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) async {
    final seq = ++_dispatchSeq;
    final service = ref.read(libraryContentSearchServiceProvider);
    final recents = ref.read(recentDocumentsControllerProvider);
    final folders = ref.read(libraryFoldersControllerProvider);
    final syncedReposAsync = ref.read(syncedReposProvider);
    final syncedRepos = syncedReposAsync.asData?.value ?? const <SyncedRepo>[];

    try {
      final results = await service.search(
        query: normalised,
        recents: recents,
        folders: folders,
        syncedRepos: syncedRepos,
        recentsSourceLabel: recentsSourceLabel,
        folderSourceLabelBuilder: folderSourceLabelBuilder,
        syncedRepoSourceLabelBuilder: syncedRepoSourceLabelBuilder,
      );
      if (seq != _dispatchSeq) return; // a newer query superseded us
      state = ContentSearchState(
        query: normalised,
        results: results,
        isLoading: false,
      );
    } on Object {
      if (seq != _dispatchSeq) return;
      state = ContentSearchState(
        query: normalised,
        results: const <ContentSearchMatch>[],
        isLoading: false,
      );
    }
  }
}

final contentSearchControllerProvider =
    NotifierProvider<ContentSearchController, ContentSearchState>(
      ContentSearchController.new,
    );

/// Convenience label builder — matches the display format the
/// existing source-picker drawer uses (`Folder: basename`) so a
/// search hit badge looks like everywhere else the source name
/// appears.
String defaultFolderSourceLabel(LibraryFolder folder) {
  final basename = p.basename(folder.path);
  return basename.isEmpty ? folder.path : basename;
}
