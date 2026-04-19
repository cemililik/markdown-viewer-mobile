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
  final existing = await ref.read(syncedReposProvider.future);
  final match = existing.where((r) => r.id == repoId).toList();
  if (match.isEmpty) return;
  final localRoot = match.first.localRoot;

  await store.delete(repoId);

  ref.read(recentDocumentsControllerProvider.notifier).removeUnder(localRoot);

  // Re-read the post-delete repo list from the store rather than
  // recomputing from `existing` minus this id — the store is the
  // authoritative truth and a concurrent sync could have mutated
  // the list between the two calls.
  final remaining = await store.readAll();
  if (remaining.isEmpty) {
    await ref.read(patStoreProvider).delete();
  }

  ref.invalidate(syncedReposProvider);
  ref.invalidate(libraryFoldersControllerProvider);
}
