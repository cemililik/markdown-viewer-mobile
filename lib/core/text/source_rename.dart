/// Hard cap on a user-supplied custom source label. 64 codepoints
/// covers comfortably the longest readable display the library
/// drawer / AppBar can fit on a phone without ellipsis, and matches
/// typical filename / Git ref length caps. Enforced both at the
/// rename-dialog input (`maxLength` on the `TextField`) and in the
/// application-layer rename use-cases so a non-UI caller cannot
/// bypass it.
const int sourceRenameMaxLength = 64;

/// Normalises a raw rename input into the canonical persisted form:
/// trims surrounding whitespace, returns `null` for empty / pure-
/// whitespace input (the "clear the override" sentinel), and
/// truncates anything past [sourceRenameMaxLength] codepoints to
/// match the input cap.
///
/// Centralised in `core/` so the presentation layer (rename dialog),
/// the library application layer (`LibraryFoldersController.rename`),
/// and the repo-sync data layer (`SyncedReposStoreImpl.rename`) all
/// share the same rules without crossing layer boundaries.
String? normaliseRenameInput(String? raw) {
  if (raw == null) return null;
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.runes.length > sourceRenameMaxLength) {
    trimmed =
        String.fromCharCodes(
          trimmed.runes.take(sourceRenameMaxLength),
        ).trimRight();
    if (trimmed.isEmpty) return null;
  }
  return trimmed;
}
