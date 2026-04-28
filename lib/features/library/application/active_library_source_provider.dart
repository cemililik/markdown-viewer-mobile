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
    // Watch the folder list. Three reactions:
    //   - removed folder       → reset to Recents (stale-pointer guard).
    //   - renamed folder       → replace the held entity so the
    //     library AppBar / source-picker labels rebuild against the
    //     fresh `customName` without waiting on the next user
    //     navigation.
    //   - refreshed bookmark   → replace the held entity so the
    //     iOS security-scoped bookmark on the active source picks
    //     up `LibraryFoldersController.updateBookmark` writes
    //     instead of staying on the stale blob.
    ref.listen(libraryFoldersControllerProvider, (previous, next) {
      final current = state;
      if (current is FolderSource) {
        LibraryFolder? match;
        for (final folder in next) {
          if (folder.path == current.folder.path) {
            match = folder;
            break;
          }
        }
        if (match == null) {
          state = const RecentsSource();
        } else if (match.customName != current.folder.customName ||
            match.bookmark != current.folder.bookmark) {
          state = FolderSource(match);
        }
      }
    });

    // Same fan-out for the synced-repos list. The provider is a
    // FutureProvider so loading / error states have no list to
    // diff against — bail out instead of treating "no data yet"
    // as "the active repo was removed" and dumping the user back
    // to Recents on every cold start or provider invalidation.
    ref.listen(syncedReposProvider, (previous, next) {
      if (!next.hasValue) return;
      final repos = next.value!;
      final current = state;
      if (current is SyncedRepoSource) {
        SyncedRepo? match;
        for (final r in repos) {
          if (r.id == current.syncedRepo.id) {
            match = r;
            break;
          }
        }
        if (match == null) {
          state = const RecentsSource();
        } else if (match.customName != current.syncedRepo.customName) {
          state = SyncedRepoSource(match);
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
