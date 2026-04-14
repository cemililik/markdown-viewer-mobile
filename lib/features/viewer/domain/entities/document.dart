import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';

/// A stable identifier for a loaded [Document].
///
/// Currently the absolute file system path is used as the id. The type
/// is a zero-overhead Dart 3 extension type so callers cannot pass a
/// bare [String] by mistake — the signature of
/// `DocumentRepository.load` explicitly requires a [DocumentId].
extension type const DocumentId(String value) {}

/// A single heading extracted from a parsed markdown document. Used to
/// build the table of contents, to jump to anchors, and to compute the
/// reading outline shown in the viewer drawer.
@freezed
abstract class HeadingRef with _$HeadingRef {
  const factory HeadingRef({
    /// Heading level in the range `[1, 6]` inclusive, matching the
    /// underlying markdown `#`–`######` syntax.
    required int level,

    /// Plain-text content of the heading with inline markup stripped.
    required String text,

    /// URL-safe slug used as the anchor target. Produced by
    /// lowercasing [text] and collapsing runs of non-word characters.
    required String anchor,

    /// Zero-based index of the top-level markdown block that
    /// contains this heading. Used by the TOC drawer to look up
    /// a widget-side `GlobalKey` and drive
    /// `Scrollable.ensureVisible` without measuring offsets by
    /// hand. When a heading appears nested inside a container
    /// block (blockquote, list item, admonition), this is the
    /// index of that top-level container — scrolling to the
    /// container is close enough for the reader to find the
    /// heading.
    required int blockIndex,
  }) = _HeadingRef;
}

/// Immutable, parsed representation of a markdown document the app has
/// loaded from disk.
///
/// The full source string is retained so that the rendering layer
/// (`markdown_widget`) can re-parse it directly — the domain does not
/// attempt to own a second parallel AST. [headings] and basic metadata
/// are extracted eagerly during the load so the application layer can
/// build a TOC and make decisions without re-parsing.
@freezed
abstract class Document with _$Document {
  const factory Document({
    /// Stable identifier for this document (currently the file path).
    required DocumentId id,

    /// Original markdown source exactly as read from disk, after UTF-8
    /// decoding. Never mutated.
    required String source,

    /// Headings in document order. Empty for documents without any.
    required List<HeadingRef> headings,

    /// Number of newline-terminated lines in [source]. Used for
    /// display (e.g. "10k lines") and for the isolate-offload threshold.
    required int lineCount,

    /// Byte length of the original file on disk, before UTF-8 decoding.
    required int byteSize,

    /// Number of top-level markdown blocks the parser produced.
    /// Used by the viewer to assign one `GlobalKey` per block and
    /// by the TOC drawer + in-doc search to `Scrollable.ensureVisible`
    /// the correct block without pixel measuring.
    ///
    /// When the render layer's widget count disagrees with this
    /// number the viewer falls back to approximate fraction-based
    /// scrolling rather than crashing — a regression in
    /// `markdown_widget`'s block count per render would silently
    /// produce a degraded TOC, not a broken viewer.
    required int topLevelBlockCount,
  }) = _Document;
}
