import 'package:flutter/services.dart';
import 'package:markdown_viewer/features/library/domain/services/native_library_folders_channel.dart';

export 'package:markdown_viewer/features/library/domain/services/native_library_folders_channel.dart'
    show
        NativeFolderPick,
        NativeFolderEntry,
        NativeFolderBookmarkStaleException,
        NativeFolderAccessDeniedException;

/// Dart-side wrapper around the `dev.markdownviewer/library_folders`
/// method channel. Deserializes payloads into typed objects and maps
/// platform error codes to sentinel exception types.
///
/// Implements [NativeLibraryFoldersChannel] so the application-layer
/// provider can depend on the port instead of this concrete class —
/// see [docs/standards/architecture-standards.md] for the layer rule
/// this indirection satisfies.
class NativeLibraryFoldersChannelImpl implements NativeLibraryFoldersChannel {
  NativeLibraryFoldersChannelImpl({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('dev.markdownviewer/library_folders');

  final MethodChannel _channel;

  @override
  Future<NativeFolderPick?> pickDirectory() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'pickDirectory',
    );
    if (raw == null) return null;
    final path = raw['path'] as String?;
    final bookmark = raw['bookmark'] as String?;
    if (path == null || bookmark == null) {
      // Interpolate only the top-level keys of the payload — not
      // the payload itself. A future native-side regression could
      // accidentally include a bookmark blob or full filesystem
      // path in a miss-shaped reply, and that blob would then
      // propagate into log / Sentry entries through the exception
      // message. Reference: security-review SR-20260419-043.
      throw FormatException(
        'pickDirectory: native payload missing required keys '
        '"path" or "bookmark"; keys present: ${raw.keys.toList()}',
      );
    }
    return NativeFolderPick(path: path, bookmark: bookmark);
  }

  @override
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

  @override
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

  @override
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
