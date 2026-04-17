/// Extracts a short plain-text preview from a markdown document's
/// raw source, suitable for the subtitle line of a recent-document
/// tile on the library home screen.
///
/// The goal is a single-line hint that conveys what the document
/// talks about, not a faithful rendering — we deliberately strip
/// every piece of inline markup, skip every heading / code fence /
/// blockquote so the reader sees the actual prose. If the document
/// has no prose at all (only headings, only fenced code, empty
/// file) the extractor returns `null` and the tile falls back to
/// its parent-folder + relative-time subtitle.
///
/// The extractor runs on the full source on every viewer load,
/// which is cheap: it walks each line once, stops as soon as it
/// finds a usable paragraph, and caps the collected text at
/// [_maxPreviewLength] characters. YAML frontmatter at the very
/// top of the file (opens on a `---` line, closes on the matching
/// `---`) is also skipped so a metadata block does not become the
/// preview.
String? extractPreviewSnippet(String source, {int maxPreviewLength = 140}) {
  if (source.isEmpty) {
    return null;
  }
  final lines = source.split('\n');
  final buffer = StringBuffer();

  var index = 0;
  // Skip a leading YAML frontmatter block so a `title: ...` line
  // does not end up as the document preview. Frontmatter must
  // start on the very first line per the CommonMark + `markdown`
  // package convention.
  if (index < lines.length && lines[index].trim() == '---') {
    var end = index + 1;
    while (end < lines.length && lines[end].trim() != '---') {
      end += 1;
    }
    if (end < lines.length) {
      index = end + 1;
    }
  }

  var inFence = false;
  for (; index < lines.length; index += 1) {
    final raw = lines[index];
    final trimmed = raw.trimLeft();

    // Fenced code block state machine. A line that starts with
    // ``` (with any number of backticks >= 3) toggles the fence
    // flag; contents of the fence are ignored entirely.
    if (_isCodeFence(trimmed)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    // Blank lines act as paragraph separators. If we already have
    // some text, a blank line ends the current paragraph and the
    // collected text is the preview.
    if (trimmed.isEmpty) {
      if (buffer.isNotEmpty) break;
      continue;
    }

    // Skip structural lines that never carry prose: ATX headings,
    // setext underlines, horizontal rules, HTML comments, raw
    // HTML blocks, and list markers / blockquote markers that
    // would only leave sentence fragments once stripped.
    if (_isStructuralLine(trimmed)) continue;

    final cleaned = _stripInlineMarkup(trimmed);
    if (cleaned.isEmpty) continue;

    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(cleaned);
    if (buffer.length >= maxPreviewLength) break;
  }

  if (buffer.isEmpty) return null;

  var preview = buffer.toString().trim();
  if (preview.length > maxPreviewLength) {
    preview = '${preview.substring(0, maxPreviewLength).trimRight()}…';
  }
  return preview;
}

bool _isCodeFence(String trimmed) {
  if (trimmed.startsWith('```')) return true;
  if (trimmed.startsWith('~~~')) return true;
  return false;
}

bool _isStructuralLine(String trimmed) {
  if (trimmed.startsWith('#')) return true;
  if (trimmed.startsWith('>')) return true;
  if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) return true;
  if (trimmed.startsWith('+ ')) return true;
  if (trimmed.startsWith('<!--')) return true;
  if (trimmed.startsWith('<') && trimmed.endsWith('>')) return true;
  if (_horizontalRule.hasMatch(trimmed)) return true;
  if (_setextUnderline.hasMatch(trimmed)) return true;
  if (_orderedListMarker.hasMatch(trimmed)) return true;
  return false;
}

/// Strips the inline markdown markup that would otherwise show up
/// as literal `*`, `_`, `` ` `` or `[text](url)` characters in the
/// preview. We do not try to be a complete CommonMark parser — a
/// handful of regexes covers 99% of real-world documents and the
/// failure mode is a slightly noisy preview, not a crash.
String _stripInlineMarkup(String line) {
  var text = line;
  // Inline images: ![alt](url) → alt
  text = text.replaceAllMapped(_imageLink, (m) => m.group(1) ?? '');
  // Links: [text](url) → text
  text = text.replaceAllMapped(_link, (m) => m.group(1) ?? '');
  // Inline code: `code` → code
  text = text.replaceAllMapped(_inlineCode, (m) => m.group(1) ?? '');
  // Bold / italic / strike markers — strip the delimiters, keep
  // the payload. The order matters: ** before *, __ before _.
  text = text.replaceAll(_bold, '').replaceAll(_italic, '');
  text = text.replaceAll(_strike, '');
  // Collapse any run of whitespace (including tabs) to a single
  // space so a preview reads like one continuous sentence.
  text = text.replaceAll(_anyWhitespace, ' ').trim();
  return text;
}

final RegExp _horizontalRule = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})\s*$');
// CommonMark setext underlines require at least two `=` or `-` characters
// on their own line; anything shorter is prose (e.g. an em-dash written
// as `--` at the start of a sentence, or a `--help` flag reference).
final RegExp _setextUnderline = RegExp(r'^(?:={2,}|-{2,})\s*$');
final RegExp _orderedListMarker = RegExp(r'^\d+[.)]\s');
final RegExp _imageLink = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final RegExp _link = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final RegExp _inlineCode = RegExp('`([^`]+)`');
final RegExp _bold = RegExp('\\*\\*|__');
// Italic delimiters. Three alternatives:
//
// 1. `(?<!\*)\*(?!\*)` — a single `*` not part of `**`. Asterisks
//    are never valid inside identifiers so a simple symmetric check
//    is enough.
//
// 2. `(?<![A-Za-z0-9])_(?!_)` — an underscore opener: preceded by a
//    non-alphanumeric (or start-of-string) and not followed by
//    another `_`. This matches the `_` in ` _italic_` but rejects
//    the `_` in `snake_case` (preceded by `e`, which is
//    alphanumeric).
//
// 3. `(?<!_)_(?![A-Za-z0-9])` — an underscore closer: followed by
//    a non-alphanumeric (or end-of-string) and not preceded by
//    another `_`. This matches the trailing `_` of `_italic_` but
//    rejects the `_` in `my_var_name` at each intra-word position.
//
// CommonMark treats intra-word `_` as literal for exactly this
// reason; mirroring it here lets the preview stay readable.
final RegExp _italic = RegExp(
  r'(?<!\*)\*(?!\*)|(?<![A-Za-z0-9])_(?!_)|(?<!_)_(?![A-Za-z0-9])',
);
final RegExp _strike = RegExp('~~');
final RegExp _anyWhitespace = RegExp(r'\s+');
