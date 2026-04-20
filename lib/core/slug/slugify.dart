/// GitHub-style anchor-slug algorithm used both by the parser when
/// it stamps each [HeadingRef] and by the link handler when it
/// normalises a user-typed href for lookup.
///
/// The pipeline:
///
/// 1. Lowercase the entire string.
/// 2. Strip every character that is not a letter, digit, whitespace,
///    underscore, or hyphen (Unicode-aware — Turkish, CJK, and
///    emoji-free text all survive). Underscores are KEPT to match
///    GitHub's GFM anchor algorithm — `## snake_case_heading` maps
///    to `#snake_case_heading` on github.com, and stripping
///    underscores here would break every intra-repo anchor link.
///    Reference: code-review CR-20260419-028.
/// 3. Collapse runs of whitespace into a single hyphen.
/// 4. Collapse runs of hyphens into a single hyphen.
/// 5. Trim leading / trailing hyphens.
/// 6. Return `'section'` when the result is empty — prevents a
///    heading made of only stripped characters (e.g. `## —`) from
///    producing an empty anchor.
///
/// Kept as a top-level function (not tied to a class) so the
/// parser and the anchor resolver can share the exact same slug
/// rules without one pulling the other's import graph along.
String slugify(String text) {
  final lower = text.toLowerCase();
  final stripped = lower.replaceAll(
    RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true),
    '',
  );
  final collapsed = stripped.replaceAll(RegExp(r'\s+'), '-');
  final deduped = collapsed.replaceAll(RegExp('-+'), '-');
  final trimmed = deduped.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'section' : trimmed;
}
