import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
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
  const LibraryFolderBody({required this.folder, super.key});

  final LibraryFolder folder;

  @override
  ConsumerState<LibraryFolderBody> createState() => _LibraryFolderBodyState();
}

class _LibraryFolderBodyState extends ConsumerState<LibraryFolderBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Flat recursive walk cached once per folder source. We
  /// trigger the walk lazily on the first non-empty search so
  /// browsing a folder without searching does not pay the walk
  /// cost at all.
  Future<List<FolderFileEntry>>? _recursiveFuture;

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
    }
  }

  @override
  void dispose() {
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
          child:
              _searchQuery.isEmpty
                  ? _FolderBrowseView(
                    key: ValueKey('browse-${widget.folder.path}'),
                    folder: widget.folder,
                  )
                  : _FolderSearchView(
                    key: ValueKey('search-${widget.folder.path}'),
                    folder: widget.folder,
                    query: _searchQuery,
                    recursiveFuture: _recursiveFuture!,
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
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

/// Search mode: flat list of markdown files that match [query],
/// drawn from the once-walked recursive scan.
class _FolderSearchView extends ConsumerWidget {
  const _FolderSearchView({
    required this.folder,
    required this.query,
    required this.recursiveFuture,
    super.key,
  });

  final LibraryFolder folder;
  final String query;
  final Future<List<FolderFileEntry>> recursiveFuture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final displayName =
        p.basename(folder.path).isEmpty ? folder.path : p.basename(folder.path);

    return FutureBuilder<List<FolderFileEntry>>(
      future: recursiveFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
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
        if (snapshot.hasError) {
          return _CenteredHint(text: l10n.libraryFolderSourceError);
        }
        final all = snapshot.data ?? const <FolderFileEntry>[];
        final matches =
            all
                .where((entry) => entry.name.toLowerCase().contains(query))
                .toList();
        if (matches.isEmpty) {
          return _CenteredHint(
            text: l10n.libraryFolderSourceSearchNoResults(displayName),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
          itemCount: matches.length,
          itemBuilder:
              (context, index) =>
                  _MatchTile(rootFolder: folder, entry: matches[index]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
