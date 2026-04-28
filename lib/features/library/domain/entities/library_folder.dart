import 'package:path/path.dart' as p;

/// A directory the user has added to the library so they can
/// browse its markdown files inside the app.
///
/// [path] is an opaque, platform-specific location string used as
/// the dedupe key for the folder list. [bookmark] is a
/// base64-encoded platform blob required on iOS to re-establish
/// access across process boundaries; `null` on other platforms.
final class LibraryFolder {
  const LibraryFolder({
    required this.path,
    required this.addedAt,
    this.bookmark,
    this.customName,
  });

  /// Opaque platform-specific location string. Used as the
  /// identity key for deduplication; do not pass directly to
  /// `dart:io` — the data layer routes access through the
  /// appropriate channel.
  final String path;

  /// Wall-clock instant the user added this folder. The
  /// application-layer controller sorts on this field
  /// (most-recent first).
  final DateTime addedAt;

  /// Base64-encoded platform bookmark blob. Opaque to the domain
  /// layer; required on iOS for cross-process folder access,
  /// `null` on all other platforms.
  final String? bookmark;

  /// Optional user-supplied display label. When non-null and
  /// non-empty, [displayName] returns this instead of the path
  /// basename so a long Documents-Provider URI can be shortened
  /// to a readable label in the drawer.
  final String? customName;

  /// Human-readable label shown in the drawer and source picker.
  /// Returns the trimmed [customName] when set; otherwise falls
  /// back to the path basename, and finally to the full [path]
  /// when no basename can be derived (e.g. SAF tree URIs whose
  /// `lastPathSegment` is empty).
  String get displayName {
    final override = customName?.trim();
    if (override != null && override.isNotEmpty) return override;
    final basename = p.basename(path);
    if (basename.isNotEmpty) return basename;
    return path;
  }

  /// Returns a copy with one or more fields replaced. Field
  /// arguments default to a sentinel so `null` can be passed
  /// explicitly to clear a value (used by `rename` to reset
  /// [customName] back to "no override"). [bookmark] follows the
  /// same convention.
  LibraryFolder copyWith({
    String? path,
    DateTime? addedAt,
    Object? bookmark = _unset,
    Object? customName = _unset,
  }) {
    return LibraryFolder(
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      bookmark:
          identical(bookmark, _unset) ? this.bookmark : bookmark as String?,
      customName:
          identical(customName, _unset)
              ? this.customName
              : customName as String?,
    );
  }
}

/// Sentinel for [LibraryFolder.copyWith] so callers can distinguish
/// "leave unchanged" from "explicitly null".
const Object _unset = Object();
