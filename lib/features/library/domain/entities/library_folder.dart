/// A directory the user has added to the library so they can
/// browse its markdown files inside the app.
///
/// Represented as a plain value type — three fields, no freezed.
/// The store encodes the list as a hand-rolled JSON array so the
/// codegen overhead is unjustified.
///
/// The [path] is an absolute filesystem path on Android and a URL
/// path component on iOS (whatever the platform directory picker
/// returned). The application layer treats it as opaque — only
/// the data layer's enumerator hands it to `dart:io` and, on
/// iOS, to the native `LibraryFoldersChannel`.
///
/// On iOS, the system requires a security-scoped bookmark
/// (`NSURL.bookmarkData(options: .minimalBookmark, ...)`) to
/// re-establish access to a picked folder across process
/// boundaries and across cold starts. Without that bookmark,
/// `dart:io` cannot read the folder at all — it raises a
/// `PathAccessException(Permission denied)` on the first
/// `Directory.list()`. The [bookmark] field carries the
/// base64-encoded bookmark blob back to the native channel,
/// which resolves it, claims the security scope, enumerates,
/// and releases the scope for every access. The field is
/// optional because Android and desktop do not need it.
final class LibraryFolder {
  const LibraryFolder({
    required this.path,
    required this.addedAt,
    this.bookmark,
  });

  /// Absolute path to the directory the user picked. Used both
  /// as the identity of the entry (dedupe by path) and, on
  /// non-iOS platforms, as the argument to `Directory(path).list()`
  /// when the drawer expands the entry to show its markdown
  /// files. On iOS this string is display-only — every read
  /// goes through the native channel keyed by [bookmark].
  final String path;

  /// Wall-clock instant the user added this folder. Sorted on
  /// this field — most recent first — by the application-layer
  /// controller before handing the list to the drawer.
  final DateTime addedAt;

  /// Base64-encoded security-scoped bookmark blob produced by
  /// `URL.bookmarkData(options: .minimalBookmark, ...)` on iOS
  /// at pick time. Opaque to Dart — only
  /// `NativeLibraryFoldersChannel` knows how to resolve it
  /// back to a usable URL. `null` on Android / desktop, and
  /// `null` on iOS for folders migrated from the pre-bookmark
  /// schema (which would have failed on every access anyway —
  /// the drawer surfaces that case as "could not read this
  /// folder").
  final String? bookmark;
}
