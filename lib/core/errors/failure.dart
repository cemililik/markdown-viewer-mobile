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
    if (cause == null) {
      return base;
    }
    // Deliberately emit only the cause's *type name*, never the raw
    // cause value. A [cause] can hold arbitrary data — file contents,
    // response bodies, HTTP headers, authentication tokens — and a
    // naive `'$base <- $cause'` interpolation would route that payload
    // through every logger and crash report that touches this string.
    // See docs/standards/security-standards.md (logging rules).
    // ignore: no_runtimeType_toString
    return '$base <- ${cause.runtimeType}';
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

// ── Repo sync failures ─────────────────────────────────────────────────────

/// The device has no network connectivity. The operation cannot
/// be retried until connectivity is restored.
final class NetworkUnavailableFailure extends Failure {
  const NetworkUnavailableFailure({required super.message, super.cause})
    : super(name: 'NetworkUnavailableFailure');
}

/// The remote provider responded with a rate-limit error (HTTP 403
/// with an exhausted quota). The user should add a PAT or wait.
final class RateLimitedFailure extends Failure {
  const RateLimitedFailure({required super.message, super.cause})
    : super(name: 'RateLimitedFailure');
}

/// The repository or sub-path was not found on the remote provider
/// (HTTP 404). The user should check the URL.
final class RepoNotFoundFailure extends Failure {
  const RepoNotFoundFailure({required super.message, super.cause})
    : super(name: 'RepoNotFoundFailure');
}

/// Sync completed but at least one file could not be downloaded.
/// The successfully downloaded files have been persisted; the
/// caller may surface a warning rather than an error.
final class PartialSyncFailure extends Failure {
  const PartialSyncFailure({
    required super.message,
    super.cause,
    required this.syncedCount,
    required this.failedCount,
  }) : super(name: 'PartialSyncFailure');

  final int syncedCount;
  final int failedCount;
}

/// The pasted URL does not match any registered sync provider.
final class UnsupportedProviderFailure extends Failure {
  const UnsupportedProviderFailure({required super.message, super.cause})
    : super(name: 'UnsupportedProviderFailure');
}

/// The remote provider rejected the request for authentication or
/// authorisation reasons — HTTP 401 (missing / invalid / expired
/// token) or HTTP 403 outside the rate-limit branch (private repo
/// without a PAT, SAML-enforced org the token cannot access, etc.).
/// Distinct from [RateLimitedFailure] so the UI can render "fix your
/// token" copy instead of "wait for the quota to reset".
final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.cause})
    : super(name: 'AuthFailure');
}
