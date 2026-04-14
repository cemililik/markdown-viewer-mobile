import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
  // Run the fallback through the same cleaning path that _firstH1 applies to
  // heading text so the output is always Latin-1 safe and entity-free.
  return _firstH1(ast) ?? _cleanText(fallback);
}

/// Converts a markdown document to a PDF byte array.
///
/// The markdown source is parsed with the same GitHub-Flavored Markdown
/// extension set used by the viewer so headings, fenced code, tables,
/// and strikethrough are all handled. Mermaid diagram fences are
/// rendered as a labelled placeholder box — rasterising an SVG inside a
/// PDF requires a WebView round-trip and is out of scope for v1.
///
/// [title] is used as the PDF document metadata title and as the header
/// on page 1. If the document's first node is an H1 heading, that text
/// is used as the display title instead of [title], so the header always
/// shows the document's own heading rather than a filename.
///
/// ### Supported elements
/// H1-H6 · paragraphs · **bold** · _italic_ · `inline code` · fenced
/// code blocks · unordered and ordered lists (1 level deep) · block
/// quotes · horizontal rules · tables (equal-width columns)
///
/// ### Unsupported elements (skipped silently)
/// Images · raw HTML · mermaid/LaTeX fences (shown as placeholder)
Future<Uint8List> exportToPdf(String title, String source) async {
  final ast = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(source.split('\n'));

  // Prefer the document's own H1 as the display title so that files with
  // GUID or hash-based filenames still show a meaningful header in the PDF.
  final displayTitle = _firstH1(ast) ?? title;

  final regular = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final italic = pw.Font.helveticaOblique();
  final boldItalic = pw.Font.helveticaBoldOblique();
  final mono = pw.Font.courier();

  final _Fonts fonts = _Fonts(
    regular: regular,
    bold: bold,
    italic: italic,
    boldItalic: boldItalic,
    mono: mono,
  );

  final doc = pw.Document(title: title, author: 'Markdown Viewer');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      theme: pw.ThemeData(
        defaultTextStyle: pw.TextStyle(
          font: regular,
          fontSize: 11,
          lineSpacing: 1.4,
          color: PdfColors.grey900,
        ),
      ),
      header:
          (context) =>
              context.pageNumber == 1
                  ? _buildTitle(displayTitle, fonts)
                  : pw.SizedBox(),
      build: (context) => _buildNodes(ast, fonts),
    ),
  );

  return doc.save();
}

// ── Fonts container ───────────────────────────────────────────────────

class _Fonts {
  const _Fonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    required this.mono,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;
  final pw.Font mono;
}

// ── Title widget ──────────────────────────────────────────────────────

pw.Widget _buildTitle(String title, _Fonts f) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          font: f.bold,
          fontSize: 22,
          color: PdfColors.grey900,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      pw.SizedBox(height: 8),
    ],
  );
}

// ── Top-level node list ───────────────────────────────────────────────

List<pw.Widget> _buildNodes(List<md.Node> nodes, _Fonts f) {
  final widgets = <pw.Widget>[];
  for (final node in nodes) {
    final w = _buildNode(node, f);
    if (w != null) widgets.add(w);
  }
  return widgets;
}

pw.Widget? _buildNode(md.Node node, _Fonts f) {
  if (node is md.Text) {
    final trimmed = node.text.trim();
    if (trimmed.isEmpty) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        trimmed,
        style: pw.TextStyle(font: f.regular, fontSize: 11),
      ),
    );
  }

  if (node is! md.Element) return null;

  switch (node.tag) {
    case 'h1':
      return _heading(node, f, fontSize: 20, spaceAbove: 16, spaceBelow: 6);
    case 'h2':
      return _heading(node, f, fontSize: 17, spaceAbove: 14, spaceBelow: 4);
    case 'h3':
      return _heading(node, f, fontSize: 14, spaceAbove: 12, spaceBelow: 3);
    case 'h4':
    case 'h5':
    case 'h6':
      return _heading(node, f, fontSize: 12, spaceAbove: 10, spaceBelow: 2);

    case 'p':
      return _paragraph(node, f);

    case 'pre':
      return _codeBlock(node, f);

    case 'blockquote':
      return _blockquote(node, f);

    case 'ul':
      return _list(node, f, ordered: false);

    case 'ol':
      return _list(node, f, ordered: true);

    case 'hr':
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      );

    case 'table':
      return _table(node, f);

    default:
      // Attempt to extract any text children for unknown tags.
      final text = _extractText(node).trim();
      if (text.isEmpty) return null;
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: f.regular, fontSize: 11),
        ),
      );
  }
}

// ── Headings ──────────────────────────────────────────────────────────

pw.Widget _heading(
  md.Element node,
  _Fonts f, {
  required double fontSize,
  required double spaceAbove,
  required double spaceBelow,
}) {
  final text = _cleanText(_extractText(node));
  return pw.Padding(
    padding: pw.EdgeInsets.only(top: spaceAbove, bottom: spaceBelow),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: f.bold,
        fontSize: fontSize,
        color: PdfColors.grey900,
      ),
    ),
  );
}

// ── Paragraphs (inline formatting) ───────────────────────────────────

pw.Widget _paragraph(md.Element node, _Fonts f) {
  final spans = _buildInlineSpans(node.children ?? [], f, baseSize: 11);
  if (spans.isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.RichText(text: pw.TextSpan(children: spans)),
  );
}

List<pw.InlineSpan> _buildInlineSpans(
  List<md.Node> nodes,
  _Fonts f, {
  required double baseSize,
  bool isBold = false,
  bool isItalic = false,
  bool isMono = false,
}) {
  final spans = <pw.InlineSpan>[];
  for (final node in nodes) {
    if (node is md.Text) {
      final text = _cleanText(node.text);
      if (text.isEmpty) continue;
      final font = _resolveFont(
        f,
        bold: isBold,
        italic: isItalic,
        mono: isMono,
      );
      spans.add(
        pw.TextSpan(
          text: text,
          style: pw.TextStyle(
            font: font,
            fontSize: isMono ? baseSize - 1 : baseSize,
            background:
                isMono
                    ? const pw.BoxDecoration(color: PdfColors.grey200)
                    : null,
          ),
        ),
      );
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          spans.addAll(
            _buildInlineSpans(
              node.children ?? [],
              f,
              baseSize: baseSize,
              isBold: true,
              isItalic: isItalic,
              isMono: isMono,
            ),
          );
        case 'em':
          spans.addAll(
            _buildInlineSpans(
              node.children ?? [],
              f,
              baseSize: baseSize,
              isBold: isBold,
              isItalic: true,
              isMono: isMono,
            ),
          );
        case 'code':
          spans.addAll(
            _buildInlineSpans(
              node.children ?? [],
              f,
              baseSize: baseSize,
              isBold: isBold,
              isItalic: isItalic,
              isMono: true,
            ),
          );
        case 'a':
          // Render link text with underline; no live URL in PDF v1.
          final text = _cleanText(_extractText(node));
          spans.add(
            pw.TextSpan(
              text: text,
              style: pw.TextStyle(
                font: f.regular,
                fontSize: baseSize,
                color: PdfColors.blue700,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          );
        case 'del':
          final text = _cleanText(_extractText(node));
          spans.add(
            pw.TextSpan(
              text: text,
              style: pw.TextStyle(
                font: f.regular,
                fontSize: baseSize,
                decoration: pw.TextDecoration.lineThrough,
              ),
            ),
          );
        default:
          spans.addAll(
            _buildInlineSpans(
              node.children ?? [],
              f,
              baseSize: baseSize,
              isBold: isBold,
              isItalic: isItalic,
              isMono: isMono,
            ),
          );
      }
    }
  }
  return spans;
}

pw.Font _resolveFont(
  _Fonts f, {
  required bool bold,
  required bool italic,
  required bool mono,
}) {
  if (mono) return f.mono;
  if (bold && italic) return f.boldItalic;
  if (bold) return f.bold;
  if (italic) return f.italic;
  return f.regular;
}

// ── Code blocks ───────────────────────────────────────────────────────

pw.Widget _codeBlock(md.Element preNode, _Fonts f) {
  // A mermaid fence is useless as raw text in a PDF — show a placeholder.
  final codeEl = preNode.children?.whereType<md.Element>().firstOrNull;
  final lang = codeEl?.attributes['class']?.replaceFirst('language-', '') ?? '';
  final isMermaid = lang == 'mermaid';

  final content =
      isMermaid
          ? '[ Diagram not included in PDF -- open in Markdown Viewer to view ]'
          : _cleanText(_extractText(preNode));

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey400, width: 3),
        ),
      ),
      child: pw.Text(
        content,
        style: pw.TextStyle(
          font: isMermaid ? f.italic : f.mono,
          fontSize: 9.5,
          color: isMermaid ? PdfColors.grey600 : PdfColors.grey900,
        ),
      ),
    ),
  );
}

// ── Block quotes ──────────────────────────────────────────────────────

pw.Widget _blockquote(md.Element node, _Fonts f) {
  final text = _cleanText(_extractText(node)).trim();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey400, width: 3),
        ),
        color: PdfColors.grey50,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: f.italic,
          fontSize: 11,
          color: PdfColors.grey700,
        ),
      ),
    ),
  );
}

// ── Lists ─────────────────────────────────────────────────────────────

pw.Widget _list(md.Element node, _Fonts f, {required bool ordered}) {
  final items = (node.children ?? []).whereType<md.Element>().where(
    (e) => e.tag == 'li',
  );
  final widgets = <pw.Widget>[];
  var index = 1;
  for (final item in items) {
    final bullet = ordered ? '${index++}.' : '•';
    final text = _cleanText(_extractText(item)).trim();
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 16,
              child: pw.Text(
                bullet,
                style: pw.TextStyle(font: f.regular, fontSize: 11),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                text,
                style: pw.TextStyle(font: f.regular, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8, left: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    ),
  );
}

// ── Tables ────────────────────────────────────────────────────────────

pw.Widget _table(md.Element tableNode, _Fonts f) {
  final rows = <pw.TableRow>[];
  for (final section in (tableNode.children ?? []).whereType<md.Element>()) {
    final isHead = section.tag == 'thead';
    for (final tr in (section.children ?? []).whereType<md.Element>()) {
      if (tr.tag != 'tr') continue;
      final cells =
          (tr.children ?? []).whereType<md.Element>().map((cell) {
            final text = _cleanText(_extractText(cell)).trim();
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  font: isHead ? f.bold : f.regular,
                  fontSize: 10,
                ),
              ),
            );
          }).toList();
      rows.add(
        pw.TableRow(
          decoration:
              isHead ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
          children: cells,
        ),
      );
    }
  }

  if (rows.isEmpty) return pw.SizedBox();

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows,
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────

/// Returns the text content of the first H1 node in [ast], or `null`
/// if the document has no H1. Used to build a meaningful PDF header
/// even when the file has a hash-based or generic filename.
String? _firstH1(List<md.Node> ast) {
  for (final node in ast) {
    if (node is md.Element && node.tag == 'h1') {
      final text = _cleanText(_extractText(node)).trim();
      return text.isEmpty ? null : text;
    }
  }
  return null;
}

/// Decodes common HTML entities and replaces characters outside the
/// Latin-1 range supported by the built-in Helvetica/Courier Type 1
/// fonts with visually equivalent ASCII sequences. This avoids missing
/// glyph boxes in the PDF output.
String _cleanText(String text) {
  return text
      // HTML entities
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      // Typographic punctuation
      .replaceAll('\u2014', '--') // em dash
      .replaceAll('\u2013', '-') // en dash
      .replaceAll('\u2018', "'") // left single quote
      .replaceAll('\u2019', "'") // right single quote
      .replaceAll('\u201C', '"') // left double quote
      .replaceAll('\u201D', '"') // right double quote
      .replaceAll('\u2026', '...') // ellipsis
      .replaceAll('\u00A0', ' ') // non-breaking space
      // Arrows
      .replaceAll('\u2192', '->') // ->
      .replaceAll('\u2190', '<-') // <-
      .replaceAll('\u2194', '<->') // <->
      // Misc symbols
      .replaceAll('\u2022', '*') // bullet •
      // Check marks (all variants → [x] / [ ])
      .replaceAll('\u2713', '[x]') // ✓ check mark
      .replaceAll('\u2714', '[x]') // ✔ heavy check mark
      .replaceAll('\u2705', '[x]') // ✅ white heavy check mark (emoji)
      .replaceAll('\u2611', '[x]') // ☑ ballot box with check
      .replaceAll(
        '\u2612',
        '[x]',
      ) // ☒ ballot box with X (often used as "yes" in tables)
      .replaceAll('\u2717', '[ ]') // ✗ ballot x
      .replaceAll('\u2718', '[ ]') // ✘ heavy ballot x
      .replaceAll('\u274C', '[ ]') // ❌ cross mark (emoji)
      .replaceAll('\u274E', '[ ]') // ✎ cross mark ornament
      .replaceAll('\u2610', '[ ]') // ☐ empty ballot box
      // Other common emoji that lack Helvetica glyphs — replace with text
      .replaceAll('\u26A0', '[!]') // ⚠ warning sign
      .replaceAll('\u2139', '[i]') // ℹ information source
      .replaceAll('\u2B50', '*') // ⭐ star
      .replaceAll('\u{1F525}', '[fire]') // 🔥
      // PUA sentinels used by the viewer's search highlight system
      .replaceAll(RegExp('[\uE000-\uE003]'), '');
}

String _extractText(md.Node node) {
  if (node is md.Text) return node.text;
  if (node is md.Element) {
    return (node.children ?? []).map(_extractText).join();
  }
  return '';
}
