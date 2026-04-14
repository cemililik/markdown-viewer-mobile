import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_source.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';

/// Notifier that owns the currently selected library source.
///
/// The active source is **in-memory UI state**, not persisted.
/// Every cold start lands on [RecentsSource] so the user always
/// sees the "where did I leave off?" home screen first; a folder
/// selection made in a previous session would otherwise drop the
/// user inside a sub-view on launch, which feels wrong for a
/// reading app.
///
/// The controller also **watches** the folder list so that if
/// the user removes the folder that is currently active (via the
/// drawer long-press remove), the state self-heals back to
/// Recents instead of leaving a dangling [FolderSource] pointing
/// at a folder that no longer exists.
class ActiveLibrarySourceController extends Notifier<LibrarySource> {
  @override
  LibrarySource build() {
    // Watch the folder list so a removed folder resets us to Recents.
    ref.listen(libraryFoldersControllerProvider, (previous, next) {
      final current = state;
      if (current is FolderSource) {
        final stillExists = next.any(
          (folder) => folder.path == current.folder.path,
        );
        if (!stillExists) {
          state = const RecentsSource();
        }
      }
    });

    // Watch the synced-repos list so a deleted repo also resets to Recents.
    ref.listen(syncedReposProvider, (previous, next) {
      final current = state;
      if (current is SyncedRepoSource) {
        final repos = next.value ?? <SyncedRepo>[];
        final stillExists = repos.any(
          (SyncedRepo r) => r.id == current.syncedRepo.id,
        );
        if (!stillExists) {
          state = const RecentsSource();
        }
      }
    });

    return const RecentsSource();
  }

  /// Selects the built-in recents source. Called from the drawer
  /// "Recents" tile.
  void selectRecents() {
    state = const RecentsSource();
  }

  /// Selects [folder] as the active library source. Called from
  /// the drawer when the user taps a folder tile.
  void selectFolder(LibraryFolder folder) {
    state = FolderSource(folder);
  }

  /// Selects a synced repository as the active source. Called from
  /// the drawer when the user taps a synced-repo tile.
  void selectSyncedRepo(SyncedRepo repo) {
    state = SyncedRepoSource(repo);
  }
}

/// `NotifierProvider` that owns the currently selected [LibrarySource].
///
/// Initial state is always [RecentsSource]. Resets to [RecentsSource]
/// automatically when the currently active folder is removed from the
/// library — see [ActiveLibrarySourceController.build].
final activeLibrarySourceProvider =
    NotifierProvider<ActiveLibrarySourceController, LibrarySource>(
      ActiveLibrarySourceController.new,
    );
