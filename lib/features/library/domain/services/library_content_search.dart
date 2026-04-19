import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart'
    show DocumentId;

/// Port for the library-wide content search feature.
///
/// The concrete implementation walks recents / folder trees / synced
/// repo mirrors, decodes each file, and dispatches the scan to an
/// isolate via `compute()`. That work is I/O-bound so it lives in
/// `data/`; the application layer depends only on this port to keep
/// the layer boundary clean.
abstract class LibraryContentSearch {
  /// Performs the content search over the given live library state.
  ///
  /// [query] is the raw user input; implementations trim + lowercase
  /// it before scanning. [recentsSourceLabel],
  /// [folderSourceLabelBuilder], and [syncedRepoSourceLabelBuilder]
  /// carry the locale-resolved source badges so the domain layer
  /// stays free of `AppLocalizations`.
  Future<List<ContentSearchMatch>> search({
    required String query,
    required List<RecentDocument> recents,
    required List<LibraryFolder> folders,
    required List<SyncedRepo> syncedRepos,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  });
}

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

  /// Absolute filesystem path of the source file. Reused as the
  /// [ContentSearchMatch.documentId] when the scan yields a hit.
  final DocumentId documentId;

  /// Human-friendly filename rendered on the result tile. For
  /// synced-repo files this is the original repo-relative filename
  /// rather than the hashed cache-directory name.
  final String displayName;

  /// Short source descriptor (e.g. `Recent`, `Folder: Notes`,
  /// `Repo: owner/repo`) carried onto every emitted
  /// [ContentSearchMatch] so the UI can badge results by origin.
  final String sourceLabel;

  /// UTF-8 decoded file body. Already loaded into memory because
  /// the isolate worker needs the full text — callers pre-read and
  /// pass bytes in to keep `compute()` allocation-minimal.
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

  /// Corpus of files to scan, in the order the UI expects ties to be
  /// broken (see [searchInContents] sort).
  final List<ContentSearchDocument> documents;

  /// User query, already trimmed and lowercased. Empty queries yield
  /// an empty match list.
  final String normalisedQuery;

  /// Number of characters of context kept on either side of a hit
  /// when building the result snippet. Clamped inside
  /// [searchInContents] to `[0, 200]` before use.
  final int maxSnippetRadius;

  /// Maximum number of matches returned. Clamped inside
  /// [searchInContents] to `[0, documents.length]` before use.
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
  // Clamp public inputs so a negative / absurd value cannot reach
  // the substring / sublist math downstream. Reference: PR-review
  // NEW-005.
  final radius =
      request.maxSnippetRadius < 0
          ? 0
          : (request.maxSnippetRadius > 200 ? 200 : request.maxSnippetRadius);
  final cap =
      request.maxResults < 0
          ? 0
          : (request.maxResults > request.documents.length
              ? request.documents.length
              : request.maxResults);
  if (cap == 0) return const <ContentSearchMatch>[];

  final matches = <ContentSearchMatch>[];
  for (final doc in request.documents) {
    final body = doc.content;
    if (body.isEmpty) continue;
    // Case-insensitive scan that PRESERVES original-body offsets.
    //
    // Previous revisions ran `body.toLowerCase().indexOf(query)` and
    // fed the resulting index into [_buildSnippet] (which operates
    // on the original body). That breaks on Unicode case-folds whose
    // lowercased form differs in length from the source — `'İ'`
    // (U+0130) lowercases to `'i̇'` (U+0069 + U+0307, two code units),
    // which drifts every downstream offset and mis-highlights the
    // snippet. The loop below walks the original body directly and
    // compares per-position `toLowerCase()` output against the query,
    // so the resulting indices always point into the original string.
    // Reference: PR-review NEW-007.
    final matchIndices = _findCaseInsensitive(body, normalisedQuery);
    if (matchIndices.isEmpty) continue;

    final firstIndex = matchIndices.first;
    final snippet = _buildSnippet(
      body: body,
      matchIndex: firstIndex,
      matchLength: normalisedQuery.length,
      radius: radius,
    );
    matches.add(
      ContentSearchMatch(
        documentId: doc.documentId,
        displayName: doc.displayName,
        snippet: snippet.text,
        snippetMatchStart: snippet.matchStart,
        snippetMatchLength: snippet.matchLength,
        matchCount: matchIndices.length,
        sourceLabel: doc.sourceLabel,
      ),
    );
  }

  matches.sort((a, b) {
    final byCount = b.matchCount.compareTo(a.matchCount);
    if (byCount != 0) return byCount;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  if (matches.length > cap) {
    return matches.sublist(0, cap);
  }
  return matches;
}

/// Returns every original-string offset of [query] inside [body]
/// under a case-insensitive comparison that preserves body-side
/// indices — scans the original body directly so the returned
/// offsets are safe to feed into `body.substring(…)` and
/// `_buildSnippet` without a lowercased-mirror offset drift.
///
/// The query is already lowercased by the caller (see
/// [ContentSearchController.submitQuery]); we only need to compare
/// each `query.length` window of the body against it after
/// per-character lower-casing.
///
/// **Limitation — ASCII / BMP-safe only.** The per-position
/// comparison assumes `body[i].toLowerCase().length == 1`, which
/// holds for ASCII and the Basic Multilingual Plane except for a
/// handful of code points whose case-fold changes length. The most
/// user-visible offender is Turkish `İ` (U+0130) → `i̇`
/// (U+0069 + U+0307, two code units): a document whose body
/// contains `İstanbul` will NOT match a query `istan` through this
/// helper, and vice versa. Dart's `RegExp(caseSensitive: false)`
/// has the same blind spot, so "just use a regex" is not a drop-in
/// fix. A future pass that needs full Unicode case-folding should
/// build an explicit `lower[i]` → `original[j]` offset map.
/// Reference: PR-review follow-up to NEW-007.
List<int> _findCaseInsensitive(String body, String query) {
  if (query.isEmpty || body.length < query.length) {
    return const <int>[];
  }
  final hits = <int>[];
  final maxStart = body.length - query.length;
  for (var start = 0; start <= maxStart; start++) {
    var matches = true;
    for (var qi = 0; qi < query.length; qi++) {
      final bodyChar = body[start + qi].toLowerCase();
      // `query` was already lowercased by the caller. If a future
      // caller passes a mixed-case string this still works because
      // both sides are folded per-character.
      if (bodyChar != query[qi].toLowerCase()) {
        matches = false;
        break;
      }
    }
    if (matches) {
      hits.add(start);
      // Skip past this hit so overlapping matches are not counted
      // twice — mirrors the old rolling-indexOf behaviour.
      start += query.length - 1;
    }
  }
  return hits;
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
