import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:path/path.dart' as p;

/// Builds the flat corpus of searchable markdown files and hands it
/// to the isolate-safe core search routine.
///
/// The corpus is rebuilt per query (not persisted) because the user-
/// visible library changes often — recents are added on every open,
/// folders get re-enumerated on pull-to-refresh, synced repos gain
/// files on each re-sync. A warm in-memory cache would need
/// invalidation hooks from every one of those code paths; a lazy
/// per-query walk trades that complexity for a bounded filesystem
/// walk that, empirically, finishes well inside the user's
/// perceived "instant" window (roughly 200 ms on a phone for
/// typical library sizes < 500 files).
///
/// Three corpus contributors:
///
/// 1. **Recents** — files the user has opened. Display name prefers
///    the stored `displayName` (original filename for folder /
///    synced-repo sources that mask the hashed cache path).
/// 2. **Library folders** — each registered folder source's `.md`
///    tree is walked with `Directory.list(recursive: true)`. Cheap
///    because the OS already indexes these paths; the filter keeps
///    the corpus to markdown only.
/// 3. **Synced repositories** — each `syncedRepo.localRoot` is
///    walked the same way. File size is capped at
///    [_maxFileBytes] so a surprise 10 MB `CHANGELOG.md` can't
///    freeze the search.
class LibraryContentSearchService {
  const LibraryContentSearchService();

  /// Hard cap on the size of any single file fed into the
  /// searcher. Markdown docs beyond this point are almost never
  /// useful search targets and the read + scan cost scales
  /// linearly with file size. Matches the per-file cap used by
  /// the native file-open channel.
  static const int _maxFileBytes = 10 * 1024 * 1024;

  /// Maximum number of files to scan in a single query. Belt-and-
  /// suspenders against a pathological library (e.g. a 20k-file
  /// monorepo synced as a single repo source) — the user is
  /// unlikely to want a scan of everything on every keystroke, and
  /// the hit cap in the core search routine already bounds result
  /// size.
  static const int _maxFiles = 2000;

  /// Performs the content search.
  ///
  /// `compute` moves the scan off the UI isolate. Parameters:
  ///
  /// - [query] — raw user input. Trimmed + lowercased before scan.
  /// - [recents] — snapshot of `recentDocumentsControllerProvider`.
  /// - [folders] — registered folder sources.
  /// - [syncedRepos] — synced repositories (their `localRoot` is
  ///   the walk root).
  /// - [recentsSourceLabel], [folderSourceLabelBuilder],
  ///   [syncedRepoSourceLabelBuilder] — localised tile-badge
  ///   strings. The domain service has no access to AppLocalizations
  ///   so the caller resolves these on the UI isolate and passes
  ///   them in already-localised form.
  Future<List<ContentSearchMatch>> search({
    required String query,
    required List<RecentDocument> recents,
    required List<LibraryFolder> folders,
    required List<SyncedRepo> syncedRepos,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) async {
    final normalised = query.trim().toLowerCase();
    if (normalised.isEmpty) return const <ContentSearchMatch>[];

    final documents = await _buildCorpus(
      recents: recents,
      folders: folders,
      syncedRepos: syncedRepos,
      recentsSourceLabel: recentsSourceLabel,
      folderSourceLabelBuilder: folderSourceLabelBuilder,
      syncedRepoSourceLabelBuilder: syncedRepoSourceLabelBuilder,
    );
    if (documents.isEmpty) return const <ContentSearchMatch>[];

    return compute<ContentSearchRequest, List<ContentSearchMatch>>(
      _runSearch,
      ContentSearchRequest(documents: documents, normalisedQuery: normalised),
    );
  }

  Future<List<ContentSearchDocument>> _buildCorpus({
    required List<RecentDocument> recents,
    required List<LibraryFolder> folders,
    required List<SyncedRepo> syncedRepos,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) async {
    final seen = <String>{};
    final corpus = <ContentSearchDocument>[];

    Future<void> tryAdd({
      required String path,
      required String displayName,
      required String sourceLabel,
    }) async {
      if (corpus.length >= _maxFiles) return;
      if (!seen.add(path)) return;
      final file = File(path);
      if (!await file.exists()) return;
      try {
        final stat = await file.stat();
        if (stat.size > _maxFileBytes) return;
        final raw = await file.readAsBytes();
        String content;
        try {
          content = utf8.decode(raw);
        } on FormatException {
          content = utf8.decode(raw, allowMalformed: true);
        }
        corpus.add(
          ContentSearchDocument(
            documentId: DocumentId(path),
            displayName: displayName,
            sourceLabel: sourceLabel,
            content: content,
          ),
        );
      } on FileSystemException {
        // Missing permission / broken symlink / mount unmount —
        // surface nothing for this file and keep scanning. The
        // user's in-progress search query is not the right moment
        // to bother them about transient I/O failures.
      }
    }

    for (final recent in recents) {
      await tryAdd(
        path: recent.documentId.value,
        displayName: recent.displayName ?? p.basename(recent.documentId.value),
        sourceLabel: recentsSourceLabel,
      );
    }

    for (final folder in folders) {
      final label = folderSourceLabelBuilder(folder);
      await _walkTree(
        root: folder.path,
        sourceLabel: label,
        onFile:
            (path, displayName) async => tryAdd(
              path: path,
              displayName: displayName,
              sourceLabel: label,
            ),
      );
    }

    for (final repo in syncedRepos) {
      final label = syncedRepoSourceLabelBuilder(repo);
      await _walkTree(
        root: repo.localRoot,
        sourceLabel: label,
        onFile:
            (path, displayName) async => tryAdd(
              path: path,
              displayName: displayName,
              sourceLabel: label,
            ),
      );
    }
    return corpus;
  }

  Future<void> _walkTree({
    required String root,
    required String sourceLabel,
    required Future<void> Function(String path, String displayName) onFile,
  }) async {
    final dir = Directory(root);
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        if (!name.endsWith('.md') && !name.endsWith('.markdown')) continue;
        await onFile(entity.path, p.basename(entity.path));
      }
    } on FileSystemException {
      // Bookmark went stale, volume unmounted, ACL flipped — the
      // folder simply drops out of the corpus. Next refresh cycle
      // can bring it back.
    }
  }
}

/// Isolate entry point. Kept as a top-level function because
/// `compute()` requires it.
List<ContentSearchMatch> _runSearch(ContentSearchRequest request) {
  return searchInContents(request);
}
