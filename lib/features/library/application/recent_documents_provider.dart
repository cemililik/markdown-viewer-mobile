import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Application-layer binding for the [RecentDocumentsStore] port.
///
/// Throws by default so a missing composition-root override fails
/// loudly instead of silently dropping every recent. Overridden in
/// `lib/main.dart` after `SharedPreferences.getInstance()` lands,
/// using the same in-memory mock pattern in tests via
/// `SharedPreferences.setMockInitialValues`.
final recentDocumentsStoreProvider = Provider<RecentDocumentsStore>((ref) {
  throw UnimplementedError(
    'recentDocumentsStoreProvider must be overridden in the composition '
    'root (lib/main.dart) after `SharedPreferences.getInstance()` '
    'completes, or in tests with a fake-backed RecentDocumentsStore.',
  );
});

/// Notifier that owns the user's recent-documents list for the
/// library home screen.
///
/// Behaviour:
///
/// 1. **Seeded synchronously** from the injected store on first
///    build, so the home screen renders the saved list on the
///    very first frame.
/// 2. **`touch(documentId, preview: ...)`** is the single
///    mutating entry point used by the viewer when a document
///    successfully loads. It removes any existing entry for the
///    same path, prepends a fresh one with `DateTime.now()`,
///    carries forward the previous pinned state (so re-opening a
///    pinned document does not silently unpin it), and caps the
///    **unpinned** tail at [_maxUnpinnedRecents]. The result is
///    pinned-first / most-recent-first and deduped by path.
/// 3. **`togglePin(documentId)`** flips the pinned flag on a
///    single entry. The list order is re-applied so pinned
///    entries stay at the top of the list the UI walks, which
///    keeps the home screen predictable without forcing every
///    caller to know about the ordering contract.
/// 4. **`remove(documentId)` and `clear()`** wipe individual
///    entries or the entire list — both used by the home-screen
///    UI's long-press / "Clear all" affordances.
/// 5. **Persistence is fire-and-forget.** Each mutation updates
///    the in-memory state synchronously (so the UI rebuilds
///    immediately) and then drops the store write Future so a
///    slow disk does not block the tap.
class RecentDocumentsController extends Notifier<List<RecentDocument>> {
  static const int _maxUnpinnedRecents = 20;

  @override
  List<RecentDocument> build() {
    final store = ref.watch(recentDocumentsStoreProvider);
    return _ordered(store.read());
  }

  /// Records that [documentId] was just opened. Promotes any
  /// existing entry for the same path to the top of the list and
  /// stamps it with `DateTime.now()`.
  ///
  /// If [preview] is non-null, the fresh entry carries it as the
  /// snippet shown on the library tile. If [displayName] is
  /// non-null, it becomes the tile title (used by folder-sourced
  /// files whose cache path basename is an opaque sha256 hash).
  /// Existing pinned state, preview, and display name are all
  /// preserved when the corresponding argument is `null`, so a
  /// plain re-open never wipes metadata a previous touch already
  /// recorded.
  ///
  /// The unpinned tail is capped at [_maxUnpinnedRecents] entries;
  /// pinned entries are exempt from the cap so the user can keep
  /// more than twenty favourites at the top of the library.
  void touch(DocumentId documentId, {String? preview, String? displayName}) {
    final now = DateTime.now();
    final existing = state
        .where((entry) => entry.documentId.value == documentId.value)
        .fold<RecentDocument?>(null, (_, entry) => entry);
    final without =
        state
            .where((entry) => entry.documentId.value != documentId.value)
            .toList();
    final fresh = RecentDocument(
      documentId: documentId,
      openedAt: now,
      isPinned: existing?.isPinned ?? false,
      preview: preview ?? existing?.preview,
      displayName: displayName ?? existing?.displayName,
    );
    state = _ordered(<RecentDocument>[fresh, ...without]);
    ref.read(recentDocumentsStoreProvider).write(state).ignore();
  }

  /// Flips the pinned state of the entry for [documentId]. No-op
  /// when the path is not in the list so a stale callback does
  /// not crash the home screen.
  void togglePin(DocumentId documentId) {
    var found = false;
    final updated = <RecentDocument>[
      for (final entry in state)
        if (entry.documentId.value == documentId.value)
          () {
            found = true;
            return entry.copyWith(isPinned: !entry.isPinned);
          }()
        else
          entry,
    ];
    if (!found) {
      return;
    }
    state = _ordered(updated);
    ref.read(recentDocumentsStoreProvider).write(state).ignore();
  }

  /// Removes a single entry from the list. No-op when the entry
  /// is not present.
  void remove(DocumentId documentId) {
    final updated =
        state
            .where((entry) => entry.documentId.value != documentId.value)
            .toList();
    if (updated.length == state.length) {
      return;
    }
    state = updated;
    ref.read(recentDocumentsStoreProvider).write(updated).ignore();
  }

  /// Wipes the entire list. Used by the "Clear all" affordance.
  void clear() {
    if (state.isEmpty) {
      return;
    }
    state = const <RecentDocument>[];
    ref
        .read(recentDocumentsStoreProvider)
        .write(const <RecentDocument>[])
        .ignore();
  }

  /// Canonical ordering: pinned entries first (most-recent-first
  /// among themselves), then unpinned entries (most-recent-first),
  /// with the unpinned tail truncated to [_maxUnpinnedRecents].
  ///
  /// Centralising the ordering here means `touch`, `togglePin`,
  /// and even a fresh read from disk all produce a consistent
  /// list shape — the UI never has to re-sort or partition.
  List<RecentDocument> _ordered(List<RecentDocument> input) {
    final pinned =
        input.where((e) => e.isPinned).toList()
          ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    final unpinned =
        input.where((e) => !e.isPinned).toList()
          ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    final bounded =
        unpinned.length > _maxUnpinnedRecents
            ? unpinned.sublist(0, _maxUnpinnedRecents)
            : unpinned;
    return <RecentDocument>[...pinned, ...bounded];
  }
}

final recentDocumentsControllerProvider =
    NotifierProvider<RecentDocumentsController, List<RecentDocument>>(
      RecentDocumentsController.new,
    );
