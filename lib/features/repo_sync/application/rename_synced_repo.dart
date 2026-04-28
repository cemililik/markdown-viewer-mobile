import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';

/// Use-case: assign a user-supplied display name to a synced
/// repository, or clear the override.
///
/// Persists through [SyncedReposStore.rename] (which trims and
/// nulls-out an empty string so the default `owner/repo` form is
/// the canonical "no override" state) and then invalidates
/// [syncedReposProvider] so every consumer (drawer, library
/// AppBar title, content-search labels) rebuilds against the new
/// label without waiting for the next sync round-trip.
Future<void> renameSyncedRepo(
  WidgetRef ref,
  int repoId,
  String? customName,
) async {
  await ref.read(syncedReposStoreProvider).rename(repoId, customName);
  ref.invalidate(syncedReposProvider);
}
