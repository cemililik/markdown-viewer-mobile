import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Resolves a markdown anchor link (`#slug`) to its target
/// [HeadingRef] within [headings].
///
/// Handles three real-world href shapes that the raw
/// `headings.where((h) => h.anchor == slug)` comparison misses:
///
/// 1. **URL-encoded characters** — a markdown renderer may hand back
///    `%20` (space) or `%C3%A7` (ç) inside the href. Decoding before
///    comparison lets `[x](#my%20heading)` resolve to a heading with
///    slug `my-heading` when combined with the other normalisations.
/// 2. **Case differences** — GitHub renders `[x](#Foo)` and `[x](#foo)`
///    identically because it lowercases anchor IDs at lookup time.
///    Our slug generator lowercases at parse time, so the comparison
///    must lowercase the href as well.
/// 3. **Encoded spaces still as `+`** — some renderers convert ` ` to
///    `+` instead of `%20`. [Uri.decodeComponent] does not reverse
///    that form, so we substitute it up front.
///
/// Anything that cannot be decoded (malformed `%` escape) falls back
/// to the raw slug — better to no-op than to crash the tap handler
/// mid-scroll.
///
/// Returns `null` when the href leads nowhere — the caller should
/// treat this as "not a known anchor" and ignore the tap.
HeadingRef? resolveAnchor({
  required String href,
  required List<HeadingRef> headings,
}) {
  if (!href.startsWith('#')) return null;
  final raw = href.substring(1);
  if (raw.isEmpty) return null;

  final candidates = <String>{raw, raw.toLowerCase()};
  final decoded = _tryDecode(raw);
  if (decoded != null) {
    candidates.add(decoded);
    candidates.add(decoded.toLowerCase());
  }

  for (final candidate in candidates) {
    for (final h in headings) {
      if (h.anchor == candidate) return h;
    }
  }
  return null;
}

String? _tryDecode(String raw) {
  try {
    // Normalise `+` to `%20` before decoding — `decodeComponent`
    // preserves `+` verbatim, but some renderers URL-encode spaces
    // as `+` (application/x-www-form-urlencoded style) for
    // anchor links.
    final swapped = raw.replaceAll('+', '%20');
    return Uri.decodeComponent(swapped);
  } on Object {
    return null;
  }
}
