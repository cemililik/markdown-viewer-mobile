import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/library/application/active_library_source_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_source.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/add_source_sheet.dart';
import 'package:path/path.dart' as p;

/// Source picker drawer for the library home screen.
///
/// This is the single place the user switches between library
/// sources. The drawer renders a flat list of source tiles —
/// the built-in Recents entry first, a section for user-added
/// folders below it, and (eventually) synced repositories below
/// that — with an "Add source" action pinned to the bottom.
///
/// Tapping a source tile updates [activeLibrarySourceProvider]
/// and closes the drawer. The main library body then swaps its
/// content to render that source. Long-pressing a folder tile
/// removes that folder from the list; if it was the active
/// source the provider listener in the controller automatically
/// falls back to Recents so the UI never renders against a
/// dangling folder.
class SourcePickerDrawer extends ConsumerWidget {
  const SourcePickerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final folders = ref.watch(libraryFoldersControllerProvider);
    final activeSource = ref.watch(activeLibrarySourceProvider);

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
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _RecentsTile(isActive: activeSource is RecentsSource),
                  if (folders.isNotEmpty) ...[
                    _SectionHeader(text: l10n.librarySourceSectionHeader),
                    for (final folder in folders)
                      _FolderSourceTile(
                        folder: folder,
                        isActive:
                            activeSource is FolderSource &&
                            activeSource.folder.path == folder.path,
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: Text(l10n.libraryAddSourceButton),
                onPressed: () => showAddSourceSheet(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RecentsTile extends ConsumerWidget {
  const _RecentsTile({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(
        Icons.history,
        color:
            isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        l10n.librarySourceRecents,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color:
              isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
        ),
      ),
      selected: isActive,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.25,
      ),
      onTap: () {
        ref.read(activeLibrarySourceProvider.notifier).selectRecents();
        Navigator.of(context).maybePop();
      },
    );
  }
}

class _FolderSourceTile extends ConsumerWidget {
  const _FolderSourceTile({required this.folder, required this.isActive});

  final LibraryFolder folder;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final basename = p.basename(folder.path);
    final displayName = basename.isEmpty ? folder.path : basename;

    return ListTile(
      leading: Icon(
        Icons.folder_outlined,
        color:
            isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color:
              isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        folder.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isActive,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.25,
      ),
      onTap: () {
        ref.read(activeLibrarySourceProvider.notifier).selectFolder(folder);
        Navigator.of(context).maybePop();
      },
      onLongPress: () => _showRemoveSheet(context, ref),
    );
  }

  Future<void> _showRemoveSheet(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.libraryFoldersRemove),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        );
      },
    );
    if (selected != true || !context.mounted) return;
    ref.read(libraryFoldersControllerProvider.notifier).remove(folder.path);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.libraryFoldersRemovedSnack)));
  }
}
