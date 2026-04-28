import 'package:flutter/material.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';

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
