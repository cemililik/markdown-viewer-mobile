import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/application/folder_file_materializer_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/content_match_tile.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart'
    show DocumentId;
import 'package:path/path.dart' as p;

/// Main library body rendered when the active source is a
/// [LibraryFolder].
///
/// The surface has two modes:
///
/// 1. **Browsing mode** — the search field is empty. The body
///    shows a lazy `ExpansionTile` tree rooted at the folder,
///    mirroring the shape the drawer used to have but promoted
///    to the main viewport where there is actual room to read
///    deep hierarchies. Each subfolder loads its children
///    through [folderEnumeratorProvider] the first time it is
///    expanded.
/// 2. **Search mode** — the search field is non-empty. The body
///    shows a flat list of every markdown file underneath the
///    folder whose name contains the query (case-insensitive).
///    The recursive walk is done once per folder source and
///    cached inside the state, so subsequent keystrokes filter
///    the cached list without re-walking the tree.
///
/// Search is scoped to the folder the user picked in the drawer
/// — it never mixes with the recents list. Pinning is a recents
/// concept and does not apply here; folder browsing uses the
/// filesystem hierarchy itself as the structure.
class LibraryFolderBody extends ConsumerStatefulWidget {
  const LibraryFolderBody({
    required this.folder,
    required this.refreshTick,
    required this.onRefresh,
    super.key,
  });

  final LibraryFolder folder;

  /// Monotonic tick the library screen bumps on every pull-to-
  /// refresh gesture. When it changes we drop the cached
  /// enumeration futures (both the root tree and the recursive
  /// search walk) so the next layout picks up any freshly synced /
  /// newly created markdown file.
  final int refreshTick;

  /// Pull-to-refresh handler supplied by the library screen. Drives
  /// the `RefreshIndicator` wrapped around the browse / search view.
  /// For a folder source this re-enumerates the directory; for a
  /// synced-repo source it triggers a GitHub re-sync before the
  /// local mirror is re-enumerated.
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<LibraryFolderBody> createState() => _LibraryFolderBodyState();
}

class _LibraryFolderBodyState extends ConsumerState<LibraryFolderBody> {
  /// Minimum query length that triggers an isolate-backed content
  /// scan. Below this threshold the body still renders filename
  /// matches, but the content section stays dormant — single- and
  /// double-character queries are too noisy to justify a walk.
  static const int _minContentQueryLength = 3;

  /// Debounce window between the last keystroke and the isolate
  /// dispatch. Matches the cross-library search on the Recents tab
  /// so the two surfaces feel identical.
  static const Duration _contentSearchDebounce = Duration(milliseconds: 250);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Flat recursive walk cached once per folder source. We
  /// trigger the walk lazily on the first non-empty search so
  /// browsing a folder without searching does not pay the walk
  /// cost at all.
  Future<List<FolderFileEntry>>? _recursiveFuture;

  // ── Content-search (source-scoped) state ────────────────────────
  //
  // The body runs two searches in parallel against the active
  // folder / synced-repo:
  //
  //   1. Filename filter — cheap, driven off `_recursiveFuture`
  //      above, case-insensitive substring match on the file's
  //      basename.
  //   2. Content search — reads file bytes, scans for the query,
  //      and surfaces a snippet. Runs on a [compute] isolate with
  //      the 10 MB / 2 000 files hard caps baked into
  //      [LibraryContentSearchService], so a surprise monorepo
  //      cannot stall the UI.
  //
  // Both run off the same search field. The content scan only fires
  // at >= [_minContentQueryLength] characters and is debounced to
  // avoid a fresh walk on every keystroke.
  Timer? _contentDebounceTimer;
  int _contentDispatchSeq = 0;
  List<ContentSearchMatch> _contentMatches = const <ContentSearchMatch>[];
  bool _isContentSearching = false;
  String _contentSearchQuery = '';

  @override
  void didUpdateWidget(covariant LibraryFolderBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder.path != widget.folder.path) {
      // Switching to a different folder source invalidates the
      // cached walk and any search state that was scoped to the
      // previous folder.
      _searchController.clear();
      _searchQuery = '';
      _recursiveFuture = null;
      _cancelContentSearch();
    } else if (oldWidget.refreshTick != widget.refreshTick) {
      // Pull-to-refresh was triggered at the library screen level.
      // Drop the recursive-walk cache so a re-enumeration runs on
      // the next non-empty query. Browsing-mode refresh runs
      // through the inner `_FolderBrowseView` via the same tick.
      //
      // If a search is already active when the refresh lands, kick
      // off a fresh walk immediately — the build side below relies
      // on the invariant "query non-empty ⇒ future non-null" and
      // hits `_recursiveFuture!` otherwise. A synced-repo source
      // that finishes a re-sync (or a folder source that receives
      // a pull-to-refresh) while the user is mid-search would
      // null the future out from under the active search view
      // and crash the library body with a bare "Null check
      // operator used on a null value" red-screen — the same red
      // screen ErrorWidget shows when any widget throws during
      // build.
      _recursiveFuture =
          _searchQuery.isNotEmpty
              ? ref
                  .read(folderEnumeratorProvider)
                  .enumerateRecursive(widget.folder)
              : null;
      // Content matches reflect the pre-refresh corpus, so rerun
      // the scan immediately (no debounce — the user already
      // committed to this query) if the current query is long
      // enough to trigger one.
      if (_searchQuery.length >= _minContentQueryLength) {
        _runContentSearch(_searchQuery);
      }
    }
  }

  @override
  void dispose() {
    _contentDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final normalized = value.trim().toLowerCase();
    setState(() {
      _searchQuery = normalized;
      if (_searchQuery.isNotEmpty) {
        _recursiveFuture ??= ref
            .read(folderEnumeratorProvider)
            .enumerateRecursive(widget.folder);
      }
    });
    _dispatchContentSearch(normalized);
  }

  void _clearSearch() {
    _searchController.clear();
    // Reset the cached recursive walk alongside the query. Without
    // this, a future that resolved to an error (stale bookmark,
    // transient I/O failure) stays cached: the next non-empty query
    // `??=` keeps the errored future and the user sees the same
    // error message with no way to retry short of leaving and
    // re-entering the folder source. Resetting here means a fresh
    // "type → walk" cycle starts after every clear.
    setState(() {
      _searchQuery = '';
      _recursiveFuture = null;
    });
    _cancelContentSearch();
  }

  /// Schedules a debounced content scan.
  ///
  /// Queries shorter than [_minContentQueryLength] cancel any
  /// pending scan and clear the match list without spawning work.
  /// Longer queries set the spinner immediately (so the UI feels
  /// live while typing settles) and fire the scan after
  /// [_contentSearchDebounce].
  void _dispatchContentSearch(String normalised) {
    _contentDebounceTimer?.cancel();
    if (normalised.length < _minContentQueryLength) {
      // Invalidate any in-flight dispatch so its result doesn't
      // arrive late and paint stale matches over a short query.
      _contentDispatchSeq += 1;
      setState(() {
        _contentMatches = const <ContentSearchMatch>[];
        _isContentSearching = false;
        _contentSearchQuery = normalised;
      });
      return;
    }
    setState(() {
      _isContentSearching = true;
      _contentSearchQuery = normalised;
    });
    _contentDebounceTimer = Timer(_contentSearchDebounce, () {
      _runContentSearch(normalised);
    });
  }

  /// Cancels a pending debounce and clears the match list. Used on
  /// `clear search` and folder-source switches.
  void _cancelContentSearch() {
    _contentDebounceTimer?.cancel();
    _contentDispatchSeq += 1;
    _contentMatches = const <ContentSearchMatch>[];
    _isContentSearching = false;
    _contentSearchQuery = '';
  }

  Future<void> _runContentSearch(String normalised) async {
    final seq = ++_contentDispatchSeq;
    final service = ref.read(libraryContentSearchProvider);
    final l10n = context.l10n;
    try {
      final results = await service.search(
        query: normalised,
        // Source-scoped: pass the active folder as the only corpus
        // contributor. Recents / other synced repos stay out of
        // scope so a hit on this tab always comes from this source.
        recents: const [],
        folders: [widget.folder],
        syncedRepos: const [],
        // The folder-body never renders a "Recent" badge, but the
        // label is required for the shared [ContentMatchTile] API.
        recentsSourceLabel: l10n.libraryContentSearchSourceRecent,
        folderSourceLabelBuilder: (folder) {
          final basename = p.basename(folder.path);
          final name = basename.isEmpty ? folder.path : basename;
          return l10n.libraryContentSearchSourceFolder(name);
        },
        syncedRepoSourceLabelBuilder: (_) => '',
      );
      if (!mounted || seq != _contentDispatchSeq) return;
      setState(() {
        _contentMatches = results;
        _isContentSearching = false;
      });
    } on Object {
      // Content search is best-effort — a transient I/O failure in
      // the isolate should not leave the spinner spinning forever.
      if (!mounted || seq != _contentDispatchSeq) return;
      setState(() {
        _contentMatches = const <ContentSearchMatch>[];
        _isContentSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final displayName = _displayNameFor(widget.folder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              hintText: l10n.libraryFolderSourceSearchHint(displayName),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon:
                  _searchQuery.isEmpty
                      ? null
                      : IconButton(
                        tooltip: l10n.librarySearchClear,
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            // Screen-reader label — without this VoiceOver / TalkBack
            // only announce the spinner. Reference: CR-20260419-012.
            semanticsLabel: context.l10n.libraryRefreshSemantic,
            // The browse / search views are backed by `ListView`s
            // that have `AlwaysScrollableScrollPhysics`, so the
            // RefreshIndicator can attach even in loading / empty /
            // error states — otherwise a branch that returned a
            // non-scrollable `Center` or `_CenteredHint` would freeze
            // the pull gesture.
            // Reference: PR-review NEW-010.
            child:
                _searchQuery.isEmpty
                    ? _FolderBrowseView(
                      key: ValueKey(
                        'browse-${widget.folder.path}-${widget.refreshTick}',
                      ),
                      folder: widget.folder,
                    )
                    : _FolderCombinedSearchView(
                      key: ValueKey('search-${widget.folder.path}'),
                      folder: widget.folder,
                      query: _searchQuery,
                      recursiveFuture: _recursiveFuture!,
                      contentMatches: _contentMatches,
                      isContentSearching: _isContentSearching,
                      contentQuery: _contentSearchQuery,
                      minContentQueryLength: _minContentQueryLength,
                    ),
          ),
        ),
      ],
    );
  }

  String _displayNameFor(LibraryFolder folder) {
    final basename = p.basename(folder.path);
    return basename.isEmpty ? folder.path : basename;
  }
}

/// Browsing mode: lazy expansion-tile tree rooted at [folder].
class _FolderBrowseView extends ConsumerStatefulWidget {
  const _FolderBrowseView({required this.folder, super.key});

  final LibraryFolder folder;

  @override
  ConsumerState<_FolderBrowseView> createState() => _FolderBrowseViewState();
}

class _FolderBrowseViewState extends ConsumerState<_FolderBrowseView> {
  Future<List<FolderEntry>>? _rootFuture;

  @override
  void initState() {
    super.initState();
    _rootFuture = ref.read(folderEnumeratorProvider).enumerate(widget.folder);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<FolderEntry>>(
      future: _rootFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Wrap in a scrollable so `RefreshIndicator` can attach
          // to the gesture while the first enumeration is still in
          // flight. Otherwise pulling on a cold-start slow SMB mount
          // would freeze with no spinner appearing.
          // Reference: PR-review NEW-010.
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return _CenteredHint(text: l10n.libraryFolderSourceError);
        }
        final entries = snapshot.data ?? const <FolderEntry>[];
        if (entries.isEmpty) {
          return _CenteredHint(text: l10n.libraryFolderSourceEmpty);
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
          itemCount: entries.length,
          itemBuilder:
              (context, index) => _FolderEntryTile(
                rootFolder: widget.folder,
                entry: entries[index],
                indent: 0,
              ),
        );
      },
    );
  }
}

/// Search mode for folder / synced-repo sources. Combines two
/// parallel result streams:
///
/// 1. **Filename matches** — case-insensitive substring match over
///    the once-walked recursive tree ([recursiveFuture]). Cheap,
///    fires on every keystroke.
/// 2. **Content matches** — [ContentSearchMatch] list produced by
///    [LibraryContentSearchService] against this source only. Only
///    populated once the query reaches [minContentQueryLength] and
///    the 250 ms debounce elapses.
///
/// Both sections share a single scrollable `ListView` so the user
/// can flip between them with one scroll gesture. The "No matching
/// files" hint only appears when both lists would otherwise render
/// empty AND no content scan is in flight — otherwise the empty
/// text would fight the spinner for screen real-estate.
class _FolderCombinedSearchView extends ConsumerWidget {
  const _FolderCombinedSearchView({
    required this.folder,
    required this.query,
    required this.recursiveFuture,
    required this.contentMatches,
    required this.isContentSearching,
    required this.contentQuery,
    required this.minContentQueryLength,
    super.key,
  });

  final LibraryFolder folder;
  final String query;
  final Future<List<FolderFileEntry>> recursiveFuture;
  final List<ContentSearchMatch> contentMatches;
  final bool isContentSearching;

  /// The query the content-search notifier is currently running
  /// against. Distinct from [query] so a short query (< min length)
  /// does not render a stale content header while the filename
  /// filter still has results to show.
  final String contentQuery;

  /// Minimum query length before the content scan kicks in. Echoed
  /// from the parent so this widget knows whether "no content
  /// matches yet" means "too few characters" or "scan finished
  /// empty".
  final int minContentQueryLength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final displayName =
        p.basename(folder.path).isEmpty ? folder.path : p.basename(folder.path);

    return FutureBuilder<List<FolderFileEntry>>(
      future: recursiveFuture,
      builder: (context, snapshot) {
        final walking = snapshot.connectionState != ConnectionState.done;
        final walkError = snapshot.hasError;

        if (walkError) {
          return _CenteredHint(text: l10n.libraryFolderSourceError);
        }

        final all = snapshot.data ?? const <FolderFileEntry>[];
        final filenameMatches =
            all
                .where((entry) => entry.name.toLowerCase().contains(query))
                .toList();

        final contentHeaderVisible =
            contentQuery.length >= minContentQueryLength;
        final hasFilenameMatches = filenameMatches.isNotEmpty;
        final hasContentMatches = contentMatches.isNotEmpty;

        // Loading state: the filename walk is still resolving and
        // no content matches have arrived yet. Mirrors the old
        // pre-v1.1 "Scanning folder…" placeholder so the user sees
        // that something is happening instead of an empty panel.
        if (walking && !hasContentMatches && !isContentSearching) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.libraryFolderSourceSearchLoading,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        // True empty state — only fires when every source of
        // results is exhausted and no content scan is pending. A
        // query below [minContentQueryLength] that produces no
        // filename matches still lands here (the scan would be a
        // noise-trap).
        final scanPending = isContentSearching;
        final contentFinishedEmpty =
            contentHeaderVisible && !scanPending && !hasContentMatches;
        final contentSkipped = !contentHeaderVisible;
        final nothingToShow =
            !hasFilenameMatches &&
            !scanPending &&
            (contentSkipped || contentFinishedEmpty);

        if (nothingToShow) {
          return _CenteredHint(
            text: l10n.libraryFolderSourceSearchNoResults(displayName),
          );
        }

        final children = <Widget>[];

        // ── Filename matches ────────────────────────────────────
        for (final entry in filenameMatches) {
          children.add(_MatchTile(rootFolder: folder, entry: entry));
        }

        // ── Content matches ─────────────────────────────────────
        // Header + (spinner | results | empty). The header is the
        // same affordance the Recents tab uses so the surface feels
        // identical across tabs.
        if (contentHeaderVisible) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.manage_search_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.libraryContentSearchHeader,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
          if (scanPending && !hasContentMatches) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.libraryContentSearchLoading,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (!hasContentMatches) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  l10n.libraryContentSearchEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          } else {
            for (final match in contentMatches) {
              children.add(
                ContentMatchTile(
                  match: match,
                  // All matches on this surface come from the same
                  // source (the active folder / synced-repo), so
                  // the source-label badge is redundant noise.
                  showSourceLabel: false,
                  onTap: () {
                    unawaited(
                      openFolderEntry(
                        context: context,
                        ref: ref,
                        folder: folder,
                        // Rebuild a FolderFileEntry from the match so
                        // the shared open-path respects any platform
                        // security-scoped bookmark on [folder]. On
                        // synced repos the materializer is a no-op
                        // passthrough.
                        entry: FolderFileEntry(
                          path: match.documentId.value,
                          name: match.displayName,
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          }
        }

        // `ListView.builder` + `AlwaysScrollableScrollPhysics` so the
        // result list lazily instantiates rows (large result sets used
        // to eager-build every tile) and always yields to the
        // pull-to-refresh gesture even when there is only one match.
        // References: performance-review PR-20260419-010 (builder),
        // PR-review NEW-010 (scroll physics).
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Recursive expansion-tile row used inside browsing mode. Each
/// subdirectory loads its own children lazily the first time it
/// is expanded, and the indent grows with depth so the eye can
/// follow the hierarchy without the tiles bleeding into each
/// other.
class _FolderEntryTile extends ConsumerStatefulWidget {
  const _FolderEntryTile({
    required this.rootFolder,
    required this.entry,
    required this.indent,
  });

  /// The [LibraryFolder] the user picked as the active source.
  /// Threaded down through every level of the expansion tree so
  /// the nested enumerate call can reuse the root's security-
  /// scoped bookmark — on iOS the native channel needs the root
  /// bookmark to claim access before listing any sub-path.
  final LibraryFolder rootFolder;
  final FolderEntry entry;
  final int indent;

  @override
  ConsumerState<_FolderEntryTile> createState() => _FolderEntryTileState();
}

class _FolderEntryTileState extends ConsumerState<_FolderEntryTile> {
  Future<List<FolderEntry>>? _childrenFuture;

  void _loadChildrenIfNeeded() {
    _childrenFuture ??= ref
        .read(folderEnumeratorProvider)
        .enumerate(widget.rootFolder, subPath: widget.entry.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final entry = widget.entry;
    final leftPadding = 8.0 + widget.indent * 12.0;

    if (entry is FolderFileEntry) {
      return Padding(
        padding: EdgeInsets.only(left: leftPadding),
        child: ListTile(
          dense: true,
          leading: Icon(
            Icons.description_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap:
              () => unawaited(
                openFolderEntry(
                  context: context,
                  ref: ref,
                  folder: widget.rootFolder,
                  entry: entry,
                ),
              ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: ExpansionTile(
        key: PageStorageKey<String>('browse-${entry.path}'),
        leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        onExpansionChanged: (expanded) {
          if (expanded) {
            setState(_loadChildrenIfNeeded);
          }
        },
        childrenPadding: EdgeInsets.zero,
        tilePadding: EdgeInsets.zero,
        children: [
          if (_childrenFuture == null)
            const SizedBox.shrink()
          else
            FutureBuilder<List<FolderEntry>>(
              future: _childrenFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _CenteredHint(
                    text: l10n.libraryFoldersEnumerationFailed,
                  );
                }
                final children = snapshot.data ?? const <FolderEntry>[];
                if (children.isEmpty) {
                  return _CenteredHint(text: l10n.libraryFoldersEmptyFolder);
                }
                return Column(
                  children: [
                    for (final child in children)
                      _FolderEntryTile(
                        rootFolder: widget.rootFolder,
                        entry: child,
                        indent: widget.indent + 1,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Search-result row. Shows the matched file name on the first
/// line and the path relative to the folder root on the second
/// line so the user can tell two `readme.md` results apart.
class _MatchTile extends ConsumerWidget {
  const _MatchTile({required this.rootFolder, required this.entry});

  final LibraryFolder rootFolder;
  final FolderFileEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final relative = p.relative(entry.path, from: rootFolder.path);
    final parent = p.dirname(relative);
    return ListTile(
      leading: Icon(
        Icons.description_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle:
          parent == '.'
              ? null
              : Text(
                parent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      onTap:
          () => unawaited(
            openFolderEntry(
              context: context,
              ref: ref,
              folder: rootFolder,
              entry: entry,
            ),
          ),
    );
  }
}

/// Shared "open a folder-sourced markdown file" handler used by
/// both the browsing tree and the search-result list.
///
/// On platforms / folders that have no security-scoped bookmark
/// the function pushes the viewer route directly with the
/// original path — exactly the legacy behaviour. When a bookmark
/// is present (iOS picked folders, Android SAF tree URIs) the
/// function asks the [folderFileMaterializerProvider] to copy
/// the bytes into the app cache and pushes the viewer with the
/// resulting cache path. The viewer + recents store + reading-
/// position store keep using plain `dart:io` filesystem reads
/// without any SAF awareness.
///
/// Errors are caught locally and surfaced as a localized
/// snackbar; an unreachable folder must not crash the library.
Future<void> openFolderEntry({
  required BuildContext context,
  required WidgetRef ref,
  required LibraryFolder folder,
  required FolderFileEntry entry,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final logger = ref.read(appLoggerProvider);
  final materializer = ref.read(folderFileMaterializerProvider);

  String resolvedPath;
  try {
    resolvedPath = await materializer.materialize(
      folder: folder,
      sourcePath: entry.path,
    );
  } on NativeFolderBookmarkStaleException catch (stale) {
    // iOS told us the bookmark is stale and (sometimes) handed back a
    // fresh one. When we have a replacement, persist it and retry
    // the materialization ONCE with the updated folder. If the retry
    // still fails, fall through to the generic error path so the
    // user sees a snackbar rather than an infinite loop.
    final refreshed = stale.refreshedBookmark;
    if (refreshed != null && refreshed.isNotEmpty) {
      ref
          .read(libraryFoldersControllerProvider.notifier)
          .updateBookmark(path: folder.path, bookmark: refreshed);
      try {
        resolvedPath = await materializer.materialize(
          folder: LibraryFolder(
            path: folder.path,
            addedAt: folder.addedAt,
            bookmark: refreshed,
          ),
          sourcePath: entry.path,
        );
      } on Object catch (retryError, retryStack) {
        logger.e(
          'Retry after bookmark refresh still failed',
          error: retryError,
          stackTrace: retryStack,
        );
        if (!context.mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.libraryFolderSourceError)),
          );
        return;
      }
    } else {
      logger.w('Bookmark stale with no refresh available', error: stale);
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.libraryFolderSourceError)));
      return;
    }
  } on Object catch (error, stackTrace) {
    logger.e(
      'Failed to materialize folder file for viewer push',
      error: error,
      stackTrace: stackTrace,
    );
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.libraryFolderSourceError)));
    return;
  }

  if (!context.mounted) return;

  // Record the recent entry with its original filename BEFORE
  // pushing the viewer. The viewer's own `ref.listen` touch
  // fires after a successful load and preserves whichever
  // `displayName` we stamped here, so the recents tile shows
  // "readme.md" instead of the sha256 cache-path basename
  // `b311fa8502d7...`.
  ref
      .read(recentDocumentsControllerProvider.notifier)
      .touch(DocumentId(resolvedPath), displayName: entry.name);

  unawaited(context.push(ViewerRoute.location(resolvedPath)));
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hosted inside a scrollable so `RefreshIndicator` can attach
    // to the enclosing gesture even when the body is otherwise
    // non-scrollable (loading / empty / error branches). Without
    // this the pull-to-refresh spinner never fires in those states.
    // Reference: PR-review NEW-010.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
