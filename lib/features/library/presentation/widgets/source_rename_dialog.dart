import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/text/source_rename.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/repo_sync/application/rename_synced_repo.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';

/// End-to-end rename flow for a [LibraryFolder] source.
///
/// Opens [showSourceRenameDialog], normalises the result through the
/// `LibraryFoldersController.rename` use-case (empty / whitespace input
/// clears the override), and surfaces a localised confirmation snackbar.
/// Returns once the snackbar is queued or the user cancels.
///
/// Centralised so every long-press surface (drawer, Recents-empty home
/// screen) does not re-inline the dialog → mounted-check → notifier →
/// snackbar fan-out.
Future<void> promptFolderRename(
  BuildContext context,
  WidgetRef ref,
  LibraryFolder folder,
) async {
  final l10n = context.l10n;
  final result = await showSourceRenameDialog(
    context,
    title: l10n.libraryFoldersRenameDialogTitle,
    hintText: l10n.libraryFoldersRenameDialogHint,
    currentName: folder.customName ?? folder.displayName,
  );
  // `null` = user cancelled. An empty string is a deliberate
  // "clear the override" signal — the controller normalises it
  // to null so the displayName falls back to the path basename.
  if (result == null || !context.mounted) return;
  // Skip the snackbar (and the redundant disk write the controller
  // already short-circuits) when the normalised input matches the
  // persisted `customName`. Tapping Save without changing the text
  // should feel like Cancel, not "renamed".
  if (normaliseRenameInput(result) == folder.customName) return;
  ref
      .read(libraryFoldersControllerProvider.notifier)
      .rename(path: folder.path, customName: result);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.libraryFoldersRenamedSnack)));
}

/// End-to-end rename flow for a [SyncedRepo] source.
///
/// Mirrors [promptFolderRename] for synced-repo sources: dialog →
/// `renameSyncedRepo` use-case → snackbar. The use-case both
/// persists the override and invalidates `syncedReposProvider`
/// so the active-source listener swaps the held entity for one
/// carrying the fresh `customName`.
Future<void> promptSyncedRepoRename(
  BuildContext context,
  WidgetRef ref,
  SyncedRepo repo,
) async {
  final l10n = context.l10n;
  final result = await showSourceRenameDialog(
    context,
    title: l10n.syncRenameDialogTitle,
    hintText: l10n.syncRenameDialogHint,
    currentName: repo.customName ?? repo.displayName,
  );
  if (result == null || !context.mounted) return;
  // Same no-op skip as the folder helper — Save without an actual
  // change should not surface a "renamed" snackbar.
  if (normaliseRenameInput(result) == repo.customName) return;
  await renameSyncedRepo(ref, repo.id, result);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.syncRenamedRepoSnack)));
}

/// Shared rename dialog used by both folder sources and synced
/// repositories.
///
/// Returns the trimmed user input on confirm, or `null` on cancel.
/// An empty / whitespace-only confirm result signals "clear the
/// override" — call sites pass that through unchanged because the
/// repository layer normalises empty strings back to `null`
/// (the canonical "no override" state).
///
/// The current display label is pre-filled in the input so the
/// user can edit rather than retype from scratch.
Future<String?> showSourceRenameDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  required String currentName,
}) {
  return showDialog<String?>(
    context: context,
    builder:
        (_) => _SourceRenameDialog(
          title: title,
          hintText: hintText,
          currentName: currentName,
        ),
  );
}

/// Stateful body of the rename dialog. Owning the
/// [TextEditingController] inside a [State] (rather than
/// constructing it in the calling function and disposing it after
/// `showDialog` returns) ensures the controller outlives the
/// `TextField`'s deactivation/dispose phase. Disposing the
/// controller from a `finally` block in the caller fires before
/// Flutter has finished tearing down the dialog's widget tree,
/// which throws "TextEditingController was used after being
/// disposed".
class _SourceRenameDialog extends StatefulWidget {
  const _SourceRenameDialog({
    required this.title,
    required this.hintText,
    required this.currentName,
  });

  final String title;
  final String hintText;
  final String currentName;

  @override
  State<_SourceRenameDialog> createState() => _SourceRenameDialogState();
}

class _SourceRenameDialogState extends State<_SourceRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    // Pre-select the entire pre-filled label so the first keystroke
    // replaces it. Users renaming a long auto-generated name like
    // `cemililik/markdown-viewer-mobile` should be able to type a
    // short alias straight away without first reaching for the
    // backspace key.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        // Hard cap (mirrored in the rename use-cases) so a paste of
        // a multi-KB string cannot persist a pathological label that
        // a future cold start has to reload on every drawer open.
        maxLength: sourceRenameMaxLength,
        decoration: InputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.actionSave)),
      ],
    );
  }
}
