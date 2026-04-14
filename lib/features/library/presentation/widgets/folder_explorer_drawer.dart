import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:path/path.dart' as p;

/// Folder explorer drawer for the library home screen.
///
/// Slides in from the left edge of [LibraryScreen]. Renders the
/// list of [LibraryFolder] roots the user has added (newest
/// first) as expandable rows. Tapping a root expands it once,
/// loading its immediate children through
/// [folderEnumeratorProvider]; tapping a markdown leaf pushes the
/// `/viewer?path=…` route. Long-pressing a root opens a bottom
/// sheet with "Remove folder" so the user can drop a stale entry
/// without leaving the drawer.
///
/// The drawer is intentionally read-only: there is no add-folder
/// button inside the drawer because the speed dial on the main
/// FAB owns that affordance and shipping it twice would be
/// noise. The empty state inside the drawer is just the localized
/// "no folders yet" hint and points the user at the speed dial.
class FolderExplorerDrawer extends ConsumerWidget {
  const FolderExplorerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final folders = ref.watch(libraryFoldersControllerProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    l10n.libraryFoldersDrawerTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  folders.isEmpty
                      ? const _FolderDrawerEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: folders.length,
                        itemBuilder:
                            (context, index) =>
                                _LibraryFolderTile(folder: folders[index]),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderDrawerEmptyState extends StatelessWidget {
  const _FolderDrawerEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.libraryFoldersEmptyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.libraryFoldersEmptyMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Top-level row representing a single user-added [LibraryFolder]
/// root. Owns its own enumeration future so the drawer does not
/// need to fan out the load through Riverpod — a single root has
/// no behaviour worth lifting into the application layer.
class _LibraryFolderTile extends ConsumerStatefulWidget {
  const _LibraryFolderTile({required this.folder});

  final LibraryFolder folder;

  @override
  ConsumerState<_LibraryFolderTile> createState() => _LibraryFolderTileState();
}

class _LibraryFolderTileState extends ConsumerState<_LibraryFolderTile> {
  Future<List<FolderEntry>>? _childrenFuture;

  void _loadChildrenIfNeeded() {
    _childrenFuture ??= ref
        .read(folderEnumeratorProvider)
        .enumerate(widget.folder.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final basename = p.basename(widget.folder.path);
    final displayName = basename.isEmpty ? widget.folder.path : basename;

    return ExpansionTile(
      key: PageStorageKey<String>('folder-${widget.folder.path}'),
      leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        widget.folder.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onExpansionChanged: (expanded) {
        if (expanded) _loadChildrenIfNeeded();
      },
      childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
      children: [
        if (_childrenFuture == null)
          const SizedBox.shrink()
        else
          FutureBuilder<List<FolderEntry>>(
            future: _childrenFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _InlineDrawerHint(
                  text: l10n.libraryFoldersEnumerationFailed,
                );
              }
              final entries = snapshot.data ?? const <FolderEntry>[];
              if (entries.isEmpty) {
                return _InlineDrawerHint(text: l10n.libraryFoldersEmptyFolder);
              }
              return Column(
                children: [
                  for (final entry in entries) _FolderEntryTile(entry: entry),
                ],
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.libraryFoldersRemove),
              onPressed: () => _confirmRemove(context),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRemove(BuildContext context) {
    final l10n = context.l10n;
    ref
        .read(libraryFoldersControllerProvider.notifier)
        .remove(widget.folder.path);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.libraryFoldersRemovedSnack)));
  }
}

/// One immediate child of a library folder root: either a
/// markdown leaf (tap to open) or a subdirectory (tap to expand
/// for one more level using the same lazy-load shape).
class _FolderEntryTile extends ConsumerStatefulWidget {
  const _FolderEntryTile({required this.entry});

  final FolderEntry entry;

  @override
  ConsumerState<_FolderEntryTile> createState() => _FolderEntryTileState();
}

class _FolderEntryTileState extends ConsumerState<_FolderEntryTile> {
  Future<List<FolderEntry>>? _childrenFuture;

  void _loadChildrenIfNeeded() {
    _childrenFuture ??= ref
        .read(folderEnumeratorProvider)
        .enumerate(widget.entry.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final entry = widget.entry;

    if (entry is FolderFileEntry) {
      return ListTile(
        dense: true,
        leading: Icon(
          Icons.description_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          // Close the drawer first so the viewer push lands on
          // a clean stack without the drawer hanging open behind
          // the reading surface.
          Navigator.of(context).maybePop();
          unawaited(context.push(ViewerRoute.location(entry.path)));
        },
      );
    }

    // Subdirectory — recursive expansion using the same lazy
    // FutureBuilder shape as the root tile.
    return ExpansionTile(
      key: PageStorageKey<String>('subdir-${entry.path}'),
      leading: Icon(
        Icons.folder_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onExpansionChanged: (expanded) {
        if (expanded) _loadChildrenIfNeeded();
      },
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [
        if (_childrenFuture == null)
          const SizedBox.shrink()
        else
          FutureBuilder<List<FolderEntry>>(
            future: _childrenFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
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
                return _InlineDrawerHint(
                  text: l10n.libraryFoldersEnumerationFailed,
                );
              }
              final children = snapshot.data ?? const <FolderEntry>[];
              if (children.isEmpty) {
                return _InlineDrawerHint(text: l10n.libraryFoldersEmptyFolder);
              }
              return Column(
                children: [
                  for (final child in children) _FolderEntryTile(entry: child),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _InlineDrawerHint extends StatelessWidget {
  const _InlineDrawerHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
