import 'package:path/path.dart' as p;

/// Result of attempting to resolve a schemeless markdown link
/// (e.g. `[API](api.md)` or `[See](../shared/types.md)`) against
/// the currently-open document's location on disk.
class RelativeDocument {
  const RelativeDocument({required this.path, required this.fragment});

  /// Absolute, normalised filesystem path to the target document.
  final String path;

  /// Anchor fragment extracted from the href, *without* the leading
  /// `#`. Empty when the href carried no fragment. The viewer passes
  /// it to [resolveAnchor] once the target document has parsed.
  final String fragment;
}

/// Resolves a schemeless markdown link to a concrete filesystem path
/// so the viewer can open it in a new route stack.
///
/// Returns `null` when the href is not a candidate for relative-file
/// navigation. The caller is responsible for the final `File.existsSync`
/// check — this helper does not touch disk, so it remains unit-testable
/// without a fake filesystem.
///
/// Accepts these shapes:
/// - `api.md` — sibling file in the same directory
/// - `../shared/types.md` — relative path with `..` traversal
/// - `./intro.markdown` — explicit-same-directory prefix
/// - `guide.md#configuration` — file + anchor fragment
///
/// Rejects:
/// - Empty hrefs
/// - Hrefs with a scheme (those go through the scheme allow-list)
/// - Hrefs starting with `#` (pure anchor — caller handles those)
/// - Absolute paths (`/etc/passwd`) — a schemeless absolute href
///   would otherwise escape the document's containing directory
///   and trigger a file read the user never authored
/// - Hrefs whose target extension is not `.md` / `.markdown` —
///   keeps this handler from accidentally producing file paths for
///   non-markdown targets (images, PDFs, arbitrary files)
RelativeDocument? resolveRelativeDocument({
  required String href,
  required String currentDocumentPath,
}) {
  if (href.isEmpty) return null;
  if (href.startsWith('#')) return null;
  if (href.startsWith('/')) return null;

  // Split off a fragment so `guide.md#section` both resolves to
  // `guide.md` and preserves `section` for the destination viewer.
  final hashIndex = href.indexOf('#');
  final filePart = hashIndex < 0 ? href : href.substring(0, hashIndex);
  final fragment = hashIndex < 0 ? '' : href.substring(hashIndex + 1);
  if (filePart.isEmpty) return null;

  final uri = Uri.tryParse(filePart);
  if (uri == null) return null;
  if (uri.scheme.isNotEmpty) return null;

  final lower = filePart.toLowerCase();
  if (!(lower.endsWith('.md') || lower.endsWith('.markdown'))) {
    return null;
  }

  final baseDir = p.dirname(currentDocumentPath);
  final joined = p.join(baseDir, filePart);
  final normalized = p.normalize(joined);

  return RelativeDocument(path: normalized, fragment: fragment);
}
