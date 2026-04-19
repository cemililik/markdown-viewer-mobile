import 'dart:convert';

/// Decodes [bytes] as UTF-8 while stripping a leading UTF-8 BOM
/// (`EF BB BF`) without allocating a copy of the input.
///
/// Kept in `core/encoding/` so both the markdown parser and the
/// library content-search walker share a single byte-level decode
/// policy. Previously the two call sites diverged — the parser
/// rejected malformed bytes with `FormatException`, while the
/// search walker silently rescued them via `allowMalformed: true`.
/// That meant the search corpus could contain files the viewer
/// refused to render, yielding hits the user could not open.
/// Reference: performance-review PR-20260419-019.
///
/// Decoding policy: strict (`allowMalformed: false`). Malformed
/// bytes propagate as `FormatException` so the caller can decide
/// whether to drop the file (search) or surface a typed failure
/// (viewer). `Utf8Decoder.convert(bytes, 3)` skips the BOM without
/// a `sublist` copy — keeps peak memory flat on multi-MB files.
String decodeUtf8StripBom(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return const Utf8Decoder().convert(bytes, 3);
  }
  return utf8.decode(bytes);
}
