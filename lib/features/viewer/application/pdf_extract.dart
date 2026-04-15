import 'package:markdown/markdown.dart' as md;

/// Returns the text of the first H1 heading in [source], cleaned and
/// ready to use as a PDF filename or display title. Falls back to
/// [fallback] when the document has no H1.
///
/// Note: calling this function and then [exportToPdf] parses the markdown
/// source twice. Avoid when performance matters.
String extractPdfTitle(String source, String fallback) {
  final ast = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(source.split('\n'));
  return _firstH1(ast) ?? fallback;
}

/// Returns the trimmed source of every mermaid fenced code block in
/// [source], in document order, without duplicates.
///
/// The returned strings are the exact look-up keys that [exportToPdf]
/// uses in [mermaidImages], so callers can pre-render the diagrams via
/// [MermaidRenderer] and pass the result map in without any key
/// mismatch — both sides go through the same extraction path: parse,
/// extract text, decode HTML entities, trim.
List<String> extractMermaidCodes(String source) {
  final ast = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(source.split('\n'));
  final codes = <String>[];
  final seen = <String>{};
  for (final node in ast) {
    if (node is! md.Element || node.tag != 'pre') continue;
    final codeEl = node.children?.whereType<md.Element>().firstOrNull;
    final lang =
        codeEl?.attributes['class']?.replaceFirst('language-', '') ?? '';
    if (lang != 'mermaid') continue;
    final code = _mermaidCodeFromPre(node);
    if (code.isNotEmpty && seen.add(code)) codes.add(code);
  }
  return codes;
}

// ── Private helpers ────────────────────────────────────────────────────

String? _firstH1(List<md.Node> ast) {
  for (final node in ast) {
    if (node is md.Element && node.tag == 'h1') {
      final text = _extractText(node).trim();
      return text.isEmpty ? null : text;
    }
  }
  return null;
}

String _mermaidCodeFromPre(md.Element preNode) {
  return _decodeMermaidHtmlEntities(_extractText(preNode)).trim();
}

String _extractText(md.Node node) {
  if (node is md.Text) return node.text;
  if (node is md.Element) {
    return (node.children ?? []).map(_extractText).join();
  }
  return '';
}

/// Decodes HTML entities introduced by the markdown parser inside fenced
/// code block text. Order matters: &amp; must be decoded LAST to avoid
/// double-decoding (e.g. `&amp;lt;` → `&lt;`, not `<`).
String _decodeMermaidHtmlEntities(String text) {
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
