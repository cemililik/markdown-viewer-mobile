import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/logging/logger.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLibrary),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.navSettings,
            onPressed: () => context.push(SettingsRoute.location()),
          ),
        ],
      ),
      body: Center(
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.libraryEmptyTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.libraryEmptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _pickAndOpenFile(context, ref),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(l10n.actionOpenFile),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.actionSyncRepo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndOpenFile(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Read the logger eagerly so the closure does not capture `ref`
    // across the await — Riverpod widget refs are tied to the element
    // lifecycle and cannot be safely used after a context.mounted gap.
    final logger = ref.read(appLoggerProvider);

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'markdown'],
      );
    } on Object catch (error, stackTrace) {
      // file_picker can surface platform-channel errors, plugin init
      // failures, or platform-specific exceptions. None of them should
      // crash the app — log the failure and show a localized snackbar.
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
    // stack and the user can tap back to come home. `go` would
    // replace the library entry and strand the user inside the
    // viewer with no back affordance. The push future completes
    // when the user pops the viewer; we intentionally do not wait
    // on it — nothing in this handler should run post-pop.
    unawaited(context.push(ViewerRoute.location(path)));
  }
}
