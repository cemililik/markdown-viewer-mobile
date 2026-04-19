import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/domain/services/native_library_folders_channel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Concrete [FolderFileMaterializer] that copies folder-sourced
/// markdown files into the app's cache directory so the viewer
/// pipeline (`File(...).readAsBytes`, reading-position store,
/// recents controller) can keep using plain `dart:io` with no SAF
/// / security-scope awareness of its own.
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
class FolderFileMaterializerImpl implements FolderFileMaterializer {
  const FolderFileMaterializerImpl({
    required NativeLibraryFoldersChannel channel,
    Future<Directory> Function()? cacheDirectoryProvider,
  }) : _native = channel,
       _cacheDirectoryProvider = cacheDirectoryProvider;

  final NativeLibraryFoldersChannel _native;
  final Future<Directory> Function()? _cacheDirectoryProvider;

  Future<Directory> _resolveCacheDirectory() {
    final override = _cacheDirectoryProvider;
    if (override != null) return override();
    return getApplicationCacheDirectory();
  }

  @override
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
    // characters the old slot is an orphan after the hash change.
    // Delete it so stale files do not accumulate in the cache
    // directory. Fresh bytes are written below regardless, so a
    // rename would serve no purpose and would throw on some
    // platforms when the destination already exists.
    final legacyHash = sha256.convert(sourcePath.codeUnits).toString();
    if (legacyHash != hash) {
      final legacyFile = File(p.join(folderCacheDir.path, '$legacyHash$ext'));
      // Best-effort cleanup: skip the prior existsSync() check to avoid a
      // TOCTOU race (file deleted between the check and the delete call).
      // FileSystemException is benign here — the orphan simply stays in the
      // cache until the next open, which is harmless.
      try {
        await legacyFile.delete();
      } on FileSystemException {
        // Ignore — cleanup is non-critical.
      }
    }

    await File(cachePath).writeAsBytes(bytes, flush: true);

    // Opportunistic eviction so the cache directory does not grow
    // unbounded across months of reading — every open of a
    // bookmark-scoped file adds a fresh copy keyed on the source
    // path's hash, and deleted-source files would otherwise linger.
    // Runs as fire-and-forget so the viewer does not wait on the
    // sweep; errors are swallowed because cache-dir hygiene must
    // never block the tap.
    // Reference: security-review SR-20260419-036.
    unawaited(_pruneFolderCache(folderCacheDir));

    return cachePath;
  }

  /// Caps the `library_folder_files` cache directory at
  /// [_maxCacheBytes]. Oldest-first eviction by `lastModified` stat,
  /// which deterministically picks the files least recently read
  /// and leaves active documents intact even under heavy rotation.
  static const int _maxCacheBytes = 50 * 1024 * 1024;

  Future<void> _pruneFolderCache(Directory folderCacheDir) async {
    try {
      final entries = <({File file, int size, DateTime mtime})>[];
      var total = 0;
      await for (final entity in folderCacheDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        entries.add((file: entity, size: stat.size, mtime: stat.modified));
        total += stat.size;
      }
      if (total <= _maxCacheBytes) return;
      entries.sort((a, b) => a.mtime.compareTo(b.mtime));
      for (final entry in entries) {
        if (total <= _maxCacheBytes) break;
        try {
          await entry.file.delete();
          total -= entry.size;
        } on FileSystemException {
          // Skip files we cannot delete (another process has a handle,
          // etc.). The next prune cycle will retry.
        }
      }
    } on FileSystemException {
      // Directory listing failed — nothing to do; cache stays as is
      // until the next materialize call triggers another attempt.
    }
  }

  String _extensionFor(String sourcePath) {
    final lower = sourcePath.toLowerCase();
    if (lower.endsWith('.markdown')) return '.markdown';
    if (lower.endsWith('.md')) return '.md';
    return '.md';
  }
}

// `folderFileMaterializerProvider` lives in
// `application/folder_file_materializer_provider.dart`. Keeping DI
// constructs out of the data layer is the architecture-standards rule
// the port here was originally violating; see P2-4.
