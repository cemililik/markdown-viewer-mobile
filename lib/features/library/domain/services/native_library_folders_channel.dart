import 'dart:typed_data';

/// Result of a successful native folder pick.
///
/// [path] is for display only; [bookmark] is the opaque iOS
/// security-scoped bookmark (or Android SAF tree URI) required for
/// all subsequent access.
class NativeFolderPick {
  const NativeFolderPick({required this.path, required this.bookmark});

  final String path;
  final String bookmark;
}

/// One immediate child returned by the native enumerator.
class NativeFolderEntry {
  const NativeFolderEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
  });

  final String path;
  final String name;
  final bool isDirectory;
}

/// Sentinel thrown by [NativeLibraryFoldersChannel.listDirectory]
/// or [NativeLibraryFoldersChannel.listDirectoryRecursive] when
/// the stored bookmark no longer resolves. The folder body maps
/// this to the localized "could not read this folder" state.
///
/// When the underlying platform could refresh the bookmark
/// (iOS — OS returns a fresh bookmark blob from the resolved URL
/// after detecting staleness), [refreshedBookmark] carries the new
/// base64 blob so the caller can persist it and retry without
/// re-prompting the user. `null` when no refresh was possible.
class NativeFolderBookmarkStaleException implements Exception {
  const NativeFolderBookmarkStaleException(
    this.message, {
    this.refreshedBookmark,
  });
  final String message;

  /// Base64-encoded `.withSecurityScope` bookmark blob returned by
  /// iOS when the OS flagged the original bookmark as stale but was
  /// still able to mint a fresh replacement. Persist this into the
  /// `LibraryFolder.bookmark` field and retry the original operation
  /// once; the caller does not need to re-prompt the user.
  ///
  /// `null` on Android (tree URIs do not go stale) and on iOS when
  /// the refresh itself failed — in the `null` case the user needs
  /// to re-add the folder via the picker.
  final String? refreshedBookmark;

  @override
  String toString() => 'NativeFolderBookmarkStaleException: $message';
}

/// Sentinel thrown when the security scope could not be claimed
/// on a resolved bookmark. Treated the same as "stale" from the
/// user's perspective — they need to re-add the folder — but
/// reported separately so logging can tell the two apart.
class NativeFolderAccessDeniedException implements Exception {
  const NativeFolderAccessDeniedException(this.message);
  final String message;

  @override
  String toString() => 'NativeFolderAccessDeniedException: $message';
}

/// Port for the platform-native library-folders channel.
///
/// The concrete implementation (iOS `UIDocumentPickerViewController`
/// + security-scoped bookmarks, Android SAF tree URIs) lives in
/// `data/services/`. The provider is bound in `main.dart` so the
/// application layer can depend on this abstraction without reaching
/// into the data layer — see
/// [docs/standards/architecture-standards.md](../../../../../docs/standards/architecture-standards.md).
abstract class NativeLibraryFoldersChannel {
  /// Shows the system folder picker. Returns `null` when the
  /// user cancels; throws on any other failure path so the
  /// caller can surface a localized error snackbar.
  Future<NativeFolderPick?> pickDirectory();

  /// Lists the immediate `.md` / `.markdown` children and
  /// subdirectories of the bookmarked folder. When [subPath] is
  /// non-null it must be inside the bookmarked tree.
  Future<List<NativeFolderEntry>> listDirectory(
    String bookmark, {
    String? subPath,
  });

  /// Walks the full tree rooted at the bookmarked folder and
  /// returns every markdown leaf as a flat list. Used by the
  /// folder body's search mode.
  Future<List<NativeFolderEntry>> listDirectoryRecursive(String bookmark);

  /// Reads the bytes of [path], which must live inside the tree
  /// identified by [bookmark].
  Future<Uint8List> readFileBytes({
    required String bookmark,
    required String path,
  });
}
