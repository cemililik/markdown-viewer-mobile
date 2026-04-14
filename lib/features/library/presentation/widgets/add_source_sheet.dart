import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';

/// Opens the "Add source" bottom sheet that lets the user pick
/// between adding a local folder and (eventually) syncing a
/// remote repository.
///
/// Exposed as a top-level function rather than a widget so the
/// caller (drawer bottom button, future keyboard shortcut,
/// onboarding CTA) does not have to `showModalBottomSheet`
/// itself or know the shape of the sheet's internals.
Future<void> showAddSourceSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _AddSourceSheetBody(),
  );
}

/// Opens the native directory picker directly, without the "Add source"
/// selection sheet. Use this when the call-site already makes the
/// user intent clear (e.g. the "Open folder" button on the empty state
/// where "Sync repository" is already a separate affordance).
Future<void> pickAndAddFolder(BuildContext context, WidgetRef ref) =>
    _AddSourceSheetBody._pickFolder(context, ref);

class _AddSourceSheetBody extends ConsumerWidget {
  const _AddSourceSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.libraryAddSourceSheetTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _AddSourceEntry(
              icon: Icons.create_new_folder_outlined,
              title: l10n.libraryActionMenuOpenFolder,
              subtitle: l10n.libraryAddSourceFolderSubtitle,
              enabled: true,
              onTap: () => _AddSourceSheetBody._pickFolder(context, ref),
            ),
            const SizedBox(height: 12),
            _AddSourceEntry(
              icon: Icons.cloud_download_outlined,
              title: l10n.libraryActionMenuSyncRepo,
              subtitle: l10n.libraryAddSourceRepoSubtitle,
              enabled: true,
              onTap: () {
                Navigator.of(context).maybePop();
                context.push(RepoSyncRoute.location());
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final logger = ref.read(appLoggerProvider);
    final controller = ref.read(libraryFoldersControllerProvider.notifier);

    // Close the sheet before the picker lands so the system
    // directory picker UI does not race with the sheet's own
    // dismiss animation — on iOS a visible sheet under the
    // picker is a jarring double-modal.
    unawaited(Navigator.of(context).maybePop());

    String? path;
    String? bookmark;
    try {
      // Both platforms go through the native channel:
      //
      // - iOS: captures the security-scoped NSURL bookmark while
      //   the document picker's URL is still alive. Without it,
      //   any later `Directory.list()` on the returned path would
      //   trip `PathAccessException(Permission denied)` the
      //   moment the URL is deallocated.
      //
      // - Android: opens the SAF tree picker, calls
      //   `takePersistableUriPermission` so the granted access
      //   survives a cold start, and returns the tree URI as the
      //   bookmark. `dart:io` cannot read SAF content URIs at
      //   all, so every later access is also routed back through
      //   the channel.
      final pick = await NativeLibraryFoldersChannel().pickDirectory();
      path = pick?.path;
      bookmark = pick?.bookmark;
    } on Object catch (error, stackTrace) {
      logger.e('Folder picker failed', error: error, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryFoldersAddFailed)),
      );
      return;
    }

    if (path == null || path.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.libraryFoldersAddCancelled)),
      );
      return;
    }

    final added = controller.add(path, bookmark: bookmark);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added
                ? l10n.libraryFoldersAddedSnack
                : l10n.libraryFoldersAlreadyAdded,
          ),
        ),
      );
  }
}

class _AddSourceEntry extends StatelessWidget {
  const _AddSourceEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color:
          enabled
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      enabled
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  icon,
                  color:
                      enabled
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            enabled
                                ? scheme.onSurface
                                : scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
