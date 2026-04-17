import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/library/application/active_library_source_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_source.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/add_source_sheet.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/library_folder_body.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/source_picker_drawer.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;

/// The library home screen.
///
/// The layout is built from the following stacked blocks, from
/// top to bottom:
///
/// 1. **Greeting header** — time-of-day salutation plus a compact
///    subtitle reporting the recent-document count. Always
///    visible, even on an empty library, so the user is never
///    confronted with a bare back-of-house screen.
/// 2. **Search field** — a Material 3 filled text field with a
///    leading search icon and a trailing clear affordance. Live
///    filters both the pinned and the time-grouped sections by
///    a case-insensitive substring match over basename + parent
///    folder + preview snippet.
/// 3. **Pinned section** — entries the user has long-press-pinned
///    to the top of the library. Separated visually from the
///    time-grouped list by its own section header and a small
///    pin icon on the tile. Pinned entries are exempt from the
///    LRU cap the controller applies to the unpinned tail.
/// 4. **Grouped recents** — unpinned entries bucketed by
///    `openedAt` into "Today", "Yesterday", "Earlier this week",
///    and "Earlier" headers. The controller already returns the
///    list most-recent-first, so each bucket simply takes entries
///    in order.
/// 5. **Empty states** — two of them. When the library has never
///    held a recent document the search field is hidden and a
///    centred welcome layout offers the first Open file CTA.
///    When the library has entries but the current search query
///    matches none of them, the sections collapse to a single
///    "No matching documents" row so the user understands why
///    the list is empty.
///
/// The settings icon stays in the AppBar `actions` regardless.
/// A floating "Open file" extended FAB appears whenever the
/// library has at least one recent — the primary open affordance
/// on a populated screen.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recents = ref.watch(recentDocumentsControllerProvider);
    final activeSource = ref.watch(activeLibrarySourceProvider);
    final folders = ref.watch(libraryFoldersControllerProvider);
    final syncedRepos = ref.watch(syncedReposProvider).value ?? <SyncedRepo>[];
    final hasSources = folders.isNotEmpty || syncedRepos.isNotEmpty;

    // AppBar title follows the active source so the user always
    // knows which source they are browsing. Recents falls back
    // to the localized "Library" string, a folder source shows
    // its basename with a small leading folder glyph.
    Widget titleWidget;
    switch (activeSource) {
      case RecentsSource():
        titleWidget = Text(l10n.navLibrary);
      case FolderSource(:final folder):
        final basename = p.basename(folder.path);
        final display = basename.isEmpty ? folder.path : basename;
        titleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_outlined, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case SyncedRepoSource(:final syncedRepo):
        titleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done_outlined, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                syncedRepo.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(
        // Explicit leading IconButton (rather than relying on
        // Scaffold's automatic drawer hamburger) so we can wire a
        // localized tooltip and keep the icon style consistent
        // with the settings action on the right. The hamburger
        // always means "open source picker" regardless of which
        // source is active.
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: l10n.libraryFoldersOpenDrawerTooltip,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: titleWidget,
        actions: [
          if (activeSource case SyncedRepoSource(:final syncedRepo))
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: l10n.syncRefreshTooltip,
              onPressed:
                  () => context.push(
                    RepoSyncRoute.location(url: syncedRepo.githubTreeUrl),
                  ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.navSettings,
            onPressed: () => context.push(SettingsRoute.location()),
          ),
        ],
      ),
      drawer: const SourcePickerDrawer(),
      body: switch (activeSource) {
        RecentsSource() when recents.isNotEmpty => _LibraryPopulatedBody(
          recents: recents,
          searchController: _searchController,
          searchQuery: _searchQuery,
          onSearchChanged: _onSearchChanged,
          onClearSearch: _clearSearch,
        ),
        RecentsSource() when hasSources => _RecentsEmptyWithSources(
          folders: folders,
          syncedRepos: syncedRepos,
          onSelectFolder:
              (LibraryFolder f) => ref
                  .read(activeLibrarySourceProvider.notifier)
                  .selectFolder(f),
          onSelectSyncedRepo:
              (SyncedRepo r) => ref
                  .read(activeLibrarySourceProvider.notifier)
                  .selectSyncedRepo(r),
          onOpenFile: () => _pickAndOpenFile(context, ref),
          onAddSource: () => showAddSourceSheet(context, ref),
        ),
        RecentsSource() => _LibraryEmptyState(
          onOpenFile: () => _pickAndOpenFile(context, ref),
          onOpenFolder: () => pickAndAddFolder(context, ref),
          onSyncRepo: () => context.push(RepoSyncRoute.location()),
        ),
        FolderSource(:final folder) => LibraryFolderBody(
          key: ValueKey('folder-body-${folder.path}'),
          folder: folder,
        ),
        SyncedRepoSource(:final syncedRepo) => LibraryFolderBody(
          key: ValueKey('synced-repo-body-${syncedRepo.localRoot}'),
          folder: LibraryFolder(
            path: syncedRepo.localRoot,
            addedAt: syncedRepo.lastSyncedAt,
          ),
        ),
      },
      // Single Open file FAB. Hidden only on the first-run onboarding
      // screen (no recents AND no sources) because its three-button
      // layout already exposes Open file as a primary CTA. On the
      // "recents cleared but sources exist" state the FAB stays
      // visible so the user can still open a one-off file quickly.
      floatingActionButton: switch (activeSource) {
        RecentsSource() when recents.isEmpty && !hasSources => null,
        _ => FloatingActionButton.extended(
          icon: const Icon(Icons.note_add_outlined),
          label: Text(l10n.actionOpenFile),
          onPressed: () => _pickAndOpenFile(context, ref),
        ),
      },
    );
  }

  /// Opens the platform file picker, validates the result, and
  /// pushes the viewer route. Used by both the empty-state CTA
  /// and the floating action button on the populated state.
  static Future<void> _pickAndOpenFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Read the logger eagerly so the closure does not capture `ref`
    // across the await — Riverpod widget refs are tied to the
    // element lifecycle and cannot be safely used after a
    // context.mounted gap.
    final logger = ref.read(appLoggerProvider);

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'markdown'],
      );
    } on Object catch (error, stackTrace) {
      logger.e('File picker failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryFilePickFailed)),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (result == null || result.files.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryFilePickCancelled)),
      );
      return;
    }

    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryFilePickFailed)),
      );
      return;
    }

    // `push` (not `go`) so the viewer sits on top of the library
    // stack and the user can tap back to come home. The push
    // future completes when the user pops the viewer; we
    // intentionally do not wait on it — nothing in this handler
    // should run post-pop.
    unawaited(context.push(ViewerRoute.location(path)));
  }
}

/// Shown when the user is on the Recents tab with no recent documents
/// but has at least one folder or synced-repo source saved.
///
/// Rather than the first-run onboarding screen, this presents the
/// existing sources as tappable shortcut cards so the user can
/// quickly jump to their content without hunting in the drawer.
class _RecentsEmptyWithSources extends ConsumerWidget {
  const _RecentsEmptyWithSources({
    required this.folders,
    required this.syncedRepos,
    required this.onSelectFolder,
    required this.onSelectSyncedRepo,
    required this.onOpenFile,
    required this.onAddSource,
  });

  final List<LibraryFolder> folders;
  final List<SyncedRepo> syncedRepos;
  final void Function(LibraryFolder) onSelectFolder;
  final void Function(SyncedRepo) onSelectSyncedRepo;
  final VoidCallback onOpenFile;
  final VoidCallback onAddSource;

  Future<void> _showFolderRemoveSheet(
    BuildContext context,
    WidgetRef ref,
    LibraryFolder folder,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
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
          ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(libraryFoldersControllerProvider.notifier).remove(folder.path);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.libraryFoldersRemovedSnack)));
  }

  Future<void> _showRepoActionsSheet(
    BuildContext context,
    WidgetRef ref,
    SyncedRepo repo,
  ) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(l10n.syncUpdateRepo),
                  onTap: () => Navigator.of(sheetContext).pop('update'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.syncRemoveRepo),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
              ],
            ),
          ),
    );
    if (!context.mounted) return;
    if (action == 'update') {
      unawaited(context.push(RepoSyncRoute.location(url: repo.githubTreeUrl)));
    } else if (action == 'remove') {
      await ref.read(syncedReposStoreProvider).delete(repo.id);
      ref.invalidate(syncedReposProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.syncRemovedRepoSnack)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final scheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.history_toggle_off_outlined,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.libraryRecentsEmptyTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.libraryRecentsEmptySubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.libraryRecentsEmptySources,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: folders.length + syncedRepos.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
          itemBuilder: (context, index) {
            if (index < folders.length) {
              final folder = folders[index];
              final basename = p.basename(folder.path);
              final display = basename.isEmpty ? folder.path : basename;
              return ListTile(
                leading: Icon(Icons.folder_outlined, color: scheme.primary),
                title: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  folder.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelectFolder(folder),
                onLongPress: () => _showFolderRemoveSheet(context, ref, folder),
              );
            }
            final repo = syncedRepos[index - folders.length];
            return ListTile(
              leading: Icon(Icons.cloud_done_outlined, color: scheme.primary),
              title: Text(
                repo.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                repo.subPath.isNotEmpty ? repo.subPath : repo.ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelectSyncedRepo(repo),
              onLongPress: () => _showRepoActionsSheet(context, ref, repo),
            );
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: Text(l10n.libraryAddSourceButton),
                  onPressed: onAddSource,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Centred welcome view shown when the user has never opened a
/// document. Three onboarding affordances stacked in priority order:
/// Open file (filled), Open folder (tonal), Sync repository (outlined).
class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.onOpenFile,
    required this.onOpenFolder,
    required this.onSyncRepo,
  });

  final VoidCallback onOpenFile;
  final VoidCallback onOpenFolder;
  final VoidCallback onSyncRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.libraryEmptyTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.libraryEmptyMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(l10n.actionOpenFile),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onOpenFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.libraryActionMenuOpenFolder),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSyncRepo,
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(l10n.actionSyncRepo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Populated library body: greeting → search → pinned → grouped
/// recents, stacked inside a single scrollable `CustomScrollView`
/// so the whole surface shares one scroll position (good for the
/// thin theme-wide scrollbar) and the greeting scrolls with the
/// content rather than staying sticky.
class _LibraryPopulatedBody extends ConsumerWidget {
  const _LibraryPopulatedBody({
    required this.recents,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final List<RecentDocument> recents;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filtered = _filter(recents, searchQuery);
    final pinned = filtered.where((e) => e.isPinned).toList();
    final unpinned = filtered.where((e) => !e.isPinned).toList();
    final groups = _groupByTime(unpinned, DateTime.now());
    final hasAnyResults = filtered.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _LibraryGreeting(recentCount: recents.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _LibrarySearchField(
              controller: searchController,
              query: searchQuery,
              onChanged: onSearchChanged,
              onClear: onClearSearch,
            ),
          ),
        ),
        if (!hasAnyResults)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Center(
                child: Text(
                  l10n.librarySearchNoResults,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        if (pinned.isNotEmpty) ...[
          _sectionHeaderSliver(
            context,
            title: l10n.libraryRecentPinnedSection,
            icon: Icons.push_pin_outlined,
          ),
          _tilesSliver(pinned),
        ],
        for (final group in groups) ...[
          _sectionHeaderSliver(context, title: group.title(l10n)),
          _tilesSliver(group.entries),
        ],
        if (pinned.isNotEmpty || groups.isNotEmpty)
          _sectionTrailingSliver(
            context,
            onTapClearAll: () async {
              await _confirmClear(context, ref);
            },
          ),
        // Extra bottom padding so the last tile is not hidden
        // behind the floating Open file action button.
        const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
      ],
    );
  }

  List<RecentDocument> _filter(List<RecentDocument> entries, String query) {
    if (query.isEmpty) return entries;
    return entries.where((entry) {
      final path = entry.documentId.value;
      // Prefer the explicit display name so a search for
      // "readme" hits a folder-sourced file whose path is a
      // sha256 cache blob.
      final nameSource = entry.displayName ?? p.basename(path);
      final name = nameSource.toLowerCase();
      final parent = p.basename(p.dirname(path)).toLowerCase();
      final preview = entry.preview?.toLowerCase() ?? '';
      return name.contains(query) ||
          parent.contains(query) ||
          preview.contains(query);
    }).toList();
  }

  /// Buckets [entries] into Today / Yesterday / This week /
  /// Earlier groups. [now] is taken as a parameter so tests can
  /// feed a deterministic clock instead of whatever wall time
  /// happens to be live.
  List<_RecentGroup> _groupByTime(List<RecentDocument> entries, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayList = <RecentDocument>[];
    final yesterdayList = <RecentDocument>[];
    final weekList = <RecentDocument>[];
    final earlierList = <RecentDocument>[];

    for (final entry in entries) {
      final day = DateTime(
        entry.openedAt.year,
        entry.openedAt.month,
        entry.openedAt.day,
      );
      if (!day.isBefore(today)) {
        todayList.add(entry);
      } else if (!day.isBefore(yesterday)) {
        yesterdayList.add(entry);
      } else if (!day.isBefore(weekAgo)) {
        weekList.add(entry);
      } else {
        earlierList.add(entry);
      }
    }

    return <_RecentGroup>[
      if (todayList.isNotEmpty) _RecentGroup(_RecentGroupKind.today, todayList),
      if (yesterdayList.isNotEmpty)
        _RecentGroup(_RecentGroupKind.yesterday, yesterdayList),
      if (weekList.isNotEmpty)
        _RecentGroup(_RecentGroupKind.thisWeek, weekList),
      if (earlierList.isNotEmpty)
        _RecentGroup(_RecentGroupKind.earlier, earlierList),
    ];
  }

  SliverToBoxAdapter _sectionHeaderSliver(
    BuildContext context, {
    required String title,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _sectionTrailingSliver(
    BuildContext context, {
    required Future<void> Function() onTapClearAll,
  }) {
    final l10n = context.l10n;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(l10n.libraryRecentClearAll),
            onPressed: () => onTapClearAll(),
          ),
        ),
      ),
    );
  }

  SliverPadding _tilesSliver(List<RecentDocument> entries) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder:
            (context, index) => _RecentDocumentTile(entry: entries[index]),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    // Guard against a double-tap on the trailing "Clear all" button
    // presenting two confirmation dialogs at the same time: the
    // dialog's own open animation means the first tap has not yet
    // blocked input when the second one lands. Tracked through the
    // file-scope [_clearDialogOpen] flag because this widget is a
    // ConsumerWidget and cannot hold instance state.
    if (_clearDialogOpen) return;
    _clearDialogOpen = true;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.libraryRecentClearConfirmTitle),
          content: Text(l10n.libraryRecentClearConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.libraryRecentClearAll),
            ),
          ],
        );
      },
    );
    _clearDialogOpen = false;
    if (confirmed == true && context.mounted) {
      // mediumImpact matches the destructive-action haptic pattern
      // the viewer uses for bookmark save so the two surfaces feel
      // consistent when the user clears state.
      HapticFeedback.mediumImpact().ignore();
      ref.read(recentDocumentsControllerProvider.notifier).clear();
    }
  }
}

/// File-scope "clear-all confirm dialog in flight" flag. See
/// [_LibraryPopulatedBody._confirmClear] for rationale.
bool _clearDialogOpen = false;

/// Greeting card at the top of the populated library body.
/// Chooses one of three salutations based on the local hour of
/// day and shows a compact "N recent documents" subtitle.
class _LibraryGreeting extends StatelessWidget {
  const _LibraryGreeting({required this.recentCount});

  final int recentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final greeting = _greetingFor(DateTime.now().hour, l10n);
    final subtitle =
        recentCount == 0
            ? l10n.libraryGreetingSubtitleEmpty
            : l10n.libraryGreetingSubtitle(recentCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Filled-tonal search field. Visual chrome comes from
/// `InputDecoration.filled`; the live filter is driven by the
/// parent widget through [onChanged] so the search state lives
/// on the screen state rather than inside this input.
class _LibrarySearchField extends StatelessWidget {
  const _LibrarySearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final scheme = theme.colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintText: l10n.librarySearchHint,
        prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
        suffixIcon:
            query.isEmpty
                ? null
                : IconButton(
                  tooltip: l10n.librarySearchClear,
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
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
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Single recent-documents tile.
///
/// Layout: `Material 3` tile with a 44 dp leading icon, the
/// document basename in `bodyLarge`, a first subtitle line
/// combining parent folder + relative "opened … ago" timestamp,
/// and an optional second subtitle line carrying the preview
/// snippet the viewer extracted on the last open. A small
/// `push_pin` icon sits on the trailing side when the entry is
/// pinned. Tap re-opens the document via the existing
/// `/viewer?path=…` route. Long-press shows a context menu with
/// Pin/Unpin and Remove from recents.
class _RecentDocumentTile extends ConsumerWidget {
  const _RecentDocumentTile({required this.entry});

  final RecentDocument entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final path = entry.documentId.value;
    // Prefer the explicit display name recorded at touch time —
    // folder-sourced files live in the app cache under a
    // sha256-hashed path, and the cache basename is an opaque
    // blob. The display name carries the original filename from
    // the folder enumeration so the tile stays readable.
    final basename = entry.displayName ?? p.basename(path);
    final parent = p.basename(p.dirname(path));
    final relative = formatRelativeOpenedAt(l10n, entry.openedAt);
    // Folder-sourced tiles have a meaningless `library_folder_files`
    // cache directory as their dirname. Drop it from the subtitle
    // so the line reads "3 minutes ago" instead of
    // "library_folder_files • 3 minutes ago".
    final displayParent = entry.displayName != null ? '' : parent;
    final subtitleFirstLine =
        displayParent.isEmpty ? relative : '$displayParent • $relative';
    final preview = entry.preview;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openRecent(context, ref),
          onLongPress: () => _showContextMenu(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              basename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (entry.isPinned) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.push_pin,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleFirstLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (preview != null && preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRecent(BuildContext context, WidgetRef ref) async {
    // Re-resolve the file before pushing the viewer so a tap on a
    // stale entry (file deleted / moved) gives the user immediate
    // feedback AND self-cleans the list, instead of pushing a
    // viewer that just shows an error.
    final exists = await File(entry.documentId.value).exists();
    if (!context.mounted) {
      return;
    }
    if (!exists) {
      ref
          .read(recentDocumentsControllerProvider.notifier)
          .remove(entry.documentId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.libraryRecentFileMissing)),
      );
      return;
    }
    unawaited(context.push(ViewerRoute.location(entry.documentId.value)));
  }

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<_RecentMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  entry.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(
                  entry.isPinned
                      ? l10n.libraryRecentUnpin
                      : l10n.libraryRecentPin,
                ),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_RecentMenuAction.togglePin),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.libraryRecentRemove),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_RecentMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    switch (selected) {
      case null:
        return;
      case _RecentMenuAction.togglePin:
        final wasPinned = entry.isPinned;
        ref
            .read(recentDocumentsControllerProvider.notifier)
            .togglePin(entry.documentId);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                wasPinned
                    ? l10n.libraryRecentUnpinnedSnack
                    : l10n.libraryRecentPinnedSnack,
              ),
            ),
          );
      case _RecentMenuAction.remove:
        ref
            .read(recentDocumentsControllerProvider.notifier)
            .remove(entry.documentId);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.libraryRecentRemoved)));
    }
  }
}

enum _RecentMenuAction { togglePin, remove }

enum _RecentGroupKind { today, yesterday, thisWeek, earlier }

class _RecentGroup {
  const _RecentGroup(this.kind, this.entries);

  final _RecentGroupKind kind;
  final List<RecentDocument> entries;

  String title(AppLocalizations l10n) {
    switch (kind) {
      case _RecentGroupKind.today:
        return l10n.libraryRecentGroupToday;
      case _RecentGroupKind.yesterday:
        return l10n.libraryRecentGroupYesterday;
      case _RecentGroupKind.thisWeek:
        return l10n.libraryRecentGroupThisWeek;
      case _RecentGroupKind.earlier:
        return l10n.libraryRecentGroupEarlier;
    }
  }
}

/// Returns the greeting string for the given local [hour] of the
/// day. Exposed as a top-level function (rather than inlined into
/// the widget) so the unit tests can drive it directly without
/// pumping a whole widget tree.
@visibleForTesting
String greetingFor(int hour, AppLocalizations l10n) => _greetingFor(hour, l10n);

String _greetingFor(int hour, AppLocalizations l10n) {
  if (hour >= 5 && hour < 12) return l10n.libraryGreetingMorning;
  if (hour >= 12 && hour < 18) return l10n.libraryGreetingAfternoon;
  return l10n.libraryGreetingEvening;
}

/// Formats [openedAt] as a localized "opened … ago" string for
/// the recent-documents tiles. Hand-rolled rather than pulling in
/// a dep like `package:timeago` — the rules are simple, the copy
/// is fully under our control, and the ARB plurals already exist.
@visibleForTesting
String formatRelativeOpenedAt(AppLocalizations l10n, DateTime openedAt) {
  final delta = DateTime.now().difference(openedAt);
  if (delta.inSeconds < 60) {
    return l10n.libraryRecentJustNow;
  }
  if (delta.inMinutes < 60) {
    return l10n.libraryRecentMinutesAgo(delta.inMinutes);
  }
  if (delta.inHours < 24) {
    return l10n.libraryRecentHoursAgo(delta.inHours);
  }
  if (delta.inDays == 1) {
    return l10n.libraryRecentYesterday;
  }
  if (delta.inDays < 7) {
    return l10n.libraryRecentDaysAgo(delta.inDays);
  }
  return l10n.libraryRecentLongAgo;
}
