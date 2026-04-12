/// Typed failure hierarchy shared across features.
///
/// The project's error-handling rules live in
/// `docs/standards/error-handling-standards.md`. Summary:
///
/// - The data layer wraps exceptions from underlying packages in the
///   concrete [Failure] subclass that describes the user-facing problem.
/// - The application layer never catches raw exceptions from the data
///   layer — only [Failure]s.
/// - The presentation layer maps a [Failure] to a localized user
///   message via a shared mapper (added in a later phase).
///
/// Every [Failure] carries a short, developer-facing [message] and may
/// optionally reference the underlying [cause] for logging. The `cause`
/// is never shown to the user.
library;

sealed class Failure implements Exception {
  const Failure({required this.name, required this.message, this.cause});

  /// Stable, tree-shake-safe identifier for this failure kind. Each
  /// concrete subclass supplies a literal here so the string survives
  /// release builds and minification.
  final String name;

  /// Short developer-facing description of what went wrong. Not localized.
  /// User-facing copy is produced separately by the presentation layer.
  final String message;

  /// The original exception or error, when the failure wraps one. Used
  /// for logging and debugging; never shown to the user.
  final Object? cause;

  @override
  String toString() {
    final base = '$name($message)';
    return cause == null ? base : '$base <- $cause';
  }
}

/// The requested file does not exist or is no longer reachable.
final class FileNotFoundFailure extends Failure {
  const FileNotFoundFailure({required super.message, super.cause})
    : super(name: 'FileNotFoundFailure');
}

/// The OS denied access to the file (scoped storage, sandbox, etc.).
final class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure({required super.message, super.cause})
    : super(name: 'PermissionDeniedFailure');
}

/// The file could not be decoded as valid UTF-8 or parsed as markdown.
final class ParseFailure extends Failure {
  const ParseFailure({required super.message, super.cause})
    : super(name: 'ParseFailure');
}

/// A single block failed to render, but the document as a whole is still
/// usable. Callers should render an inline placeholder and continue.
final class RenderFailure extends Failure {
  const RenderFailure({required super.message, super.cause})
    : super(name: 'RenderFailure');
}

/// Catch-all for unexpected exceptions that do not map to a more
/// specific failure. Prefer a specific subclass whenever possible.
final class UnknownFailure extends Failure {
  const UnknownFailure({required super.message, super.cause})
    : super(name: 'UnknownFailure');
}
