import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/remote_file.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/repo_locator.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/sync_result.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/repo_sync/domain/repositories/synced_repos_store.dart';
import 'package:markdown_viewer/features/repo_sync/domain/services/repo_sync_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────

/// The current state of a repository sync operation.
sealed class RepoSyncState {
  const RepoSyncState();
}

/// No sync is running. Initial and post-reset state.
final class SyncIdle extends RepoSyncState {
  const SyncIdle();
}

/// Parsing the URL and calling the Trees API to enumerate files.
final class SyncDiscovering extends RepoSyncState {
  const SyncDiscovering();
}

/// Files discovered; now downloading them with bounded concurrency.
final class SyncDownloading extends RepoSyncState {
  const SyncDownloading({required this.current, required this.total});

  final int current;
  final int total;
}

/// Sync completed successfully (possibly with partial failures).
final class SyncComplete extends RepoSyncState {
  const SyncComplete(this.result);

  final SyncResult result;
}

/// Sync aborted with a fatal error.
final class SyncError extends RepoSyncState {
  const SyncError(this.failure);

  final Failure failure;
}

// ── Notifier ───────────────────────────────────────────────────────────────

/// Drives the repository sync state machine.
///
/// `keepAlive: true` on [repoSyncNotifierProvider] means an
/// in-progress sync outlives the sync screen — the user can
/// navigate away and files already downloaded are preserved.
/// Calling [reset] returns to [SyncIdle].
class RepoSyncNotifier extends Notifier<RepoSyncState> {
  @override
  RepoSyncState build() => const SyncIdle();

  CancelToken? _cancelToken;

  /// Starts a full sync for [rawUrl].
  ///
  /// Reads any stored PAT from [PatStore] and injects it as an
  /// `Authorization` header for the duration of this sync.
  Future<void> startSync(String rawUrl) async {
    if (state is SyncDownloading || state is SyncDiscovering) return;

    _cancelToken = CancelToken();
    final logger = ref.read(appLoggerProvider);
    final gitHubProvider = ref.read(gitHubSyncProviderProvider);
    final store = ref.read(syncedReposStoreProvider);

    state = const SyncDiscovering();

    try {
      final uri = Uri.parse(rawUrl);
      final locator = await gitHubProvider.parse(uri);

      final files = await _collectFiles(gitHubProvider, locator);

      if (_cancelToken!.isCancelled) {
        state = const SyncIdle();
        return;
      }

      if (files.isEmpty) {
        state = const SyncError(
          RepoNotFoundFailure(message: 'No markdown files found at that path'),
        );
        return;
      }

      final localRoot = await _buildLocalRoot(locator);
      // Natural-key lookup hits a drift index directly instead of
      // scanning the full repo list — the old implementation iterated
      // `store.readAll()` manually, which grew O(n) with the number
      // of synced repos.
      final existing = await store.findByNaturalKey(
        provider: locator.provider,
        owner: locator.owner,
        repo: locator.repo,
        ref: locator.ref,
        subPath: locator.subPath,
      );

      final knownShas =
          existing != null
              ? await store.knownShas(existing.id)
              : <String, String>{};

      // Deliberately do NOT wipe the file rows up-front. `upsertFile`
      // is keyed on (repoId, remotePath), so refreshed downloads just
      // overwrite the old row, and the [knownShas] snapshot above stays
      // valid for the duration of this sync. If the user cancels
      // mid-batch, the pre-existing rows for files we did not reach
      // survive — a subsequent re-sync can still skip them via SHA
      // match + on-disk file-exists check, rather than re-downloading
      // the entire repo.
      //
      // Orphan cleanup (rows for remote paths that no longer exist)
      // happens below, only on a successful completion.

      state = SyncDownloading(current: 0, total: files.length);

      final result = await _downloadAll(
        files: files,
        locator: locator,
        localRoot: localRoot,
        existing: existing,
        knownShas: knownShas,
        store: store,
        gitHubProvider: gitHubProvider,
        logger: logger,
      );

      // Orphan cleanup runs only on a completed, non-cancelled sync.
      // _downloadAll returns normally on cancellation (it breaks out
      // of the batch loop rather than throwing), so we must check the
      // cancel token here — otherwise a cancelled sync would evict
      // file rows for every entry the user did not reach, breaking
      // the very metadata P1-14 preserved.
      if (existing != null && _cancelToken?.isCancelled != true) {
        final retained = {for (final f in files) f.path};
        await store.deleteFilesNotIn(existing.id, retained);
      }

      state = SyncComplete(result);
      ref.invalidate(syncedReposProvider);
    } on CancelException {
      state = const SyncIdle();
    } on Failure catch (f) {
      logger.e('Repo sync failed', error: f);
      state = SyncError(f);
    } on Object catch (e, st) {
      logger.e('Repo sync unexpected error', error: e, stackTrace: st);
      state = SyncError(UnknownFailure(message: 'Unexpected error', cause: e));
    }
  }

  /// Cancels any running sync and resets state to [SyncIdle].
  void cancel() {
    _cancelToken?.cancel('User cancelled');
    state = const SyncIdle();
  }

  /// Resets to [SyncIdle] so the screen can accept a new URL.
  void reset() => state = const SyncIdle();

  // ── Private helpers ──────────────────────────────────────────────────

  Future<List<RemoteFile>> _collectFiles(
    RepoSyncProvider provider,
    RepoLocator locator,
  ) async {
    final files = <RemoteFile>[];
    await for (final file in provider.listFiles(locator)) {
      files.add(file);
    }
    return files;
  }

  Future<SyncResult> _downloadAll({
    required List<RemoteFile> files,
    required RepoLocator locator,
    required String localRoot,
    required SyncedRepo? existing,
    required Map<String, String> knownShas,
    required SyncedReposStore store,
    required RepoSyncProvider gitHubProvider,
    required Logger logger,
  }) async {
    var persistedRepo = await store.upsert(
      SyncedRepo(
        id: existing?.id ?? 0,
        provider: locator.provider,
        owner: locator.owner,
        repo: locator.repo,
        ref: locator.ref,
        subPath: locator.subPath,
        localRoot: localRoot,
        lastSyncedAt: DateTime.now().toUtc(),
        fileCount: 0,
        status: SyncStatus.ok,
      ),
    );

    var downloadedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    const concurrency = 4;

    // Throttle progress state updates to at most once every 250 ms.
    // Without throttling a large repo fires a widget rebuild on every
    // file, producing rapid-succession rebuilds that risk janking the
    // progress indicator. The final update (current == total) always
    // fires immediately so the bar reaches 100 % before the result
    // card appears.
    final progressStopwatch = Stopwatch()..start();
    const progressThresholdMs = 250;

    void notifyProgress() {
      final current = downloadedCount + skippedCount + failedCount;
      if (progressStopwatch.elapsedMilliseconds >= progressThresholdMs ||
          current == files.length) {
        state = SyncDownloading(current: current, total: files.length);
        progressStopwatch.reset();
      }
    }

    for (var i = 0; i < files.length; i += concurrency) {
      if (_cancelToken!.isCancelled) break;

      final batch = files.skip(i).take(concurrency).toList();
      await Future.wait(
        batch.map((file) async {
          // Skip unchanged files detected via SHA comparison, but
          // still upsert a row so `lastSyncedAt` and `status` reflect
          // this sync run for the unchanged path. Without the upsert
          // the metadata would drift behind — the skipped files would
          // still carry the previous sync's timestamp/status.
          final localPath = p.join(
            localRoot,
            file.path.replaceAll('/', p.separator),
          );
          _validateLocalPath(localPath, localRoot);
          if (file.sha.isNotEmpty &&
              knownShas[file.path] == file.sha &&
              await File(localPath).exists()) {
            await store.upsertFile(
              repoId: persistedRepo.id,
              remotePath: file.path,
              localPath: localPath,
              sha: file.sha,
              size: file.size,
              status: 'synced',
            );
            skippedCount++;
            notifyProgress();
            return;
          }

          try {
            final bytes = await gitHubProvider.downloadRaw(file);
            final outFile = File(localPath);
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(bytes);

            await store.upsertFile(
              repoId: persistedRepo.id,
              remotePath: file.path,
              localPath: localPath,
              sha: file.sha,
              size: file.size,
              status: 'synced',
            );
            downloadedCount++;
          } on Object catch (e) {
            logger.w(
              'File download failed: ${p.basename(file.path)}',
              error: e,
            );
            await store.upsertFile(
              repoId: persistedRepo.id,
              remotePath: file.path,
              localPath: localPath,
              sha: file.sha,
              size: file.size,
              status: 'failed',
            );
            failedCount++;
          } finally {
            notifyProgress();
          }
        }),
      );
    }

    final totalUsable = downloadedCount + skippedCount;
    final finalStatus =
        failedCount == 0
            ? SyncStatus.ok
            : totalUsable == 0
            ? SyncStatus.failed
            : SyncStatus.partial;

    persistedRepo = await store.upsert(
      persistedRepo.copyWith(
        fileCount: totalUsable,
        status: finalStatus,
        lastSyncedAt: DateTime.now().toUtc(),
      ),
    );

    return SyncResult(
      syncedCount: totalUsable,
      downloadedCount: downloadedCount,
      failedCount: failedCount,
      repo: persistedRepo,
    );
  }

  /// Returns the absolute path to the local mirror directory:
  /// `<app-docs>/synced_repos/<provider>/<owner>/<repo>/<ref-encoded>/[subPath]`
  ///
  /// Every segment derived from user input is validated against path
  /// traversal attacks (`..' , absolute paths, null bytes).
  static Future<String> _buildLocalRoot(RepoLocator locator) async {
    _validatePathSegment(locator.provider);
    _validatePathSegment(locator.owner);
    _validatePathSegment(locator.repo);
    if (locator.subPath.isNotEmpty) {
      for (final part in locator.subPath.split('/')) {
        _validatePathSegment(part);
      }
    }

    final base = await getApplicationDocumentsDirectory();
    // `Uri.encodeComponent('..') == '..'` — encoding alone does not
    // defuse a ref like `../../etc`. Split on `/` first, validate each
    // segment (same traversal rejection the static segments use above),
    // then URL-encode to keep spaces / fragments safe. Without this a
    // malicious or compromised `default_branch` value could escape the
    // sandbox root.
    // Reference: code-review CR-20260419-007.
    final refParts = locator.ref.split('/');
    for (final part in refParts) {
      _validatePathSegment(part);
    }
    final refSafe = refParts.map(Uri.encodeComponent).join('/');
    final segments = [
      base.path,
      'synced_repos',
      locator.provider,
      locator.owner,
      locator.repo,
      refSafe,
      if (locator.subPath.isNotEmpty) locator.subPath,
    ];
    return p.joinAll(segments);
  }

  /// Rejects path segments that could escape the sync sandbox.
  static void _validatePathSegment(String segment) {
    if (segment == '..' ||
        segment.startsWith('/') ||
        segment.contains('\x00')) {
      throw const UnsupportedProviderFailure(
        message: 'Invalid path segment: contains traversal characters',
      );
    }
  }

  /// Validates that a remote file path does not escape [localRoot]
  /// after joining.
  ///
  /// Uses `p.isWithin` instead of `String.startsWith` because a naive
  /// prefix check treats `/foo/bar` and `/foo/bar2/evil` as related
  /// (they share the same string prefix but the second is outside the
  /// first). `p.isWithin` normalises both paths and enforces proper
  /// filesystem-boundary containment.
  static void _validateLocalPath(String localPath, String localRoot) {
    final rootNormalized = p.normalize(localRoot);
    final pathNormalized = p.normalize(localPath);
    if (pathNormalized == rootNormalized) return;
    if (!p.isWithin(rootNormalized, pathNormalized)) {
      throw const UnsupportedProviderFailure(
        message: 'Remote path escapes the sync sandbox',
      );
    }
  }
}

/// Thrown internally when [RepoSyncNotifier.cancel] fires and a
/// later await detects the cancelled token.
final class CancelException implements Exception {
  const CancelException();
}

/// `keepAlive: true` — running syncs survive navigation away from
/// the sync screen and finish in the background.
final repoSyncNotifierProvider =
    NotifierProvider<RepoSyncNotifier, RepoSyncState>(RepoSyncNotifier.new);
