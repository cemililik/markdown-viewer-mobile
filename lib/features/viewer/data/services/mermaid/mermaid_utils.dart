/// Returns the byte index just past the closing `---` (or `...`) and its
/// trailing newline of a leading YAML frontmatter block, or `null` when
/// [source] has no frontmatter.
///
/// Recognises the canonical mermaid frontmatter shape:
/// ```
/// ---
/// key: value
/// ---        ← or ...
/// <diagram body>
/// ```
/// The opener must be the literal `---` at offset 0 (optionally followed by
/// whitespace before the newline). The closer is the first subsequent line
/// whose trimmed content equals `---` or `...`.
int? frontmatterEndIndex(String source) {
  if (!source.startsWith('---')) {
    return null;
  }
  final firstNewline = source.indexOf('\n');
  if (firstNewline < 0 || firstNewline > 32) {
    return null;
  }
  final openerLine = source.substring(0, firstNewline).trimRight();
  if (openerLine != '---') {
    return null;
  }
  var cursor = firstNewline + 1;
  while (cursor < source.length) {
    final nextNewline = source.indexOf('\n', cursor);
    final lineEnd = nextNewline < 0 ? source.length : nextNewline;
    final line = source.substring(cursor, lineEnd).trimRight();
    if (line == '---' || line == '...') {
      return nextNewline < 0 ? source.length : nextNewline + 1;
    }
    if (nextNewline < 0) break;
    cursor = nextNewline + 1;
  }
  return null;
}

/// Coerces a JSON-bridged number into a positive [double].
///
/// The `flutter_inappwebview` bridge sometimes delivers integers as
/// [int] and decimals as [double]; both cases are accepted. Returns
/// `null` for anything that is not a finite positive number.
double? asPositiveDouble(Object? raw) {
  if (raw is num) {
    final value = raw.toDouble();
    if (value > 0 && value.isFinite) {
      return value;
    }
  }
  return null;
}
