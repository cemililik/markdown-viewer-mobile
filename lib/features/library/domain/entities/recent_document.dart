import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// A single entry in the "recently opened documents" list shown on
/// the library home screen.
///
/// Plain value type — no freezed, no codegen — because the feature
/// surface is small and the data layer encodes the list as a
/// hand-rolled JSON array. If we ever grow more recent-related
/// fields (tags, thumbnail), promoting this to freezed is a
/// five-line change.
final class RecentDocument {
  const RecentDocument({
    required this.documentId,
    required this.openedAt,
    this.isPinned = false,
    this.preview,
  });

  /// Identity of the document the user opened. The path inside is
  /// what we use to (a) re-open the file when the user taps the
  /// recent entry and (b) show a basename + parent-folder hint in
  /// the recent tile.
  final DocumentId documentId;

  /// Wall-clock instant of the most recent open. Sorted on this
  /// field — most recent first — by the application-layer
  /// controller before handing the list to the UI.
  final DateTime openedAt;

  /// Whether the user has pinned this entry to the top of the
  /// library. Pinned entries live in their own section above the
  /// time-grouped recents and are exempt from the 20-entry LRU
  /// cap that keeps the unpinned tail bounded.
  final bool isPinned;

  /// Optional one-line preview of the document's opening prose,
  /// populated by the viewer when it successfully renders the
  /// source. The controller copies the snippet into the entity on
  /// each [touch] so a re-open overwrites stale previews with the
  /// freshest text. `null` until the first successful load — in
  /// that case the tile falls back to showing only the
  /// parent-folder + relative-time subtitle.
  final String? preview;

  /// Returns a copy of this entry with any combination of fields
  /// replaced. Mirrors the `copyWith` shape we would get from
  /// freezed without pulling in the codegen dep.
  RecentDocument copyWith({
    DocumentId? documentId,
    DateTime? openedAt,
    bool? isPinned,
    String? preview,
  }) {
    return RecentDocument(
      documentId: documentId ?? this.documentId,
      openedAt: openedAt ?? this.openedAt,
      isPinned: isPinned ?? this.isPinned,
      preview: preview ?? this.preview,
    );
  }
}
