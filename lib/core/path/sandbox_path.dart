import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Translates filesystem paths between an absolute form (what
/// `dart:io` needs to open the file) and a portable form that
/// survives a container-UUID change.
///
/// ## Why this exists
///
/// On iOS every fresh install from Xcode assigns the app a new
/// container UUID. The same file that used to live at
/// `/var/mobile/Containers/Data/Application/<UUID-A>/Documents/foo.md`
/// is now at `/var/mobile/Containers/Data/Application/<UUID-B>/...`.
/// If we stored the absolute path in SharedPreferences, every
/// reference becomes stale on the next dev build — recents show
/// tiles, tapping them says "file no longer available".
///
/// App Store and TestFlight updates do NOT change the container
/// UUID, so **end users never hit this**. But it makes debugging
/// painful and would trip the same bug if a user ever uninstalled
/// and reinstalled.
///
/// Android has a similar concept (app data directory changes on
/// clear-data / reinstall) so the same indirection applies there.
///
/// ## Contract
///
/// * [initialize] must be called exactly once during app startup,
///   before any store reads or writes.
/// * [toPortable] accepts an absolute path and returns a
///   `sandbox:<kind>:<relative>` token if the path sits inside one
///   of the app's own directories. Paths outside the sandbox
///   (e.g. iCloud Drive, SAF content URIs) passthrough unchanged.
/// * [fromPortable] reverses the mapping. Anything that does not
///   start with `sandbox:` is returned unchanged.
///
/// ## Storage compatibility
///
/// Existing persisted entries written as absolute paths still
/// decode correctly — [fromPortable] just passes them through. On
/// the next successful open the store re-writes them in portable
/// form, so the population migrates over time without a
/// one-shot upgrade step.
final class SandboxPath {
  SandboxPath._();

  static String? _documents;
  static String? _cache;
  static String? _support;

  /// Caches the three sandbox roots so later sync calls do not
  /// await disk.
  static Future<void> initialize() async {
    _documents = (await getApplicationDocumentsDirectory()).path;
    _cache = (await getApplicationCacheDirectory()).path;
    // Not every platform exposes Application Support; ignore the
    // failure and leave `_support` null.
    try {
      _support = (await getApplicationSupportDirectory()).path;
    } on Object {
      _support = null;
    }
  }

  /// Test-only seam — inject fake roots so unit tests do not need
  /// a real filesystem.
  static void debugSetRoots({
    String? documents,
    String? cache,
    String? support,
  }) {
    _documents = documents;
    _cache = cache;
    _support = support;
  }

  /// Converts [absolute] to a portable form when the path sits
  /// inside one of the app's own sandbox directories. Other
  /// paths — including SAF content URIs on Android that are not
  /// filesystem paths — passthrough unchanged.
  static String toPortable(String absolute) {
    final match = _matchRoot(absolute);
    if (match == null) return absolute;
    final (kind, root) = match;
    // +1 for the path separator between the root and the relative
    // remainder. `Platform.pathSeparator` keeps this correct when
    // the codebase ever runs outside iOS/Android.
    final relative = absolute.substring(root.length + 1);
    return 'sandbox:$kind:$relative';
  }

  /// Resolves a portable path back to its current absolute form.
  /// Returns [portable] unchanged when it is not a `sandbox:` URI
  /// or when the sandbox roots have not been initialized yet.
  static String fromPortable(String portable) {
    if (!portable.startsWith('sandbox:')) return portable;
    final firstColon = portable.indexOf(':');
    final secondColon = portable.indexOf(':', firstColon + 1);
    if (secondColon < 0) return portable;
    final kind = portable.substring(firstColon + 1, secondColon);
    final relative = portable.substring(secondColon + 1);
    final root = _rootFor(kind);
    if (root == null) return portable;
    return '$root${Platform.pathSeparator}$relative';
  }

  static (String, String)? _matchRoot(String path) {
    final candidates = <(String, String?)>[
      ('docs', _documents),
      ('cache', _cache),
      ('support', _support),
    ];
    for (final (kind, root) in candidates) {
      if (root == null) continue;
      if (path == root) return (kind, root);
      if (path.startsWith('$root${Platform.pathSeparator}')) {
        return (kind, root);
      }
    }
    return null;
  }

  static String? _rootFor(String kind) {
    switch (kind) {
      case 'docs':
        return _documents;
      case 'cache':
        return _cache;
      case 'support':
        return _support;
      default:
        return null;
    }
  }
}
