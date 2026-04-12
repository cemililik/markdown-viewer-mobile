import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLibrary)),
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
                  onPressed: () => _pickAndOpenFile(context),
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

  Future<void> _pickAndOpenFile(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

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
      Logger().e('File picker failed', error: error, stackTrace: stackTrace);
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

    context.go(ViewerRoute.location(path));
  }
}
