import 'package:flutter/services.dart';

/// Result of a successful native folder pick.
///
/// [path] is for display only; [bookmark] is the opaque iOS security-scoped
/// bookmark required for all subsequent access.
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
/// (iOS — OS returns a fresh bookmark blob via
/// `bookmarkData(options: [.withSecurityScope])` after detecting
/// staleness), [refreshedBookmark] carries the new base64 blob so
/// the caller can persist it and retry without re-prompting the
/// user. `null` when no refresh was possible.
class NativeFolderBookmarkStaleException implements Exception {
  const NativeFolderBookmarkStaleException(
    this.message, {
    this.refreshedBookmark,
  });
  final String message;
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

/// Dart-side wrapper around the `dev.markdownviewer/library_folders`
/// method channel. Deserializes payloads into typed objects and maps
/// platform error codes to sentinel exception types.
class NativeLibraryFoldersChannel {
  NativeLibraryFoldersChannel({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('dev.markdownviewer/library_folders');

  final MethodChannel _channel;

  /// Shows the system folder picker. Returns `null` when the
  /// user cancels; throws on any other failure path so the
  /// caller can surface a localized error snackbar.
  Future<NativeFolderPick?> pickDirectory() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'pickDirectory',
    );
    if (raw == null) return null;
    final path = raw['path'] as String?;
    final bookmark = raw['bookmark'] as String?;
    if (path == null || bookmark == null) {
      throw FormatException(
        'pickDirectory: native payload missing required keys '
        '"path" or "bookmark": $raw',
      );
    }
    return NativeFolderPick(path: path, bookmark: bookmark);
  }

  /// Lists the immediate `.md` / `.markdown` children and
  /// subdirectories of the bookmarked folder. When [subPath] is
  /// non-null it must be inside the bookmarked tree.
  Future<List<NativeFolderEntry>> listDirectory(
    String bookmark, {
    String? subPath,
  }) async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'listDirectory',
        <String, dynamic>{
          'bookmark': bookmark,
          if (subPath != null) 'subPath': subPath,
        },
      );
      return _decodeEntries(raw);
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  /// Walks the full tree rooted at the bookmarked folder and
  /// returns every markdown leaf as a flat list. Used by the
  /// folder body's search mode.
  Future<List<NativeFolderEntry>> listDirectoryRecursive(
    String bookmark,
  ) async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'listDirectoryRecursive',
        <String, dynamic>{'bookmark': bookmark},
      );
      return _decodeEntries(raw);
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  /// Reads the bytes of [path], which must live inside the tree
  /// identified by [bookmark].
  Future<Uint8List> readFileBytes({
    required String bookmark,
    required String path,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Uint8List>(
        'readFileBytes',
        <String, dynamic>{'bookmark': bookmark, 'path': path},
      );
      if (raw == null) {
        throw const NativeFolderBookmarkStaleException(
          'native channel returned null bytes',
        );
      }
      return raw;
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  List<NativeFolderEntry> _decodeEntries(List<dynamic>? raw) {
    if (raw == null) return const <NativeFolderEntry>[];
    return raw.whereType<Map<dynamic, dynamic>>().map((entry) {
      return NativeFolderEntry(
        path: entry['path'] as String,
        name: entry['name'] as String,
        isDirectory: entry['isDirectory'] as bool? ?? false,
      );
    }).toList();
  }

  Exception _mapError(PlatformException error) {
    switch (error.code) {
      case 'BOOKMARK_STALE':
        // iOS hands a freshly-minted `.withSecurityScope` bookmark back
        // in `details` so the caller can persist and retry without
        // re-prompting. Android has no equivalent — tree URIs do not
        // go stale and the same exception type is reused for parity.
        return NativeFolderBookmarkStaleException(
          error.message ?? '',
          refreshedBookmark: error.details as String?,
        );
      case 'ACCESS_DENIED':
        return NativeFolderAccessDeniedException(error.message ?? '');
      default:
        return Exception(
          '${error.code}: ${error.message ?? 'unknown native error'}',
        );
    }
  }
}
