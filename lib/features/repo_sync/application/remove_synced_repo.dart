import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';

/// Use-case: remove a synced repository and every piece of state
/// that refers to it.
///
/// Call sites used to invoke `syncedReposStoreProvider.delete(id)`
/// directly, which dropped the DB row + on-disk mirror but left the
/// PAT in the Keychain after the last repo was removed and left
/// `RecentDocuments` entries pointing under the now-deleted
/// `localRoot` (so tiles 404 on tap).
///
/// The fan-out this helper owns:
///
///  1. Delete the repo row (the store's own `delete` already wipes
///     the on-disk `localRoot` tree and cascades `synced_files` via
///     the Drift FK).
///  2. Prune `RecentDocuments` entries that sit under `localRoot`
///     — otherwise the library home screen keeps 404-ing.
///  3. When no repos remain, wipe the stored PAT. Keeping a PAT in
///     Keychain "until the next sync" violates ADR-0012's
///     wipe-on-sign-out contract and leaves a credential on-device
///     that the user has no UI to remove.
///  4. Invalidate the `syncedReposProvider` and
///     `libraryFoldersControllerProvider` so every screen rebuilds
///     against the new truth.
///
/// References: security-review SR-20260419-006, code-review
/// CR-20260419-003 / CR-20260419-040.
///
/// Accepts [WidgetRef] because both call sites are widgets (the
/// library screen bottom sheet and the source picker drawer).
/// The helper only needs `read` / `invalidate` which are the
/// overlap between `WidgetRef` and `Ref`; keeping the signature
/// narrow avoids having to expose a dual-API overload.
Future<void> removeSyncedRepo(WidgetRef ref, int repoId) async {
  final store = ref.read(syncedReposStoreProvider);

  // Resolve the localRoot from the authoritative store, not from
  // `syncedReposProvider.future`. The FutureProvider can be in an
  // error state (transient DB hiccup / test seam) — a user who
  // wants to remove a repo should still be able to even in that
  // case.
  String? localRoot;
  try {
    final all = await store.readAll();
    final match = all.where((r) => r.id == repoId).toList();
    if (match.isEmpty) return;
    localRoot = match.first.localRoot;
  } on Object {
    // Fall through to best-effort delete — the DB may still accept
    // the delete even when the read failed for a transient reason.
  }

  await store.delete(repoId);

  try {
    // Every follow-up is non-fatal. If recents pruning or PAT wipe
    // fails (e.g. Keychain flakiness), we still want the invalidates
    // in `finally` to run so the UI rebuilds against the
    // post-delete store state.
    if (localRoot != null) {
      ref
          .read(recentDocumentsControllerProvider.notifier)
          .removeUnder(localRoot);
    }

    // Re-read the post-delete repo list from the store rather than
    // recomputing from the pre-delete snapshot — a concurrent sync
    // could have mutated the list between the two calls.
    final remaining = await store.readAll();
    if (remaining.isEmpty) {
      await ref.read(patStoreProvider).delete();
    }
  } finally {
    // Always fan the invalidations out, even when a follow-up step
    // threw. Without this a Keychain error would leave every screen
    // rendering the deleted repo until the next manual refresh.
    ref.invalidate(syncedReposProvider);
    ref.invalidate(libraryFoldersControllerProvider);
  }
}
