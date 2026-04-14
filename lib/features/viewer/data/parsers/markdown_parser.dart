import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Parses raw markdown bytes into a [Document].
///
/// The parser is intentionally stateless and dependency-free so it can
/// run inside a background isolate via `compute()` when the source is
/// larger than the threshold defined in the rendering pipeline.
///
/// Only the headings are extracted up front — the full AST is re-parsed
/// lazily by `markdown_widget` when the document is rendered, so the
/// domain layer does not try to own a second parallel tree.
final class MarkdownParser {
  const MarkdownParser();

  /// Decodes [bytes] as UTF-8, parses the source with GitHub-flavoured
  /// markdown extensions enabled, and returns a [Document] with
  /// extracted metadata. [id] becomes the new document's identifier.
  ///
  /// Throws [FormatException] if [bytes] are not valid UTF-8; the
  /// repository layer converts that into a `ParseFailure` before the
  /// exception reaches application code.
  Document parse({required DocumentId id, required List<int> bytes}) {
    final source = _decode(bytes);
    final parsed = _parseStructure(source);
    return Document(
      id: id,
      source: source,
      headings: parsed.headings,
      lineCount: _countLines(source),
      byteSize: bytes.length,
      topLevelBlockCount: parsed.topLevelBlockCount,
    );
  }

  String _decode(List<int> bytes) {
    // Strip a leading UTF-8 BOM if present so it does not leak into
    // the first heading or paragraph. `Utf8Decoder.convert` accepts a
    // start offset, which lets us skip the 3 BOM bytes without
    // allocating a copy of the backing byte array — important for
    // large files where `bytes.sublist(3)` would double peak memory.
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return const Utf8Decoder().convert(bytes, 3);
    }
    return utf8.decode(bytes);
  }

  int _countLines(String source) {
    if (source.isEmpty) {
      return 0;
    }
    return '\n'.allMatches(source).length + (source.endsWith('\n') ? 0 : 1);
  }

  _ParsedStructure _parseStructure(String source) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: true,
    );
    final nodes = document.parseLines(const LineSplitter().convert(source));
    final out = <HeadingRef>[];
    final seenAnchors = <String, int>{};
    // Walk top-level blocks once and, for every heading found
    // (either the block itself or nested inside a container),
    // stamp the outer top-level index. The TOC drawer uses this
    // index to look up a `GlobalKey` on the rendered widget and
    // drive `Scrollable.ensureVisible`.
    for (var i = 0; i < nodes.length; i += 1) {
      final node = nodes[i];
      if (node is! md.Element) continue;
      _walkForHeadings(
        nodes: [node],
        blockIndex: i,
        out: out,
        seenAnchors: seenAnchors,
      );
    }
    return _ParsedStructure(
      headings: List.unmodifiable(out),
      topLevelBlockCount: nodes.length,
    );
  }

  /// Depth-first walk that collects heading elements from anywhere in
  /// the parsed AST, not just top-level nodes. Headings can legally
  /// appear inside blockquotes, list items, and other container blocks;
  /// a top-level-only scan would silently drop them from the TOC.
  ///
  /// Every heading found is stamped with [blockIndex] — the index of
  /// the enclosing top-level block — so the viewer can map from
  /// `HeadingRef` back to a widget key on the render side.
  void _walkForHeadings({
    required List<md.Node> nodes,
    required int blockIndex,
    required List<HeadingRef> out,
    required Map<String, int> seenAnchors,
  }) {
    for (final node in nodes) {
      if (node is! md.Element) {
        continue;
      }
      final level = _headingLevel(node.tag);
      if (level != null) {
        final text = _plainText(node);
        if (text.isNotEmpty) {
          final anchor = _uniqueAnchor(text, seenAnchors);
          out.add(
            HeadingRef(
              level: level,
              text: text,
              anchor: anchor,
              blockIndex: blockIndex,
            ),
          );
        }
      }
      final children = node.children;
      if (children != null && children.isNotEmpty) {
        _walkForHeadings(
          nodes: children,
          blockIndex: blockIndex,
          out: out,
          seenAnchors: seenAnchors,
        );
      }
    }
  }

  int? _headingLevel(String tag) {
    if (tag.length != 2 || tag[0] != 'h') {
      return null;
    }
    final level = int.tryParse(tag[1]);
    if (level == null || level < 1 || level > 6) {
      return null;
    }
    return level;
  }

  String _plainText(md.Node node) {
    final buffer = StringBuffer();
    _collectText(node, buffer);
    return buffer.toString().trim();
  }

  void _collectText(md.Node node, StringBuffer buffer) {
    if (node is md.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is md.Element) {
      final children = node.children;
      if (children == null) {
        return;
      }
      for (final child in children) {
        _collectText(child, buffer);
      }
    }
  }

  /// Produces a GitHub-style anchor slug from [text] and disambiguates
  /// duplicates within the same document by appending `-1`, `-2`, etc.
  String _uniqueAnchor(String text, Map<String, int> seen) {
    final base = _slug(text);
    final count = seen[base] ?? 0;
    seen[base] = count + 1;
    if (count == 0) {
      return base;
    }
    return '$base-$count';
  }

  String _slug(String text) {
    final lower = text.toLowerCase();
    final stripped = lower.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s-]', unicode: true),
      '',
    );
    final collapsed = stripped.replaceAll(RegExp(r'\s+'), '-');
    final deduped = collapsed.replaceAll(RegExp('-+'), '-');
    final trimmed = deduped.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'section' : trimmed;
  }
}

/// Internal tuple returned by [MarkdownParser._parseStructure] so
/// the public [MarkdownParser.parse] method stays a single AST
/// walk — one pass collects headings with their enclosing block
/// index AND the top-level block count used by the viewer to
/// wire its per-block `GlobalKey`s.
class _ParsedStructure {
  const _ParsedStructure({
    required this.headings,
    required this.topLevelBlockCount,
  });

  final List<HeadingRef> headings;
  final int topLevelBlockCount;
}
