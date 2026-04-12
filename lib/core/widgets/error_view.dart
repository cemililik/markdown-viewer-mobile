import 'package:flutter/material.dart';

/// Shared error display used by every feature's error state.
///
/// The widget has no logic of its own — it is a pure presentation of a
/// fully-formed user message plus an optional retry callback. Mapping a
/// [Failure] to the [message] string happens at each feature's own
/// `failure_message_mapper.dart`, because different features may want
/// different wording for the same failure type.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline,
    super.key,
  }) : assert(
         onRetry == null || retryLabel != null,
         'ErrorView.onRetry requires a non-null localized retryLabel. '
         'Passing onRetry without retryLabel would force the widget to '
         'pick a hard-coded English fallback for the button copy, which '
         'violates localization-standards.md.',
       );

  /// Localized, user-facing description of the failure. Must already be
  /// translated — do not pass raw [Failure.message] here.
  final String message;

  /// Invoked when the retry button is tapped. Passing `null` hides the
  /// button entirely.
  final VoidCallback? onRetry;

  /// Localized label for the retry button. Must be non-null whenever
  /// [onRetry] is non-null — the constructor asserts on this. Ignored
  /// when [onRetry] is null. The widget never falls back to an
  /// untranslated English label.
  final String? retryLabel;

  /// Icon shown above the message. Defaults to a generic error icon;
  /// callers can override for domain-specific visuals.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  // `retryLabel!` is safe because the constructor
                  // asserts that a non-null onRetry implies a non-null
                  // retryLabel.
                  label: Text(retryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
