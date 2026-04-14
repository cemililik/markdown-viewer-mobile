import 'package:flutter/services.dart';

/// The result of a successful native folder pick: both the raw
/// filesystem path (for display) and the base64-encoded security-
/// scoped bookmark (for every subsequent access).
class NativeFolderPick {
  const NativeFolderPick({required this.path, required this.bookmark});

  /// Absolute path on disk of the directory the user picked. Used
  /// exclusively for display and as the dedupe key in the folder
  /// list — it is never handed to `dart:io` because that path is
  /// not readable without the security scope claim that only the
  /// native side can re-establish from the bookmark.
  final String path;

  /// Base64-encoded `Data` blob representing a `.minimalBookmark`
  /// NSURL bookmark. Persisted alongside the folder entry and
  /// passed back to [NativeLibraryFoldersChannel.listDirectory]
  /// every time the drawer or folder body needs to enumerate the
  /// folder. Opaque to Dart — the bytes are meaningful only to
  /// the iOS `URL(resolvingBookmarkData:)` initializer.
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
class NativeFolderBookmarkStaleException implements Exception {
  const NativeFolderBookmarkStaleException(this.message);
  final String message;

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

/// Dart-side wrapper around the iOS `LibraryFoldersChannel`
/// method channel defined in `ios/Runner/LibraryFoldersChannel.swift`.
///
/// Responsibilities:
///
/// - Own the single [MethodChannel] instance shared across the app.
/// - Serialize + deserialize the channel payloads so every other
///   layer works with typed Dart objects instead of raw `Map<String,
///   dynamic>` blobs.
/// - Translate platform `FlutterError` codes into sentinel exception
///   types the folder enumerator and the widget layer can
///   pattern-match against.
///
/// The channel is only available on iOS. Callers decide via
/// `Platform.isIOS` whether to hit the channel or fall back to
/// the dart:io-backed implementation — this class itself does not
/// sniff the platform so it stays cheap to unit test with a fake
/// `MethodChannel` and does not pull `dart:io` into Dart-only
/// layers.
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
    if (path == null || bookmark == null) return null;
    return NativeFolderPick(path: path, bookmark: bookmark);
  }

  /// Enumerates the immediate `.md` / `.markdown` children and
  /// subdirectories of the bookmarked folder.
  ///
  /// When [subPath] is non-null, the native side claims the
  /// security scope from the bookmarked root and then lists
  /// `subPath` — which must sit inside the bookmarked tree — so
  /// the drawer can drill into nested directories without having
  /// to re-bookmark every level. `sub-URLs` inherit the parent's
  /// scope as long as the root scope is active, which is why one
  /// root bookmark covers an arbitrarily deep hierarchy.
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

  /// Reads the contents of [path] (which must live under the
  /// tree the [bookmark] was created against) and returns the
  /// raw bytes. Used by [materializeFolderFile] to copy the
  /// bytes into the app cache so the existing viewer code path
  /// (`File(...).readAsBytes`) can read the document with no
  /// SAF / security-scope awareness of its own.
  ///
  /// On iOS, [path] is the filesystem path returned by the
  /// document picker; on Android, [path] is the stringified
  /// content URI of a child document inside the bookmarked
  /// tree.
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
        return NativeFolderBookmarkStaleException(error.message ?? '');
      case 'ACCESS_DENIED':
        return NativeFolderAccessDeniedException(error.message ?? '');
      default:
        return Exception(
          '${error.code}: ${error.message ?? 'unknown native error'}',
        );
    }
  }
}
