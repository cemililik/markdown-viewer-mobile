import 'package:markdown_viewer/features/viewer/domain/entities/document.dart'
    show DocumentId;

/// A single cross-library content-search hit.
///
/// The library screen groups these under the existing search field
/// so the user can surface a document they half-remember ("which
/// ADR was that `PlatformDispatcher` snippet in?") without opening
/// each file and running the in-document search.
class ContentSearchMatch {
  const ContentSearchMatch({
    required this.documentId,
    required this.displayName,
    required this.snippet,
    required this.snippetMatchStart,
    required this.snippetMatchLength,
    required this.matchCount,
    required this.sourceLabel,
  });

  /// Absolute filesystem path of the matching document. Reused as
  /// the key fed to `ViewerRoute.location(…)`.
  final DocumentId documentId;

  /// Human-friendly filename shown on the result tile. Synced-repo
  /// files use their original repository-relative filename rather
  /// than the hashed cache-directory name.
  final String displayName;

  /// Context line centred on the first match. Always plain text —
  /// leading and trailing markdown syntax characters are not
  /// stripped because the goal is to show how the line looks in
  /// the source, not how it will render.
  final String snippet;

  /// Zero-based offset inside [snippet] where the highlighted
  /// portion starts. -1 if the highlight could not be computed
  /// (e.g. whitespace collapse removed the matched run entirely —
  /// a real edge case but the UI renders no background painting in
  /// that case instead of crashing).
  final int snippetMatchStart;

  /// Length of the highlighted fragment inside [snippet].
  final int snippetMatchLength;

  /// Total hits of the query inside the document body. Only the
  /// first hit is rendered in [snippet]; the count anchors the
  /// "+N more" hint on the tile.
  final int matchCount;

  /// Short descriptor rendered next to the filename — e.g.
  /// `Recent`, `Folder: Notes`, `Repo: owner/repo`. Lets the user
  /// understand where a hit came from without opening it.
  final String sourceLabel;
}

/// Pure-data representation of a single file to be searched.
///
/// Decoupled from filesystem I/O so [searchInContents] can run
/// inside a Dart isolate via `compute()` — the isolate entry point
/// only needs bytes and the per-file metadata the results will
/// render with.
class ContentSearchDocument {
  const ContentSearchDocument({
    required this.documentId,
    required this.displayName,
    required this.sourceLabel,
    required this.content,
  });

  final DocumentId documentId;
  final String displayName;
  final String sourceLabel;
  final String content;
}

/// Isolate-safe search request — bundles the document corpus with
/// the normalised query. Needed because `compute()` accepts a
/// single argument for the isolate entry point.
class ContentSearchRequest {
  const ContentSearchRequest({
    required this.documents,
    required this.normalisedQuery,
    this.maxSnippetRadius = 40,
    this.maxResults = 50,
  });

  final List<ContentSearchDocument> documents;
  final String normalisedQuery;
  final int maxSnippetRadius;
  final int maxResults;
}

/// Entry point safe to run inside a Dart isolate.
///
/// Linear scan over each document. Case-insensitive. Returns the
/// full list of matches, sorted by the highest match count first
/// and then alphabetically by display name to keep subsequent
/// keystrokes (which narrow rather than re-order) stable.
///
/// The query is trimmed and lowercased by the caller — this helper
/// takes the normalised form so the isolate work is
/// allocation-minimal.
List<ContentSearchMatch> searchInContents(ContentSearchRequest request) {
  final normalisedQuery = request.normalisedQuery;
  if (normalisedQuery.isEmpty) {
    return const <ContentSearchMatch>[];
  }
  final matches = <ContentSearchMatch>[];
  for (final doc in request.documents) {
    final body = doc.content;
    if (body.isEmpty) continue;
    final lower = body.toLowerCase();
    final firstIndex = lower.indexOf(normalisedQuery);
    if (firstIndex < 0) continue;

    // Count remaining occurrences with a rolling indexOf — cheaper
    // than compiling a regex for a substring query, and avoids
    // regex-escape surprises on user-supplied patterns.
    var count = 1;
    var scan = firstIndex + normalisedQuery.length;
    while (true) {
      final next = lower.indexOf(normalisedQuery, scan);
      if (next < 0) break;
      count += 1;
      scan = next + normalisedQuery.length;
    }

    final snippet = _buildSnippet(
      body: body,
      matchIndex: firstIndex,
      matchLength: normalisedQuery.length,
      radius: request.maxSnippetRadius,
    );
    matches.add(
      ContentSearchMatch(
        documentId: doc.documentId,
        displayName: doc.displayName,
        snippet: snippet.text,
        snippetMatchStart: snippet.matchStart,
        snippetMatchLength: snippet.matchLength,
        matchCount: count,
        sourceLabel: doc.sourceLabel,
      ),
    );
  }

  matches.sort((a, b) {
    final byCount = b.matchCount.compareTo(a.matchCount);
    if (byCount != 0) return byCount;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  if (matches.length > request.maxResults) {
    return matches.sublist(0, request.maxResults);
  }
  return matches;
}

/// Context window centred on a hit, collapsed to a single line.
///
/// The raw slice goes through `\s+`-to-space collapse so the snippet
/// stays on one line regardless of the surrounding markdown layout.
/// Because whitespace collapse changes the string length, the
/// match-offset returned points into the *collapsed* string, not
/// the source document — that is the coordinate the UI's
/// highlighted paint layer needs.
///
/// Leading / trailing "…" markers signal a truncated edge. Omitted
/// when the window already touches the document's natural start /
/// end.
_Snippet _buildSnippet({
  required String body,
  required int matchIndex,
  required int matchLength,
  required int radius,
}) {
  final start = (matchIndex - radius).clamp(0, body.length);
  final end = (matchIndex + matchLength + radius).clamp(0, body.length);
  final rawBefore = body.substring(start, matchIndex);
  final rawMatch = body.substring(matchIndex, matchIndex + matchLength);
  final rawAfter = body.substring(matchIndex + matchLength, end);

  final collapsedBefore = rawBefore.replaceAll(RegExp(r'\s+'), ' ');
  final collapsedMatch = rawMatch.replaceAll(RegExp(r'\s+'), ' ');
  final collapsedAfter = rawAfter.replaceAll(RegExp(r'\s+'), ' ');

  final leadingCut = collapsedBefore.length - collapsedBefore.trimLeft().length;
  final trailingCut = collapsedAfter.length - collapsedAfter.trimRight().length;
  final beforeTrimmed = collapsedBefore.substring(leadingCut);
  final afterTrimmed = collapsedAfter.substring(
    0,
    collapsedAfter.length - trailingCut,
  );

  final prefix = start > 0 ? '… ' : '';
  final suffix = end < body.length ? ' …' : '';
  final text = '$prefix$beforeTrimmed$collapsedMatch$afterTrimmed$suffix';
  final matchStart = prefix.length + beforeTrimmed.length;
  return _Snippet(
    text: text,
    matchStart: matchStart,
    matchLength: collapsedMatch.length,
  );
}

class _Snippet {
  const _Snippet({
    required this.text,
    required this.matchStart,
    required this.matchLength,
  });
  final String text;
  final int matchStart;
  final int matchLength;
}
