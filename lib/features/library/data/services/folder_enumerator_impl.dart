import 'dart:io';

import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:path/path.dart' as p;

/// Production [FolderEnumerator] that routes between the native
/// `LibraryFoldersChannel` (iOS + Android) and `dart:io`.
///
/// **iOS**: the system's document picker hands back a path that
/// is only readable while the security-scoped `NSURL` stays
/// alive. `dart:io` sees that path as a plain string, has no
/// knowledge of the underlying URL, and fails with
/// `PathAccessException(Permission denied)` on every read of a
/// folder outside the app sandbox. The Swift channel resolves
/// the persisted bookmark blob, claims the scope, enumerates,
/// and releases the scope — all inside Swift where the URL
/// lifecycle stays valid.
///
/// **Android**: anything outside the app's own data dir lives
/// behind a Storage Access Framework `content://` tree URI which
/// `dart:io`'s `Directory` cannot read at all. The Kotlin
/// channel uses `DocumentFile.fromTreeUri(...)` to walk the
/// tree, leveraging the persisted permission grant taken at pick
/// time so the URI survives a cold start.
///
/// **Tests / desktop / non-bookmarked folders**: stay on the
/// `dart:io` code path so unit tests can run without a method-
/// channel stub. The routing rule is simple: **if the folder
/// carries a non-empty [LibraryFolder.bookmark], go native;
/// otherwise go dart:io.** The bookmark is opaque to this
/// class — it is passed through to the channel verbatim.
class FolderEnumeratorImpl implements FolderEnumerator {
  const FolderEnumeratorImpl({NativeLibraryFoldersChannel? nativeChannel})
    : _nativeChannel = nativeChannel;

  /// Lazily constructed because the default method channel
  /// instantiation pulls in the platform plugin machinery we do
  /// not want to touch in pure-Dart unit tests.
  final NativeLibraryFoldersChannel? _nativeChannel;

  NativeLibraryFoldersChannel get _native =>
      _nativeChannel ?? NativeLibraryFoldersChannel();

  @override
  Future<List<FolderEntry>> enumerate(
    LibraryFolder folder, {
    String? subPath,
  }) async {
    final effectivePath = subPath ?? folder.path;
    final bookmark = folder.bookmark;
    if (bookmark != null && bookmark.isNotEmpty) {
      return _enumerateViaChannel(
        rootBookmark: bookmark,
        effectivePath: effectivePath,
        rootPath: folder.path,
      );
    }
    return _enumerateViaDartIo(effectivePath);
  }

  @override
  Future<List<FolderFileEntry>> enumerateRecursive(LibraryFolder folder) async {
    final bookmark = folder.bookmark;
    if (bookmark != null && bookmark.isNotEmpty) {
      final raw = await _native.listDirectoryRecursive(bookmark);
      final files =
          raw
              .where((entry) => !entry.isDirectory)
              .map(
                (entry) => FolderFileEntry(path: entry.path, name: entry.name),
              )
              .toList();
      files.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return files;
    }
    return _enumerateRecursiveViaDartIo(folder.path);
  }

  Future<List<FolderEntry>> _enumerateViaChannel({
    required String rootBookmark,
    required String effectivePath,
    required String rootPath,
  }) async {
    // The native channel resolves [rootBookmark] to an NSURL,
    // claims the security scope on it, and lists [effectivePath]
    // (which must sit inside the bookmarked tree). When the
    // folder body drills into a sub-directory, the caller passes
    // the absolute child path as [effectivePath]; the sub-URL
    // inherits the root scope automatically so no extra bookmark
    // is needed per level.
    final raw = await _native.listDirectory(
      rootBookmark,
      subPath: effectivePath == rootPath ? null : effectivePath,
    );
    return _toEntries(raw);
  }

  List<FolderEntry> _toEntries(List<NativeFolderEntry> raw) {
    final subdirs = <FolderSubdirEntry>[];
    final files = <FolderFileEntry>[];
    for (final entry in raw) {
      if (entry.isDirectory) {
        subdirs.add(FolderSubdirEntry(path: entry.path, name: entry.name));
      } else {
        files.add(FolderFileEntry(path: entry.path, name: entry.name));
      }
    }
    int byName(FolderEntry a, FolderEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    subdirs.sort(byName);
    files.sort(byName);
    return <FolderEntry>[...subdirs, ...files];
  }

  Future<List<FolderEntry>> _enumerateViaDartIo(String folderPath) async {
    final directory = Directory(folderPath);
    final children = await directory.list(followLinks: false).toList();

    final files = <FolderFileEntry>[];
    final subdirs = <FolderSubdirEntry>[];

    for (final child in children) {
      final name = p.basename(child.path);
      if (name.startsWith('.')) continue;

      if (child is Directory) {
        subdirs.add(FolderSubdirEntry(path: child.path, name: name));
      } else if (child is File) {
        final lower = name.toLowerCase();
        if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
          files.add(FolderFileEntry(path: child.path, name: name));
        }
      }
    }

    int byName(FolderEntry a, FolderEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    subdirs.sort(byName);
    files.sort(byName);

    return <FolderEntry>[...subdirs, ...files];
  }

  Future<List<FolderFileEntry>> _enumerateRecursiveViaDartIo(
    String folderPath,
  ) async {
    final root = Directory(folderPath);
    final out = <FolderFileEntry>[];
    await _walk(root, out);
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<void> _walk(Directory dir, List<FolderFileEntry> out) async {
    final children = await dir.list(followLinks: false).toList();
    for (final child in children) {
      final name = p.basename(child.path);
      if (name.startsWith('.')) continue;
      if (child is Directory) {
        await _walk(child, out);
      } else if (child is File) {
        final lower = name.toLowerCase();
        if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
          out.add(FolderFileEntry(path: child.path, name: name));
        }
      }
    }
  }
}
