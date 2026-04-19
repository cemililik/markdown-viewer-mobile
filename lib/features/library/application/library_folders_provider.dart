import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/errors/log_and_drop.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';

/// Application-layer binding for the [LibraryFoldersStore] port.
///
/// Throws by default so a missing composition-root override
/// fails loudly instead of silently dropping every folder.
/// Overridden in `lib/main.dart` after
/// `SharedPreferences.getInstance()` lands and in tests via
/// `recentDocumentsStoreProvider`'s usual fake pattern.
final libraryFoldersStoreProvider = Provider<LibraryFoldersStore>((ref) {
  throw UnimplementedError(
    'libraryFoldersStoreProvider must be overridden in the composition '
    'root (lib/main.dart) after `SharedPreferences.getInstance()` '
    'completes, or in tests with a fake-backed LibraryFoldersStore.',
  );
});

/// Application-layer binding for the [FolderEnumerator] port.
///
/// Defaults to the production `dart:io`-backed implementation so
/// the home screen works without any explicit override; tests
/// replace it with a fake that yields a deterministic tree from
/// in-memory data.
final folderEnumeratorProvider = Provider<FolderEnumerator>((ref) {
  throw UnimplementedError(
    'folderEnumeratorProvider must be overridden in the composition '
    'root (lib/main.dart) with FolderEnumeratorImpl, or in tests with '
    'a fake.',
  );
});

/// Notifier that owns the user's library root list for the
/// folder explorer drawer.
///
/// Behaviour:
///
/// 1. **Seeded synchronously** from the injected store on first
///    build so the drawer renders the saved roots on the very
///    first frame.
/// 2. **`add(path)`** prepends a fresh entry stamped with
///    `DateTime.now()`. If the path is already in the list, the
///    method returns `false` without mutating state — the UI
///    surfaces a localized "already added" snackbar so the user
///    understands why nothing happened.
/// 3. **`remove(path)`** drops the matching entry. No-op when
///    the path is not present so a stale callback cannot crash
///    the drawer.
/// 4. **Persistence is fire-and-forget.** Each mutation updates
///    the in-memory state synchronously (so the UI rebuilds
///    immediately) and then drops the store write Future so a
///    slow disk does not block the tap.
class LibraryFoldersController extends Notifier<List<LibraryFolder>> {
  @override
  List<LibraryFolder> build() {
    final store = ref.watch(libraryFoldersStoreProvider);
    return _ordered(store.read());
  }

  /// Returns `true` if [path] was added, `false` if the list
  /// already contained an entry with the same path. The boolean
  /// lets the UI distinguish "added a new root" from "no-op
  /// because of a duplicate" without re-reading the state.
  ///
  /// On iOS, callers must pass the [bookmark] returned by the
  /// native picker alongside the path. Without it, every
  /// subsequent access to the folder will fail with a permission
  /// error. On Android / desktop [bookmark] is always `null`
  /// because the filesystem path alone is sufficient.
  bool add(String path, {String? bookmark}) {
    final alreadyExists = state.any((folder) => folder.path == path);
    if (alreadyExists) {
      return false;
    }
    final fresh = LibraryFolder(
      path: path,
      addedAt: DateTime.now(),
      bookmark: bookmark,
    );
    final updated = _ordered(<LibraryFolder>[fresh, ...state]);
    state = updated;
    dropWithLog(
      ref,
      ref.read(libraryFoldersStoreProvider).write(updated),
      'library.folders.add',
    );
    return true;
  }

  /// Replaces the bookmark blob on the entry at [path] with
  /// [bookmark]. Used by the folder body's retry path when iOS
  /// hands back a refreshed `.withSecurityScope` bookmark via
  /// [NativeFolderBookmarkStaleException.refreshedBookmark]. No-op
  /// when no entry matches [path].
  void updateBookmark({required String path, required String bookmark}) {
    final index = state.indexWhere((folder) => folder.path == path);
    if (index < 0) return;
    final updatedList = [...state];
    updatedList[index] = LibraryFolder(
      path: state[index].path,
      addedAt: state[index].addedAt,
      bookmark: bookmark,
    );
    state = _ordered(updatedList);
    dropWithLog(
      ref,
      ref.read(libraryFoldersStoreProvider).write(state),
      'library.folders.updateBookmark',
    );
  }

  /// Removes the entry with the matching [path]. No-op when the
  /// list does not contain such an entry.
  void remove(String path) {
    final updated = state.where((folder) => folder.path != path).toList();
    if (updated.length == state.length) {
      return;
    }
    state = updated;
    dropWithLog(
      ref,
      ref.read(libraryFoldersStoreProvider).write(updated),
      'library.folders.remove',
    );
  }

  /// Canonical ordering: most recently added first. Centralising
  /// the sort here keeps `add`, the initial store read, and any
  /// future mutation entry point producing the same shape.
  List<LibraryFolder> _ordered(List<LibraryFolder> input) {
    final sorted = <LibraryFolder>[...input]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted;
  }
}

final libraryFoldersControllerProvider =
    NotifierProvider<LibraryFoldersController, List<LibraryFolder>>(
      LibraryFoldersController.new,
    );
