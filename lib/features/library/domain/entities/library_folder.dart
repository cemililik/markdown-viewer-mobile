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
}
