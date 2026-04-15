import 'package:flutter/material.dart';

/// Shared loading indicator used during async data fetches.
///
/// Intentionally minimal: a centred circular progress indicator with an
/// optional label. Feature-specific loading skeletons belong in the
/// feature's own presentation folder.
class LoadingView extends StatelessWidget {
  const LoadingView({this.label, super.key});

  /// Optional localized label shown beneath the spinner.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: 16),
              // ExcludeSemantics prevents the label being read twice:
              // once by the Semantics node above and again as a Text.
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
