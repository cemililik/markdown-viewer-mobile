/// A directory the user has added to the library so they can
/// browse its markdown files inside the app.
///
/// Represented as a plain value type — two fields, no freezed.
/// The store encodes the list as a hand-rolled JSON array so the
/// codegen overhead is unjustified.
///
/// The [path] is an absolute filesystem path on Android and a URL
/// path component on iOS (whatever the platform directory picker
/// returned). The application layer treats it as opaque — only
/// the data layer's enumerator hands it to `dart:io`.
final class LibraryFolder {
  const LibraryFolder({required this.path, required this.addedAt});

  /// Absolute path to the directory the user picked. Used both
  /// as the identity of the entry (dedupe by path) and as the
  /// argument to `Directory(path).list()` when the drawer
  /// expands the entry to show its markdown files.
  final String path;

  /// Wall-clock instant the user added this folder. Sorted on
  /// this field — most recent first — by the application-layer
  /// controller before handing the list to the drawer.
  final DateTime addedAt;
}
