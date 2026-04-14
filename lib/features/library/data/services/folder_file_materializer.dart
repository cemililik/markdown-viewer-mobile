import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies the contents of a folder-sourced markdown file into the
/// app's cache directory and returns the resulting filesystem
/// path so the existing viewer pipeline (`File(...).readAsBytes`,
/// reading-position store, recents controller) can keep using
/// plain `dart:io` with no SAF / security-scope awareness of its
/// own.
///
/// Why not read the file directly from inside the viewer?
///
/// - On iOS, the picked folder's bytes only live behind a
///   security-scoped NSURL whose access window must be claimed
///   immediately before the read. The viewer is not the layer
///   that owns the bookmark — the library feature is — so the
///   cleanest seam is to materialise once, return a vanilla path,
///   and let the viewer carry on as before.
/// - On Android, the picked folder is a SAF tree URI that
///   `dart:io` cannot read at all. We have to copy the bytes
///   through `ContentResolver` regardless; the materializer is
///   where that copy lands.
///
/// Cache layout: `<appCache>/library_folder_files/<sha256>.md`
/// keyed on the source path so the same file always lands at the
/// same cache slot. Repeated reads of the same document are
/// idempotent; the second read overwrites the bytes, picking up
/// any edits the user made on disk between sessions.
class FolderFileMaterializer {
  const FolderFileMaterializer({
    NativeLibraryFoldersChannel? channel,
    Future<Directory> Function()? cacheDirectoryProvider,
  }) : _channel = channel,
       _cacheDirectoryProvider = cacheDirectoryProvider;

  final NativeLibraryFoldersChannel? _channel;
  final Future<Directory> Function()? _cacheDirectoryProvider;

  NativeLibraryFoldersChannel get _native =>
      _channel ?? NativeLibraryFoldersChannel();

  Future<Directory> _resolveCacheDirectory() {
    final override = _cacheDirectoryProvider;
    if (override != null) return override();
    return getApplicationCacheDirectory();
  }

  /// Materializes the file at [sourcePath] (which lives under
  /// the [folder]'s bookmarked tree) into the app cache and
  /// returns the cache path. Throws on any read error so the
  /// caller can surface a localized snackbar.
  Future<String> materialize({
    required LibraryFolder folder,
    required String sourcePath,
  }) async {
    final bookmark = folder.bookmark;
    if (bookmark == null || bookmark.isEmpty) {
      // The folder was added without a bookmark, which means we
      // are on a platform where the source path is already a
      // real filesystem path the viewer can open directly. The
      // dart:io fast path skips the cache entirely.
      return sourcePath;
    }
    final bytes = await _native.readFileBytes(
      bookmark: bookmark,
      path: sourcePath,
    );
    final cacheDir = await _resolveCacheDirectory();
    final folderCacheDir = Directory(
      p.join(cacheDir.path, 'library_folder_files'),
    );
    if (!folderCacheDir.existsSync()) {
      await folderCacheDir.create(recursive: true);
    }
    final hash = sha256.convert(utf8.encode(sourcePath)).toString();
    // Preserve the original extension so the viewer's
    // basename-driven UI (AppBar title, recents tile) still shows
    // a sensible name. Default to `.md` when the source path has
    // no recognisable extension (e.g. a SAF URI with a query).
    final ext = _extensionFor(sourcePath);
    final cachePath = p.join(folderCacheDir.path, '$hash$ext');

    // The hash was previously computed with sourcePath.codeUnits
    // (UTF-16 code units) instead of utf8.encode. For ASCII paths
    // the two are identical; for any path containing non-ASCII
    // characters the old slot will be an orphan after the hash
    // change. Rename it to the new slot so the bytes survive and
    // no stale files accumulate in the cache directory.
    final legacyHash = sha256.convert(sourcePath.codeUnits).toString();
    if (legacyHash != hash) {
      final legacyFile = File(p.join(folderCacheDir.path, '$legacyHash$ext'));
      if (legacyFile.existsSync()) {
        await legacyFile.rename(cachePath);
      }
    }

    await File(cachePath).writeAsBytes(bytes, flush: true);
    return cachePath;
  }

  String _extensionFor(String sourcePath) {
    final lower = sourcePath.toLowerCase();
    if (lower.endsWith('.markdown')) return '.markdown';
    if (lower.endsWith('.md')) return '.md';
    return '.md';
  }
}

/// Application-layer binding for [FolderFileMaterializer].
///
/// Defaulted to the production implementation so callers can
/// `ref.read(folderFileMaterializerProvider)` without an explicit
/// override; tests replace it with a fake that returns a
/// deterministic path.
final folderFileMaterializerProvider = Provider<FolderFileMaterializer>(
  (ref) => const FolderFileMaterializer(),
);
